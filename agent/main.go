package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

// Config holds the agent configuration.
type Config struct {
	Port int
	Host string
	Token string
	Root string
}

// cached CPU percentage updated by background goroutine.
var cpuPercent atomic.Value

func init() {
	cpuPercent.Store(0.0)
}

// updateCPU periodically samples CPU usage so the metrics endpoint is fast.
func updateCPU() {
	// First call to cpu.Percent returns nothing; prime it.
	_, _ = cpu.Percent(0, false)
	for {
		percents, err := cpu.Percent(2*time.Second, false)
		if err == nil && len(percents) > 0 {
			cpuPercent.Store(percents[0])
		}
	}
}

// --- JSON helpers ---

type JSONResponse map[string]interface{}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("ERROR: failed to write JSON response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, JSONResponse{"error": message})
}

// --- CORS middleware ---

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Auth-Token")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// --- Auth middleware ---

func authMiddleware(token string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Health check is unauthenticated.
			if r.URL.Path == "/api/health" {
				next.ServeHTTP(w, r)
				return
			}
			if r.Header.Get("X-Auth-Token") != token {
				writeError(w, http.StatusUnauthorized, "unauthorized: invalid or missing X-Auth-Token")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// --- Logging middleware ---

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	})
}

// --- Path safety ---

// safePath resolves and validates a path relative to root, preventing directory traversal.
func safePath(root, sub string) (string, error) {
	// Clean and join
	full := filepath.Join(root, filepath.Clean("/"+sub))
	abs, err := filepath.Abs(full)
	if err != nil {
		return "", fmt.Errorf("failed to resolve path: %w", err)
	}
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return "", fmt.Errorf("failed to resolve root: %w", err)
	}
	if !strings.HasPrefix(abs, absRoot) {
		return "", fmt.Errorf("path escapes root directory")
	}
	return abs, nil
}

// --- Handlers ---

type Handlers struct {
	cfg Config
}

// GET /api/metrics
func (h *Handlers) metrics(w http.ResponseWriter, r *http.Request) {
	// CPU (cached)
	cpuVal := cpuPercent.Load().(float64)

	// Memory
	var memUsedGB, memTotalGB float64
	if v, err := mem.VirtualMemory(); err == nil {
		memUsedGB = float64(v.Used) / 1e9
		memTotalGB = float64(v.Total) / 1e9
	}

	// Disk (root partition)
	var diskUsedGB, diskTotalGB float64
	if d, err := disk.Usage("/"); err == nil {
		diskUsedGB = float64(d.Used) / 1e9
		diskTotalGB = float64(d.Total) / 1e9
	}

	// Network (cumulative bytes since boot, all interfaces)
	var netIn, netOut uint64
	if counters, err := net.IOCounters(false); err == nil && len(counters) > 0 {
		netIn = counters[0].BytesRecv
		netOut = counters[0].BytesSent
	}

	// Load average
	var load1, load5, load15 float64
	if l, err := load.Avg(); err == nil {
		load1 = l.Load1
		load5 = l.Load5
		load15 = l.Load15
	}

	// Uptime
	var uptimeSec uint64
	if u, err := host.Uptime(); err == nil {
		uptimeSec = u
	}

	writeJSON(w, http.StatusOK, JSONResponse{
		"cpu_percent":     round2(cpuVal),
		"memory_used_gb":  round2(memUsedGB),
		"memory_total_gb": round2(memTotalGB),
		"disk_used_gb":    round2(diskUsedGB),
		"disk_total_gb":   round2(diskTotalGB),
		"network_in_bytes":  netIn,
		"network_out_bytes": netOut,
		"load_avg_1":  round2(load1),
		"load_avg_5":  round2(load5),
		"load_avg_15": round2(load15),
		"uptime_seconds": uptimeSec,
	})
}

func round2(f float64) float64 {
	return float64(int(f*100)) / 100
}

// POST /api/exec
func (h *Handlers) execCmd(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var body struct {
		Cmd string `json:"cmd"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if body.Cmd == "" {
		writeError(w, http.StatusBadRequest, "cmd is required")
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", body.Cmd)
	cmd.Env = os.Environ()

	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create stdout pipe")
		return
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create stderr pipe")
		return
	}

	if err := cmd.Start(); err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to start command: %v", err))
		return
	}

	var stdout, stderr strings.Builder
	// Read both streams concurrently
	done := make(chan struct{}, 2)
	go func() {
		scanner := bufio.NewScanner(stdoutPipe)
		for scanner.Scan() {
			stdout.WriteString(scanner.Text() + "\n")
		}
		done <- struct{}{}
	}()
	go func() {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			stderr.WriteString(scanner.Text() + "\n")
		}
		done <- struct{}{}
	}()

	// Wait for streams or context cancellation
	streamsDone := 0
	for streamsDone < 2 {
		select {
		case <-done:
			streamsDone++
		case <-ctx.Done():
			cmd.Process.Kill()
			// Drain remaining
			for streamsDone < 2 {
				<-done
				streamsDone++
			}
		}
	}

	err = cmd.Wait()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}
	if ctx.Err() != nil {
		exitCode = -1
		stderr.WriteString("\n[command timed out after 30s]\n")
	}

	writeJSON(w, http.StatusOK, JSONResponse{
		"stdout":   stdout.String(),
		"stderr":   stderr.String(),
		"exitCode": exitCode,
	})
}

// GET /api/files
func (h *Handlers) listFiles(w http.ResponseWriter, r *http.Request) {
	relPath := r.URL.Query().Get("path")
	if relPath == "" {
		relPath = "/"
	}

	absPath, err := safePath(h.cfg.Root, relPath)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	entries, err := os.ReadDir(absPath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to read directory: %v", err))
		return
	}

	type FileEntry struct {
		Name     string `json:"name"`
		Type     string `json:"type"`
		Size     int64  `json:"size"`
		Modified string `json:"modified"`
		Perms    string `json:"perms"`
	}

	result := make([]FileEntry, 0, len(entries))
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}
		entryType := "file"
		if entry.IsDir() {
			entryType = "dir"
		}
		result = append(result, FileEntry{
			Name:     entry.Name(),
			Type:     entryType,
			Size:     info.Size(),
			Modified: info.ModTime().UTC().Format(time.RFC3339),
			Perms:    info.Mode().String(),
		})
	}

	writeJSON(w, http.StatusOK, JSONResponse{"files": result})
}

// POST /api/files/upload
func (h *Handlers) uploadFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	// Limit upload to 100MB
	r.Body = http.MaxBytesReader(w, r.Body, 100<<20)

	if err := r.ParseMultipartForm(32 << 20); err != nil {
		writeError(w, http.StatusBadRequest, fmt.Sprintf("failed to parse multipart form: %v", err))
		return
	}

	relPath := r.FormValue("path")
	if relPath == "" {
		relPath = "/"
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, fmt.Sprintf("failed to read uploaded file: %v", err))
		return
	}
	defer file.Close()

	destPath, err := safePath(h.cfg.Root, filepath.Join(relPath, header.Filename))
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to create parent directory: %v", err))
		return
	}

	out, err := os.Create(destPath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to create file: %v", err))
		return
	}
	defer out.Close()

	written, err := io.Copy(out, file)
	if err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to write file: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, JSONResponse{
		"path": filepath.Join(relPath, header.Filename),
		"size": written,
	})
}

// GET /api/files/download
func (h *Handlers) downloadFile(w http.ResponseWriter, r *http.Request) {
	relPath := r.URL.Query().Get("path")
	if relPath == "" {
		writeError(w, http.StatusBadRequest, "path query parameter is required")
		return
	}

	absPath, err := safePath(h.cfg.Root, relPath)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	info, err := os.Stat(absPath)
	if err != nil {
		writeError(w, http.StatusNotFound, fmt.Sprintf("file not found: %v", err))
		return
	}
	if info.IsDir() {
		writeError(w, http.StatusBadRequest, "cannot download a directory")
		return
	}

	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filepath.Base(absPath)))
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, absPath)
}

// POST /api/files/mkdir
func (h *Handlers) mkdir(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var body struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if body.Path == "" {
		writeError(w, http.StatusBadRequest, "path is required")
		return
	}

	absPath, err := safePath(h.cfg.Root, body.Path)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := os.MkdirAll(absPath, 0755); err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to create directory: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, JSONResponse{"path": body.Path})
}

// POST /api/files/delete
func (h *Handlers) deleteFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	var body struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if body.Path == "" {
		writeError(w, http.StatusBadRequest, "path is required")
		return
	}

	absPath, err := safePath(h.cfg.Root, body.Path)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Prevent deleting root
	if absPath == h.cfg.Root || absPath == "/" {
		writeError(w, http.StatusBadRequest, "cannot delete root directory")
		return
	}

	if err := os.RemoveAll(absPath); err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to delete: %v", err))
		return
	}

	writeJSON(w, http.StatusOK, JSONResponse{"deleted": body.Path})
}

// GET /api/health
func (h *Handlers) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, JSONResponse{
		"status": "ok",
		"time":   time.Now().UTC().Format(time.RFC3339),
		"go":     runtime.Version(),
	})
}

// --- WebSocket terminal ---

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for server agent
	},
}

func (h *Handlers) wsTerminal(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ERROR: WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	log.Printf("INFO: WebSocket terminal connected from %s", r.RemoteAddr)

	// Set read deadline to detect stale connections
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))

	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("ERROR: WebSocket read error: %v", err)
			}
			break
		}

		// Reset read deadline on each message
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))

		if messageType != websocket.TextMessage {
			continue
		}

		cmdStr := strings.TrimSpace(string(message))
		if cmdStr == "" {
			continue
		}

		// Handle special commands
		if cmdStr == "exit" {
			conn.WriteMessage(websocket.TextMessage, []byte("Bye!\n"))
			break
		}

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		cmd := exec.CommandContext(ctx, "/bin/sh", "-c", cmdStr)
		cmd.Env = os.Environ()

		output, err := cmd.CombinedOutput()
		cancel()

		if err != nil {
			if ctx.Err() != nil {
				output = append(output, []byte("\n[command timed out]\n")...)
			} else {
				output = append(output, []byte(fmt.Sprintf("\n[exit code: %v]\n", err))...)
			}
		}

		if len(output) > 0 {
			if err := conn.WriteMessage(websocket.TextMessage, output); err != nil {
				log.Printf("ERROR: WebSocket write error: %v", err)
				break
			}
		}

		// Send a prompt marker
		conn.WriteMessage(websocket.TextMessage, []byte("\n$ "))
	}

	log.Printf("INFO: WebSocket terminal disconnected from %s", r.RemoteAddr)
}

// --- Router setup ---

func (h *Handlers) setupRoutes() http.Handler {
	mux := http.NewServeMux()

	// Health - unauthenticated
	mux.HandleFunc("/api/health", h.health)

	// Metrics
	mux.HandleFunc("/api/metrics", h.metrics)

	// Exec
	mux.HandleFunc("/api/exec", h.execCmd)

	// Files
	mux.HandleFunc("/api/files", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			h.listFiles(w, r)
		default:
			writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	})
	mux.HandleFunc("/api/files/upload", h.uploadFile)
	mux.HandleFunc("/api/files/download", h.downloadFile)
	mux.HandleFunc("/api/files/mkdir", h.mkdir)
	mux.HandleFunc("/api/files/delete", h.deleteFile)

	// WebSocket terminal
	mux.HandleFunc("/ws/terminal", h.wsTerminal)

	// Apply middleware: CORS → Auth → Logging
	var handler http.Handler = mux
	handler = loggingMiddleware(handler)
	handler = authMiddleware(h.cfg.Token)(handler)
	handler = corsMiddleware(handler)

	return handler
}

// --- Main ---

func main() {
	cfg := Config{}

	flag.IntVar(&cfg.Port, "port", 9527, "HTTP server port")
	flag.StringVar(&cfg.Host, "host", "0.0.0.0", "HTTP server host")
	flag.StringVar(&cfg.Token, "token", "zhizon-agent", "Auth token for X-Auth-Token header")
	flag.StringVar(&cfg.Root, "root", "/", "Root directory for file operations")
	flag.Parse()

	// Resolve root to absolute path
	absRoot, err := filepath.Abs(cfg.Root)
	if err != nil {
		log.Fatalf("FATAL: invalid root path: %v", err)
	}
	cfg.Root = absRoot

	log.Printf("INFO: Zhizon Agent starting...")
	log.Printf("INFO: Host: %s, Port: %d, Root: %s", cfg.Host, cfg.Port, cfg.Root)

	// Start CPU monitoring in background
	go updateCPU()

	h := &Handlers{cfg: cfg}
	handler := h.setupRoutes()

	addr := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Printf("INFO: Server listening on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("FATAL: server error: %v", err)
		}
	}()

	<-stop
	log.Println("INFO: Shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("ERROR: server shutdown error: %v", err)
	}
	log.Println("INFO: Server stopped")
}
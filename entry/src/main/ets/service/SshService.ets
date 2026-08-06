// 智子 - SSH 服务（双模通信：直连 + Agent）
import { http, webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { Server, ServerMetrics, FileItem, ConnectionMode, AuthType } from '../model/Models';
import { DataRepository } from './DataRepository';
import { libssh } from '@ohos/libssh';

// ========== 错误码 ==========

export class SshError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
    this.name = 'SshError';
  }
}

export const SSH_ERR_AUTH_FAIL = 'SSH_ERR_AUTH_FAIL';
export const SSH_ERR_TIMEOUT = 'SSH_ERR_TIMEOUT';
export const SSH_ERR_HOST_UNREACH = 'SSH_ERR_HOST_UNREACH';
export const SSH_ERR_KEY_INVALID = 'SSH_ERR_KEY_INVALID';
export const AGENT_ERR_UNREACH = 'AGENT_ERR_UNREACH';
export const AGENT_ERR_TOKEN = 'AGENT_ERR_TOKEN';

// ========== ServerConfig ==========

export interface ServerConfig {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKeyContent?: string;
  privateKeyPath?: string;
  agentToken?: string;
  authType: AuthType;
  connectionMode: ConnectionMode;
}

// ========== SshEngine 接口 ==========

export interface SshEngine {
  connect(config: ServerConfig): Promise<boolean>;
  disconnect(): Promise<void>;
  isConnected(): boolean;
  exec(command: string, timeout?: number): Promise<string>;
  openTerminal(cols?: number, rows?: number): Promise<void>;
  onTerminalData(callback: (data: string) => void): void;
  sendTerminalInput(data: string): void;
  closeTerminal(): void;
  resizeTerminal?(cols: number, rows: number): void;
  getMetrics(): Promise<ServerMetrics>;
  listFiles(path: string): Promise<FileItem[]>;
  uploadFile(localPath: string, remotePath: string): Promise<void>;
  downloadFile(remotePath: string, localPath: string): Promise<void>;
}

// ========== AgentClient（HTTP 通信客户端） ==========

export class AgentClient {
  private baseUrl: string;
  private token: string;
  private agentPort: number = 9527;

  constructor(host: string, port: number = 9527, token: string = 'zhizon-agent') {
    this.agentPort = port;
    this.baseUrl = `http://${host}:${port}`;
    this.token = token;
  }

  getWsUrl(): string {
    return `ws://${this.baseUrl.replace('http://', '')}/ws/terminal`;
  }

  getToken(): string {
    return this.token;
  }

  private async request(method: http.RequestMethod, path: string, data?: string): Promise<Record<string, Object> | null> {
    try {
      const req = http.createHttp();
      const res = await req.request(`${this.baseUrl}${path}`, {
        method: method,
        header: {
          'Content-Type': 'application/json',
          'X-Auth-Token': this.token
        },
        extraData: data,
        expectDataType: http.HttpDataType.OBJECT,
        connectTimeout: 10000,
        readTimeout: 30000
      });
      req.destroy();
      if (res.responseCode === 200) {
        return res.result as Record<string, Object>;
      }
      return null;
    } catch (e) {
      console.error('Agent request failed:', JSON.stringify(e));
      return null;
    }
  }

  // 二进制请求（用于文件下载）
  private async requestBinary(path: string): Promise<ArrayBuffer | null> {
    try {
      const req = http.createHttp();
      const res = await req.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'X-Auth-Token': this.token
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 60000
      });
      req.destroy();
      if (res.responseCode === 200) {
        return res.result as ArrayBuffer;
      }
      return null;
    } catch (e) {
      console.error('Agent binary request failed:', JSON.stringify(e));
      return null;
    }
  }

  async healthCheck(): Promise<boolean> {
    const res = await this.request(http.RequestMethod.GET, '/api/health');
    return res !== null && res['status'] === 'ok';
  }

  async getMetrics(): Promise<ServerMetrics | null> {
    const res = await this.request(http.RequestMethod.GET, '/api/metrics');
    if (!res) return null;

    const cpu = (res['cpu_percent'] as number) || 0;
    const memUsed = (res['memory_used_gb'] as number) || 0;
    const memTotal = (res['memory_total_gb'] as number) || 1;
    const diskUsed = (res['disk_used_gb'] as number) || 0;
    const diskTotal = (res['disk_total_gb'] as number) || 1;
    const netIn = (res['network_in_bytes'] as number) || 0;
    const netOut = (res['network_out_bytes'] as number) || 0;
    const load = (res['load_avg_1'] as number) || 0;
    const uptime = (res['uptime_seconds'] as number) || 0;

    return {
      cpu: Math.round(cpu),
      mem: Math.round((memUsed / memTotal) * 100),
      disk: Math.round((diskUsed / diskTotal) * 100),
      netIn: netIn,
      netOut: netOut,
      load: load,
      uptime: uptime
    };
  }

  async exec(cmd: string): Promise<string> {
    const res = await this.request(http.RequestMethod.POST, '/api/exec', JSON.stringify({ cmd: cmd }));
    if (!res) return '命令执行失败：无法连接到 Agent';

    const stdout = (res['stdout'] as string) || '';
    const stderr = (res['stderr'] as string) || '';
    const exitCode = (res['exitCode'] as number) || 0;

    let output = stdout;
    if (stderr) output += '\n[stderr]\n' + stderr;
    if (exitCode !== 0) output += `\n[退出码: ${exitCode}]`;
    return output || '命令执行成功 (无输出)';
  }

  async listFiles(dirPath: string): Promise<FileItem[]> {
    const res = await this.request(http.RequestMethod.GET, `/api/files?path=${encodeURIComponent(dirPath)}`);
    if (!res || !res['files']) return [];

    const files = res['files'] as Array<Record<string, Object>>;
    const result: FileItem[] = [];
    for (const f of files) {
      const item: FileItem = {
        name: (f['name'] as string) || '',
        type: ((f['type'] as string) || 'file') as 'dir' | 'file',
        size: (f['size'] as number) || 0,
        modified: (f['modified'] as string) || '',
        perms: (f['perms'] as string) || ''
      };
      result.push(item);
    }
    return result;
  }

  async mkdir(dirPath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/mkdir', JSON.stringify({ path: dirPath }));
    return res !== null;
  }

  async deleteFile(filePath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/delete', JSON.stringify({ path: filePath }));
    return res !== null;
  }

  // base64 文件上传
  async uploadFileBase64(remotePath: string, content: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/upload-base64',
      JSON.stringify({ path: remotePath, content: content }));
    return res !== null;
  }

  // 二进制文件下载
  async downloadFileBinary(remotePath: string): Promise<ArrayBuffer | null> {
    return await this.requestBinary(`/api/files/download?path=${encodeURIComponent(remotePath)}`);
  }
}

// ========== AgentEngine（封装 AgentClient 为 SshEngine，含 WebSocket 终端 + SSH 网关） ==========
// 支持两种终端模式：
//   1. 本地终端：WS 直连 Agent，Agent 在本地执行 shell 命令（现有模式）
//   2. SSH 网关：WS 连接 Agent，Agent 通过 x/crypto/ssh 远程连接目标服务器并转发 PTY

export class AgentEngine implements SshEngine {
  private client: AgentClient | null = null;
  private connected: boolean = false;
  private terminalCallback: ((data: string) => void) | null = null;
  private ws: webSocket.WebSocket | null = null;
  private wsConnected: boolean = false;
  private config: ServerConfig | null = null;
  private eventCallback: ((event: string, message: string) => void) | null = null;

  async connect(config: ServerConfig): Promise<boolean> {
    try {
      this.config = config;
      this.client = new AgentClient(config.host, 9527, config.agentToken || 'zhizon-agent');
      const ok = await this.client.healthCheck();
      this.connected = ok;
      if (!ok) {
        throw new SshError(AGENT_ERR_UNREACH, `Agent 不可达: ${config.host}:9527`);
      }
      return true;
    } catch (e) {
      this.connected = false;
      if (e instanceof SshError) throw e;
      throw new SshError(AGENT_ERR_UNREACH, `Agent 连接失败: ${JSON.stringify(e)}`);
    }
  }

  async disconnect(): Promise<void> {
    this.closeTerminal();
    this.client = null;
    this.connected = false;
    this.config = null;
    this.eventCallback = null;
  }

  isConnected(): boolean {
    return this.connected;
  }

  async exec(command: string, timeout?: number): Promise<string> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');
    return await this.client.exec(command);
  }

  // 注册连接事件回调（connected / disconnected / error / reconnecting）
  onConnectionEvent(callback: (event: string, message: string) => void): void {
    this.eventCallback = callback;
  }

  async openTerminal(cols?: number, rows?: number): Promise<void> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');

    // 如果已有 WebSocket 连接，先关闭
    this.closeTerminal();

    try {
      this.ws = webSocket.createWebSocket();
      // 使用 /ws/ssh 网关端点，支持 SSH 远程连接
      const wsUrl = this.client.getWsUrl().replace('/ws/terminal', '/ws/ssh');
      const token = this.client.getToken();

      this.ws.on('open', () => {
        this.wsConnected = true;
        // WS 连接建立后，发送 SSH 连接参数（JSON 格式）
        if (this.config) {
          const sshParams = JSON.stringify({
            type: 'connect',
            host: this.config.host,
            port: this.config.port,
            username: this.config.username,
            password: this.config.password || '',
            privateKeyContent: this.config.privateKeyContent || '',
            authType: this.config.authType,
            cols: cols || 80,
            rows: rows || 24
          });
          this.ws!.send(sshParams, (err: Error) => {
            if (err) console.error('SSH params send failed:', JSON.stringify(err));
          });
        }
        if (this.terminalCallback) {
          this.terminalCallback('\x1b[32m终端连接已建立\x1b[0m\n');
        }
        if (this.eventCallback) {
          this.eventCallback('connected', `已连接到 ${this.config?.host || 'Agent'}`);
        }
      });

      this.ws.on('message', (err: Error, value: string | ArrayBuffer) => {
        if (err) {
          console.error('WS message error:', JSON.stringify(err));
          return;
        }
        const raw = typeof value === 'string' ? value : '';
        // 尝试解析 JSON 控制消息
        try {
          const msg = JSON.parse(raw) as Record<string, Object>;
          if (msg['type'] === 'event') {
            // Agent 侧事件转发
            if (this.eventCallback) {
              this.eventCallback((msg['event'] as string) || 'info', (msg['message'] as string) || '');
            }
            if (this.terminalCallback) {
              this.terminalCallback(`\n[${msg['event']}] ${msg['message']}\n`);
            }
            return;
          }
          if (msg['type'] === 'progress') {
            // SFTP 传输进度
            if (this.terminalCallback) {
              const pct = msg['percent'] as number || 0;
              const transferred = msg['transferred'] as number || 0;
              const total = msg['total'] as number || 0;
              this.terminalCallback(`\r传输进度: ${pct}% (${transferred}/${total} bytes)`);
            }
            return;
          }
        } catch (e) {
          // 不是 JSON，当作普通终端输出
        }
        if (this.terminalCallback) {
          this.terminalCallback(raw);
        }
      });

      this.ws.on('close', (err: Error, value: webSocket.CloseResult) => {
        this.wsConnected = false;
        if (this.terminalCallback) {
          this.terminalCallback('\n\x1b[31m[连接已关闭]\x1b[0m\n');
        }
        if (this.eventCallback) {
          this.eventCallback('disconnected', `连接已关闭 (code=${value.code})`);
        }
      });

      this.ws.on('error', (err: Error) => {
        this.wsConnected = false;
        if (this.terminalCallback) {
          this.terminalCallback(`\n\x1b[31m[WebSocket 错误: ${err.message}]\x1b[0m\n`);
        }
        if (this.eventCallback) {
          this.eventCallback('error', err.message);
        }
      });

      await this.ws.connect(wsUrl, {
        header: { 'X-Auth-Token': token }
      });
    } catch (e) {
      throw new SshError(AGENT_ERR_UNREACH, `WebSocket 连接失败: ${JSON.stringify(e)}`);
    }
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    if (this.ws && this.wsConnected) {
      this.ws.send(data, (err: Error) => {
        if (err) {
          console.error('WebSocket send failed:', JSON.stringify(err));
        }
      });
    }
  }

  // 终端尺寸变化时通知 Agent
  resizeTerminal(cols: number, rows: number): void {
    if (this.ws && this.wsConnected) {
      const resizeMsg = JSON.stringify({ type: 'resize', cols: cols, rows: rows });
      this.ws.send(resizeMsg, (err: Error) => {
        if (err) {
          console.error('Resize send failed:', JSON.stringify(err));
        }
      });
    }
  }

  closeTerminal(): void {
    if (this.ws) {
      try {
        // 发送断开命令
        if (this.wsConnected) {
          const discMsg = JSON.stringify({ type: 'disconnect' });
          this.ws.send(discMsg, () => {});
        }
        this.ws.close((err: Error) => {
          if (err) {
            console.error('WebSocket close failed:', JSON.stringify(err));
          }
        });
      } catch (e) {
        // 忽略关闭错误
      }
      this.ws = null;
      this.wsConnected = false;
    }
    this.terminalCallback = null;
  }

  async getMetrics(): Promise<ServerMetrics> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');
    const metrics = await this.client.getMetrics();
    if (metrics) return metrics;
    return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
  }

  async listFiles(path: string): Promise<FileItem[]> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');
    return await this.client.listFiles(path);
  }

  async uploadFile(localPath: string, remotePath: string): Promise<void> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');

    // 读取本地文件并 base64 编码上传
    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(localPath);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);

      const base64Helper = new util.Base64Helper();
      const encoded: string = await base64Helper.encodeToString(new Uint8Array(buf));

      const ok = await this.client.uploadFileBase64(remotePath, encoded);
      if (!ok) {
        throw new SshError(SSH_ERR_TIMEOUT, '文件上传失败');
      }
    } catch (e) {
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_TIMEOUT, `文件上传异常: ${JSON.stringify(e)}`);
    }
  }

  async downloadFile(remotePath: string, localPath: string): Promise<void> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');

    try {
      const data = await this.client.downloadFileBinary(remotePath);
      if (!data) {
        throw new SshError(SSH_ERR_TIMEOUT, '文件下载失败：无数据返回');
      }

      // 写入本地文件
      const file = fileIo.openSync(localPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
    } catch (e) {
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_TIMEOUT, `文件下载异常: ${JSON.stringify(e)}`);
    }
  }
}

// ========== DirectEngine（基于 @ohos/libssh 的直连引擎） ==========
// 能力边界（基于 libssh-0.11.1 NAPI 封装实际 API）：
//   - 支持：密码/密钥认证、非交互命令执行（exec）、SFTP 只读文件列表
//   - 不支持：流式终端回调、resize、SFTP 上传/下载、keepalive 心跳
//   - 策略：connect/exec/listFiles 走真实 libssh；终端/SFTP 传输降级到 Agent

export class DirectEngine implements SshEngine {
  private ssh: libssh | null = null;
  private connected: boolean = false;
  private shellReady: boolean = false;
  private config: ServerConfig | null = null;
  private terminalCallback: ((data: string) => void) | null = null;
  private agentFallback: AgentEngine | null = null;
  private terminalPollingTimer: number = -1;
  private keepaliveTimer: number = -1;

  async connect(config: ServerConfig): Promise<boolean> {
    this.config = config;
    this.connected = false;
    this.shellReady = false;
    try {
      this.ssh = new libssh();
      // 设置用户名密码
      const userResult = this.ssh.setUser(config.username, config.password || '');
      console.info('DirectEngine: setUser result:', userResult);

      // 确定私钥路径（空串表示使用密码认证，底层会先尝试 publickey_auto 再 fallback 到 password）
      const keyPath = config.authType === 'key' ? (config.privateKeyPath || '') : '';

      // startSSHClient 返回 Promise<number>，0 表示成功
      const startResult = await this.ssh.startSSHClient(config.host, config.port, keyPath,
        (event: number) => {
          console.info('DirectEngine: startSSHClient callback event:', event);
        });
      console.info('DirectEngine: startSSHClient result:', startResult);

      if (startResult !== 0) {
        throw new SshError(SSH_ERR_AUTH_FAIL,
          `SSH 认证失败: ${config.host}:${config.port} (code=${startResult})`);
      }

      this.connected = true;
      this.startKeepalive();
      return true;
    } catch (e) {
      this.connected = false;
      this.shellReady = false;
      this.stopKeepalive();
      if (e instanceof SshError) throw e;
      const msg = JSON.stringify(e);
      if (msg.includes('auth') || msg.includes('password') || msg.includes('key')) {
        throw new SshError(SSH_ERR_AUTH_FAIL, `SSH 认证失败: ${config.host}:${config.port}`);
      }
      throw new SshError(SSH_ERR_HOST_UNREACH, `SSH 连接失败: ${msg}`);
    }
  }

  async disconnect(): Promise<void> {
    this.stopKeepalive();
    this.stopTerminalPolling();
    this.closeTerminal();
    if (this.agentFallback) {
      await this.agentFallback.disconnect();
      this.agentFallback = null;
    }
    if (this.ssh) {
      try {
        this.ssh.stopSSHClient();
      } catch (e) {
        // 忽略关闭错误
      }
      this.ssh = null;
    }
    this.connected = false;
    this.shellReady = false;
    this.config = null;
  }

  isConnected(): boolean {
    return this.connected;
  }

  // 确保 shell 已创建（exec 依赖 CreateShell）
  private ensureShell(): void {
    if (!this.ssh || !this.connected) {
      throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    }
    if (!this.shellReady) {
      const shellResult = this.ssh.createShell();
      console.info('DirectEngine: createShell result:', shellResult);
      if (shellResult !== 0) {
        throw new SshError(SSH_ERR_TIMEOUT, '创建 Shell 会话失败');
      }
      this.shellReady = true;
    }
  }

  async exec(command: string, timeout?: number): Promise<string> {
    this.ensureShell();
    try {
      const timeoutMs = timeout !== undefined ? timeout : 10000;
      const output = await this.ssh!.executeSSHComm(command, timeoutMs);
      return output || '(无输出)';
    } catch (e) {
      const msg = JSON.stringify(e);
      console.error('DirectEngine exec failed:', msg);
      throw new SshError(SSH_ERR_TIMEOUT, `命令执行失败: ${msg}`);
    }
  }

  async openTerminal(cols?: number, rows?: number): Promise<void> {
    // libssh 不支持流式终端回调，降级到 Agent 模式
    if (!this.config) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');

    // 创建 Agent 降级引擎
    this.agentFallback = new AgentEngine();
    const agentConfig: ServerConfig = {
      host: this.config.host,
      port: 9527,
      username: this.config.username,
      agentToken: this.config.agentToken || 'zhizon-agent',
      authType: 'password',
      connectionMode: 'agent'
    };
    await this.agentFallback.connect(agentConfig);
    this.agentFallback.onTerminalData((data: string) => {
      if (this.terminalCallback) {
        this.terminalCallback(data);
      }
    });
    await this.agentFallback.openTerminal(cols, rows);
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    if (this.agentFallback) {
      this.agentFallback.sendTerminalInput(data);
    } else if (this.terminalCallback) {
      // 无 Agent 降级时，回显输入
      this.terminalCallback(data);
    }
  }

  closeTerminal(): void {
    this.stopTerminalPolling();
    if (this.agentFallback) {
      this.agentFallback.closeTerminal();
    }
    this.terminalCallback = null;
  }

  // 终端轮询模式（无 Agent 时的退化方案：周期执行命令获取输出）
  private startTerminalPolling(command: string): void {
    this.stopTerminalPolling();
    this.terminalPollingTimer = setInterval(async () => {
      try {
        const output = await this.exec(command, 3000);
        if (this.terminalCallback && output) {
          this.terminalCallback(output);
        }
      } catch (e) {
        // 轮询忽略错误
      }
    }, 2000);
  }

  private stopTerminalPolling(): void {
    if (this.terminalPollingTimer >= 0) {
      clearInterval(this.terminalPollingTimer);
      this.terminalPollingTimer = -1;
    }
  }

  // 心跳保活：定期 exec 简单命令检测连接状态
  private startKeepalive(): void {
    this.stopKeepalive();
    this.keepaliveTimer = setInterval(async () => {
      if (!this.connected || !this.ssh) return;
      try {
        await this.exec('echo keepalive', 5000);
      } catch (e) {
        console.warn('DirectEngine keepalive failed, marking disconnected');
        this.connected = false;
        this.stopKeepalive();
        if (this.terminalCallback) {
          this.terminalCallback('\n[连接已断开]\n');
        }
      }
    }, 30000); // 30 秒心跳
  }

  private stopKeepalive(): void {
    if (this.keepaliveTimer >= 0) {
      clearInterval(this.keepaliveTimer);
      this.keepaliveTimer = -1;
    }
  }

  async getMetrics(): Promise<ServerMetrics> {
    try {
      this.ensureShell();
      const cpuOutput = await this.ssh!.executeSSHComm(
        "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'", 5000);
      const memOutput = await this.ssh!.executeSSHComm(
        "free | awk '/Mem/{printf(\"%d\", $3/$2*100)}'", 5000);
      const diskOutput = await this.ssh!.executeSSHComm(
        "df / | awk 'NR==2{printf(\"%d\", $5)}' | tr -d '%'", 5000);
      return {
        cpu: parseFloat(cpuOutput.trim()) || 0,
        mem: parseFloat(memOutput.trim()) || 0,
        disk: parseFloat(diskOutput.trim()) || 0,
        netIn: 0,
        netOut: 0,
        load: 0,
        uptime: 0
      };
    } catch (e) {
      console.error('DirectEngine getMetrics failed:', JSON.stringify(e));
      return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
    }
  }

  async listFiles(path: string): Promise<FileItem[]> {
    if (!this.config) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    try {
      const keyPath = this.config.authType === 'key' ? (this.config.privateKeyPath || '') : '';
      // sftpRequestRead 每次独立创建新连接，返回逗号分隔的文件名列表
      const raw = await this.ssh!.sftpRequestRead(this.config.host, this.config.port, keyPath, path);
      if (!raw) return [];
      const names = raw.split(',').filter((n: string) => n.length > 0);
      const result: FileItem[] = [];
      for (const name of names) {
        const trimmed = name.trim();
        // 无法区分目录/文件，以 '/' 结尾的视为目录
        const isDir = trimmed.endsWith('/');
        result.push({
          name: isDir ? trimmed.substring(0, trimmed.length - 1) : trimmed,
          type: isDir ? 'dir' : 'file',
          size: 0,
          modified: '',
          perms: ''
        });
      }
      return result;
    } catch (e) {
      console.error('DirectEngine listFiles failed:', JSON.stringify(e));
      return [];
    }
  }

  // 直连模式不支持 SFTP 上传/下载，降级到 Agent
  async uploadFile(localPath: string, remotePath: string): Promise<void> {
    if (!this.config) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(localPath);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const base64Helper = new util.Base64Helper();
      const encoded: string = await base64Helper.encodeToString(new Uint8Array(buf));
      const ok = await agentClient.uploadFileBase64(remotePath, encoded);
      if (!ok) {
        throw new SshError(SSH_ERR_TIMEOUT, '文件上传失败');
      }
    } catch (e) {
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_TIMEOUT, `文件上传异常: ${JSON.stringify(e)}`);
    }
  }

  async downloadFile(remotePath: string, localPath: string): Promise<void> {
    if (!this.config) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
    try {
      const data = await agentClient.downloadFileBinary(remotePath);
      if (!data) {
        throw new SshError(SSH_ERR_TIMEOUT, '文件下载失败');
      }
      const file = fileIo.openSync(localPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
    } catch (e) {
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_TIMEOUT, `文件下载异常: ${JSON.stringify(e)}`);
    }
  }
}

// ========== SshService 门面（策略模式路由） ==========

interface EngineEntry {
  engine: SshEngine;
  mode: ConnectionMode;
}

export class SshService {
  private static engines: Map<string, EngineEntry> = new Map<string, EngineEntry>();

  private static toConfig(server: Server): ServerConfig {
    return {
      host: server.host,
      port: server.port,
      username: server.username,
      password: server.password || '',
      privateKeyContent: server.privateKeyContent,
      privateKeyPath: server.privateKeyPath,
      agentToken: server.agentToken || 'zhizon-agent',
      authType: server.authType,
      connectionMode: server.connectionMode || 'direct'
    };
  }

  private static getEngine(server: Server): SshEngine {
    const mode: ConnectionMode = server.connectionMode || 'direct';
    const existing = SshService.engines.get(server.id);
    if (existing && existing.mode === mode) {
      return existing.engine;
    }

    let engine: SshEngine;
    if (mode === 'direct') {
      engine = new DirectEngine();
    } else {
      engine = new AgentEngine();
    }
    SshService.engines.set(server.id, { engine: engine, mode: mode });
    return engine;
  }

  // 从加密存储加载凭据到内存态（列表页连接/测试前调用，凭据不落库）
  static async hydrateCredentials(server: Server): Promise<Server> {
    // 内存态已有明文凭据（表单测试/新建场景）则直接复用
    if (server.password || server.privateKeyContent) return server;
    try {
      const password = await DataRepository.getPassword(server.id);
      const keyContent = await DataRepository.getKeyContent(server.id);
      if (!password && !keyContent) return server;
      const hydrated: Server = {
        id: server.id,
        name: server.name,
        host: server.host,
        port: server.port,
        username: server.username,
        authType: server.authType,
        connectionMode: server.connectionMode,
        agentToken: server.agentToken,
        privateKeyPath: server.privateKeyPath,
        group: server.group,
        tags: server.tags,
        os: server.os,
        status: server.status,
        metrics: server.metrics,
        password: password || undefined,
        privateKeyContent: keyContent || undefined,
        lastConnected: server.lastConnected,
        createdAt: server.createdAt
      };
      return hydrated;
    } catch (e) {
      console.error('hydrateCredentials failed:', JSON.stringify(e));
      return server;
    }
  }

  // 测试连接
  static async testConnection(server: Server): Promise<boolean> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const config = SshService.toConfig(hydrated);
      const engine = SshService.getEngine(server);
      return await engine.connect(config);
    } catch (e) {
      console.error('SshService.testConnection failed:', JSON.stringify(e));
      return false;
    }
  }

  // 执行命令
  static async exec(server: Server, cmd: string): Promise<string> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return await engine.exec(cmd);
    } catch (e) {
      if (e instanceof SshError) {
        return `[${e.code}] ${e.message}`;
      }
      return `命令执行失败: ${JSON.stringify(e)}`;
    }
  }

  // 获取服务器指标
  static async getMetrics(server: Server): Promise<ServerMetrics> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return await engine.getMetrics();
    } catch (e) {
      return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
    }
  }

  // 列出文件
  static async listFiles(server: Server, dirPath: string = '/'): Promise<FileItem[]> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return await engine.listFiles(dirPath);
    } catch (e) {
      return [];
    }
  }

  // 获取终端初始输出
  static async getTerminalOutput(server: Server): Promise<string[]> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      const whoami = await engine.exec('whoami');
      const hostname = await engine.exec('hostname');
      const output = await engine.exec('uptime && free -h && echo "---" && df -h /');
      const prompt = `${whoami.trim()}@${hostname.trim()}:~# `;
      return [`连接成功: ${server.name} (${server.host})`, output, prompt];
    } catch (e) {
      const errMs = e instanceof SshError ? e.message : JSON.stringify(e);
      return [`无法连接到 ${server.name} (${server.host})`, `错误: ${errMs}`];
    }
  }

  // 开启终端会话
  static async openTerminal(server: Server, cols?: number, rows?: number): Promise<SshEngine> {
    const hydrated = await SshService.hydrateCredentials(server);
    const engine = SshService.getEngine(server);
    if (!engine.isConnected()) {
      await engine.connect(SshService.toConfig(hydrated));
    }
    await engine.openTerminal(cols, rows);
    return engine;
  }

  // 文件上传
  static async uploadFile(server: Server, localPath: string, remotePath: string): Promise<boolean> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      await engine.uploadFile(localPath, remotePath);
      return true;
    } catch (e) {
      console.error('SshService.uploadFile failed:', JSON.stringify(e));
      return false;
    }
  }

  // 文件下载
  static async downloadFile(server: Server, remotePath: string, localPath: string): Promise<boolean> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      await engine.downloadFile(remotePath, localPath);
      return true;
    } catch (e) {
      console.error('SshService.downloadFile failed:', JSON.stringify(e));
      return false;
    }
  }

  // 断开连接
  static async disconnect(server: Server): Promise<void> {
    const entry = SshService.engines.get(server.id);
    if (entry) {
      await entry.engine.disconnect();
      SshService.engines.delete(server.id);
    }
  }
}

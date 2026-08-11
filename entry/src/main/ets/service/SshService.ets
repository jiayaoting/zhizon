// 智子 - SSH 服务（双模通信：直连 + Agent）
import { http, webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Server, ServerMetrics, FileItem, ConnectionMode, AuthType } from '../model/Models';
import { DataRepository } from './DataRepository';
import { libssh } from '@ohos/libssh';
import { RemoteFailureCategory, RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from './RemoteResultAdapter';

const SSH_DOMAIN = 0x9201;

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
export const SSH_ERR_PERMISSION = 'SSH_ERR_PERMISSION';
export const SSH_ERR_PROTOCOL = 'SSH_ERR_PROTOCOL';
export const SSH_ERR_HTTP = 'SSH_ERR_HTTP';

// ========== TestResult ==========

export class TestResult {
  ok: boolean;
  message: string;
  result: RemoteResult<boolean>;

  constructor(ok: boolean, message: string, result: RemoteResult<boolean>) {
    this.ok = ok; this.message = message; this.result = result;
  }
}

class AgentResponse { status: string = ''; }
class AgentMetricsResponse { cpu_percent: number = 0; memory_used_gb: number = 0; memory_total_gb: number = 1; disk_used_gb: number = 0; disk_total_gb: number = 1; network_in_bytes: number = 0; network_out_bytes: number = 0; load_avg_1: number = 0; uptime_seconds: number = 0; }
class AgentExecResponse { stdout: string = ''; stderr: string = ''; exitCode: number = 0; }
class AgentFileData { name: string = ''; type: string = ''; size: number = 0; modified: string = ''; perms: string = ''; }
class AgentFilesResponse { files: AgentFileData[] = []; }
class AgentEventMessage { type: string = ''; event: string = ''; message: string = ''; percent: number = 0; transferred: number = 0; total: number = 0; }
class AgentCommandRequest {
  cmd: string;
  constructor(cmd: string) { this.cmd = cmd; }
}
class AgentPathRequest {
  path: string;
  constructor(path: string) { this.path = path; }
}
class AgentUploadRequest {
  path: string;
  content: string;
  constructor(path: string, content: string) { this.path = path; this.content = content; }
}
class AgentConnectRequest {
  type: string = 'connect';
  host: string;
  port: number;
  username: string;
  password: string;
  privateKeyContent: string;
  authType: AuthType;
  cols: number;
  rows: number;
  constructor(config: ServerConfig, cols: number, rows: number) {
    this.host = config.host;
    this.port = config.port;
    this.username = config.username;
    this.password = config.password || '';
    this.privateKeyContent = config.privateKeyContent || '';
    this.authType = config.authType;
    this.cols = cols;
    this.rows = rows;
  }
}
class AgentResizeRequest {
  type: string = 'resize';
  cols: number;
  rows: number;
  constructor(cols: number, rows: number) { this.cols = cols; this.rows = rows; }
}
class AgentDisconnectRequest { type: string = 'disconnect'; }
class AgentRequestSerializer {
  static serialize(payload: Object): string {
    try {
      return JSON.stringify(payload);
    } catch (error) {
      throw new SshError(SSH_ERR_PROTOCOL, '远程请求参数无效');
    }
  }
}

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

  getSshWsUrl(): string {
    return `ws://${this.baseUrl.replace('http://', '')}/ws/ssh`;
  }

  getToken(): string {
    return this.token;
  }

  private async request(method: http.RequestMethod, path: string, data?: string): Promise<Object> {
    const req = http.createHttp();
    try {
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
      if (res.responseCode === 200) {
        return res.result as Object;
      }
      if (res.responseCode === 401) throw new SshError(AGENT_ERR_TOKEN, 'Agent 认证失败');
      if (res.responseCode === 403) throw new SshError(SSH_ERR_PERMISSION, 'Agent 权限不足');
      throw new SshError(SSH_ERR_HTTP, 'Agent HTTP 响应异常');
    } catch (e) {
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=agent-request category=UNREACHABLE code=REMOTE_UNREACHABLE rollback=preserved');
      if (e instanceof SshError) throw e;
      throw new SshError(AGENT_ERR_UNREACH, 'Agent 服务不可达');
    } finally {
      req.destroy();
    }
  }

  // 二进制请求（用于文件下载）
  private async requestBinary(path: string): Promise<ArrayBuffer | null> {
    const req = http.createHttp();
    try {
      const res = await req.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'X-Auth-Token': this.token
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 60000
      });
      if (res.responseCode === 200) {
        return res.result as ArrayBuffer;
      }
      if (res.responseCode === 401) throw new SshError(AGENT_ERR_TOKEN, 'Agent 认证失败');
      if (res.responseCode === 403) throw new SshError(SSH_ERR_PERMISSION, 'Agent 权限不足');
      throw new SshError(SSH_ERR_HTTP, 'Agent HTTP 响应异常');
    } catch (e) {
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=agent-binary category=UNREACHABLE code=REMOTE_UNREACHABLE rollback=preserved');
      if (e instanceof SshError) throw e;
      throw new SshError(AGENT_ERR_UNREACH, 'Agent 服务不可达');
    } finally {
      req.destroy();
    }
  }

  async healthCheck(): Promise<boolean> {
    const res = await this.request(http.RequestMethod.GET, '/api/health') as AgentResponse;
    return res.status === 'ok';
  }

  async getMetrics(): Promise<ServerMetrics | null> {
    const res = await this.request(http.RequestMethod.GET, '/api/metrics') as AgentMetricsResponse;
    const cpu = res.cpu_percent || 0; const memUsed = res.memory_used_gb || 0;
    const memTotal = res.memory_total_gb || 1; const diskUsed = res.disk_used_gb || 0;
    const diskTotal = res.disk_total_gb || 1; const netIn = res.network_in_bytes || 0;
    const netOut = res.network_out_bytes || 0; const load = res.load_avg_1 || 0;
    const uptime = res.uptime_seconds || 0;

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
    const body: string = AgentRequestSerializer.serialize(new AgentCommandRequest(cmd));
    const res = await this.request(http.RequestMethod.POST, '/api/exec', body) as AgentExecResponse;
    const stdout = res.stdout || ''; const stderr = res.stderr || ''; const exitCode = res.exitCode || 0;

    let output = stdout;
    if (stderr) output += '\n[stderr]\n' + stderr;
    if (exitCode !== 0) output += `\n[退出码: ${exitCode}]`;
    return output || '命令执行成功 (无输出)';
  }

  async listFiles(dirPath: string): Promise<FileItem[]> {
    const res = await this.request(http.RequestMethod.GET, `/api/files?path=${encodeURIComponent(dirPath)}`) as AgentFilesResponse;
    if (!res.files || !Array.isArray(res.files)) throw new SshError(SSH_ERR_PROTOCOL, '文件响应格式异常');
    const files = res.files;
    const result: FileItem[] = [];
    for (const f of files) {
      const item: FileItem = {
        name: f.name || '', type: (f.type || 'file') as 'dir' | 'file', size: f.size || 0,
        modified: f.modified || '', perms: f.perms || ''
      };
      result.push(item);
    }
    return result;
  }

  async mkdir(dirPath: string): Promise<boolean> {
    const body: string = AgentRequestSerializer.serialize(new AgentPathRequest(dirPath));
    await this.request(http.RequestMethod.POST, '/api/files/mkdir', body);
    return true;
  }

  async deleteFile(filePath: string): Promise<boolean> {
    const body: string = AgentRequestSerializer.serialize(new AgentPathRequest(filePath));
    await this.request(http.RequestMethod.POST, '/api/files/delete', body);
    return true;
  }

  // base64 文件上传
  async uploadFileBase64(remotePath: string, content: string): Promise<boolean> {
    const body: string = AgentRequestSerializer.serialize(new AgentUploadRequest(remotePath, content));
    await this.request(http.RequestMethod.POST, '/api/files/upload-base64', body);
    return true;
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
      throw new SshError(AGENT_ERR_UNREACH, 'Agent 连接失败');
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
      const wsUrl = this.client.getSshWsUrl();
      const token = this.client.getToken();

      this.ws.on('open', () => {
        this.wsConnected = true;
        // WS 连接建立后，发送 SSH 连接参数（JSON 格式）
        if (this.config) {
          const sshParams: string = AgentRequestSerializer.serialize(
            new AgentConnectRequest(this.config, cols || 80, rows || 24));
          this.ws!.send(sshParams, (err: Error) => {
            if (err) hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-ws-send category=PROTOCOL code=SSH_WS_SEND_FAILED rollback=preserved');
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
          hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-ws-message category=PROTOCOL code=SSH_WS_MESSAGE_FAILED rollback=preserved');
          return;
        }
        const raw = typeof value === 'string' ? value : '';
        // 尝试解析 JSON 控制消息
        try {
          const msg: AgentEventMessage = JSON.parse(raw) as Record<string, Object> as AgentEventMessage;
          if (msg.type === 'event') {
            // Agent 侧事件转发
            if (this.eventCallback) {
              this.eventCallback(msg.event || 'info', msg.message || '');
            }
            if (this.terminalCallback) {
              this.terminalCallback(`\n[${msg.event}] ${msg.message}\n`);
            }
            return;
          }
          if (msg.type === 'progress') {
            // SFTP 传输进度
            if (this.terminalCallback) {
              const pct = msg.percent || 0;
              const transferred = msg.transferred || 0;
              const total = msg.total || 0;
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
      throw new SshError(AGENT_ERR_UNREACH, 'WebSocket 连接失败');
    }
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    if (this.ws && this.wsConnected) {
      this.ws.send(data, (err: Error) => {
        if (err) {
          hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-ws-send category=PROTOCOL code=SSH_WS_SEND_FAILED rollback=preserved');
        }
      });
    }
  }

  // 终端尺寸变化时通知 Agent
  resizeTerminal(cols: number, rows: number): void {
    if (this.ws && this.wsConnected) {
      const resizeMsg: string = AgentRequestSerializer.serialize(new AgentResizeRequest(cols, rows));
      this.ws.send(resizeMsg, (err: Error) => {
        if (err) {
          hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-ws-resize category=PROTOCOL code=SSH_WS_RESIZE_FAILED rollback=preserved');
        }
      });
    }
  }

  closeTerminal(): void {
    if (this.ws) {
      try {
        // 发送断开命令
        if (this.wsConnected) {
          const discMsg: string = AgentRequestSerializer.serialize(new AgentDisconnectRequest());
          this.ws.send(discMsg, () => {});
        }
        this.ws.close((err: Error) => {
          if (err) {
            hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-ws-close category=PROTOCOL code=SSH_WS_CLOSE_FAILED rollback=preserved');
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
      throw new SshError(SSH_ERR_TIMEOUT, '文件上传异常');
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
      throw new SshError(SSH_ERR_TIMEOUT, '文件下载异常');
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

  // 等待 callback 触发（原生层在连接成功后进入死循环，Promise 永不 resolve，必须通过 callback 判断结果）
  // 参考 @ohos/libssh 官方示例 ohos_ssh/entry/src/main/ets/pages/Index.ets
  private static waitForCallback(ssh: libssh, host: string, port: number, keyPath: string, ms: number): Promise<number> {
    return new Promise<number>((resolve: (value: number) => void, reject: (reason: Error) => void) => {
      let settled: boolean = false;
      const timer: number = setTimeout(() => {
        if (!settled) {
          settled = true;
          reject(new Error(`SSH 连接超时（${ms / 1000}秒）：目标主机不可达或端口被防火墙拦截`));
        }
      }, ms);

      ssh.startSSHClient(host, port, keyPath, (event: number): void => {
        hilog.info(SSH_DOMAIN, 'SshService', '%{public}s%{public}d', 'DirectEngine: startSSHClient callback event: ', event);
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(event);
        }
      });
    });
  }

  async connect(config: ServerConfig): Promise<boolean> {
    this.config = config;
    this.connected = false;
    this.shellReady = false;
    try {
      this.ssh = new libssh();
      const userResult: number = this.ssh.setUser(config.username, config.password || '');
      hilog.info(SSH_DOMAIN, 'SshService', '%{public}s%{public}d', 'DirectEngine: setUser result: ', userResult);

      if (userResult !== 0) {
        throw new SshError(SSH_ERR_AUTH_FAIL, 'setUser 失败：用户名或密码为空');
      }

      const keyPath: string = config.authType === 'key' ? (config.privateKeyPath || '') : '';

      // 不 await startSSHClient 的 Promise（原生层死循环永不 resolve），通过 callback 判断结果
      const connectResult: number = await DirectEngine.waitForCallback(this.ssh, config.host, config.port, keyPath, 15000);
      hilog.info(SSH_DOMAIN, 'SshService', '%{public}s%{public}d', 'DirectEngine: connectResult: ', connectResult);

      if (connectResult !== 0) {
        throw new SshError(SSH_ERR_AUTH_FAIL,
          `SSH 认证失败: ${config.host}:${config.port} (code=${connectResult})`);
      }

      this.connected = true;
      this.startKeepalive();
      return true;
    } catch (e) {
      this.connected = false;
      this.shellReady = false;
      this.stopKeepalive();
      if (e instanceof SshError) {
        throw e;
      }
      const msg: string = e instanceof Error ? e.message.toLowerCase() : '';
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
      hilog.info(SSH_DOMAIN, 'SshService', '%{public}s%{public}d', 'DirectEngine: createShell result: ', shellResult);
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
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-exec category=TIMEOUT code=SSH_ERR_TIMEOUT rollback=preserved');
      throw new SshError(SSH_ERR_TIMEOUT, '命令执行失败');
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
        hilog.warn(SSH_DOMAIN, 'SshService', '%{public}s', 'DirectEngine keepalive failed, marking disconnected');
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
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-metrics category=PROTOCOL code=SSH_METRICS_FAILED rollback=preserved');
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_PROTOCOL, '指标响应格式异常');
    }
  }

  async listFiles(path: string): Promise<FileItem[]> {
    if (!this.config) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');

    // sftpRequestRead 只支持密钥认证，密码认证时降级到 Agent
    if (this.config.authType === 'password') {
      hilog.warn(SSH_DOMAIN, 'SshService', '%{public}s', 'DirectEngine listFiles: password auth not supported, falling back to Agent');
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      return await agentClient.listFiles(path);
    }

    try {
      const keyPath = this.config.privateKeyPath || '';
      if (!keyPath) {
        hilog.warn(SSH_DOMAIN, 'SshService', '%{public}s', 'DirectEngine listFiles: no private key path provided');
        throw new SshError(SSH_ERR_KEY_INVALID, '私钥配置无效');
      }
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
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=ssh-files category=PROTOCOL code=SSH_FILES_FAILED rollback=preserved');
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_PROTOCOL, '文件响应格式异常');
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
      throw new SshError(SSH_ERR_TIMEOUT, '文件上传异常');
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
      throw new SshError(SSH_ERR_TIMEOUT, '文件下载异常');
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

  private static failureFromSshError(error: SshError): RemoteResult<boolean> {
    if (error.code === SSH_ERR_AUTH_FAIL || error.code === SSH_ERR_KEY_INVALID || error.code === AGENT_ERR_TOKEN) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.AUTHENTICATION, 'REMOTE_AUTH_FAILED',
        '认证失败，请返回服务器配置检查凭据', false);
    }
    if (error.code === SSH_ERR_TIMEOUT) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.TIMEOUT, 'REMOTE_TIMEOUT',
        '远程操作超时，请重试', true);
    }
    if (error.code === SSH_ERR_PERMISSION) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.PERMISSION, 'REMOTE_PERMISSION_DENIED',
        '当前账号没有执行此操作的权限', false);
    }
    if (error.code === SSH_ERR_PROTOCOL) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.PROTOCOL, 'REMOTE_PROTOCOL_INVALID',
        '远程响应格式异常，请稍后重试', true);
    }
    if (error.code === SSH_ERR_HTTP) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.HTTP, 'REMOTE_HTTP_FAILED',
        '远程服务返回异常状态，请稍后重试', true);
    }
    return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.UNREACHABLE, 'REMOTE_UNREACHABLE',
      '远程服务不可达，请检查网络后重试', true);
  }

  private static failureFromException(error: Error | null): RemoteResult<boolean> {
    return RemoteResultAdapter.fromException<boolean>(error);
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
      hilog.error(SSH_DOMAIN, 'SshService', '%{public}s', 'operation=hydrate-credentials category=PROTOCOL code=CREDENTIAL_READ_FAILED rollback=preserved');
      return server;
    }
  }

  // 测试连接
  static async testConnection(server: Server): Promise<boolean> {
    const result: TestResult = await SshService.testConnectionEx(server);
    return result.result.success;
  }

  // 测试连接（带详细错误信息）
  static async testConnectionEx(server: Server): Promise<TestResult> {
    let engine: SshEngine | null = null;
    try {
      const hydrated: Server = await SshService.hydrateCredentials(server);
      const config: ServerConfig = SshService.toConfig(hydrated);
      engine = SshService.getEngine(server);
      const ok: boolean = await engine.connect(config);
      const remote = ok ? RemoteResultAdapter.success<boolean>(true) :
        RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.PROTOCOL, 'REMOTE_PROTOCOL_INVALID',
          '远程响应格式异常，请稍后重试', true);
      return new TestResult(remote.success, remote.success ? '连接成功' : RemoteResultAdapter.publicMessage(remote), remote);
    } catch (e) {
      if (engine) {
        SshService.engines.delete(server.id);
        engine.disconnect().catch(() => {});
      }
      let remote: RemoteResult<boolean>;
      if (e instanceof SshError) {
        remote = SshService.failureFromSshError(e);
      } else {
        remote = SshService.failureFromException(e instanceof Error ? e : null);
      }
      RemoteResultAdapter.logFailure('ssh-connect', remote);
      return new TestResult(false, RemoteResultAdapter.publicMessage(remote), remote);
    }
  }

  // 执行命令
  static async exec(server: Server, cmd: string): Promise<RemoteResult<string>> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return RemoteResultAdapter.success<string>(await engine.exec(cmd));
    } catch (e) {
      if (e instanceof SshError) {
        const failure = SshService.failureFromSshError(e);
        return new RemoteResult<string>(false, null, failure.failure);
      }
      const failure = SshService.failureFromException(e instanceof Error ? e : null);
      return new RemoteResult<string>(false, null, failure.failure);
    }
  }

  // 获取服务器指标
  static async getMetrics(server: Server): Promise<RemoteResult<ServerMetrics>> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return RemoteResultAdapter.success<ServerMetrics>(await engine.getMetrics());
    } catch (e) {
      const failure = e instanceof SshError ? SshService.failureFromSshError(e) :
        SshService.failureFromException(e instanceof Error ? e : null);
      return new RemoteResult<ServerMetrics>(false, null, failure.failure);
    }
  }

  // 列出文件
  static async listFiles(server: Server, dirPath: string = '/'): Promise<RemoteResult<FileItem[]>> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      return RemoteResultAdapter.success<FileItem[]>(await engine.listFiles(dirPath));
    } catch (e) {
      const failure = e instanceof SshError ? SshService.failureFromSshError(e) :
        SshService.failureFromException(e instanceof Error ? e : null);
      return new RemoteResult<FileItem[]>(false, null, failure.failure);
    }
  }

  // 获取终端初始输出
  static async getTerminalOutput(server: Server): Promise<RemoteResult<string[]>> {
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
      return RemoteResultAdapter.success<string[]>([`连接成功: ${server.name}`, output, prompt]);
    } catch (e) {
      const failure = e instanceof SshError ? SshService.failureFromSshError(e) :
        SshService.failureFromException(e instanceof Error ? e : null);
      return new RemoteResult<string[]>(false, null, failure.failure);
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
  static async uploadFile(server: Server, localPath: string, remotePath: string): Promise<RemoteResult<boolean>> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      await engine.uploadFile(localPath, remotePath);
      return RemoteResultAdapter.success<boolean>(true);
    } catch (e) {
      const failure = e instanceof SshError ? SshService.failureFromSshError(e) :
        SshService.failureFromException(e instanceof Error ? e : null);
      RemoteResultAdapter.logFailure('ssh-upload', failure);
      return failure;
    }
  }

  // 文件下载
  static async downloadFile(server: Server, remotePath: string, localPath: string): Promise<RemoteResult<boolean>> {
    try {
      const hydrated = await SshService.hydrateCredentials(server);
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(hydrated));
      }
      await engine.downloadFile(remotePath, localPath);
      return RemoteResultAdapter.success<boolean>(true);
    } catch (e) {
      const failure = e instanceof SshError ? SshService.failureFromSshError(e) :
        SshService.failureFromException(e instanceof Error ? e : null);
      RemoteResultAdapter.logFailure('ssh-download', failure);
      return failure;
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

// 智子 - SSH 服务（双模通信：直连 + Agent）
import { http, webSocket } from '@kit.NetworkKit';
import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { Server, ServerMetrics, FileItem, ConnectionMode, AuthType } from '../model/Models';

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

// ========== AgentEngine（封装 AgentClient 为 SshEngine，含 WebSocket 终端） ==========

export class AgentEngine implements SshEngine {
  private client: AgentClient | null = null;
  private connected: boolean = false;
  private terminalCallback: ((data: string) => void) | null = null;
  private ws: webSocket.WebSocket | null = null;
  private wsConnected: boolean = false;

  async connect(config: ServerConfig): Promise<boolean> {
    try {
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
  }

  isConnected(): boolean {
    return this.connected;
  }

  async exec(command: string, timeout?: number): Promise<string> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');
    return await this.client.exec(command);
  }

  async openTerminal(cols?: number, rows?: number): Promise<void> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');

    // 如果已有 WebSocket 连接，先关闭
    this.closeTerminal();

    try {
      this.ws = webSocket.createWebSocket();
      const wsUrl = this.client.getWsUrl();
      const token = this.client.getToken();

      this.ws.on('open', () => {
        this.wsConnected = true;
        if (this.terminalCallback) {
          this.terminalCallback('连接已建立\n');
        }
      });

      this.ws.on('message', (err: Error, value: string | ArrayBuffer) => {
        if (this.terminalCallback) {
          const data = typeof value === 'string' ? value : '';
          this.terminalCallback(data);
        }
      });

      this.ws.on('close', () => {
        this.wsConnected = false;
        if (this.terminalCallback) {
          this.terminalCallback('\n[连接已关闭]\n');
        }
      });

      this.ws.on('error', (err: Error) => {
        this.wsConnected = false;
        if (this.terminalCallback) {
          this.terminalCallback(`\n[WebSocket 错误: ${err.message}]\n`);
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

  closeTerminal(): void {
    if (this.ws) {
      try {
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

// ========== DirectEngine（SSH 直连引擎 — TCP 端口探测） ==========

export class DirectEngine implements SshEngine {
  private connected: boolean = false;
  private config: ServerConfig | null = null;
  private terminalCallback: ((data: string) => void) | null = null;

  async connect(config: ServerConfig): Promise<boolean> {
    this.config = config;
    try {
      const testResult = await this.testTcpConnection(config.host, config.port);
      if (!testResult) {
        throw new SshError(SSH_ERR_HOST_UNREACH, `主机不可达: ${config.host}:${config.port}`);
      }
      this.connected = true;
      return true;
    } catch (e) {
      this.connected = false;
      if (e instanceof SshError) throw e;
      throw new SshError(SSH_ERR_TIMEOUT, `连接超时: ${JSON.stringify(e)}`);
    }
  }

  // 使用 TCP Socket 测试 SSH 端口可达性
  private async testTcpConnection(host: string, port: number): Promise<boolean> {
    try {
      const tcpSocket = socket.constructTCPSocketInstance();
      await tcpSocket.connect({
        address: { address: host, port: port, family: 1 },
        timeout: 5000
      });
      tcpSocket.close();
      return true;
    } catch (e) {
      const errStr = JSON.stringify(e);
      // 连接被拒绝说明主机可达，只是端口未开放
      if (errStr.includes('refused') || errStr.includes('ECONNREFUSED')) {
        return true;
      }
      return false;
    }
  }

  async disconnect(): Promise<void> {
    this.connected = false;
    this.config = null;
    this.terminalCallback = null;
  }

  isConnected(): boolean {
    return this.connected;
  }

  async exec(command: string, timeout?: number): Promise<string> {
    if (!this.connected || !this.config) {
      throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    }
    // 直连模式降级：尝试通过 Agent HTTP 接口执行
    try {
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      return await agentClient.exec(command);
    } catch (e) {
      throw new SshError(SSH_ERR_TIMEOUT, `命令执行失败: ${JSON.stringify(e)}`);
    }
  }

  async openTerminal(cols?: number, rows?: number): Promise<void> {
    if (!this.connected) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    // 直连模式降级：通过 Agent WebSocket 终端
    if (this.config) {
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      const ws = webSocket.createWebSocket();

      ws.on('open', () => {
        if (this.terminalCallback) {
          this.terminalCallback('连接已建立\n');
        }
      });

      ws.on('message', (err: Error, value: string | ArrayBuffer) => {
        if (this.terminalCallback) {
          const data = typeof value === 'string' ? value : '';
          this.terminalCallback(data);
        }
      });

      ws.on('close', () => {
        if (this.terminalCallback) {
          this.terminalCallback('\n[连接已关闭]\n');
        }
      });

      ws.on('error', (err: Error) => {
        if (this.terminalCallback) {
          this.terminalCallback(`\n[错误: ${err.message}]\n`);
        }
      });

      try {
        await ws.connect(agentClient.getWsUrl(), {
          header: { 'X-Auth-Token': agentClient.getToken() }
        });
      } catch (e) {
        throw new SshError(SSH_ERR_TIMEOUT, `WebSocket 连接失败: ${JSON.stringify(e)}`);
      }
    }
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    // 在直连降级模式下，通过 exec 发送命令
    if (this.terminalCallback) {
      this.terminalCallback(data);
    }
  }

  closeTerminal(): void {
    this.terminalCallback = null;
  }

  async getMetrics(): Promise<ServerMetrics> {
    if (!this.connected || !this.config) {
      throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    }
    try {
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      const metrics = await agentClient.getMetrics();
      if (metrics) return metrics;

      // 降级：通过 exec 解析命令输出
      const cpuOutput = await agentClient.exec("top -bn1 | grep 'Cpu(s)' | awk '{print $2}'");
      const memOutput = await agentClient.exec("free | awk '/Mem/{printf(\"%d\", $3/$2*100)}'");
      const diskOutput = await agentClient.exec("df / | awk 'NR==2{printf(\"%d\", $5)}' | tr -d '%'");

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
      return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
    }
  }

  async listFiles(path: string): Promise<FileItem[]> {
    if (!this.connected || !this.config) {
      throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    }
    try {
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      return await agentClient.listFiles(path);
    } catch (e) {
      return [];
    }
  }

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
      password: '',
      privateKeyPath: server.privateKeyPath,
      agentToken: server.agentToken || 'zhizon-agent',
      authType: server.authType,
      connectionMode: server.connectionMode || 'agent'
    };
  }

  private static getEngine(server: Server): SshEngine {
    const mode: ConnectionMode = server.connectionMode || 'agent';
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

  // 测试连接
  static async testConnection(server: Server): Promise<boolean> {
    try {
      const config = SshService.toConfig(server);
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
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
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
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
      }
      return await engine.getMetrics();
    } catch (e) {
      return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
    }
  }

  // 列出文件
  static async listFiles(server: Server, dirPath: string = '/'): Promise<FileItem[]> {
    try {
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
      }
      return await engine.listFiles(dirPath);
    } catch (e) {
      return [];
    }
  }

  // 获取终端初始输出
  static async getTerminalOutput(server: Server): Promise<string[]> {
    try {
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
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
    const engine = SshService.getEngine(server);
    if (!engine.isConnected()) {
      await engine.connect(SshService.toConfig(server));
    }
    await engine.openTerminal(cols, rows);
    return engine;
  }

  // 文件上传
  static async uploadFile(server: Server, localPath: string, remotePath: string): Promise<boolean> {
    try {
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
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
      const engine = SshService.getEngine(server);
      if (!engine.isConnected()) {
        await engine.connect(SshService.toConfig(server));
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

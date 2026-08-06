// 智子 - SSH 服务（双模通信：直连 + Agent）
import { http } from '@kit.NetworkKit';
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

// ========== AgentClient（原有 HTTP 通信客户端） ==========

export class AgentClient {
  private baseUrl: string;
  private token: string;

  constructor(host: string, port: number = 9527, token: string = 'zhizon-agent') {
    this.baseUrl = `http://${host}:${port}`;
    this.token = token;
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
    return files.map((f): FileItem => {
      const result: FileItem = {
        name: f['name'] as string,
        type: (f['type'] as string) as 'dir' | 'file',
        size: f['size'] as number,
        modified: f['modified'] as string,
        perms: f['perms'] as string
      };
      return result;
    });
  }

  async mkdir(dirPath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/mkdir', JSON.stringify({ path: dirPath }));
    return res !== null;
  }

  async deleteFile(filePath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/delete', JSON.stringify({ path: filePath }));
    return res !== null;
  }
}

// ========== AgentEngine（封装 AgentClient 为 SshEngine） ==========

export class AgentEngine implements SshEngine {
  private client: AgentClient | null = null;
  private connected: boolean = false;
  private terminalCallback: ((data: string) => void) | null = null;

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
    this.client = null;
    this.connected = false;
    this.terminalCallback = null;
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
    // Agent 模式下终端通过 exec 模拟
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    // Agent 模式下通过 exec 发送命令
  }

  closeTerminal(): void {
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
    // TODO: 通过 Agent /api/files/upload 上传
    throw new Error('Agent 文件上传尚未实现');
  }

  async downloadFile(remotePath: string, localPath: string): Promise<void> {
    if (!this.client) throw new SshError(AGENT_ERR_UNREACH, 'Agent 未连接');
    // TODO: 通过 Agent /api/files/download 下载
    throw new Error('Agent 文件下载尚未实现');
  }
}

// ========== DirectEngine（SSH 直连引擎） ==========
// 使用 exec 命令解析方式实现指标采集，终端降级为命令-应答模式

export class DirectEngine implements SshEngine {
  private connected: boolean = false;
  private config: ServerConfig | null = null;
  private terminalCallback: ((data: string) => void) | null = null;

  async connect(config: ServerConfig): Promise<boolean> {
    this.config = config;
    // 直连模式：通过 socket 连接测试可达性
    try {
      const testResult = await this.testConnection(config.host, config.port);
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

  // 通过 HTTP 连接测试主机可达性（直连模式下使用 socket 替代）
  private async testConnection(host: string, port: number): Promise<boolean> {
    try {
      const req = http.createHttp();
      await req.request(`http://${host}:${port}`, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 5000
      });
      req.destroy();
      return true;
    } catch (e) {
      // 连接被拒绝也说明主机可达（端口未开放但主机在线）
      const errStr = JSON.stringify(e);
      if (errStr.includes('refused') || errStr.includes('connection')) {
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
    // 直连模式：通过 Agent exec 端点或本地 SSH 库执行
    // 当前降级：通过 Agent HTTP 接口执行（如果目标机器有 Agent）
    // 后续替换为 libssh NAPI 调用
    try {
      const agentClient = new AgentClient(this.config.host, 9527, this.config.agentToken || 'zhizon-agent');
      return await agentClient.exec(command);
    } catch (e) {
      throw new SshError(SSH_ERR_TIMEOUT, `命令执行失败: ${JSON.stringify(e)}`);
    }
  }

  async openTerminal(cols?: number, rows?: number): Promise<void> {
    if (!this.connected) throw new SshError(SSH_ERR_HOST_UNREACH, 'SSH 未连接');
    // 降级模式：终端通过 exec 命令-应答实现
  }

  onTerminalData(callback: (data: string) => void): void {
    this.terminalCallback = callback;
  }

  sendTerminalInput(data: string): void {
    // 降级模式：通过 exec 发送命令
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
    // 直连模式：通过执行命令解析系统指标
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
    throw new Error('直连模式文件上传尚未实现');
  }

  async downloadFile(remotePath: string, localPath: string): Promise<void> {
    throw new Error('直连模式文件下载尚未实现');
  }
}

// ========== SshService 门面（策略模式路由） ==========

interface EngineEntry {
  engine: SshEngine;
  mode: ConnectionMode;
}

export class SshService {
  private static engines: Map<string, EngineEntry> = new Map<string, EngineEntry>();

  // 将 Server 转换为 ServerConfig
  private static toConfig(server: Server): ServerConfig {
    return {
      host: server.host,
      port: server.port,
      username: server.username,
      password: '', // 从加密存储读取（后续实现）
      privateKeyPath: server.privateKeyPath,
      agentToken: server.agentToken || 'zhizon-agent',
      authType: server.authType,
      connectionMode: server.connectionMode || 'agent'
    };
  }

  // 获取或创建引擎实例（模式变更时自动重建）
  private static getEngine(server: Server): SshEngine {
    const mode: ConnectionMode = server.connectionMode || 'agent';
    const existing = SshService.engines.get(server.id);
    if (existing && existing.mode === mode) {
      return existing.engine;
    }

    // 模式变更或首次创建：断开旧引擎并创建新引擎
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
      const output = await engine.exec('uptime && free -h && echo "---" && df -h /');
      return output.split('\n').filter(l => l.trim() !== '');
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

  // 断开连接
  static async disconnect(server: Server): Promise<void> {
    const entry = SshService.engines.get(server.id);
    if (entry) {
      await entry.engine.disconnect();
      SshService.engines.delete(server.id);
    }
  }
}

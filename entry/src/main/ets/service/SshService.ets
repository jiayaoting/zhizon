// 智子 - SSH 服务（通过 Agent 通信）
import { http } from '@kit.NetworkKit';
import { webSocket } from '@kit.NetworkKit';
import { Server, ServerMetrics, FileItem } from '../model/Models';

// Agent 通信客户端
export class AgentClient {
  private baseUrl: string;
  private token: string;

  constructor(host: string, port: number = 9527, token: string = 'zhizon-agent') {
    this.baseUrl = `http://${host}:${port}`;
    this.token = token;
  }

  // 通用 HTTP 请求
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

  // 健康检查
  async healthCheck(): Promise<boolean> {
    const res = await this.request(http.RequestMethod.GET, '/api/health');
    return res !== null && res['status'] === 'ok';
  }

  // 获取系统指标
  async getMetrics(): Promise<ServerMetrics | null> {
    const res = await this.request(http.RequestMethod.GET, '/api/metrics');
    if (!res) return null;

    const cpu = (res['cpu_percent'] as number) || 0;
    const mem = res['memory'] as Record<string, Object>;
    const disk = res['disk'] as Record<string, Object>;
    const net = res['network'] as Record<string, Object>;
    const load = (res['load_avg'] as number) || 0;

    const memUsed = (mem['used'] as number) || 0;
    const memTotal = (mem['total'] as number) || 1;
    const diskUsed = (disk['used'] as number) || 0;
    const diskTotal = (disk['total'] as number) || 1;

    return {
      cpu: Math.round(cpu),
      mem: Math.round((memUsed / memTotal) * 100),
      disk: Math.round((diskUsed / diskTotal) * 100),
      netIn: (net['bytes_recv'] as number) || 0,
      netOut: (net['bytes_sent'] as number) || 0,
      load: load,
      uptime: (res['uptime_seconds'] as number) || 0
    };
  }

  // 执行命令
  async exec(cmd: string): Promise<string> {
    const res = await this.request(http.RequestMethod.POST, '/api/exec', JSON.stringify({ cmd: cmd }));
    if (!res) return '命令执行失败：无法连接到 Agent';

    const stdout = (res['stdout'] as string) || '';
    const stderr = (res['stderr'] as string) || '';
    const exitCode = (res['exit_code'] as number) || 0;

    let output = stdout;
    if (stderr) output += '\n[stderr]\n' + stderr;
    if (exitCode !== 0) output += `\n[退出码: ${exitCode}]`;
    return output || '命令执行成功 (无输出)';
  }

  // 列出文件
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

  // 创建目录
  async mkdir(dirPath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/mkdir', JSON.stringify({ path: dirPath }));
    return res !== null;
  }

  // 删除文件/目录
  async deleteFile(filePath: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, '/api/files/delete', JSON.stringify({ path: filePath }));
    return res !== null;
  }
}

// SSH 服务门面
export class SshService {
  // 测试连接（通过 Agent 健康检查）
  static async testConnection(server: Server): Promise<boolean> {
    try {
      const client = new AgentClient(server.host, 9527);
      return await client.healthCheck();
    } catch (e) {
      return false;
    }
  }

  // 执行命令
  static async exec(server: Server, cmd: string): Promise<string> {
    const client = new AgentClient(server.host, 9527);
    return await client.exec(cmd);
  }

  // 获取服务器指标
  static async getMetrics(server: Server): Promise<ServerMetrics> {
    const client = new AgentClient(server.host, 9527);
    const metrics = await client.getMetrics();
    if (metrics) return metrics;

    // 返回空指标
    return { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 };
  }

  // 列出文件
  static async listFiles(server: Server, dirPath: string = '/'): Promise<FileItem[]> {
    const client = new AgentClient(server.host, 9527);
    return await client.listFiles(dirPath);
  }

  // 获取终端初始输出（通过执行 uptime 命令）
  static async getTerminalOutput(server: Server): Promise<string[]> {
    try {
      const client = new AgentClient(server.host, 9527);
      const output = await client.exec('uptime && free -h && echo "---" && df -h /');
      return output.split('\n').filter(l => l.trim() !== '');
    } catch (e) {
      return [`无法连接到 ${server.name} (${server.host})`, '请确保已安装并启动 zhizon-agent'];
    }
  }
}
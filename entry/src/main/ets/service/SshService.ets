// 智子 - SSH 服务（MVP 占位，真实 SSH 协议层在后续版本用 NAPI+libssh2 实现）

import { Server } from '../model/Models';
import { MockData } from './MockData';

export class SshService {
  // 测试连接（占位）
  static async testConnection(server: Server): Promise<boolean> {
    // 真实实现：通过 NAPI 调用 libssh2 进行握手
    await new Promise(r => setTimeout(r, 500));
    return server.status !== 'offline';
  }

  // 执行命令（占位）
  static async exec(server: Server, cmd: string): Promise<string> {
    await new Promise(r => setTimeout(r, 300));
    // 占位返回
    return `[${server.name}] 执行: ${cmd}\n命令已完成 (退出码 0)`;
  }

  // 获取终端初始输出（占位）
  static getTerminalOutput(server: Server): string[] {
    return MockData.terminalLines.map(line =>
      line.replace('prod-web-01', server.name)
    );
  }

  // 获取服务器资源指标（占位，真实实现通过 SSH 执行 top/free/df 解析）
  static async getMetrics(server: Server): Promise<Server['metrics']> {
    await new Promise(r => setTimeout(r, 200));
    return server.metrics;
  }
}

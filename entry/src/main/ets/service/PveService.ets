// 智子 - PVE 服务（对接 Proxmox VE REST API）
// API 文档: https://pve.proxmox.com/wiki/Proxmox_VE_API
// MVP 阶段使用 Mock 数据，真实实现用 @ohos.net.http 调用 REST API

import { PveCluster, PveNode, Vm, Storage, PveTask, Snapshot } from '../model/Models';
import { DataRepository } from './DataRepository';
// 真实接入 PVE API 时取消下方注释
// import { http } from '@kit.NetworkKit';

// PVE API 客户端
export class PveClient {
  private baseUrl: string;
  private ticket?: string;
  private csrfToken?: string;

  constructor(cluster: PveCluster) {
    this.baseUrl = `https://${cluster.host}:${cluster.port}/api2/json`;
  }

  // 登录获取 Ticket
  // POST /access/ticket
  // Body: username=root@pam&password=xxx
  async login(username: string, password: string): Promise<void> {
    // 真实实现：
    // const res = await http.sendRequest(`${this.baseUrl}/access/ticket`, {
    //   method: http.RequestMethod.POST,
    //   extraData: `username=${username}&password=${password}`,
    //   header: { 'Content-Type': 'application/x-www-form-urlencoded' }
    // });
    // const data = res.result as Record<string, Object>;
    // this.ticket = data.ticket as string;
    // this.csrfToken = data.CSRFPreventionToken as string;
    this.ticket = 'mock-ticket';
    this.csrfToken = 'mock-csrf';
  }

  // 统一请求
  private async request(method: string, path: string, data?: Record<string, Object>): Promise<Record<string, Object>> {
    // 真实实现：
    // const res = await http.sendRequest(`${this.baseUrl}${path}`, {
    //   method,
    //   header: { Cookie: `PVEAuthCookie=${this.ticket}` },
    //   extraData: data
    // });
    // return res.result as Record<string, Object>;
    return {};
  }

  // 获取集群节点列表 GET /nodes
  async getNodes(): Promise<PveNode[]> {
    return [];
  }

  // 获取 VM 列表 GET /nodes/{node}/qemu
  async getVms(node: string): Promise<Vm[]> {
    return [];
  }

  // VM 操作 POST /nodes/{node}/qemu/{vmid}/status/{action}
  // action: start | shutdown | stop | reboot | suspend | resume
  async vmAction(node: string, vmid: number, action: string): Promise<void> {
    await this.request('POST', `/nodes/${node}/qemu/${vmid}/status/${action}`);
  }

  // 创建快照 POST /nodes/{node}/qemu/{vmid}/snapshot
  async createSnapshot(node: string, vmid: number, name: string): Promise<void> {
    await this.request('POST', `/nodes/${node}/qemu/${vmid}/snapshot`, { name });
  }
}

// PVE 服务门面（MVP 阶段返回 Mock 数据）
export class PveService {
  static getClusters(): PveCluster[] {
    return DataRepository.getPveClusters();
  }

  static getCluster(id: string): PveCluster | undefined {
    return DataRepository.getPveCluster(id);
  }

  static getVms(node?: string): Vm[] {
    return DataRepository.getVms(node);
  }

  static getVm(vmid: number): Vm | undefined {
    return DataRepository.getVm(vmid);
  }

  static getStorages(node?: string): Storage[] {
    return DataRepository.getStorages(node);
  }

  static getTasks(): PveTask[] {
    return DataRepository.getTasks();
  }

  static getSnapshots(vmid?: number): Snapshot[] {
    return DataRepository.getSnapshots(vmid);
  }

  // VM 操作（占位）
  static async vmAction(vmid: number, action: string): Promise<boolean> {
    await new Promise(r => setTimeout(r, 500));
    return true;
  }
}

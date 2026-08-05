// 智子 - PVE 服务（对接 Proxmox VE REST API）
// API 文档: https://pve.proxmox.com/wiki/Proxmox_VE_API

import { http } from '@kit.NetworkKit';
import { PveCluster, PveNode, Vm, Storage, PveTask, Snapshot } from '../model/Models';
import { DataRepository } from './DataRepository';

// PVE API 客户端
export class PveClient {
  private baseUrl: string;
  private ticket: string = '';
  private csrfToken: string = '';
  private verifyTls: boolean;

  constructor(host: string, port: number, verifyTls: boolean = false) {
    this.baseUrl = `https://${host}:${port}/api2/json`;
    this.verifyTls = verifyTls;
  }

  // 登录获取 Ticket
  // POST /access/ticket
  async login(username: string, password: string): Promise<boolean> {
    try {
      const req = http.createHttp();
      const body = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
      const res = await req.request(`${this.baseUrl}/access/ticket`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        extraData: body,
        expectDataType: http.HttpDataType.OBJECT,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (res.responseCode === 200) {
        const data = res.result as Record<string, Object>;
        this.ticket = (data['data'] as Record<string, Object>)['ticket'] as string;
        this.csrfToken = (data['data'] as Record<string, Object>)['CSRFPreventionToken'] as string;
        req.destroy();
        return true;
      }
      req.destroy();
      return false;
    } catch (e) {
      console.error('PVE login failed:', JSON.stringify(e));
      return false;
    }
  }

  // 登录获取 API Token
  async loginWithToken(tokenId: string, secret: string): Promise<boolean> {
    this.ticket = `PVEAPIToken=${tokenId}=${secret}`;
    return true;
  }

  // 统一请求方法
  private async request(method: http.RequestMethod, path: string, data?: Record<string, Object>): Promise<Record<string, Object> | null> {
    try {
      const req = http.createHttp();
      const headers: Record<string, string> = {};
      if (this.ticket.startsWith('PVEAPIToken=')) {
        headers['Authorization'] = this.ticket;
      } else {
        headers['Cookie'] = `PVEAuthCookie=${this.ticket}`;
      }
      if (this.csrfToken && method !== http.RequestMethod.GET) {
        headers['CSRFPreventionToken'] = this.csrfToken;
      }

      const res = await req.request(`${this.baseUrl}${path}`, {
        method: method,
        header: headers,
        extraData: data ? JSON.stringify(data) : undefined,
        expectDataType: http.HttpDataType.OBJECT,
        connectTimeout: 15000,
        readTimeout: 15000
      });

      req.destroy();
      if (res.responseCode === 200) {
        return res.result as Record<string, Object>;
      }
      return null;
    } catch (e) {
      console.error(`PVE request failed: ${method} ${path}`, JSON.stringify(e));
      return null;
    }
  }

  // 获取集群节点列表 GET /nodes
  async getNodes(): Promise<PveNode[]> {
    const res = await this.request(http.RequestMethod.GET, '/nodes');
    if (!res || !res['data']) return [];

    const nodesData = res['data'] as Array<Record<string, Object>>;
    const nodes: PveNode[] = [];

    for (const n of nodesData) {
      const nodeName = n['node'] as string;
      // 获取节点状态
      const statusRes = await this.request(http.RequestMethod.GET, `/nodes/${nodeName}/status`);
      const statusData = (statusRes && statusRes['data']) ? statusRes['data'] as Record<string, Object> : null;

      nodes.push({
        id: nodeName,
        node: nodeName,
        status: (n['status'] === 'online' ? 'online' : 'offline') as 'online' | 'offline',
        cpu: statusData ? (statusData['cpu'] as number) || 0 : 0,
        maxcpu: statusData ? (statusData['cpuinfo'] as Record<string, Object>)['cpus'] as number || 0 : 0,
        mem: statusData ? ((statusData['memory'] as Record<string, Object>)['used'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        maxmem: statusData ? ((statusData['memory'] as Record<string, Object>)['total'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        disk: statusData ? ((statusData['rootfs'] as Record<string, Object>)['used'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        maxdisk: statusData ? ((statusData['rootfs'] as Record<string, Object>)['total'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        uptime: statusData ? (statusData['uptime'] as number) || 0 : 0,
        vmCount: 0,
        ctCount: 0
      });
    }

    return nodes;
  }

  // 获取 VM 列表 GET /nodes/{node}/qemu
  async getVms(node: string): Promise<Vm[]> {
    const res = await this.request(http.RequestMethod.GET, `/nodes/${node}/qemu`);
    if (!res || !res['data']) return [];

    const vmsData = res['data'] as Array<Record<string, Object>>;
    const vms: Vm[] = [];

    for (const v of vmsData) {
      const vmid = v['vmid'] as number;
      const statusRes = await this.request(http.RequestMethod.GET, `/nodes/${node}/qemu/${vmid}/status/current`);
      const statusData = (statusRes && statusRes['data']) ? statusRes['data'] as Record<string, Object> : null;

      const status = statusData ? (statusData['status'] as string) : 'stopped';
      let vmStatus: 'running' | 'stopped' | 'paused' = 'stopped';
      if (status === 'running') vmStatus = 'running';
      else if (status === 'paused') vmStatus = 'paused';

      vms.push({
        vmid: vmid,
        name: (v['name'] as string) || `vm-${vmid}`,
        node: node,
        type: 'qemu',
        status: vmStatus,
        cpu: statusData ? (statusData['cpu'] as number) || 0 : 0,
        mem: statusData ? (statusData['mem'] as number) / (1024 * 1024) || 0 : 0,
        maxmem: statusData ? (statusData['maxmem'] as number) / (1024 * 1024) || 0 : 0,
        maxdisk: statusData ? (statusData['maxdisk'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        netin: statusData ? (statusData['netin'] as number) || 0 : 0,
        netout: statusData ? (statusData['netout'] as number) || 0 : 0,
        diskread: statusData ? (statusData['diskread'] as number) || 0 : 0,
        diskwrite: statusData ? (statusData['diskwrite'] as number) || 0 : 0,
        uptime: statusData ? (statusData['uptime'] as number) || 0 : 0,
        tags: (v['tags'] as string) ? (v['tags'] as string).split(';').filter(Boolean) : [],
        os: (v['ostype'] as string) || ''
      });
    }

    return vms;
  }

  // 获取 CT 列表 GET /nodes/{node}/lxc
  async getCts(node: string): Promise<Vm[]> {
    const res = await this.request(http.RequestMethod.GET, `/nodes/${node}/lxc`);
    if (!res || !res['data']) return [];

    const ctsData = res['data'] as Array<Record<string, Object>>;
    const cts: Vm[] = [];

    for (const c of ctsData) {
      const vmid = c['vmid'] as number;
      const statusRes = await this.request(http.RequestMethod.GET, `/nodes/${node}/lxc/${vmid}/status/current`);
      const statusData = (statusRes && statusRes['data']) ? statusRes['data'] as Record<string, Object> : null;

      const status = statusData ? (statusData['status'] as string) : 'stopped';
      let vmStatus: 'running' | 'stopped' | 'paused' = 'stopped';
      if (status === 'running') vmStatus = 'running';
      else if (status === 'paused') vmStatus = 'paused';

      cts.push({
        vmid: vmid,
        name: (c['name'] as string) || `ct-${vmid}`,
        node: node,
        type: 'lxc',
        status: vmStatus,
        cpu: statusData ? (statusData['cpu'] as number) || 0 : 0,
        mem: statusData ? (statusData['mem'] as number) / (1024 * 1024) || 0 : 0,
        maxmem: statusData ? (statusData['maxmem'] as number) / (1024 * 1024) || 0 : 0,
        maxdisk: statusData ? (statusData['maxdisk'] as number) / (1024 * 1024 * 1024) || 0 : 0,
        netin: statusData ? (statusData['netin'] as number) || 0 : 0,
        netout: statusData ? (statusData['netout'] as number) || 0 : 0,
        diskread: statusData ? (statusData['diskread'] as number) || 0 : 0,
        diskwrite: statusData ? (statusData['diskwrite'] as number) || 0 : 0,
        uptime: 0,
        tags: [],
        os: (c['ostype'] as string) || ''
      });
    }

    return cts;
  }

  // VM 操作 POST /nodes/{node}/qemu/{vmid}/status/{action}
  // action: start | shutdown | stop | reboot | suspend | resume
  async vmAction(node: string, vmid: number, action: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, `/nodes/${node}/qemu/${vmid}/status/${action}`);
    return res !== null;
  }

  // CT 操作
  async ctAction(node: string, vmid: number, action: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.POST, `/nodes/${node}/lxc/${vmid}/status/${action}`);
    return res !== null;
  }

  // 创建快照 POST /nodes/{node}/qemu/{vmid}/snapshot
  async createSnapshot(node: string, vmid: number, snapName: string, description: string = ''): Promise<boolean> {
    const data: Record<string, Object> = {
      snapname: snapName,
      description: description
    };
    const res = await this.request(http.RequestMethod.POST, `/nodes/${node}/qemu/${vmid}/snapshot`, data);
    return res !== null;
  }

  // 获取快照列表
  async getSnapshots(node: string, vmid: number): Promise<Snapshot[]> {
    const res = await this.request(http.RequestMethod.GET, `/nodes/${node}/qemu/${vmid}/snapshot`);
    if (!res || !res['data']) return [];

    const snapsData = res['data'] as Array<Record<string, Object>>;
    return snapsData.map((s): Snapshot => {
      const result: Snapshot = {
        name: s['name'] as string,
        vmid: vmid,
        date: s['snaptime'] ? new Date((s['snaptime'] as number) * 1000).toLocaleString() : '',
        size: s['size'] ? `${(s['size'] as number / (1024 * 1024 * 1024)).toFixed(1)} GB` : '',
        desc: (s['description'] as string) || ''
      };
      return result;
    });
  }

  // 删除快照
  async deleteSnapshot(node: string, vmid: number, snapName: string): Promise<boolean> {
    const res = await this.request(http.RequestMethod.DELETE, `/nodes/${node}/qemu/${vmid}/snapshot/${snapName}`);
    return res !== null;
  }

  // 获取存储池列表 GET /nodes/{node}/storage
  async getStorages(node: string): Promise<Storage[]> {
    const res = await this.request(http.RequestMethod.GET, `/nodes/${node}/storage`);
    if (!res || !res['data']) return [];

    const storagesData = res['data'] as Array<Record<string, Object>>;
    return storagesData.map((s): Storage => {
      const result: Storage = {
        name: s['storage'] as string,
        type: (s['type'] as string) as 'dir' | 'lvmthin' | 'zfs' | 'nfs',
        node: node,
        content: (s['content'] as string) || '',
        used: s['used'] ? (s['used'] as number) / (1024 * 1024 * 1024) : 0,
        total: s['total'] ? (s['total'] as number) / (1024 * 1024 * 1024) : 0,
        status: (s['active'] as number) === 1 ? 'active' : 'inactive'
      };
      return result;
    });
  }

  // 获取任务列表 GET /nodes/{node}/tasks
  async getTasks(node: string): Promise<PveTask[]> {
    const res = await this.request(http.RequestMethod.GET, `/nodes/${node}/tasks`);
    if (!res || !res['data']) return [];

    const tasksData = res['data'] as Array<Record<string, Object>>;
    return tasksData.map(t => {
      const tStatus = t['status'] as string || '';
      let status: 'running' | 'success' | 'failed' = 'running';
      if (tStatus === 'OK') status = 'success';
      else if (tStatus.includes('fail') || tStatus.includes('error')) status = 'failed';

      const result: PveTask = {
        id: t['upid'] as string,
        node: node,
        upid: t['upid'] as string,
        type: t['type'] as string,
        status: status,
        user: (t['user'] as string) || '',
        target: (t['id'] as string) || '',
        progress: 0,
        startTime: t['starttime'] ? new Date((t['starttime'] as number) * 1000).toLocaleTimeString() : ''
      };
      return result;
    });
  }

  // 获取集群版本
  async getVersion(): Promise<string> {
    const res = await this.request(http.RequestMethod.GET, '/version');
    if (res && res['data']) {
      return (res['data'] as Record<string, Object>)['version'] as string || '';
    }
    return '';
  }
}

// PVE 服务门面
export class PveService {
  // 获取所有集群配置
  static async getClusters(): Promise<PveCluster[]> {
    return await DataRepository.getPveClusters();
  }

  // 同步单个集群数据
  static async syncCluster(cluster: PveCluster): Promise<PveCluster> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);

    // 登录
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) {
      const failedCluster: PveCluster = {
        id: cluster.id,
        name: cluster.name,
        host: cluster.host,
        port: cluster.port,
        username: cluster.username,
        authType: cluster.authType,
        verifyTls: cluster.verifyTls,
        version: cluster.version,
        lastSync: '登录失败',
        nodes: []
      };
      return failedCluster;
    }

    // 获取版本
    const version = await client.getVersion();

    // 获取节点
    const nodes = await client.getNodes();

    // 获取每个节点的 VM/CT 数量
    for (const node of nodes) {
      const vms = await client.getVms(node.node);
      const cts = await client.getCts(node.node);
      node.vmCount = vms.length;
      node.ctCount = cts.length;
    }

    const syncedCluster: PveCluster = {
      id: cluster.id,
      name: cluster.name,
      host: cluster.host,
      port: cluster.port,
      username: cluster.username,
      authType: cluster.authType,
      verifyTls: cluster.verifyTls,
      version: version,
      lastSync: new Date().toLocaleTimeString(),
      nodes: nodes
    };
    return syncedCluster;
  }

  // 获取 VM 列表
  static async getVms(cluster: PveCluster, node?: string): Promise<Vm[]> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return [];

    const targetNodes = node ? [node] : cluster.nodes.map(n => n.node);
    const allVms: Vm[] = [];

    for (const n of targetNodes) {
      const vms = await client.getVms(n);
      const cts = await client.getCts(n);
      allVms.push(...vms, ...cts);
    }

    return allVms;
  }

  // 获取存储池
  static async getStorages(cluster: PveCluster, node: string): Promise<Storage[]> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return [];
    return await client.getStorages(node);
  }

  // 获取任务
  static async getTasks(cluster: PveCluster, node: string): Promise<PveTask[]> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return [];
    return await client.getTasks(node);
  }

  // VM 操作
  static async vmAction(cluster: PveCluster, node: string, vmid: number, type: 'qemu' | 'lxc', action: string): Promise<boolean> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return false;

    if (type === 'qemu') {
      return await client.vmAction(node, vmid, action);
    } else {
      return await client.ctAction(node, vmid, action);
    }
  }

  // 快照操作
  static async createSnapshot(cluster: PveCluster, node: string, vmid: number, name: string, desc: string = ''): Promise<boolean> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return false;
    return await client.createSnapshot(node, vmid, name, desc);
  }

  static async getSnapshots(cluster: PveCluster, node: string, vmid: number): Promise<Snapshot[]> {
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const loggedIn = await client.login(cluster.username, '');
    if (!loggedIn) return [];
    return await client.getSnapshots(node, vmid);
  }
}
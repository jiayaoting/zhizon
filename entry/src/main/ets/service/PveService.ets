import { http } from '@kit.NetworkKit';
import { PveCluster, PveNode, Vm, Storage, PveTask, Snapshot } from '../model/Models';
import { RemoteFailureCategory, RemoteResult } from '../model/GovernanceModels';
import { DataRepository } from './DataRepository';
import { RemoteOperation } from './RemoteOperation';
import { RemoteResultAdapter } from './RemoteResultAdapter';
import { PveTransportAdapter, PveTransportResponse } from './PveTransportAdapter';

class PveTicketData { ticket: string = ''; CSRFPreventionToken: string = ''; }
class PveTicketEnvelope { data: PveTicketData = new PveTicketData(); }
class PveArrayEnvelope { data: Object[] = []; }
class PveEmptyData {}
class PveObjectEnvelope { data: Object = new PveEmptyData(); }
class PveNodeData { node: string = ''; status: string = ''; }
class PveCpuInfo { cpus: number = 0; }
class PveUsage { used: number = 0; total: number = 0; }
class PveNodeStatusData {
  cpu: number = 0; cpuinfo: PveCpuInfo = new PveCpuInfo(); memory: PveUsage = new PveUsage();
  rootfs: PveUsage = new PveUsage(); uptime: number = 0;
}
class PveVmData {
  vmid: number = 0; name: string = ''; status: string = ''; cpu: number = 0; mem: number = 0;
  maxmem: number = 0; maxdisk: number = 0; netin: number = 0; netout: number = 0;
  diskread: number = 0; diskwrite: number = 0; uptime: number = 0; tags: string = ''; ostype: string = '';
}
class PveSnapshotData { name: string = ''; snaptime: number = 0; size: number = 0; description: string = ''; }
class PveStorageData {
  storage: string = ''; type: string = ''; content: string = ''; used: number = 0; total: number = 0; active: number = 0;
}
class PveTaskData {
  upid: string = ''; type: string = ''; status: string = ''; user: string = ''; id: string = ''; starttime: number = 0;
}
class PveVersionData { version: string = ''; }
class PveSnapshotRequest {
  snapname: string;
  description: string;
  constructor(snapname: string, description: string) {
    this.snapname = snapname;
    this.description = description;
  }
}
class PveLoginHeaders {
  'Content-Type': string = 'application/x-www-form-urlencoded';
}
class PveRequestHeaders {
  Authorization?: string;
  Cookie?: string;
  CSRFPreventionToken?: string;
}

export class PveClient {
  private baseUrl: string;
  private host: string;
  private port: number;
  private ticket: string = '';
  private csrfToken: string = '';

  constructor(host: string, port: number, verifyTls: boolean = false) {
    this.host = host;
    this.port = port;
    this.baseUrl = `https://${host}:${port}/api2/json`;
  }

  async login(username: string, password: string): Promise<RemoteResult<boolean>> {
    const body = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
    const operation = new RemoteOperation('pve-login', this.host, this.port, '/access/ticket', 10000, 10000);
    const headers: PveLoginHeaders = new PveLoginHeaders();
    const response = await PveTransportAdapter.request(operation, http.RequestMethod.POST,
      `${this.baseUrl}/access/ticket`, headers, body);
    if (!response.success || response.value === null || response.value.body === null) {
      return new RemoteResult<boolean>(false, null, response.failure);
    }
    const envelope = response.value.body as PveTicketEnvelope;
    if (!envelope.data || !envelope.data.ticket || !envelope.data.CSRFPreventionToken) {
      return RemoteResultAdapter.protocolFailure<boolean>();
    }
    this.ticket = envelope.data.ticket;
    this.csrfToken = envelope.data.CSRFPreventionToken;
    return RemoteResultAdapter.success<boolean>(true);
  }

  loginWithToken(tokenId: string, secret: string): RemoteResult<boolean> {
    if (!tokenId || !secret) {
      return RemoteResultAdapter.failure<boolean>(
        RemoteFailureCategory.AUTHENTICATION,
        'REMOTE_AUTH_MISSING', '认证失败，请返回配置页检查凭据', false);
    }
    this.ticket = `PVEAPIToken=${tokenId}=${secret}`;
    return RemoteResultAdapter.success<boolean>(true);
  }

  private async request(method: http.RequestMethod, path: string, data: string = ''): Promise<RemoteResult<Object>> {
    const headers: PveRequestHeaders = new PveRequestHeaders();
    if (this.ticket.startsWith('PVEAPIToken=')) {
      headers.Authorization = this.ticket;
    } else {
      headers.Cookie = `PVEAuthCookie=${this.ticket}`;
    }
    if (this.csrfToken.length > 0 && method !== http.RequestMethod.GET) {
      headers.CSRFPreventionToken = this.csrfToken;
    }
    const operation = new RemoteOperation('pve-request', this.host, this.port, path, 15000, 15000);
    const response: RemoteResult<PveTransportResponse> = await PveTransportAdapter.request(operation, method,
      `${this.baseUrl}${path}`, headers, data);
    if (!response.success || response.value === null || response.value.body === null) {
      return new RemoteResult<Object>(false, null, response.failure);
    }
    return RemoteResultAdapter.success<Object>(response.value.body);
  }

  async getNodes(): Promise<RemoteResult<PveNode[]>> {
    const response = await this.request(http.RequestMethod.GET, '/nodes');
    if (!response.success || response.value === null) return new RemoteResult<PveNode[]>(false, null, response.failure);
    const envelope = response.value as PveArrayEnvelope;
    if (!envelope.data || !Array.isArray(envelope.data)) return RemoteResultAdapter.protocolFailure<PveNode[]>();
    const nodes: PveNode[] = [];
    for (const raw of envelope.data) {
      const nodeData = raw as PveNodeData;
      if (!nodeData.node) return RemoteResultAdapter.protocolFailure<PveNode[]>();
      const statusResult = await this.request(http.RequestMethod.GET, `/nodes/${nodeData.node}/status`);
      if (!statusResult.success || statusResult.value === null) return new RemoteResult<PveNode[]>(false, null, statusResult.failure);
      const statusEnvelope = statusResult.value as PveObjectEnvelope;
      const status = statusEnvelope.data as PveNodeStatusData;
      nodes.push({ id: nodeData.node, node: nodeData.node, status: nodeData.status === 'online' ? 'online' : 'offline',
        cpu: status.cpu || 0, maxcpu: status.cpuinfo ? status.cpuinfo.cpus || 0 : 0,
        mem: status.memory ? (status.memory.used || 0) / 1073741824 : 0,
        maxmem: status.memory ? (status.memory.total || 0) / 1073741824 : 0,
        disk: status.rootfs ? (status.rootfs.used || 0) / 1073741824 : 0,
        maxdisk: status.rootfs ? (status.rootfs.total || 0) / 1073741824 : 0,
        uptime: status.uptime || 0, vmCount: 0, ctCount: 0 });
    }
    return RemoteResultAdapter.success<PveNode[]>(nodes);
  }

  private async getGuests(node: string, type: 'qemu' | 'lxc'): Promise<RemoteResult<Vm[]>> {
    const response = await this.request(http.RequestMethod.GET, `/nodes/${node}/${type}`);
    if (!response.success || response.value === null) return new RemoteResult<Vm[]>(false, null, response.failure);
    const envelope = response.value as PveArrayEnvelope;
    if (!envelope.data || !Array.isArray(envelope.data)) return RemoteResultAdapter.protocolFailure<Vm[]>();
    const vms: Vm[] = [];
    for (const raw of envelope.data) {
      const source = raw as PveVmData;
      if (!source.vmid) return RemoteResultAdapter.protocolFailure<Vm[]>();
      const statusResult = await this.request(http.RequestMethod.GET,
        `/nodes/${node}/${type}/${source.vmid}/status/current`);
      if (!statusResult.success || statusResult.value === null) return new RemoteResult<Vm[]>(false, null, statusResult.failure);
      const status = (statusResult.value as PveObjectEnvelope).data as PveVmData;
      const vmStatus: 'running' | 'stopped' | 'paused' = status.status === 'running' ? 'running' :
        status.status === 'paused' ? 'paused' : 'stopped';
      vms.push({ vmid: source.vmid, name: source.name || `${type === 'qemu' ? 'vm' : 'ct'}-${source.vmid}`,
        node: node, type: type, status: vmStatus, cpu: status.cpu || 0, mem: (status.mem || 0) / 1048576,
        maxmem: (status.maxmem || 0) / 1048576, maxdisk: (status.maxdisk || 0) / 1073741824,
        netin: status.netin || 0, netout: status.netout || 0, diskread: status.diskread || 0,
        diskwrite: status.diskwrite || 0, uptime: status.uptime || 0,
        tags: PveClient.parseTags(source.tags), os: source.ostype || '' });
    }
    return RemoteResultAdapter.success<Vm[]>(vms);
  }

  async getVms(node: string): Promise<RemoteResult<Vm[]>> { return await this.getGuests(node, 'qemu'); }
  async getCts(node: string): Promise<RemoteResult<Vm[]>> { return await this.getGuests(node, 'lxc'); }

  async vmAction(node: string, vmid: number, type: 'qemu' | 'lxc', action: string): Promise<RemoteResult<boolean>> {
    const result = await this.request(http.RequestMethod.POST, `/nodes/${node}/${type}/${vmid}/status/${action}`);
    return result.success ? RemoteResultAdapter.success<boolean>(true) : new RemoteResult<boolean>(false, null, result.failure);
  }

  async createSnapshot(node: string, vmid: number, name: string, description: string): Promise<RemoteResult<boolean>> {
    let body: string = '';
    try {
      body = JSON.stringify(new PveSnapshotRequest(name, description));
    } catch (error) {
      return RemoteResultAdapter.failure<boolean>(RemoteFailureCategory.VALIDATION,
        'REMOTE_REQUEST_SERIALIZATION_FAILED', '远程请求参数无效', false);
    }
    const result = await this.request(http.RequestMethod.POST, `/nodes/${node}/qemu/${vmid}/snapshot`, body);
    return result.success ? RemoteResultAdapter.success<boolean>(true) : new RemoteResult<boolean>(false, null, result.failure);
  }

  private static parseTags(value: string): string[] {
    if (value.length === 0) return [];
    const candidates: string[] = value.split(';');
    const tags: string[] = [];
    for (let index: number = 0; index < candidates.length; index++) {
      if (candidates[index].length > 0) tags.push(candidates[index]);
    }
    return tags;
  }

  async getSnapshots(node: string, vmid: number): Promise<RemoteResult<Snapshot[]>> {
    const result = await this.request(http.RequestMethod.GET, `/nodes/${node}/qemu/${vmid}/snapshot`);
    if (!result.success || result.value === null) return new RemoteResult<Snapshot[]>(false, null, result.failure);
    const envelope = result.value as PveArrayEnvelope;
    if (!envelope.data || !Array.isArray(envelope.data)) return RemoteResultAdapter.protocolFailure<Snapshot[]>();
    const snapshots: Snapshot[] = [];
    for (const raw of envelope.data) {
      const source = raw as PveSnapshotData;
      snapshots.push({ name: source.name, vmid: vmid,
        date: source.snaptime ? new Date(source.snaptime * 1000).toLocaleString() : '',
        size: source.size ? `${(source.size / 1073741824).toFixed(1)} GB` : '', desc: source.description || '' });
    }
    return RemoteResultAdapter.success<Snapshot[]>(snapshots);
  }

  async getStorages(node: string): Promise<RemoteResult<Storage[]>> {
    const result = await this.request(http.RequestMethod.GET, `/nodes/${node}/storage`);
    if (!result.success || result.value === null) return new RemoteResult<Storage[]>(false, null, result.failure);
    const envelope = result.value as PveArrayEnvelope;
    if (!envelope.data || !Array.isArray(envelope.data)) return RemoteResultAdapter.protocolFailure<Storage[]>();
    const storages: Storage[] = [];
    for (const raw of envelope.data) {
      const source = raw as PveStorageData;
      storages.push({ name: source.storage, type: source.type as 'dir' | 'lvmthin' | 'zfs' | 'nfs', node: node,
        content: source.content || '', used: (source.used || 0) / 1073741824,
        total: (source.total || 0) / 1073741824, status: source.active === 1 ? 'active' : 'inactive' });
    }
    return RemoteResultAdapter.success<Storage[]>(storages);
  }

  async getTasks(node: string): Promise<RemoteResult<PveTask[]>> {
    const result = await this.request(http.RequestMethod.GET, `/nodes/${node}/tasks`);
    if (!result.success || result.value === null) return new RemoteResult<PveTask[]>(false, null, result.failure);
    const envelope = result.value as PveArrayEnvelope;
    if (!envelope.data || !Array.isArray(envelope.data)) return RemoteResultAdapter.protocolFailure<PveTask[]>();
    const tasks: PveTask[] = [];
    for (const raw of envelope.data) {
      const source = raw as PveTaskData;
      const status: 'running' | 'success' | 'failed' = source.status === 'OK' ? 'success' :
        source.status.indexOf('fail') >= 0 || source.status.indexOf('error') >= 0 ? 'failed' : 'running';
      tasks.push({ id: source.upid, node: node, upid: source.upid, type: source.type, status: status,
        user: source.user || '', target: source.id || '', progress: 0,
        startTime: source.starttime ? new Date(source.starttime * 1000).toLocaleTimeString() : '' });
    }
    return RemoteResultAdapter.success<PveTask[]>(tasks);
  }

  async getVersion(): Promise<RemoteResult<string>> {
    const result = await this.request(http.RequestMethod.GET, '/version');
    if (!result.success || result.value === null) return new RemoteResult<string>(false, null, result.failure);
    const data = (result.value as PveObjectEnvelope).data as PveVersionData;
    return data.version ? RemoteResultAdapter.success<string>(data.version) : RemoteResultAdapter.protocolFailure<string>();
  }
}

export class PveService {
  static async getClusters(): Promise<PveCluster[]> { return await DataRepository.getPveClusters(); }

  private static async loginClient(client: PveClient, cluster: PveCluster): Promise<RemoteResult<boolean>> {
    if (cluster.authType === 'token') return client.loginWithToken(cluster.tokenId || '', cluster.tokenSecret || '');
    if (!cluster.password) {
      return RemoteResultAdapter.failure<boolean>(
        RemoteFailureCategory.AUTHENTICATION,
        'REMOTE_AUTH_MISSING', '认证失败，请返回配置页检查凭据', false);
    }
    return await client.login(cluster.username, cluster.password);
  }

  private static async clientFor(cluster: PveCluster): Promise<RemoteResult<PveClient>> {
    const hydrated = await DataRepository.hydratePveCredentials(cluster);
    const client = new PveClient(cluster.host, cluster.port, cluster.verifyTls);
    const login = await PveService.loginClient(client, hydrated);
    if (!login.success) return new RemoteResult<PveClient>(false, null, login.failure);
    return RemoteResultAdapter.success<PveClient>(client);
  }

  static async syncCluster(cluster: PveCluster): Promise<RemoteResult<PveCluster>> {
    const prepared = await PveService.clientFor(cluster);
    if (!prepared.success || prepared.value === null) return new RemoteResult<PveCluster>(false, null, prepared.failure);
    const version = await prepared.value.getVersion();
    if (!version.success || version.value === null) return new RemoteResult<PveCluster>(false, null, version.failure);
    const nodes = await prepared.value.getNodes();
    if (!nodes.success || nodes.value === null) return new RemoteResult<PveCluster>(false, null, nodes.failure);
    for (const node of nodes.value) {
      const vms = await prepared.value.getVms(node.node);
      if (!vms.success || vms.value === null) return new RemoteResult<PveCluster>(false, null, vms.failure);
      const cts = await prepared.value.getCts(node.node);
      if (!cts.success || cts.value === null) return new RemoteResult<PveCluster>(false, null, cts.failure);
      node.vmCount = vms.value.length;
      node.ctCount = cts.value.length;
    }
    return RemoteResultAdapter.success<PveCluster>({ id: cluster.id, name: cluster.name, host: cluster.host,
      port: cluster.port, username: cluster.username, authType: cluster.authType, verifyTls: cluster.verifyTls,
      version: version.value, lastSync: new Date().toLocaleTimeString(), nodes: nodes.value });
  }

  static async getVms(cluster: PveCluster, node?: string): Promise<RemoteResult<Vm[]>> {
    const prepared = await PveService.clientFor(cluster);
    if (!prepared.success || prepared.value === null) return new RemoteResult<Vm[]>(false, null, prepared.failure);
    const nodes: string[] = [];
    if (node !== undefined && node.length > 0) {
      nodes.push(node);
    } else {
      for (let index: number = 0; index < cluster.nodes.length; index++) {
        nodes.push(cluster.nodes[index].node);
      }
    }
    const all: Vm[] = [];
    for (const name of nodes) {
      const vms = await prepared.value.getVms(name);
      if (!vms.success || vms.value === null) return new RemoteResult<Vm[]>(false, null, vms.failure);
      const cts = await prepared.value.getCts(name);
      if (!cts.success || cts.value === null) return new RemoteResult<Vm[]>(false, null, cts.failure);
      all.push(...vms.value, ...cts.value);
    }
    return RemoteResultAdapter.success<Vm[]>(all);
  }

  static async getStorages(cluster: PveCluster, node: string): Promise<RemoteResult<Storage[]>> {
    const prepared = await PveService.clientFor(cluster);
    return prepared.success && prepared.value ? await prepared.value.getStorages(node) :
      new RemoteResult<Storage[]>(false, null, prepared.failure);
  }

  static async getTasks(cluster: PveCluster, node: string): Promise<RemoteResult<PveTask[]>> {
    const prepared = await PveService.clientFor(cluster);
    return prepared.success && prepared.value ? await prepared.value.getTasks(node) :
      new RemoteResult<PveTask[]>(false, null, prepared.failure);
  }

  static async getSnapshots(cluster: PveCluster, node: string, vmid: number): Promise<RemoteResult<Snapshot[]>> {
    const prepared = await PveService.clientFor(cluster);
    return prepared.success && prepared.value ? await prepared.value.getSnapshots(node, vmid) :
      new RemoteResult<Snapshot[]>(false, null, prepared.failure);
  }

  static async vmAction(cluster: PveCluster, node: string, vmid: number, type: 'qemu' | 'lxc', action: string): Promise<RemoteResult<boolean>> {
    const prepared = await PveService.clientFor(cluster);
    return prepared.success && prepared.value ? await prepared.value.vmAction(node, vmid, type, action) :
      new RemoteResult<boolean>(false, null, prepared.failure);
  }

  static async createSnapshot(cluster: PveCluster, node: string, vmid: number, name: string,
    description: string = ''): Promise<RemoteResult<boolean>> {
    const prepared = await PveService.clientFor(cluster);
    return prepared.success && prepared.value ? await prepared.value.createSnapshot(node, vmid, name, description) :
      new RemoteResult<boolean>(false, null, prepared.failure);
  }
}

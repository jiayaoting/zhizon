// 智子 - 数据模型定义

// SSH 服务器认证方式
export type AuthType = 'password' | 'key';

// 连接模式
export type ConnectionMode = 'direct' | 'agent';

// SSH 服务器
export interface Server {
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  authType: AuthType;
  connectionMode: ConnectionMode;
  agentToken?: string;
  privateKeyPath?: string;
  group?: string;
  tags: string[];
  os?: string;
  status: 'online' | 'warning' | 'offline';
  metrics: ServerMetrics;
  lastConnected?: number;
  createdAt: number;
}

export interface ServerMetrics {
  cpu: number;
  mem: number;
  disk: number;
  netIn: number;
  netOut: number;
  load: number;
  uptime: number;
}

// SSH 密钥
export interface SshKey {
  id: string;
  name: string;
  type: 'rsa' | 'ed25519' | 'ecdsa';
  fingerprint: string;
  createdAt: number;
}

// PVE 集群
export interface PveCluster {
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  authType: 'password' | 'token';
  verifyTls: boolean;
  version: string;
  lastSync: string;
  nodes: PveNode[];
}

// PVE 集群内的物理节点
export interface PveNode {
  id: string;
  node: string;
  status: 'online' | 'offline';
  cpu: number;        // 0~1
  maxcpu: number;     // 核数
  mem: number;        // GB
  maxmem: number;     // GB
  disk: number;       // GB
  maxdisk: number;    // GB
  uptime: number;     // 秒
  vmCount: number;
  ctCount: number;
}

// 虚拟机/容器
export interface Vm {
  vmid: number;
  name: string;
  node: string;
  type: 'qemu' | 'lxc';
  status: 'running' | 'stopped' | 'paused';
  cpu: number;
  mem: number;
  maxmem: number;
  maxdisk: number;
  netin: number;
  netout: number;
  diskread: number;
  diskwrite: number;
  uptime: number;
  tags: string[];
  os: string;
}

// 存储池
export interface Storage {
  name: string;
  type: 'dir' | 'lvmthin' | 'zfs' | 'nfs';
  node: string;
  content: string;
  used: number;
  total: number;
  status: 'active' | 'inactive';
}

// PVE 任务
export interface PveTask {
  id: string;
  node: string;
  upid: string;
  type: string;
  status: 'running' | 'success' | 'failed';
  user: string;
  target: string;
  progress: number;
  startTime: string;
  error?: string;
}

// 快照
export interface Snapshot {
  name: string;
  vmid: number;
  date: string;
  size: string;
  desc: string;
}

// 快捷命令
export interface Command {
  id: string;
  name: string;
  cmd: string;
  category: string;
  uses: number;
}

// 告警
export interface Alert {
  id: string;
  level: 'critical' | 'warning' | 'info';
  source: string;
  title: string;
  detail: string;
  time: string;
  resolved: boolean;
}

// 文件项
export interface FileItem {
  name: string;
  type: 'dir' | 'file';
  size: number;
  modified: string;
  perms: string;
}

// 统计数据
export interface Stats {
  total: number;
  online: number;
  warning: number;
  offline: number;
  alerts: number;
  pveNodes: number;
  vmTotal: number;
  vmRunning: number;
  vmStopped: number;
  ctTotal: number;
  runningTasks: number;
}

// 终端会话
export interface TerminalSession {
  id: string;
  serverName: string;
  cwd: string;
  history: string[];
}

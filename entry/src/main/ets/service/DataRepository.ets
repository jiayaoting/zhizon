// 智子 - 业务服务基类与格式化工具

import { Server, PveCluster, Vm, Storage, PveTask, Snapshot, Command, Alert, FileItem, Stats } from '../model/Models';
import { MockData } from './MockData';

// 格式化运行时间
export function formatUptime(seconds: number): string {
  if (!seconds) return '-';
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}天 ${h}小时`;
  if (h > 0) return `${h}小时 ${m}分钟`;
  return `${m}分钟`;
}

// 格式化大小（GB → TB）
export function formatSize(gb: number): string {
  if (gb >= 1024) return (gb / 1024).toFixed(1) + ' TB';
  return gb.toFixed(1) + ' GB';
}

// 数据仓库 - MVP 阶段直接返回 Mock 数据
export class DataRepository {
  static getServers(): Server[] {
    return MockData.servers;
  }

  static getServer(id: string): Server | undefined {
    return MockData.servers.find(s => s.id === id);
  }

  static getPveClusters(): PveCluster[] {
    return MockData.pveClusters;
  }

  static getPveCluster(id: string): PveCluster | undefined {
    return MockData.pveClusters.find(c => c.id === id);
  }

  static getVms(node?: string): Vm[] {
    return node ? MockData.vms.filter(v => v.node === node) : MockData.vms;
  }

  static getVm(vmid: number): Vm | undefined {
    return MockData.vms.find(v => v.vmid === vmid);
  }

  static getStorages(node?: string): Storage[] {
    return node ? MockData.storages.filter(s => s.node === node) : MockData.storages;
  }

  static getTasks(): PveTask[] {
    return MockData.pveTasks;
  }

  static getSnapshots(vmid?: number): Snapshot[] {
    return vmid ? MockData.snapshots.filter(s => s.vmid === vmid) : MockData.snapshots;
  }

  static getCommands(): Command[] {
    return MockData.commands;
  }

  static getAlerts(): Alert[] {
    return MockData.alerts;
  }

  static getFiles(): FileItem[] {
    return MockData.files;
  }

  static getStats(): Stats {
    const s = MockData.servers;
    const vms = MockData.vms;
    const nodes = MockData.pveClusters.flatMap(c => c.nodes);
    return {
      total: s.length,
      online: s.filter(x => x.status === 'online').length,
      warning: s.filter(x => x.status === 'warning').length,
      offline: s.filter(x => x.status === 'offline').length,
      alerts: MockData.alerts.filter(a => !a.resolved).length,
      pveNodes: nodes.length,
      vmTotal: vms.length,
      vmRunning: vms.filter(v => v.status === 'running').length,
      vmStopped: vms.filter(v => v.status === 'stopped').length,
      ctTotal: vms.filter(v => v.type === 'lxc').length,
      runningTasks: MockData.pveTasks.filter(t => t.status === 'running').length
    };
  }
}

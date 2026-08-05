// 智子 - 数据仓库（基于数据库持久化）
import { Server, PveCluster, Vm, Storage, PveTask, Snapshot, Command, Alert, FileItem, Stats } from '../model/Models';
import { DatabaseHelper } from './DatabaseHelper';
import { PveService } from './PveService';

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

// 格式化大小（GB -> TB）
export function formatSize(gb: number): string {
  if (gb >= 1024) return (gb / 1024).toFixed(1) + ' TB';
  return gb.toFixed(1) + ' GB';
}

// 生成唯一 ID
export function generateId(prefix: string): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `${prefix}-${timestamp}-${random}`;
}

// 数据仓库 - 持久化版本
export class DataRepository {
  // ========== 服务器管理 ==========

  static async getServers(): Promise<Server[]> {
    return await DatabaseHelper.getServers();
  }

  static async getServer(id: string): Promise<Server | undefined> {
    return await DatabaseHelper.getServer(id);
  }

  static async addServer(server: Server): Promise<void> {
    await DatabaseHelper.addServer(server);
  }

  static async updateServer(id: string, updates: Partial<Server>): Promise<void> {
    await DatabaseHelper.updateServer(id, updates);
  }

  static async deleteServer(id: string): Promise<void> {
    await DatabaseHelper.deleteServer(id);
  }

  // ========== PVE 集群管理 ==========

  static async getPveClusters(): Promise<PveCluster[]> {
    return await DatabaseHelper.getPveClusters();
  }

  static async addPveCluster(cluster: PveCluster): Promise<void> {
    await DatabaseHelper.addPveCluster(cluster);
  }

  static async deletePveCluster(id: string): Promise<void> {
    await DatabaseHelper.deletePveCluster(id);
  }

  // ========== 快捷命令 ==========

  static async getCommands(): Promise<Command[]> {
    return await DatabaseHelper.getCommands();
  }

  static async addCommand(cmd: Command): Promise<void> {
    await DatabaseHelper.addCommand(cmd);
  }

  static async incrementCommandUses(id: string): Promise<void> {
    await DatabaseHelper.incrementCommandUses(id);
  }

  static async deleteCommand(id: string): Promise<void> {
    await DatabaseHelper.deleteCommand(id);
  }

  // ========== 告警 ==========

  static async getAlerts(): Promise<Alert[]> {
    return await DatabaseHelper.getAlerts();
  }

  static async addAlert(alert: Alert): Promise<void> {
    await DatabaseHelper.addAlert(alert);
  }

  static async resolveAlert(id: string): Promise<void> {
    await DatabaseHelper.resolveAlert(id);
  }

  static async resolveAllAlerts(): Promise<void> {
    await DatabaseHelper.resolveAllAlerts();
  }

  // ========== 文件管理 ==========

  static async getFiles(): Promise<FileItem[]> {
    return await DatabaseHelper.getFiles();
  }

  // ========== 设置 ==========

  static async getSetting(key: string, defaultValue: string = ''): Promise<string> {
    return await DatabaseHelper.getSetting(key, defaultValue);
  }

  static async setSetting(key: string, value: string): Promise<void> {
    await DatabaseHelper.setSetting(key, value);
  }

  // ========== 统计 ==========

  static async getStats(): Promise<Stats> {
    const servers = await DataRepository.getServers();
    const alerts = await DataRepository.getAlerts();
    const unresolvedAlerts = alerts.filter(a => !a.resolved);

    return {
      total: servers.length,
      online: 0,
      warning: 0,
      offline: servers.length,
      alerts: unresolvedAlerts.length,
      pveNodes: 0,
      vmTotal: 0,
      vmRunning: 0,
      vmStopped: 0,
      ctTotal: 0,
      runningTasks: 0
    };
  }

  // ========== PVE 节点详情 ==========

  static async getPveCluster(id: string): Promise<PveCluster | undefined> {
    const clusters = await DataRepository.getPveClusters();
    return clusters.find(c => c.id === id);
  }

  static async getVms(cluster: PveCluster, node?: string): Promise<Vm[]> {
    try {
      return await PveService.getVms(cluster, node);
    } catch (e) {
      return [];
    }
  }

  static async getStorages(cluster: PveCluster, node: string): Promise<Storage[]> {
    try {
      return await PveService.getStorages(cluster, node);
    } catch (e) {
      return [];
    }
  }

  static async getTasks(cluster: PveCluster, node: string): Promise<PveTask[]> {
    try {
      return await PveService.getTasks(cluster, node);
    } catch (e) {
      return [];
    }
  }

  static async getVm(cluster: PveCluster, node: string, vmid: number): Promise<Vm | undefined> {
    const vms = await DataRepository.getVms(cluster, node);
    return vms.find(v => v.vmid === vmid);
  }

  static async getSnapshots(cluster: PveCluster, node: string, vmid: number): Promise<Snapshot[]> {
    try {
      return await PveService.getSnapshots(cluster, node, vmid);
    } catch (e) {
      return [];
    }
  }
}
// 智子 - 数据仓库（基于数据库持久化）
import { Server, PveCluster, Vm, Storage, PveTask, Snapshot, Command, Alert, Stats } from '../model/Models';
import { DatabaseHelper, ScoreEntry } from './DatabaseHelper';
import { PveService } from './PveService';
import { ThemePreference, ThemeMode, GlobalBackgroundPreference } from '../common/Theme';
import { hilog } from '@kit.PerformanceAnalysisKit';

const SETTINGS_DOMAIN = 0x9201;

class StoredThemePreference {
  followSystem: boolean = true;
  manualMode: string = ThemeMode.DARK;
}

class StoredBackgroundPreference {
  globalUri: string = '';
  visibleStrength: number = 50;
}

class LegacyBackgroundConfig {
  global: string = '';
}

function isSandboxBackgroundReference(uri: string): boolean {
  return uri.length === 0 || uri.indexOf('://') < 0;
}

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

  // ========== 凭据管理（加密存储） ==========

  static async saveCredentials(id: string, password?: string, keyContent?: string): Promise<void> {
    await DatabaseHelper.saveCredentials(id, password, keyContent);
  }

  static async getPassword(id: string): Promise<string> {
    return await DatabaseHelper.getPassword(id);
  }

  static async getKeyContent(id: string): Promise<string> {
    return await DatabaseHelper.getKeyContent(id);
  }

  // ========== 连接历史（按最近连接排序） ==========

  static async getConnectionHistory(limit: number = 5): Promise<Server[]> {
    const servers = await DatabaseHelper.getServers();
    const connected = servers.filter(s => (s.lastConnected ?? 0) > 0);
    connected.sort((a, b) => (b.lastConnected ?? 0) - (a.lastConnected ?? 0));
    return connected.slice(0, limit);
  }

  // ========== PVE 集群管理 ==========

  static async getPveClusters(): Promise<PveCluster[]> {
    return await DatabaseHelper.getPveClusters();
  }

  static async addPveCluster(cluster: PveCluster): Promise<void> {
    await DatabaseHelper.addPveCluster(cluster);
  }

  static async updatePveCluster(id: string, updates: Partial<PveCluster>): Promise<void> {
    await DatabaseHelper.updatePveCluster(id, updates);
  }

  static async deletePveCluster(id: string): Promise<void> {
    await DatabaseHelper.deletePveCluster(id);
  }

  // ========== PVE 凭据管理（加密存储） ==========

  static async savePveCredentials(id: string, password?: string, tokenSecret?: string): Promise<void> {
    await DatabaseHelper.savePveCredentials(id, password, tokenSecret);
  }

  static async getPvePassword(id: string): Promise<string> {
    return await DatabaseHelper.getPvePassword(id);
  }

  static async getPveTokenId(id: string): Promise<string> {
    return await DatabaseHelper.getPveTokenId(id);
  }

  static async getPveTokenSecret(id: string): Promise<string> {
    return await DatabaseHelper.getPveTokenSecret(id);
  }

  // 从加密存储加载 PVE 凭据到内存态（列表页连接/测试前调用，凭据不落库）
  static async hydratePveCredentials(cluster: PveCluster): Promise<PveCluster> {
    // 内存态已有明文凭据（表单测试/新建场景）则直接复用
    if (cluster.password || cluster.tokenSecret) return cluster;
    try {
      const password = await DataRepository.getPvePassword(cluster.id);
      const tokenSecret = await DataRepository.getPveTokenSecret(cluster.id);
      const tokenId = await DataRepository.getPveTokenId(cluster.id);
      if (!password && !tokenSecret) return cluster;
      const hydrated: PveCluster = {
        id: cluster.id,
        name: cluster.name,
        host: cluster.host,
        port: cluster.port,
        username: cluster.username,
        authType: cluster.authType,
        verifyTls: cluster.verifyTls,
        version: cluster.version,
        lastSync: cluster.lastSync,
        nodes: cluster.nodes,
        password: password || undefined,
        tokenId: tokenId || undefined,
        tokenSecret: tokenSecret || undefined
      };
      return hydrated;
    } catch (e) {
      console.error('hydratePveCredentials failed:', JSON.stringify(e));
      return cluster;
    }
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

  // ========== 游戏战绩 ==========

  static async addGameScore(game: string, score: number, level: number, difficulty: string): Promise<void> {
    await DatabaseHelper.addGameScore(game, score, level, difficulty);
  }

  static async getGameScores(game: string, limit?: number): Promise<ScoreEntry[]> {
    return await DatabaseHelper.getGameScores(game, limit);
  }

  static async getGameHighScore(game: string): Promise<number> {
    return await DatabaseHelper.getGameHighScore(game);
  }

  static async deleteGameScore(id: string): Promise<void> {
    await DatabaseHelper.deleteGameScore(id);
  }

  static async clearGameScores(game: string): Promise<void> {
    await DatabaseHelper.clearGameScores(game);
  }

  // ========== 文件管理 ==========

  // ========== 设置 ==========

  static async getSetting(key: string, defaultValue: string = ''): Promise<string> {
    return await DatabaseHelper.getSetting(key, defaultValue);
  }

  static async setSetting(key: string, value: string): Promise<void> {
    await DatabaseHelper.setSetting(key, value);
  }

  static async getThemePreference(): Promise<ThemePreference> {
    const raw = await DatabaseHelper.getSetting('themePreference', '');
    if (raw.length > 0) {
      try {
        const stored = JSON.parse(raw) as StoredThemePreference;
        let followSystem = true;
        if (stored.followSystem === false) {
          followSystem = false;
        }
        let manualMode = ThemeMode.DARK;
        if (stored.manualMode === ThemeMode.LIGHT) {
          manualMode = ThemeMode.LIGHT;
        }
        return new ThemePreference(followSystem, manualMode);
      } catch (e) {
        return new ThemePreference(true, ThemeMode.DARK);
      }
    }
    const legacyFollow = await DatabaseHelper.getSetting('followSystemDark', 'true');
    const legacyManual = await DatabaseHelper.getSetting('manualDarkMode', 'true');
    const preference = new ThemePreference(legacyFollow === 'true',
      legacyManual === 'false' ? ThemeMode.LIGHT : ThemeMode.DARK);
    await DataRepository.saveThemePreference(preference);
    return preference;
  }

  static async saveThemePreference(preference: ThemePreference): Promise<void> {
    const stored = new StoredThemePreference();
    stored.followSystem = preference.followSystem;
    stored.manualMode = preference.manualMode;
    await DatabaseHelper.setSetting('themePreference', JSON.stringify(stored));
  }

  static async getGlobalBackground(): Promise<GlobalBackgroundPreference> {
    const raw = await DatabaseHelper.getSetting('globalBackgroundPreference', '');
    if (raw.length > 0) {
      try {
        const stored = JSON.parse(raw) as StoredBackgroundPreference;
        const globalUri = stored.globalUri && isSandboxBackgroundReference(stored.globalUri) ? stored.globalUri : '';
        let strength = Number.isInteger(stored.visibleStrength) ? stored.visibleStrength : 50;
        if (strength < 0 || strength > 100) {
          strength = 50;
        }
        return new GlobalBackgroundPreference(globalUri, strength);
      } catch (e) {
        hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置读取失败 source=%{public}s fallback=%{public}s', 'globalBackgroundPreference', 'true');
        return new GlobalBackgroundPreference('', 50);
      }
    }
    let migratedUri = '';
    const legacyRaw = await DatabaseHelper.getSetting('backgroundConfig', '');
    if (legacyRaw.length > 0) {
      try {
        const legacy = JSON.parse(legacyRaw) as LegacyBackgroundConfig;
        if (legacy.global && isSandboxBackgroundReference(legacy.global)) {
          migratedUri = legacy.global;
        }
        hilog.info(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置迁移完成 source=%{public}s pagesIgnored=%{public}s', 'backgroundConfig', 'true');
      } catch (e) {
        migratedUri = '';
        hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置迁移失败 source=%{public}s fallback=%{public}s', 'backgroundConfig', 'true');
      }
    }
    const migrated = new GlobalBackgroundPreference(migratedUri, 50);
    await DataRepository.saveGlobalBackground(migrated);
    await DatabaseHelper.setSetting('backgroundConfig', '');
    return migrated;
  }

  static async saveGlobalBackground(preference: GlobalBackgroundPreference): Promise<void> {
    if (!isSandboxBackgroundReference(preference.globalUri)) {
      throw new Error('EXTERNAL_URI_NOT_ALLOWED');
    }
    if (!Number.isInteger(preference.visibleStrength) || preference.visibleStrength < 0 ||
      preference.visibleStrength > 100) {
      throw new Error('INVALID_STRENGTH');
    }
    const stored = new StoredBackgroundPreference();
    stored.globalUri = preference.globalUri;
    stored.visibleStrength = preference.visibleStrength;
    await DatabaseHelper.setSetting('globalBackgroundPreference', JSON.stringify(stored));
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

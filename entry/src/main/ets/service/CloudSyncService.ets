// 智子 - 云同步服务（华为账号标识 + Cloud Foundation Kit 云存储，未配置 AGC 时优雅降级为本地备份）
import { cloudStorage } from '@kit.CloudFoundationKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { request, BusinessError } from '@kit.BasicServicesKit';
import { DatabaseHelper, GameScoreRecord } from './DatabaseHelper';
import { ChatRepository } from './ChatRepository';
import { ChatSession } from '../common/LlmModels';
import { AchievementService } from './AchievementService';
import { AchievementState } from '../common/AchievementModels';
import { DataRepository } from './DataRepository';

const CLOUD_FILE = 'zhizon-backup-v3.json';
const KEY_LAST_SYNC = 'cloudSyncLastTime';

export class CloudSyncResult {
  ok: boolean;
  cloud: boolean;
  message: string;

  constructor(ok: boolean, cloud: boolean, message: string) {
    this.ok = ok;
    this.cloud = cloud;
    this.message = message;
  }
}

// 云备份载荷（v3：配置 + 战绩 + 成就 + 对话）
class CloudBackupPayload {
  app: string = 'zhizon';
  version: number = 3;
  exportedAt: number = 0;
  account: string = '';
  settings: Record<string, string> = {};
  scores: GameScoreRecord[] = [];
  achievements: AchievementState[] = [];
  chat: string = '';
}

export class CloudSyncService {
  // 立即备份：先写本地缓存文件，再尽力上传云端
  static async backupNow(context: common.Context): Promise<CloudSyncResult> {
    try {
      const payload: CloudBackupPayload = await CloudSyncService.buildPayload();
      const filePath: string = context.cacheDir + '/zhizon-backup.json';
      await CloudSyncService.writeText(filePath, JSON.stringify(payload));

      let cloud: boolean = false;
      try {
        const bucket: cloudStorage.StorageBucket = cloudStorage.bucket();
        const uploadParams: cloudStorage.UploadParams = {
          localPath: filePath,
          cloudPath: CLOUD_FILE
        };
        const task: request.agent.Task = await bucket.uploadFile(context, uploadParams);
        await CloudSyncService.awaitTask(task);
        cloud = true;
      } catch (e) {
        // 未配置 AGC / 无网 / 云侧失败：降级为本地备份
        cloud = false;
      }

      await DataRepository.setSetting(KEY_LAST_SYNC, Date.now().toString());
      return new CloudSyncResult(true, cloud, cloud ? '已备份到华为云空间' : '已备份到本地（云端未配置或不可用）');
    } catch (e) {
      return new CloudSyncResult(false, false, '备份失败：' + CloudSyncService.errMsg(e));
    }
  }

  // 立即恢复：优先从云端下载，失败则尝试本地缓存文件
  static async restoreNow(context: common.Context): Promise<CloudSyncResult> {
    const filePath: string = context.cacheDir + '/zhizon-backup.json';
    let cloud: boolean = false;
    try {
      const bucket: cloudStorage.StorageBucket = cloudStorage.bucket();
      const downloadParams: cloudStorage.DownloadParams = {
        cloudPath: CLOUD_FILE,
        localPath: filePath
      };
      const task: request.agent.Task = await bucket.downloadFile(context, downloadParams);
      await CloudSyncService.awaitTask(task);
      cloud = true;
    } catch (e) {
      cloud = false;
    }

    const exists: boolean = CloudSyncService.fileExists(filePath);
    if (!exists) {
      return new CloudSyncResult(false, false, '没有可恢复的备份（云端与本地均不存在）');
    }
    const json: string = CloudSyncService.readText(filePath);
    const ok: boolean = await CloudSyncService.applyPayload(json);
    if (!ok) {
      return new CloudSyncResult(false, cloud, '备份文件格式无效');
    }
    await DataRepository.setSetting(KEY_LAST_SYNC, Date.now().toString());
    return new CloudSyncResult(true, cloud, cloud ? '已从华为云空间恢复' : '已从本地备份恢复');
  }

  static async lastSyncLabel(): Promise<string> {
    const raw: string = await DataRepository.getSetting(KEY_LAST_SYNC, '');
    if (raw.length === 0) return '从未同步';
    const ts: number = Number(raw);
    if (Number.isNaN(ts) || ts <= 0) return '从未同步';
    const d: Date = new Date(ts);
    const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  // 组装完整备份载荷
  private static async buildPayload(): Promise<CloudBackupPayload> {
    const payload: CloudBackupPayload = new CloudBackupPayload();
    payload.exportedAt = Date.now();
    const account = await DataRepository.getSetting('huaweiAccountProfile', '');
    payload.account = account.length > 0 ? account : 'local';
    payload.settings = await DatabaseHelper.getAllSettings();
    payload.scores = await DatabaseHelper.getAllGameScores();
    payload.achievements = await AchievementService.getAll();
    const sessions: ChatSession[] = await ChatRepository.loadSessions();
    payload.chat = await CloudSyncService.exportAllChat(sessions);
    return payload;
  }

  private static async exportAllChat(sessions: ChatSession[]): Promise<string> {
    const sessionList: Object[] = [];
    for (let i: number = 0; i < sessions.length; i++) {
      const s: ChatSession = sessions[i];
      const messages = await ChatRepository.loadMessages(s.id);
      const item: Record<string, Object> = {};
      item['title'] = s.title;
      item['createdAt'] = s.createdAt;
      const msgList: Object[] = [];
      for (let j: number = 0; j < messages.length; j++) {
        const m = messages[j];
        const mi: Record<string, Object> = {};
        mi['role'] = m.role;
        mi['content'] = m.content;
        mi['reasoning'] = m.reasoning;
        mi['time'] = m.time;
        msgList.push(mi);
      }
      item['messages'] = msgList;
      sessionList.push(item);
    }
    const payload: Record<string, Object> = {};
    payload['app'] = 'zhizon';
    payload['version'] = 2;
    payload['exportedAt'] = Date.now();
    payload['sessions'] = sessionList;
    return JSON.stringify(payload);
  }

  // 应用备份：设置/战绩/成就/对话
  private static async applyPayload(json: string): Promise<boolean> {
    try {
      const parsed: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (parsed['app'] !== 'zhizon') return false;

      const settingsRaw: Object | undefined = parsed['settings'];
      if (settingsRaw !== undefined) {
        const settings: Record<string, string> = {};
        const keys: string[] = Object.keys(settingsRaw);
        for (let i: number = 0; i < keys.length; i++) {
          const v: Object = (settingsRaw as Record<string, Object>)[keys[i]];
          settings[keys[i]] = typeof v === 'string' ? v as string : '';
        }
        await DatabaseHelper.replaceAllSettings(settings);
      }

      const scoresRaw: Object | undefined = parsed['scores'];
      if (scoresRaw !== undefined && Array.isArray(scoresRaw)) {
        await DatabaseHelper.clearGameScoresAll();
        const arr: Object[] = scoresRaw as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const item: Record<string, Object> = arr[i] as Record<string, Object>;
          await DatabaseHelper.insertGameScoreRaw(
            typeof item['game'] === 'string' ? item['game'] as string : '',
            DatabaseHelper.scoreFromCloud(item));
        }
      }

      const achievementsRaw: Object | undefined = parsed['achievements'];
      if (achievementsRaw !== undefined && Array.isArray(achievementsRaw)) {
        const states: AchievementState[] = [];
        const arr: Object[] = achievementsRaw as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const item: Record<string, Object> = arr[i] as Record<string, Object>;
          states.push(new AchievementState(
            typeof item['id'] === 'string' ? item['id'] as string : '',
            item['unlocked'] === true,
            typeof item['progress'] === 'number' ? item['progress'] as number : 0,
            typeof item['unlockedAt'] === 'number' ? item['unlockedAt'] as number : 0));
        }
        await AchievementService.restoreAll(states);
      }

      const chat: string = typeof parsed['chat'] === 'string' ? parsed['chat'] as string : '';
      if (chat.length > 0) {
        await ChatRepository.importBackupAll(chat);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // 等待上传/下载任务完成
  private static awaitTask(task: request.agent.Task): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Object) => void) => {
      task.on('completed', () => { resolve(); });
      task.on('failed', () => { reject(new Error('cloud task failed')); });
      task.start((err: BusinessError) => {
        if (err) {
          reject(new Error('cloud task start failed'));
        }
      });
    });
  }

  private static async writeText(filePath: string, text: string): Promise<void> {
    const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
    fileIo.writeSync(file.fd, text);
    fileIo.closeSync(file);
  }

  private static readText(filePath: string): string {
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(filePath);
    const buf = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buf);
    fileIo.closeSync(file);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buf));
  }

  private static fileExists(filePath: string): boolean {
    try {
      fileIo.statSync(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  private static errMsg(e: Object): string {
    const err = e as BusinessError;
    if (err.message !== undefined && err.message.length > 0) return err.message;
    return '未知错误';
  }
}

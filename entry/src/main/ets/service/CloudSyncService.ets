// 智子 - 云同步服务（华为账号标识 + Cloud Foundation Kit 云存储，未配置 AGC 时优雅降级为本地备份）
import { cloudStorage } from '@kit.CloudFoundationKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { request, BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper, GameScoreRecord, ScoreEntry } from './DatabaseHelper';
import { ChatRepository } from './ChatRepository';
import { ChatExporter, ImportedChat } from './ChatExporter';
import { ChatMessage, ChatSession } from '../common/LlmModels';
import { AchievementService } from './AchievementService';
import { AchievementState } from '../common/AchievementModels';
import { DataRepository } from './DataRepository';

const CLOUD_FILE = 'zhizon-backup-v3.json';
const KEY_LAST_SYNC = 'cloudSyncLastTime';
const TASK_TIMEOUT_MS = 60000; // 云上传/下载任务超时（毫秒）

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

// 恢复预览统计（供设置页恢复确认对话框展示）
export class RestorePreview {
  ok: boolean;
  message: string;
  settingsCount: number;
  scoreCount: number;
  achievementCount: number;
  sessionCount: number;
  messageCount: number;
  checksumOk: boolean;
  hasChecksum: boolean;

  constructor(ok: boolean, message: string, settingsCount: number, scoreCount: number,
    achievementCount: number, sessionCount: number, messageCount: number,
    checksumOk: boolean, hasChecksum: boolean) {
    this.ok = ok;
    this.message = message;
    this.settingsCount = settingsCount;
    this.scoreCount = scoreCount;
    this.achievementCount = achievementCount;
    this.sessionCount = sessionCount;
    this.messageCount = messageCount;
    this.checksumOk = checksumOk;
    this.hasChecksum = hasChecksum;
  }
}

// 云备份载荷（v3：配置 + 战绩 + 成就 + 对话 + 校验和）
class CloudBackupPayload {
  app: string = 'zhizon';
  version: number = 3;
  exportedAt: number = 0;
  account: string = '';
  settings: Record<string, string> = {};
  scores: GameScoreRecord[] = [];
  achievements: AchievementState[] = [];
  chat: string = '';
  checksum: string = '';
}

// 校验和检查结果
class ChecksumResult {
  hasChecksum: boolean;
  valid: boolean;

  constructor(hasChecksum: boolean, valid: boolean) {
    this.hasChecksum = hasChecksum;
    this.valid = valid;
  }
}

export class CloudSyncService {
  // 立即备份：先原子写本地缓存文件，再尽力上传云端
  static async backupNow(context: common.Context): Promise<CloudSyncResult> {
    try {
      const payload: CloudBackupPayload = await CloudSyncService.buildPayload();
      const filePath: string = context.cacheDir + '/zhizon-backup.json';
      await CloudSyncService.writeTextAtomic(filePath, JSON.stringify(payload));

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

  // 恢复预览：下载备份并统计内容与校验结果（不写任何数据，供恢复前确认）
  static async restorePreview(context: common.Context): Promise<RestorePreview> {
    const filePath: string = context.cacheDir + '/zhizon-backup.json';
    const cloud: boolean = await CloudSyncService.downloadToLocal(context, filePath);
    if (!CloudSyncService.fileExists(filePath)) {
      return new RestorePreview(false, '没有可恢复的备份（云端与本地均不存在）', 0, 0, 0, 0, 0, false, false);
    }
    let json: string = '';
    try {
      json = CloudSyncService.readText(filePath);
    } catch (e) {
      return new RestorePreview(false, '备份文件读取失败或已损坏', 0, 0, 0, 0, 0, false, false);
    }
    const parsed: Record<string, Object> | null = CloudSyncService.parseBackup(json);
    if (parsed === null) {
      return new RestorePreview(false, '备份文件格式无效', 0, 0, 0, 0, 0, false, false);
    }
    const checksum: ChecksumResult = await CloudSyncService.verifyChecksum(parsed);

    const settingsRaw: Object | undefined = parsed['settings'];
    const settingsCount: number = settingsRaw !== undefined
      ? Object.keys(settingsRaw as Record<string, Object>).length : 0;
    const scoresRaw: Object | undefined = parsed['scores'];
    const scoreCount: number = scoresRaw !== undefined && Array.isArray(scoresRaw)
      ? (scoresRaw as Object[]).length : 0;
    const achievementsRaw: Object | undefined = parsed['achievements'];
    const achievementCount: number = achievementsRaw !== undefined && Array.isArray(achievementsRaw)
      ? (achievementsRaw as Object[]).length : 0;
    const chat: string = typeof parsed['chat'] === 'string' ? parsed['chat'] as string : '';
    let sessionCount: number = 0;
    let messageCount: number = 0;
    if (chat.length > 0) {
      const importedList: ImportedChat[] = ChatExporter.parseImportAll(chat);
      sessionCount = importedList.length;
      for (let i: number = 0; i < importedList.length; i++) {
        messageCount += importedList[i].messages.length;
      }
    }
    const message: string = !checksum.hasChecksum ? '旧备份（无校验和）' :
      (checksum.valid ? '校验通过' : '校验失败：文件可能已损坏或被篡改');
    return new RestorePreview(true, message + (cloud ? '（云端）' : '（本地）'),
      settingsCount, scoreCount, achievementCount, sessionCount, messageCount,
      checksum.valid, checksum.hasChecksum);
  }

  // 立即恢复：优先从云端下载，失败则尝试本地缓存文件（合并式恢复，不再清空覆盖）
  static async restoreNow(context: common.Context): Promise<CloudSyncResult> {
    const filePath: string = context.cacheDir + '/zhizon-backup.json';
    const cloud: boolean = await CloudSyncService.downloadToLocal(context, filePath);
    if (!CloudSyncService.fileExists(filePath)) {
      return new CloudSyncResult(false, cloud, '没有可恢复的备份（云端与本地均不存在）');
    }
    let json: string = '';
    try {
      json = CloudSyncService.readText(filePath);
    } catch (e) {
      return new CloudSyncResult(false, cloud, '备份文件读取失败或已损坏');
    }
    const parsed: Record<string, Object> | null = CloudSyncService.parseBackup(json);
    if (parsed === null) {
      return new CloudSyncResult(false, cloud, '备份文件格式无效');
    }
    // 先校验：旧版备份无 checksum 字段则跳过；校验不匹配直接失败，不继续 apply
    const checksum: ChecksumResult = await CloudSyncService.verifyChecksum(parsed);
    if (checksum.hasChecksum && !checksum.valid) {
      return new CloudSyncResult(false, cloud, '备份校验失败：文件可能已损坏或被篡改');
    }
    const ok: boolean = await CloudSyncService.applyPayloadParsed(parsed);
    if (!ok) {
      return new CloudSyncResult(false, cloud, '恢复失败：应用备份数据时出错');
    }
    await DataRepository.setSetting(KEY_LAST_SYNC, Date.now().toString());
    const base: string = cloud ? '已从华为云空间恢复' : '已从本地备份恢复';
    return new CloudSyncResult(true, cloud, checksum.hasChecksum ? base : base + '（旧备份未校验）');
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

  // 组装完整备份载荷（checksum 基于不含 checksum 字段的 JSON 字符串计算）
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
    payload.checksum = await CloudSyncService.sha256Hex(CloudSyncService.bodyJson(payload));
    return payload;
  }

  // 不含 checksum 字段的载荷 JSON（字段顺序即哈希输入，恢复校验时必须保持一致）
  private static bodyJson(payload: CloudBackupPayload): string {
    return '{"app":' + JSON.stringify(payload.app) +
      ',"version":' + payload.version.toString() +
      ',"exportedAt":' + payload.exportedAt.toString() +
      ',"account":' + JSON.stringify(payload.account) +
      ',"settings":' + JSON.stringify(payload.settings) +
      ',"scores":' + JSON.stringify(payload.scores) +
      ',"achievements":' + JSON.stringify(payload.achievements) +
      ',"chat":' + JSON.stringify(payload.chat) + '}';
  }

  private static async sha256Hex(text: string): Promise<string> {
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    const encoder = new util.TextEncoder();
    const input: cryptoFramework.DataBlob = { data: encoder.encodeInto(text) };
    await md.update(input);
    const digest: cryptoFramework.DataBlob = await md.digest();
    return CloudSyncService.toHex(digest.data);
  }

  private static toHex(bytes: Uint8Array): string {
    let out: string = '';
    for (let i: number = 0; i < bytes.length; i++) {
      const hex: string = bytes[i].toString(16);
      out += hex.length === 1 ? '0' + hex : hex;
    }
    return out;
  }

  // 导出全部会话（v3：会话携带 id/updatedAt，消息携带 id 便于恢复去重）
  private static async exportAllChat(sessions: ChatSession[]): Promise<string> {
    const msgMap: Record<string, ChatMessage[]> = {};
    for (let i: number = 0; i < sessions.length; i++) {
      msgMap[sessions[i].id] = await ChatRepository.loadMessages(sessions[i].id);
    }
    return ChatExporter.toJsonAll(sessions, (sessionId: string): ChatMessage[] => {
      const msgs: ChatMessage[] | undefined = msgMap[sessionId];
      return msgs === undefined ? [] : msgs;
    });
  }

  // 解析并校验备份 JSON 的 app 标识
  private static parseBackup(json: string): Record<string, Object> | null {
    try {
      const parsed: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (parsed['app'] !== 'zhizon') return null;
      return parsed;
    } catch (e) {
      return null;
    }
  }

  // 校验 checksum：旧版备份无该字段时跳过（hasChecksum=false，视为通过）
  private static async verifyChecksum(parsed: Record<string, Object>): Promise<ChecksumResult> {
    const raw: Object | undefined = parsed['checksum'];
    if (raw === undefined) {
      return new ChecksumResult(false, true);
    }
    if (typeof raw !== 'string') {
      return new ChecksumResult(true, false);
    }
    try {
      const actual: string = await CloudSyncService.sha256Hex(CloudSyncService.parsedBodyJson(parsed));
      return new ChecksumResult(true, actual === raw);
    } catch (e) {
      return new ChecksumResult(true, false);
    }
  }

  // 恢复侧重建不含 checksum 的载荷 JSON（与 bodyJson 的字段顺序与序列化保持一致）
  private static parsedBodyJson(parsed: Record<string, Object>): string {
    const settingsRaw: Object | undefined = parsed['settings'];
    const scoresRaw: Object | undefined = parsed['scores'];
    const achievementsRaw: Object | undefined = parsed['achievements'];
    return '{"app":' + CloudSyncService.jsonStr(parsed['app'], 'zhizon') +
      ',"version":' + CloudSyncService.jsonNum(parsed['version'], 3) +
      ',"exportedAt":' + CloudSyncService.jsonNum(parsed['exportedAt'], 0) +
      ',"account":' + CloudSyncService.jsonStr(parsed['account'], '') +
      ',"settings":' + (settingsRaw !== undefined ? JSON.stringify(settingsRaw) : '{}') +
      ',"scores":' + (scoresRaw !== undefined ? JSON.stringify(scoresRaw) : '[]') +
      ',"achievements":' + (achievementsRaw !== undefined ? JSON.stringify(achievementsRaw) : '[]') +
      ',"chat":' + CloudSyncService.jsonStr(parsed['chat'], '') + '}';
  }

  private static jsonStr(v: Object | undefined, fallback: string): string {
    return JSON.stringify(typeof v === 'string' ? v as string : fallback);
  }

  private static jsonNum(v: Object | undefined, fallback: number): string {
    return (typeof v === 'number' ? v as number : fallback).toString();
  }

  // 合并式应用备份：设置逐 key 写回、战绩按 id 补缺、成就取并集、对话按 id/标题合并
  private static async applyPayloadParsed(parsed: Record<string, Object>): Promise<boolean> {
    try {
      // 设置：逐 key 写回，保留本地有而备份没有的 key（不再 replaceAllSettings 清空）
      const settingsRaw: Object | undefined = parsed['settings'];
      if (settingsRaw !== undefined) {
        const settings: Record<string, Object> = settingsRaw as Record<string, Object>;
        const keys: string[] = Object.keys(settings);
        for (let i: number = 0; i < keys.length; i++) {
          const v: Object = settings[keys[i]];
          await DataRepository.setSetting(keys[i], typeof v === 'string' ? v as string : '');
        }
      }

      // 战绩：只补本地不存在的 id（不再 clearGameScoresAll）
      const scoresRaw: Object | undefined = parsed['scores'];
      if (scoresRaw !== undefined && Array.isArray(scoresRaw)) {
        const localScores: GameScoreRecord[] = await DatabaseHelper.getAllGameScores();
        const localIds: Set<string> = new Set<string>();
        for (let i: number = 0; i < localScores.length; i++) localIds.add(localScores[i].id);
        const arr: Object[] = scoresRaw as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const item: Record<string, Object> = arr[i] as Record<string, Object>;
          const entry: ScoreEntry = DatabaseHelper.scoreFromCloud(item);
          const rawId: string = typeof item['id'] === 'string' ? item['id'] as string : '';
          const dedupId: string = rawId.length > 0 ? rawId : entry.id;
          if (!localIds.has(dedupId)) {
            localIds.add(dedupId);
            await DatabaseHelper.insertGameScoreRaw(
              typeof item['game'] === 'string' ? item['game'] as string : '', entry);
          }
        }
      }

      // 成就：按 id 合并（unlocked 取或、progress 取最大、unlockedAt 取先解锁时间）
      const achievementsRaw: Object | undefined = parsed['achievements'];
      if (achievementsRaw !== undefined && Array.isArray(achievementsRaw)) {
        const localStates: AchievementState[] = await AchievementService.getAll();
        const localMap: Record<string, AchievementState> = {};
        for (let i: number = 0; i < localStates.length; i++) {
          localMap[localStates[i].id] = localStates[i];
        }
        const arr: Object[] = achievementsRaw as Object[];
        const merged: AchievementState[] = [];
        for (let i: number = 0; i < arr.length; i++) {
          const item: Record<string, Object> = arr[i] as Record<string, Object>;
          const id: string = typeof item['id'] === 'string' ? item['id'] as string : '';
          const backup: AchievementState = new AchievementState(id,
            item['unlocked'] === true,
            typeof item['progress'] === 'number' ? item['progress'] as number : 0,
            typeof item['unlockedAt'] === 'number' ? item['unlockedAt'] as number : 0);
          if (localMap[id] !== undefined) {
            const local: AchievementState = localMap[id] as AchievementState;
            const unlocked: boolean = local.unlocked || backup.unlocked;
            const progress: number = Math.max(local.progress, backup.progress);
            let unlockedAt: number = 0;
            if (local.unlockedAt > 0 &&
              (backup.unlockedAt === 0 || backup.unlockedAt > local.unlockedAt)) {
              unlockedAt = local.unlockedAt;
            } else {
              unlockedAt = backup.unlockedAt;
            }
            merged.push(new AchievementState(id, unlocked, progress, unlockedAt));
          } else {
            merged.push(backup);
          }
        }
        await AchievementService.restoreAll(merged);
      }

      // 对话：合并式导入（同 id 会话补消息，旧备份按 title+createdAt 匹配）
      const chat: string = typeof parsed['chat'] === 'string' ? parsed['chat'] as string : '';
      if (chat.length > 0) {
        await CloudSyncService.importChatMerged(chat);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // 合并式导入对话：同 id 会话补缺失消息；旧备份按 title+createdAt 匹配；都不中才新建
  private static async importChatMerged(chat: string): Promise<void> {
    const importedList: ImportedChat[] = ChatExporter.parseImportAll(chat);
    if (importedList.length === 0) return;
    const sessions: ChatSession[] = await ChatRepository.loadSessions();
    const byId: Record<string, ChatSession> = {};
    const byTitleCreated: Record<string, ChatSession> = {};
    for (let i: number = 0; i < sessions.length; i++) {
      const s: ChatSession = sessions[i];
      if (s.id.length > 0) byId[s.id] = s;
      if (s.createdAt > 0) {
        byTitleCreated[CloudSyncService.sessionMatchKey(s.title, s.createdAt)] = s;
      }
    }
    for (let i: number = 0; i < importedList.length; i++) {
      const imported: ImportedChat = importedList[i];
      let target: ChatSession | null = null;
      if (imported.sessionId.length > 0 && byId[imported.sessionId] !== undefined) {
        target = byId[imported.sessionId] as ChatSession;
      } else if (imported.sessionId.length === 0 && imported.createdAt > 0 &&
        byTitleCreated[CloudSyncService.sessionMatchKey(imported.title, imported.createdAt)] !== undefined) {
        target = byTitleCreated[CloudSyncService.sessionMatchKey(imported.title, imported.createdAt)] as ChatSession;
      }
      if (target !== null) {
        // 已存在会话：只补缺失消息，不新建
        await CloudSyncService.mergeMessages(target.id, imported.messages);
      } else if (imported.sessionId.length > 0) {
        // v3：本地无同 id 会话 → 保留备份 id/时间建会话，保证再次恢复可去重
        const created: ChatSession = await CloudSyncService.insertSessionFromBackup(imported);
        byId[created.id] = created;
        byTitleCreated[CloudSyncService.sessionMatchKey(created.title, created.createdAt)] = created;
        await CloudSyncService.mergeMessages(created.id, imported.messages);
      } else {
        // 旧备份（无 id）：匹配不到再 createSession
        const created: ChatSession = await ChatRepository.createSession(imported.title);
        byTitleCreated[CloudSyncService.sessionMatchKey(created.title, created.createdAt)] = created;
        await CloudSyncService.mergeMessages(created.id, imported.messages);
      }
    }
  }

  private static sessionMatchKey(title: string, createdAt: number): string {
    return title + '\u0000' + createdAt.toString();
  }

  // 按备份字段建会话（保留 id/createdAt/updatedAt，行结构与 ChatRepository.createSession 一致）
  private static async insertSessionFromBackup(imported: ImportedChat): Promise<ChatSession> {
    const id: string = imported.sessionId.length > 0 ? imported.sessionId : ChatSession.newId();
    const createdAt: number = imported.createdAt > 0 ? imported.createdAt : Date.now();
    const updatedAt: number = imported.updatedAt > 0 ? imported.updatedAt : createdAt;
    const bucket: relationalStore.ValuesBucket = {
      id: id,
      title: imported.title,
      created_at: createdAt,
      updated_at: updatedAt,
      pinned: 0,
      active_model_id: ''
    };
    await DatabaseHelper.getStore().insert('chat_sessions', bucket);
    return new ChatSession(id, imported.title, createdAt, updatedAt, false, '');
  }

  // 按消息 id 去重后补齐缺失消息
  private static async mergeMessages(sessionId: string, incoming: ChatMessage[]): Promise<void> {
    if (incoming.length === 0) return;
    const existing: ChatMessage[] = await ChatRepository.loadMessages(sessionId);
    const existingIds: Set<string> = new Set<string>();
    for (let i: number = 0; i < existing.length; i++) existingIds.add(existing[i].id);
    const missing: ChatMessage[] = [];
    for (let i: number = 0; i < incoming.length; i++) {
      const m: ChatMessage = incoming[i];
      if (m.id.length === 0 || !existingIds.has(m.id)) {
        missing.push(m);
        if (m.id.length > 0) existingIds.add(m.id);
      }
    }
    if (missing.length > 0) {
      await ChatRepository.appendMessages(sessionId, missing);
    }
  }

  // 尽力从云端下载备份到本地缓存（失败返回 false，调用方回退本地文件）
  private static async downloadToLocal(context: common.Context, filePath: string): Promise<boolean> {
    try {
      const bucket: cloudStorage.StorageBucket = cloudStorage.bucket();
      const downloadParams: cloudStorage.DownloadParams = {
        cloudPath: CLOUD_FILE,
        localPath: filePath
      };
      const task: request.agent.Task = await bucket.downloadFile(context, downloadParams);
      await CloudSyncService.awaitTask(task);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 等待上传/下载任务完成（60 秒超时，超时拒绝并清除定时器）
  private static async awaitTask(task: request.agent.Task): Promise<void> {
    let timer: number = -1;
    const timeoutPromise: Promise<void> = new Promise<void>(
      (resolve: () => void, reject: (reason: Object) => void) => {
        timer = setTimeout(() => {
          reject(new Error('cloud task timeout'));
        }, TASK_TIMEOUT_MS);
      });
    const taskPromise: Promise<void> = new Promise<void>(
      (resolve: () => void, reject: (reason: Object) => void) => {
        task.on('completed', () => { resolve(); });
        task.on('failed', () => { reject(new Error('cloud task failed')); });
        task.start((err: BusinessError) => {
          if (err) {
            reject(new Error('cloud task start failed'));
          }
        });
      });
    try {
      return await Promise.race([taskPromise, timeoutPromise]);
    } finally {
      if (timer >= 0) {
        clearTimeout(timer);
      }
    }
  }

  // 原子写：先写 '<最终路径>.tmp'，成功后改名覆盖最终路径，避免半写文件被当作有效备份
  private static async writeTextAtomic(filePath: string, text: string): Promise<void> {
    const tmpPath: string = filePath + '.tmp';
    await CloudSyncService.writeText(tmpPath, text);
    try {
      fileIo.renameSync(tmpPath, filePath);
    } catch (e) {
      try {
        fileIo.unlinkSync(tmpPath);
      } catch (e2) {
      }
      throw new Error('备份写入失败');
    }
  }

  private static async writeText(filePath: string, text: string): Promise<void> {
    const file = fileIo.openSync(filePath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
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

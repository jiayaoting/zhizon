// 智子 - 热榜「关注」列表的本地存储与 NewsNow 云端同步
// 设计文档：doc/newsnow-redesign.md §7
// 冲突策略：整份按 updatedTime 新者覆盖（与服务端/网页版语义一致）
import { DataRepository } from './DataRepository';
import { NewsNowClient } from './NewsNowClient';
import { NewsNowAuth } from './NewsNowAuth';
import { FocusMetadata } from '../common/HotModels';

const KEY_FOCUS_META = 'hot_focus_meta';
// 标星后延迟上传（对齐网页版防抖行为）
const PUSH_DEBOUNCE_MS = 10000;

// 同步状态（设置页展示）
export class HotSyncState {
  lastSyncTime: number;      // 上次成功同步时间（0 = 从未）
  lastError: string;         // 最近一次错误文案（'' = 无）

  constructor(lastSyncTime: number, lastError: string) {
    this.lastSyncTime = lastSyncTime;
    this.lastError = lastError;
  }
}

export class NewsNowSync {
  private static pushTimer: number = -1;
  private static focusCache: FocusMetadata | null = null;
  private static lastSyncTime: number = 0;
  private static lastError: string = '';
  // 关注列表变更通知（UI 订阅刷新）
  private static listeners: (() => void)[] = [];

  static addListener(fn: () => void): void {
    NewsNowSync.listeners.push(fn);
  }

  static removeListener(fn: () => void): void {
    const idx: number = NewsNowSync.listeners.indexOf(fn);
    if (idx >= 0) NewsNowSync.listeners.splice(idx, 1);
  }

  private static notify(): void {
    for (let i: number = 0; i < NewsNowSync.listeners.length; i++) {
      NewsNowSync.listeners[i]();
    }
  }

  static state(): HotSyncState {
    return new HotSyncState(NewsNowSync.lastSyncTime, NewsNowSync.lastError);
  }

  // ==================== 本地存储 ====================

  static async getFocus(): Promise<FocusMetadata> {
    if (NewsNowSync.focusCache !== null) return NewsNowSync.focusCache;
    const raw: string = await DataRepository.getSetting(KEY_FOCUS_META, '');
    if (raw.length === 0) {
      const empty: FocusMetadata = new FocusMetadata([], 0);
      NewsNowSync.focusCache = empty;
      return empty;
    }
    try {
      const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const arrObj: Object = obj['focusSources'];
      const list: string[] = [];
      if (arrObj !== undefined && arrObj !== null && Array.isArray(arrObj)) {
        const arr: Object[] = arrObj as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') list.push(arr[i] as string);
        }
      }
      const timeObj: Object = obj['updatedTime'];
      const t: number = timeObj === undefined || timeObj === null ? 0 : Number(timeObj.toString());
      const meta: FocusMetadata = new FocusMetadata(list, isNaN(t) ? 0 : t);
      NewsNowSync.focusCache = meta;
      return meta;
    } catch (e) {
      const empty: FocusMetadata = new FocusMetadata([], 0);
      NewsNowSync.focusCache = empty;
      return empty;
    }
  }

  private static async saveFocus(meta: FocusMetadata): Promise<void> {
    NewsNowSync.focusCache = meta;
    await DataRepository.setSetting(KEY_FOCUS_META, JSON.stringify(meta));
  }

  static async isStarred(sourceId: string): Promise<boolean> {
    const meta: FocusMetadata = await NewsNowSync.getFocus();
    return meta.focusSources.indexOf(sourceId) >= 0;
  }

  static async focusIds(): Promise<string[]> {
    const meta: FocusMetadata = await NewsNowSync.getFocus();
    return meta.focusSources;
  }

  // 标星/取消；返回切换后是否已关注
  static async toggleStar(sourceId: string): Promise<boolean> {
    const meta: FocusMetadata = await NewsNowSync.getFocus();
    const idx: number = meta.focusSources.indexOf(sourceId);
    const next: string[] = [];
    for (let i: number = 0; i < meta.focusSources.length; i++) next.push(meta.focusSources[i]);
    let starred: boolean;
    if (idx >= 0) {
      next.splice(idx, 1);
      starred = false;
    } else {
      next.push(sourceId);
      starred = true;
    }
    await NewsNowSync.saveFocus(new FocusMetadata(next, Date.now()));
    NewsNowSync.notify();
    if (await NewsNowAuth.isLoggedIn()) NewsNowSync.schedulePush();
    return starred;
  }

  // 重排关注列表
  static async reorderFocus(sourceIds: string[]): Promise<void> {
    const kept: string[] = [];
    for (let i: number = 0; i < sourceIds.length; i++) kept.push(sourceIds[i]);
    await NewsNowSync.saveFocus(new FocusMetadata(kept, Date.now()));
    NewsNowSync.notify();
    if (await NewsNowAuth.isLoggedIn()) NewsNowSync.schedulePush();
  }

  // ==================== 云端同步 ====================

  private static applyRemote(remote: FocusMetadata): void {
    NewsNowSync.focusCache = remote;
    DataRepository.setSetting(KEY_FOCUS_META, JSON.stringify(remote));
  }

  // 拉取并与本地比较（新者胜）；返回是否有变化
  static async pull(): Promise<boolean> {
    const res = await NewsNowClient.pullMetadata();
    if (!res.ok) {
      NewsNowSync.lastError = res.error === null ? '同步失败' : res.error.message;
      if (res.error !== null && res.error.code === 'unauthorized') {
        await NewsNowAuth.clearSession();
      }
      return false;
    }
    const remote: FocusMetadata | null = res.meta;
    NewsNowSync.lastError = '';
    if (remote === null) return false;
    const local: FocusMetadata = await NewsNowSync.getFocus();
    // 云端更新 → 覆盖本地
    if (remote.updatedTime > local.updatedTime) {
      const changed: boolean = !NewsNowSync.sameList(local.focusSources, remote.focusSources);
      NewsNowSync.applyRemote(remote);
      NewsNowSync.lastSyncTime = Date.now();
      if (changed) NewsNowSync.notify();
      return changed;
    }
    // 本地更新 → 反向推送
    if (local.updatedTime > remote.updatedTime) {
      const err = await NewsNowClient.pushMetadata(local);
      if (err === null) {
        NewsNowSync.lastSyncTime = Date.now();
        return false;
      }
      NewsNowSync.lastError = err.message;
      return false;
    }
    NewsNowSync.lastSyncTime = Date.now();
    return false;
  }

  // 登录成功后调用
  static async onLogin(): Promise<void> {
    await NewsNowSync.pull();
  }

  // App 启动调用（仅已登录时拉取）
  static async onAppStart(): Promise<void> {
    if (!(await NewsNowAuth.isLoggedIn())) return;
    await NewsNowSync.pull();
  }

  // 防抖上传
  static schedulePush(): void {
    if (NewsNowSync.pushTimer >= 0) {
      clearTimeout(NewsNowSync.pushTimer);
    }
    NewsNowSync.pushTimer = setTimeout(() => {
      NewsNowSync.pushTimer = -1;
      NewsNowSync.flushPush();
    }, PUSH_DEBOUNCE_MS);
  }

  // 立即上传（App 退后台前调用）
  static async flushPush(): Promise<void> {
    if (NewsNowSync.pushTimer >= 0) {
      clearTimeout(NewsNowSync.pushTimer);
      NewsNowSync.pushTimer = -1;
    }
    if (!(await NewsNowAuth.isLoggedIn())) return;
    const local: FocusMetadata = await NewsNowSync.getFocus();
    const err = await NewsNowClient.pushMetadata(local);
    if (err === null) {
      NewsNowSync.lastSyncTime = Date.now();
      NewsNowSync.lastError = '';
    } else {
      NewsNowSync.lastError = err.message;
      if (err.code === 'unauthorized') await NewsNowAuth.clearSession();
    }
  }

  // 「立即同步」按钮：双向合并
  static async syncNow(): Promise<HotSyncState> {
    if (!(await NewsNowAuth.isLoggedIn())) {
      NewsNowSync.lastError = '未登录';
      return NewsNowSync.state();
    }
    await NewsNowSync.pull();
    await NewsNowSync.flushPush();
    return NewsNowSync.state();
  }

  private static sameList(a: string[], b: string[]): boolean {
    if (a.length !== b.length) return false;
    for (let i: number = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }
}

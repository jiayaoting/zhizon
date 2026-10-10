// 智子 - 热榜内存状态（各源榜单缓存 + 加载状态机）
// 设计文档：doc/newsnow-redesign.md §8
// 客户端不做 HTTP 缓存，一切以服务端 TTL 为准；此层只做内存态与加载编排
import { HotBoardData, HotEntry, HotViewKey, HotItem } from '../common/HotModels';
import { HotSources } from '../common/HotSources';
import { NewsNowClient, HotBoardsResult, HotBoardResult } from './NewsNowClient';
import { NewsNowSync } from './NewsNowSync';

// 槽位状态
export enum SlotStatus {
  Idle = 'idle',
  Loading = 'loading',
  Ready = 'ready',
  Error = 'error'
}

// 单源槽位
export class BoardSlot {
  status: SlotStatus;
  data: HotBoardData | null;
  error: string;

  constructor(status: SlotStatus, data: HotBoardData | null, error: string) {
    this.status = status;
    this.data = data;
    this.error = error;
  }
}

// 前台驻留超过该时长后回到页面，静默补齐
const STALE_REFRESH_MS = 30 * 60 * 1000;

export class HotFeedStore {
  private static slots: Map<string, BoardSlot> = new Map<string, BoardSlot>();
  private static focusIds: string[] = [];
  private static serverOnline: boolean = true;
  private static lastEnsureTime: number = 0;
  // 变更通知：页面注册回调后自增本地 tick 触发重绘（V2 组件用 @Local）
  private static changeListeners: (() => void)[] = [];

  static addChangeListener(fn: () => void): void {
    HotFeedStore.changeListeners.push(fn);
  }

  static removeChangeListener(fn: () => void): void {
    const idx: number = HotFeedStore.changeListeners.indexOf(fn);
    if (idx >= 0) HotFeedStore.changeListeners.splice(idx, 1);
  }

  private static bump(): void {
    for (let i: number = 0; i < HotFeedStore.changeListeners.length; i++) {
      HotFeedStore.changeListeners[i]();
    }
  }

  static isServerOnline(): boolean {
    return HotFeedStore.serverOnline;
  }

  // 视图内的源 id 列表（异步，需读取关注列表）
  static async sourceIds(view: HotViewKey): Promise<string[]> {
    const focus: string[] = await NewsNowSync.focusIds();
    HotFeedStore.focusIds = focus;
    return HotSources.sourceIdsForView(view, focus);
  }

  // 关注列表变更后同步缓存
  static async refreshFocusCache(): Promise<void> {
    HotFeedStore.focusIds = await NewsNowSync.focusIds();
  }

  static focusSourceIds(): string[] {
    return HotFeedStore.focusIds;
  }

  static slotOf(sourceId: string): BoardSlot {
    const s: BoardSlot | undefined = HotFeedStore.slots.get(sourceId);
    if (s === undefined) return new BoardSlot(SlotStatus.Idle, null, '');
    return s;
  }

  // 源榜单 → 组合条目
  static entriesOf(sourceId: string): HotEntry[] {
    const slot: BoardSlot = HotFeedStore.slotOf(sourceId);
    const out: HotEntry[] = [];
    if (slot.data === null) return out;
    const name: string = HotSources.nameOf(sourceId);
    const items: HotItem[] = slot.data.items;
    for (let i: number = 0; i < items.length; i++) {
      const key: string = sourceId + ':' + items[i].id;
      out.push(new HotEntry(key, items[i], sourceId, name));
    }
    return out;
  }

  // 全部已加载条目（AI 今日要闻 / 搜索用）
  static allLoadedEntries(): HotEntry[] {
    const out: HotEntry[] = [];
    HotFeedStore.slots.forEach((slot: BoardSlot, sourceId: string) => {
      if (slot.data === null) return;
      const name: string = HotSources.nameOf(sourceId);
      const items: HotItem[] = slot.data.items;
      for (let i: number = 0; i < items.length; i++) {
        out.push(new HotEntry(sourceId + ':' + items[i].id, items[i], sourceId, name));
      }
    });
    return out;
  }

  // 按源取 TopN 条目（今日要闻用）
  static topEntries(sourceId: string, n: number): HotEntry[] {
    const all: HotEntry[] = HotFeedStore.entriesOf(sourceId);
    return all.length <= n ? all : all.slice(0, n);
  }

  // ==================== 加载编排 ====================

  // 确保视图内所有源有数据：idle 源批量 entire 预取 + 缺失源单独补齐
  static async ensureView(view: HotViewKey, force: boolean = false): Promise<void> {
    const ids: string[] = await HotFeedStore.sourceIds(view);
    if (ids.length === 0) return;
    const missing: string[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      const slot: BoardSlot = HotFeedStore.slotOf(ids[i]);
      if (force || slot.status === SlotStatus.Idle || slot.status === SlotStatus.Error) {
        missing.push(ids[i]);
      }
    }
    if (missing.length === 0) {
      HotFeedStore.lastEnsureTime = Date.now();
      return;
    }
    for (let i: number = 0; i < missing.length; i++) {
      HotFeedStore.setSlot(missing[i], new BoardSlot(SlotStatus.Loading, null, ''));
    }
    HotFeedStore.bump();

    const res: HotBoardsResult = await NewsNowClient.fetchBoards(missing);
    if (!res.ok && res.boards.length === 0) {
      // 整体失败（服务器不可达）
      HotFeedStore.serverOnline = false;
      for (let i: number = 0; i < missing.length; i++) {
        HotFeedStore.setSlot(missing[i],
          new BoardSlot(SlotStatus.Error, null, '无法连接热榜服务器'));
      }
      HotFeedStore.bump();
      return;
    }
    HotFeedStore.serverOnline = true;
    const got: string[] = [];
    for (let i: number = 0; i < res.boards.length; i++) {
      const r: HotBoardResult = res.boards[i];
      if (r.ok && r.data !== null) {
        HotFeedStore.setSlot(r.sourceId, new BoardSlot(SlotStatus.Ready, r.data, ''));
        got.push(r.sourceId);
      } else if (!r.ok) {
        HotFeedStore.setSlot(r.sourceId,
          new BoardSlot(SlotStatus.Error, null, r.error === null ? '加载失败' : r.error.message));
      }
    }
    // entire 未覆盖的源单独补（懒加载）
    const rest: string[] = [];
    for (let i: number = 0; i < missing.length; i++) {
      if (got.indexOf(missing[i]) < 0 && HotFeedStore.slotOf(missing[i]).status === SlotStatus.Loading) {
        rest.push(missing[i]);
      }
    }
    HotFeedStore.bump();
    if (rest.length > 0) {
      await HotFeedStore.loadEach(rest, false);
    }
    HotFeedStore.lastEnsureTime = Date.now();
  }

  // 单源刷新（latest = 请求服务端真实抓取）
  static async refreshSource(sourceId: string, latest: boolean = true): Promise<void> {
    HotFeedStore.setSlot(sourceId, new BoardSlot(SlotStatus.Loading, null, ''));
    HotFeedStore.bump();
    const r: HotBoardResult = await NewsNowClient.fetchBoard(sourceId, latest);
    if (r.ok && r.data !== null) {
      HotFeedStore.serverOnline = true;
      HotFeedStore.setSlot(sourceId, new BoardSlot(SlotStatus.Ready, r.data, ''));
    } else {
      const msg: string = r.error === null ? '加载失败' : r.error.message;
      if (r.error !== null && r.error.code === 'network') HotFeedStore.serverOnline = false;
      // 保留旧数据，仅标记错误
      const old: BoardSlot = HotFeedStore.slotOf(sourceId);
      HotFeedStore.setSlot(sourceId, new BoardSlot(SlotStatus.Error, old.data, msg));
    }
    HotFeedStore.bump();
  }

  // 视图整体刷新（并发）
  static async refreshView(view: HotViewKey): Promise<void> {
    const ids: string[] = await HotFeedStore.sourceIds(view);
    if (ids.length === 0) return;
    const tasks: Promise<void>[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      tasks.push(HotFeedStore.refreshSource(ids[i], true));
    }
    for (let i: number = 0; i < tasks.length; i++) {
      await tasks[i];
    }
  }

  // 前台驻留过久后静默补齐（不触发 latest 抓取）
  static async refreshIfStale(view: HotViewKey): Promise<void> {
    if (Date.now() - HotFeedStore.lastEnsureTime < STALE_REFRESH_MS) return;
    const ids: string[] = await HotFeedStore.sourceIds(view);
    if (ids.length === 0) return;
    const res: HotBoardsResult = await NewsNowClient.fetchBoards(ids);
    if (!res.ok && res.boards.length === 0) return;
    for (let i: number = 0; i < res.boards.length; i++) {
      const r: HotBoardResult = res.boards[i];
      if (r.ok && r.data !== null && r.data.items.length > 0) {
        HotFeedStore.setSlot(r.sourceId, new BoardSlot(SlotStatus.Ready, r.data, ''));
      }
    }
    HotFeedStore.lastEnsureTime = Date.now();
    HotFeedStore.bump();
  }

  // 逐源加载（entire 未覆盖时的兜底）
  private static async loadEach(ids: string[], latest: boolean): Promise<void> {
    for (let i: number = 0; i < ids.length; i++) {
      await HotFeedStore.refreshSource(ids[i], latest);
    }
  }

  // 切换服务器地址等场景：清空内存
  static clearAll(): void {
    HotFeedStore.slots.clear();
    HotFeedStore.lastEnsureTime = 0;
    HotFeedStore.serverOnline = true;
    HotFeedStore.bump();
  }

  private static setSlot(sourceId: string, slot: BoardSlot): void {
    HotFeedStore.slots.set(sourceId, slot);
  }
}

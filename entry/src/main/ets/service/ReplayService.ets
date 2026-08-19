// 智子 - 对局回放：事件录制 + 持久化 + 查询
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';

export class ReplayEvent {
  t: number;      // 距开局起点的毫秒偏移
  type: string;   // dir / spawn / food / tick / move / meta ...
  data: string;   // 事件参数（JSON 或逗号分隔字符串）

  constructor(t: number, type: string, data: string) {
    this.t = t;
    this.type = type;
    this.data = data;
  }
}

export class ReplayRecord {
  id: string;
  game: string;
  level: number;
  score: number;
  durationMs: number;
  eventsJson: string;
  metaJson: string;
  createdAt: number;

  constructor(id: string, game: string, level: number, score: number, durationMs: number,
    eventsJson: string, metaJson: string, createdAt: number) {
    this.id = id;
    this.game = game;
    this.level = level;
    this.score = score;
    this.durationMs = durationMs;
    this.eventsJson = eventsJson;
    this.metaJson = metaJson;
    this.createdAt = createdAt;
  }
}

// 单局录制器：游戏页面持有，随开局 start，随结束 finish 落库
export class ReplayRecorder {
  private startAt: number = 0;
  private events: ReplayEvent[] = [];

  start(): void {
    this.startAt = Date.now();
    this.events = [];
  }

  record(type: string, data: string): void {
    if (this.startAt === 0) return;
    this.events.push(new ReplayEvent(Date.now() - this.startAt, type, data));
  }

  cancel(): void {
    this.startAt = 0;
    this.events = [];
  }

  async finish(game: string, level: number, score: number, meta: string): Promise<void> {
    if (this.startAt === 0 || this.events.length === 0) {
      this.cancel();
      return;
    }
    const durationMs: number = Date.now() - this.startAt;
    await ReplayService.save(game, level, score, durationMs, this.events, meta);
    this.cancel();
  }
}

export class ReplayService {
  // 保存一局回放（事件序列 JSON 持久化）
  static async save(game: string, level: number, score: number, durationMs: number,
    events: ReplayEvent[], meta: string): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const id: string = 'rp-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const eventsJson: string = JSON.stringify(events);
    const bucket: relationalStore.ValuesBucket = {
      id: id,
      game: game,
      level: level,
      score: score,
      duration_ms: durationMs,
      events_json: eventsJson,
      meta_json: meta,
      created_at: Date.now()
    };
    await store.insert('game_replays', bucket);
  }

  // 列出某游戏（或全部）的回放，按时间倒序
  static async list(game?: string): Promise<ReplayRecord[]> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_replays');
    if (game !== undefined && game.length > 0) {
      predicates.equalTo('game', game);
    }
    predicates.orderByDesc('created_at');
    const results: ReplayRecord[] = [];
    try {
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ReplayService.readRecord(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  static async get(id: string): Promise<ReplayRecord | null> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_replays');
    predicates.equalTo('id', id);
    try {
      const resultSet = await store.query(predicates);
      if (resultSet.goToNextRow()) {
        const record: ReplayRecord = ReplayService.readRecord(resultSet);
        resultSet.close();
        return record;
      }
      resultSet.close();
    } catch (e) {
    }
    return null;
  }

  static async delete(id: string): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_replays');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  // 解析事件 JSON，非法时返回空数组
  static parseEvents(json: string): ReplayEvent[] {
    try {
      const arr: Object[] = JSON.parse(json) as Object[];
      const events: ReplayEvent[] = [];
      for (let i: number = 0; i < arr.length; i++) {
        const item: Record<string, Object> = arr[i] as Record<string, Object>;
        const t: number = typeof item.t === 'number' ? item.t as number : 0;
        const type: string = typeof item.type === 'string' ? item.type as string : '';
        const data: string = typeof item.data === 'string' ? item.data as string : '';
        if (type.length > 0) events.push(new ReplayEvent(t, type, data));
      }
      return events;
    } catch (e) {
      return [];
    }
  }

  private static readRecord(resultSet: relationalStore.ResultSet): ReplayRecord {
    return new ReplayRecord(
      resultSet.getString(resultSet.getColumnIndex('id')),
      resultSet.getString(resultSet.getColumnIndex('game')),
      resultSet.getLong(resultSet.getColumnIndex('level')),
      resultSet.getLong(resultSet.getColumnIndex('score')),
      resultSet.getLong(resultSet.getColumnIndex('duration_ms')),
      resultSet.getString(resultSet.getColumnIndex('events_json')),
      resultSet.getString(resultSet.getColumnIndex('meta_json')),
      resultSet.getLong(resultSet.getColumnIndex('created_at'))
    );
  }
}

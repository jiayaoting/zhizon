// 智子 - 排行榜服务（本地排行 + Game Service Kit 云端预留）
// 说明：HarmonyOS NEXT 的 Game Service Kit 排行榜 API 目前尚未在公开文档中开放，
// 因此当前实现为本地排行榜；待 AGC 游戏服务就绪后，在 submitToCloud 中接入云端提交。
import { DatabaseHelper, GameScoreRecord } from './DatabaseHelper';
import { DataRepository } from './DataRepository';

const KEY_CLOUD_ENABLED = 'leaderboardCloudEnabled';

export class LeaderboardEntry {
  rank: number;
  game: string;
  score: number;
  difficulty: string;
  model: string;
  createdAt: number;

  constructor(rank: number, game: string, score: number, difficulty: string, model: string,
    createdAt: number) {
    this.rank = rank;
    this.game = game;
    this.score = score;
    this.difficulty = difficulty;
    this.model = model;
    this.createdAt = createdAt;
  }
}

export class LeaderboardService {
  // 是否已启用云端排行榜（需 AGC Game Service 配置）
  static async cloudEnabled(): Promise<boolean> {
    const raw: string = await DataRepository.getSetting(KEY_CLOUD_ENABLED, 'false');
    return raw === 'true';
  }

  static async setCloudEnabled(enabled: boolean): Promise<void> {
    await DataRepository.setSetting(KEY_CLOUD_ENABLED, enabled ? 'true' : 'false');
  }

  // 本地排行榜：按分数倒序，同分按时间倒序
  static async localTop(game: string, limit: number): Promise<LeaderboardEntry[]> {
    const all: GameScoreRecord[] = await DatabaseHelper.getAllGameScores();
    const list: GameScoreRecord[] = [];
    for (let i: number = 0; i < all.length; i++) {
      if (game === 'all' || all[i].game === game) {
        list.push(all[i]);
      }
    }
    // 简单插入排序：score 降序，createdAt 降序
    const sorted: GameScoreRecord[] = [];
    for (let i: number = 0; i < list.length; i++) {
      const item: GameScoreRecord = list[i];
      let pos: number = 0;
      while (pos < sorted.length) {
        const cur: GameScoreRecord = sorted[pos];
        if (item.score > cur.score || (item.score === cur.score && item.createdAt > cur.createdAt)) {
          break;
        }
        pos += 1;
      }
      sorted.splice(pos, 0, item);
    }
    const entries: LeaderboardEntry[] = [];
    const n: number = Math.min(limit, sorted.length);
    for (let i: number = 0; i < n; i++) {
      const s: GameScoreRecord = sorted[i];
      entries.push(new LeaderboardEntry(i + 1, s.game, s.score, s.difficulty, s.model, s.createdAt));
    }
    return entries;
  }

  // 云端提交预留：接入 Game Service Kit 后在此调用 leaderboard 提交接口
  static async submitToCloud(game: string, score: number): Promise<void> {
    // TODO(AGC Game Service): 待 Game Service Kit 排行榜开放后，调用云端提交。
    // 本地战绩已在 addGameScore 中持久化，无需重复提交。
  }
}

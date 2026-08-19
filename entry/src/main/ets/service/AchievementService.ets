// 智子 - 成就服务：进度计算、解锁判定与持久化
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';
import { AchievementDefinition, AchievementState, ACHIEVEMENT_DEFINITIONS,
  achievementDefinition } from '../common/AchievementModels';
import { SoundService } from './SoundService';

export class AchievementService {
  // 确保所有成就都在表中有记录（缺省补 0 进度）
  static async ensureRows(): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    for (let i: number = 0; i < ACHIEVEMENT_DEFINITIONS.length; i++) {
      const def: AchievementDefinition = ACHIEVEMENT_DEFINITIONS[i];
      const predicates = new relationalStore.RdbPredicates('achievements');
      predicates.equalTo('id', def.id);
      const resultSet = await store.query(predicates);
      const exists: boolean = resultSet.goToNextRow();
      resultSet.close();
      if (!exists) {
        const bucket: relationalStore.ValuesBucket = {
          id: def.id,
          unlocked: 0,
          progress: 0,
          unlocked_at: 0
        };
        await store.insert('achievements', bucket);
      }
    }
  }

  // 读取全部成就状态（与定义合并，保持定义顺序）
  static async getAll(): Promise<AchievementState[]> {
    await AchievementService.ensureRows();
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const map: Record<string, AchievementState> = {};
    const predicates = new relationalStore.RdbPredicates('achievements');
    const resultSet = await store.query(predicates);
    while (resultSet.goToNextRow()) {
      const id: string = resultSet.getString(resultSet.getColumnIndex('id'));
      map[id] = new AchievementState(id,
        resultSet.getLong(resultSet.getColumnIndex('unlocked')) === 1,
        resultSet.getLong(resultSet.getColumnIndex('progress')),
        resultSet.getLong(resultSet.getColumnIndex('unlocked_at')));
    }
    resultSet.close();

    const states: AchievementState[] = [];
    for (let i: number = 0; i < ACHIEVEMENT_DEFINITIONS.length; i++) {
      const id: string = ACHIEVEMENT_DEFINITIONS[i].id;
      if (map[id] !== undefined) {
        states.push(map[id]);
      } else {
        states.push(new AchievementState(id, false, 0, 0));
      }
    }
    return states;
  }

  // 记录一局游戏（在 addGameScore 之后调用），返回本次新解锁的成就
  static async onGameScore(game: string, score: number): Promise<AchievementDefinition[]> {
    await AchievementService.ensureRows();
    const newly: AchievementDefinition[] = [];

    const totalGames: number = await DatabaseHelper.getGameCount();
    await AchievementService.collect('first_game', totalGames, false, newly);
    await AchievementService.collect('game_10', totalGames, false, newly);
    await AchievementService.collect('game_50', totalGames, false, newly);
    await AchievementService.collect('game_100', totalGames, false, newly);

    if (game === '2048') {
      await AchievementService.collect('score_2048_2048', score, true, newly);
    } else if (game === 'Snake') {
      await AchievementService.collect('snake_100', score, true, newly);
    } else if (game === 'Tetris') {
      await AchievementService.collect('tetris_1000', score, true, newly);
    } else if (game === 'Gomoku' && score > 0) {
      const wins: number = await DatabaseHelper.getGameWinCount('Gomoku');
      await AchievementService.collect('gomoku_win', wins, false, newly);
    } else if (game === 'ChineseChess' && score > 0) {
      const wins: number = await DatabaseHelper.getGameWinCount('ChineseChess');
      await AchievementService.collect('chess_win', wins, false, newly);
    }

    const aiHostCount: number = await DatabaseHelper.getAiHostCount();
    await AchievementService.collect('ai_host_1', aiHostCount, false, newly);
    await AchievementService.collect('ai_host_10', aiHostCount, false, newly);

    if (newly.length > 0) {
      SoundService.play('achievement');
    }
    return newly;
  }

  // 记录 AI 对话消息数（累计用户消息条数），返回本次新解锁的成就
  static async onChatMessages(count: number): Promise<AchievementDefinition[]> {
    await AchievementService.ensureRows();
    const newly: AchievementDefinition[] = [];
    await AchievementService.collect('chat_1', count, false, newly);
    await AchievementService.collect('chat_50', count, false, newly);
    await AchievementService.collect('chat_200', count, false, newly);
    if (newly.length > 0) {
      SoundService.play('achievement');
    }
    return newly;
  }

  // 云同步恢复：按 id 覆盖进度与解锁状态
  static async restoreAll(states: AchievementState[]): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    for (let i: number = 0; i < states.length; i++) {
      const s: AchievementState = states[i];
      const predicates = new relationalStore.RdbPredicates('achievements');
      predicates.equalTo('id', s.id);
      const bucket: relationalStore.ValuesBucket = {
        id: s.id,
        unlocked: s.unlocked ? 1 : 0,
        progress: s.progress,
        unlocked_at: s.unlockedAt
      };
      const resultSet = await store.query(predicates);
      const exists: boolean = resultSet.goToNextRow();
      resultSet.close();
      if (exists) {
        await store.update(bucket, predicates);
      } else {
        await store.insert('achievements', bucket);
      }
    }
  }

  // 计算并写入单个成就进度，若本次新解锁则追加到 newly
  private static async collect(id: string, value: number, maxMode: boolean,
    newly: AchievementDefinition[]): Promise<void> {
    const def: AchievementDefinition | null = achievementDefinition(id);
    if (def === null) return;

    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('achievements');
    predicates.equalTo('id', id);
    const resultSet = await store.query(predicates);
    let unlocked: boolean = false;
    let progress: number = 0;
    let unlockedAt: number = 0;
    if (resultSet.goToNextRow()) {
      unlocked = resultSet.getLong(resultSet.getColumnIndex('unlocked')) === 1;
      progress = resultSet.getLong(resultSet.getColumnIndex('progress'));
      unlockedAt = resultSet.getLong(resultSet.getColumnIndex('unlocked_at'));
    }
    resultSet.close();

    const next: number = maxMode ? Math.max(progress, value) : value;
    if (next === progress) return;

    const willUnlock: boolean = !unlocked && next >= def.target;
    if (willUnlock) {
      newly.push(def);
      unlockedAt = Date.now();
    }
    const bucket: relationalStore.ValuesBucket = {
      id: id,
      unlocked: willUnlock || unlocked ? 1 : 0,
      progress: next,
      unlocked_at: unlockedAt
    };
    await store.update(bucket, predicates);
  }
}

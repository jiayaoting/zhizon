// 智子 - 数据库管理（RDB Store）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AffectedFeature, DefectInput, DefectRecord, DefectSeverity, DefectStateHistory, DefectStatus, EvidenceConclusion, EvidenceType, FixEvidence, FixResult } from '../model/GovernanceModels';
import { NewsItem, NewsDigestEntry, NewsRating } from '../common/NewsModels';

export interface GameScoreRecord {
  game: string;
  id: string;
  score: number;
  level: number;
  difficulty: string;
  model: string;
  duration: number;
  aiThinkTime: number;
  createdAt: number;
}

export interface ScoreEntry {
  id: string;
  score: number;
  level: number;
  difficulty: string;
  // AI 托管时使用的模型显示名；非 AI 托管为空串
  model: string;
  // 本局游戏总耗时（秒）
  duration: number;
  // AI 托管累计思考总时长（秒）；非 AI 托管为 0
  aiThinkTime: number;
  createdAt: number;
}

export interface AiCallLogEntry {
  id: string;
  type: string;
  game: string;
  model: string;
  provider: string;
  startTime: number;
  endTime: number;
  durationMs: number;
  success: boolean;
  errorCode: string;
  errorMsg: string;
  promptChars: number;
  responseChars: number;
  // Token 消耗（服务端 usage，未返回时为 0）
  inputTokens: number;
  cachedTokens: number;
  outputTokens: number;
  totalTokens: number;
}

// 累计统计（独立于 ai_call_logs，删除模型/清空调用记录均不影响，只增不减）
export interface AiTokenStats {
  callCount: number;
  inputTokens: number;
  cachedTokens: number;
  outputTokens: number;
  totalTokens: number;
}

// 新闻收藏条目（news_favorites 行）
export interface NewsFavoriteEntry {
  id: string;
  url: string;
  title: string;
  summary: string;
  imageUrl: string;
  sourceName: string;
  addedAt: number;
}

// 新闻正文缓存条目（news_article_cache 行）
export interface NewsArticleCacheEntry {
  title: string;
  html: string;
}

// 赞/踩状态行（news_ratings 行）
export interface NewsRatingEntry {
  url: string;
  rating: number;
  itemId: string;
  title: string;
  summary: string;
  imageUrl: string;
  sourceName: string;
  category: string;
  publishedAt: number;
  tagsJson: string;
  updatedAt: number;
}

// 标签缓存行（news_tags 行）
export interface NewsTagEntry {
  url: string;
  tagsJson: string;
  sourceType: string;
  model: string;
  updatedAt: number;
}

// 翻译缓存行（news_translations 行）
export interface NewsTranslationEntry {
  url: string;
  kind: string;      // title / body
  langPair: string;  // en->zh / zh->en
  text: string;
  model: string;
  updatedAt: number;
}

const DB_NAME = 'zhizon.db';
const DB_VERSION = 15;
const DB_DOMAIN = 0x9201;

const SQL_CREATE_SETTINGS = `
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )
`;

const SQL_CREATE_GAME_SCORES = `
  CREATE TABLE IF NOT EXISTS game_scores (
    id TEXT PRIMARY KEY,
    game TEXT NOT NULL,
    score INTEGER NOT NULL,
    level INTEGER DEFAULT 1,
    difficulty TEXT DEFAULT '中等',
    model TEXT DEFAULT '',
    duration INTEGER DEFAULT 0,
    ai_think_time INTEGER DEFAULT 0,
    created_at INTEGER
  )
`;

const SQL_CREATE_DEFECTS = `CREATE TABLE IF NOT EXISTS defects (
  defect_key TEXT PRIMARY KEY, title TEXT NOT NULL, symptom TEXT NOT NULL, preconditions TEXT NOT NULL,
  steps TEXT NOT NULL, expected_behavior TEXT NOT NULL, actual_behavior TEXT NOT NULL, device_info TEXT,
  source TEXT, severity TEXT NOT NULL, status TEXT NOT NULL, priority INTEGER NOT NULL,
  affected_features TEXT NOT NULL, fix_result TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
)`;
const SQL_CREATE_DEFECT_EVIDENCE = `CREATE TABLE IF NOT EXISTS defect_evidence (
  evidence_id TEXT PRIMARY KEY, defect_key TEXT NOT NULL, evidence_type TEXT NOT NULL,
  conclusion TEXT NOT NULL, source TEXT, conditions TEXT NOT NULL, operator TEXT, recorded_at INTEGER NOT NULL
)`;
const SQL_CREATE_DEFECT_HISTORY = `CREATE TABLE IF NOT EXISTS defect_status_history (
  history_id TEXT PRIMARY KEY, defect_key TEXT NOT NULL, from_status TEXT NOT NULL,
  to_status TEXT NOT NULL, operator TEXT, trigger TEXT, evidence_id TEXT, recorded_at INTEGER NOT NULL
)`;
const SQL_CREATE_DEFECT_FIX_RESULTS = `CREATE TABLE IF NOT EXISTS defect_fix_results (
  defect_key TEXT PRIMARY KEY, scope TEXT NOT NULL, expected_behavior TEXT NOT NULL,
  failure_behavior TEXT NOT NULL, validation_conditions TEXT NOT NULL, residual_risks TEXT NOT NULL
)`;
const SQL_CREATE_AI_CALL_LOGS = `CREATE TABLE IF NOT EXISTS ai_call_logs (
  id TEXT PRIMARY KEY, type TEXT NOT NULL, game TEXT DEFAULT '', model TEXT DEFAULT '',
  provider TEXT DEFAULT '', start_time INTEGER NOT NULL, end_time INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL, success INTEGER NOT NULL, error_code TEXT DEFAULT '',
  error_msg TEXT DEFAULT '', prompt_chars INTEGER DEFAULT 0, response_chars INTEGER DEFAULT 0,
  input_tokens INTEGER DEFAULT 0, cached_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0, total_tokens INTEGER DEFAULT 0
)`;
// 旧版本升级：为 ai_call_logs 补充 token 消耗列（列已存在时忽略错误）
const SQL_ALTER_AI_CALL_LOGS = [
  'ALTER TABLE ai_call_logs ADD COLUMN input_tokens INTEGER DEFAULT 0',
  'ALTER TABLE ai_call_logs ADD COLUMN cached_tokens INTEGER DEFAULT 0',
  'ALTER TABLE ai_call_logs ADD COLUMN output_tokens INTEGER DEFAULT 0',
  'ALTER TABLE ai_call_logs ADD COLUMN total_tokens INTEGER DEFAULT 0'
];
// 累计统计表：仅一行（id='all'），删除模型/清空调用记录时不清理，只增不减
const SQL_CREATE_AI_TOKEN_STATS = `CREATE TABLE IF NOT EXISTS ai_token_stats (
  id TEXT PRIMARY KEY, call_count INTEGER DEFAULT 0, input_tokens INTEGER DEFAULT 0,
  cached_tokens INTEGER DEFAULT 0, output_tokens INTEGER DEFAULT 0, total_tokens INTEGER DEFAULT 0
)`;
// AI 对话多会话：会话表 + 消息表（v9）
const SQL_CREATE_CHAT_SESSIONS = `CREATE TABLE IF NOT EXISTS chat_sessions (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL, pinned INTEGER DEFAULT 0, active_model_id TEXT DEFAULT ''
)`;
const SQL_CREATE_CHAT_MESSAGES = `CREATE TABLE IF NOT EXISTS chat_messages (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL,
  reasoning TEXT DEFAULT '', time INTEGER NOT NULL, status TEXT DEFAULT 'ok',
  error_code TEXT DEFAULT '', error_msg TEXT DEFAULT '', model_id TEXT DEFAULT '',
  model_name TEXT DEFAULT '', input_tokens INTEGER DEFAULT 0, cached_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0, total_tokens INTEGER DEFAULT 0,
  image_data TEXT DEFAULT ''
)`;
const SQL_CREATE_CHAT_MSG_INDEX = `CREATE INDEX IF NOT EXISTS idx_chat_messages_session
  ON chat_messages (session_id, time)`;

// 成就系统（v12）
const SQL_CREATE_ACHIEVEMENTS = `CREATE TABLE IF NOT EXISTS achievements (
  id TEXT PRIMARY KEY, unlocked INTEGER DEFAULT 0, progress INTEGER DEFAULT 0,
  unlocked_at INTEGER DEFAULT 0
)`;

// 对局回放（v12）：events_json/meta_json 存 JSON 字符串
const SQL_CREATE_GAME_REPLAYS = `CREATE TABLE IF NOT EXISTS game_replays (
  id TEXT PRIMARY KEY, game TEXT NOT NULL, level INTEGER DEFAULT 1,
  score INTEGER DEFAULT 0, duration_ms INTEGER DEFAULT 0,
  events_json TEXT DEFAULT '', meta_json TEXT DEFAULT '',
  created_at INTEGER NOT NULL
)`;

// Agent 执行步骤（v13）
const SQL_CREATE_CHAT_AGENT_STEPS = `CREATE TABLE IF NOT EXISTS chat_agent_steps (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL, message_id TEXT DEFAULT '',
  step_index INTEGER DEFAULT 0, status TEXT DEFAULT 'done', tool_name TEXT DEFAULT '',
  args_json TEXT DEFAULT '', result_json TEXT DEFAULT '',
  started_at INTEGER NOT NULL, ended_at INTEGER NOT NULL
)`;

// 新闻资讯（v14）：收藏 / 已读 / AI 今日要闻缓存
const SQL_CREATE_NEWS_FAVORITES = `CREATE TABLE IF NOT EXISTS news_favorites (
  id TEXT PRIMARY KEY, url TEXT NOT NULL, title TEXT NOT NULL,
  summary TEXT DEFAULT '', image_url TEXT DEFAULT '', source_name TEXT DEFAULT '',
  added_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_READ = `CREATE TABLE IF NOT EXISTS news_read (
  url TEXT PRIMARY KEY, read_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_DIGESTS = `CREATE TABLE IF NOT EXISTS news_digests (
  id TEXT PRIMARY KEY, date TEXT NOT NULL, content TEXT NOT NULL,
  model_name TEXT DEFAULT '', created_at INTEGER NOT NULL
)`;
// 新闻频道快照缓存（离线阅读，v14）
const SQL_CREATE_NEWS_CACHE = `CREATE TABLE IF NOT EXISTS news_cache (
  channel_id TEXT PRIMARY KEY, items_json TEXT NOT NULL, cached_at INTEGER NOT NULL
)`;
// 新闻正文缓存（离线全文阅读，v14）
const SQL_CREATE_NEWS_ARTICLE_CACHE = `CREATE TABLE IF NOT EXISTS news_article_cache (
  url TEXT PRIMARY KEY, title TEXT NOT NULL, html TEXT NOT NULL, cached_at INTEGER NOT NULL
)`;
// 个性化推荐（v15）：标签缓存 / 赞踩状态 / 行为流水 / 单篇排除 / 画像快照 / 翻译缓存
const SQL_CREATE_NEWS_TAGS = `CREATE TABLE IF NOT EXISTS news_tags (
  url TEXT PRIMARY KEY, tags_json TEXT NOT NULL, source_type TEXT DEFAULT 'rule',
  model TEXT DEFAULT '', updated_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_RATINGS = `CREATE TABLE IF NOT EXISTS news_ratings (
  url TEXT PRIMARY KEY, rating INTEGER NOT NULL, item_id TEXT DEFAULT '',
  title TEXT NOT NULL, summary TEXT DEFAULT '', image_url TEXT DEFAULT '',
  source_name TEXT DEFAULT '', category TEXT DEFAULT '', published_at INTEGER DEFAULT 0,
  tags_json TEXT DEFAULT '', updated_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_EVENTS = `CREATE TABLE IF NOT EXISTS news_events (
  id TEXT PRIMARY KEY, url TEXT NOT NULL, item_id TEXT DEFAULT '',
  event_type TEXT NOT NULL, weight REAL DEFAULT 0, extra_json TEXT DEFAULT '',
  occurred_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_EVENTS_URL_IDX = 'CREATE INDEX IF NOT EXISTS idx_news_events_url ON news_events(url)';
const SQL_CREATE_NEWS_EVENTS_TIME_IDX = 'CREATE INDEX IF NOT EXISTS idx_news_events_time ON news_events(occurred_at)';
const SQL_CREATE_NEWS_EXCLUSIONS = `CREATE TABLE IF NOT EXISTS news_exclusions (
  type TEXT NOT NULL, value TEXT NOT NULL, reason TEXT DEFAULT '',
  created_at INTEGER NOT NULL, PRIMARY KEY (type, value)
)`;
const SQL_CREATE_NEWS_PROFILE = `CREATE TABLE IF NOT EXISTS news_profile (
  key TEXT PRIMARY KEY, value_json TEXT NOT NULL, updated_at INTEGER NOT NULL
)`;
const SQL_CREATE_NEWS_TRANSLATIONS = `CREATE TABLE IF NOT EXISTS news_translations (
  url TEXT PRIMARY KEY, kind TEXT NOT NULL, lang_pair TEXT NOT NULL,
  text TEXT NOT NULL, model TEXT DEFAULT '', updated_at INTEGER NOT NULL
)`;

export class DatabaseHelper {
  private static store: relationalStore.RdbStore | null = null;

  // 初始化数据库
  static async init(context: common.Context): Promise<void> {
    if (DatabaseHelper.store) return;

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    DatabaseHelper.store = await relationalStore.getRdbStore(context, config);

    // 创建表
    await DatabaseHelper.store.executeSql(SQL_CREATE_SETTINGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_GAME_SCORES);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_EVIDENCE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_HISTORY);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_FIX_RESULTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_AI_CALL_LOGS);
    if (DatabaseHelper.store.version < 5) {
      // 旧库升级：为 ai_call_logs 补齐 token 消耗列（新库建表已含，会命中重复列错误并忽略）
      for (let i: number = 0; i < SQL_ALTER_AI_CALL_LOGS.length; i++) {
        try {
          await DatabaseHelper.store.executeSql(SQL_ALTER_AI_CALL_LOGS[i]);
        } catch (e) {
        }
      }
    }
    if (DatabaseHelper.store.version < 7) {
      // 旧库升级：为 game_scores 补齐 model 列（新库建表已含，会命中重复列错误并忽略）
      try {
        await DatabaseHelper.store.executeSql("ALTER TABLE game_scores ADD COLUMN model TEXT DEFAULT ''");
      } catch (e) {
      }
    }
    if (DatabaseHelper.store.version < 8) {
      // 旧库升级：为 game_scores 补齐 duration 列（新库建表已含，会命中重复列错误并忽略）
      try {
        await DatabaseHelper.store.executeSql("ALTER TABLE game_scores ADD COLUMN duration INTEGER DEFAULT 0");
      } catch (e) {
      }
    }
    if (DatabaseHelper.store.version < 11) {
      // 旧库升级：为 game_scores 补齐 AI 思考总时长列（新库建表已含，会命中重复列错误并忽略）
      try {
        await DatabaseHelper.store.executeSql("ALTER TABLE game_scores ADD COLUMN ai_think_time INTEGER DEFAULT 0");
      } catch (e) {
      }
    }
    // 累计统计表：独立于 ai_call_logs，清空调用记录不影响
    await DatabaseHelper.store.executeSql(SQL_CREATE_AI_TOKEN_STATS);
    // AI 对话多会话表（v9/v10）
    await DatabaseHelper.store.executeSql(SQL_CREATE_CHAT_SESSIONS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_CHAT_MESSAGES);
    await DatabaseHelper.store.executeSql(SQL_CREATE_CHAT_MSG_INDEX);
    // 成就 + 对局回放（v12，CREATE IF NOT EXISTS 保证幂等）
    await DatabaseHelper.store.executeSql(SQL_CREATE_ACHIEVEMENTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_GAME_REPLAYS);
    // Agent 执行步骤（v13）
    await DatabaseHelper.store.executeSql(SQL_CREATE_CHAT_AGENT_STEPS);
    // 新闻资讯（v14）
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_FAVORITES);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_READ);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_DIGESTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_CACHE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_ARTICLE_CACHE);
    // 个性化推荐（v15）
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_TAGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_RATINGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS_URL_IDX);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS_TIME_IDX);
    // 行为流水 90 天自动清理（画像已落快照，事件仅用于审计/重算）
    try {
      const cutoff: number = Date.now() - 90 * 24 * 3600 * 1000;
      await DatabaseHelper.store.executeSql('DELETE FROM news_events WHERE occurred_at < ' + cutoff.toString());
    } catch (e) {
    }
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EXCLUSIONS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_PROFILE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_TRANSLATIONS);
    if (DatabaseHelper.store.version < 10) {
      // 旧库升级：为 chat_messages 补齐图片附件列（新库建表已含，重复列错误被忽略）
      try {
        await DatabaseHelper.store.executeSql("ALTER TABLE chat_messages ADD COLUMN image_data TEXT DEFAULT ''");
      } catch (e) {
      }
    }
    // 旧库升级：为 ai_token_stats 补齐可能缺失的列（新库建表已含，会命中重复列错误并忽略）
    const tokenStatAlters: string[] = [
      'ALTER TABLE ai_token_stats ADD COLUMN call_count INTEGER DEFAULT 0',
      'ALTER TABLE ai_token_stats ADD COLUMN input_tokens INTEGER DEFAULT 0',
      'ALTER TABLE ai_token_stats ADD COLUMN cached_tokens INTEGER DEFAULT 0',
      'ALTER TABLE ai_token_stats ADD COLUMN output_tokens INTEGER DEFAULT 0',
      'ALTER TABLE ai_token_stats ADD COLUMN total_tokens INTEGER DEFAULT 0'
    ];
    for (let i: number = 0; i < tokenStatAlters.length; i++) {
      try {
        await DatabaseHelper.store.executeSql(tokenStatAlters[i]);
      } catch (e) {
      }
    }
    await DatabaseHelper.initTokenStats();
    if (DatabaseHelper.store.version < DB_VERSION) {
      DatabaseHelper.store.version = DB_VERSION;
    }
  }

  static getStore(): relationalStore.RdbStore {
    if (!DatabaseHelper.store) throw new Error('Database not initialized');
    return DatabaseHelper.store;
  }

  // ========== 游戏战绩 ==========

  static async addGameScore(game: string, score: number, level: number, difficulty: string,
    model: string = '', duration: number = 0, aiThinkTime: number = 0): Promise<void> {
    const store = DatabaseHelper.getStore();
    const id: string = 'gs-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const valueBucket: relationalStore.ValuesBucket = {
      id: id,
      game: game,
      score: score,
      level: level,
      difficulty: difficulty,
      model: model,
      duration: duration,
      ai_think_time: aiThinkTime,
      created_at: Date.now()
    };
    await store.insert('game_scores', valueBucket);
  }

  static async getGameScores(game: string, limit: number = 50): Promise<ScoreEntry[]> {
    const store = DatabaseHelper.getStore();
    const results: ScoreEntry[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('game_scores');
      predicates.equalTo('game', game);
      predicates.orderByDesc('score');
      predicates.limitAs(limit);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          score: resultSet.getLong(resultSet.getColumnIndex('score')),
          level: resultSet.getLong(resultSet.getColumnIndex('level')),
          difficulty: resultSet.getString(resultSet.getColumnIndex('difficulty')),
          model: resultSet.getString(resultSet.getColumnIndex('model')),
          duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
          aiThinkTime: resultSet.getLong(resultSet.getColumnIndex('ai_think_time')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        } as ScoreEntry);
      }
      resultSet.close();
    } catch (e) {
      hilog.error(DB_DOMAIN, 'DatabaseHelper', '%{public}s', 'getGameScores failed');
    }
    return results;
  }

  static async getGameHighScore(game: string): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('game_scores');
      predicates.equalTo('game', game);
      predicates.orderByDesc('score');
      predicates.limitAs(1);
      const resultSet = await store.query(predicates);
      let high: number = 0;
      if (resultSet.goToNextRow()) {
        high = resultSet.getLong(resultSet.getColumnIndex('score'));
      }
      resultSet.close();
      return high;
    } catch (e) {
      return 0;
    }
  }

  static async deleteGameScore(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_scores');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  static async clearGameScores(game: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_scores');
    predicates.equalTo('game', game);
    await store.delete(predicates);
  }

  // ========== 统计计数（成就系统） ==========

  static async getGameCount(): Promise<number> {
    return await DatabaseHelper.countRows('game_scores', '');
  }

  static async getGameWinCount(game: string): Promise<number> {
    return await DatabaseHelper.countRows('game_scores', game);
  }

  static async getAiHostCount(): Promise<number> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_scores');
    predicates.notEqualTo('model', '');
    try {
      const resultSet = await store.query(predicates);
      let count: number = 0;
      while (resultSet.goToNextRow()) count += 1;
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  static async getChatMessageCount(): Promise<number> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('chat_messages');
    predicates.equalTo('role', 'user');
    try {
      const resultSet = await store.query(predicates);
      let count: number = 0;
      while (resultSet.goToNextRow()) count += 1;
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  private static async countRows(table: string, winGame: string): Promise<number> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates(table);
    if (winGame.length > 0) {
      predicates.equalTo('game', winGame);
      predicates.greaterThan('score', 0);
    }
    try {
      const resultSet = await store.query(predicates);
      let count: number = 0;
      while (resultSet.goToNextRow()) count += 1;
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ========== 云同步导出/恢复辅助 ==========

  static async getAllSettings(): Promise<Record<string, string>> {
    const store = DatabaseHelper.getStore();
    const result: Record<string, string> = {};
    try {
      const predicates = new relationalStore.RdbPredicates('settings');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        result[resultSet.getString(resultSet.getColumnIndex('key'))] =
          resultSet.getString(resultSet.getColumnIndex('value'));
      }
      resultSet.close();
    } catch (e) {
    }
    return result;
  }

  static async replaceAllSettings(settings: Record<string, string>): Promise<void> {
    const store = DatabaseHelper.getStore();
    await store.beginTransaction();
    try {
      await store.delete(new relationalStore.RdbPredicates('settings'));
      const keys: string[] = Object.keys(settings);
      for (let i: number = 0; i < keys.length; i++) {
        const bucket: relationalStore.ValuesBucket = {
          key: keys[i],
          value: settings[keys[i]]
        };
        await store.insert('settings', bucket);
      }
      await store.commit();
    } catch (e) {
      await store.rollBack();
    }
  }

  static async getAllGameScores(): Promise<GameScoreRecord[]> {
    const store = DatabaseHelper.getStore();
    const results: GameScoreRecord[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('game_scores');
      predicates.orderByDesc('created_at');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push({
          game: resultSet.getString(resultSet.getColumnIndex('game')),
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          score: resultSet.getLong(resultSet.getColumnIndex('score')),
          level: resultSet.getLong(resultSet.getColumnIndex('level')),
          difficulty: resultSet.getString(resultSet.getColumnIndex('difficulty')),
          model: resultSet.getString(resultSet.getColumnIndex('model')),
          duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
          aiThinkTime: resultSet.getLong(resultSet.getColumnIndex('ai_think_time')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        } as GameScoreRecord);
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  static async clearGameScoresAll(): Promise<void> {
    const store = DatabaseHelper.getStore();
    await store.delete(new relationalStore.RdbPredicates('game_scores'));
  }

  static async insertGameScoreRaw(game: string, entry: ScoreEntry): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {
      id: entry.id,
      game: game,
      score: entry.score,
      level: entry.level,
      difficulty: entry.difficulty,
      model: entry.model,
      duration: entry.duration,
      ai_think_time: entry.aiThinkTime,
      created_at: entry.createdAt
    };
    await store.insert('game_scores', bucket);
  }

  // 从云备份 JSON 对象解析战绩条目
  static scoreFromCloud(item: Record<string, Object>): ScoreEntry {
    const num = (v: Object, fallback: number): number => typeof v === 'number' ? v as number : fallback;
    const str = (v: Object, fallback: string): string => typeof v === 'string' ? v as string : fallback;
    return {
      id: str(item['id'], 'gs-' + Date.now().toString(36)),
      score: num(item['score'], 0),
      level: num(item['level'], 1),
      difficulty: str(item['difficulty'], '中等'),
      model: str(item['model'], ''),
      duration: num(item['duration'], 0),
      aiThinkTime: num(item['aiThinkTime'], 0),
      createdAt: num(item['createdAt'], Date.now())
    } as ScoreEntry;
  }

  // ========== Agent 执行步骤（v13，追加保存，P0 仅落库不做查询） ==========

  static async addAgentStep(sessionId: string, messageId: string, stepIndex: number, status: string,
    toolName: string, argsJson: string, resultJson: string, startedAt: number, endedAt: number): Promise<void> {
    const store = DatabaseHelper.getStore();
    const id: string = 'ags-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const bucket: relationalStore.ValuesBucket = {
      id: id,
      session_id: sessionId,
      message_id: messageId,
      step_index: stepIndex,
      status: status,
      tool_name: toolName,
      args_json: argsJson,
      result_json: resultJson,
      started_at: startedAt,
      ended_at: endedAt
    };
    try {
      await store.insert('chat_agent_steps', bucket);
    } catch (e) {
    }
  }

  // ========== 缺陷记录（只允许追加历史，不提供物理删除） ==========

  static async saveDefect(record: DefectRecord): Promise<void> {
    const store = DatabaseHelper.getStore();
    await store.beginTransaction();
    try {
      await store.insert('defects', DatabaseHelper.defectBucket(record));
      if (record.fixResult !== null) await DatabaseHelper.saveFixResultInTransaction(store, record.defectKey, record.fixResult);
      for (const evidence of record.evidence) await store.insert('defect_evidence', DatabaseHelper.evidenceBucket(record.defectKey, evidence));
      await store.commit();
    } catch (e) {
      await store.rollBack();
      throw new Error('PERSISTENCE_FAILED');
    }
  }

  static async getDefect(defectKey: string): Promise<DefectRecord | null> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('defects'); predicates.equalTo('defect_key', defectKey);
    const resultSet = await store.query(predicates);
    let record: DefectRecord | null = null;
    try {
      if (resultSet.goToNextRow()) record = DatabaseHelper.readDefect(resultSet);
    } finally { resultSet.close(); }
    if (record === null) return null;
    record.evidence = await DatabaseHelper.getDefectEvidence(defectKey);
    record.fixResult = await DatabaseHelper.getFixResult(defectKey);
    return record;
  }

  static async updateDefect(record: DefectRecord): Promise<void> {
    const store = DatabaseHelper.getStore(); const predicates = new relationalStore.RdbPredicates('defects'); predicates.equalTo('defect_key', record.defectKey);
    await store.beginTransaction();
    try {
      const changed: number = await store.update(DatabaseHelper.defectBucket(record), predicates);
      if (changed !== 1) throw new Error('DEFECT_NOT_FOUND');
      if (record.fixResult !== null) await DatabaseHelper.saveFixResultInTransaction(store, record.defectKey, record.fixResult);
      await store.commit();
    } catch (e) { await store.rollBack(); throw new Error('PERSISTENCE_FAILED'); }
  }

  static async appendEvidence(record: DefectRecord, evidence: FixEvidence): Promise<void> {
    const store = DatabaseHelper.getStore(); const predicates = new relationalStore.RdbPredicates('defects'); predicates.equalTo('defect_key', record.defectKey);
    await store.beginTransaction();
    try {
      await store.insert('defect_evidence', DatabaseHelper.evidenceBucket(record.defectKey, evidence));
      const bucket: relationalStore.ValuesBucket = { updated_at: record.updatedAt };
      const changed: number = await store.update(bucket, predicates); if (changed !== 1) throw new Error('DEFECT_NOT_FOUND');
      await store.commit();
    } catch (e) { await store.rollBack(); throw new Error('PERSISTENCE_FAILED'); }
  }

  static async appendDefectHistory(history: DefectStateHistory): Promise<void> {
    const bucket: relationalStore.ValuesBucket = { history_id: history.id, defect_key: history.defectKey, from_status: history.fromStatus, to_status: history.toStatus, operator: history.operator, trigger: history.trigger, evidence_id: history.evidenceId, recorded_at: history.recordedAt };
    try { await DatabaseHelper.getStore().insert('defect_status_history', bucket); } catch (e) { throw new Error('PERSISTENCE_FAILED'); }
  }

  static async transitionDefect(record: DefectRecord, history: DefectStateHistory, evidence: FixEvidence | null): Promise<void> {
    const store = DatabaseHelper.getStore(); const predicates = new relationalStore.RdbPredicates('defects'); predicates.equalTo('defect_key', record.defectKey);
    const historyBucket: relationalStore.ValuesBucket = { history_id: history.id, defect_key: history.defectKey, from_status: history.fromStatus, to_status: history.toStatus, operator: history.operator, trigger: history.trigger, evidence_id: history.evidenceId, recorded_at: history.recordedAt };
    await store.beginTransaction();
    try {
      const changed: number = await store.update(DatabaseHelper.defectBucket(record), predicates); if (changed !== 1) throw new Error('DEFECT_NOT_FOUND');
      if (evidence !== null) await store.insert('defect_evidence', DatabaseHelper.evidenceBucket(record.defectKey, evidence));
      await store.insert('defect_status_history', historyBucket);
      await store.commit();
    } catch (e) { await store.rollBack(); throw new Error('PERSISTENCE_FAILED'); }
  }

  private static defectBucket(record: DefectRecord): relationalStore.ValuesBucket {
    return { defect_key: record.defectKey, title: record.title, symptom: record.symptom, preconditions: JSON.stringify(record.preconditions), steps: JSON.stringify(record.steps), expected_behavior: record.expectedBehavior, actual_behavior: record.actualBehavior, device_info: record.deviceInfo, source: record.source, severity: record.severity, status: record.status, priority: record.priority, affected_features: JSON.stringify(record.affectedFeatures), fix_result: '', created_at: record.createdAt, updated_at: record.updatedAt };
  }
  private static evidenceBucket(defectKey: string, evidence: FixEvidence): relationalStore.ValuesBucket { return { evidence_id: evidence.id, defect_key: defectKey, evidence_type: evidence.type, conclusion: evidence.conclusion, source: evidence.source, conditions: JSON.stringify(evidence.conditions), operator: evidence.operator, recorded_at: evidence.recordedAt }; }
  private static readDefect(resultSet: relationalStore.ResultSet): DefectRecord {
    const input = new DefectInput(resultSet.getString(resultSet.getColumnIndex('title')), resultSet.getString(resultSet.getColumnIndex('symptom')), DatabaseHelper.parseStringArray(resultSet.getString(resultSet.getColumnIndex('preconditions'))), DatabaseHelper.parseStringArray(resultSet.getString(resultSet.getColumnIndex('steps'))), resultSet.getString(resultSet.getColumnIndex('expected_behavior')), resultSet.getString(resultSet.getColumnIndex('actual_behavior')), resultSet.getString(resultSet.getColumnIndex('device_info')), resultSet.getString(resultSet.getColumnIndex('source')), DatabaseHelper.parseFeatures(resultSet.getString(resultSet.getColumnIndex('affected_features'))));
    const record = new DefectRecord(resultSet.getString(resultSet.getColumnIndex('defect_key')), input, resultSet.getString(resultSet.getColumnIndex('severity')) as DefectSeverity, resultSet.getString(resultSet.getColumnIndex('status')) as DefectStatus, resultSet.getLong(resultSet.getColumnIndex('priority')), [], null, resultSet.getLong(resultSet.getColumnIndex('created_at'))); record.updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at')); return record;
  }
  private static async getDefectEvidence(defectKey: string): Promise<FixEvidence[]> { const store = DatabaseHelper.getStore(); const predicates = new relationalStore.RdbPredicates('defect_evidence'); predicates.equalTo('defect_key', defectKey); predicates.orderByAsc('recorded_at'); const rs = await store.query(predicates); const items: FixEvidence[] = []; try { while (rs.goToNextRow()) items.push(new FixEvidence(rs.getString(rs.getColumnIndex('evidence_id')), rs.getString(rs.getColumnIndex('evidence_type')) as EvidenceType, rs.getString(rs.getColumnIndex('conclusion')) as EvidenceConclusion, rs.getString(rs.getColumnIndex('source')), DatabaseHelper.parseStringArray(rs.getString(rs.getColumnIndex('conditions'))), rs.getLong(rs.getColumnIndex('recorded_at')), rs.getString(rs.getColumnIndex('operator')))); } finally { rs.close(); } return items; }
  private static async saveFixResultInTransaction(store: relationalStore.RdbStore, defectKey: string, result: FixResult): Promise<void> { const predicates = new relationalStore.RdbPredicates('defect_fix_results'); predicates.equalTo('defect_key', defectKey); const existing = await store.query(predicates); let found = false; try { found = existing.goToNextRow(); } finally { existing.close(); } const bucket: relationalStore.ValuesBucket = { defect_key: defectKey, scope: JSON.stringify(result.scope), expected_behavior: result.expectedBehavior, failure_behavior: result.failureBehavior, validation_conditions: JSON.stringify(result.validationConditions), residual_risks: JSON.stringify(result.residualRisks) }; if (found) await store.update(bucket, predicates); else await store.insert('defect_fix_results', bucket); }
  private static async getFixResult(defectKey: string): Promise<FixResult | null> { const predicates = new relationalStore.RdbPredicates('defect_fix_results'); predicates.equalTo('defect_key', defectKey); const rs = await DatabaseHelper.getStore().query(predicates); try { if (!rs.goToNextRow()) return null; return new FixResult(DatabaseHelper.parseFeatures(rs.getString(rs.getColumnIndex('scope'))), rs.getString(rs.getColumnIndex('expected_behavior')), rs.getString(rs.getColumnIndex('failure_behavior')), DatabaseHelper.parseStringArray(rs.getString(rs.getColumnIndex('validation_conditions'))), DatabaseHelper.parseStringArray(rs.getString(rs.getColumnIndex('residual_risks')))); } finally { rs.close(); } }
  private static parseStringArray(raw: string): string[] { try { const parsed: Object = JSON.parse(raw); if (Array.isArray(parsed)) { return parsed as string[]; } return []; } catch (e) { return []; } }
  private static parseFeatures(raw: string): AffectedFeature[] { try { const parsed: Object = JSON.parse(raw); if (Array.isArray(parsed)) { return parsed as AffectedFeature[]; } return []; } catch (e) { return []; } }

  // ========== 设置 ==========

  static async getSetting(key: string, defaultValue: string = ''): Promise<string> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('settings');
    predicates.equalTo('key', key);
    const resultSet = await store.query(predicates);
    if (resultSet.goToNextRow()) {
      const val = resultSet.getString(resultSet.getColumnIndex('value'));
      resultSet.close();
      return val || defaultValue;
    }
    resultSet.close();
    return defaultValue;
  }

  static async setSetting(key: string, value: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('settings');
    predicates.equalTo('key', key);
    const resultSet = await store.query(predicates);
    if (resultSet.goToNextRow()) {
      resultSet.close();
      const bucket: relationalStore.ValuesBucket = { value: value };
      await store.update(bucket, predicates);
    } else {
      resultSet.close();
      const bucket: relationalStore.ValuesBucket = { key: key, value: value };
      await store.insert('settings', bucket);
    }
  }

  static async setPreferenceSettings(themeValue: string, backgroundValue: string,
    colorThemeValue: string, fontSizeValue: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    await store.beginTransaction();
    try {
      await DatabaseHelper.setSettingInTransaction(store, 'themePreference', themeValue);
      await DatabaseHelper.setSettingInTransaction(store, 'globalBackgroundPreference', backgroundValue);
      await DatabaseHelper.setSettingInTransaction(store, 'colorTheme', colorThemeValue);
      await DatabaseHelper.setSettingInTransaction(store, 'fontSizeScale', fontSizeValue);
      await store.commit();
    } catch (e) { await store.rollBack(); throw new Error('PERSISTENCE_FAILED'); }
  }

  private static async setSettingInTransaction(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('settings'); predicates.equalTo('key', key);
    const resultSet = await store.query(predicates); let exists: boolean = false;
    try { exists = resultSet.goToNextRow(); } finally { resultSet.close(); }
    const bucket: relationalStore.ValuesBucket = { key: key, value: value };
    if (exists) await store.update(bucket, predicates); else await store.insert('settings', bucket);
  }

  // ========== AI 调用日志 ==========

  static async insertAiCallLog(entry: AiCallLogEntry): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {
      id: entry.id,
      type: entry.type,
      game: entry.game,
      model: entry.model,
      provider: entry.provider,
      start_time: entry.startTime,
      end_time: entry.endTime,
      duration_ms: entry.durationMs,
      success: entry.success ? 1 : 0,
      error_code: entry.errorCode,
      error_msg: entry.errorMsg,
      prompt_chars: entry.promptChars,
      response_chars: entry.responseChars,
      input_tokens: entry.inputTokens,
      cached_tokens: entry.cachedTokens,
      output_tokens: entry.outputTokens,
      total_tokens: entry.totalTokens
    };
    // 日志与累计统计分开写入（不使用事务内嵌套读-改-写，RDB 事务内 query 不可靠）：
    // 各自独立容错，任一步失败不影响另一步；统计只增不减，独立于调用记录（清空日志不影响）
    try {
      await store.insert('ai_call_logs', bucket);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'AiCallLogger', 'AI 调用日志写入失败 %{public}s', (e as Error).message);
      return;
    }
    try {
      await DatabaseHelper.accumulateTokenStats(store, entry.inputTokens, entry.cachedTokens,
        entry.outputTokens, entry.totalTokens);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'AiCallLogger', 'AI 调用统计累加失败 %{public}s', (e as Error).message);
    }
  }

  // 初始化累计统计：统计行不存在时从历史 ai_call_logs 汇总一次（升级/新装均安全，幂等）
  private static async initTokenStats(): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('ai_token_stats');
    predicates.equalTo('id', 'all');
    const existing = await store.query(predicates);
    let found: boolean = false;
    try {
      found = existing.goToNextRow();
    } finally {
      existing.close();
    }
    if (found) return;
    let count: number = 0;
    let input: number = 0;
    let cached: number = 0;
    let output: number = 0;
    let total: number = 0;
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS cnt, ' +
        'COALESCE(SUM(input_tokens),0) AS inp, COALESCE(SUM(cached_tokens),0) AS cached, ' +
        'COALESCE(SUM(output_tokens),0) AS out, COALESCE(SUM(total_tokens),0) AS tot FROM ai_call_logs');
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
          input = resultSet.getLong(resultSet.getColumnIndex('inp'));
          cached = resultSet.getLong(resultSet.getColumnIndex('cached'));
          output = resultSet.getLong(resultSet.getColumnIndex('out'));
          total = resultSet.getLong(resultSet.getColumnIndex('tot'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    const bucket: relationalStore.ValuesBucket = {
      id: 'all',
      call_count: count,
      input_tokens: input,
      cached_tokens: cached,
      output_tokens: output,
      total_tokens: total
    };
    try {
      await store.insert('ai_token_stats', bucket);
    } catch (e) {
    }
  }

  // 累加累计统计：调用次数 +1，各 token 字段累加（行不存在时先创建）
  // 非事务读-改-写，与项目其他数据库读写路径一致
  private static async accumulateTokenStats(store: relationalStore.RdbStore, input: number,
    cached: number, output: number, total: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('ai_token_stats');
    predicates.equalTo('id', 'all');
    const resultSet = await store.query(predicates);
    let count: number = 0;
    let inputTokens: number = 0;
    let cachedTokens: number = 0;
    let outputTokens: number = 0;
    let totalTokens: number = 0;
    let found: boolean = false;
    try {
      found = resultSet.goToNextRow();
      if (found) {
        count = resultSet.getLong(resultSet.getColumnIndex('call_count'));
        inputTokens = resultSet.getLong(resultSet.getColumnIndex('input_tokens'));
        cachedTokens = resultSet.getLong(resultSet.getColumnIndex('cached_tokens'));
        outputTokens = resultSet.getLong(resultSet.getColumnIndex('output_tokens'));
        totalTokens = resultSet.getLong(resultSet.getColumnIndex('total_tokens'));
      }
    } finally {
      resultSet.close();
    }
    const bucket: relationalStore.ValuesBucket = {
      id: 'all',
      call_count: count + 1,
      input_tokens: inputTokens + input,
      cached_tokens: cachedTokens + cached,
      output_tokens: outputTokens + output,
      total_tokens: totalTokens + total
    };
    if (found) {
      await store.update(bucket, predicates);
    } else {
      await store.insert('ai_token_stats', bucket);
    }
  }

  // 读取累计统计（调用次数 / 输入总 Token / 输入缓存 Token / 输出 Token / 总 Token）
  // 自愈：统计表缺失或统计行为空时，自动建表并从历史日志汇总，保证统计不会丢失
  static async getAiTokenStats(): Promise<AiTokenStats> {
    const store = DatabaseHelper.getStore();
    let exists: boolean = false;
    try {
      const predicates = new relationalStore.RdbPredicates('ai_token_stats');
      predicates.equalTo('id', 'all');
      const resultSet = await store.query(predicates);
      try {
        exists = resultSet.goToNextRow();
      } finally {
        resultSet.close();
      }
    } catch (e) {
      // 统计表缺失（异常兜底）：重建表
      try {
        await store.executeSql(SQL_CREATE_AI_TOKEN_STATS);
      } catch (e2) {
      }
    }
    if (!exists) {
      // 统计行为空：从历史日志汇总一次
      await DatabaseHelper.initTokenStats();
    }
    // 重新读取统计（自愈后返回最新值）
    return await DatabaseHelper.readTokenStats(store);
  }

  // 纯读取累计统计行（不存在时返回全 0）
  private static async readTokenStats(store: relationalStore.RdbStore): Promise<AiTokenStats> {
    const stats: AiTokenStats = {
      callCount: 0,
      inputTokens: 0,
      cachedTokens: 0,
      outputTokens: 0,
      totalTokens: 0
    };
    try {
      const predicates = new relationalStore.RdbPredicates('ai_token_stats');
      predicates.equalTo('id', 'all');
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          stats.callCount = resultSet.getLong(resultSet.getColumnIndex('call_count'));
          stats.inputTokens = resultSet.getLong(resultSet.getColumnIndex('input_tokens'));
          stats.cachedTokens = resultSet.getLong(resultSet.getColumnIndex('cached_tokens'));
          stats.outputTokens = resultSet.getLong(resultSet.getColumnIndex('output_tokens'));
          stats.totalTokens = resultSet.getLong(resultSet.getColumnIndex('total_tokens'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return stats;
  }

  static async queryAiCallLogs(limit: number): Promise<AiCallLogEntry[]> {
    const store = DatabaseHelper.getStore();
    const results: AiCallLogEntry[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('ai_call_logs');
      predicates.orderByDesc('start_time');
      predicates.limitAs(limit);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          type: resultSet.getString(resultSet.getColumnIndex('type')),
          game: resultSet.getString(resultSet.getColumnIndex('game')),
          model: resultSet.getString(resultSet.getColumnIndex('model')),
          provider: resultSet.getString(resultSet.getColumnIndex('provider')),
          startTime: resultSet.getLong(resultSet.getColumnIndex('start_time')),
          endTime: resultSet.getLong(resultSet.getColumnIndex('end_time')),
          durationMs: resultSet.getLong(resultSet.getColumnIndex('duration_ms')),
          success: resultSet.getLong(resultSet.getColumnIndex('success')) === 1,
          errorCode: resultSet.getString(resultSet.getColumnIndex('error_code')),
          errorMsg: resultSet.getString(resultSet.getColumnIndex('error_msg')),
          promptChars: resultSet.getLong(resultSet.getColumnIndex('prompt_chars')),
          responseChars: resultSet.getLong(resultSet.getColumnIndex('response_chars')),
          inputTokens: resultSet.getLong(resultSet.getColumnIndex('input_tokens')),
          cachedTokens: resultSet.getLong(resultSet.getColumnIndex('cached_tokens')),
          outputTokens: resultSet.getLong(resultSet.getColumnIndex('output_tokens')),
          totalTokens: resultSet.getLong(resultSet.getColumnIndex('total_tokens'))
        } as AiCallLogEntry);
      }
      resultSet.close();
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'AiCallLogger', 'AI 调用日志读取失败 %{public}s', (e as Error).message);
    }
    return results;
  }

  static async countAiCallLogs(): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS cnt FROM ai_call_logs');
      let count: number = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
      }
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  static async clearAiCallLogs(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('ai_call_logs');
      await store.delete(predicates);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'AiCallLogger', 'AI 调用日志清空失败 %{public}s', (e as Error).message);
    }
  }

  // ========== 新闻资讯：收藏 ==========

  static async isNewsFavorite(url: string): Promise<boolean> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_favorites');
      predicates.equalTo('url', url);
      const resultSet = await store.query(predicates);
      try {
        return resultSet.goToNextRow();
      } finally {
        resultSet.close();
      }
    } catch (e) {
      return false;
    }
  }

  static async addNewsFavorite(item: NewsItem): Promise<void> {
    const exists: boolean = await DatabaseHelper.isNewsFavorite(item.url);
    if (exists) return;
    const store = DatabaseHelper.getStore();
    const id: string = 'fav-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const valueBucket: relationalStore.ValuesBucket = {
      id: id,
      url: item.url,
      title: item.title,
      summary: item.summary,
      image_url: item.imageUrl,
      source_name: item.sourceName,
      added_at: Date.now()
    };
    try {
      await store.insert('news_favorites', valueBucket);
    } catch (e) {
    }
  }

  static async removeNewsFavorite(url: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_favorites');
      predicates.equalTo('url', url);
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async listNewsFavorites(): Promise<NewsFavoriteEntry[]> {
    const store = DatabaseHelper.getStore();
    const results: NewsFavoriteEntry[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('news_favorites');
      predicates.orderByDesc('added_at');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          url: resultSet.getString(resultSet.getColumnIndex('url')),
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          summary: resultSet.getString(resultSet.getColumnIndex('summary')),
          imageUrl: resultSet.getString(resultSet.getColumnIndex('image_url')),
          sourceName: resultSet.getString(resultSet.getColumnIndex('source_name')),
          addedAt: resultSet.getLong(resultSet.getColumnIndex('added_at'))
        } as NewsFavoriteEntry);
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  static async clearNewsFavorites(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_favorites');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  // ========== 新闻资讯：已读 ==========

  static async markNewsRead(url: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      // 幂等：url 为主键，先删后插并刷新 read_at（避免重复打开时 UNIQUE 冲突）
      const del = new relationalStore.RdbPredicates('news_read');
      del.equalTo('url', url);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = { url: url, read_at: Date.now() };
      await store.insert('news_read', valueBucket);
    } catch (e) {
    }
  }

  static async isNewsRead(url: string): Promise<boolean> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_read');
      predicates.equalTo('url', url);
      const resultSet = await store.query(predicates);
      try {
        return resultSet.goToNextRow();
      } finally {
        resultSet.close();
      }
    } catch (e) {
      return false;
    }
  }

  static async listNewsReadUrls(): Promise<string[]> {
    const store = DatabaseHelper.getStore();
    const urls: string[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('news_read');
      predicates.orderByDesc('read_at');
      predicates.limitAs(2000);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        urls.push(resultSet.getString(resultSet.getColumnIndex('url')));
      }
      resultSet.close();
    } catch (e) {
    }
    return urls;
  }

  // ========== 新闻资讯：AI 今日要闻缓存 ==========

  static async saveNewsDigest(entry: NewsDigestEntry): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      // 按 id 先删后插，保证幂等（同日不同模式互不影响）
      const del = new relationalStore.RdbPredicates('news_digests');
      del.equalTo('id', entry.id);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        id: entry.id,
        date: entry.date,
        content: entry.content,
        model_name: entry.modelName,
        created_at: entry.createdAt
      };
      await store.insert('news_digests', valueBucket);
    } catch (e) {
    }
  }

  // 按 id 查询（id = digest-<yyyyMMdd> 或 digest-<yyyyMMdd>-hotspot）
  static async getNewsDigestById(id: string): Promise<NewsDigestEntry | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_digests');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return new NewsDigestEntry(
            resultSet.getString(resultSet.getColumnIndex('id')),
            resultSet.getString(resultSet.getColumnIndex('date')),
            resultSet.getString(resultSet.getColumnIndex('content')),
            resultSet.getString(resultSet.getColumnIndex('model_name')),
            resultSet.getLong(resultSet.getColumnIndex('created_at'))
          );
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async getNewsDigest(date: string): Promise<NewsDigestEntry | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_digests');
      predicates.equalTo('date', date);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return new NewsDigestEntry(
            resultSet.getString(resultSet.getColumnIndex('id')),
            resultSet.getString(resultSet.getColumnIndex('date')),
            resultSet.getString(resultSet.getColumnIndex('content')),
            resultSet.getString(resultSet.getColumnIndex('model_name')),
            resultSet.getLong(resultSet.getColumnIndex('created_at'))
          );
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async deleteNewsDigest(date: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_digests');
      predicates.equalTo('date', date);
      await store.delete(predicates);
    } catch (e) {
    }
  }

  // ========== 新闻资讯：频道快照缓存（离线阅读） ==========

  static async saveNewsChannelCache(channelId: string, itemsJson: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_cache');
      del.equalTo('channel_id', channelId);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        channel_id: channelId,
        items_json: itemsJson,
        cached_at: Date.now()
      };
      await store.insert('news_cache', valueBucket);
    } catch (e) {
    }
  }

  static async getNewsChannelCache(channelId: string): Promise<string | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_cache');
      predicates.equalTo('channel_id', channelId);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return resultSet.getString(resultSet.getColumnIndex('items_json'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  // ========== 新闻资讯：正文缓存（离线全文阅读） ==========

  static async saveNewsArticleCache(url: string, title: string, html: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_article_cache');
      del.equalTo('url', url);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        url: url,
        title: title,
        html: html,
        cached_at: Date.now()
      };
      await store.insert('news_article_cache', valueBucket);
    } catch (e) {
    }
  }

  static async getNewsArticleCache(url: string): Promise<NewsArticleCacheEntry | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_article_cache');
      predicates.equalTo('url', url);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return {
            title: resultSet.getString(resultSet.getColumnIndex('title')),
            html: resultSet.getString(resultSet.getColumnIndex('html'))
          };
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async clearNewsArticleCache(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_article_cache');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  // ========== 新闻资讯：赞/踩状态（v15） ==========

  static async setNewsRating(rating: NewsRating): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_ratings');
      del.equalTo('url', rating.url);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        url: rating.url,
        rating: rating.rating,
        item_id: rating.url,
        title: rating.title,
        summary: rating.summary,
        image_url: rating.imageUrl,
        source_name: rating.sourceName,
        category: rating.category,
        published_at: rating.publishedAt,
        tags_json: JSON.stringify(rating.tags),
        updated_at: rating.updatedAt
      };
      await store.insert('news_ratings', valueBucket);
    } catch (e) {
    }
  }

  static async getNewsRating(url: string): Promise<NewsRating | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_ratings');
      predicates.equalTo('url', url);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return DatabaseHelper.ratingFromRow(resultSet);
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async listNewsRatings(): Promise<NewsRating[]> {
    const store = DatabaseHelper.getStore();
    const results: NewsRating[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('news_ratings');
      predicates.orderByDesc('updated_at');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(DatabaseHelper.ratingFromRow(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  static async deleteNewsRating(url: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_ratings');
      predicates.equalTo('url', url);
      await store.delete(predicates);
    } catch (e) {
    }
  }

  private static ratingFromRow(resultSet: relationalStore.ResultSet): NewsRating {
    const tagsRaw: string = resultSet.getString(resultSet.getColumnIndex('tags_json'));
    let tags: string[] = [];
    if (tagsRaw.trim().length > 0) {
      try {
        const parsed: Object = JSON.parse(tagsRaw) as Object;
        if (Array.isArray(parsed)) {
          tags = (parsed as Object[]).map((v: Object) => typeof v === 'string' ? v as string : '')
            .filter((s: string) => s.length > 0);
        }
      } catch (e) {
        tags = [];
      }
    }
    return new NewsRating(
      resultSet.getString(resultSet.getColumnIndex('url')),
      resultSet.getLong(resultSet.getColumnIndex('rating')),
      resultSet.getString(resultSet.getColumnIndex('title')),
      resultSet.getString(resultSet.getColumnIndex('summary')),
      resultSet.getString(resultSet.getColumnIndex('image_url')),
      resultSet.getString(resultSet.getColumnIndex('source_name')),
      resultSet.getString(resultSet.getColumnIndex('category')),
      resultSet.getLong(resultSet.getColumnIndex('published_at')),
      tags,
      resultSet.getLong(resultSet.getColumnIndex('updated_at'))
    );
  }

  // ========== 新闻资讯：行为流水（v15） ==========

  static async recordNewsEvent(eventType: string, url: string, itemId: string = '',
    weight: number = 0, extraJson: string = ''): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const id: string = 'evt-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
      const valueBucket: relationalStore.ValuesBucket = {
        id: id,
        url: url,
        item_id: itemId,
        event_type: eventType,
        weight: weight,
        extra_json: extraJson,
        occurred_at: Date.now()
      };
      await store.insert('news_events', valueBucket);
    } catch (e) {
    }
  }

  // ========== 新闻资讯：单篇排除（v15） ==========

  static async addNewsExclusion(url: string, reason: string = ''): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        type: 'url',
        value: url,
        reason: reason,
        created_at: Date.now()
      };
      await store.insert('news_exclusions', valueBucket);
    } catch (e) {
    }
  }

  static async isNewsExcluded(url: string): Promise<boolean> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_exclusions');
      predicates.equalTo('type', 'url');
      predicates.equalTo('value', url);
      const resultSet = await store.query(predicates);
      try {
        return resultSet.goToNextRow();
      } finally {
        resultSet.close();
      }
    } catch (e) {
      return false;
    }
  }

  static async removeNewsExclusion(url: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_exclusions');
      predicates.equalTo('type', 'url');
      predicates.equalTo('value', url);
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async listNewsExcludedUrls(): Promise<string[]> {
    const store = DatabaseHelper.getStore();
    const urls: string[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('news_exclusions');
      predicates.equalTo('type', 'url');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        urls.push(resultSet.getString(resultSet.getColumnIndex('value')));
      }
      resultSet.close();
    } catch (e) {
    }
    return urls;
  }

  // ========== 新闻资讯：标签缓存（v15） ==========

  static async saveNewsTags(url: string, tagsJson: string, sourceType: string = 'rule',
    model: string = ''): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_tags');
      del.equalTo('url', url);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        url: url,
        tags_json: tagsJson,
        source_type: sourceType,
        model: model,
        updated_at: Date.now()
      };
      await store.insert('news_tags', valueBucket);
    } catch (e) {
    }
  }

  static async saveNewsProfile(valueJson: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_profile');
      del.equalTo('key', 'main');
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        key: 'main',
        value_json: valueJson,
        updated_at: Date.now()
      };
      await store.insert('news_profile', valueBucket);
    } catch (e) {
    }
  }

  static async getNewsProfile(): Promise<string | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_profile');
      predicates.equalTo('key', 'main');
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return resultSet.getString(resultSet.getColumnIndex('value_json'));
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async clearNewsTags(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_tags');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async clearNewsProfile(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_profile');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async clearNewsExclusions(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_exclusions');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  // ========== 新闻资讯：翻译缓存（v15） ==========

  static async saveNewsTranslation(url: string, kind: string, langPair: string, text: string,
    model: string = ''): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const del = new relationalStore.RdbPredicates('news_translations');
      del.equalTo('url', url);
      del.equalTo('kind', kind);
      await store.delete(del);
      const valueBucket: relationalStore.ValuesBucket = {
        url: url,
        kind: kind,
        lang_pair: langPair,
        text: text,
        model: model,
        updated_at: Date.now()
      };
      await store.insert('news_translations', valueBucket);
    } catch (e) {
    }
  }

  static async getNewsTranslation(url: string, kind: string): Promise<NewsTranslationEntry | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_translations');
      predicates.equalTo('url', url);
      predicates.equalTo('kind', kind);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return {
            url: url,
            kind: kind,
            langPair: resultSet.getString(resultSet.getColumnIndex('lang_pair')),
            text: resultSet.getString(resultSet.getColumnIndex('text')),
            model: resultSet.getString(resultSet.getColumnIndex('model')),
            updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
          } as NewsTranslationEntry;
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  static async clearNewsTranslations(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_translations');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async getNewsTags(url: string): Promise<NewsTagEntry | null> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_tags');
      predicates.equalTo('url', url);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) {
          return {
            url: url,
            tagsJson: resultSet.getString(resultSet.getColumnIndex('tags_json')),
            sourceType: resultSet.getString(resultSet.getColumnIndex('source_type')),
            model: resultSet.getString(resultSet.getColumnIndex('model')),
            updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
          } as NewsTagEntry;
        }
      } finally {
        resultSet.close();
      }
    } catch (e) {
    }
    return null;
  }

  // ========== 新闻资讯：清理与统计 ==========

  static async clearNewsRead(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_read');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async clearNewsChannelCache(): Promise<void> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('news_cache');
      await store.delete(predicates);
    } catch (e) {
    }
  }

  static async countNewsFavorites(): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS cnt FROM news_favorites');
      let count: number = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
      }
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  static async countNewsRead(): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS cnt FROM news_read');
      let count: number = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
      }
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }

  // 统计 AI 调用日志中资讯场景（game 以 news: 开头）的条数
  static async countNewsAiCalls(): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const resultSet = await store.querySql("SELECT COUNT(*) AS cnt FROM ai_call_logs WHERE game LIKE 'news:%'");
      let count: number = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
      }
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
  }
}

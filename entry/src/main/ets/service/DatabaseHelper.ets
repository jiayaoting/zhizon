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

// 阅读周报统计结果（日期标签按时间升序，旧 → 新）
export class WeeklyReadingStats {
  dates: string[];
  reads: number[];
  favorites: number[];
  aiCalls: number[];
  totalReads: number;
  totalFavorites: number;
  totalAiCalls: number;
  activeDays: number;
  bestDayIndex: number;

  constructor(dates: string[], reads: number[], favorites: number[], aiCalls: number[],
    totalReads: number, totalFavorites: number, totalAiCalls: number,
    activeDays: number, bestDayIndex: number) {
    this.dates = dates;
    this.reads = reads;
    this.favorites = favorites;
    this.aiCalls = aiCalls;
    this.totalReads = totalReads;
    this.totalFavorites = totalFavorites;
    this.totalAiCalls = totalAiCalls;
    this.activeDays = activeDays;
    this.bestDayIndex = bestDayIndex;
  }
}

const DB_NAME = 'zhizon.db';
const DB_VERSION = 16;
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
// 版本门控迁移步骤定义：minVersion 为引入该列的最低数据库版本号（version < minVersion 才需要补列）
interface SchemaAlterStep {
  table: string;
  column: string;
  minVersion: number;
  sql: string;
}

// 旧库升级 ALTER 步骤：新库建表已含全部列，迁移时会先检查列是否存在，重复列自动跳过
const SQL_ALTER_STEPS: SchemaAlterStep[] = [
  { table: 'ai_call_logs', column: 'input_tokens', minVersion: 5, sql: 'ALTER TABLE ai_call_logs ADD COLUMN input_tokens INTEGER DEFAULT 0' },
  { table: 'ai_call_logs', column: 'cached_tokens', minVersion: 5, sql: 'ALTER TABLE ai_call_logs ADD COLUMN cached_tokens INTEGER DEFAULT 0' },
  { table: 'ai_call_logs', column: 'output_tokens', minVersion: 5, sql: 'ALTER TABLE ai_call_logs ADD COLUMN output_tokens INTEGER DEFAULT 0' },
  { table: 'ai_call_logs', column: 'total_tokens', minVersion: 5, sql: 'ALTER TABLE ai_call_logs ADD COLUMN total_tokens INTEGER DEFAULT 0' },
  { table: 'game_scores', column: 'model', minVersion: 7, sql: "ALTER TABLE game_scores ADD COLUMN model TEXT DEFAULT ''" },
  { table: 'game_scores', column: 'duration', minVersion: 8, sql: 'ALTER TABLE game_scores ADD COLUMN duration INTEGER DEFAULT 0' },
  { table: 'game_scores', column: 'ai_think_time', minVersion: 11, sql: 'ALTER TABLE game_scores ADD COLUMN ai_think_time INTEGER DEFAULT 0' },
  { table: 'chat_messages', column: 'image_data', minVersion: 10, sql: "ALTER TABLE chat_messages ADD COLUMN image_data TEXT DEFAULT ''" },
  // ai_token_stats 无明确引入版本：只要未达 DB_VERSION 就检查补列（保持旧行为）
  { table: 'ai_token_stats', column: 'call_count', minVersion: 15, sql: 'ALTER TABLE ai_token_stats ADD COLUMN call_count INTEGER DEFAULT 0' },
  { table: 'ai_token_stats', column: 'input_tokens', minVersion: 15, sql: 'ALTER TABLE ai_token_stats ADD COLUMN input_tokens INTEGER DEFAULT 0' },
  { table: 'ai_token_stats', column: 'cached_tokens', minVersion: 15, sql: 'ALTER TABLE ai_token_stats ADD COLUMN cached_tokens INTEGER DEFAULT 0' },
  { table: 'ai_token_stats', column: 'output_tokens', minVersion: 15, sql: 'ALTER TABLE ai_token_stats ADD COLUMN output_tokens INTEGER DEFAULT 0' },
  { table: 'ai_token_stats', column: 'total_tokens', minVersion: 15, sql: 'ALTER TABLE ai_token_stats ADD COLUMN total_tokens INTEGER DEFAULT 0' },
  // v16：会话无痕标记 + 会话级系统提示词（AI 角色模板库）
  { table: 'chat_sessions', column: 'incognito', minVersion: 16, sql: 'ALTER TABLE chat_sessions ADD COLUMN incognito INTEGER DEFAULT 0' },
  { table: 'chat_sessions', column: 'system_prompt', minVersion: 16, sql: "ALTER TABLE chat_sessions ADD COLUMN system_prompt TEXT DEFAULT ''" }
];
// 累计统计表：仅一行（id='all'），删除模型/清空调用记录时不清理，只增不减
const SQL_CREATE_AI_TOKEN_STATS = `CREATE TABLE IF NOT EXISTS ai_token_stats (
  id TEXT PRIMARY KEY, call_count INTEGER DEFAULT 0, input_tokens INTEGER DEFAULT 0,
  cached_tokens INTEGER DEFAULT 0, output_tokens INTEGER DEFAULT 0, total_tokens INTEGER DEFAULT 0
)`;
// AI 对话多会话：会话表 + 消息表（v9）
const SQL_CREATE_CHAT_SESSIONS = `CREATE TABLE IF NOT EXISTS chat_sessions (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL, pinned INTEGER DEFAULT 0, active_model_id TEXT DEFAULT '',
  incognito INTEGER DEFAULT 0, system_prompt TEXT DEFAULT ''
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

// 查询/清理用索引（CREATE INDEX IF NOT EXISTS，幂等）
const SQL_CREATE_IDX_GAME_SCORES = 'CREATE INDEX IF NOT EXISTS idx_game_scores_game_score ON game_scores(game, score)';
const SQL_CREATE_IDX_AI_CALL_LOGS_START_TIME = 'CREATE INDEX IF NOT EXISTS idx_ai_call_logs_start_time ON ai_call_logs(start_time)';
const SQL_CREATE_IDX_NEWS_READ_READ_AT = 'CREATE INDEX IF NOT EXISTS idx_news_read_read_at ON news_read(read_at)';
const SQL_CREATE_IDX_NEWS_FAVORITES_ADDED_AT = 'CREATE INDEX IF NOT EXISTS idx_news_favorites_added_at ON news_favorites(added_at)';

// 已读标记 upsert（url 为主键，一次写完成）
const SQL_UPSERT_NEWS_READ = 'INSERT OR REPLACE INTO news_read (url, read_at) VALUES (?, ?)';

// 保留策略：过期数据清理（executeSql + bindArgs 参数化，禁止字符串拼值）
const SQL_RETENTION_CHAT_AGENT_STEPS = 'DELETE FROM chat_agent_steps WHERE started_at < ?';
const SQL_RETENTION_AI_CALL_LOGS = 'DELETE FROM ai_call_logs WHERE start_time < ?';
const SQL_RETENTION_NEWS_READ = 'DELETE FROM news_read WHERE read_at < ?';
const SQL_RETENTION_NEWS_ARTICLE_CACHE = 'DELETE FROM news_article_cache WHERE cached_at < ?';
const SQL_RETENTION_GAME_REPLAYS = 'DELETE FROM game_replays WHERE created_at < ?';
const SQL_RETENTION_CHAT_MESSAGES = 'DELETE FROM chat_messages WHERE time < ?';
// 行为流水 90 天自动清理（画像已落快照，事件仅用于审计/重算）
const SQL_RETENTION_NEWS_EVENTS = 'DELETE FROM news_events WHERE occurred_at < ?';

// ========== SQLite FTS5 全文索引（设备支持时启用，不支持自动回退 LIKE） ==========
// 优先 trigram 分词（中英文子串匹配），失败再退回默认分词；均失败则 ftsReady=false
const SQL_CREATE_CHAT_FTS_TRIGRAM = "CREATE VIRTUAL TABLE IF NOT EXISTS chat_messages_fts " +
  "USING fts5(session_id UNINDEXED, role UNINDEXED, content, reasoning, tokenize='trigram')";
const SQL_CREATE_CHAT_FTS_PLAIN = 'CREATE VIRTUAL TABLE IF NOT EXISTS chat_messages_fts ' +
  'USING fts5(session_id UNINDEXED, role UNINDEXED, content, reasoning)';
const SQL_CREATE_NEWS_FTS_TRIGRAM = "CREATE VIRTUAL TABLE IF NOT EXISTS news_articles_fts " +
  "USING fts5(kind UNINDEXED, url UNINDEXED, title, body, tokenize='trigram')";
const SQL_CREATE_NEWS_FTS_PLAIN = 'CREATE VIRTUAL TABLE IF NOT EXISTS news_articles_fts ' +
  'USING fts5(kind UNINDEXED, url UNINDEXED, title, body)';

export class DatabaseHelper {
  private static store: relationalStore.RdbStore | null = null;
  // FTS5 虚拟表可用标记（init 时探测；不可用时搜索自动回退 LIKE）
  private static chatFtsReady: boolean = false;
  private static newsFtsReady: boolean = false;

  // 初始化数据库
  static async init(context: common.Context): Promise<void> {
    if (DatabaseHelper.store) return;

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    DatabaseHelper.store = await relationalStore.getRdbStore(context, config);

    // 创建表（CREATE TABLE IF NOT EXISTS，幂等）
    await DatabaseHelper.store.executeSql(SQL_CREATE_SETTINGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_GAME_SCORES);
    await DatabaseHelper.store.executeSql(SQL_CREATE_IDX_GAME_SCORES);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_EVIDENCE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_HISTORY);
    await DatabaseHelper.store.executeSql(SQL_CREATE_DEFECT_FIX_RESULTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_AI_CALL_LOGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_IDX_AI_CALL_LOGS_START_TIME);
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
    await DatabaseHelper.store.executeSql(SQL_CREATE_IDX_NEWS_FAVORITES_ADDED_AT);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_READ);
    await DatabaseHelper.store.executeSql(SQL_CREATE_IDX_NEWS_READ_READ_AT);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_DIGESTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_CACHE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_ARTICLE_CACHE);
    // 个性化推荐（v15）
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_TAGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_RATINGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS_URL_IDX);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EVENTS_TIME_IDX);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_EXCLUSIONS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_PROFILE);
    await DatabaseHelper.store.executeSql(SQL_CREATE_NEWS_TRANSLATIONS);

    // 版本门控迁移：仅对旧库执行 ALTER 补列（事务包裹，失败回滚且 version 不变，下次启动重试）
    await DatabaseHelper.migrateSchema();
    await DatabaseHelper.initTokenStats();
    // 保留策略：启动时清理一次过期数据
    await DatabaseHelper.applyRetentionPolicy();
    // FTS5 全文索引（设备/系统支持才启用，失败静默回退 LIKE 搜索）
    await DatabaseHelper.initFtsTables();
  }

  // 尝试创建 FTS5 虚拟表：先 trigram 分词（中英文子串），失败退回默认分词；再失败标记不可用
  private static async initFtsTables(): Promise<void> {
    DatabaseHelper.chatFtsReady = await DatabaseHelper.tryCreateFtsTable(SQL_CREATE_CHAT_FTS_TRIGRAM,
      SQL_CREATE_CHAT_FTS_PLAIN, 'chat_messages_fts');
    DatabaseHelper.newsFtsReady = await DatabaseHelper.tryCreateFtsTable(SQL_CREATE_NEWS_FTS_TRIGRAM,
      SQL_CREATE_NEWS_FTS_PLAIN, 'news_articles_fts');
  }

  private static async tryCreateFtsTable(sqlTrigram: string, sqlPlain: string, name: string): Promise<boolean> {
    const store = DatabaseHelper.getStore();
    try {
      await store.executeSql(sqlTrigram);
      return true;
    } catch (e1) {
      try {
        await store.executeSql(sqlPlain);
        return true;
      } catch (e2) {
        hilog.warn(DB_DOMAIN, 'DatabaseHelper', 'FTS5 虚拟表 %{public}s 创建失败，回退 LIKE 搜索 %{public}s', name,
          (e2 as Error).message);
        return false;
      }
    }
  }

  static isChatFtsReady(): boolean {
    return DatabaseHelper.chatFtsReady;
  }

  static isNewsFtsReady(): boolean {
    return DatabaseHelper.newsFtsReady;
  }

  // 版本门控迁移：读取 store.version，只对 version < 目标版本的步骤执行 ALTER。
  // 新库（version=0）建表已含全部列，先做列存在性检查避免重复加列报错；
  // 任一步失败则回滚且不提升 version，下次启动自动重试。
  private static async migrateSchema(): Promise<void> {
    const store = DatabaseHelper.getStore();
    const current: number = store.version;
    if (current >= DB_VERSION) return;
    await store.beginTransaction();
    try {
      for (let i: number = 0; i < SQL_ALTER_STEPS.length; i++) {
        const step: SchemaAlterStep = SQL_ALTER_STEPS[i];
        if (current >= step.minVersion) continue;
        // 列已存在（新库或已补过列）则跳过，避免重复加列
        if (await DatabaseHelper.tableHasColumn(store, step.table, step.column)) continue;
        await store.executeSql(step.sql);
      }
      store.version = DB_VERSION;
      await store.commit();
    } catch (e) {
      await store.rollBack();
      // 保持 version 不变，下次启动重试
      hilog.error(DB_DOMAIN, 'DatabaseHelper', '数据库版本迁移失败（version=%{public}d）：%{public}s', current,
        (e as Error).message);
    }
  }

  // 检查表是否已含指定列（SELECT * LIMIT 0 仅取列元数据，无遍历开销）
  private static async tableHasColumn(store: relationalStore.RdbStore, table: string, column: string): Promise<boolean> {
    const resultSet: relationalStore.ResultSet = await store.querySql('SELECT * FROM ' + table + ' LIMIT 0');
    try {
      const names: string[] = resultSet.getColumnNames();
      return names.indexOf(column) >= 0;
    } finally {
      resultSet.close();
    }
  }

  // 保留策略：按各表保留期清理过期数据（executeSql + bindArgs 参数化）
  static async applyRetentionPolicy(): Promise<void> {
    const store = DatabaseHelper.getStore();
    const now: number = Date.now();
    const dayMs: number = 24 * 3600 * 1000;
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_CHAT_AGENT_STEPS, now - 90 * dayMs, 'chat_agent_steps');
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_AI_CALL_LOGS, now - 90 * dayMs, 'ai_call_logs');
    // 注意：不动 ai_token_stats 累计表（只增不减，独立于调用记录）
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_NEWS_READ, now - 90 * dayMs, 'news_read');
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_NEWS_ARTICLE_CACHE, now - 30 * dayMs, 'news_article_cache');
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_GAME_REPLAYS, now - 180 * dayMs, 'game_replays');
    // 行为流水 90 天自动清理（保留原启动清理行为）
    await DatabaseHelper.deleteExpired(store, SQL_RETENTION_NEWS_EVENTS, now - 90 * dayMs, 'news_events');
    // 聊天消息保留天数由设置决定：默认 365 天，'0' 表示不清理
    let retentionDays: number = 365;
    try {
      const retentionDaysStr: string = await DatabaseHelper.getSetting('chatRetentionDays', '365');
      retentionDays = parseInt(retentionDaysStr, 10);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'DatabaseHelper', '读取聊天保留天数失败，使用默认 365 天 %{public}s', (e as Error).message);
      retentionDays = 365;
    }
    if (!Number.isNaN(retentionDays) && retentionDays > 0) {
      await DatabaseHelper.deleteExpired(store, SQL_RETENTION_CHAT_MESSAGES, now - retentionDays * dayMs, 'chat_messages');
    }
  }

  // 按过期时间清理单个表（失败仅告警，不影响其他清理项）
  private static async deleteExpired(store: relationalStore.RdbStore, sql: string, cutoff: number,
    tableName: string): Promise<void> {
    const bindArgs: Array<relationalStore.ValueType> = [cutoff];
    try {
      await store.executeSql(sql, bindArgs);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'DatabaseHelper', tableName + ' 过期清理失败 %{public}s', (e as Error).message);
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
    try {
      // AI 托管对局：model 非空（语义与原 notEqualTo('model','') 一致）
      const bindArgs: Array<relationalStore.ValueType> = [''];
      const resultSet = await store.querySql('SELECT COUNT(*) AS c FROM game_scores WHERE model != ?', bindArgs);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('c'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  static async getChatMessageCount(): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      // 用户消息条数（role='user'，语义与原 equalTo 一致）
      const bindArgs: Array<relationalStore.ValueType> = ['user'];
      const resultSet = await store.querySql('SELECT COUNT(*) AS c FROM chat_messages WHERE role = ?', bindArgs);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('c'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  private static async countRows(table: string, winGame: string): Promise<number> {
    const store = DatabaseHelper.getStore();
    // 无 winGame 时统计全表；有 winGame 时统计 game=winGame 且 score>0
    let sql: string = 'SELECT COUNT(*) AS c FROM ' + table;
    const bindArgs: Array<relationalStore.ValueType> = [];
    if (winGame.length > 0) {
      sql = 'SELECT COUNT(*) AS c FROM ' + table + ' WHERE game = ? AND score > 0';
      bindArgs.push(winGame);
    }
    try {
      const resultSet = await store.querySql(sql, bindArgs);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('c'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ========== 阅读周报（近 7 天阅读/收藏/AI 资讯调用） ==========

  // 近 7 天阅读周报（含今天；AI 调用统计 news 场景日志）
  static async getWeeklyReadingStats(): Promise<WeeklyReadingStats> {
    const store = DatabaseHelper.getStore();
    const dates: string[] = [];
    const reads: number[] = [];
    const favorites: number[] = [];
    const aiCalls: number[] = [];
    const now: Date = new Date();
    now.setHours(0, 0, 0, 0);
    const dayMs: number = 24 * 3600 * 1000;
    for (let i: number = 6; i >= 0; i--) {
      const dayStart: number = now.getTime() - i * dayMs;
      const nextStart: number = dayStart + dayMs;
      dates.push(DatabaseHelper.weekDayLabel(new Date(dayStart)));
      reads.push(await DatabaseHelper.countBetween(store, 'news_read', 'read_at', dayStart, nextStart, ''));
      favorites.push(await DatabaseHelper.countBetween(store, 'news_favorites', 'added_at', dayStart, nextStart, ''));
      aiCalls.push(await DatabaseHelper.countBetween(store, 'ai_call_logs', 'start_time', dayStart, nextStart,
        " AND type LIKE 'news%'"));
    }
    let totalReads: number = 0;
    let totalFavorites: number = 0;
    let totalAiCalls: number = 0;
    let activeDays: number = 0;
    let bestDayIndex: number = -1;
    let best: number = 0;
    for (let i: number = 0; i < reads.length; i++) {
      totalReads += reads[i];
      totalFavorites += favorites[i];
      totalAiCalls += aiCalls[i];
      if (reads[i] > 0) activeDays += 1;
      if (reads[i] > best) {
        best = reads[i];
        bestDayIndex = i;
      }
    }
    return new WeeklyReadingStats(dates, reads, favorites, aiCalls,
      totalReads, totalFavorites, totalAiCalls, activeDays, bestDayIndex);
  }

  // 时间段计数（表名/列名来自内部常量，无注入风险；extraWhere 为固定常量）
  private static async countBetween(store: relationalStore.RdbStore, table: string, column: string,
    from: number, to: number, extraWhere: string): Promise<number> {
    try {
      const sql: string = 'SELECT COUNT(*) AS c FROM ' + table + ' WHERE ' + column +
        ' >= ? AND ' + column + ' < ?' + extraWhere;
      const bindArgs: Array<relationalStore.ValueType> = [from, to];
      const resultSet = await store.querySql(sql, bindArgs);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = resultSet.getLong(resultSet.getColumnIndex('c'));
        }
      } finally {
        resultSet.close();
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // 日期标签：MM-DD
  private static weekDayLabel(d: Date): string {
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return m + '-' + day;
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
      // 幂等：url 为主键，INSERT OR REPLACE 覆盖旧行并刷新 read_at（一次写完成）
      const bindArgs: Array<relationalStore.ValueType> = [url, Date.now()];
      await store.executeSql(SQL_UPSERT_NEWS_READ, bindArgs);
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

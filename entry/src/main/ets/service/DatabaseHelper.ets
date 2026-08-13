// 智子 - 数据库管理（RDB Store）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AffectedFeature, DefectInput, DefectRecord, DefectSeverity, DefectStateHistory, DefectStatus, EvidenceConclusion, EvidenceType, FixEvidence, FixResult } from '../model/GovernanceModels';

export interface ScoreEntry {
  id: string;
  score: number;
  level: number;
  difficulty: string;
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
}

const DB_NAME = 'zhizon.db';
const DB_VERSION = 4;
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
  error_msg TEXT DEFAULT '', prompt_chars INTEGER DEFAULT 0, response_chars INTEGER DEFAULT 0
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
    if (DatabaseHelper.store.version < DB_VERSION) {
      DatabaseHelper.store.version = DB_VERSION;
    }
  }

  static getStore(): relationalStore.RdbStore {
    if (!DatabaseHelper.store) throw new Error('Database not initialized');
    return DatabaseHelper.store;
  }

  // ========== 游戏战绩 ==========

  static async addGameScore(game: string, score: number, level: number, difficulty: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const id: string = 'gs-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const valueBucket: relationalStore.ValuesBucket = {
      id: id,
      game: game,
      score: score,
      level: level,
      difficulty: difficulty,
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
      response_chars: entry.responseChars
    };
    try {
      await store.insert('ai_call_logs', bucket);
    } catch (e) {
      hilog.warn(DB_DOMAIN, 'AiCallLogger', 'AI 调用日志写入失败 %{public}s', (e as Error).message);
    }
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
          responseChars: resultSet.getLong(resultSet.getColumnIndex('response_chars'))
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
}

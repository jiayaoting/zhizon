// 智子 - 数据仓库（基于数据库持久化）
import { DatabaseHelper, ScoreEntry } from './DatabaseHelper';
import { ThemePreference, ThemeMode, GlobalBackgroundPreference } from '../common/ThemeContracts';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DefectRecord, DefectStateHistory, FixEvidence, RecoverableResult, AppErrorCategory, RecoveryAction, AppFailure, ValidationResult, PreferenceSnapshot, PreferencePersistenceResult } from '../model/GovernanceModels';

const SETTINGS_DOMAIN = 0x9201;

class StoredThemePreference {
  followSystem: boolean = true;
  manualMode: string = ThemeMode.DARK;
}

class StoredBackgroundPreference {
  globalUri: string = '';
  visibleStrength: number = 50;
}

class StoredBackgroundPreferenceValue {
  globalUri: string;
  visibleStrength: number;
  constructor(globalUri: string, visibleStrength: number) { this.globalUri = globalUri; this.visibleStrength = visibleStrength; }
}

class LegacyBackgroundConfig {
  global: string = '';
}

function isSandboxBackgroundReference(uri: string): boolean {
  return uri.length === 0 || uri.startsWith('file://') || uri.indexOf('://') < 0;
}

// 生成唯一 ID
export function generateId(prefix: string): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `${prefix}-${timestamp}-${random}`;
}

// 数据仓库 - 持久化版本
export class DataRepository {
  private static preferenceSnapshot: PreferenceSnapshot = new PreferenceSnapshot(true, ThemeMode.DARK,
    'cyan', 'standard', '', 50, false, 0);
  static generateId(prefix: string): string { return generateId(prefix); }

  static async saveDefect(record: DefectRecord): Promise<RecoverableResult<DefectRecord>> {
    try { await DatabaseHelper.saveDefect(record); return new RecoverableResult<DefectRecord>(true, record, null, null); }
    catch (e) { return new RecoverableResult<DefectRecord>(false, null, new AppFailure(AppErrorCategory.PERSISTENCE, 'PERSISTENCE_FAILED', '缺陷记录未保存', true, RecoveryAction.RETRY), record); }
  }
  static async getDefect(defectKey: string): Promise<DefectRecord | null> { return await DatabaseHelper.getDefect(defectKey); }
  static async updateDefect(record: DefectRecord): Promise<RecoverableResult<DefectRecord>> {
    const previous: DefectRecord | null = await DatabaseHelper.getDefect(record.defectKey);
    try { await DatabaseHelper.updateDefect(record); return new RecoverableResult<DefectRecord>(true, record, null, previous); }
    catch (e) { return new RecoverableResult<DefectRecord>(false, null, new AppFailure(AppErrorCategory.PERSISTENCE, 'PERSISTENCE_FAILED', '缺陷记录未更新', true, RecoveryAction.RESTORE_SNAPSHOT), previous); }
  }
  static async appendEvidence(record: DefectRecord, evidence: FixEvidence): Promise<RecoverableResult<DefectRecord>> {
    try { await DatabaseHelper.appendEvidence(record, evidence); return new RecoverableResult<DefectRecord>(true, record, null, null); }
    catch (e) { return new RecoverableResult<DefectRecord>(false, null, new AppFailure(AppErrorCategory.PERSISTENCE, 'PERSISTENCE_FAILED', '验证证据未保存', true, RecoveryAction.RETRY), record); }
  }
  static async appendDefectHistory(history: DefectStateHistory): Promise<void> { await DatabaseHelper.appendDefectHistory(history); }
  static async transitionDefect(record: DefectRecord, history: DefectStateHistory, evidence: FixEvidence | null): Promise<RecoverableResult<DefectRecord>> { try { await DatabaseHelper.transitionDefect(record, history, evidence); return new RecoverableResult<DefectRecord>(true, record, null, null); } catch (e) { return new RecoverableResult<DefectRecord>(false, null, new AppFailure(AppErrorCategory.PERSISTENCE, 'PERSISTENCE_FAILED', '缺陷状态未更新', true, RecoveryAction.RESTORE_SNAPSHOT), record); } }

  static validateBackgroundStrength(strength: number): ValidationResult { return Number.isInteger(strength) && strength >= 0 && strength <= 100 ? new ValidationResult(true, '', '') : new ValidationResult(false, 'INVALID_STRENGTH', '背景强度必须为 0 至 100'); }
  static initializePreferenceSnapshot(snapshot: PreferenceSnapshot): void {
    DataRepository.preferenceSnapshot = DataRepository.copyPreferenceSnapshot(snapshot);
  }
  static getPreferenceSnapshot(): PreferenceSnapshot {
    return DataRepository.copyPreferenceSnapshot(DataRepository.preferenceSnapshot);
  }
  static async persistPreferenceCandidate(candidate: PreferenceSnapshot): Promise<PreferencePersistenceResult> {
    const rollback: PreferenceSnapshot = DataRepository.getPreferenceSnapshot();
    if (candidate.operationVersion <= rollback.operationVersion ||
      !DataRepository.validateBackgroundStrength(candidate.backgroundStrength).valid ||
      (candidate.manualThemeMode !== ThemeMode.DARK && candidate.manualThemeMode !== ThemeMode.LIGHT) ||
      !DataRepository.isColorTheme(candidate.colorThemeId) || !DataRepository.isFontSizeScale(candidate.fontSizeScale) ||
      !isSandboxBackgroundReference(candidate.backgroundUri)) {
      return new PreferencePersistenceResult(false, 'INVALID_PREFERENCE_CANDIDATE', rollback, rollback);
    }
    try {
      const storedTheme = new StoredThemePreference(); storedTheme.followSystem = candidate.followSystem; storedTheme.manualMode = candidate.manualThemeMode;
      await DatabaseHelper.setPreferenceSettings(JSON.stringify(storedTheme),
        JSON.stringify(new StoredBackgroundPreferenceValue(candidate.backgroundUri, candidate.backgroundStrength)),
        candidate.colorThemeId, candidate.fontSizeScale);
      // 单独持久化毛玻璃开关
      await DatabaseHelper.setSetting('glassEffectEnabled', candidate.glassEffectEnabled ? 'true' : 'false');
      DataRepository.preferenceSnapshot = DataRepository.copyPreferenceSnapshot(candidate);
      return new PreferencePersistenceResult(true, '', DataRepository.getPreferenceSnapshot(), rollback);
    } catch (e) { return new PreferencePersistenceResult(false, 'PERSISTENCE_FAILED', rollback, rollback); }
  }
  private static copyPreferenceSnapshot(source: PreferenceSnapshot): PreferenceSnapshot {
    return new PreferenceSnapshot(source.followSystem, source.manualThemeMode, source.colorThemeId,
      source.fontSizeScale, source.backgroundUri, source.backgroundStrength, source.glassEffectEnabled,
      source.operationVersion);
  }
  private static isColorTheme(value: string): boolean {
    return value === 'cyan' || value === 'ocean' || value === 'sunset' || value === 'aurora' ||
      value === 'sakura' || value === 'forest';
  }
  private static isFontSizeScale(value: string): boolean {
    return value === 'xsmall' || value === 'small' || value === 'standard' ||
      value === 'large' || value === 'xlarge';
  }

  // ========== 游戏战绩 ==========

  static async addGameScore(game: string, score: number, level: number, difficulty: string,
    model: string = ''): Promise<void> {
    await DatabaseHelper.addGameScore(game, score, level, difficulty, model);
  }

  static async getGameScores(game: string, limit?: number): Promise<ScoreEntry[]> {
    return await DatabaseHelper.getGameScores(game, limit);
  }

  static async getGameHighScore(game: string): Promise<number> {
    return await DatabaseHelper.getGameHighScore(game);
  }

  static async deleteGameScore(id: string): Promise<void> {
    await DatabaseHelper.deleteGameScore(id);
  }

  static async clearGameScores(game: string): Promise<void> {
    await DatabaseHelper.clearGameScores(game);
  }

  // ========== 设置 ==========

  static async getSetting(key: string, defaultValue: string = ''): Promise<string> {
    return await DatabaseHelper.getSetting(key, defaultValue);
  }

  static async setSetting(key: string, value: string): Promise<void> {
    await DatabaseHelper.setSetting(key, value);
  }

  static async getThemePreference(): Promise<ThemePreference> {
    const raw = await DatabaseHelper.getSetting('themePreference', '');
    if (raw.length > 0) {
      try {
        const stored: StoredThemePreference = JSON.parse(raw) as StoredThemePreference;
        if ((stored.followSystem !== true && stored.followSystem !== false) ||
          (stored.manualMode !== ThemeMode.DARK && stored.manualMode !== ThemeMode.LIGHT)) {
          hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
            '主题偏好无效 source=%{public}s fallback=%{public}s', 'themePreference', 'true');
          return new ThemePreference(true, ThemeMode.DARK);
        }
        const manualMode = stored.manualMode === ThemeMode.LIGHT ? ThemeMode.LIGHT : ThemeMode.DARK;
        return new ThemePreference(stored.followSystem, manualMode);
      } catch (e) {
        hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
          '主题偏好读取失败 source=%{public}s fallback=%{public}s', 'themePreference', 'true');
        return new ThemePreference(true, ThemeMode.DARK);
      }
    }
    const legacyFollow = await DatabaseHelper.getSetting('followSystemDark', 'true');
    const legacyManual = await DatabaseHelper.getSetting('manualDarkMode', 'true');
    const preference = new ThemePreference(legacyFollow === 'true',
      legacyManual === 'false' ? ThemeMode.LIGHT : ThemeMode.DARK);
    await DataRepository.saveThemePreference(preference);
    return preference;
  }

  static async saveThemePreference(preference: ThemePreference): Promise<void> {
    const stored = new StoredThemePreference();
    stored.followSystem = preference.followSystem;
    stored.manualMode = preference.manualMode;
    await DatabaseHelper.setSetting('themePreference', JSON.stringify(stored));
  }

  static async getGlobalBackground(): Promise<GlobalBackgroundPreference> {
    const raw = await DatabaseHelper.getSetting('globalBackgroundPreference', '');
    if (raw.length > 0) {
      try {
        const stored: StoredBackgroundPreference = JSON.parse(raw) as StoredBackgroundPreference;
        const globalUri = stored.globalUri && isSandboxBackgroundReference(stored.globalUri) ? stored.globalUri : '';
        let strength = Number.isInteger(stored.visibleStrength) ? stored.visibleStrength : 50;
        if (strength < 0 || strength > 100) {
          strength = 50;
        }
        return new GlobalBackgroundPreference(globalUri, strength);
      } catch (e) {
        hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置读取失败 source=%{public}s fallback=%{public}s', 'globalBackgroundPreference', 'true');
        return new GlobalBackgroundPreference('', 50);
      }
    }
    let migratedUri = '';
    const legacyRaw = await DatabaseHelper.getSetting('backgroundConfig', '');
    if (legacyRaw.length > 0) {
      try {
        const legacy: LegacyBackgroundConfig = JSON.parse(legacyRaw) as LegacyBackgroundConfig;
        if (legacy.global && isSandboxBackgroundReference(legacy.global)) {
          migratedUri = legacy.global;
        }
        hilog.info(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置迁移完成 source=%{public}s pagesIgnored=%{public}s', 'backgroundConfig', 'true');
      } catch (e) {
        migratedUri = '';
        hilog.warn(SETTINGS_DOMAIN, 'DataRepository',
          '背景配置迁移失败 source=%{public}s fallback=%{public}s', 'backgroundConfig', 'true');
      }
    }
    const migrated = new GlobalBackgroundPreference(migratedUri, 50);
    await DataRepository.saveGlobalBackground(migrated);
    await DatabaseHelper.setSetting('backgroundConfig', '');
    return migrated;
  }

  static async saveGlobalBackground(preference: GlobalBackgroundPreference): Promise<void> {
    if (!isSandboxBackgroundReference(preference.globalUri)) {
      throw new Error('EXTERNAL_URI_NOT_ALLOWED');
    }
    if (!Number.isInteger(preference.visibleStrength) || preference.visibleStrength < 0 ||
      preference.visibleStrength > 100) {
      throw new Error('INVALID_STRENGTH');
    }
    const stored = new StoredBackgroundPreference();
    stored.globalUri = preference.globalUri;
    stored.visibleStrength = preference.visibleStrength;
    await DatabaseHelper.setSetting('globalBackgroundPreference', JSON.stringify(stored));
  }
}

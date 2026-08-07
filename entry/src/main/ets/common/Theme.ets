// 智子 - 响应式多主题系统（沉浸光感版）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataRepository } from '../service/DataRepository';
import { BackgroundImporter, BackgroundImportResult } from '../service/BackgroundImporter';

const DOMAIN = 0x9201;

// ============================================================
// 颜色主题 ID
// ============================================================
export enum ColorThemeId {
  CYAN = 'cyan',       // 终端青绿
  OCEAN = 'ocean',     // 海洋蓝
  SUNSET = 'sunset',   // 日落橙
  AURORA = 'aurora',   // 极光紫
  SAKURA = 'sakura',   // 樱花粉
  FOREST = 'forest'    // 自然绿
}

export const COLOR_THEME_NAMES: Record<string, string> = {
  'cyan': '终端青绿',
  'ocean': '海洋蓝',
  'sunset': '日落橙',
  'aurora': '极光紫',
  'sakura': '樱花粉',
  'forest': '自然绿'
};

export const COLOR_THEME_COLORS: Record<string, string> = {
  'cyan': '#00D9A3',
  'ocean': '#3B82F6',
  'sunset': '#F59E0B',
  'aurora': '#8B5CF6',
  'sakura': '#EC4899',
  'forest': '#10B981'
};

// ============================================================
// 完整色板接口
// ============================================================
export interface ThemePalette {
  // 背景层次
  bgBase: string;
  bgSurface: string;
  bgSurface2: string;
  bgElevated: string;
  bgHover: string;
  // 边框
  borderSubtle: string;
  borderDefault: string;
  borderStrong: string;
  // 文字
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  // 主色系
  primary: string;
  primaryHover: string;
  primaryDim: string;
  // 状态色
  success: string;
  warning: string;
  danger: string;
  info: string;
  purple: string;
  // 系统
  statusBarContentColor: string;
  navBarContentColor: string;
  isDark: boolean;
  // 字号
  fsXs: number;
  fsSm: number;
  fsBase: number;
  fsMd: number;
  fsLg: number;
  fsXl: number;
  fs2xl: number;
  fs3xl: number;
  // 间距
  sp1: string;
  sp2: string;
  sp3: string;
  sp4: string;
  sp5: string;
  sp6: string;
  sp8: string;
  // 圆角
  radiusSm: string;
  radiusMd: string;
  radiusLg: string;
  radiusXl: string;
  // 字体
  fontSans: string;
  fontMono: string;
}

// ============================================================
// 辅助：构建深色色板
// ============================================================
function darkPalette(primary: string, primaryHover: string, primaryDim: string): ThemePalette {
  return {
    bgBase: '#0A0E1A',
    bgSurface: '#131826',
    bgSurface2: '#1A2030',
    bgElevated: '#232A3D',
    bgHover: '#2A3349',
    borderSubtle: '#1E293B',
    borderDefault: '#2D3748',
    borderStrong: '#3D4A63',
    textPrimary: '#E2E8F0',
    textSecondary: '#94A3B8',
    textTertiary: '#8B95A7',
    primary: primary,
    primaryHover: primaryHover,
    primaryDim: primaryDim,
    success: '#10B981',
    warning: '#F59E0B',
    danger: '#EF4444',
    info: '#3B82F6',
    purple: '#8B5CF6',
    statusBarContentColor: '#E2E8F0',
    navBarContentColor: '#E2E8F0',
    isDark: true,
    fsXs: 10,
    fsSm: 12,
    fsBase: 13,
    fsMd: 14,
    fsLg: 16,
    fsXl: 20,
    fs2xl: 26,
    fs3xl: 32,
    sp1: '4vp',
    sp2: '8vp',
    sp3: '12vp',
    sp4: '16vp',
    sp5: '20vp',
    sp6: '24vp',
    sp8: '32vp',
    radiusSm: '4vp',
    radiusMd: '6vp',
    radiusLg: '10vp',
    radiusXl: '14vp',
    fontSans: 'HarmonyOS Sans, sans-serif',
    fontMono: 'JetBrains Mono, Fira Code, Consolas, Courier New, monospace'
  };
}

// ============================================================
// 辅助：构建浅色色板
// ============================================================
function lightPalette(primary: string, primaryHover: string, primaryDim: string): ThemePalette {
  return {
    bgBase: '#F5F6FA',
    bgSurface: '#FFFFFF',
    bgSurface2: '#F0F1F5',
    bgElevated: '#FFFFFF',
    bgHover: '#EBEDF2',
    borderSubtle: '#E5E7EB',
    borderDefault: '#D1D5DB',
    borderStrong: '#9CA3AF',
    textPrimary: '#1A202C',
    textSecondary: '#64748B',
    textTertiary: '#94A3B8',
    primary: primary,
    primaryHover: primaryHover,
    primaryDim: primaryDim,
    success: '#059669',
    warning: '#D97706',
    danger: '#DC2626',
    info: '#2563EB',
    purple: '#7C3AED',
    statusBarContentColor: '#1A202C',
    navBarContentColor: '#1A202C',
    isDark: false,
    fsXs: 10,
    fsSm: 12,
    fsBase: 13,
    fsMd: 14,
    fsLg: 16,
    fsXl: 20,
    fs2xl: 26,
    fs3xl: 32,
    sp1: '4vp',
    sp2: '8vp',
    sp3: '12vp',
    sp4: '16vp',
    sp5: '20vp',
    sp6: '24vp',
    sp8: '32vp',
    radiusSm: '4vp',
    radiusMd: '6vp',
    radiusLg: '10vp',
    radiusXl: '14vp',
    fontSans: 'HarmonyOS Sans, sans-serif',
    fontMono: 'JetBrains Mono, Fira Code, Consolas, Courier New, monospace'
  };
}

// ============================================================
// 6 种颜色主题 × 深色/浅色 = 12 套色板
// ============================================================
function buildPalette(themeId: ColorThemeId, isDark: boolean): ThemePalette {
  switch (themeId) {
    case ColorThemeId.CYAN:
      return isDark
        ? darkPalette('#00D9A3', '#00F0B5', 'rgba(0, 217, 163, 0.15)')
        : lightPalette('#00A67D', '#00C090', 'rgba(0, 166, 125, 0.12)');
    case ColorThemeId.OCEAN:
      return isDark
        ? darkPalette('#3B82F6', '#60A5FA', 'rgba(59, 130, 246, 0.15)')
        : lightPalette('#2563EB', '#3B82F6', 'rgba(37, 99, 235, 0.12)');
    case ColorThemeId.SUNSET:
      return isDark
        ? darkPalette('#F59E0B', '#FBBF24', 'rgba(245, 158, 11, 0.15)')
        : lightPalette('#D97706', '#F59E0B', 'rgba(217, 119, 6, 0.12)');
    case ColorThemeId.AURORA:
      return isDark
        ? darkPalette('#8B5CF6', '#A78BFA', 'rgba(139, 92, 246, 0.15)')
        : lightPalette('#7C3AED', '#8B5CF6', 'rgba(124, 58, 237, 0.12)');
    case ColorThemeId.SAKURA:
      return isDark
        ? darkPalette('#EC4899', '#F472B6', 'rgba(236, 72, 153, 0.15)')
        : lightPalette('#DB2777', '#EC4899', 'rgba(219, 39, 119, 0.12)');
    case ColorThemeId.FOREST:
      return isDark
        ? darkPalette('#10B981', '#34D399', 'rgba(16, 185, 129, 0.15)')
        : lightPalette('#059669', '#10B981', 'rgba(5, 150, 105, 0.12)');
    default:
      return darkPalette('#00D9A3', '#00F0B5', 'rgba(0, 217, 163, 0.15)');
  }
}

// ============================================================
// 默认浅色色板（用于组件初始化兜底）
// ============================================================
export const defaultLightPalette: ThemePalette = buildPalette(ColorThemeId.CYAN, false);
export const defaultDarkPalette: ThemePalette = buildPalette(ColorThemeId.CYAN, true);

export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

export enum PreferenceFailureReason {
  INVALID_VALUE = 'INVALID_VALUE',
  INVALID_STRENGTH = 'INVALID_STRENGTH',
  PERSISTENCE_FAILED = 'PERSISTENCE_FAILED',
  SYSTEM_MODE_UNAVAILABLE = 'SYSTEM_MODE_UNAVAILABLE',
  BACKGROUND_LOAD_FAILED = 'BACKGROUND_LOAD_FAILED',
  BACKGROUND_IMPORT_FAILED = 'BACKGROUND_IMPORT_FAILED'
}

export enum BackgroundDisplayState {
  LOADING = 'loading',
  READY = 'ready',
  INVALID = 'invalid'
}

export class ThemePreference {
  followSystem: boolean;
  manualMode: ThemeMode;

  constructor(followSystem: boolean, manualMode: ThemeMode) {
    this.followSystem = followSystem;
    this.manualMode = manualMode;
  }
}

export class EffectiveThemeState {
  followSystem: boolean;
  manualMode: ThemeMode;
  effectiveMode: ThemeMode;

  constructor(followSystem: boolean, manualMode: ThemeMode, effectiveMode: ThemeMode) {
    this.followSystem = followSystem;
    this.manualMode = manualMode;
    this.effectiveMode = effectiveMode;
  }
}

export class GlobalBackgroundPreference {
  globalUri: string;
  visibleStrength: number;

  constructor(globalUri: string, visibleStrength: number) {
    this.globalUri = globalUri;
    this.visibleStrength = visibleStrength;
  }
}

export class ThemeMutationResult {
  success: boolean;
  reason: PreferenceFailureReason | null;
  operationVersion: number;
  snapshot: EffectiveThemeState;
  rollbackSnapshot: EffectiveThemeState;

  constructor(success: boolean, reason: PreferenceFailureReason | null, operationVersion: number,
    snapshot: EffectiveThemeState, rollbackSnapshot: EffectiveThemeState) {
    this.success = success;
    this.reason = reason;
    this.operationVersion = operationVersion;
    this.snapshot = snapshot;
    this.rollbackSnapshot = rollbackSnapshot;
  }
}

export class BackgroundMutationResult {
  success: boolean;
  reason: PreferenceFailureReason | null;
  operationVersion: number;
  snapshot: GlobalBackgroundPreference;
  rollbackSnapshot: GlobalBackgroundPreference;

  constructor(success: boolean, reason: PreferenceFailureReason | null, operationVersion: number,
    snapshot: GlobalBackgroundPreference, rollbackSnapshot: GlobalBackgroundPreference) {
    this.success = success;
    this.reason = reason;
    this.operationVersion = operationVersion;
    this.snapshot = snapshot;
    this.rollbackSnapshot = rollbackSnapshot;
  }
}

// ============================================================
// ThemeManager 单例
// ============================================================
export class ThemeManager {
  private static instance: ThemeManager;
  private currentColorTheme: ColorThemeId = ColorThemeId.CYAN;
  private isSystemDark: boolean = true;
  private followSystem: boolean = true;
  private manualMode: ThemeMode = ThemeMode.DARK;
  private backgroundPreference: GlobalBackgroundPreference = new GlobalBackgroundPreference('', 50);
  private context: Context | null = null;
  private initialized: boolean = false;
  private themeOperationVersion: number = 0;
  private lastSuccessfulThemeVersion: number = 0;
  private lastSuccessfulTheme: EffectiveThemeState = new EffectiveThemeState(true, ThemeMode.DARK, ThemeMode.DARK);
  private backgroundOperationVersion: number = 0;
  private lastSuccessfulBackgroundVersion: number = 0;
  private lastSuccessfulBackground: GlobalBackgroundPreference = new GlobalBackgroundPreference('', 50);

  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  async init(context: Context, isSystemDark: boolean = true): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.context = context;
    this.isSystemDark = isSystemDark;
    try {
      // 加载颜色主题偏好
      const savedTheme = await DataRepository.getSetting('colorTheme', 'cyan');
      this.currentColorTheme = savedTheme as ColorThemeId;

      const themePreference = await DataRepository.getThemePreference();
      this.followSystem = themePreference.followSystem;
      this.manualMode = themePreference.manualMode;
      this.backgroundPreference = await DataRepository.getGlobalBackground();
      this.lastSuccessfulBackground = this.getGlobalBackground();
      this.lastSuccessfulTheme = this.getThemeState();

      // 加载字号配置
      const fontSize = await DataRepository.getSetting('fontSizeScale', 'standard');
      this.applyFontSize(fontSize);

      this.initialized = true;
      hilog.info(DOMAIN, 'Theme', '主题管理器初始化完成: color=%{public}s dark=%{public}s followSys=%{public}s',
        this.currentColorTheme, this.getIsDark() ? 'true' : 'false', this.followSystem ? 'true' : 'false');

      // 首次写入 AppStorage
      this.applyTheme();
      this.publishInitialBackground();
    } catch (e) {
      hilog.error(DOMAIN, 'Theme', '主题读取失败 reason=%{public}s fallback=%{public}s',
        PreferenceFailureReason.PERSISTENCE_FAILED, 'true');
      this.initialized = true;
      this.applyTheme(); // 使用默认值
      this.publishInitialBackground();
    }
  }

  // 系统深色模式变化回调（由 EntryAbility.onConfigurationUpdate 触发）
  onSystemDarkModeChange(isDark: boolean): void {
    this.isSystemDark = isDark;
    if (this.followSystem) {
      this.applyTheme();
      hilog.info(DOMAIN, 'Theme', '系统深色模式变更: dark=%{public}s', isDark ? 'true' : 'false');
    }
  }

  // 设置颜色主题
  async setColorTheme(themeId: ColorThemeId): Promise<void> {
    this.currentColorTheme = themeId;
    await DataRepository.setSetting('colorTheme', themeId);
    this.applyTheme();
  }

  // 设置是否跟随系统深色模式
  async setFollowSystem(follow: boolean): Promise<ThemeMutationResult> {
    const rollbackSnapshot = this.lastSuccessfulTheme;
    const operationVersion = ++this.themeOperationVersion;
    const next = new ThemePreference(follow, this.manualMode);
    this.followSystem = follow;
    this.applyTheme();
    const operationSnapshot = this.getThemeState();
    try {
      await DataRepository.saveThemePreference(next);
      if (operationVersion > this.lastSuccessfulThemeVersion) {
        this.lastSuccessfulThemeVersion = operationVersion;
        this.lastSuccessfulTheme = operationSnapshot;
      }
      return new ThemeMutationResult(true, null, operationVersion, this.getThemeState(), rollbackSnapshot);
    } catch (e) {
      if (operationVersion === this.themeOperationVersion) {
        this.restoreTheme(rollbackSnapshot);
      }
      hilog.error(DOMAIN, 'Theme', '主题写入失败 reason=%{public}s rollback=%{public}s',
        PreferenceFailureReason.PERSISTENCE_FAILED, 'true');
      return new ThemeMutationResult(false, PreferenceFailureReason.PERSISTENCE_FAILED, operationVersion,
        this.getThemeState(), rollbackSnapshot);
    }
  }

  // 设置手动深色/浅色模式（仅在 followSystem=false 时生效）
  async setManualMode(mode: ThemeMode): Promise<ThemeMutationResult> {
    const rollbackSnapshot = this.lastSuccessfulTheme;
    const operationVersion = ++this.themeOperationVersion;
    const next = new ThemePreference(this.followSystem, mode);
    this.manualMode = mode;
    this.applyTheme();
    const operationSnapshot = this.getThemeState();
    try {
      await DataRepository.saveThemePreference(next);
      if (operationVersion > this.lastSuccessfulThemeVersion) {
        this.lastSuccessfulThemeVersion = operationVersion;
        this.lastSuccessfulTheme = operationSnapshot;
      }
      return new ThemeMutationResult(true, null, operationVersion, this.getThemeState(), rollbackSnapshot);
    } catch (e) {
      if (operationVersion === this.themeOperationVersion) {
        this.restoreTheme(rollbackSnapshot);
      }
      hilog.error(DOMAIN, 'Theme', '主题写入失败 reason=%{public}s rollback=%{public}s',
        PreferenceFailureReason.PERSISTENCE_FAILED, 'true');
      return new ThemeMutationResult(false, PreferenceFailureReason.PERSISTENCE_FAILED, operationVersion,
        this.getThemeState(), rollbackSnapshot);
    }
  }

  // 获取当前是否为深色模式
  getIsDark(): boolean {
    if (this.followSystem) {
      return this.isSystemDark;
    }
    return this.manualMode === ThemeMode.DARK;
  }

  // 获取当前颜色主题
  getCurrentColorTheme(): ColorThemeId {
    return this.currentColorTheme;
  }

  // 获取当前色板
  getPalette(): ThemePalette {
    return buildPalette(this.currentColorTheme, this.getIsDark());
  }

  // 应用字号缩放
  async setFontSize(scale: string): Promise<void> {
    await DataRepository.setSetting('fontSizeScale', scale);
    this.applyFontSize(scale);
    this.applyTheme();
  }

  private applyFontSize(scale: string): void {
    // 字号缩放因子存储在 AppStorage 中，组件层通过 @StorageLink 获取
    AppStorage.setOrCreate('fontSizeScale', scale);
  }

  // 获取缩放后的字号（供组件使用）
  static scaledFontSize(base: number, scale: string): number {
    if (scale === 'small') return Math.max(8, base - 2);
    if (scale === 'large') return base + 2;
    return base;
  }

  // 应用主题到 AppStorage
  private applyTheme(): void {
    const palette = this.getPalette();
    AppStorage.setOrCreate('themePalette', palette);
    AppStorage.setOrCreate('isDarkMode', palette.isDark);
    AppStorage.setOrCreate('colorThemeId', this.currentColorTheme);
    AppStorage.setOrCreate('followSystemDark', this.followSystem);
    AppStorage.setOrCreate('manualThemeMode', this.manualMode);
    AppStorage.setOrCreate('effectiveThemeMode', this.getIsDark() ? ThemeMode.DARK : ThemeMode.LIGHT);
    AppStorage.setOrCreate('globalBackgroundUri', this.backgroundPreference.globalUri);
    AppStorage.setOrCreate('backgroundVisibleStrength', this.backgroundPreference.visibleStrength);
  }

  private publishInitialBackground(): void {
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', this.backgroundPreference.globalUri.length > 0 ?
      BackgroundDisplayState.READY : BackgroundDisplayState.INVALID);
  }

  getThemeState(): EffectiveThemeState {
    const effectiveMode = this.getIsDark() ? ThemeMode.DARK : ThemeMode.LIGHT;
    return new EffectiveThemeState(this.followSystem, this.manualMode, effectiveMode);
  }

  private restoreTheme(snapshot: EffectiveThemeState): void {
    this.followSystem = snapshot.followSystem;
    this.manualMode = snapshot.manualMode;
    this.applyTheme();
  }

  getGlobalBackground(): GlobalBackgroundPreference {
    return new GlobalBackgroundPreference(this.backgroundPreference.globalUri,
      this.backgroundPreference.visibleStrength);
  }

  async setGlobalBackground(uri: string): Promise<BackgroundMutationResult> {
    return await this.saveBackground(new GlobalBackgroundPreference(uri,
      this.backgroundPreference.visibleStrength));
  }

  beginBackgroundCandidate(uri: string): void {
    AppStorage.setOrCreate('backgroundCandidateUri', uri);
    AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.LOADING);
  }

  async importBackgroundCandidate(sourceUri: string): Promise<BackgroundMutationResult> {
    const rollback = this.copyBackground(this.lastSuccessfulBackground);
    if (this.context === null) {
      this.restoreBackground(rollback, rollback.globalUri.length > 0 ? BackgroundDisplayState.READY :
        BackgroundDisplayState.INVALID);
      return new BackgroundMutationResult(false, PreferenceFailureReason.BACKGROUND_IMPORT_FAILED,
        this.backgroundOperationVersion, this.getGlobalBackground(), rollback);
    }
    const imported: BackgroundImportResult = BackgroundImporter.importToSandbox(this.context, sourceUri);
    if (!imported.success) {
      this.restoreBackground(rollback, rollback.globalUri.length > 0 ? BackgroundDisplayState.READY :
        BackgroundDisplayState.INVALID);
      hilog.error(DOMAIN, 'Theme', '背景导入失败 reason=%{public}s rollback=%{public}s',
        PreferenceFailureReason.BACKGROUND_IMPORT_FAILED, 'true');
      return new BackgroundMutationResult(false, PreferenceFailureReason.BACKGROUND_IMPORT_FAILED,
        this.backgroundOperationVersion, this.getGlobalBackground(), rollback);
    }
    return await this.saveBackground(new GlobalBackgroundPreference(imported.sandboxUri,
      this.backgroundPreference.visibleStrength));
  }

  async clearGlobalBackground(): Promise<BackgroundMutationResult> {
    return await this.saveBackground(new GlobalBackgroundPreference('',
      this.backgroundPreference.visibleStrength));
  }

  async setBackgroundStrength(strength: number): Promise<BackgroundMutationResult> {
    if (!Number.isInteger(strength) || strength < 0 || strength > 100) {
      return new BackgroundMutationResult(false, PreferenceFailureReason.INVALID_STRENGTH,
        this.backgroundOperationVersion, this.getGlobalBackground(), this.copyBackground(this.lastSuccessfulBackground));
    }
    return await this.saveBackground(new GlobalBackgroundPreference(this.backgroundPreference.globalUri, strength));
  }

  reportBackgroundLoadFailure(): void {
    hilog.warn(DOMAIN, 'Theme', '背景加载失败 reason=%{public}s fallback=%{public}s',
      PreferenceFailureReason.BACKGROUND_LOAD_FAILED, 'true');
    AppStorage.setOrCreate('globalBackgroundUri', '');
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.INVALID);
  }

  reportBackgroundReady(): void {
    if (this.backgroundPreference.globalUri.length > 0) {
      AppStorage.setOrCreate('backgroundCandidateUri', '');
      AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.READY);
    }
  }

  private async saveBackground(next: GlobalBackgroundPreference): Promise<BackgroundMutationResult> {
    const rollback = this.copyBackground(this.lastSuccessfulBackground);
    const operationVersion = ++this.backgroundOperationVersion;
    this.backgroundPreference = this.copyBackground(next);
    AppStorage.setOrCreate('globalBackgroundUri', next.globalUri);
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundVisibleStrength', next.visibleStrength);
    AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.READY);
    try {
      await DataRepository.saveGlobalBackground(next);
      if (operationVersion > this.lastSuccessfulBackgroundVersion) {
        this.lastSuccessfulBackgroundVersion = operationVersion;
        this.lastSuccessfulBackground = this.copyBackground(next);
      }
      return new BackgroundMutationResult(true, null, operationVersion, this.getGlobalBackground(), rollback);
    } catch (e) {
      if (operationVersion === this.backgroundOperationVersion) {
        this.restoreBackground(rollback, BackgroundDisplayState.READY);
      }
      hilog.error(DOMAIN, 'Theme', '背景写入失败 reason=%{public}s rollback=%{public}s strength=%{public}d',
        PreferenceFailureReason.PERSISTENCE_FAILED, 'true', rollback.visibleStrength);
      return new BackgroundMutationResult(false, PreferenceFailureReason.PERSISTENCE_FAILED, operationVersion,
        this.getGlobalBackground(), rollback);
    }
  }

  private copyBackground(source: GlobalBackgroundPreference): GlobalBackgroundPreference {
    return new GlobalBackgroundPreference(source.globalUri, source.visibleStrength);
  }

  private restoreBackground(snapshot: GlobalBackgroundPreference, state: BackgroundDisplayState): void {
    this.backgroundPreference = this.copyBackground(snapshot);
    AppStorage.setOrCreate('globalBackgroundUri', snapshot.globalUri);
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundVisibleStrength', snapshot.visibleStrength);
    AppStorage.setOrCreate('backgroundDisplayState', state);
  }
}

// ============================================================
// 进度条颜色阈值（响应式版本）
// ============================================================
export function progressColor(value: number, palette: ThemePalette): string {
  if (value >= 85) return palette.danger;
  if (value >= 65) return palette.warning;
  return palette.success;
}

// ============================================================
// 状态文本映射（响应式版本）
// ============================================================
export class StatusInfo {
  text: string;
  color: string;
  dotColor: string;

  constructor(text: string, color: string, dotColor: string) {
    this.text = text;
    this.color = color;
    this.dotColor = dotColor;
  }
}

export function statusInfo(status: string, palette: ThemePalette): StatusInfo {
  const map = new Map<string, StatusInfo>();
  map.set('online', new StatusInfo('在线', palette.success, palette.success));
  map.set('warning', new StatusInfo('告警', palette.warning, palette.warning));
  map.set('offline', new StatusInfo('离线', palette.textTertiary, palette.textTertiary));
  map.set('running', new StatusInfo('运行中', palette.success, palette.success));
  map.set('stopped', new StatusInfo('已停止', palette.danger, palette.danger));
  map.set('paused', new StatusInfo('已暂停', palette.warning, palette.warning));
  map.set('success', new StatusInfo('成功', palette.success, palette.success));
  map.set('failed', new StatusInfo('失败', palette.danger, palette.danger));
  map.set('active', new StatusInfo('可用', palette.success, palette.success));
  return map.get(status) || map.get('offline')!;
}

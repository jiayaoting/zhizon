// 智子 - 响应式多主题系统（沉浸光感版）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataRepository } from '../service/DataRepository';
import { BackgroundImporter, BackgroundImportResult } from '../service/BackgroundImporter';
import { PreferenceSnapshot, PreferencePersistenceResult } from '../model/GovernanceModels';
import { ThemeMode, ThemePreference, GlobalBackgroundPreference } from './ThemeContracts';

export { ThemeMode, ThemePreference, GlobalBackgroundPreference } from './ThemeContracts';

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

export function colorThemeName(themeId: ColorThemeId): string {
  if (themeId === ColorThemeId.CYAN) return '终端青绿';
  if (themeId === ColorThemeId.OCEAN) return '海洋蓝';
  if (themeId === ColorThemeId.SUNSET) return '日落橙';
  if (themeId === ColorThemeId.AURORA) return '极光紫';
  if (themeId === ColorThemeId.SAKURA) return '樱花粉';
  return '自然绿';
}

export function colorThemeColor(themeId: ColorThemeId): string {
  if (themeId === ColorThemeId.CYAN) return '#00D9A3';
  if (themeId === ColorThemeId.OCEAN) return '#3B82F6';
  if (themeId === ColorThemeId.SUNSET) return '#F59E0B';
  if (themeId === ColorThemeId.AURORA) return '#8B5CF6';
  if (themeId === ColorThemeId.SAKURA) return '#EC4899';
  return '#10B981';
}

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
  // 玻璃材质背景（毛玻璃效果使用）
  bgGlassBar: string;      // 顶栏/底栏玻璃色
  bgGlassCard: string;     // 指标卡/列表卡玻璃色
  bgGlassCard2: string;    // 卡片内次级元素玻璃色
  borderGlass: string;     // 玻璃边框色
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
    bgGlassBar: 'rgba(19, 24, 38, 0.35)',
    bgGlassCard: 'rgba(19, 24, 38, 0.30)',
    bgGlassCard2: 'rgba(26, 32, 48, 0.35)',
    borderGlass: 'rgba(61, 74, 99, 0.40)',
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
    bgGlassBar: 'rgba(255, 255, 255, 0.35)',
    bgGlassCard: 'rgba(255, 255, 255, 0.30)',
    bgGlassCard2: 'rgba(240, 241, 245, 0.35)',
    borderGlass: 'rgba(209, 213, 219, 0.40)',
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

// ============================================================
// 字号缩放比例
// 5 档：超小、小、标准、大、特大
// ============================================================
function fontSizeRatio(scale: string): number {
  if (scale === 'xsmall') return 0.8;
  if (scale === 'small') return 0.9;
  if (scale === 'large') return 1.3;
  if (scale === 'xlarge') return 1.45;
  return 1.0; // standard
}

// 按字号档位缩放 fs 系列，并注入全局字体（原地修改 palette）
function applyFontPreferences(palette: ThemePalette, fontSizeScale: string, fontFamily: string): void {
  // 字号缩放由系统级 setFontSizeScale 统一处理（对全部 Text 生效），此处不再缩放 fs 系列
  if (fontFamily.length > 0 && fontFamily !== 'HarmonyOS Sans') {
    palette.fontSans = fontFamily + ', HarmonyOS Sans, sans-serif';
  }
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

export enum PreferenceMutationType {
  FOLLOW_SYSTEM = 'FOLLOW_SYSTEM',
  MANUAL_MODE = 'MANUAL_MODE',
  COLOR_THEME = 'COLOR_THEME',
  FONT_SIZE = 'FONT_SIZE',
  BACKGROUND = 'BACKGROUND',
  BACKGROUND_STRENGTH = 'BACKGROUND_STRENGTH',
  GLASS_EFFECT = 'GLASS_EFFECT'
}

export class PreferenceMutation {
  operationVersion: number;
  type: PreferenceMutationType;
  booleanValue: boolean;
  stringValue: string;
  numberValue: number;
  importedFile: string;

  constructor(type: PreferenceMutationType, booleanValue: boolean, stringValue: string, numberValue: number,
    importedFile: string = '') {
    this.operationVersion = 0;
    this.type = type;
    this.booleanValue = booleanValue;
    this.stringValue = stringValue;
    this.numberValue = numberValue;
    this.importedFile = importedFile;
  }
}

export class PreferenceMutationResult {
  success: boolean;
  restored: boolean;
  published: boolean;
  reason: PreferenceFailureReason | null;
  operationVersion: number;
  snapshot: PreferenceSnapshot;
  rollbackSnapshot: PreferenceSnapshot;

  constructor(success: boolean, restored: boolean, published: boolean, reason: PreferenceFailureReason | null,
    operationVersion: number, snapshot: PreferenceSnapshot, rollbackSnapshot: PreferenceSnapshot) {
    this.success = success;
    this.restored = restored;
    this.published = published;
    this.reason = reason;
    this.operationVersion = operationVersion;
    this.snapshot = snapshot;
    this.rollbackSnapshot = rollbackSnapshot;
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
  private effectiveMode: ThemeMode = ThemeMode.DARK;
  private backgroundPreference: GlobalBackgroundPreference = new GlobalBackgroundPreference('', 50);
  private glassEffectEnabled: boolean = false;
  private fontSizeScale: string = 'standard';
  private fontFamily: string = 'HarmonyOS Sans';
  private context: Context | null = null;
  private initialized: boolean = false;
  private themeOperationVersion: number = 0;
  private lastSuccessfulThemeVersion: number = 0;
  private lastSuccessfulTheme: EffectiveThemeState = new EffectiveThemeState(true, ThemeMode.DARK, ThemeMode.DARK);
  private backgroundOperationVersion: number = 0;
  private lastSuccessfulBackgroundVersion: number = 0;
  private lastSuccessfulBackground: GlobalBackgroundPreference = new GlobalBackgroundPreference('', 50);
  private operationVersion: number = 0;
  private mutationQueue: Promise<PreferenceMutationResult> | null = null;
  private pendingFollowSystemVersion: number = 0;

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
      this.currentColorTheme = this.isColorTheme(savedTheme) ? savedTheme as ColorThemeId : ColorThemeId.CYAN;

      const themePreference = await DataRepository.getThemePreference();
      this.followSystem = themePreference.followSystem;
      this.manualMode = themePreference.manualMode;
      this.effectiveMode = this.followSystem ?
        (this.isSystemDark ? ThemeMode.DARK : ThemeMode.LIGHT) : this.manualMode;
      this.backgroundPreference = await DataRepository.getGlobalBackground();
      this.lastSuccessfulBackground = this.getGlobalBackground();
      this.lastSuccessfulTheme = this.getThemeState();

      // 加载字号配置
      const fontSize = await DataRepository.getSetting('fontSizeScale', 'standard');
      this.fontSizeScale = this.isFontSizeScale(fontSize) ? fontSize : 'standard';

      // 加载全局字体
      this.fontFamily = await DataRepository.getSetting('fontFamily', 'HarmonyOS Sans');
      if (!this.isSupportedFontFamily(this.fontFamily)) {
        this.fontFamily = 'HarmonyOS Sans';
      }

      // 加载毛玻璃开关
      const glassEnabled = await DataRepository.getSetting('glassEffectEnabled', 'false');
      this.glassEffectEnabled = glassEnabled === 'true';

      this.applyFontSize(this.fontSizeScale);
      DataRepository.initializePreferenceSnapshot(this.createPreferenceSnapshot(0));

      this.initialized = true;
      hilog.info(DOMAIN, 'Theme', '主题管理器初始化完成: color=%{public}s dark=%{public}s followSys=%{public}s glass=%{public}s',
        this.currentColorTheme, this.getIsDark() ? 'true' : 'false', this.followSystem ? 'true' : 'false',
        this.glassEffectEnabled ? 'true' : 'false');

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
    if (this.followSystem && this.pendingFollowSystemVersion === 0) {
      this.effectiveMode = isDark ? ThemeMode.DARK : ThemeMode.LIGHT;
      this.applyTheme();
      hilog.info(DOMAIN, 'Theme', '系统深色模式变更: dark=%{public}s', isDark ? 'true' : 'false');
    }
  }

  // 设置颜色主题
  async setColorTheme(themeId: ColorThemeId): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.COLOR_THEME,
      false, themeId, 0));
  }

  // 设置是否跟随系统深色模式
  async setFollowSystem(follow: boolean): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.FOLLOW_SYSTEM,
      follow, '', 0));
  }

  // 设置手动深色/浅色模式（仅在 followSystem=false 时生效）
  async setManualMode(mode: ThemeMode): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.MANUAL_MODE,
      false, mode, 0));
  }

  // 获取当前是否为深色模式
  getIsDark(): boolean {
    return this.effectiveMode === ThemeMode.DARK;
  }

  // 获取当前颜色主题
  getCurrentColorTheme(): ColorThemeId {
    return this.currentColorTheme;
  }

  // 获取当前色板
  getPalette(): ThemePalette {
    const raw = buildPalette(this.currentColorTheme, this.getIsDark());
    applyFontPreferences(raw, this.fontSizeScale, this.fontFamily);
    return raw;
  }

  // 应用字号缩放
  async setFontSize(scale: string): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.FONT_SIZE,
      false, scale, 0));
  }

  private applyFontSize(scale: string): void {
    // 字号缩放因子存储在 AppStorage 中，组件层通过 @StorageLink 获取
    AppStorage.setOrCreate('fontSizeScale', scale);
    // 系统级全局缩放：对所有 Text（含硬编码字号）生效
    try {
      if (this.context !== null) {
        this.context.getApplicationContext().setFontSizeScale(fontSizeRatio(scale));
      }
    } catch (e) {
      // 系统不支持全局字号缩放时忽略
    }
  }

  // 设置全局字体
  async setFontFamily(family: string): Promise<void> {
    if (family === this.fontFamily || family.length === 0) return;
    this.fontFamily = family;
    try {
      await DataRepository.setSetting('fontFamily', family);
    } catch (e) {
      // 持久化失败不阻断界面更新
    }
    this.applyTheme();
    AppStorage.setOrCreate('fontFamily', family);
  }

  // 获取缩放后的字号（供组件使用）
  static scaledFontSize(base: number, scale: string): number {
    if (scale === 'xsmall') return Math.max(8, Math.round(base * 0.8));
    if (scale === 'small') return Math.max(8, Math.round(base * 0.9));
    if (scale === 'large') return Math.round(base * 1.3);
    if (scale === 'xlarge') return Math.round(base * 1.45);
    return base; // standard
  }

  // 应用主题到 AppStorage
  private applyTheme(): void {
    const raw = buildPalette(this.currentColorTheme, this.effectiveMode === ThemeMode.DARK);
    applyFontPreferences(raw, this.fontSizeScale, this.fontFamily);
    AppStorage.setOrCreate('themePalette', raw);
    AppStorage.setOrCreate('isDarkMode', raw.isDark);
    AppStorage.setOrCreate('colorThemeId', this.currentColorTheme);
    AppStorage.setOrCreate('followSystemDark', this.followSystem);
    AppStorage.setOrCreate('manualThemeMode', this.manualMode);
    AppStorage.setOrCreate('effectiveThemeMode', this.effectiveMode);
    AppStorage.setOrCreate('globalBackgroundUri', this.backgroundPreference.globalUri);
    AppStorage.setOrCreate('backgroundVisibleStrength', this.backgroundPreference.visibleStrength);
    AppStorage.setOrCreate('glassEffectEnabled', this.glassEffectEnabled);
  }

  private publishInitialBackground(): void {
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', this.backgroundPreference.globalUri.length > 0 ?
      BackgroundDisplayState.READY : BackgroundDisplayState.INVALID);
  }

  getThemeState(): EffectiveThemeState {
    return new EffectiveThemeState(this.followSystem, this.manualMode, this.effectiveMode);
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

  async setGlobalBackground(uri: string): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.BACKGROUND,
      false, uri, 0));
  }

  beginBackgroundCandidate(uri: string): void {
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.LOADING);
  }

  async importBackgroundCandidate(sourceUri: string): Promise<PreferenceMutationResult> {
    const operationVersion = ++this.operationVersion;
    const rollback = DataRepository.getPreferenceSnapshot();
    if (this.context === null) {
      this.restoreBackground(this.backgroundFromSnapshot(rollback), rollback.backgroundUri.length > 0 ? BackgroundDisplayState.READY :
        BackgroundDisplayState.INVALID);
      return new PreferenceMutationResult(false, true, true, PreferenceFailureReason.BACKGROUND_IMPORT_FAILED,
        operationVersion, rollback, rollback);
    }
    const imported: BackgroundImportResult = await BackgroundImporter.importToSandbox(this.context, sourceUri);
    if (!imported.success) {
      const currentSnapshot = DataRepository.getPreferenceSnapshot();
      if (operationVersion === this.operationVersion) {
        this.publishPreferenceSnapshot(currentSnapshot);
        this.restoreBackground(this.backgroundFromSnapshot(currentSnapshot), currentSnapshot.backgroundUri.length > 0 ?
          BackgroundDisplayState.READY : BackgroundDisplayState.INVALID);
      }
      hilog.error(DOMAIN, 'Theme', '背景导入失败 reason=%{public}s rollback=%{public}s',
        PreferenceFailureReason.BACKGROUND_IMPORT_FAILED, 'true');
      return new PreferenceMutationResult(false, operationVersion === this.operationVersion,
        operationVersion === this.operationVersion, PreferenceFailureReason.BACKGROUND_IMPORT_FAILED,
        operationVersion, currentSnapshot, rollback);
    }
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.BACKGROUND,
      false, imported.sandboxUri, 0, imported.sandboxUri), operationVersion);
  }

  async clearGlobalBackground(): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.BACKGROUND,
      false, '', 0));
  }

  async setBackgroundStrength(strength: number): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.BACKGROUND_STRENGTH,
      false, '', strength));
  }

  // 设置毛玻璃效果开关
  async setGlassEffect(enabled: boolean): Promise<PreferenceMutationResult> {
    return await this.enqueueMutation(new PreferenceMutation(PreferenceMutationType.GLASS_EFFECT,
      enabled, '', 0));
  }

  // 获取毛玻璃效果是否开启
  getGlassEffectEnabled(): boolean {
    return this.glassEffectEnabled;
  }

  reportBackgroundLoadFailure(uri: string): void {
    if (uri !== this.backgroundPreference.globalUri) return;
    hilog.warn(DOMAIN, 'Theme', '背景加载失败 reason=%{public}s fallback=%{public}s',
      PreferenceFailureReason.BACKGROUND_LOAD_FAILED, 'true');
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.INVALID);
  }

  reportBackgroundReady(uri: string): void {
    if (uri === this.backgroundPreference.globalUri && this.backgroundPreference.globalUri.length > 0) {
      AppStorage.setOrCreate('backgroundCandidateUri', '');
      AppStorage.setOrCreate('backgroundDisplayState', BackgroundDisplayState.READY);
    }
  }

  private async enqueueMutation(mutation: PreferenceMutation,
    reservedVersion: number = 0): Promise<PreferenceMutationResult> {
    const operationVersion = reservedVersion > 0 ? reservedVersion : ++this.operationVersion;
    mutation.operationVersion = operationVersion;
    if (mutation.type === PreferenceMutationType.FOLLOW_SYSTEM) {
      this.pendingFollowSystemVersion = operationVersion;
    }
    let queued: Promise<PreferenceMutationResult>;
    if (this.mutationQueue === null) {
      queued = this.executeMutation(mutation, operationVersion);
    } else {
      queued = this.mutationQueue.then(
        this.continueMutation.bind(this, mutation, operationVersion),
        this.continueMutationAfterFailure.bind(this, mutation, operationVersion));
    }
    this.mutationQueue = queued;
    return await queued;
  }

  private async continueMutation(mutation: PreferenceMutation,
    operationVersion: number): Promise<PreferenceMutationResult> {
    return await this.executeMutation(mutation, operationVersion);
  }

  private async continueMutationAfterFailure(mutation: PreferenceMutation,
    operationVersion: number): Promise<PreferenceMutationResult> {
    return await this.executeMutation(mutation, operationVersion);
  }

  private async executeMutation(mutation: PreferenceMutation,
    operationVersion: number): Promise<PreferenceMutationResult> {
    const rollback = DataRepository.getPreferenceSnapshot();
    const candidate = this.buildCandidate(rollback, mutation, operationVersion);
    if (candidate === null) {
      this.completeFollowSystemMutation(mutation, operationVersion);
      if (mutation.importedFile.length > 0) BackgroundImporter.removeSandboxFile(mutation.importedFile);
      return new PreferenceMutationResult(false, false, false, PreferenceFailureReason.INVALID_VALUE,
        operationVersion, rollback, rollback);
    }
    const persisted: PreferencePersistenceResult = await DataRepository.persistPreferenceCandidate(candidate);
    if (!persisted.success) {
      if (mutation.importedFile.length > 0) BackgroundImporter.removeSandboxFile(mutation.importedFile);
      const latest = operationVersion === this.operationVersion;
      this.completeFollowSystemMutation(mutation, operationVersion);
      if (latest) this.publishPreferenceSnapshot(persisted.rollbackSnapshot,
        mutation.type === PreferenceMutationType.FOLLOW_SYSTEM && persisted.rollbackSnapshot.followSystem);
      hilog.error(DOMAIN, 'Theme', '偏好写入失败 version=%{public}d reason=%{public}s rollback=%{public}s',
        operationVersion, persisted.code, latest ? 'true' : 'false');
      return new PreferenceMutationResult(false, latest, latest, PreferenceFailureReason.PERSISTENCE_FAILED,
        operationVersion, persisted.rollbackSnapshot, persisted.rollbackSnapshot);
    }
    const latest = operationVersion === this.operationVersion;
    this.completeFollowSystemMutation(mutation, operationVersion);
    if (latest) this.publishPreferenceSnapshot(persisted.snapshot,
      mutation.type === PreferenceMutationType.FOLLOW_SYSTEM && persisted.snapshot.followSystem);
    if (mutation.type === PreferenceMutationType.BACKGROUND && rollback.backgroundUri.length > 0 &&
      rollback.backgroundUri !== persisted.snapshot.backgroundUri) {
      BackgroundImporter.removeSandboxFile(rollback.backgroundUri);
    }
    return new PreferenceMutationResult(true, false, latest, null, operationVersion,
      persisted.snapshot, persisted.rollbackSnapshot);
  }

  private buildCandidate(base: PreferenceSnapshot, mutation: PreferenceMutation,
    operationVersion: number): PreferenceSnapshot | null {
    const candidate = new PreferenceSnapshot(base.followSystem, base.manualThemeMode, base.colorThemeId,
      base.fontSizeScale, base.backgroundUri, base.backgroundStrength, base.glassEffectEnabled, operationVersion);
    if (mutation.type === PreferenceMutationType.FOLLOW_SYSTEM) {
      candidate.followSystem = mutation.booleanValue;
      if (!mutation.booleanValue) candidate.manualThemeMode = this.effectiveMode;
    }
    else if (mutation.type === PreferenceMutationType.MANUAL_MODE) candidate.manualThemeMode = mutation.stringValue;
    else if (mutation.type === PreferenceMutationType.COLOR_THEME) candidate.colorThemeId = mutation.stringValue;
    else if (mutation.type === PreferenceMutationType.FONT_SIZE) candidate.fontSizeScale = mutation.stringValue;
    else if (mutation.type === PreferenceMutationType.BACKGROUND) candidate.backgroundUri = mutation.stringValue;
    else if (mutation.type === PreferenceMutationType.BACKGROUND_STRENGTH) candidate.backgroundStrength = mutation.numberValue;
    else if (mutation.type === PreferenceMutationType.GLASS_EFFECT) candidate.glassEffectEnabled = mutation.booleanValue;
    else return null;
    return candidate;
  }

  private publishPreferenceSnapshot(snapshot: PreferenceSnapshot, syncFollowingSystem: boolean = false): void {
    this.followSystem = snapshot.followSystem;
    this.manualMode = snapshot.manualThemeMode === ThemeMode.LIGHT ? ThemeMode.LIGHT : ThemeMode.DARK;
    if (!this.followSystem) {
      this.effectiveMode = this.manualMode;
    } else if (syncFollowingSystem) {
      this.effectiveMode = this.isSystemDark ? ThemeMode.DARK : ThemeMode.LIGHT;
    }
    this.currentColorTheme = this.isColorTheme(snapshot.colorThemeId) ?
      snapshot.colorThemeId as ColorThemeId : ColorThemeId.CYAN;
    this.fontSizeScale = snapshot.fontSizeScale;
    this.backgroundPreference = this.backgroundFromSnapshot(snapshot);
    this.glassEffectEnabled = snapshot.glassEffectEnabled;
    this.lastSuccessfulTheme = this.getThemeState();
    this.lastSuccessfulBackground = this.copyBackground(this.backgroundPreference);
    this.applyFontSize(this.fontSizeScale);
    this.applyTheme();
    AppStorage.setOrCreate('backgroundCandidateUri', '');
    AppStorage.setOrCreate('backgroundDisplayState', snapshot.backgroundUri.length > 0 ?
      BackgroundDisplayState.READY : BackgroundDisplayState.INVALID);
  }

  private createPreferenceSnapshot(operationVersion: number): PreferenceSnapshot {
    return new PreferenceSnapshot(this.followSystem, this.manualMode, this.currentColorTheme,
      this.fontSizeScale, this.backgroundPreference.globalUri, this.backgroundPreference.visibleStrength,
      this.glassEffectEnabled, operationVersion);
  }

  private completeFollowSystemMutation(mutation: PreferenceMutation, operationVersion: number): void {
    if (mutation.type === PreferenceMutationType.FOLLOW_SYSTEM &&
      this.pendingFollowSystemVersion === operationVersion) {
      this.pendingFollowSystemVersion = 0;
    }
  }

  private backgroundFromSnapshot(snapshot: PreferenceSnapshot): GlobalBackgroundPreference {
    return new GlobalBackgroundPreference(snapshot.backgroundUri, snapshot.backgroundStrength);
  }

  private isFontSizeScale(value: string): boolean {
    return value === 'xsmall' || value === 'small' || value === 'standard' ||
      value === 'large' || value === 'xlarge';
  }

  // 校验字体是否在应用支持列表中（全部为免费商用授权）
  private isSupportedFontFamily(value: string): boolean {
    return value === 'HarmonyOS Sans' || value === 'Inter' ||
      value === 'JetBrains Mono' || value === 'Fira Code' ||
      value === 'Lobster' || value === 'Pacifico' || value === 'Bebas Neue' ||
      value === 'Righteous' || value === 'Press Start 2P' ||
      value === 'Orbitron' || value === 'Dancing Script' || value === 'ZCOOL KuaiLe';
  }

  private isColorTheme(value: string): boolean {
    return value === ColorThemeId.CYAN || value === ColorThemeId.OCEAN || value === ColorThemeId.SUNSET ||
      value === ColorThemeId.AURORA || value === ColorThemeId.SAKURA || value === ColorThemeId.FOREST;
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

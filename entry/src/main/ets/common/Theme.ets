// 智子 - 响应式多主题系统（沉浸光感版）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataRepository } from '../service/DataRepository';

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

// ============================================================
// 背景图配置
// ============================================================
export interface BackgroundConfig {
  global: string;   // 全局默认背景图 URI，空字符串表示无
  pages: Record<string, string>;  // 分页面背景图 { 'Index': 'file://...', 'Servers': 'file://...' }
}

export function emptyBackgroundConfig(): BackgroundConfig {
  return { global: '', pages: {} };
}

// ============================================================
// ThemeManager 单例
// ============================================================
export class ThemeManager {
  private static instance: ThemeManager;
  private currentColorTheme: ColorThemeId = ColorThemeId.CYAN;
  private isSystemDark: boolean = true;
  private followSystem: boolean = true;
  private manualDarkMode: boolean = true;
  private backgroundConfig: BackgroundConfig = emptyBackgroundConfig();
  private context: Context | null = null;
  private initialized: boolean = false;

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

      // 加载深色模式偏好
      const followSys = await DataRepository.getSetting('followSystemDark', 'true');
      this.followSystem = followSys === 'true';

      const manualDark = await DataRepository.getSetting('manualDarkMode', 'true');
      this.manualDarkMode = manualDark === 'true';

      // 加载背景图配置
      const bgJson = await DataRepository.getSetting('backgroundConfig', '');
      if (bgJson) {
        try {
          this.backgroundConfig = JSON.parse(bgJson) as BackgroundConfig;
        } catch (e) {
          this.backgroundConfig = emptyBackgroundConfig();
        }
      }

      // 加载字号配置
      const fontSize = await DataRepository.getSetting('fontSizeScale', 'standard');
      this.applyFontSize(fontSize);

      this.initialized = true;
      hilog.info(DOMAIN, 'Theme', '主题管理器初始化完成: color=%{public}s dark=%{public}s followSys=%{public}s',
        this.currentColorTheme, this.getIsDark() ? 'true' : 'false', this.followSystem ? 'true' : 'false');

      // 首次写入 AppStorage
      this.applyTheme();
    } catch (e) {
      hilog.error(DOMAIN, 'Theme', '主题管理器初始化失败');
      this.initialized = true;
      this.applyTheme(); // 使用默认值
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
  async setFollowSystem(follow: boolean): Promise<void> {
    this.followSystem = follow;
    await DataRepository.setSetting('followSystemDark', follow ? 'true' : 'false');
    this.applyTheme();
  }

  // 设置手动深色/浅色模式（仅在 followSystem=false 时生效）
  async setManualDarkMode(isDark: boolean): Promise<void> {
    this.manualDarkMode = isDark;
    await DataRepository.setSetting('manualDarkMode', isDark ? 'true' : 'false');
    if (!this.followSystem) {
      this.applyTheme();
    }
  }

  // 获取当前是否为深色模式
  getIsDark(): boolean {
    if (this.followSystem) {
      return this.isSystemDark;
    }
    return this.manualDarkMode;
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
  }

  // ==================== 背景图管理 ====================

  getBackgroundConfig(): BackgroundConfig {
    return this.backgroundConfig;
  }

  // 获取指定页面的背景图（优先页面级，fallback 到全局）
  getPageBackground(pageKey: string): string {
    const pageBg = this.backgroundConfig.pages[pageKey];
    if (pageBg && pageBg.length > 0) {
      return pageBg;
    }
    return this.backgroundConfig.global;
  }

  // 设置全局背景
  async setGlobalBackground(uri: string): Promise<void> {
    this.backgroundConfig.global = uri;
    await this.saveBackgroundConfig();
  }

  // 设置页面背景
  async setPageBackground(pageKey: string, uri: string): Promise<void> {
    if (uri.length === 0) {
      const newPages: Record<string, string> = {};
      for (const k of Object.keys(this.backgroundConfig.pages)) {
        if (k !== pageKey) {
          newPages[k] = this.backgroundConfig.pages[k];
        }
      }
      this.backgroundConfig.pages = newPages;
    } else {
      this.backgroundConfig.pages[pageKey] = uri;
    }
    await this.saveBackgroundConfig();
  }

  // 清除所有背景
  async clearAllBackgrounds(): Promise<void> {
    this.backgroundConfig = emptyBackgroundConfig();
    await this.saveBackgroundConfig();
  }

  private async saveBackgroundConfig(): Promise<void> {
    const json = JSON.stringify(this.backgroundConfig);
    await DataRepository.setSetting('backgroundConfig', json);
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

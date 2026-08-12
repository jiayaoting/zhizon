import { UIAbility, AbilityConstant, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../service/DatabaseHelper';
import { CryptoHelper } from '../common/CryptoHelper';
import { ThemeManager, ThemePalette, PreferenceFailureReason } from '../common/Theme';
import { WindowEnvironmentProvider } from '../service/WindowEnvironmentProvider';
import { SecurityService } from '../service/SecurityService';

const DOMAIN = 0x9201;

export enum StartupState {
  INITIALIZING = 'INITIALIZING',
  READY = 'READY',
  FAILED = 'FAILED'
}

export default class EntryAbility extends UIAbility {
  private initialized: boolean = false;
  private mainWindow: window.Window | null = null;
  private windowEnvironmentProvider: WindowEnvironmentProvider = new WindowEnvironmentProvider();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'EntryAbility', '智子应用启动 onCreate');
  }

  onDestroy(): void {
    this.windowEnvironmentProvider.detach();
    this.mainWindow = null;
    hilog.info(DOMAIN, 'EntryAbility', '智子应用 onDestroy');
  }

  // 监听系统配置变化（深色模式切换）
  onConfigurationUpdate(newConfig: Configuration): void {
    const colorMode = newConfig.colorMode;
    if (colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK &&
      colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      hilog.warn(DOMAIN, 'EntryAbility', '系统主题不可读 reason=%{public}s fallback=%{public}s colorMode=%{public}d',
        PreferenceFailureReason.SYSTEM_MODE_UNAVAILABLE, 'true', colorMode);
      return;
    }
    const isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    hilog.info(DOMAIN, 'EntryAbility', '系统配置变更: colorMode=%{public}d isDark=%{public}s',
      colorMode, isDark ? 'true' : 'false');
    ThemeManager.getInstance().onSystemDarkModeChange(isDark);
    this.windowEnvironmentProvider.refresh();
    this.updateStatusBarColor();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.prepareWindowStage(windowStage);
  }

  private async prepareWindowStage(windowStage: window.WindowStage): Promise<void> {
    try {
      AppStorage.setOrCreate('startupState', StartupState.INITIALIZING);
      const mainWindow: window.Window = await windowStage.getMainWindow();
      this.mainWindow = mainWindow;
      this.windowEnvironmentProvider.attach(mainWindow);
      await mainWindow.setWindowLayoutFullScreen(true);
      const initialized: boolean = await this.initializeApplication();
      if (!initialized) return;
      windowStage.loadContent('pages/AppShell', (error) => {
        if (error.code) {
          AppStorage.setOrCreate('startupState', StartupState.FAILED);
          hilog.error(DOMAIN, 'EntryAbility',
            'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
            'startup-page-load', 'STARTUP', 'PAGE_LOAD_FAILED', 'degraded');
          return;
        }
        hilog.info(DOMAIN, 'EntryAbility', '首页加载成功');
        this.windowEnvironmentProvider.refresh();
        this.updateStatusBarColor();
      });
    } catch (error) {
      AppStorage.setOrCreate('startupState', StartupState.FAILED);
      hilog.error(DOMAIN, 'EntryAbility',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'window-stage-create', 'STARTUP', 'WINDOW_STAGE_CREATE_FAILED', 'degraded');
    }
  }

  private async initializeApplication(): Promise<boolean> {
    if (this.initialized) {
      AppStorage.setOrCreate('startupState', StartupState.READY);
      return true;
    }
    this.initialized = true;
    AppStorage.setOrCreate('startupState', StartupState.INITIALIZING);
    const sysColorMode: ConfigurationConstant.ColorMode | undefined = this.context.config.colorMode;
    let sysIsDark: boolean = true;
    if (sysColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      sysIsDark = false;
    } else if (sysColorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      hilog.warn(DOMAIN, 'EntryAbility', '系统主题不可读 reason=%{public}s fallback=%{public}s colorMode=%{public}d',
        PreferenceFailureReason.SYSTEM_MODE_UNAVAILABLE, 'true', sysColorMode);
    }
    try {
      await CryptoHelper.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', '凭据加密初始化成功');
      await DatabaseHelper.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', '数据库初始化成功');
      await ThemeManager.getInstance().init(this.context, sysIsDark);
      hilog.info(DOMAIN, 'EntryAbility', '主题系统初始化成功');
      AppStorage.setOrCreate('startupState', StartupState.READY);
      this.updateStatusBarColor();
      return true;
    } catch (error) {
      this.initialized = false;
      AppStorage.setOrCreate('startupState', StartupState.FAILED);
      hilog.error(DOMAIN, 'EntryAbility',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'application-initialize', 'STARTUP', 'INITIALIZATION_FAILED', 'degraded');
      return false;
    }
  }

  // 根据当前主题动态设置状态栏颜色
  private updateStatusBarColor(): void {
    try {
      const palette: ThemePalette = ThemeManager.getInstance().getPalette();
      const mainWindow = window.getLastWindow(this.context);
      mainWindow.then((win) => {
        win.setWindowSystemBarProperties({
          statusBarContentColor: palette.statusBarContentColor,
          navigationBarContentColor: palette.navBarContentColor
        }).catch(() => {});
      }).catch(() => {});
    } catch (e) {
      // 忽略窗口未就绪的情况
    }
  }

  onWindowStageDestroy(): void {
    this.windowEnvironmentProvider.detach();
    this.mainWindow = null;
    hilog.info(DOMAIN, 'EntryAbility', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'onForeground');
    SecurityService.checkAndLockOnForeground();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'onBackground');
    SecurityService.onBackground();
  }
}

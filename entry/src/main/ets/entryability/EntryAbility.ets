import { UIAbility, AbilityConstant, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../service/DatabaseHelper';
import { CryptoHelper } from '../common/CryptoHelper';
import { ThemeManager, ThemePalette, PreferenceFailureReason } from '../common/Theme';

const DOMAIN = 0x9201;

export default class EntryAbility extends UIAbility {
  private initialized: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'EntryAbility', '智子应用启动 onCreate');
  }

  onDestroy(): void {
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
    this.updateStatusBarColor();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 延迟初始化：此时 context 已完全就绪
    if (!this.initialized) {
      this.initialized = true;

      // 读取当前系统深色模式状态
      const sysColorMode = this.context.config.colorMode;
      let sysIsDark = true;
      if (sysColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        sysIsDark = false;
      } else if (sysColorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        hilog.warn(DOMAIN, 'EntryAbility', '系统主题不可读 reason=%{public}s fallback=%{public}s colorMode=%{public}d',
          PreferenceFailureReason.SYSTEM_MODE_UNAVAILABLE, 'true', sysColorMode);
      }
      hilog.info(DOMAIN, 'EntryAbility', '系统深色模式: %{public}d isDark=%{public}s',
        sysColorMode, sysIsDark ? 'true' : 'false');

      CryptoHelper.init(this.context).then(() => {
        hilog.info(DOMAIN, 'EntryAbility', '凭据加密初始化成功');
        return DatabaseHelper.init(this.context);
      }).then(() => {
        hilog.info(DOMAIN, 'EntryAbility', '数据库初始化成功');
        // 初始化主题管理器，传入系统深色模式状态
        return ThemeManager.getInstance().init(this.context, sysIsDark);
      }).then(() => {
        hilog.info(DOMAIN, 'EntryAbility', '主题系统初始化成功');
        this.updateStatusBarColor();
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'EntryAbility', '初始化失败: %{public}s', err.message);
        this.initialized = false;
      });
    }

    windowStage.getMainWindow().then((win) => {
      win.setWindowLayoutFullScreen(true).catch(() => {});
      this.updateStatusBarColor();

      // 兜底最小安全区
      const SAFE_TOP_MIN: number = 44;
      const SAFE_BOTTOM_MIN: number = 24;

      const refreshSafeArea = (): void => {
        try {
          const density: number = display.getDefaultDisplaySync().densityPixels;
          if (density <= 0) {
            return;
          }
          const sysArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          const cutoutArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
          const navArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          const topSys: number = sysArea.topRect.height / density;
          const topCutout: number = cutoutArea.topRect.height / density;
          const bottomSys: number = sysArea.bottomRect.height / density;
          const bottomNav: number = navArea.bottomRect.height / density;
          const statusBarHeight: number = Math.max(topSys, topCutout, SAFE_TOP_MIN);
          const navBarHeight: number = Math.max(bottomSys, bottomNav, SAFE_BOTTOM_MIN);
          AppStorage.setOrCreate('statusBarHeight', statusBarHeight);
          AppStorage.setOrCreate('navBarHeight', navBarHeight);
          hilog.info(DOMAIN, 'EntryAbility', '安全区已更新 top=%{public}f bottom=%{public}f',
            statusBarHeight, navBarHeight);
        } catch (e) {
          hilog.error(DOMAIN, 'EntryAbility', '读取系统安全区失败: %{public}s', JSON.stringify(e));
        }
      };

      try {
        refreshSafeArea();
        win.on('avoidAreaChange', () => {
          refreshSafeArea();
        });
      } catch (e) {
        hilog.error(DOMAIN, 'EntryAbility', '注册安全区监听失败: %{public}s', JSON.stringify(e));
      }

      windowStage.loadContent('pages/AppShell', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'EntryAbility', '加载首页失败: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'EntryAbility', '首页加载成功');
        refreshSafeArea();
        this.updateStatusBarColor();
      });
    });
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
    hilog.info(DOMAIN, 'EntryAbility', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'onBackground');
  }
}

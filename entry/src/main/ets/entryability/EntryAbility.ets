import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../service/DatabaseHelper';
import { CryptoHelper } from '../common/CryptoHelper';

const DOMAIN = 0x9201;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'EntryAbility', '智子应用启动 onCreate');
    // 串行初始化：先加密再数据库，确保后续任何数据操作时 CryptoHelper 已就绪
    CryptoHelper.init(this.context).then(() => {
      hilog.info(DOMAIN, 'EntryAbility', '凭据加密初始化成功');
      return DatabaseHelper.init(this.context);
    }).then(() => {
      hilog.info(DOMAIN, 'EntryAbility', '数据库初始化成功');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'EntryAbility', '初始化失败: %{public}s', err.message);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '智子应用 onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 设置深色沉浸式状态栏
    windowStage.getMainWindow().then((win) => {
      win.setWindowLayoutFullScreen(true).catch(() => {});
      win.setWindowSystemBarProperties({
        statusBarContentColor: '#E2E8F0',
        navigationBarContentColor: '#E2E8F0'
      }).catch(() => {});

      // 兜底最小安全区（vp），任何设备都不会被状态栏/挖孔/手势条压住
      const SAFE_TOP_MIN: number = 44;
      const SAFE_BOTTOM_MIN: number = 24;

      // 统一刷新安全区：合并 TYPE_SYSTEM + TYPE_CUTOUT + TYPE_NAVIGATION_INDICATOR，
      // 取各方向最大值写入 AppStorage，供 TopBar/NavSidebar/AppShell 等动态避让
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
        // 尽早读取一次，保证页面首帧有兜底值
        refreshSafeArea();
        // 避让区变化（旋转/刘海变更/导航方式切换）时重新读取全部区域
        win.on('avoidAreaChange', () => {
          refreshSafeArea();
        });
      } catch (e) {
        hilog.error(DOMAIN, 'EntryAbility', '注册安全区监听失败: %{public}s', JSON.stringify(e));
      }

      // 加载首页，加载完成后再刷新一次确保数据就绪
      windowStage.loadContent('pages/AppShell', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'EntryAbility', '加载首页失败: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'EntryAbility', '首页加载成功');
        refreshSafeArea();
      });
    });
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
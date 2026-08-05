import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../service/DatabaseHelper';

const DOMAIN = 0x9201;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'EntryAbility', '智子应用启动 onCreate');
    // 初始化数据库
    DatabaseHelper.init(this.context).then(() => {
      hilog.info(DOMAIN, 'EntryAbility', '数据库初始化成功');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'EntryAbility', '数据库初始化失败: %{public}s', err.message);
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
    });

    // 加载首页
    windowStage.loadContent('pages/AppShell', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', '加载首页失败: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', '首页加载成功');
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
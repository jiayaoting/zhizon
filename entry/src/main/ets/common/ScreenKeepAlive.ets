// 智子 - 屏幕常亮控制
// 游戏进行中（含 AI 托管）保持屏幕常亮，避免锁屏打断对局。
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN: number = 0x9202;
const TAG: string = 'ScreenKeepAlive';

export class ScreenKeepAlive {
  // 获取当前 UIAbility 上下文对应的主窗口并设置常亮
  static async enable(context: object): Promise<void> {
    try {
      const win: window.Window = await window.getLastWindow(context as common.BaseContext);
      win.setWindowKeepScreenOn(true);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'operation=%{public}s code=%{public}s',
        'enable-keep-screen-on', (error as Error).message);
    }
  }

  // 关闭常亮（页面离开对局时恢复系统默认熄屏行为）
  static async disable(context: object): Promise<void> {
    try {
      const win: window.Window = await window.getLastWindow(context as common.BaseContext);
      win.setWindowKeepScreenOn(false);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'operation=%{public}s code=%{public}s',
        'disable-keep-screen-on', (error as Error).message);
    }
  }
}
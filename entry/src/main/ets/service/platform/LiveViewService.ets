// 智子 - 实况窗服务（Live View Kit：胶囊/灵动岛展示 AI 生成与托管进度）
// 不支持的设备/系统上所有操作自动降级为 no-op，绝不影响业务主流程
import { liveViewManager } from '@kit.LiveViewKit';

export class LiveViewService {
  private static liveViewId: number = 1;
  private static active: boolean = false;
  private static supported: boolean | null = null;

  // 当前场景是否支持实况窗（结果缓存；异常按不支持处理）
  static async isSupported(): Promise<boolean> {
    if (LiveViewService.supported !== null) return LiveViewService.supported;
    try {
      const enabled: boolean = await liveViewManager.isLiveViewEnabled();
      LiveViewService.supported = enabled;
      return enabled;
    } catch (e) {
      LiveViewService.supported = false;
      return false;
    }
  }

  // 发布一条实况窗（title + 进度百分比 0-100；不支持的设备直接忽略）
  static async publish(event: string, title: string, progress: number): Promise<void> {
    const supported: boolean = await LiveViewService.isSupported();
    if (!supported) return;
    try {
      const liveView: liveViewManager.LiveView = {
        id: LiveViewService.liveViewId,
        event: event,
        liveViewData: {
          primary: {
            title: title,
            content: [{
              text: LiveViewService.progressText(progress)
            }],
            layoutData: {
              layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
              progress: LiveViewService.clampProgress(progress)
            }
          }
        }
      };
      const result: liveViewManager.LiveViewResult = await liveViewManager.startLiveView(liveView);
      if (result.resultCode === 0) {
        LiveViewService.active = true;
      }
    } catch (e) {
      LiveViewService.active = false;
    }
  }

  // 更新已发布的实况窗
  static async update(event: string, title: string, progress: number): Promise<void> {
    if (!LiveViewService.active) return;
    try {
      const liveView: liveViewManager.LiveView = {
        id: LiveViewService.liveViewId,
        event: event,
        liveViewData: {
          primary: {
            title: title,
            content: [{
              text: LiveViewService.progressText(progress)
            }],
            layoutData: {
              layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
              progress: LiveViewService.clampProgress(progress)
            }
          }
        }
      };
      await liveViewManager.updateLiveView(liveView);
    } catch (e) {
      LiveViewService.active = false;
    }
  }

  // 关闭实况窗
  static async close(event: string): Promise<void> {
    if (!LiveViewService.active) return;
    try {
      const liveView: liveViewManager.LiveView = {
        id: LiveViewService.liveViewId,
        event: event,
        liveViewData: {
          primary: {
            title: '智子',
            content: [{ text: '已结束' }]
          }
        }
      };
      await liveViewManager.stopLiveView(liveView);
    } catch (e) {
    }
    LiveViewService.active = false;
  }

  // 下一事件场景名（避免与历史场景冲突）
  static nextEvent(prefix: string): string {
    LiveViewService.liveViewId += 1;
    return prefix + '-' + Date.now().toString();
  }

  private static clampProgress(value: number): number {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return Math.round(value);
  }

  private static progressText(progress: number): string {
    const p: number = LiveViewService.clampProgress(progress);
    if (p <= 0) return '进行中…';
    if (p >= 100) return '已完成';
    return p.toString() + '%';
  }
}

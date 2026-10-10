// 智子 - 宿主页面刷新总线
// 背景：嵌入 AppShell 的 Tab 组件（如 IndexPage）拿不到 onPageShow，
// 由 AppShell.onPageShow 广播，订阅方自行刷新（从详情页返回等场景）。
export class PageRefreshBus {
  private static hotShowListeners: (() => void)[] = [];

  static onHotShow(fn: () => void): void {
    PageRefreshBus.hotShowListeners.push(fn);
  }

  static offHotShow(fn: () => void): void {
    const idx: number = PageRefreshBus.hotShowListeners.indexOf(fn);
    if (idx >= 0) PageRefreshBus.hotShowListeners.splice(idx, 1);
  }

  // 热榜 Tab 重新可见
  static emitHotShow(): void {
    for (let i: number = 0; i < PageRefreshBus.hotShowListeners.length; i++) {
      PageRefreshBus.hotShowListeners[i]();
    }
  }
}

// 智子 - 宿主页面刷新总线
// 背景：嵌入 AppShell 的 Tab 组件（如 IndexPage / BettaFishPage）拿不到 onPageShow，
// 由 AppShell.onPageShow 广播，订阅方自行刷新（从子页返回等场景）。
// v10：V2 组件无法使用 @StorageLink + @Watch，故统一改用本总线（替代 AppStorage 刷新令牌）。
export class PageRefreshBus {
  private static hotShowListeners: (() => void)[] = [];
  private static bettaShowListeners: (() => void)[] = [];
  private static chatShowListeners: (() => void)[] = [];

  // ==================== 热榜 Tab ====================
  static onHotShow(fn: () => void): void {
    PageRefreshBus.hotShowListeners.push(fn);
  }

  static offHotShow(fn: () => void): void {
    const idx: number = PageRefreshBus.hotShowListeners.indexOf(fn);
    if (idx >= 0) PageRefreshBus.hotShowListeners.splice(idx, 1);
  }

  static emitHotShow(): void {
    for (let i: number = 0; i < PageRefreshBus.hotShowListeners.length; i++) {
      PageRefreshBus.hotShowListeners[i]();
    }
  }

  // ==================== 微舆 Tab ====================
  static onBettaShow(fn: () => void): void {
    PageRefreshBus.bettaShowListeners.push(fn);
  }

  static offBettaShow(fn: () => void): void {
    const idx: number = PageRefreshBus.bettaShowListeners.indexOf(fn);
    if (idx >= 0) PageRefreshBus.bettaShowListeners.splice(idx, 1);
  }

  static emitBettaShow(): void {
    for (let i: number = 0; i < PageRefreshBus.bettaShowListeners.length; i++) {
      PageRefreshBus.bettaShowListeners[i]();
    }
  }

  // ==================== AI 对话 Tab ====================
  static onChatShow(fn: () => void): void {
    PageRefreshBus.chatShowListeners.push(fn);
  }

  static offChatShow(fn: () => void): void {
    const idx: number = PageRefreshBus.chatShowListeners.indexOf(fn);
    if (idx >= 0) PageRefreshBus.chatShowListeners.splice(idx, 1);
  }

  static emitChatShow(): void {
    for (let i: number = 0; i < PageRefreshBus.chatShowListeners.length; i++) {
      PageRefreshBus.chatShowListeners[i]();
    }
  }
}

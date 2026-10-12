// 智子 - 热榜数据源接缝（v10 §5.3 可注入单例）
// 目的：把「网络取数」从 HotFeedStore 中解耦，单测可注入 Fake 实现，
//      不依赖网络与服务端；生产路径默认使用 NewsNowClient（行为完全不变）。
import { HotNowError, FocusMetadata } from '../../common/HotModels';
import { NewsNowClient, HotBoardResult, HotBoardsResult, HotPingResult, HotMetaResult } from './NewsNowClient';

// 热榜数据源契约
export interface IHotDataProvider {
  ping(): Promise<HotPingResult>;
  fetchBoard(sourceId: string, latest: boolean): Promise<HotBoardResult>;
  fetchBoards(sourceIds: string[]): Promise<HotBoardsResult>;
  pullMetadata(): Promise<HotMetaResult>;
  pushMetadata(meta: FocusMetadata): Promise<HotNowError | null>;
}

// 默认实现：委托给 NewsNowClient（静态方法，行为零变化）
export class NewsNowHotDataProvider implements IHotDataProvider {
  ping(): Promise<HotPingResult> {
    return NewsNowClient.ping();
  }

  fetchBoard(sourceId: string, latest: boolean): Promise<HotBoardResult> {
    return NewsNowClient.fetchBoard(sourceId, latest);
  }

  fetchBoards(sourceIds: string[]): Promise<HotBoardsResult> {
    return NewsNowClient.fetchBoards(sourceIds);
  }

  pullMetadata(): Promise<HotMetaResult> {
    return NewsNowClient.pullMetadata();
  }

  pushMetadata(meta: FocusMetadata): Promise<HotNowError | null> {
    return NewsNowClient.pushMetadata(meta);
  }
}

// 注册表：默认返回真实实现；测试可 inject(Fake) / reset()
export class HotDataProviders {
  private static override: IHotDataProvider | null = null;
  private static fallback: IHotDataProvider = new NewsNowHotDataProvider();

  static inject(provider: IHotDataProvider): void {
    HotDataProviders.override = provider;
  }

  static reset(): void {
    HotDataProviders.override = null;
  }

  static get(): IHotDataProvider {
    return HotDataProviders.override === null ? HotDataProviders.fallback : HotDataProviders.override;
  }

  // 是否处于测试注入态（供断言）
  static isInjected(): boolean {
    return HotDataProviders.override !== null;
  }
}

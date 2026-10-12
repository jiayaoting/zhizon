import { describe, it, expect } from '@ohos/hypium';
import { IHotDataProvider, HotDataProviders } from '../main/ets/service/hot/HotDataProvider';
import { HotBoardResult, HotBoardsResult, HotPingResult, HotMetaResult } from '../main/ets/service/hot/NewsNowClient';
import { HotBoardData, HotItem, HotNowError, FocusMetadata } from '../main/ets/common/HotModels';

// 假数据源：验证「可注入单例」接缝（无需网络/服务端）
class FakeHotDataProvider implements IHotDataProvider {
  fetchCount: number = 0;
  failNext: boolean = false;

  ping(): Promise<HotPingResult> {
    return Promise.resolve(new HotPingResult(true, 'fake-1.0', null));
  }

  fetchBoard(sourceId: string, latest: boolean): Promise<HotBoardResult> {
    this.fetchCount++;
    if (this.failNext) {
      return Promise.resolve(HotBoardResult.failure(sourceId, new HotNowError('network', 0, 'fake failure')));
    }
    const item: HotItem = new HotItem('1', '假条目', 'https://example.com/1', 'https://example.com/1', 0, '热度 1万');
    const data: HotBoardData = new HotBoardData(sourceId, false, 1700000000000, [item]);
    return Promise.resolve(HotBoardResult.success(sourceId, data));
  }

  fetchBoards(sourceIds: string[]): Promise<HotBoardsResult> {
    const tasks: Promise<HotBoardResult>[] = [];
    for (let i: number = 0; i < sourceIds.length; i++) {
      tasks.push(this.fetchBoard(sourceIds[i], false));
    }
    return Promise.all(tasks).then((boards: HotBoardResult[]) => new HotBoardsResult(true, boards, null));
  }

  pullMetadata(): Promise<HotMetaResult> {
    return Promise.resolve(new HotMetaResult(true,
      new FocusMetadata(['weibo', 'zhihu'], 1700000000000), null));
  }

  pushMetadata(meta: FocusMetadata): Promise<HotNowError | null> {
    return Promise.resolve(null);
  }
}

export default function HotDataProviderTest() {
  describe('HotDataProviderTest', () => {
    it('defaults to the real NewsNow-backed provider', 0, () => {
      HotDataProviders.reset();
      expect(HotDataProviders.isInjected()).assertFalse();
      expect(HotDataProviders.get() !== null).assertTrue();
    });

    it('inject/reset swaps the singleton used by callers', 0, () => {
      const fake: FakeHotDataProvider = new FakeHotDataProvider();
      HotDataProviders.inject(fake);
      expect(HotDataProviders.isInjected()).assertTrue();
      expect(HotDataProviders.get() === fake).assertTrue();
      HotDataProviders.reset();
      expect(HotDataProviders.isInjected()).assertFalse();
      expect(HotDataProviders.get() === fake).assertFalse();
    });

    it('fake provider satisfies the contract (board + meta)', 0, async () => {
      const fake: FakeHotDataProvider = new FakeHotDataProvider();
      HotDataProviders.inject(fake);
      const res: HotBoardsResult = await HotDataProviders.get().fetchBoards(['weibo', 'zhihu']);
      expect(res.ok).assertTrue();
      expect(res.boards.length).assertEqual(2);
      expect(res.boards[0].data !== null).assertTrue();
      const meta: HotMetaResult = await HotDataProviders.get().pullMetadata();
      expect(meta.ok).assertTrue();
      expect(meta.meta !== null).assertTrue();
      HotDataProviders.reset();
    });

    it('fake provider can simulate a single-source failure', 0, async () => {
      const fake: FakeHotDataProvider = new FakeHotDataProvider();
      fake.failNext = true;
      HotDataProviders.inject(fake);
      const r: HotBoardResult = await HotDataProviders.get().fetchBoard('weibo', true);
      expect(r.ok).assertFalse();
      expect(r.error !== null).assertTrue();
      HotDataProviders.reset();
    });
  });
}

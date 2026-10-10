import { describe, it, expect } from '@ohos/hypium';
import { HotSources } from '../main/ets/common/HotSources';
import { HotViewKey, FocusMetadata, HotItem, HotEntry } from '../main/ets/common/HotModels';
import { hotRelativeTime, hotClockTime } from '../main/ets/common/HotFormat';

export default function HotModuleTest() {
  describe('HotModuleTest', () => {
    it('source catalog exposes known NewsNow ids', 0, () => {
      expect(HotSources.byId('weibo') !== null).assertTrue();
      expect(HotSources.byId('zhihu') !== null).assertTrue();
      expect(HotSources.byId('cls') !== null).assertTrue();
      expect(HotSources.byId('not-a-real-source') === null).assertTrue();
    });

    it('displayName joins site and sub title', 0, () => {
      expect(HotSources.nameOf('weibo')).assertEqual('微博·实时热搜');
      expect(HotSources.nameOf('zhihu')).assertEqual('知乎');
    });

    it('unknown source falls back to its id and default color', 0, () => {
      expect(HotSources.nameOf('unknown-src')).assertEqual('unknown-src');
      expect(HotSources.colorOf('unknown-src')).assertEqual('#6B7280');
    });

    it('hottest/realtime views exclude disabled sources', 0, () => {
      const hottest: string[] = HotSources.hottestIds();
      const realtime: string[] = HotSources.realtimeIds();
      expect(hottest.length > 0).assertTrue();
      expect(realtime.length > 0).assertTrue();
      // bilibili 系列在 NewsNow 标记为 disable: cf，默认视图不展示
      expect(hottest.indexOf('bilibili')).assertEqual(-1);
      expect(hottest.indexOf('weibo') >= 0).assertTrue();
      expect(realtime.indexOf('cls') >= 0).assertTrue();
    });

    it('focus view keeps only ids present in the catalog, in user order', 0, () => {
      const ids: string[] = HotSources.sourceIdsForView(HotViewKey.Focus, ['cls', 'ghost', 'weibo']);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual('cls');
      expect(ids[1]).assertEqual('weibo');
    });

    it('focus metadata has empty defaults', 0, () => {
      const meta: FocusMetadata = new FocusMetadata([], 0);
      expect(meta.focusSources.length).assertEqual(0);
      expect(meta.updatedTime).assertEqual(0);
    });

    it('hotRelativeTime handles empty and recent timestamps', 0, () => {
      expect(hotRelativeTime(0)).assertEqual('');
      expect(hotRelativeTime(Date.now())).assertEqual('刚刚');
      expect(hotRelativeTime(Date.now() - 5 * 60 * 1000)).assertEqual('5 分钟前');
    });

    it('hotClockTime returns empty for zero timestamp', 0, () => {
      expect(hotClockTime(0)).assertEqual('');
      expect(hotClockTime(Date.now()).length).assertEqual(5);
    });

    it('HotEntry key convention is sourceId:itemId', 0, () => {
      const item: HotItem = new HotItem('123', '标题', 'https://x.com/1', 'https://x.com/1', 0, '热度 10万');
      const entry: HotEntry = new HotEntry('weibo:123', item, 'weibo', '微博·实时热搜');
      expect(entry.key).assertEqual('weibo:123');
      expect(entry.item.info).assertEqual('热度 10万');
    });
  });
}

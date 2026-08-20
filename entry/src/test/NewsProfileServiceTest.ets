import { describe, it, expect } from '@ohos/hypium';
import { NewsProfileService, NewsProfileSnapshot, emptyProfile } from '../main/ets/service/NewsProfileService';
import { NewsItem } from '../main/ets/common/NewsModels';

export default function NewsProfileServiceTest() {
  describe('NewsProfileServiceTest', () => {
    it('applyDelta adds like weights to posTags', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      const item: NewsItem = new NewsItem('n1', 'T', '', 'https://x.com/1', '', 'hn', 'Hacker News', 'tech', Date.now());
      NewsProfileService.applyDelta(p, item, 1, 1, ['AI', '芯片']);
      expect(p.posTags['AI']).assertEqual(1);
      expect(p.posTags['芯片']).assertEqual(1);
      expect(p.categoryWeights['tech']).assertGreaterThan(0);
      expect(p.sourceWeights['hn']).assertGreaterThan(0);
    });

    it('applyDelta adds dislike weights to negTags', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      const item: NewsItem = new NewsItem('n2', 'T', '', 'https://x.com/2', '', 'hn', 'Hacker News', 'world', Date.now());
      NewsProfileService.applyDelta(p, item, -1, 1, ['娱乐']);
      expect(p.negTags['娱乐']).assertEqual(1);
      expect(p.posTags['娱乐']).assertEqual(0);
    });

    it('revert like decrements weight and never goes negative', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      const item: NewsItem = new NewsItem('n3', 'T', '', 'https://x.com/3', '', 'hn', 'Hacker News', 'tech', Date.now());
      NewsProfileService.applyDelta(p, item, 1, 1, ['AI']);
      NewsProfileService.applyDelta(p, item, 1, -1, ['AI']);
      expect(p.posTags['AI']).assertEqual(0);
      NewsProfileService.applyDelta(p, item, 1, -1, ['AI']);
      expect(p.posTags['AI']).assertEqual(0);
    });

    it('decayWeights applies half-life factor', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      p.posTags['AI'] = 1;
      p.updatedAt = Date.now() - 7 * 24 * 3600 * 1000;
      NewsProfileService.decayWeights(p, Date.now());
      expect(p.posTags['AI']).assertLessThan(1);
      expect(p.posTags['AI']).assertGreaterThan(0.8);
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { NewsRanker, RankParams } from '../main/ets/service/NewsRanker';
import { NewsProfileSnapshot, emptyProfile } from '../main/ets/service/NewsProfileService';
import { NewsItem } from '../main/ets/common/NewsModels';

export default function NewsRankerTest() {
  describe('NewsRankerTest', () => {
    it('negative weight penalty grows sublinearly and is capped', 0, () => {
      const f1: number = NewsRanker.fNeg(1);
      const f3: number = NewsRanker.fNeg(3);
      const f8: number = NewsRanker.fNeg(8);
      const f20: number = NewsRanker.fNeg(20);
      expect(f1).assertLessThan(f3);
      expect(f3).assertLessThan(f8);
      expect(f8).assertEqual(f20);
    });

    it('liked tags rank above disliked tags', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      p.posTags['AI'] = 3;
      p.negTags['娱乐'] = 6;
      const liked: NewsItem = new NewsItem('a', 'AI 新闻', '', 'https://x.com/a', '', 'hn', 'Hacker News', 'tech', Date.now(), ['AI'], 'zh');
      const disliked: NewsItem = new NewsItem('b', '娱乐新闻', '', 'https://x.com/b', '', 'hn', 'Hacker News', 'world', Date.now(), ['娱乐'], 'zh');
      const now: number = Date.now();
      const sLiked: number = NewsRanker.score(liked, p, now);
      const sDisliked: number = NewsRanker.score(disliked, p, now);
      expect(sLiked).assertGreaterThan(sDisliked);
    });

    it('diversity caps same tag share per screen', 0, () => {
      const items: NewsItem[] = [];
      for (let i: number = 0; i < 5; i++) {
        items.push(new NewsItem('t' + i.toString(), 'T' + i.toString(), '', 'https://x.com/t' + i.toString(), '', 's1', 'S1', 'tech', Date.now(), ['AI'], 'zh'));
      }
      const out: NewsItem[] = NewsRanker.applyDiversity(items, 5);
      expect(out.length).assertEqual(2);
    });

    it('diversity limits consecutive same source', 0, () => {
      const items: NewsItem[] = [];
      for (let i: number = 0; i < 4; i++) {
        items.push(new NewsItem('s' + i.toString(), 'T' + i.toString(), '', 'https://x.com/s' + i.toString(), '', 'src', 'SRC', 'tech', Date.now(), [], 'zh'));
      }
      const out: NewsItem[] = NewsRanker.applyDiversity(items, 4);
      expect(out.length).assertEqual(3);
    });

    it('aggressive mode strengthens feedback weights', 0, () => {
      const std: RankParams = NewsRanker.paramsForMode('standard');
      const agg: RankParams = NewsRanker.paramsForMode('aggressive');
      expect(agg.alpha).assertGreaterThan(std.alpha);
      expect(agg.beta).assertGreaterThan(std.beta);
      expect(agg.zeta).assertLessThan(std.zeta);
    });

    it('explore mode raises exploration and lowers penalties', 0, () => {
      const std: RankParams = NewsRanker.paramsForMode('standard');
      const exp: RankParams = NewsRanker.paramsForMode('explore');
      expect(exp.zeta).assertGreaterThan(std.zeta);
      expect(exp.eta).assertLessThan(std.eta);
    });

    it('excluded url gets soft penalty but score stays finite', 0, () => {
      const p: NewsProfileSnapshot = emptyProfile();
      p.posTags['AI'] = 2;
      const item: NewsItem = new NewsItem('x', 'T', '', 'https://x.com/x', '', 's1', 'S1', 'tech', Date.now(), ['AI'], 'zh');
      const now: number = Date.now();
      const params: RankParams = NewsRanker.paramsForMode('standard');
      const s1: number = NewsRanker.scoreWith(item, p, now, params, []);
      const s2: number = NewsRanker.scoreWith(item, p, now, params, [item.url]);
      expect(s1).assertGreaterThan(s2);
    });
  });
}

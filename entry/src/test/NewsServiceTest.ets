import { describe, it, expect } from '@ohos/hypium';
import { NewsService } from '../main/ets/service/NewsService';
import { NewsSourceDef } from '../main/ets/common/NewsModels';
import { NewsItem } from '../main/ets/common/NewsModels';

export default function NewsServiceTest() {
  describe('NewsServiceTest', () => {
    it('parses zhihu daily json', 0, () => {
      const fixture = '{"date":"20260819","stories":[{"id":1001,"title":"测试新闻一","hint":"测试作者","url":"https://daily.zhihu.com/story/1001","image":"https://picsum.photos/100"},{"id":1002,"title":"测试新闻二","hint":"","images":["https://picsum.photos/200"]}]}';
      const items: NewsItem[] = NewsService.parseZhihu(fixture);
      expect(items.length).assertEqual(2);
      expect(items[0].title).assertEqual('测试新闻一');
      expect(items[0].sourceId).assertEqual('zhihu');
      expect(items[0].id).assertEqual('zhihu:1001');
      expect(items[0].imageUrl).assertEqual('https://picsum.photos/100');
      expect(items[1].imageUrl).assertEqual('https://picsum.photos/200');
    });

    it('tolerates malformed zhihu json', 0, () => {
      const items: NewsItem[] = NewsService.parseZhihu('not json');
      expect(items.length).assertEqual(0);
      const empty: NewsItem[] = NewsService.parseZhihu('{"stories":[]}');
      expect(empty.length).assertEqual(0);
    });

    it('parses hacker news algolia json', 0, () => {
      const fixture = '{"hits":[{"objectID":"3000001","title":"A Great Post","url":"https://example.com/a","points":123,"num_comments":45,"author":"alice","created_at_i":1752900000},{"objectID":"3000002","title":"No Url Post","points":9,"num_comments":2,"author":"bob","created_at_i":1752900000}]}';
      const items: NewsItem[] = NewsService.parseHn(fixture);
      expect(items.length).assertEqual(2);
      expect(items[0].title).assertEqual('A Great Post');
      expect(items[0].summary.indexOf('123')).assertGreaterThan(-1);
      expect(items[0].sourceId).assertEqual('hn');
      // 无 url 时回退到 HN 讨论页
      expect(items[1].url).assertEqual('https://news.ycombinator.com/item?id=3000002');
    });

    it('parses rss 2.0 xml', 0, () => {
      const xml = '<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>示例源</title><item><title>RSS 标题</title><link>https://example.com/rss/1</link><description>&lt;p&gt;RSS 摘要&lt;/p&gt;</description><pubDate>Wed, 19 Aug 2026 08:00:00 GMT</pubDate></item></channel></rss>';
      const def: NewsSourceDef = new NewsSourceDef('test', '示例源', 'tech', 'rss', 'https://example.com/feed');
      const items: NewsItem[] = NewsService.parseRss(xml, def);
      expect(items.length).assertEqual(1);
      expect(items[0].title).assertEqual('RSS 标题');
      expect(items[0].url).assertEqual('https://example.com/rss/1');
      expect(items[0].summary.indexOf('RSS 摘要')).assertGreaterThan(-1);
      expect(items[0].sourceName).assertEqual('示例源');
    });

    it('parses atom xml', 0, () => {
      const xml = '<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>Atom 源</title><entry><title>Atom 标题</title><link href="https://example.com/atom/1" rel="alternate"/><summary>Atom 摘要</summary><updated>2026-08-19T08:00:00Z</updated></entry></feed>';
      const def: NewsSourceDef = new NewsSourceDef('atom', 'Atom源', 'world', 'rss', 'https://example.com/atom');
      const items: NewsItem[] = NewsService.parseRss(xml, def);
      expect(items.length).assertEqual(1);
      expect(items[0].title).assertEqual('Atom 标题');
      expect(items[0].url).assertEqual('https://example.com/atom/1');
    });

    it('parses opml subscriptions', 0, () => {
      const xml = '<?xml version="1.0" encoding="UTF-8"?><opml version="2.0"><body><outline text="科技组"><outline text="少数派" xmlUrl="https://sspai.com/feed"/><outline text="IT之家" xmlUrl="https://www.ithome.com/rss/"/></outline><outline text="无链接分组"><outline text="空源"/></outline></body></opml>';
      const sources: NewsSourceDef[] = NewsService.parseOpml(xml);
      expect(sources.length).assertEqual(2);
      expect(sources[0].name).assertEqual('少数派');
      expect(sources[0].url).assertEqual('https://sspai.com/feed');
      expect(sources[0].type).assertEqual('rss');
      expect(sources[1].name).assertEqual('IT之家');
    });

    it('tolerates malformed opml', 0, () => {
      const sources: NewsSourceDef[] = NewsService.parseOpml('not xml');
      expect(sources.length).assertEqual(0);
      const empty: NewsSourceDef[] = NewsService.parseOpml('');
      expect(empty.length).assertEqual(0);
    });

    it('merges and dedupes by url', 0, () => {
      const a: NewsItem = new NewsItem('a1', 'A', '', 'https://x.com/a', '', 's1', 'S1', 'tech', 1000);
      const aDup: NewsItem = new NewsItem('a2', 'A 重复', '', 'https://x.com/a', '', 's2', 'S2', 'tech', 2000);
      const b: NewsItem = new NewsItem('b1', 'B', '', 'https://x.com/b', '', 's1', 'S1', 'tech', 500);
      const merged: NewsItem[] = NewsService.merge([[a, aDup], [b]], 10);
      expect(merged.length).assertEqual(2);
      expect(merged[0].title).assertEqual('A 重复');
    });

    it('enrich adds L1 tags for zh news', 0, () => {
      const zh: NewsItem = new NewsItem('t1', 'OpenAI 发布新大模型，芯片算力提升', '摘要', 'https://x.com/t1', '', 'custom', '自定义', 'tech', Date.now());
      const out: NewsItem[] = NewsService.enrich([zh]);
      expect(out.length).assertEqual(1);
      expect(out[0].tags.length).assertGreaterThan(0);
      expect(out[0].tags.indexOf('AI')).assertGreaterThan(-1);
      expect(out[0].tags.indexOf('科技')).assertGreaterThan(-1);
      expect(out[0].language).assertEqual('zh');
    });

    it('enrich detects foreign language by preset source', 0, () => {
      const en: NewsItem = new NewsItem('t2', 'Breaking: stock market rallies', 'Summary', 'https://x.com/t2', '', 'hn', 'Hacker News', 'finance', Date.now());
      const out: NewsItem[] = NewsService.enrich([en]);
      expect(out[0].language).assertEqual('en');
      // 频道标签仍会打上
      expect(out[0].tags.indexOf('财经')).assertGreaterThan(-1);
    });

    it('enrich keeps existing tags unchanged', 0, () => {
      const tagged: NewsItem = new NewsItem('t3', 'OpenAI 发布新大模型', '', 'https://x.com/t3', '', 'custom', '自定义', 'tech', Date.now(), ['AI'], 'zh');
      const out: NewsItem[] = NewsService.enrich([tagged]);
      expect(out[0].tags.length).assertEqual(1);
      expect(out[0].tags[0]).assertEqual('AI');
    });
  });
}

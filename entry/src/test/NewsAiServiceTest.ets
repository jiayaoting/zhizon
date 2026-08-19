import { describe, it, expect } from '@ohos/hypium';
import { NewsAiService } from '../main/ets/service/NewsAiService';
import { NewsItem } from '../main/ets/common/NewsModels';

export default function NewsAiServiceTest() {
  describe('NewsAiServiceTest', () => {
    it('truncates long text', 0, () => {
      const long: string = 'x'.repeat(20000);
      const cut: string = NewsAiService.truncate(long, 1000);
      expect(cut.length).assertLessThan(1200);
      expect(cut.indexOf('已截断')).assertGreaterThan(-1);
    });

    it('keeps short text unchanged', 0, () => {
      const short: string = '短文本';
      expect(NewsAiService.truncate(short, 1000)).assertEqual(short);
    });

    it('builds article context with title summary and body', 0, () => {
      const item: NewsItem = new NewsItem('t1', '标题', '摘要', 'https://x.com', '', 's1', 'S1', 'tech', 0);
      const ctx: string = NewsAiService.articleContext(item, '正文内容');
      expect(ctx.indexOf('标题')).assertGreaterThan(-1);
      expect(ctx.indexOf('摘要')).assertGreaterThan(-1);
      expect(ctx.indexOf('正文内容')).assertGreaterThan(-1);
    });

    it('builds context without body when empty', 0, () => {
      const item: NewsItem = new NewsItem('t2', '标题', '', 'https://x.com', '', 's1', 'S1', 'tech', 0);
      const ctx: string = NewsAiService.articleContext(item, '');
      expect(ctx.indexOf('文章正文')).assertEqual(-1);
    });
  });
}

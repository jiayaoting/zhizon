// 智子 - 联网搜索服务（可配置 JSON 搜索接口，默认 DuckDuckGo Instant Answer）
import { http } from '@kit.NetworkKit';

// 单条搜索结果
export class WebSearchResult {
  title: string;
  url: string;
  snippet: string;

  constructor(title: string, url: string, snippet: string) {
    this.title = title;
    this.url = url;
    this.snippet = snippet;
  }
}

export class WebSearchService {
  // 搜索：baseUrl 中 {q} 会被替换为查询词；apiKey 非空时追加 api_key 参数
  // 兼容 DuckDuckGo Instant Answer 与 SerpAPI 风格 JSON；失败或超时返回空数组
  static async search(query: string, baseUrl: string, apiKey: string = ''): Promise<WebSearchResult[]> {
    const q: string = query.trim();
    if (q.length === 0) return [];
    let url: string = baseUrl.trim();
    if (url.length === 0) return [];
    url = url.replace('{q}', encodeURIComponent(q));
    if (apiKey.trim().length > 0) {
      url = url + (url.indexOf('?') >= 0 ? '&' : '?') + 'api_key=' + encodeURIComponent(apiKey.trim());
    }
    try {
      const request: http.HttpRequest = http.createHttp();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 8000,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING
      });
      request.destroy();
      if (response.responseCode !== 200) return [];
      const text: string = response.result as string;
      return WebSearchService.parse(text);
    } catch (e) {
      return [];
    }
  }

  // 解析搜索 JSON：兼容多种结构
  private static parse(jsonText: string): WebSearchResult[] {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const results: WebSearchResult[] = [];
      // 1) DuckDuckGo Instant Answer：RelatedTopics 数组（条目可能含嵌套 Topics）
      const related: Object = parsed['RelatedTopics'];
      if (related !== undefined && Array.isArray(related)) {
        const items: Object[] = related as Object[];
        for (let i: number = 0; i < items.length; i++) {
          const item: Record<string, Object> = items[i] as Record<string, Object>;
          if (item['Topics'] !== undefined && Array.isArray(item['Topics'])) {
            const nested: Object[] = item['Topics'] as Object[];
            for (let j: number = 0; j < nested.length; j++) {
              const n: Record<string, Object> = nested[j] as Record<string, Object>;
              WebSearchService.pushResult(results, n['Text'], n['FirstURL'], '');
            }
          } else {
            WebSearchService.pushResult(results, item['Text'], item['FirstURL'], '');
          }
        }
      }
      // 2) SerpAPI 风格：organic_results 数组
      const organic: Object = parsed['organic_results'];
      if (organic !== undefined && Array.isArray(organic)) {
        const items: Object[] = organic as Object[];
        for (let i: number = 0; i < items.length; i++) {
          const item: Record<string, Object> = items[i] as Record<string, Object>;
          WebSearchService.pushResult(results, item['title'], item['link'], item['snippet']);
        }
      }
      // 3) 兜底：answer 摘要
      if (results.length === 0) {
        const answer: Object = parsed['AbstractText'];
        if (answer !== undefined && typeof answer === 'string' && (answer as string).length > 0) {
          const url: Object = parsed['AbstractURL'];
          results.push(new WebSearchResult('摘要', typeof url === 'string' ? url as string : '',
            answer as string));
        }
      }
      return results.length > 4 ? results.slice(0, 4) : results;
    } catch (e) {
      return [];
    }
  }

  private static pushResult(results: WebSearchResult[], title: Object, url: Object,
    snippet: Object): void {
    const t: string = typeof title === 'string' ? title as string : '';
    if (t.trim().length === 0) return;
    const u: string = typeof url === 'string' ? url as string : '';
    const s: string = typeof snippet === 'string' ? snippet as string : '';
    results.push(new WebSearchResult(t, u, s));
  }

  // 将搜索结果拼进用户消息上下文
  static buildContext(original: string, results: WebSearchResult[]): string {
    if (results.length === 0) return original;
    let block: string = '【联网搜索结果】\n';
    for (let i: number = 0; i < results.length; i++) {
      const r: WebSearchResult = results[i];
      block = block + (i + 1).toString() + '. ' + r.title +
        (r.snippet.trim().length > 0 ? '：' + r.snippet.trim() : '') +
        (r.url.trim().length > 0 ? '（' + r.url.trim() + '）' : '') + '\n';
    }
    block = block + '请优先基于以上搜索结果回答，并简要说明信息来源。\n\n用户问题：' + original;
    return block;
  }
}

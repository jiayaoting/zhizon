// 智子 - 新闻数据服务（多源拉取 / 归一化 / 合并 / 内存缓存 / RSS 解析）
import { http } from '@kit.NetworkKit';
import { convertxml } from '@kit.ArkTS';
import { NewsItem, NewsSourceDef } from '../common/NewsModels';
import { NEWS_SOURCES, AI_KEYWORDS } from '../common/NewsChannels';
import { DatabaseHelper } from './DatabaseHelper';
import { NewsRepository } from './NewsRepository';

// convertxml 选项结构（SDK 的 ConvertOptions 为 type 别名，字面量需先落到本地 interface）
interface XmlConvertOptions {
  trim: boolean;
  declarationKey: string;
  instructionKey: string;
  attributesKey: string;
  textKey: string;
  cdataKey: string;
  doctypeKey: string;
  commentKey: string;
  parentKey: string;
  typeKey: string;
  nameKey: string;
  elementsKey: string;
}

// 内存缓存有效期：10 分钟
const CACHE_TTL_MS: number = 10 * 60 * 1000;
// 单请求超时（毫秒）
const REQUEST_TIMEOUT: number = 8000;

interface FeedCacheEntry {
  items: NewsItem[];
  fetchedAt: number;
}

export class NewsService {
  private static cache: Map<string, FeedCacheEntry> = new Map<string, FeedCacheEntry>();
  private static inFlight: Map<string, Promise<NewsItem[]>> = new Map<string, Promise<NewsItem[]>>();

  // ==================== 对外接口 ====================

  // 拉取某个频道：并发抓取该频道下所有源 → 合并去重排序
  // recommend = 全部启用源 + 自定义 RSS；ai = 关键词派生频道；其余按源 category 过滤
  // 全部源失败时回退到本地快照缓存（离线阅读），成功后更新快照
  static async fetchChannel(channelId: string, limit: number = 50, force: boolean = false): Promise<NewsItem[]> {
    const enabled: string[] = await NewsService.enabledSourceIds();
    const active: NewsSourceDef[] = [];
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      if (enabled.length === 0 || enabled.indexOf(NEWS_SOURCES[i].id) >= 0) {
        active.push(NEWS_SOURCES[i]);
      }
    }
    // 自定义 RSS 订阅始终参与
    const custom: NewsSourceDef[] = await NewsService.customSources();
    for (let i: number = 0; i < custom.length; i++) {
      active.push(custom[i]);
    }

    let result: NewsItem[] = [];
    if (channelId === 'recommend') {
      const arrays: NewsItem[][] = [];
      for (let i: number = 0; i < active.length; i++) {
        arrays.push(await NewsService.fetchSource(active[i], force));
      }
      result = NewsService.merge(arrays, limit);
    } else if (channelId === 'ai') {
      const tech: NewsItem[] = await NewsService.fetchChannel('tech', limit * 2, force);
      const finance: NewsItem[] = await NewsService.fetchChannel('finance', limit * 2, force);
      const combined: NewsItem[] = NewsService.merge([tech, finance], limit * 2);
      const filtered: NewsItem[] = [];
      for (let i: number = 0; i < combined.length; i++) {
        if (NewsService.matchesAi(combined[i])) {
          filtered.push(combined[i]);
          if (filtered.length >= limit) break;
        }
      }
      result = filtered;
    } else {
      const arrays: NewsItem[][] = [];
      for (let i: number = 0; i < active.length; i++) {
        if (active[i].category === channelId) {
          arrays.push(await NewsService.fetchSource(active[i], force));
        }
      }
      result = NewsService.merge(arrays, limit);
    }

    // 离线回退 / 快照更新
    if (result.length === 0) {
      const cached: NewsItem[] | null = await NewsRepository.loadChannelCache(channelId);
      if (cached !== null) return cached;
    } else {
      NewsRepository.saveChannelCache(channelId, result);
    }
    return result;
  }

  // 跨源关键词搜索：Hacker News Algolia 搜索 + 本地各源标题/摘要过滤，合并去重
  static async search(keyword: string, limit: number = 30): Promise<NewsItem[]> {
    const q: string = keyword.trim();
    if (q.length === 0) return [];
    const arrays: NewsItem[][] = [];
    // 1) HN 全文搜索（免费无 key）
    try {
      const url: string = 'https://hn.algolia.com/api/v1/search?query=' + encodeURIComponent(q) +
        '&hitsPerPage=30';
      const text: string = await NewsService.httpGet(url);
      const hits: NewsItem[] = NewsService.parseHn(text);
      if (hits.length > 0) arrays.push(hits);
    } catch (e) {
    }
    // 2) 本地各源当前 feed 过滤（标题/摘要包含关键词）
    try {
      const feeds: NewsItem[] = await NewsService.fetchChannel('recommend', 60, false);
      const lower: string = q.toLowerCase();
      const local: NewsItem[] = [];
      for (let i: number = 0; i < feeds.length; i++) {
        const hay: string = (feeds[i].title + ' ' + feeds[i].summary).toLowerCase();
        if (hay.indexOf(lower) >= 0) {
          local.push(feeds[i]);
        }
      }
      if (local.length > 0) arrays.push(local);
    } catch (e) {
    }
    if (arrays.length === 0) return [];
    return NewsService.merge(arrays, limit);
  }

  // 读取用户自定义 RSS 订阅（settings.newsCustomRss：JSON 数组 [{name, url}]）
  static async customSources(): Promise<NewsSourceDef[]> {
    const sources: NewsSourceDef[] = [];
    try {
      const raw: string = await DatabaseHelper.getSetting('newsCustomRss', '');
      if (raw.trim().length === 0) return sources;
      const parsed: Object = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const arr: Object[] = parsed as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const entry: Record<string, Object> = arr[i] as Record<string, Object>;
          const name: string = typeof entry['name'] === 'string' ? entry['name'] as string : '';
          const url: string = typeof entry['url'] === 'string' ? entry['url'] as string : '';
          if (name.trim().length === 0 || url.trim().length === 0) continue;
          if (url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0) continue;
          sources.push(new NewsSourceDef('custom:' + NewsService.simpleHash(url), name.trim(),
            'recommend', 'rss', url.trim()));
        }
      }
    } catch (e) {
    }
    return sources;
  }

  // 读取设置中启用的源 id 列表；为空表示全部启用
  private static async enabledSourceIds(): Promise<string[]> {
    try {
      const raw: string = await DatabaseHelper.getSetting('newsEnabledSources', '');
      if (raw.trim().length === 0) return [];
      const parsed: Object = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const ids: string[] = [];
        const arr: Object[] = parsed as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') ids.push(arr[i] as string);
        }
        return ids;
      }
    } catch (e) {
    }
    return [];
  }

  // 清理全部缓存（下拉刷新强刷前可调用；fetchChannel(force=true) 已内部处理）
  static clearCache(): void {
    NewsService.cache.clear();
  }

  // ==================== 单源拉取（带缓存与并发去重） ====================

  private static async fetchSource(def: NewsSourceDef, force: boolean): Promise<NewsItem[]> {
    const cached: FeedCacheEntry | undefined = NewsService.cache.get(def.id);
    if (!force && cached !== undefined && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
      return cached.items;
    }
    const pending: Promise<NewsItem[]> | undefined = NewsService.inFlight.get(def.id);
    if (pending !== undefined) return pending;
    const task: Promise<NewsItem[]> = NewsService.fetchSourceInner(def).then((items: NewsItem[]) => {
      NewsService.cache.set(def.id, { items: items, fetchedAt: Date.now() });
      NewsService.inFlight.delete(def.id);
      return items;
    }).catch(() => {
      NewsService.inFlight.delete(def.id);
      return [] as NewsItem[];
    });
    NewsService.inFlight.set(def.id, task);
    return task;
  }

  private static async fetchSourceInner(def: NewsSourceDef): Promise<NewsItem[]> {
    try {
      if (def.type === 'zhihu') {
        const text: string = await NewsService.httpGet(def.url);
        return NewsService.parseZhihu(text);
      }
      if (def.type === 'hn') {
        const text: string = await NewsService.httpGet(def.url);
        return NewsService.parseHn(text);
      }
      if (def.type === 'rss') {
        const xml: string = await NewsService.httpGet(def.url);
        return NewsService.parseRss(xml, def);
      }
    } catch (e) {
    }
    return [];
  }

  // ==================== HTTP ====================

  private static async httpGet(url: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT,
        header: { 'Accept': 'application/json, application/xml, text/xml, text/plain, */*' },
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode !== 200) return '';
      return response.result as string;
    } finally {
      request.destroy();
    }
  }

  // ==================== 归一化解析 ====================

  // 知乎日报：https://news-at.zhihu.com/api/4/news/latest
  static parseZhihu(text: string): NewsItem[] {
    const items: NewsItem[] = [];
    try {
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const stories: Object | undefined = parsed['stories'];
      if (stories !== undefined && Array.isArray(stories)) {
        const arr: Object[] = stories as Object[];
        const now: number = Date.now();
        for (let i: number = 0; i < arr.length; i++) {
          const s: Record<string, Object> = arr[i] as Record<string, Object>;
          const id: string = typeof s['id'] === 'number' ? (s['id'] as number).toString() : '';
          if (id.length === 0) continue;
          const title: string = typeof s['title'] === 'string' ? s['title'] as string : '';
          if (title.length === 0) continue;
          const hint: string = typeof s['hint'] === 'string' ? s['hint'] as string : '';
          let url: string = typeof s['url'] === 'string' ? s['url'] as string : '';
          if (url.length === 0) url = 'https://daily.zhihu.com/story/' + id;
          let image: string = '';
          const img: Object | undefined = s['image'];
          if (typeof img === 'string') {
            image = img as string;
          } else {
            const images: Object | undefined = s['images'];
            if (images !== undefined && Array.isArray(images) && (images as Object[]).length > 0) {
              const first: Object = (images as Object[])[0];
              if (typeof first === 'string') image = first as string;
            }
          }
          items.push(new NewsItem('zhihu:' + id, title, hint, url, image, 'zhihu', '知乎日报',
            'recommend', now - i * 60000));
        }
      }
    } catch (e) {
    }
    return items;
  }

  // Hacker News Algolia：https://hn.algolia.com/api/v1/search?tags=front_page
  static parseHn(text: string): NewsItem[] {
    const items: NewsItem[] = [];
    try {
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const hits: Object | undefined = parsed['hits'];
      if (hits !== undefined && Array.isArray(hits)) {
        const arr: Object[] = hits as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const h: Record<string, Object> = arr[i] as Record<string, Object>;
          const objectID: string = typeof h['objectID'] === 'string' ? h['objectID'] as string : '';
          if (objectID.length === 0) continue;
          const title: string = typeof h['title'] === 'string' ? h['title'] as string : '';
          if (title.length === 0) continue;
          let url: string = typeof h['url'] === 'string' ? h['url'] as string : '';
          if (url.length === 0) url = 'https://news.ycombinator.com/item?id=' + objectID;
          const points: number = typeof h['points'] === 'number' ? h['points'] as number : 0;
          const comments: number = typeof h['num_comments'] === 'number' ? h['num_comments'] as number : 0;
          const author: string = typeof h['author'] === 'string' ? h['author'] as string : '';
          const created: number = typeof h['created_at_i'] === 'number' ?
            (h['created_at_i'] as number) * 1000 : Date.now();
          const summary: string = points.toString() + ' 分 · ' + comments.toString() + ' 评论 · ' +
            (author.length > 0 ? author : '匿名');
          items.push(new NewsItem('hn:' + objectID, title, summary, url, '', 'hn', 'Hacker News',
            'tech', created));
        }
      }
    } catch (e) {
    }
    return items;
  }

  // RSS/Atom：经 @ohos.convertxml 解析为 JS 对象后遍历
  static parseRss(xml: string, def: NewsSourceDef): NewsItem[] {
    const items: NewsItem[] = [];
    if (xml.trim().length === 0) return items;
    try {
      const conv: convertxml.ConvertXML = new convertxml.ConvertXML();
      const options: XmlConvertOptions = {
        trim: false,
        declarationKey: '_declaration',
        instructionKey: '_instruction',
        attributesKey: '_attributes',
        textKey: '_text',
        cdataKey: '_cdata',
        doctypeKey: '_doctype',
        commentKey: '_comment',
        parentKey: '_parent',
        typeKey: '_type',
        nameKey: '_name',
        elementsKey: '_elements'
      };
      const root: Record<string, Object> = conv.convertToJSObject(xml, options as convertxml.ConvertOptions) as Record<string, Object>;
      const rss: Object | undefined = root['rss'];
      if (rss !== undefined) {
        const rssObj: Record<string, Object> = rss as Record<string, Object>;
        const channel: Object | undefined = rssObj['channel'];
        if (channel !== undefined) {
          const channelObj: Record<string, Object> = channel as Record<string, Object>;
          const itemList: Object | undefined = channelObj['item'];
          if (itemList !== undefined) {
            if (Array.isArray(itemList)) {
              const arr: Object[] = itemList as Object[];
              for (let i: number = 0; i < arr.length; i++) {
                NewsService.pushRssItem(items, arr[i] as Record<string, Object>, def);
              }
            } else {
              NewsService.pushRssItem(items, itemList as Record<string, Object>, def);
            }
          }
        }
      }
      const feed: Object | undefined = root['feed'];
      if (feed !== undefined && items.length === 0) {
        const feedObj: Record<string, Object> = feed as Record<string, Object>;
        const entryList: Object | undefined = feedObj['entry'];
        if (entryList !== undefined) {
          if (Array.isArray(entryList)) {
            const arr: Object[] = entryList as Object[];
            for (let i: number = 0; i < arr.length; i++) {
              NewsService.pushAtomItem(items, arr[i] as Record<string, Object>, def);
            }
          } else {
            NewsService.pushAtomItem(items, entryList as Record<string, Object>, def);
          }
        }
      }
    } catch (e) {
    }
    return items;
  }

  // RSS 2.0 item
  private static pushRssItem(items: NewsItem[], item: Record<string, Object>, def: NewsSourceDef): void {
    const title: string = NewsService.nodeText(item['title']);
    if (title.length === 0) return;
    const link: string = NewsService.nodeText(item['link']);
    if (link.length === 0) return;
    const description: string = NewsService.stripHtml(NewsService.nodeText(item['description']));
    const pubDate: string = NewsService.nodeText(item['pubDate']);
    const ts: number = NewsService.parseDate(pubDate);
    let image: string = '';
    const enc: Object | undefined = item['enclosure'];
    if (enc !== undefined) {
      image = NewsService.nodeAttr(enc, 'url');
    }
    const id: string = 'rss:' + NewsService.simpleHash(link);
    items.push(new NewsItem(id, title, description, link, image, def.id, def.name, def.category, ts));
  }

  // Atom entry
  private static pushAtomItem(items: NewsItem[], entry: Record<string, Object>, def: NewsSourceDef): void {
    const title: string = NewsService.nodeText(entry['title']);
    if (title.length === 0) return;
    let link: string = '';
    const linkVal: Object | undefined = entry['link'];
    if (linkVal !== undefined) {
      if (Array.isArray(linkVal)) {
        const arr: Object[] = linkVal as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const href: string = NewsService.nodeAttr(arr[i], 'href');
          if (href.length > 0) {
            link = href;
            break;
          }
        }
      } else {
        link = NewsService.nodeAttr(linkVal, 'href');
      }
    }
    if (link.length === 0) return;
    const summary: string = NewsService.stripHtml(NewsService.nodeText(entry['summary']));
    const published: string = NewsService.nodeText(entry['published']);
    const updated: string = NewsService.nodeText(entry['updated']);
    const ts: number = NewsService.parseDate(published.length > 0 ? published : updated);
    const id: string = 'rss:' + NewsService.simpleHash(link);
    items.push(new NewsItem(id, title, summary, link, '', def.id, def.name, def.category, ts));
  }

  // ==================== XML 取值工具 ====================

  private static nodeText(node: Object | undefined): string {
    if (node === undefined) return '';
    const rec: Record<string, Object> = node as Record<string, Object>;
    const text: Object | undefined = rec['_text'];
    if (typeof text === 'string') return (text as string).trim();
    const cdata: Object | undefined = rec['_cdata'];
    if (typeof cdata === 'string') return (cdata as string).trim();
    if (typeof node === 'string') return (node as string).trim();
    return '';
  }

  private static nodeAttr(node: Object, attr: string): string {
    const rec: Record<string, Object> = node as Record<string, Object>;
    const attrs: Object | undefined = rec['_attributes'];
    if (attrs !== undefined) {
      const attrObj: Record<string, Object> = attrs as Record<string, Object>;
      const v: Object | undefined = attrObj[attr];
      if (typeof v === 'string') return v as string;
    }
    return '';
  }

  private static stripHtml(html: string): string {
    return html.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
      .replace(/\s+/g, ' ').trim();
  }

  // ==================== 工具 ====================

  // 简单字符串哈希（生成 RSS 条目 id）
  private static simpleHash(input: string): string {
    let hash: number = 0;
    for (let i: number = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.charCodeAt(i)) | 0;
    }
    return Math.abs(hash).toString(36);
  }

  private static parseDate(value: string): number {
    if (value.length === 0) return Date.now();
    const d: Date = new Date(value);
    const ts: number = d.getTime();
    return isNaN(ts) ? Date.now() : ts;
  }

  // 多源数组合并：按时间倒序 + URL 去重
  static merge(arrays: NewsItem[][], limit: number): NewsItem[] {
    const all: NewsItem[] = [];
    for (let i: number = 0; i < arrays.length; i++) {
      const arr: NewsItem[] = arrays[i];
      for (let j: number = 0; j < arr.length; j++) {
        all.push(arr[j]);
      }
    }
    all.sort((a: NewsItem, b: NewsItem) => b.publishedAt - a.publishedAt);
    const seen: Set<string> = new Set<string>();
    const out: NewsItem[] = [];
    for (let i: number = 0; i < all.length; i++) {
      const item: NewsItem = all[i];
      if (seen.has(item.url)) continue;
      seen.add(item.url);
      out.push(item);
      if (out.length >= limit) break;
    }
    return out;
  }

  // AI 专题关键词匹配
  private static matchesAi(item: NewsItem): boolean {
    const text: string = (item.title + ' ' + item.summary).toLowerCase();
    for (let i: number = 0; i < AI_KEYWORDS.length; i++) {
      if (text.indexOf(AI_KEYWORDS[i].toLowerCase()) >= 0) return true;
    }
    return false;
  }
}

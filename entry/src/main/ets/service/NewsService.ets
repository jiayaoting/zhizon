// 智子 - 新闻数据服务（多源拉取 / 归一化 / 合并 / 内存缓存 / RSS 解析）
import { http } from '@kit.NetworkKit';
import { convertxml } from '@kit.ArkTS';
import { NewsItem, NewsSourceDef, NewsChannel } from '../common/NewsModels';
import { NEWS_SOURCES, AI_KEYWORDS, TAG_KEYWORDS, SOURCE_LANGUAGES, channelById } from '../common/NewsChannels';
import { DatabaseHelper, NewsTagEntry } from './DatabaseHelper';
import { NewsRepository } from './NewsRepository';
import { NewsRanker } from './NewsRanker';
import { NewsAiService } from './NewsAiService';
import { DataRepository } from './DataRepository';
import { LlmConfig, LlmResult } from '../common/LlmModels';

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
// L1 规则标签上限
const TAG_MAX: number = 8;
// CJK 字符区间（语言检测）
const CJK_RE: RegExp = /[\u4e00-\u9fff\u3400-\u4dbf]/g;

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
      // 多源并发抓取（源多时避免串行等待；fetchSource 内部有 inFlight 去重）
      const tasks: Promise<NewsItem[]>[] = [];
      for (let i: number = 0; i < active.length; i++) {
        tasks.push(NewsService.fetchSource(active[i], force));
      }
      const arrays: NewsItem[][] = await Promise.all(tasks);
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
      const tasks: Promise<NewsItem[]>[] = [];
      for (let i: number = 0; i < active.length; i++) {
        if (active[i].category === channelId) {
          tasks.push(NewsService.fetchSource(active[i], force));
        }
      }
      const arrays: NewsItem[][] = await Promise.all(tasks);
      result = NewsService.merge(arrays, limit);
    }

    // 标签/语言增强（点踩未勾选标签的单篇不再硬排除，改由排序软降权）
    NewsService.enrich(result);

    // M4：LLM 智能标签增强（默认关闭；开启后用所选模型生成更细标签，失败自动保留 L1）
    result = await NewsService.enhanceWithLlm(result);

    // M2 + 个性化模式 + 单篇软降权（v0.8）
    if (result.length > 0) {
      const excludedUrls: string[] = await NewsRepository.listExcludedUrls();
      const mode: string = await DataRepository.getSetting('newsPersonalizedMode', 'standard');
      if (mode === 'hot') {
        // 仅热点：纯时间排序（单篇仍软降权到最后）
        result = NewsService.moveExcludedTail(result, excludedUrls).slice(0, limit);
      } else if (await NewsRepository.isChannelPersonalized(channelId)) {
        // 个性化排序：按模式参数打分，排除单篇扣分但不移除
        result = await NewsRanker.rank(result, limit, mode, excludedUrls);
      } else {
        // 频道已关闭个性化：恢复纯时间排序，单篇软降权到最后
        result = NewsService.moveExcludedTail(result, excludedUrls).slice(0, limit);
      }
    }

    // 离线回退 / 快照更新
    if (result.length === 0) {
      const cached: NewsItem[] | null = await NewsRepository.loadChannelCache(channelId);
      if (cached !== null) {
        NewsService.enrich(cached);
        return cached;
      }
    } else {
      NewsRepository.saveChannelCache(channelId, result);
    }
    return result;
  }

  // ==================== L1 标签与语言识别 ====================

  // 为一批条目补齐 tags / language（幂等：已有 tags 的不重复打）
  static enrich(items: NewsItem[]): NewsItem[] {
    for (let i: number = 0; i < items.length; i++) {
      const item: NewsItem = items[i];
      if (item.tags === undefined || item.tags.length === 0) {
        item.tags = NewsService.tagItem(item);
      }
      if (item.language === undefined || item.language.length === 0) {
        item.language = NewsService.detectLanguage(item);
      }
    }
    return items;
  }

  // 单篇打标签：频道标签 + 词典关键词命中，去重后最多 TAG_MAX 个
  private static tagItem(item: NewsItem): string[] {
    const tags: string[] = [];
    const ch: NewsChannel | null = channelById(item.category);
    if (ch !== null && tags.indexOf(ch.name) < 0) {
      tags.push(ch.name);
    }
    const hay: string = (item.title + ' ' + item.summary);
    const keys: string[] = Object.keys(TAG_KEYWORDS);
    for (let i: number = 0; i < keys.length; i++) {
      const tag: string = keys[i];
      const words: string[] = TAG_KEYWORDS[tag];
      for (let j: number = 0; j < words.length; j++) {
        if (hay.indexOf(words[j]) >= 0) {
          if (tags.indexOf(tag) < 0) tags.push(tag);
          break;
        }
      }
      if (tags.length >= TAG_MAX) break;
    }
    return tags;
  }

  // 语言检测：内置源预置优先，否则按 CJK 字符占比（<5% 视为外文）
  private static detectLanguage(item: NewsItem): string {
    const preset: string | undefined = SOURCE_LANGUAGES[item.sourceId];
    if (preset !== undefined && preset.length > 0) return preset;
    const text: string = item.title + ' ' + item.summary;
    if (text.trim().length === 0) return 'zh';
    const cjkMatches: RegExpMatchArray | null = text.match(CJK_RE);
    const cjkCount: number = cjkMatches === null ? 0 : cjkMatches.length;
    return (cjkCount / text.length) < 0.05 ? 'en' : 'zh';
  }

  // ==================== LLM 智能标签（M4） ====================

  // L2 增强：开启且模型可用时为候选前 20 条生成 LLM 标签（并发 3，24h 缓存）
  static async enhanceWithLlm(items: NewsItem[]): Promise<NewsItem[]> {
    try {
      if (items.length === 0) return items;
      const config: LlmConfig | null = await NewsAiService.getTagConfig();
      if (config === null) return items;
      const cap: number = items.length > 20 ? 20 : items.length;
      const BATCH: number = 3;
      for (let i: number = 0; i < cap; i += BATCH) {
        const tasks: Promise<void>[] = [];
        const end: number = i + BATCH < cap ? i + BATCH : cap;
        for (let j: number = i; j < end; j++) {
          tasks.push(NewsService.llmTagOne(items[j], config));
        }
        await Promise.all(tasks);
      }
    } catch (e) {
    }
    return items;
  }

  // 单篇 LLM 打标签：缓存优先（24h）；成功写 news_tags，失败静默保留 L1 标签
  private static async llmTagOne(item: NewsItem, config: LlmConfig): Promise<void> {
    try {
      if (item.url.length === 0) return;
      const cached: NewsTagEntry | null = await NewsRepository.getTags(item.url);
      if (cached !== null && cached.sourceType === 'llm' &&
        Date.now() - cached.updatedAt < 24 * 3600 * 1000) {
        const cachedTags: string[] = NewsAiService.parseTagsJson(cached.tagsJson);
        if (cachedTags.length > 0) {
          item.tags = cachedTags;
        }
        return;
      }
      const result: LlmResult = await NewsAiService.generateTags(config, item);
      if (result.success) {
        const tags: string[] = NewsAiService.parseTagsJson(result.content);
        if (tags.length > 0) {
          item.tags = tags;
          await NewsRepository.saveTags(item.url, tags, 'llm', config.displayName);
        }
      }
    } catch (e) {
    }
  }

  // 单篇软降权：把排除的 url 移到列表尾部（保持各自内部时间顺序，不硬删除）
  static moveExcludedTail(items: NewsItem[], excluded: string[]): NewsItem[] {
    if (excluded.length === 0) return items;
    const normal: NewsItem[] = [];
    const tail: NewsItem[] = [];
    for (let i: number = 0; i < items.length; i++) {
      if (excluded.indexOf(items[i].url) >= 0) {
        tail.push(items[i]);
      } else {
        normal.push(items[i]);
      }
    }
    return normal.concat(tail);
  }

  // 单篇排除过滤（仅 search 使用：查询结果中直接不出现已排除单篇）
  private static excludedUrls: Map<string, number> = new Map<string, number>();
  private static async filterExcluded(items: NewsItem[]): Promise<NewsItem[]> {
    try {
      const now: number = Date.now();
      let urls: string[] = [];
      if (NewsService.excludedUrls.size === 0 || now - NewsService.excludedUrls.get('_ts')! > 30000) {
        urls = await NewsRepository.listExcludedUrls();
        NewsService.excludedUrls.clear();
        NewsService.excludedUrls.set('_ts', now);
        for (let i: number = 0; i < urls.length; i++) {
          NewsService.excludedUrls.set(urls[i], now);
        }
      } else {
        const keys: string[] = [];
        NewsService.excludedUrls.forEach((v: number, k: string) => {
          if (k !== '_ts') keys.push(k);
        });
        urls = keys;
      }
      if (urls.length === 0) return items;
      const out: NewsItem[] = [];
      for (let i: number = 0; i < items.length; i++) {
        if (urls.indexOf(items[i].url) < 0) out.push(items[i]);
      }
      return out;
    } catch (e) {
      return items;
    }
  }

  // 知乎日报文章 id（'zhihu:123' → '123'；非 zhihu 源返回空）
  static zhihuStoryId(itemId: string): string {
    if (itemId.indexOf('zhihu:') === 0) {
      return itemId.substring('zhihu:'.length);
    }
    return '';
  }

  // 抓取知乎日报正文 HTML（/api/4/news/{id}），补全相对图片协议；失败返回空串
  static async fetchZhihuStory(storyId: string): Promise<string> {
    if (storyId.length === 0) return '';
    try {
      const url: string = 'https://news-at.zhihu.com/api/4/news/' + storyId;
      const text: string = await NewsService.httpGet(url);
      if (text.trim().length === 0) return '';
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const body: Object = parsed['body'];
      if (typeof body !== 'string') return '';
      let html: string = body as string;
      html = html.replace(/src="\/\//g, 'src="https://');
      html = html.replace(/src="http:\/\//g, 'src="https://');
      return html;
    } catch (e) {
      return '';
    }
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
    const merged: NewsItem[] = NewsService.merge(arrays, limit);
    NewsService.enrich(merged);
    return await NewsService.filterExcluded(merged);
  }

  // 解析 OPML 订阅列表（<outline text="名称" xmlUrl="RSS地址"/>，支持嵌套分组）
  static parseOpml(xml: string): NewsSourceDef[] {
    const sources: NewsSourceDef[] = [];
    if (xml.trim().length === 0) return sources;
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
      const root: Record<string, Object> = conv.convertToJSObject(xml, options) as Record<string, Object>;
      const opml: Object | undefined = root['opml'];
      if (opml !== undefined) {
        const opmlObj: Record<string, Object> = opml as Record<string, Object>;
        const body: Object | undefined = opmlObj['body'];
        if (body !== undefined) {
          const bodyObj: Record<string, Object> = body as Record<string, Object>;
          const outline: Object | undefined = bodyObj['outline'];
          if (outline !== undefined) {
            NewsService.collectOpmlOutlines(outline, sources);
          }
        }
      }
    } catch (e) {
    }
    return sources;
  }

  // 递归收集 OPML outline（支持嵌套分组）
  private static collectOpmlOutlines(outline: Object, sources: NewsSourceDef[]): void {
    if (Array.isArray(outline)) {
      const arr: Object[] = outline as Object[];
      for (let i: number = 0; i < arr.length; i++) {
        NewsService.collectOpmlOutlines(arr[i], sources);
      }
      return;
    }
    const node: Record<string, Object> = outline as Record<string, Object>;
    const attrs: Object | undefined = node['_attributes'];
    let title: string = '';
    let xmlUrl: string = '';
    if (attrs !== undefined) {
      const attrObj: Record<string, Object> = attrs as Record<string, Object>;
      const t: Object | undefined = attrObj['title'] !== undefined ? attrObj['title'] : attrObj['text'];
      if (typeof t === 'string') title = (t as string).trim();
      const u: Object | undefined = attrObj['xmlUrl'] !== undefined ? attrObj['xmlUrl'] : attrObj['url'];
      if (typeof u === 'string') xmlUrl = (u as string).trim();
    }
    if (xmlUrl.length > 0 && (xmlUrl.indexOf('http://') === 0 || xmlUrl.indexOf('https://') === 0)) {
      const name: string = title.length > 0 ? title : xmlUrl;
      sources.push(new NewsSourceDef('custom:' + NewsService.simpleHash(xmlUrl), name,
        'recommend', 'rss', xmlUrl));
    }
    // 嵌套 outline
    const nested: Object | undefined = node['outline'];
    if (nested !== undefined) {
      NewsService.collectOpmlOutlines(nested, sources);
    }
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

  // 清空单篇排除的内存缓存（撤销点踩后调用，避免 30s 内仍被过滤）
  static clearExclusionCache(): void {
    NewsService.excludedUrls.clear();
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
          // 缩略图参数：减小列表流量
          if (image.length > 0 && image.indexOf('?') < 0) {
            image = image + '?imageView2/0/w/480';
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

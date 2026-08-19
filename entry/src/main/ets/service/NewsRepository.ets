// 智子 - 新闻数据仓库门面（收藏 / 已读 / AI 今日要闻缓存）
import { DatabaseHelper, NewsArticleCacheEntry } from './DatabaseHelper';
import { NewsItem, NewsDigestEntry } from '../common/NewsModels';

// 资讯统计
export interface NewsStats {
  favoriteCount: number;
  readCount: number;
  aiCallCount: number;
}

// 频道快照缓存行结构（显式 interface，满足 arkts-no-untyped-obj-literals）
interface NewsCacheRow {
  id: string;
  title: string;
  summary: string;
  url: string;
  imageUrl: string;
  sourceId: string;
  sourceName: string;
  category: string;
  publishedAt: number;
}

export class NewsRepository {
  // ==================== 收藏 ====================

  static async isFavorite(url: string): Promise<boolean> {
    return await DatabaseHelper.isNewsFavorite(url);
  }

  static async addFavorite(item: NewsItem): Promise<void> {
    await DatabaseHelper.addNewsFavorite(item);
  }

  static async removeFavorite(url: string): Promise<void> {
    await DatabaseHelper.removeNewsFavorite(url);
  }

  // 收藏/取消收藏；返回 true = 已收藏
  static async toggleFavorite(item: NewsItem): Promise<boolean> {
    const fav: boolean = await DatabaseHelper.isNewsFavorite(item.url);
    if (fav) {
      await DatabaseHelper.removeNewsFavorite(item.url);
      return false;
    }
    await DatabaseHelper.addNewsFavorite(item);
    return true;
  }

  // 收藏列表 → NewsItem（供列表/详情页复用）
  static async listFavorites(): Promise<NewsItem[]> {
    const entries = await DatabaseHelper.listNewsFavorites();
    const items: NewsItem[] = [];
    for (let i: number = 0; i < entries.length; i++) {
      const e = entries[i];
      items.push(new NewsItem('fav:' + e.url, e.title, e.summary, e.url, e.imageUrl,
        'favorite', e.sourceName.length > 0 ? e.sourceName : '收藏', 'recommend', e.addedAt));
    }
    return items;
  }

  static async clearFavorites(): Promise<void> {
    await DatabaseHelper.clearNewsFavorites();
  }

  // ==================== 已读 ====================

  static async markRead(url: string): Promise<void> {
    await DatabaseHelper.markNewsRead(url);
  }

  static async isRead(url: string): Promise<boolean> {
    return await DatabaseHelper.isNewsRead(url);
  }

  static async listReadUrls(): Promise<string[]> {
    return await DatabaseHelper.listNewsReadUrls();
  }

  // ==================== AI 今日要闻 ====================

  static todayKey(): string {
    const d: Date = new Date();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return d.getFullYear().toString() + m + day;
  }

  static todayLabel(): string {
    const d: Date = new Date();
    const week: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return (d.getMonth() + 1).toString() + '月' + d.getDate().toString() + '日 星期' + week[d.getDay()];
  }

  // 当日简报 id：mode = 'digest'（今日要闻）或 'hotspot'（热点速递）
  static digestId(mode: string): string {
    const key: string = NewsRepository.todayKey();
    return mode === 'hotspot' ? 'digest-' + key + '-hotspot' : 'digest-' + key;
  }

  static async todayDigest(mode: string = 'digest'): Promise<NewsDigestEntry | null> {
    return await DatabaseHelper.getNewsDigestById(NewsRepository.digestId(mode));
  }

  static async saveDigest(content: string, modelName: string, mode: string = 'digest'): Promise<NewsDigestEntry> {
    const key: string = NewsRepository.todayKey();
    const entry: NewsDigestEntry = new NewsDigestEntry(NewsRepository.digestId(mode), key, content, modelName, Date.now());
    await DatabaseHelper.saveNewsDigest(entry);
    return entry;
  }

  static async deleteTodayDigest(): Promise<void> {
    await DatabaseHelper.deleteNewsDigest(NewsRepository.todayKey());
  }

  // ==================== 正文缓存（离线全文阅读） ====================

  static async saveArticleCache(url: string, title: string, html: string): Promise<void> {
    if (url.trim().length === 0 || html.trim().length === 0) return;
    await DatabaseHelper.saveNewsArticleCache(url.trim(), title, html);
  }

  static async getArticleCache(url: string): Promise<NewsArticleCacheEntry | null> {
    return await DatabaseHelper.getNewsArticleCache(url);
  }

  // ==================== 统计与清理 ====================

  static async stats(): Promise<NewsStats> {
    const stats: NewsStats = {
      favoriteCount: await DatabaseHelper.countNewsFavorites(),
      readCount: await DatabaseHelper.countNewsRead(),
      aiCallCount: await DatabaseHelper.countNewsAiCalls()
    };
    return stats;
  }

  static async clearRead(): Promise<void> {
    await DatabaseHelper.clearNewsRead();
  }

  static async clearChannelCache(): Promise<void> {
    await DatabaseHelper.clearNewsChannelCache();
  }

  static async clearArticleCache(): Promise<void> {
    await DatabaseHelper.clearNewsArticleCache();
  }

  // ==================== 频道快照缓存（离线阅读） ====================

  static async saveChannelCache(channelId: string, items: NewsItem[]): Promise<void> {
    try {
      const rows: NewsCacheRow[] = [];
      for (let i: number = 0; i < items.length; i++) {
        const item: NewsItem = items[i];
        const row: NewsCacheRow = {
          id: item.id,
          title: item.title,
          summary: item.summary,
          url: item.url,
          imageUrl: item.imageUrl,
          sourceId: item.sourceId,
          sourceName: item.sourceName,
          category: item.category,
          publishedAt: item.publishedAt
        };
        rows.push(row);
      }
      await DatabaseHelper.saveNewsChannelCache(channelId, JSON.stringify(rows));
    } catch (e) {
    }
  }

  static async loadChannelCache(channelId: string): Promise<NewsItem[] | null> {
    try {
      const json: string | null = await DatabaseHelper.getNewsChannelCache(channelId);
      if (json === null || json.trim().length === 0) return null;
      const parsed: Object = JSON.parse(json) as Object;
      if (!Array.isArray(parsed)) return null;
      const arr: Object[] = parsed as Object[];
      const items: NewsItem[] = [];
      for (let i: number = 0; i < arr.length; i++) {
        const r: Record<string, Object> = arr[i] as Record<string, Object>;
        const url: string = typeof r['url'] === 'string' ? r['url'] as string : '';
        const title: string = typeof r['title'] === 'string' ? r['title'] as string : '';
        if (url.length === 0 || title.length === 0) continue;
        items.push(new NewsItem(
          typeof r['id'] === 'string' ? r['id'] as string : 'c:' + url,
          title,
          typeof r['summary'] === 'string' ? r['summary'] as string : '',
          url,
          typeof r['imageUrl'] === 'string' ? r['imageUrl'] as string : '',
          typeof r['sourceId'] === 'string' ? r['sourceId'] as string : '',
          typeof r['sourceName'] === 'string' ? r['sourceName'] as string : '',
          typeof r['category'] === 'string' ? r['category'] as string : 'recommend',
          typeof r['publishedAt'] === 'number' ? r['publishedAt'] as number : 0
        ));
      }
      return items.length > 0 ? items : null;
    } catch (e) {
      return null;
    }
  }
}

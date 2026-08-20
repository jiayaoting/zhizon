// 智子 - 新闻数据仓库门面（收藏 / 已读 / AI 今日要闻缓存）
import { DatabaseHelper, NewsArticleCacheEntry, NewsTagEntry, NewsTranslationEntry } from './DatabaseHelper';
import { NewsItem, NewsDigestEntry, NewsRating } from '../common/NewsModels';
import { NewsProfileService } from './NewsProfileService';

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
  tags: string[];
  language: string;
}

export class NewsRepository {
  // ==================== 收藏 ====================

  static async isFavorite(url: string): Promise<boolean> {
    return await DatabaseHelper.isNewsFavorite(url);
  }

  static async addFavorite(item: NewsItem): Promise<void> {
    await DatabaseHelper.addNewsFavorite(item);
    await NewsRepository.recordEvent('favorite', item, 5, '');
  }

  static async removeFavorite(url: string): Promise<void> {
    await DatabaseHelper.removeNewsFavorite(url);
    const stub: NewsItem = new NewsItem('fav:' + url, '', '', url, '', 'favorite', '收藏', 'recommend', Date.now());
    await NewsRepository.recordEvent('unfavorite', stub, -4, '');
  }

  // 收藏/取消收藏；返回 true = 已收藏（隐式信号：favorite +5 / unfavorite -4）
  static async toggleFavorite(item: NewsItem): Promise<boolean> {
    const fav: boolean = await DatabaseHelper.isNewsFavorite(item.url);
    if (fav) {
      await DatabaseHelper.removeNewsFavorite(item.url);
      await NewsRepository.recordEvent('unfavorite', item, -4, '');
      return false;
    }
    await DatabaseHelper.addNewsFavorite(item);
    await NewsRepository.recordEvent('favorite', item, 5, '');
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

  // 当日简报 id：mode = digest（今日要闻）/ morning（早报）/ noon（午间速递）/ evening（晚报）
  // 'hotspot' 兼容旧版热点速递（映射到 noon）
  static digestId(mode: string): string {
    const key: string = NewsRepository.todayKey();
    if (mode === 'digest') return 'digest-' + key;
    if (mode === 'morning') return 'digest-' + key + '-morning';
    if (mode === 'evening') return 'digest-' + key + '-evening';
    if (mode === 'personal') return 'digest-' + key + '-personal';
    return 'digest-' + key + '-noon';
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

  // ==================== 赞/踩（v15） ====================

  // 写入赞/踩状态（rating: 1 赞 / -1 踩），记录事件，并更新偏好画像权重
  static async setRating(item: NewsItem, rating: number, tags: string[]): Promise<void> {
    const record: NewsRating = new NewsRating(item.url, rating, item.title, item.summary,
      item.imageUrl, item.sourceName, item.category, item.publishedAt, tags, Date.now());
    await DatabaseHelper.setNewsRating(record);
    const eventType: string = rating === 1 ? 'like' : (rating === -1 ? 'dislike' : 'undo');
    const extra: string = tags.length > 0 ? JSON.stringify(tags) : '';
    await DatabaseHelper.recordNewsEvent(eventType, item.url, item.id, rating, extra);
    // M2：权重累积（点赞 → posTags +1；点踩勾选 → negTags +1）
    if (rating === 1 || rating === -1) {
      await NewsProfileService.applyFeedback(item, rating, tags);
    }
  }

  static async getRating(url: string): Promise<NewsRating | null> {
    return await DatabaseHelper.getNewsRating(url);
  }

  static async listRatings(): Promise<NewsRating[]> {
    return await DatabaseHelper.listNewsRatings();
  }

  // 我的点赞列表（rating = 1）
  static async listLikedItems(): Promise<NewsItem[]> {
    const ratings: NewsRating[] = await DatabaseHelper.listNewsRatings();
    const items: NewsItem[] = [];
    for (let i: number = 0; i < ratings.length; i++) {
      const r: NewsRating = ratings[i];
      if (r.rating === 1) {
        items.push(new NewsItem('like:' + r.url, r.title, r.summary, r.url, r.imageUrl,
          'favorite', r.sourceName.length > 0 ? r.sourceName : '我的点赞',
          r.category.length > 0 ? r.category : 'recommend', r.publishedAt, r.tags, 'zh'));
      }
    }
    return items;
  }

  // 撤销赞/踩：回退画像权重并删除状态（无需再单独调用 deleteNewsRating）
  static async removeRating(url: string): Promise<void> {
    await NewsProfileService.revertRating(url);
  }

  // 重置推荐画像（清空权重；不影响收藏/已读）
  static async resetProfile(): Promise<void> {
    await NewsProfileService.reset();
  }

  // 恢复全部被屏蔽的单篇
  static async clearExclusions(): Promise<void> {
    await DatabaseHelper.clearNewsExclusions();
  }

  // ==================== 行为事件（v15） ====================

  static async recordEvent(eventType: string, item: NewsItem | null = null,
    weight: number = 0, extraJson: string = ''): Promise<void> {
    const url: string = item === null ? '' : item.url;
    const itemId: string = item === null ? '' : item.id;
    await DatabaseHelper.recordNewsEvent(eventType, url, itemId, weight, extraJson);
  }

  // ==================== 单篇排除（v15） ====================

  static async excludeUrl(url: string, reason: string = ''): Promise<void> {
    await DatabaseHelper.addNewsExclusion(url, reason);
  }

  static async isUrlExcluded(url: string): Promise<boolean> {
    return await DatabaseHelper.isNewsExcluded(url);
  }

  static async unexcludeUrl(url: string): Promise<void> {
    await DatabaseHelper.removeNewsExclusion(url);
  }

  static async listExcludedUrls(): Promise<string[]> {
    return await DatabaseHelper.listNewsExcludedUrls();
  }

  // ==================== 标签缓存（v15，L2 预留） ====================

  static async saveTags(url: string, tags: string[], sourceType: string = 'rule',
    model: string = ''): Promise<void> {
    await DatabaseHelper.saveNewsTags(url, JSON.stringify(tags), sourceType, model);
  }

  static async getTags(url: string): Promise<NewsTagEntry | null> {
    return await DatabaseHelper.getNewsTags(url);
  }

  // 清除全部标签缓存（LLM 标签重生成时使用）
  static async clearTags(): Promise<void> {
    await DatabaseHelper.clearNewsTags();
  }

  // ==================== 翻译缓存（v15 / M3） ====================

  // 卡片轻量译（标题+摘要）
  static async saveTitleTranslation(item: NewsItem, text: string, model: string): Promise<void> {
    await DatabaseHelper.saveNewsTranslation(item.url, 'title', 'en->zh', text, model);
  }

  static async getTitleTranslation(url: string): Promise<string> {
    const entry: NewsTranslationEntry | null = await DatabaseHelper.getNewsTranslation(url, 'title');
    return entry === null ? '' : entry.text;
  }

  // 详情页全文译
  static async saveBodyTranslation(item: NewsItem, text: string, model: string): Promise<void> {
    await DatabaseHelper.saveNewsTranslation(item.url, 'body', 'en->zh', text, model);
  }

  static async getBodyTranslation(url: string): Promise<string> {
    const entry: NewsTranslationEntry | null = await DatabaseHelper.getNewsTranslation(url, 'body');
    return entry === null ? '' : entry.text;
  }

  static async clearTranslations(): Promise<void> {
    await DatabaseHelper.clearNewsTranslations();
  }

  // ==================== 频道个性化开关（v15） ====================

  // 读取关闭个性化的频道 id 列表（默认空 = 全部频道个性化）
  private static async personalizedOffIds(): Promise<string[]> {
    try {
      const raw: string = await DatabaseHelper.getSetting('newsPersonalizedChannels', '');
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

  // 频道是否启用个性化（默认 true；新增频道自动默认启用）
  static async isChannelPersonalized(channelId: string): Promise<boolean> {
    const off: string[] = await NewsRepository.personalizedOffIds();
    return off.indexOf(channelId) < 0;
  }

  // 设置频道个性化开关（false = 关闭该频道个性化）
  static async setChannelPersonalized(channelId: string, on: boolean): Promise<void> {
    const off: string[] = await NewsRepository.personalizedOffIds();
    const idx: number = off.indexOf(channelId);
    if (on && idx >= 0) {
      off.splice(idx, 1);
    } else if (!on && idx < 0) {
      off.push(channelId);
    } else {
      return;
    }
    await DatabaseHelper.setSetting('newsPersonalizedChannels', JSON.stringify(off));
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
          publishedAt: item.publishedAt,
          tags: item.tags === undefined ? [] : item.tags,
          language: item.language === undefined ? '' : item.language
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
        let tags: string[] = [];
        const rawTags: Object | undefined = r['tags'];
        if (rawTags !== undefined && Array.isArray(rawTags)) {
          const arr: Object[] = rawTags as Object[];
          tags = [];
          for (let t: number = 0; t < arr.length; t++) {
            if (typeof arr[t] === 'string') tags.push(arr[t] as string);
          }
        }
        items.push(new NewsItem(
          typeof r['id'] === 'string' ? r['id'] as string : 'c:' + url,
          title,
          typeof r['summary'] === 'string' ? r['summary'] as string : '',
          url,
          typeof r['imageUrl'] === 'string' ? r['imageUrl'] as string : '',
          typeof r['sourceId'] === 'string' ? r['sourceId'] as string : '',
          typeof r['sourceName'] === 'string' ? r['sourceName'] as string : '',
          typeof r['category'] === 'string' ? r['category'] as string : 'recommend',
          typeof r['publishedAt'] === 'number' ? r['publishedAt'] as number : 0,
          tags,
          typeof r['language'] === 'string' ? r['language'] as string : ''
        ));
      }
      return items.length > 0 ? items : null;
    } catch (e) {
      return null;
    }
  }
}

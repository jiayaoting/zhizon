// 智子 - 热榜本地数据仓库（收藏 / 已读 / 正文缓存 / AI 今日要闻 / 搜索）
// 设计文档：doc/newsnow-redesign.md §10
// 主键统一为 HotEntry.key（`sourceId:itemId`），避免跨源同 URL 相互覆盖
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper, HotFavoriteEntry, HotArticleCacheEntry } from '../platform/DatabaseHelper';
import { HotEntry, HotItem, HotDigestEntry } from '../../common/HotModels';

// 热榜本地全文索引（hot_articles_fts 虚拟表；不可用时回退 LIKE）
const SQL_HOT_FTS_INSERT = 'INSERT OR REPLACE INTO hot_articles_fts (kind, key, title, body) VALUES (?, ?, ?, ?)';
const SQL_HOT_FTS_DELETE = 'DELETE FROM hot_articles_fts WHERE kind = ? AND key = ?';
const SQL_HOT_FTS_DELETE_KIND = 'DELETE FROM hot_articles_fts WHERE kind = ?';

// 资讯统计
export interface HotStats {
  favoriteCount: number;
  readCount: number;
  aiCallCount: number;
}

// 搜索结果条目（收藏 / 正文缓存）
export class HotSearchHit {
  key: string;
  title: string;
  url: string;
  sourceId: string;
  sourceName: string;
  info: string;
  kind: string;      // 'fav' | 'article'

  constructor(key: string, title: string, url: string, sourceId: string,
    sourceName: string, info: string, kind: string) {
    this.key = key;
    this.title = title;
    this.url = url;
    this.sourceId = sourceId;
    this.sourceName = sourceName;
    this.info = info;
    this.kind = kind;
  }
}

export class NewsRepository {
  // ==================== 收藏 ====================

  static async isFavorite(key: string): Promise<boolean> {
    return await DatabaseHelper.isHotFavorite(key);
  }

  static async addFavorite(entry: HotEntry): Promise<void> {
    const row: HotFavoriteEntry = {
      key: entry.key,
      sourceId: entry.sourceId,
      sourceName: entry.sourceName,
      title: entry.item.title,
      url: entry.item.url,
      info: entry.item.info,
      addedAt: Date.now()
    };
    await DatabaseHelper.addHotFavorite(row);
    await NewsRepository.indexItem('fav', entry.key, entry.item.title, entry.item.info);
  }

  static async removeFavorite(key: string): Promise<void> {
    await DatabaseHelper.removeHotFavorite(key);
    await NewsRepository.unindexItem('fav', key);
  }

  // 切换收藏；返回切换后是否已收藏
  static async toggleFavorite(entry: HotEntry): Promise<boolean> {
    const fav: boolean = await DatabaseHelper.isHotFavorite(entry.key);
    if (fav) {
      await NewsRepository.removeFavorite(entry.key);
      return false;
    }
    await NewsRepository.addFavorite(entry);
    return true;
  }

  // 收藏列表 → HotEntry（列表/详情页复用）
  static async listFavorites(): Promise<HotEntry[]> {
    const rows: HotFavoriteEntry[] = await DatabaseHelper.listHotFavorites();
    const out: HotEntry[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const r: HotFavoriteEntry = rows[i];
      const itemId: string = NewsRepository.itemIdOf(r.key);
      const item: HotItem = new HotItem(itemId, r.title, r.url, r.url, 0, r.info);
      out.push(new HotEntry(r.key, item, r.sourceId, r.sourceName));
    }
    return out;
  }

  static async clearFavorites(): Promise<void> {
    await DatabaseHelper.clearHotFavorites();
    await NewsRepository.clearFtsKind('fav');
  }

  // ==================== 已读 ====================

  static async markRead(key: string): Promise<void> {
    if (key.length === 0) return;
    await DatabaseHelper.markHotRead(key);
  }

  static async isRead(key: string): Promise<boolean> {
    return await DatabaseHelper.isHotRead(key);
  }

  static async listReadKeys(): Promise<string[]> {
    return await DatabaseHelper.listHotReadKeys();
  }

  static async clearRead(): Promise<void> {
    await DatabaseHelper.clearHotRead();
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
  static digestId(mode: string): string {
    const key: string = NewsRepository.todayKey();
    if (mode === 'digest') return 'digest-' + key;
    if (mode === 'morning') return 'digest-' + key + '-morning';
    if (mode === 'evening') return 'digest-' + key + '-evening';
    return 'digest-' + key + '-noon';
  }

  static async todayDigest(mode: string = 'digest'): Promise<HotDigestEntry | null> {
    return await DatabaseHelper.getHotDigestById(NewsRepository.digestId(mode));
  }

  static async saveDigest(content: string, modelName: string, mode: string = 'digest'): Promise<HotDigestEntry> {
    const key: string = NewsRepository.todayKey();
    const entry: HotDigestEntry =
      new HotDigestEntry(NewsRepository.digestId(mode), key, content, modelName, Date.now());
    await DatabaseHelper.saveHotDigest(entry);
    return entry;
  }

  // ==================== 正文缓存（离线阅读 + AI 摘要/翻译正文来源） ====================

  static async saveArticleCache(url: string, title: string, html: string): Promise<void> {
    if (url.trim().length === 0 || html.trim().length === 0) return;
    await DatabaseHelper.saveHotArticleCache(url.trim(), title, html);
    await NewsRepository.indexItem('article', url.trim(), title, html);
  }

  static async getArticleCache(url: string): Promise<HotArticleCacheEntry | null> {
    return await DatabaseHelper.getHotArticleCache(url);
  }

  static async clearArticleCache(): Promise<void> {
    await DatabaseHelper.clearHotArticleCache();
    await NewsRepository.clearFtsKind('article');
  }

  // ==================== 搜索（收藏 + 正文缓存） ====================

  static async searchFavorites(q: string, limit: number): Promise<HotSearchHit[]> {
    const out: HotSearchHit[] = [];
    const query: string = q.trim();
    if (query.length === 0) return out;
    const rows: HotFavoriteEntry[] = await DatabaseHelper.listHotFavorites();
    // FTS 优先（命中的 key 集合），失败或未命中回退 LIKE
    let keys: string[] = await NewsRepository.ftsKeys('fav', query, limit);
    if (keys.length === 0) {      for (let i: number = 0; i < rows.length && out.length < limit; i++) {
        const r: HotFavoriteEntry = rows[i];
        if (r.title.indexOf(query) >= 0 || r.info.indexOf(query) >= 0) out.push(NewsRepository.favToHit(r));
      }
      return out;
    }
    for (let i: number = 0; i < rows.length && out.length < limit; i++) {
      if (keys.indexOf(rows[i].key) >= 0) out.push(NewsRepository.favToHit(rows[i]));
    }
    return out;
  }

  // 正文缓存命中（FTS 优先，回退 LIKE）
  static async searchArticles(q: string, limit: number): Promise<HotSearchHit[]> {
    const out: HotSearchHit[] = [];
    const query: string = q.trim();
    if (query.length === 0) return out;
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    if (DatabaseHelper.isHotFtsReady() && query.length >= 3) {
      try {
        const sql: string = 'SELECT key, title FROM hot_articles_fts WHERE kind = ? AND hot_articles_fts MATCH ? LIMIT ?';
        const args: Array<relationalStore.ValueType> = ['article', NewsRepository.ftsPhrase(query), limit];
        const rs: relationalStore.ResultSet = await store.querySql(sql, args);
        try {
          while (rs.goToNextRow()) {
            const url: string = rs.getString(rs.getColumnIndex('key'));
            const title: string = rs.getString(rs.getColumnIndex('title'));
            out.push(new HotSearchHit(url, title, url, '', '缓存正文', '', 'article'));
          }
        } finally {
          rs.close();
        }
        if (out.length > 0) return out;
      } catch (e) {
      }
    }
    const like: string = '%' + query + '%';
    const sql2: string = 'SELECT url, title FROM hot_article_cache WHERE title LIKE ? OR html LIKE ? LIMIT ?';
    const args2: Array<relationalStore.ValueType> = [like, like, limit];
    try {
      const rs2: relationalStore.ResultSet = await store.querySql(sql2, args2);
      try {
        while (rs2.goToNextRow()) {
          const url: string = rs2.getString(rs2.getColumnIndex('url'));
          const title: string = rs2.getString(rs2.getColumnIndex('title'));
          out.push(new HotSearchHit(url, title, url, '', '缓存正文', '', 'article'));
        }
      } finally {
        rs2.close();
      }
    } catch (e) {
    }
    return out;
  }

  // ==================== 统计 ====================

  static async stats(): Promise<HotStats> {
    const stats: HotStats = {
      favoriteCount: await DatabaseHelper.countHotFavorites(),
      readCount: await DatabaseHelper.countHotRead(),
      aiCallCount: await DatabaseHelper.countHotAiCalls()
    };
    return stats;
  }

  // ==================== 内部：全文索引 ====================

  private static async indexItem(kind: string, key: string, title: string, body: string): Promise<void> {
    if (!DatabaseHelper.isHotFtsReady()) return;
    try {
      const store: relationalStore.RdbStore = DatabaseHelper.getStore();
      const args: Array<relationalStore.ValueType> = [kind, key, title, body];
      await store.executeSql(SQL_HOT_FTS_INSERT, args);
    } catch (e) {
    }
  }

  private static async unindexItem(kind: string, key: string): Promise<void> {
    if (!DatabaseHelper.isHotFtsReady()) return;
    try {
      const store: relationalStore.RdbStore = DatabaseHelper.getStore();
      const args: Array<relationalStore.ValueType> = [kind, key];
      await store.executeSql(SQL_HOT_FTS_DELETE, args);
    } catch (e) {
    }
  }

  private static async clearFtsKind(kind: string): Promise<void> {
    if (!DatabaseHelper.isHotFtsReady()) return;
    try {
      const store: relationalStore.RdbStore = DatabaseHelper.getStore();
      const args: Array<relationalStore.ValueType> = [kind];
      await store.executeSql(SQL_HOT_FTS_DELETE_KIND, args);
    } catch (e) {
    }
  }

  // FTS 命中的 key 列表（不可用/查询过短/无命中 → 空数组，调用方回退 LIKE）
  private static async ftsKeys(kind: string, q: string, limit: number): Promise<string[]> {
    const keys: string[] = [];
    if (!DatabaseHelper.isHotFtsReady() || q.length < 3) return keys;
    try {
      const store: relationalStore.RdbStore = DatabaseHelper.getStore();
      const sql: string = 'SELECT key FROM hot_articles_fts WHERE kind = ? AND hot_articles_fts MATCH ? LIMIT ?';
      const args: Array<relationalStore.ValueType> = [kind, NewsRepository.ftsPhrase(q), limit];
      const rs: relationalStore.ResultSet = await store.querySql(sql, args);
      try {
        while (rs.goToNextRow()) {
          keys.push(rs.getString(rs.getColumnIndex('key')));
        }
      } finally {
        rs.close();
      }
    } catch (e) {
    }
    return keys;
  }

  private static favToHit(r: HotFavoriteEntry): HotSearchHit {
    return new HotSearchHit(r.key, r.title, r.url, r.sourceId, r.sourceName, r.info, 'fav');
  }

  // `sourceId:itemId` → itemId
  private static itemIdOf(key: string): string {
    const idx: number = key.indexOf(':');
    return idx < 0 ? key : key.substring(idx + 1);
  }

  // FTS 查询串转义（trigram 分词下直接使用子串；去掉会破坏语法的字符）
  private static ftsPhrase(q: string): string {
    return q.replace(/["'*()]/g, ' ').trim();
  }
}

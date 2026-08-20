// 智子 - 新闻偏好画像服务（v0.7 / M2）
// 赞/踩权重累积：点赞 → posTags 全部标签 +1；点踩勾选 → negTags 所选标签 +1
// 权重带时间衰减（半衰期约一周），撤销动作回退对应权重
import { DatabaseHelper } from './DatabaseHelper';
import { NewsItem } from '../common/NewsModels';

// 画像快照（news_profile 表 value_json）
export interface NewsProfileSnapshot {
  posTags: Record<string, number>;
  negTags: Record<string, number>;
  categoryWeights: Record<string, number>;
  sourceWeights: Record<string, number>;
  updatedAt: number;
}

const PROFILE_KEY: string = 'main';
const DECAY_PER_DAY: number = 0.9;

// 空画像
export function emptyProfile(): NewsProfileSnapshot {
  return {
    posTags: {},
    negTags: {},
    categoryWeights: {},
    sourceWeights: {},
    updatedAt: Date.now()
  };
}

export class NewsProfileService {
  // ==================== 读取 ====================

  static async getProfile(): Promise<NewsProfileSnapshot> {
    try {
      const raw: string | null = await DatabaseHelper.getNewsProfile();
      if (raw === null || raw.trim().length === 0) return emptyProfile();
      const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const p: NewsProfileSnapshot = emptyProfile();
      p.posTags = NewsProfileService.toNumMap(obj['posTags']);
      p.negTags = NewsProfileService.toNumMap(obj['negTags']);
      p.categoryWeights = NewsProfileService.toNumMap(obj['categoryWeights']);
      p.sourceWeights = NewsProfileService.toNumMap(obj['sourceWeights']);
      p.updatedAt = typeof obj['updatedAt'] === 'number' ? obj['updatedAt'] as number : Date.now();
      return p;
    } catch (e) {
      return emptyProfile();
    }
  }

  private static toNumMap(value: Object | undefined): Record<string, number> {
    const out: Record<string, number> = {};
    if (value === undefined || typeof value !== 'object') return out;
    const rec: Record<string, Object> = value as Record<string, Object>;
    const keys: string[] = Object.keys(rec);
    for (let i: number = 0; i < keys.length; i++) {
      const k: string = keys[i];
      const v: Object | undefined = rec[k];
      if (typeof v === 'number') out[k] = v as number;
    }
    return out;
  }

  // ==================== 写入（累积 / 回退） ====================

  // kind: 1=点赞桶 / -1=点踩桶；delta: +1 累积 / -1 回退
  static applyDelta(p: NewsProfileSnapshot, item: NewsItem, kind: number, delta: number, tags: string[]): void {
    const bucket: Record<string, number> = kind > 0 ? p.posTags : p.negTags;
    for (let i: number = 0; i < tags.length; i++) {
      const tag: string = tags[i];
      const next: number = (bucket[tag] === undefined ? 0 : bucket[tag]) + delta;
      bucket[tag] = next < 0 ? 0 : next;
    }
    const catNext: number = (p.categoryWeights[item.category] === undefined ? 0 : p.categoryWeights[item.category]) + delta * 0.2;
    p.categoryWeights[item.category] = catNext < 0 ? 0 : catNext;
    const srcNext: number = (p.sourceWeights[item.sourceId] === undefined ? 0 : p.sourceWeights[item.sourceId]) + delta * 0.1;
    p.sourceWeights[item.sourceId] = srcNext < 0 ? 0 : srcNext;
  }

  // 赞/踩事件 → 画像（点赞 kind=1，点踩 kind=-1，delta=+1）
  static async applyFeedback(item: NewsItem, rating: number, tags: string[]): Promise<void> {
    const p: NewsProfileSnapshot = await NewsProfileService.getProfile();
    NewsProfileService.applyDelta(p, item, rating, rating > 0 ? 1 : -1, tags);
    await NewsProfileService.save(p);
  }

  // 撤销（取消赞/撤销踩）：读取原 rating 状态后反向回退并删除
  static async revertRating(url: string): Promise<void> {
    const r = await DatabaseHelper.getNewsRating(url);
    if (r === null) return;
    const p: NewsProfileSnapshot = await NewsProfileService.getProfile();
    const item: NewsItem = new NewsItem('like:' + url, r.title, r.summary, r.url, r.imageUrl,
      'favorite', r.sourceName, r.category, r.publishedAt, r.tags, 'zh');
    NewsProfileService.applyDelta(p, item, r.rating, -1, r.tags);
    await NewsProfileService.save(p);
    await DatabaseHelper.deleteNewsRating(url);
  }

  // 移除某个厌恶标签（反馈管理）
  static async removeNegTag(tag: string): Promise<void> {
    const p: NewsProfileSnapshot = await NewsProfileService.getProfile();
    if (p.negTags[tag] !== undefined) p.negTags[tag] = 0;
    await NewsProfileService.save(p);
  }

  // 重置画像
  static async reset(): Promise<void> {
    await DatabaseHelper.clearNewsProfile();
  }

  // ==================== 衰减与保存 ====================

  // 时间衰减：权重 × 0.9^(天数/7)（半衰期约一周）
  static decayWeights(p: NewsProfileSnapshot, now: number): void {
    const days: number = Math.max(0, (now - p.updatedAt) / 86400000);
    const factor: number = Math.pow(DECAY_PER_DAY, days / 7);
    NewsProfileService.decayMap(p.posTags, factor);
    NewsProfileService.decayMap(p.negTags, factor);
    NewsProfileService.decayMap(p.categoryWeights, factor);
    NewsProfileService.decayMap(p.sourceWeights, factor);
  }

  private static decayMap(m: Record<string, number>, factor: number): void {
    const keys: string[] = Object.keys(m);
    for (let i: number = 0; i < keys.length; i++) {
      const k: string = keys[i];
      const v: number = m[k] * factor;
      m[k] = v < 0.05 ? 0 : v;
    }
  }

  private static async save(p: NewsProfileSnapshot): Promise<void> {
    const now: number = Date.now();
    NewsProfileService.decayWeights(p, now);
    p.updatedAt = now;
    await DatabaseHelper.saveNewsProfile(JSON.stringify(p));
  }
}

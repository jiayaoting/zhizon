// 智子 - 新闻排序器（v0.8 / M2+）
// 打分：正标签加分 − 负标签压缩扣分 + 频道/来源亲和 + 新鲜度 + 探索分 − 单篇软降权
// 个性化模式：standard / aggressive（高个性化）/ explore（探索）/ hot（仅热点，不走本排序）
// 混排：同标签每屏占比上限 + 同源连续上限（多样性，防霸屏）
import { NewsItem } from '../common/NewsModels';
import { NewsProfileService, NewsProfileSnapshot } from './NewsProfileService';

interface ScoredItem {
  item: NewsItem;
  score: number;
}

// 排序参数（按模式切换）
export interface RankParams {
  alpha: number;   // 正标签系数
  beta: number;    // 负标签系数
  gamma: number;   // 频道亲和系数
  delta: number;   // 来源亲和系数
  epsilon: number; // 新鲜度系数
  zeta: number;    // 探索系数
  eta: number;     // 单篇软降权（点踩未勾选标签）
}

export class NewsRanker {
  // ==================== 参数参考值（集中可调） ====================
  static readonly NEG_CAP: number = 8;           // 负权重压缩上限
  static readonly TAG_SCREEN_CAP: number = 0.4;  // 同标签每屏占比上限
  static readonly SAME_SOURCE_MAX: number = 3;   // 同源连续条数上限
  static readonly FRESH_WINDOW_MS: number = 7 * 24 * 3600 * 1000; // 新鲜度窗口 7 天

  // 标准模式参数
  static standardParams(): RankParams {
    return { alpha: 1.0, beta: 2.0, gamma: 0.5, delta: 0.3, epsilon: 0.8, zeta: 0.3, eta: 1.5 } as RankParams;
  }

  // 按个性化模式取参数（hot 模式不进本排序，由调用方处理）
  static paramsForMode(mode: string): RankParams {
    if (mode === 'aggressive') {
      // 高个性化：反馈权重 ×1.5，探索率降低
      return { alpha: 1.5, beta: 3.0, gamma: 0.6, delta: 0.4, epsilon: 0.8, zeta: 0.15, eta: 1.5 } as RankParams;
    }
    if (mode === 'explore') {
      // 探索：正负权重略降，探索分提升，单篇降权减轻
      return { alpha: 0.8, beta: 1.6, gamma: 0.4, delta: 0.3, epsilon: 0.8, zeta: 0.6, eta: 1.2 } as RankParams;
    }
    return NewsRanker.standardParams();
  }

  // 负权重压缩曲线：次数越多扣分越多但渐近平缓（非永久拉黑）
  static fNeg(x: number): number {
    const capped: number = x < 0 ? 0 : (x > NewsRanker.NEG_CAP ? NewsRanker.NEG_CAP : x);
    return Math.log(1 + capped);
  }

  // 稳定哈希（探索分用，保证同一条目分数稳定）
  static stableHash(input: string): number {
    let hash: number = 0;
    for (let i: number = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.charCodeAt(i)) | 0;
    }
    return Math.abs(hash);
  }

  // 标准模式打分（兼容旧调用/单测）
  static score(item: NewsItem, profile: NewsProfileSnapshot, now: number): number {
    return NewsRanker.scoreWith(item, profile, now, NewsRanker.standardParams(), []);
  }

  // 完整打分（纯函数，可单测）
  static scoreWith(item: NewsItem, profile: NewsProfileSnapshot, now: number,
    params: RankParams, excludedUrls: string[]): number {
    let pos: number = 0;
    let neg: number = 0;
    for (let i: number = 0; i < item.tags.length; i++) {
      const tag: string = item.tags[i];
      const pw: number = profile.posTags[tag] === undefined ? 0 : Math.max(0, profile.posTags[tag]);
      const nw: number = profile.negTags[tag] === undefined ? 0 : Math.max(0, profile.negTags[tag]);
      pos += pw;
      neg += NewsRanker.fNeg(nw);
    }
    const cat: number = profile.categoryWeights[item.category] === undefined ? 0 : profile.categoryWeights[item.category];
    const src: number = profile.sourceWeights[item.sourceId] === undefined ? 0 : profile.sourceWeights[item.sourceId];
    const age: number = Math.max(0, now - item.publishedAt);
    const fresh: number = Math.max(0, 1 - age / NewsRanker.FRESH_WINDOW_MS);
    const explore: number = (NewsRanker.stableHash(item.url) % 1000) / 1000 * params.zeta;
    const penalty: number = excludedUrls.indexOf(item.url) >= 0 ? params.eta : 0;
    return params.alpha * pos - params.beta * neg +
      params.gamma * cat + params.delta * src +
      params.epsilon * fresh + explore - penalty;
  }

  // 多样性混排：同标签占比 + 同源连续限制（纯函数，可单测）
  static applyDiversity(sorted: NewsItem[], limit: number): NewsItem[] {
    const out: NewsItem[] = [];
    const tagCount: Record<string, number> = {};
    const tagCap: number = Math.max(1, Math.ceil(limit * NewsRanker.TAG_SCREEN_CAP));
    let sameSourceRun: number = 0;
    let lastSource: string = '';
    for (let i: number = 0; i < sorted.length && out.length < limit; i++) {
      const item: NewsItem = sorted[i];
      // 同标签占比限制
      let overTag: boolean = false;
      for (let t: number = 0; t < item.tags.length; t++) {
        const tag: string = item.tags[t];
        if ((tagCount[tag] === undefined ? 0 : tagCount[tag]) >= tagCap) {
          overTag = true;
          break;
        }
      }
      if (overTag) continue;
      // 同源连续限制
      if (item.sourceId === lastSource) {
        sameSourceRun++;
        if (sameSourceRun >= NewsRanker.SAME_SOURCE_MAX) continue;
      } else {
        sameSourceRun = 1;
        lastSource = item.sourceId;
      }
      out.push(item);
      for (let t: number = 0; t < item.tags.length; t++) {
        const tag: string = item.tags[t];
        tagCount[tag] = (tagCount[tag] === undefined ? 0 : tagCount[tag]) + 1;
      }
    }
    return out;
  }

  // 个性化排序入口（按模式参数；excludedUrls 走软降权）
  static async rank(items: NewsItem[], limit: number, mode: string = 'standard',
    excludedUrls: string[] = []): Promise<NewsItem[]> {
    if (items.length === 0) return items;
    const profile: NewsProfileSnapshot = await NewsProfileService.getProfile();
    const now: number = Date.now();
    const params: RankParams = NewsRanker.paramsForMode(mode);
    const scored: ScoredItem[] = [];
    for (let i: number = 0; i < items.length; i++) {
      scored.push({
        item: items[i],
        score: NewsRanker.scoreWith(items[i], profile, now, params, excludedUrls)
      } as ScoredItem);
    }
    scored.sort((a: ScoredItem, b: ScoredItem) => b.score - a.score);
    const sorted: NewsItem[] = [];
    for (let i: number = 0; i < scored.length; i++) {
      sorted.push(scored[i].item);
    }
    return NewsRanker.applyDiversity(sorted, limit);
  }
}

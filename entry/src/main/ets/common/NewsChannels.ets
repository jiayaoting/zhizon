// 智子 - 新闻频道与内置源注册表（仿 Difficulty.ets 注册表模式）
import { NewsChannel, NewsSourceDef } from './NewsModels';

// 频道列表（推荐 = 全源合并；ai = 关键词派生频道）
export const NEWS_CHANNELS: NewsChannel[] = [
  new NewsChannel('recommend', '推荐', '🔥'),
  new NewsChannel('tech', '科技', '💻'),
  new NewsChannel('ai', 'AI专题', '🤖'),
  new NewsChannel('finance', '财经', '📈'),
  new NewsChannel('world', '国际', '🌍')
];

// 内置源（Layer 0：免费、免 key，开箱即用）
export const NEWS_SOURCES: NewsSourceDef[] = [
  new NewsSourceDef('zhihu', '知乎日报', 'recommend', 'zhihu', 'https://news-at.zhihu.com/api/4/news/latest'),
  new NewsSourceDef('hn', 'Hacker News', 'tech', 'hn', 'https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30'),
  new NewsSourceDef('sspai', '少数派', 'tech', 'rss', 'https://sspai.com/feed'),
  new NewsSourceDef('ithome', 'IT之家', 'tech', 'rss', 'https://www.ithome.com/rss/'),
  new NewsSourceDef('kr36', '36氪', 'finance', 'rss', 'https://36kr.com/feed'),
  new NewsSourceDef('bbc', 'BBC中文', 'world', 'rss', 'https://feeds.bbci.co.uk/zhongwen/simp/rss.xml')
];

// AI 专题派生频道关键词（标题/摘要命中任一即归类）
export const AI_KEYWORDS: string[] = [
  'AI', '人工智能', '大模型', 'LLM', 'GPT', 'OpenAI', 'DeepSeek', '通义', 'Kimi',
  '智谱', '文心', '豆包', '机器学习', '深度学习', '神经网络', 'Agent', '智能体',
  'NVIDIA', '英伟达', '芯片', '算力', 'AIGC'
];

// 频道查找
export function channelById(id: string): NewsChannel | null {
  for (let i: number = 0; i < NEWS_CHANNELS.length; i++) {
    if (NEWS_CHANNELS[i].id === id) return NEWS_CHANNELS[i];
  }
  return null;
}

// 源查找
export function sourceById(id: string): NewsSourceDef | null {
  for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
    if (NEWS_SOURCES[i].id === id) return NEWS_SOURCES[i];
  }
  return null;
}

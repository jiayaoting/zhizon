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
// 注意：标注「需实测」的源在上线前请在真机验证可用性；任一源失败自动降级，不影响其他源
export const NEWS_SOURCES: NewsSourceDef[] = [
  new NewsSourceDef('zhihu', '知乎日报', 'recommend', 'zhihu', 'https://news-at.zhihu.com/api/4/news/latest'),
  new NewsSourceDef('hn', 'Hacker News', 'tech', 'hn', 'https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30'),
  new NewsSourceDef('sspai', '少数派', 'tech', 'rss', 'https://sspai.com/feed'),
  new NewsSourceDef('ithome', 'IT之家', 'tech', 'rss', 'https://www.ithome.com/rss/'),
  new NewsSourceDef('kr36', '36氪', 'finance', 'rss', 'https://36kr.com/feed'),
  new NewsSourceDef('bbc', 'BBC中文', 'world', 'rss', 'https://feeds.bbci.co.uk/zhongwen/simp/rss.xml'),
  // ===== 新增（2026-08 推荐清单） =====
  // 综合/中文
  new NewsSourceDef('chinanews', '中国新闻网', 'recommend', 'rss', 'https://www.chinanews.com.cn/rss/scroll-news.xml'),
  new NewsSourceDef('gnews', '谷歌新闻·科技', 'recommend', 'rss', 'https://news.google.com/rss/search?q=%E7%A7%91%E6%8A%80&hl=zh-CN&gl=CN&ceid=CN:zh-Hans'),
  new NewsSourceDef('zaobao', '联合早报', 'recommend', 'rss', 'https://www.zaobao.com.sg/rss/'),
  // 科技（中文）
  new NewsSourceDef('ifanr', '爱范儿', 'tech', 'rss', 'https://www.ifanr.com/feed'),
  new NewsSourceDef('huxiu', '虎嗅', 'tech', 'rss', 'https://www.huxiu.com/rss/0.xml'),
  new NewsSourceDef('geekpark', '极客公园', 'tech', 'rss', 'https://www.geekpark.net/rss'),
  new NewsSourceDef('pingwest', '品玩', 'tech', 'rss', 'https://www.pingwest.com/feed'),
  // 科技（英文）
  new NewsSourceDef('techcrunch', 'TechCrunch', 'tech', 'rss', 'https://techcrunch.com/feed/'),
  new NewsSourceDef('verge', 'The Verge', 'tech', 'rss', 'https://www.theverge.com/rss/index.xml'),
  new NewsSourceDef('arstechnica', 'Ars Technica', 'tech', 'rss', 'https://arstechnica.com/feed/'),
  // AI 专项（关键词派生频道会自动纳入「AI专题」）
  new NewsSourceDef('jiqizhixin', '机器之心', 'tech', 'rss', 'https://www.jiqizhixin.com/rss'),
  new NewsSourceDef('qbitai', '量子位', 'tech', 'rss', 'https://www.qbitai.com/feed'),
  new NewsSourceDef('openai', 'OpenAI 博客', 'tech', 'rss', 'https://openai.com/blog/rss.xml'),
  new NewsSourceDef('deepmind', 'DeepMind 博客', 'tech', 'rss', 'https://deepmind.google/blog/rss.xml'),
  // 财经
  new NewsSourceDef('nikkei', '日经中文网', 'finance', 'rss', 'https://cn.nikkei.com/rss/'),
  new NewsSourceDef('yahoo', 'Yahoo Finance', 'finance', 'rss', 'https://finance.yahoo.com/news/rssindex'),
  new NewsSourceDef('ftchinese', 'FT中文网', 'finance', 'rss', 'https://www.ftchinese.com/rss/news'),
  // 国际
  new NewsSourceDef('bbcworld', 'BBC World', 'world', 'rss', 'https://feeds.bbci.co.uk/news/world/rss.xml'),
  new NewsSourceDef('guardian', 'The Guardian', 'world', 'rss', 'https://www.theguardian.com/world/rss'),
  new NewsSourceDef('aljazeera', 'Al Jazeera', 'world', 'rss', 'https://www.aljazeera.com/xml/rss/all.xml'),
  new NewsSourceDef('nhk', 'NHK World', 'world', 'rss', 'https://www3.nhk.or.jp/rss/news/cat0.xml'),
  new NewsSourceDef('dwzh', '德国之声中文', 'world', 'rss', 'https://rss.dw.com/rdf/rss-chi-all')
];

// 预置标签词典：标签 → 命中关键词（标题/摘要包含任一即打该标签；L1 规则标签）
export const TAG_KEYWORDS: Record<string, string[]> = {
  'AI': ['AI', '人工智能', '大模型', 'LLM', 'GPT', 'OpenAI', 'DeepSeek', '通义', 'Kimi', '智谱',
    '文心', '豆包', '机器学习', '深度学习', '神经网络', 'Agent', '智能体', 'AIGC', '生成式'],
  '芯片': ['芯片', '半导体', '英伟达', 'NVIDIA', 'ASML', '台积电', '晶圆', '制程', '光刻'],
  '算力': ['算力', 'GPU', '数据中心', '服务器', '云计算', '超算'],
  '手机': ['手机', 'iPhone', '华为', '小米', 'OPPO', 'vivo', '荣耀', '折叠屏', '旗舰'],
  '汽车': ['汽车', '新能源车', '电动车', '特斯拉', '比亚迪', '蔚来', '小鹏', '理想', '自动驾驶', '智驾'],
  '财经': ['股价', '股市', '财报', '融资', 'IPO', '上市', '市值', '营收', '利润', '利率', '通胀', '基金'],
  '国际': ['美国', '欧洲', '日本', '韩国', '联合国', '北约', '欧盟', '中东', '俄罗斯', '乌克兰', '外交'],
  '航天': ['航天', '火箭', '卫星', 'SpaceX', 'NASA', '嫦娥', '空间站', '登月'],
  '生物医药': ['医药', '疫苗', '基因', '创新药', '临床试验', '医疗'],
  '游戏': ['游戏', '主机', 'Steam', 'PlayStation', 'Xbox', '任天堂', '电竞'],
  '消费': ['电商', '零售', '消费', '618', '双11', '直播间'],
  '体育': ['足球', '篮球', 'NBA', '英超', '西甲', '世界杯', '奥运', 'C罗', '梅西', '电竞'],
  '娱乐': ['电影', '电视剧', '综艺', '明星', '八卦', '票房', '音乐', '演唱会', '奥斯卡'],
  '健康': ['健康', '医疗', '疾病', '养生', '营养', '心理健康', '医保'],
  '能源': ['能源', '石油', '天然气', '光伏', '风电', '电池', '锂电', '储能'],
  '教育': ['教育', '高考', '大学', '考研', '留学', '学校'],
  '数码': ['数码', '笔记本', '平板', '耳机', '相机', '智能家居', '显示器']
};

// 内置源默认语言（其余走字符检测）
export const SOURCE_LANGUAGES: Record<string, string> = {
  'zhihu': 'zh',
  'hn': 'en',
  'sspai': 'zh',
  'ithome': 'zh',
  'kr36': 'zh',
  'bbc': 'zh',
  'chinanews': 'zh',
  'gnews': 'zh',
  'zaobao': 'zh',
  'ifanr': 'zh',
  'huxiu': 'zh',
  'geekpark': 'zh',
  'pingwest': 'zh',
  'techcrunch': 'en',
  'verge': 'en',
  'arstechnica': 'en',
  'jiqizhixin': 'zh',
  'qbitai': 'zh',
  'openai': 'en',
  'deepmind': 'en',
  'nikkei': 'zh',
  'yahoo': 'en',
  'ftchinese': 'zh',
  'bbcworld': 'en',
  'guardian': 'en',
  'aljazeera': 'en',
  'nhk': 'en',
  'dwzh': 'zh'
};

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

// 智子 - 新闻资讯数据模型
// 所有新闻源统一归一化为 NewsItem；频道与源见 NewsChannels.ets

// 统一新闻条目（源无关）
export class NewsItem {
  id: string;          // 源内唯一 id（如 zhihu:123 / hn:456 / rss:md5(url)）
  title: string;
  summary: string;     // 源自带摘要/描述/元信息，可为空
  url: string;         // 原文链接
  imageUrl: string;    // 头图（可为空 → 纯文本卡）
  sourceId: string;    // 所属源 id
  sourceName: string;  // 展示名（知乎日报 / Hacker News / 少数派 …）
  category: string;    // 频道 id（recommend/tech/ai/finance/world）
  publishedAt: number; // 时间戳（毫秒）
  tags: string[];      // 内容标签（L1 规则生成，3~8 个；点踩面板可多选）
  language: string;    // 语言：zh / en / other（外文翻译用）

  constructor(id: string, title: string, summary: string, url: string, imageUrl: string,
    sourceId: string, sourceName: string, category: string, publishedAt: number,
    tags: string[] = [], language: string = 'zh') {
    this.id = id;
    this.title = title;
    this.summary = summary;
    this.url = url;
    this.imageUrl = imageUrl;
    this.sourceId = sourceId;
    this.sourceName = sourceName;
    this.category = category;
    this.publishedAt = publishedAt;
    this.tags = tags;
    this.language = language;
  }
}

// 赞/踩状态（news_ratings 行；rating: 1=赞 / -1=踩 / 0=取消）
export class NewsRating {
  url: string;
  rating: number;
  title: string;
  summary: string;
  imageUrl: string;
  sourceName: string;
  category: string;
  publishedAt: number;
  tags: string[];      // 点赞=该篇全部标签；点踩=用户勾选的标签（可为空）
  updatedAt: number;

  constructor(url: string, rating: number, title: string, summary: string, imageUrl: string,
    sourceName: string, category: string, publishedAt: number, tags: string[], updatedAt: number) {
    this.url = url;
    this.rating = rating;
    this.title = title;
    this.summary = summary;
    this.imageUrl = imageUrl;
    this.sourceName = sourceName;
    this.category = category;
    this.publishedAt = publishedAt;
    this.tags = tags;
    this.updatedAt = updatedAt;
  }
}

// 频道（频道 Tabs 展示）
export class NewsChannel {
  id: string;
  name: string;
  icon: string;

  constructor(id: string, name: string, icon: string) {
    this.id = id;
    this.name = name;
    this.icon = icon;
  }
}

// 新闻源定义（注册表条目）
export class NewsSourceDef {
  id: string;
  name: string;
  category: string;   // 所属频道 id
  type: string;       // zhihu / hn / rss
  url: string;        // 接口或 RSS 地址

  constructor(id: string, name: string, category: string, type: string, url: string) {
    this.id = id;
    this.name = name;
    this.category = category;
    this.type = type;
    this.url = url;
  }
}

// AI 今日要闻缓存条目
export class NewsDigestEntry {
  id: string;
  date: string;       // yyyyMMdd
  content: string;    // 简报 Markdown 文本
  modelName: string;  // 生成所用模型显示名
  createdAt: number;

  constructor(id: string, date: string, content: string, modelName: string, createdAt: number) {
    this.id = id;
    this.date = date;
    this.content = content;
    this.modelName = modelName;
    this.createdAt = createdAt;
  }
}

// 详情页路由参数（避免跨路由传递复杂对象）
export class NewsDetailRouteParams {
  itemId: string;
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

  constructor(item: NewsItem) {
    this.itemId = item.id;
    this.title = item.title;
    this.summary = item.summary;
    this.url = item.url;
    this.imageUrl = item.imageUrl;
    this.sourceId = item.sourceId;
    this.sourceName = item.sourceName;
    this.category = item.category;
    this.publishedAt = item.publishedAt;
    this.tags = item.tags === undefined ? [] : item.tags;
    this.language = item.language === undefined ? 'zh' : item.language;
  }

  toItem(): NewsItem {
    return new NewsItem(this.itemId, this.title, this.summary, this.url, this.imageUrl,
      this.sourceId, this.sourceName, this.category, this.publishedAt,
      this.tags === undefined ? [] : this.tags, this.language);
  }
}

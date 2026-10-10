// 智子 - 热榜数据模型（对齐 NewsNow 服务端 SourceResponse / NewsItem）
// 设计文档：doc/newsnow-redesign.md §4

// 单条热榜条目
export class HotItem {
  id: string;          // 源内唯一 id（服务端原始 id 转字符串）
  title: string;
  url: string;
  mobileUrl: string;   // 移动端链接，缺省 = url
  pubDate: number;     // 毫秒时间戳；0 = 源未提供
  info: string;        // 热度/评论数等描述文本（extra.info），可为 ''

  constructor(id: string, title: string, url: string, mobileUrl: string,
    pubDate: number, info: string) {
    this.id = id;
    this.title = title;
    this.url = url;
    this.mobileUrl = mobileUrl;
    this.pubDate = pubDate;
    this.info = info;
  }
}

// 一个源的一次榜单响应
export class HotBoardData {
  sourceId: string;
  fromCache: boolean;    // status === 'cache'
  updatedTime: number;
  items: HotItem[];

  constructor(sourceId: string, fromCache: boolean, updatedTime: number, items: HotItem[]) {
    this.sourceId = sourceId;
    this.fromCache = fromCache;
    this.updatedTime = updatedTime;
    this.items = items;
  }
}

// 渲染用组合条目（全局唯一键 + 源上下文）
export class HotEntry {
  key: string;          // `${sourceId}:${item.id}`，已读/收藏主键
  item: HotItem;
  sourceId: string;
  sourceName: string;

  constructor(key: string, item: HotItem, sourceId: string, sourceName: string) {
    this.key = key;
    this.item = item;
    this.sourceId = sourceId;
    this.sourceName = sourceName;
  }
}

// 视图（一级 Tab）
export enum HotViewKey {
  Focus = 'focus',
  Hottest = 'hottest',
  Realtime = 'realtime',
  China = 'china',
  Tech = 'tech',
  Finance = 'finance',
  World = 'world',
  Sports = 'sports'
}

// 视图定义
export class HotViewDef {
  key: HotViewKey;
  name: string;
  icon: string;

  constructor(key: HotViewKey, name: string, icon: string) {
    this.key = key;
    this.name = name;
    this.icon = icon;
  }
}

export const HOT_VIEWS: HotViewDef[] = [
  new HotViewDef(HotViewKey.Focus, '关注', '⭐'),
  new HotViewDef(HotViewKey.Hottest, '最热', '🔥'),
  new HotViewDef(HotViewKey.Realtime, '实时', '⚡'),
  new HotViewDef(HotViewKey.China, '国内', '🇨🇳'),
  new HotViewDef(HotViewKey.Tech, '科技', '💻'),
  new HotViewDef(HotViewKey.Finance, '财经', '📈'),
  new HotViewDef(HotViewKey.World, '国际', '🌍'),
  new HotViewDef(HotViewKey.Sports, '体育', '⚽')
];

// AI 今日要闻缓存条目
export class HotDigestEntry {
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

// 关注同步负载（本地模型；网络层负责补全 hottest/realtime/updated）
export class FocusMetadata {
  focusSources: string[];
  updatedTime: number;   // 本地最后变更时间；初始 0

  constructor(focusSources: string[], updatedTime: number) {
    this.focusSources = focusSources;
    this.updatedTime = updatedTime;
  }
}

// 登录用户资料
export class NewsNowUser {
  id: string;        // GitHub 数字 id 字符串
  name: string;
  avatar: string;

  constructor(id: string, name: string, avatar: string) {
    this.id = id;
    this.name = name;
    this.avatar = avatar;
  }
}

// 详情页路由参数
export class HotDetailRouteParams {
  key: string;
  sourceId: string;
  sourceName: string;
  title: string;
  url: string;
  info: string;

  constructor(key: string, sourceId: string, sourceName: string,
    title: string, url: string, info: string) {
    this.key = key;
    this.sourceId = sourceId;
    this.sourceName = sourceName;
    this.title = title;
    this.url = url;
    this.info = info;
  }
}

// 单源榜单页路由参数
export class HotBoardRouteParams {
  sourceId: string;
  sourceName: string;

  constructor(sourceId: string, sourceName: string) {
    this.sourceId = sourceId;
    this.sourceName = sourceName;
  }
}

// 热榜错误
export class HotNowError {
  code: string;       // 'network' | 'http' | 'server' | 'unauthorized' | 'not_configured'
  httpStatus: number;
  message: string;

  constructor(code: string, httpStatus: number, message: string) {
    this.code = code;
    this.httpStatus = httpStatus;
    this.message = message;
  }
}

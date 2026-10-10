// 智子 - 热榜源目录（对齐 NewsNow shared/pre-sources.ts，随 App 版本更新）
// 设计文档：doc/newsnow-redesign.md §2.4 / §5
import { HotViewKey } from './HotModels';

// 源定义：id 与 NewsNow 服务端 sourceId 完全一致
export class HotSourceDef {
  id: string;
  name: string;        // 站点名（微博 / 知乎）
  title: string;       // 子榜名（实时热搜 / 热门视频），可为 ''
  type: string;        // 'hottest' | 'realtime' | ''（时间流）
  column: string;      // china | world | tech | finance | sports
  color: string;       // NewsNow 配色名（UnoCSS 色板）
  home: string;        // 源站首页
  disabled: boolean;   // NewsNow 标记为 disable（true / cf），默认视图不展示

  constructor(id: string, name: string, title: string, type: string,
    column: string, color: string, home: string, disabled: boolean) {
    this.id = id;
    this.name = name;
    this.title = title;
    this.type = type;
    this.column = column;
    this.color = color;
    this.home = home;
    this.disabled = disabled;
  }

  // 展示名：站点名 + 子榜名
  displayName(): string {
    return this.title.length > 0 ? this.name + '·' + this.title : this.name;
  }
}

// 全量源目录（父源与其子源均为合法 API id）
export const HOT_SOURCES: HotSourceDef[] = [
  new HotSourceDef('v2ex', 'V2EX', '最新分享', '', 'tech', 'slate', 'https://v2ex.com/', false),
  new HotSourceDef('zhihu', '知乎', '', 'hottest', 'china', 'blue', 'https://www.zhihu.com', false),
  new HotSourceDef('weibo', '微博', '实时热搜', 'hottest', 'china', 'red', 'https://weibo.com', false),
  new HotSourceDef('zaobao', '联合早报', '', 'realtime', 'world', 'red', 'https://www.zaobao.com', false),
  new HotSourceDef('coolapk', '酷安', '今日最热', 'hottest', 'tech', 'green', 'https://coolapk.com', false),
  new HotSourceDef('mktnews', 'MKTNews', '快讯', '', 'finance', 'indigo', 'https://mktnews.net', false),
  new HotSourceDef('wallstreetcn', '华尔街见闻', '快讯', 'realtime', 'finance', 'blue', 'https://wallstreetcn.com/', false),
  new HotSourceDef('36kr', '36氪', '快讯', 'realtime', 'tech', 'blue', 'https://36kr.com', false),
  new HotSourceDef('douyin', '抖音', '', 'hottest', 'china', 'gray', 'https://www.douyin.com', false),
  new HotSourceDef('hupu', '虎扑', '主干道热帖', 'hottest', 'sports', 'red', 'https://hupu.com', false),
  new HotSourceDef('dongqiudi', '懂球帝', '头条', 'realtime', 'sports', 'green', 'https://www.dongqiudi.com', false),
  new HotSourceDef('aihot', 'AIHOT', '', 'realtime', 'tech', 'blue', 'https://aihot.virxact.com/all', false),
  new HotSourceDef('tieba', '百度贴吧', '热议', 'hottest', 'china', 'blue', 'https://tieba.baidu.com', false),
  new HotSourceDef('toutiao', '今日头条', '', 'hottest', 'china', 'red', 'https://www.toutiao.com', false),
  new HotSourceDef('ithome', 'IT之家', '', 'realtime', 'tech', 'red', 'https://www.ithome.com', false),
  new HotSourceDef('thepaper', '澎湃新闻', '热榜', 'hottest', 'china', 'gray', 'https://www.thepaper.cn', false),
  new HotSourceDef('sputniknewscn', '卫星通讯社', '', '', 'world', 'orange', 'https://sputniknews.cn', false),
  new HotSourceDef('cankaoxiaoxi', '参考消息', '', '', 'world', 'red', 'https://china.cankaoxiaoxi.com', false),
  new HotSourceDef('pcbeta', '远景论坛', 'Win11', 'realtime', 'tech', 'blue', 'https://bbs.pcbeta.com', true),
  new HotSourceDef('cls', '财联社', '电报', 'realtime', 'finance', 'red', 'https://www.cls.cn', false),
  new HotSourceDef('xueqiu', '雪球', '热门股票', 'hottest', 'finance', 'blue', 'https://xueqiu.com', false),
  new HotSourceDef('gelonghui', '格隆汇', '事件', 'realtime', 'finance', 'blue', 'https://www.gelonghui.com', false),
  new HotSourceDef('fastbull', '法布财经', '快讯', 'realtime', 'finance', 'emerald', 'https://www.fastbull.cn', false),
  new HotSourceDef('solidot', 'Solidot', '', '', 'tech', 'teal', 'https://solidot.org', false),
  new HotSourceDef('hackernews', 'Hacker News', '', 'hottest', 'tech', 'orange', 'https://news.ycombinator.com/', false),
  new HotSourceDef('producthunt', 'Product Hunt', '', 'hottest', 'tech', 'red', 'https://www.producthunt.com/', false),
  new HotSourceDef('github', 'Github', 'Today', 'hottest', 'tech', 'gray', 'https://github.com/', false),
  new HotSourceDef('github-trending-today', 'Github', 'Today', 'hottest', 'tech', 'gray', 'https://github.com/', false),
  new HotSourceDef('bilibili', '哔哩哔哩', '热搜', 'hottest', 'china', 'blue', 'https://www.bilibili.com', true),
  new HotSourceDef('bilibili-hot-search', '哔哩哔哩', '热搜', 'hottest', 'china', 'blue', 'https://www.bilibili.com', true),
  new HotSourceDef('bilibili-hot-video', '哔哩哔哩', '热门视频', 'hottest', 'china', 'blue', 'https://www.bilibili.com', true),
  new HotSourceDef('bilibili-ranking', '哔哩哔哩', '排行榜', 'hottest', 'china', 'blue', 'https://www.bilibili.com', true),
  new HotSourceDef('kuaishou', '快手', '', 'hottest', 'china', 'orange', 'https://www.kuaishou.com', true),
  new HotSourceDef('kaopu', '靠谱新闻', '', '', 'world', 'gray', 'https://kaopu.news/', false),
  new HotSourceDef('jin10', '金十数据', '', 'realtime', 'finance', 'blue', 'https://www.jin10.com', false),
  new HotSourceDef('baidu', '百度热搜', '', 'hottest', 'china', 'blue', 'https://www.baidu.com', false),
  new HotSourceDef('linuxdo', 'LINUX DO', '最新', 'hottest', 'tech', 'slate', 'https://linux.do/', true),
  new HotSourceDef('ghxi', '果核剥壳', '', '', 'china', 'yellow', 'https://www.ghxi.com/', true),
  new HotSourceDef('smzdm', '什么值得买', '', 'hottest', 'china', 'red', 'https://www.smzdm.com', true),
  new HotSourceDef('nowcoder', '牛客', '', 'hottest', 'china', 'blue', 'https://www.nowcoder.com', false),
  new HotSourceDef('sspai', '少数派', '', 'hottest', 'tech', 'red', 'https://sspai.com', false),
  new HotSourceDef('juejin', '稀土掘金', '', 'hottest', 'tech', 'blue', 'https://juejin.cn', false),
  new HotSourceDef('ifeng', '凤凰网', '热点资讯', 'hottest', 'china', 'red', 'https://www.ifeng.com', false),
  new HotSourceDef('chongbuluo', '虫部落', '最新', 'hottest', 'china', 'green', 'https://www.chongbuluo.com', false),
  new HotSourceDef('douban', '豆瓣', '热门电影', 'hottest', 'china', 'green', 'https://www.douban.com', false),
  new HotSourceDef('steam', 'Steam', '在线人数', 'hottest', 'world', 'blue', 'https://store.steampowered.com', false),
  new HotSourceDef('tencent', '腾讯新闻', '综合早报', 'hottest', 'china', 'blue', 'https://news.qq.com', false),
  new HotSourceDef('freebuf', 'Freebuf', '网络安全', 'hottest', 'china', 'green', 'https://www.freebuf.com/', false),
  new HotSourceDef('qqvideo', '腾讯视频', '热搜榜', 'hottest', 'china', 'blue', 'https://v.qq.com/', false),
  new HotSourceDef('qqvideo-tv-hotsearch', '腾讯视频', '热搜榜', 'hottest', 'china', 'blue', 'https://v.qq.com/channel/tv', false),
  new HotSourceDef('iqiyi', '爱奇艺', '热播榜', 'hottest', 'china', 'green', 'https://www.iqiyi.com', false),
  new HotSourceDef('iqiyi-hot-ranklist', '爱奇艺', '热播榜', 'hottest', 'china', 'green', 'https://www.iqiyi.com', false)
];

// 源 id → 定义索引
function buildSourceIndex(): Map<string, HotSourceDef> {
  const m: Map<string, HotSourceDef> = new Map<string, HotSourceDef>();
  for (let i: number = 0; i < HOT_SOURCES.length; i++) {
    m.set(HOT_SOURCES[i].id, HOT_SOURCES[i]);
  }
  return m;
}

// NewsNow 配色名 → 十六进制（UnoCSS 色板）
function buildColorHex(): Map<string, string> {
  const m: Map<string, string> = new Map<string, string>();
  m.set('slate', '#64748B');
  m.set('gray', '#6B7280');
  m.set('red', '#EF4444');
  m.set('orange', '#F97316');
  m.set('yellow', '#EAB308');
  m.set('green', '#22C55E');
  m.set('emerald', '#10B981');
  m.set('teal', '#14B8A6');
  m.set('blue', '#3B82F6');
  m.set('indigo', '#6366F1');
  return m;
}

const SOURCE_INDEX: Map<string, HotSourceDef> = buildSourceIndex();
const COLOR_HEX: Map<string, string> = buildColorHex();

// 视图 → 列名（focus/hottest/realtime 无列名）
function viewToColumn(view: HotViewKey): string {
  if (view === HotViewKey.China) return 'china';
  if (view === HotViewKey.Tech) return 'tech';
  if (view === HotViewKey.Finance) return 'finance';
  if (view === HotViewKey.World) return 'world';
  if (view === HotViewKey.Sports) return 'sports';
  return '';
}

export class HotSources {
  static byId(id: string): HotSourceDef | null {
    const def: HotSourceDef | undefined = SOURCE_INDEX.get(id);
    return def === undefined ? null : def;
  }

  static nameOf(id: string): string {
    const def: HotSourceDef | null = HotSources.byId(id);
    return def === null ? id : def.displayName();
  }

  static colorOf(id: string): string {
    const def: HotSourceDef | null = HotSources.byId(id);
    if (def === null) return '#6B7280';
    const hex: string | undefined = COLOR_HEX.get(def.color);
    return hex === undefined ? '#6B7280' : hex;
  }

  // 视图内的源列表（focus 视图由调用方传入已关注 id）
  static sourceIdsForView(view: HotViewKey, focusIds: string[]): string[] {
    if (view === HotViewKey.Focus) {
      const out: string[] = [];
      for (let i: number = 0; i < focusIds.length; i++) {
        if (SOURCE_INDEX.has(focusIds[i])) out.push(focusIds[i]);
      }
      return out;
    }
    if (view === HotViewKey.Hottest) return HotSources.byType('hottest');
    if (view === HotViewKey.Realtime) return HotSources.byType('realtime');
    const column: string = viewToColumn(view);
    if (column.length === 0) return [];
    return HotSources.enabledByColumn(column);
  }

  static byType(type: string): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < HOT_SOURCES.length; i++) {
      const s: HotSourceDef = HOT_SOURCES[i];
      if (s.type === type && !s.disabled) out.push(s.id);
    }
    return out;
  }

  // 分类视图用：排除 NewsNow 标记为 disable（含 cf）的源
  static enabledByColumn(column: string): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < HOT_SOURCES.length; i++) {
      const s: HotSourceDef = HOT_SOURCES[i];
      if (s.column === column && !s.disabled) out.push(s.id);
    }
    return out;
  }

  // 设置页源选择器用：含 disabled 源（用户仍可手动关注）
  static byColumn(column: string): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < HOT_SOURCES.length; i++) {
      const s: HotSourceDef = HOT_SOURCES[i];
      if (s.column === column) out.push(s.id);
    }
    return out;
  }

  // 按分组列出全部源（设置页源选择器用；含 disabled）

  static groupLabel(column: string): string {
    if (column === 'china') return '国内';
    if (column === 'tech') return '科技';
    if (column === 'finance') return '财经';
    if (column === 'world') return '国际';
    if (column === 'sports') return '体育';
    return column;
  }

  // NewsNow 网页版 sync 需要完整四列；非 focus 列由源目录派生
  static hottestIds(): string[] { return HotSources.byType('hottest'); }

  static realtimeIds(): string[] { return HotSources.byType('realtime'); }

  // 「更新」列：NewsNow 由 updated-sources.ts 维护，此处用 realtime + 时间流源近似
  static updatedIds(): string[] {
    return HotSources.byType('realtime');
  }
}

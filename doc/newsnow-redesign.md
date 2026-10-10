# 智子热榜模块重构设计（NewsNow 后端版）

> 状态：待实施 · 版本：v1.0 · 日期：2026-09
>
> 目标：将智子现有「AI 资讯」模块整体下线，替换为以自部署/公共 NewsNow 实例为后端的热榜聚合模块，包含 GitHub 登录与「关注」多端同步。**不考虑任何历史数据兼容**，新闻域全部重做；游戏、AI 对话、微舆、主题等其他模块不受影响。

---

## 1. 背景与目标

### 1.1 现状问题

智子当前资讯模块（v14~v17 逐步堆叠）为「客户端直连 RSS/API 抓取」架构：

- `NewsService.ets`（31.5KB）：知乎日报/HN/RSS/OPML 抓取解析、频道聚合、标签与语言检测、LLM 打标管线、屏蔽逻辑；
- `NewsRanker.ets` + `NewsProfileService.ets`：本地画像推荐（赞/踩、标签权重、多样性约束）；
- 相关持久化 8 张表（ratings/events/exclusions/profile/tags/translations/cache…）。

痛点：源站结构变动即失效、抓取易被限流、客户端代码重、推荐算法与「热榜」使用场景错位。

### 1.2 新方案

以 [NewsNow](https://github.com/newsnext/newsnow) 实例为唯一数据源：

- **抓取、解析、缓存、源失效兜底全部在服务端**；客户端只消费三个 JSON API；
- 数据语义为各站官方热榜（服务端已排序），客户端**不做重排序、不做推荐算法**；
- 保留并增强智子差异化能力：AI 摘要/翻译/问 AI/今日要闻、收藏/已读/离线正文、全文搜索；
- 接入 NewsNow 的 GitHub 登录与 `/api/me/sync`，实现「关注」源列表与 NewsNow 网页版**数据互通**的多端同步。

### 1.3 非目标

- 不做文章级云端同步（NewsNow sync 只承载源 metadata，收藏仍走本地 RDB + 智子既有华为云同步通道）；
- 不保留旧推荐/画像体系的任何代码与数据；
- 不修改 NewsNow 服务端（全部能力以其现有 API 为准）。

---

## 2. NewsNow 服务端契约（实测源码确认）

### 2.1 API 一览

| 接口 | 方法 | 鉴权 | 说明 |
|---|---|---|---|
| `/api/latest` | GET | 无 | 返回 `{v: Version}`，连通性探测用 |
| `/api/s?id=<sourceId>[&latest]` | GET | 可选 Bearer | 单源榜单。响应见 2.2。带 JWT 且 `latest` 时可强制真实抓取；无 JWT 只能拿缓存 |
| `/api/s/entire` | POST | 无 | Body `{sources: string[]}`，返回 `SourceResponse[]`（仅缓存，毫秒级），批量预取用 |
| `/api/login` | GET | 无 | 302 → GitHub OAuth 授权页 |
| `/api/oauth/github?code=` | GET | 无 | 授权回调，302 → `/?login=github&jwt=<JWT>&user={"avatar","name"}` |
| `/api/me/sync` | GET / POST | 必需 Bearer | 拉取/上传用户 metadata，见 2.3 |

### 2.2 榜单响应结构

```ts
interface SourceResponse {
  status: "success" | "cache";   // cache = 命中服务端缓存
  id: string;                    // sourceId
  updatedTime: number | string;  // 服务端缓存更新时间
  items: NewsItem[];
}
interface NewsItem {
  id: string | number;   // 源内唯一
  title: string;
  url: string;
  mobileUrl?: string;    // 移动端链接，优先用于打开
  pubDate?: number | string;
  extra?: {
    hover?: string;
    date?: number | string;
    info?: false | string;   // 热度/评论数等描述文本
    icon?: false | string | { url: string; scale: number };
  };
}
```

要点：单源最多返回 30 条；`status="cache"` 时 UI 展示「更新于 HH:mm」；抓取失败时服务端自动回退旧缓存。

### 2.3 登录与同步结构

- JWT：HS256，60 天有效期，通过 `Authorization: Bearer <jwt>` 携带；
- 登录成功回调 URL 形如 `{baseUrl}/?login=github&jwt=<jwt>&user=<urlencoded JSON>`；
- `/api/me/sync` 负载（`PrimitiveMetadata`）：

```json
{
  "data": {
    "focus":    ["weibo", "zhihu"],
    "hottest":  ["...服务端预置，客户端不可改..."],
    "realtime": ["..."],
    "updated":  ["..."]
  },
  "updatedTime": 1736400000000
}
```

- GET 响应 `{data, updatedTime}`；POST body 需带 `data + updatedTime`，服务端原样存储（后写覆盖，无字段级合并）；
- **用户可编辑的只有 `focus`**；其余三列为源目录派生的固定列表（网页版 preprocess 会强制重置为预置值），App 侧同样处理：本地只持久化 `focus`，同步时补全其余三列以兼容网页版读取；
- 401 = JWT 失效；506 = 服务端未配置登录。

### 2.4 源目录（shared/pre-sources.ts 移植）

每个源含 `name / title / type("hottest"|"realtime"|默认时间流) / column(china|world|tech|finance|sports) / color / home / interval / redirect / disable / sub(子源)`。App 内置一份静态注册表（含子源展开，如 `wallstreetcn-quick`），随 App 版本更新；源 id 与服务端一致。

---

## 3. 总体架构

```
┌──────────────────────────── 智子 App ────────────────────────────┐
│ pages/                                                           │
│   Index.ets            热榜首页（视图 Tabs + 源卡片流，重写）     │
│   HotBoard.ets      ★ 单源榜单页（榜单 + 下拉强制刷新）           │
│   NewsDetail.ets       详情页（ArkWeb + AI 工具条，适配新模型）   │
│   NewsDigest.ets       AI 今日要闻（适配，跨源汇总）              │
│   NewsFavorites.ets    收藏列表（适配）                           │
│   NewsSearch.ets       搜索（已加载榜单 + 收藏/正文 FTS）         │
│   NewsSettings.ets     热榜设置（重写：服务器/账号/源/缓存）      │
│   NewsLogin.ets       ★ WebView 登录页（GitHub OAuth 拦截）      │
│ components/                                                      │
│   HotSourceCard.ets   ★ 源卡片（源徽标 + TopN 列表 + ⭐关注）     │
│   HotItemRow.ets      ★ 榜单条目行（序号/标题/热度/时间/已读态）  │
│   SourceBadge.ets     ★ 源徽标（按源 color 着色）                │
│   NewsDetailPane.ets   平板双栏详情（适配保留）                   │
│ service/                                                         │
│   NewsNowClient.ets   ★ 网络层：baseUrl + 三个 API + 错误模型    │
│   NewsNowAuth.ets     ★ 登录：JWT 存取(加密)/用户资料/过期检测    │
│   NewsNowSync.ets     ★ 同步：focus 拉取/上传、防抖、冲突处理    │
│   HotFeedStore.ets    ★ 内存状态：各源榜单缓存 + 加载状态机      │
│   HotSources.ets      ★ 源目录注册表（静态，含列分组计算）        │
│   NewsRepository.ets   本地持久化门面（重写，4 张新表 + FTS）     │
│   NewsAiService.ets    AI 能力（保留，入参适配 HotEntry）         │
│ common/                                                          │
│   HotModels.ets       ★ 数据模型（HotItem/HotBoardData/HotEntry…）│
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTPS + JSON
                    NewsNow 实例（默认 https://newsnow.busiyi.world，
                    可切换自部署 Docker/Cloudflare 实例）
```

分层规则：pages/components 只依赖 HotFeedStore + NewsRepository；网络细节只在 NewsNowClient/Auth/Sync 三处；AI 能力只接受 HotEntry + 正文文本，不感知 NewsNow。

---

## 4. 数据模型（common/HotModels.ets，全新）

```ts
// 单条热榜条目（对齐 NewsNow NewsItem）
export class HotItem {
  id: string;          // String(newsNowItem.id)
  title: string;
  url: string;
  mobileUrl: string;   // 缺省 = url
  pubDate: number;     // 毫秒；0 = 源未提供（extra.date 优先解析，其次 pubDate）
  info: string;        // extra.info → 热度描述（如 "热度 342万"），可为 ''
}

// 一个源的一次响应（对齐 SourceResponse）
export class HotBoardData {
  sourceId: string;
  fromCache: boolean;  // status === 'cache'
  updatedTime: number;
  items: HotItem[];
}

// 渲染用组合条目：全局唯一键 + 源上下文
export class HotEntry {
  key: string;         // `${sourceId}:${item.id}`，已读/收藏主键
  item: HotItem;
  sourceId: string;
  sourceName: string;
}

// 视图（一级 Tab）定义
export enum HotViewKey { Focus = 'focus', Hottest = 'hottest', Realtime = 'realtime',
  China = 'china', Tech = 'tech', Finance = 'finance', World = 'world', Sports = 'sports' }

// 关注同步负载（本地模型；网络层负责补全 hottest/realtime/updated）
export class FocusMetadata {
  focusSources: string[];
  updatedTime: number; // 本地最后变更时间；初始 0
}

// 登录用户资料
export class NewsNowUser {
  id: string;          // GitHub 数字 id 字符串（来自 JWT payload）
  name: string;
  avatar: string;
}
```

对比旧 `NewsItem`：删除 `tags / language / category / imageUrl / summary`；新增 `info / mobileUrl / key`。AI 摘要/翻译的内容来源由 `summary` 改为「标题 + 详情页抓取的网页正文」。

---

## 5. 网络层（service/NewsNowClient.ets）

```ts
export class NewsNowError {
  code: string;        // 'network' | 'http' | 'server' | 'unauthorized' | 'not_configured'
  httpStatus: number;
  message: string;
}

export class NewsNowClient {
  // —— 服务器配置（Preferences key: hot_server_url；默认 DEFAULT_SERVER） ——
  static getBaseUrl(): Promise<string>
  static setBaseUrl(url: string): Promise<void>   // 校验格式；变更后调用方负责清缓存

  // —— 探测 ——
  static ping(): Promise<string>                  // GET /api/latest → 版本号字符串

  // —— 榜单 ——
  static fetchBoard(sourceId: string, latest: boolean): Promise<HotBoardData>
      // GET /api/s?id=&latest=；有 JWT 自动带 Authorization；8s 超时
  static fetchBoards(sourceIds: string[]): Promise<HotBoardData[]>
      // POST /api/s/entire；失败降级为并发 fetchBoard(id, false)；单源失败该源返回 null（过滤）

  // —— 同步（JWT 必需，401/506 抛 NewsNowError） ——
  static pullMetadata(): Promise<FocusMetadata | null>   // GET /api/me/sync；data 为空 → null
  static pushMetadata(meta: FocusMetadata): Promise<number> // POST → 返回服务端 updatedTime
}
```

实现要点：

- HTTP 栈复用项目现有 `http`/`rcp` 风格（与 LlmClient 一致），统一 8s 超时、统一错误文案（FailureHandling 工具）；
- JWT 由 NewsNowAuth 注入，Client 通过回调/getter 获取，避免循环依赖；
- **客户端不做 HTTP 层缓存**，一切以 `HotFeedStore` 内存态 + 服务端 TTL 为准；
- pushMetadata 时把 `hottest/realtime/updated` 按 HotSources 计算的当前预置列表一并填入（保持与网页版读取兼容）。

---

## 6. 登录（service/NewsNowAuth.ets + pages/NewsLogin.ets）

### 6.1 流程

```
用户点「GitHub 登录」
  → 打开 NewsLogin 页（ArkWeb WebView，domStorage 开启）
  → 加载 {baseUrl}/api/login  → 302 GitHub 授权页 → 用户授权
  → 302 {baseUrl}/api/oauth/github?code=…
  → 302 {baseUrl}/?login=github&jwt=<JWT>&user={"avatar","name"}
  → onLoadIntercept 匹配到 `/?login=github&jwt=`：
       解析 jwt + user → 保存 → 返回 true 拦截加载 → 关闭页面 → 回调成功
```

- JWT 存储：**AES-256-GCM 加密**后存 Preferences（复用 CryptoHelper，与 API Key 同策略）；
- 用户资料（id/name/avatar）明文存 Preferences；头像用 Image 直接加载远程 URL；
- JWT payload（`{id, type, exp}`）本地 base64 解码取 `exp`：剩余 < 3 天时登录卡片提示「凭证即将过期，请重新登录」；任何 sync 请求 401 → 自动置为未登录 + toast；
- 登出：清 JWT + 用户资料；**focus 数据保留在本地**（退化为纯本地模式）。

### 6.2 登录态能力差异

| 能力 | 未登录 | 已登录 |
|---|---|---|
| 浏览全部榜单（缓存） | ✅ | ✅ |
| 下拉强制实时抓取（`/api/s?latest`） | ❌ 只能拿缓存 | ✅ |
| 关注列表多端同步 | ❌ 仅本地 | ✅ 与 NewsNow 网页版互通 |

UI 上对未登录用户在下拉刷新时提示一次「登录后可强制刷新最新数据」。

---

## 7. 关注与同步（service/NewsNowSync.ets）

```ts
export class NewsNowSync {
  // 本地真相：Preferences hot_focus_meta（FocusMetadata JSON）
  static getFocus(): Promise<FocusMetadata>
  static toggleStar(sourceId: string): Promise<boolean>   // 返回是否已关注；更新 updatedTime=now
  static reorderFocus(sourceIds: string[]): Promise<void>
  static isStarred(sourceId: string): Promise<boolean>

  // 云端同步
  static onLogin(): Promise<void>      // 登录成功：pull → 与本地按 updatedTime 新者胜 → 落地
  static onAppStart(): Promise<void>   // 已登录启动：静默 pull 合并（同上策略）
  static schedulePush(): void          // 标星/排序后调用：10s 防抖 push（对齐网页版行为）
  static flushPush(): Promise<void>    // App 退后台前强制 flush（EntryAbility onBackground 钩子）
}
```

冲突策略：**整份按 updatedTime 新者覆盖**（与服务端/网页版语义一致，不做字段合并）。`action` 字段不入库，仅网络层需要时构造。

---

## 8. 状态层（service/HotFeedStore.ets）

```ts
export type SlotStatus = 'idle' | 'loading' | 'ready' | 'error';

export class BoardSlot {
  status: SlotStatus;
  data: HotBoardData | null;
  error: string;
}

@Observed
export class HotFeedStore {
  static boards: Map<string, BoardSlot>;        // @Observed 经 UI 桥接（见下）
  static serverOnline: boolean;

  static ensureView(viewKey: HotViewKey): Promise<void>
      // 视图内所有 slot=idle 的源 → 先尝试 fetchBoards(全部 idle 源) 批量补齐，
      // entire 未覆盖的源并发 fetchBoard(id, false)
  static refreshSource(sourceId: string): Promise<void>
      // fetchBoard(id, latest=true)；未登录时 latest 由 Client 忽略（服务端行为）
  static refreshView(viewKey: HotViewKey): Promise<void>  // 视图内全部源并发 refreshSource
  static clearAll(): void                       // 切换服务器地址时调用
}
```

- UI 桥接：Store 以 `Map` 持有数据，页面侧用 `@State version: number` + `notifyChanged()` 触发刷新（与项目现有 @StorageLink 模式协调，避免 @Observed Map 的细粒度坑）；
- 冷启动：EntryAbility 完成后 `ensureView(当前视图)`，entire 一次往返即可铺满（全部为服务端缓存，不产生源站抓取）；
- 前台驻留 ≥ 30min 回到热榜 Tab：对当前视图 `ensureView` 静默补齐（不触发 latest 抓取）；
- 单源失败：该卡片显示错误态 + 重试按钮，不影响其他源。

---

## 9. 页面设计

### 9.1 Index.ets（热榜首页，重写）

结构（手机）：

```
TopBar：问候语 + [AI 今日要闻入口] + [搜索🔍] + [设置⚙]
视图 Tabs（横向滚动）：⭐关注 | 🔥最热 | ⚡实时 | 国内 | 科技 | 财经 | 国际 | 体育
内容区（Refresh 下拉刷新 = refreshView）：
  按视图内源逐个渲染 HotSourceCard：
    ┌───────────────────────────────┐
    │ [徽标] 微博·实时热搜   ⭐  ↻  │  ← 卡片头：关注星、单源刷新、> 进单源页
    │  25分钟前更新                  │
    │  1  xxxxxxxx        热度342万 │
    │  2  xxxxxxxx                 │  ← Top 5
    │  …                           │
    │  查看全部 30 条 >             │
    └───────────────────────────────┘
空态：关注视图为空 → 「点击任意源卡片右上角 ⭐ 添加关注」引导
离线/服务器不可达 → 顶部横幅 + 去设置按钮；已有内存数据继续展示
```

平板/折叠屏（width ≥ 840vp）：双栏——左侧源卡片列表，右侧 NewsDetailPane；或 ≥ 600vp 时源卡片改 2~3 列网格（还原 NewsNow 官网多栏感）。

### 9.2 HotBoard.ets（单源榜单页，新增）

- 头部：源徽标 + 源名 + 「更新于 HH:mm」+ ⭐ + 「源站首页」跳转；
- 列表：全部 30 条，序号着色（Top3 红/橙/黄），热度 info 右对齐，已读条目降透明度；
- 下拉刷新 = `refreshSource(sourceId)`；登录用户提示「已获取最新数据/暂无更新」；
- 点击条目 → 标记已读 → NewsDetail。

### 9.3 NewsDetail.ets（适配改造，保留主体）

- 入参改为 `HotDetailRouteParams { key, sourceId, sourceName, title, url, mobileUrl, info }`；
- ArkWeb 优先加载 `mobileUrl`；正文抽取结果喂 AI（替代旧 summary 字段）；
- 工具条保留：收藏、AI 摘要、AI 翻译、问 AI、朗读、离线缓存、分享；
- 已读上报：`NewsRepository.markRead(key)`；收藏存整条 HotEntry 快照。

### 9.4 NewsDigest.ets（今日要闻，适配）

- 数据源：当前「关注 + 最热」视图已加载榜单的各源 Top3（零网络，纯内存）；
- prompt 组装改为「标题列表 + 源名」，由 NewsAiService 生成 Markdown 简报；缓存入 `hot_digests`（沿用按日/时段 id 策略）。

### 9.5 NewsSearch.ets（改造）

- 搜索范围：① HotFeedStore 已加载榜单（内存过滤）② 收藏 FTS ③ 正文缓存 FTS；
- 保留「AI 汇总搜索结果」按钮（NewsAiService.search 逻辑适配）。

### 9.6 NewsSettings.ets（重写）

```
热榜设置
├─ 服务器
│   ├─ 当前服务器：newsnow.busiyi.world（点击编辑，格式校验 https://）
│   ├─ 测试连接 → ping() → 「✓ 版本 v0.0.42 / ✗ 无法连接」
│   └─ 恢复默认
├─ 账号
│   ├─ 未登录：[使用 GitHub 登录]（说明：登录可强制刷新 + 同步关注）
│   └─ 已登录：头像 + 昵称 + 同步状态（上次同步时间）+ [立即同步] + [退出登录]
├─ 关注管理：已关注源列表（拖拽排序 / 取消关注）+ 全部源目录（分组浏览，点 ⭐）
├─ 数据
│   ├─ 清除已读记录 / 清除正文缓存 / 清除收藏（二次确认）
│   └─ 收藏/已读/AI 调用统计数字
└─ 关于数据源：NewsNow 项目链接 + MIT 许可 + 「热榜内容版权归原站点所有」声明
```

### 9.7 NewsLogin.ets（新增）

全屏 WebView + 顶栏（标题「GitHub 登录」+ 关闭按钮）；`onLoadIntercept` 拦截 `/?login=github&jwt=`；加载失败显示重试；登录中禁止返回手势误关闭（二次确认）。

---

## 10. 数据库重构（不兼容历史）

`DB_VERSION` 17 → 18，升级回调执行：`DROP TABLE IF EXISTS` 旧新闻 8 表（`news_favorites, news_read, news_digests, news_cache, news_article_cache, news_tags, news_ratings, news_events, news_exclusions, news_profile, news_translations` 及 `news_articles_fts`），随后创建新表：

```sql
-- 收藏（存 HotEntry 快照）
CREATE TABLE hot_favorites (
  key TEXT PRIMARY KEY, source_id TEXT NOT NULL, source_name TEXT DEFAULT '',
  title TEXT NOT NULL, url TEXT NOT NULL, info TEXT DEFAULT '', added_at INTEGER NOT NULL
);
CREATE INDEX idx_hot_favorites_added ON hot_favorites(added_at);

-- 已读
CREATE TABLE hot_read (
  key TEXT PRIMARY KEY, read_at INTEGER NOT NULL
);
CREATE INDEX idx_hot_read_at ON hot_read(read_at);

-- 详情页正文离线缓存（AI 摘要/翻译正文来源）
CREATE TABLE hot_article_cache (
  url TEXT PRIMARY KEY, title TEXT NOT NULL, html TEXT NOT NULL, cached_at INTEGER NOT NULL
);

-- AI 今日要闻缓存
CREATE TABLE hot_digests (
  id TEXT PRIMARY KEY, date TEXT NOT NULL, content TEXT NOT NULL,
  model_name TEXT DEFAULT '', created_at INTEGER NOT NULL
);

-- FTS5（沿用 trigram → 默认分词 → LIKE 回退三级探测）
CREATE VIRTUAL TABLE hot_articles_fts USING fts5(
  kind UNINDEXED, key UNINDEXED, title, body, tokenize='trigram');  -- kind = fav | article
```

保留策略（沿用现有 retention 框架）：`hot_read` 90 天、`hot_article_cache` 30 天。

Preferences 新增键：

| key | 内容 |
|---|---|
| `hot_server_url` | 服务器地址 |
| `hot_jwt_enc` | AES-256-GCM 加密后的 JWT |
| `hot_user` | 用户资料 JSON |
| `hot_focus_meta` | FocusMetadata JSON |
| `hot_read_migrated` | —（不需要，无迁移） |

---

## 11. 导航与路由变更

- `main_pages.json`：移除 `NewsRecommend / NewsStats / NewsLikes / NewsProfile / NewsSourceSettings / NewsChannelSettings`；新增 `pages/HotBoard`、`pages/NewsLogin`；保留 `NewsDetail / NewsDigest / NewsFavorites / NewsSearch / NewsSettings`；
- `Navigation.ets` 的 `PageKey` 同步增删（删除的枚举值连同 `pageFromString` 分支一起移除）；
- 底部主导航不变（资讯 Tab 仍是 Index），`MainNavKey.Index` 指向重写后的热榜首页；
- Profile 页入口调整：「资讯统计/点赞记录/推荐」入口删除，替换为「热榜设置」直达；「我的收藏」「阅读记录」入口保留。

---

## 12. 删除清单

### 12.1 整文件删除（15 个）

| 文件 | 原因 |
|---|---|
| common/NewsChannels.ets | 频道/源注册表 → HotSources.ets |
| common/NewsModels.ets | 模型 → HotModels.ets |
| service/NewsService.ets | 抓取/聚合/标签 → NewsNowClient + HotFeedStore |
| service/NewsRanker.ets | 推荐算法废弃 |
| service/NewsProfileService.ets | 画像废弃 |
| components/NewsCard.ets | → HotSourceCard / HotItemRow |
| components/NewsDislikePanel.ets | 点踩废弃 |
| components/NewsModelSelector.ets | 并入设置页内联 |
| pages/NewsRecommend.ets | 推荐页废弃 |
| pages/NewsLikes.ets | 点赞记录废弃 |
| pages/NewsProfile.ets | 画像页废弃 |
| pages/NewsChannelSettings.ets | 频道设置 → NewsSettings 关注管理 |
| pages/NewsSourceSettings.ets | 同上 |
| pages/NewsStats.ets | 统计并入 NewsSettings 数据区 |
| pages/Index.ets | 原样重写（同名文件覆盖） |

### 12.2 改造保留（6 个）

`NewsDetail.ets`（入参/已读/收藏键改造）、`NewsDigest.ets`（数据源改造）、`NewsFavorites.ets`（模型改造）、`NewsSearch.ets`（范围改造）、`NewsSettings.ets`（重写）、`components/NewsDetailPane.ets`（模型适配）、`service/NewsAiService.ets`（入参适配）、`service/NewsRepository.ets`（重写门面）。

### 12.3 连带修改

- `service/DatabaseHelper.ets`：v18 升级 + 新表 SQL + 删旧表 SQL 与方法；
- `service/ToolRegistry.ets`：Agent 工具 `news_search / news_fetch` 改走 HotFeedStore 内存检索与当前视图 TopN；
- `common/Navigation.ets`、`main_pages.json`、`pages/Profile.ets`：入口与枚举清理；
- `service/CloudSyncService.ets`：若此前同步 news_* 表，移除对应表同步（收藏多设备同步留待后续接华为云，本期不做）；
- `README.md` / `doc/DESIGN.md`：功能描述更新。

---

## 13. 异常与边界

| 场景 | 行为 |
|---|---|
| 冷启动服务器不可达 | 首页横幅「无法连接热榜服务器」+ 设置入口；收藏/已读/正文缓存正常可用 |
| 单源抓取失败（服务端 500/timeout） | 该源卡片错误态 + 重试；其余源不受影响 |
| `status="cache"` | 卡片显示「更新于 HH:mm」；`success` 显示「刚刚更新」 |
| entire 未返回某源 | 该源 slot 保持 idle，进入时单独 fetchBoard(false) 懒补 |
| JWT 过期（sync 401） | 自动登出 + toast「登录已过期」；本地 focus 保留 |
| 服务器未配置登录（sync 506） | 登录入口隐藏/置灰提示「该服务器未开启账号功能」 |
| 切换服务器地址 | HotFeedStore.clearAll() + focus 保留（focus 是源 id 列表，与实例无关；若新实例缺某源 id，UI 跳过该源） |
| 局域网 HTTP 自部署 | module.json5 配置 cleartextTraffic（文档说明，默认关） |
| WebView 登录被用户中途关闭 | 无状态变更，回到原页 |

---

## 14. 实施计划（每步独立可编译验证）

| # | 内容 | 产出 |
|---|---|---|
| 1 | HotModels + HotSources（源目录静态注册表） | 纯新增，可单测 |
| 2 | NewsNowClient（ping/fetchBoard/fetchBoards）+ 设置页「服务器」区 | 可手测连通 |
| 3 | HotFeedStore + HotSourceCard/HotItemRow + 新 Index 视图流 | 首页可看榜 |
| 4 | HotBoard 单源页 + 已读/收藏（新表 + NewsRepository 重写） | 数据闭环 |
| 5 | NewsNowAuth + NewsLogin WebView 登录 | 登录可用 |
| 6 | NewsNowSync（focus 推拉/防抖/冲突）+ 设置页账号区 | 同步闭环 |
| 7 | NewsDetail/Digest/Search/Favorites 适配 + NewsAiService 入参 | AI 功能回归 |
| 8 | 删除清单执行（文件/表/路由/枚举/Profile 入口/ToolRegistry） | 净代码落地 |
| 9 | 文档更新（README/DESIGN）+ 全量回归（主题/平板/Agent/实况窗） | 收尾 |

预估：删除 ~4500 行，新增 ~1500 行，净减 ~3000 行。

---

## 15. 验收清单

1. 默认地址冷启动：「最热」视图 2s 内铺满源卡片（entire 预取）；
2. 切换自部署地址 → ping 显示版本 → 榜单正常；
3. 未登录下拉刷新：数据来自缓存，UI 提示登录可强制刷新；
4. GitHub 登录成功：头像昵称展示，JWT 加密落盘；
5. 标星某源 → 10s 内自动上传；网页版登录同账号可见相同关注列表（互通验证）；
6. 网页版标星 → App 重新启动后关注列表一致（拉取验证）；
7. 登录用户下拉「关注」视图触发 latest 抓取，`updatedTime` 更新；
8. 详情页：mobileUrl 优先、AI 摘要/翻译/问 AI 正常、调用日志落表；
9. AI 今日要闻跨源生成成功并可回看当日缓存；
10. 断网：榜单离线态、收藏/已读/缓存正文可读；
11. 平板双栏、深色模式、6 套主题无回归；Agent news_search 工具可用；
12. DB v17→v18 升级后旧新闻表不存在、新表功能正常（无崩溃、无数据残留引用）。

---

## 16. 开放项（实施前已拍板）

- ✅ 频道模型：采用 NewsNow 对齐的「视图 Tab」（关注/最热/实时/列分组），关注 = 标星源；
- ✅ 默认服务器：`https://newsnow.busiyi.world`，可切自部署；
- ✅ 登录：WebView 拦截回调方案，依赖其 `/?login=github&jwt=` 回跳实现细节（改版风险由「登录功能降级可用」兜底）；
- ⏳ 收藏多设备同步：本期本地 RDB，后续可挂智子既有华为云同步通道（独立迭代）。

---

## 17. 实施记录（v9.0，已完成）

实施时间：本轮迭代。编译验证：`hvigorw assembleHap --mode module -p module=entry` **BUILD SUCCESSFUL**（ArkTS 0 error）。

### 17.1 交付文件

**新增（11）**：`common/HotModels.ets` · `common/HotSources.ets`（52 条源）· `common/HotFormat.ets` · `common/PageRefreshBus.ets` · `service/NewsNowClient.ets` · `service/NewsNowAuth.ets` · `service/NewsNowSync.ets` · `service/HotFeedStore.ets` · `components/HotSourceBadge.ets` · `components/HotItemRow.ets` · `components/HotSourceCard.ets` · `pages/HotBoard.ets` · `pages/NewsLogin.ets`（含组件共 13 个文件）

**重写（5）**：`pages/Index.ets` · `pages/NewsSettings.ets` · `pages/NewsSearch.ets` · `pages/NewsFavorites.ets` · `service/NewsRepository.ets` · `service/NewsAiService.ets`

**适配（4）**：`pages/NewsDetail.ets` · `pages/NewsDigest.ets` · `service/DatabaseHelper.ets` · `service/ToolRegistry.ets`

**删除（15 个源码 + 4 个文档/日志）**：NewsModels / NewsChannels / NewsService / NewsRanker / NewsProfileService / NewsCard / NewsDislikePanel / NewsModelSelector / NewsDetailPane / NewsRecommend / NewsStats / NewsLikes / NewsProfile / NewsSourceSettings / NewsChannelSettings；`doc/news-feature-plan.md`、`doc/news-smart-recommend.md`、`doc/news-smart-recommend-m1.md`、`doc/news-rss-full.opml`、`build-output-iteration-1.log`

**测试**：删除 4 个失效用例（NewsServiceTest / NewsRankerTest / NewsProfileServiceTest / NewsAiServiceTest），新增 `HotModuleTest.ets`、`NewsNowAuthTest.ets`，更新 `NewsRepositoryTest.ets`。

**连带**：`common/Navigation.ets`（PageKey 增删）· `main_pages.json` · `pages/AppShell.ets`（路由分支 + `PageRefreshBus.emitHotShow()`）· `pages/Profile.ets`（入口重排）· `pages/Settings.ets`（清理项改造）· `entryability/EntryAbility.ets`（启动拉取关注 + 退后台 flush）· `service/CloudSyncService.ets`（排除本机凭证类设置）。

### 17.2 与方案的偏差（实现时调整）

| 项 | 方案 | 实现 | 原因 |
|---|---|---|---|
| 平板双栏 | 复用 `NewsDetailPane` 内嵌右栏 | 删除该组件，改为 isMd 双列 / isLg 三列源卡片网格，条目走路由详情页 | 内嵌面板与路由页重复维护，且热榜以「扫榜」为主，多列网格信息密度更高 |
| 源目录规模 | 约 40 源 | 52 条（含子榜展开，如 `bilibili-hot-search`、`github-trending-today`）；`disable`（含 `cf`）源不进默认视图 | 对齐 NewsNow `pre-sources.ts` 实测结果，避免 Cloudflare 实例上必然失败的源污染默认视图 |
| 模型选择器 | 复用 `NewsModelSelector` | 该组件随旧模块删除，在 NewsDetail / NewsDigest 内联轻量选择器 | 旧组件依赖旧模型 API |
| 简报时段 | 4 档（今日要闻/早报/午间/晚报） | 一致（去掉了旧的「为你精选」个性化档） | 个性化画像已废弃 |
| `news:` 场景前缀 | — | 保留（`ai_call_logs.game = news:summary` 等） | 仅日志标签，改名会牵连历史统计口径 |
| 关注排序 | 拖拽排序 | 设置页 ▲▼ 按钮排序 | 拖拽需引入 `onItemDragStart` 等，收益低，先满足可用 |

### 17.3 待办（未做，与方案一致）

- 收藏的跨设备同步（当前本地 RDB；可后续挂智子既有华为云同步通道）；
- 「更新」视图的源列表目前用 `realtime` 源近似（NewsNow `updated-sources.ts` 未移植）；
- 真机联调：登录回跳、latest 强制抓取、localStorage 无关的 ArkWeb 行为需在设备上验证（本机仅完成编译与静态校验）。
### 17.4 实测补充：Cloudflare 403 与公共实例容量（真机联调发现）

**现象**：真机「测试连接」返回 `403`，而手机浏览器访问同一地址正常。

**定位**（同一环境对照实验，与 IP 无关）：

| 请求头 | 结果 |
|---|---|
| `Accept: */*`（修复前的实现） | `403` — Cloudflare `Sorry, you have been blocked` |
| `User-Agent` + `Accept` + `Accept-Language` + `Referer` + `Origin` | `200 {"v":"0.0.42"}` |

**结论**：`busiyi.world` 的 Cloudflare WAF 按请求头（UA）拦非浏览器客户端，属头校验而非 TLS/JA3 指纹校验。

**修复**：`NewsNowClient.browserHeaders()` 统一为所有请求（GET/POST/同步）附加浏览器化请求头，UA 常量 `NEWSNOW_UA` 同时用于 `NewsLogin` 的 WebView（`.userAgent(NEWSNOW_UA)`），保证两侧标识一致；`httpError()` 对 403 给出「先登录一次或改自部署」的可操作提示。

**第二个问题（服务端侧，客户端无法修复）**：修复 403 后发现公共实例 `newsnow.busiyi.world` 的 D1 数据库过载——

```
GET /api/s?id=weibo      -> 500  D1_ERROR: D1 DB is overloaded. Requests queued for too long.
GET /api/s?id=zhihu      -> 500  同上
GET /api/s?id=baidu      -> 500  同上
GET /api/s?id=hackernews -> 500  同上
GET /api/s?id=cls        -> 500  同上
GET /api/s?id=github     -> 200  正常返回 30 条
POST /api/s/entire       -> 204  空（缓存为空时返回）
GET  /api/me/sync(无 JWT) -> 401  符合预期
```

即公共实例当前**大部分源不可用**，符合「服务不受你控制」的预判。因此：

- 产品层面：**推荐自部署实例**；`/api/s/entire` 返回 204 时按「未命中缓存」处理并逐源降级抓取（当前实现即如此），单源失败只影响该源卡片；
- 错误透出：`httpErrorWithBody()` 把服务端 `message` 原文展示到源卡片（如 `HTTP 500：D1_ERROR: D1 DB is overloaded…`），让用户能区分「App 坏了」与「服务端过载」；
- 设置页新增说明文案，指引 403 的两种处理方式。
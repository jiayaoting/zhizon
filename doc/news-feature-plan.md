# 智子「AI 资讯」主功能重设计方案（v2.0）

> 版本：v2.1（已确认版：导航方案 A / 默认频道与源按设计 / AI 今日要闻独立全屏页 / AI 摘要手动触发）
> 定位调整：**新闻资讯升级为应用主功能，游戏降为次要功能；AI 摘要手动触发**
> 关联应用：智子（Zhizon）· HarmonyOS NEXT · ArkTS/ArkUI · API 24
> 关联文档：[DESIGN.md](DESIGN.md) / [README.md](../README.md)

---

## 一、产品定位调整（v1.0 → v2.0）

### 1.1 新定位

**智子 = AI 增强的资讯阅读器 + 智能对话 + 休闲游戏**

   旧定位：游戏中心 + AI 对话 + 多主题（新闻是附加）
   新定位：AI 资讯阅读（主） + AI 对话（辅） + 游戏中心（次）

| 维度 | 旧（v1.0 方案） | 新（v2.0） |
|------|----------------|-----------|
| 主功能 | 游戏中心 + AI 对话 | **AI 资讯阅读**（资讯流 + AI 摘要/翻译/问AI/日报/推荐） |
| 次功能 | — | AI 对话（与资讯深度联动） |
| 次次功能 | — | 游戏中心（保留全部游戏，入口降级） |
| 首页 | 游戏入口大卡 + 战绩 | **资讯流首页**（问候 + AI 日报入口 + 频道 + 新闻列表） |
| AI 摘要 | 手动触发（默认关闭） | **手动触发（已确认，默认关闭、按钮显式触发）** |

### 1.2 主功能用户场景（资讯优先）

| 场景 | 说明 |
|------|------|
| 打开即看 | 启动进入首页 → 直接是资讯流，无需二次点击 |
| 频道浏览 | 推荐/科技/财经/AI专题/国际 频道切换，下拉刷新、上拉加载 |
| AI 摘要（手动） | 读文章时点「🤖 摘要」→ 流式输出要点 |
| AI 翻译（手动） | 外文新闻点「🌐 翻译」→ 中文 |
| 问 AI（手动） | 详情页对正文追问、查背景 |
| AI 今日要闻（手动） | 首页卡片一键生成当天热点简报，可重生成/朗读 |
| 个性化推荐 | 「为你推荐」频道：按收藏/阅读历史由 AI 排序 |
| 收藏稍后读 | 收藏 + 已读 + 本地缓存，无网可读 |
| 对话联动 | 读到一半丢给 AI 对话继续讨论；AI 对话中可直接调「今日新闻」工具 |

---

## 二、参考案例与调研（补充）

在 v1.0 调研基础上（华为官方 [NewsData](https://gitee.com/harmonyos_codelabs/NewsData)、[multi-news-read](https://gitee.com/harmonyos_samples/multi-news-read)、GitCode [DailyNews](https://gitcode.com/nuankafei/DailyNews) / [FocusOnNews](https://gitcode.com/uksri/FocusOnNews)、AI RSS 阅读器 [Horizon](https://github.com/xyg165/Horizon) / [YourRSS](https://github.com/XimilalaXiang/YourRSS)），补充主流新闻产品结构参考：

| 参考 | 借鉴点 |
|------|--------|
| 今日头条 / 腾讯新闻 | 首页即信息流；频道栏横向滑动；大图卡信息密度 |
| Flipboard / Google News | 杂志式卡片排版；**个性化话题页**；「为你推荐」 |
| Feedly / Readwise Reader | 订阅管理、稍后读、阅读进度 |
| YomiAI / RSSFlow（AI 阅读器） | **AI 摘要按钮化**（手动触发）、摘要可复制/朗读 |

结论：主流新闻 App 均以「**首页信息流 + 频道 + 详情**」为核心骨架，AI 类阅读器以「**手动触发 AI 摘要/翻译**」为标配——与本次设计一致。

---

## 三、信息架构与导航重设计（核心改动）

### 3.1 方案 A（推荐）：4 Tab，首页即资讯

   手机底部 Tab：  [📰 资讯]  [🗨️ AI对话]  [🎮 游戏]  [👤 我的]
                   （主）      （辅）       （次）      （设置/收藏）
   平板侧边栏：    同顺序

| Tab | 内容 | 与原架构关系 |
|-----|------|--------------|
| 资讯（新首页） | 问候栏 + AI 今日要闻卡 + 频道 Tabs + 资讯流 + 收藏入口 | 改造原 Index.ets（去掉游戏卡，换成资讯流） |
| AI 对话 | 保持不变 | 无改动 |
| 游戏 | 保留原 Games.ets 全部游戏与难度选择 | 仅顺序后移（第 3 位），功能不动 |
| 我的 | 原内容 + 新增「收藏/稍后读」「新闻设置」「资讯统计」 | 增加 2~3 个入口 |

- 优点：资讯成为第一屏；4 Tab 数量不变、结构稳定；游戏功能零删除
- 缺点：首页改造工作量最大（Index.ets 重写）

### 3.2 方案 B：3 Tab，游戏收进「我的」

   [📰 资讯]  [🗨️ AI对话]  [👤 我的（含 游戏中心 入口）]

- 游戏中心降为「我的 → 游戏中心」二级入口（Games.ets 仍作为路由页存在）
- 优点：资讯地位最突出；底部更简洁
- 缺点：老用户找游戏多一步；导航/页面结构改动更大（Games 从 EMBEDDED 变 ROUTE）

> **推荐方案 A**：信息架构改动最小、升级路径最平滑；游戏虽为次要但仍是可一键到达的 Tab，避免老用户流失。

### 3.3 导航改造点（方案 A）

- MainNavKey：保持 Index / Games / Chat / Profile 四个枚举不变
- PageKey：新增 NewsDetail、NewsDigest（ROUTE 页）；Index 语义变为「资讯首页」
- AppConstants.navItems：第 1 项改为 new NavItem(MainNavKey.Index, '资讯', '📰')
- Index.ets：重写为资讯首页（见第七章）
- AppShell.ets：Index 分支渲染新的 IndexPage；routeDestination 增加 NewsDetail / NewsDigest
- main_pages.json：注册 pages/NewsDetail、pages/NewsDigest

---

## 四、功能规划（P0 / P1 / P2）

### 4.1 P0 — 资讯主功能 MVP（约 1 周）

| 功能 | 说明 |
|------|------|
| 资讯首页（新 Index） | 问候栏 + 频道 Tabs + 新闻卡片流 + 下拉刷新/上拉加载 |
| 频道 | 推荐 / 科技 / AI专题 / 财经 / 国际（由内置源映射，见第五章） |
| 新闻列表 | LazyForEach 卡片（大图/小图/纯文本三态），已读置灰 |
| 详情页 NewsDetail | ArkWeb 加载原文 + 来源/时间/头图 + 已读标记 + 收藏 |
| 收藏/稍后读 | RDB 表 news_favorites；资讯页顶部入口进入收藏列表 |
| 空态/错误态 | 加载失败重试、无网络提示、空列表引导 |

### 4.2 P1 — AI 能力（主功能差异化，约 1 周，全部手动触发）

| 功能 | 触发方式 | 说明 |
|------|----------|------|
| 🤖 **AI 摘要** | 详情页按钮（**手动，默认关**） | 流式输出要点，正文截断后入上下文 |
| 🌐 **AI 翻译** | 详情页按钮（手动） | 英→中（可切中→英） |
| 💬 **问 AI** | 详情页按钮（手动） | 以正文为上下文多轮追问，流式回答 |
| 📰 **AI 今日要闻** | 首页卡片按钮（手动） | 聚合当天各源标题 → LLM 生成 8~10 条分类简报，可重生成/复制/朗读 |
| 🎯 **为你推荐** | 首页频道「为你推荐」（手动进入） | 基于收藏/已读历史 → LLM 排序候选 |
| 🗂️ **AI 调用记录** | — | 场景 news_summary / news_translate / news_qa / news_digest / news_recommend 写入 ai_call_logs |
| 🔇 **降级** | — | 未配置模型时 AI 按钮隐藏并提示；调用失败 Toast + 不影响原文阅读 |

### 4.3 P2 — 增强（后续迭代）

- 自定义 RSS 订阅源 + OPML 导入
- 离线正文缓存（news_cache）+ 无网阅读
- AI 早报定时生成（前台触发为主，后台评估 WorkScheduler）
- 语音朗读新闻（复用 SpeechService TTS）
- 新闻搜索（跨源关键词 + AI 摘要）
- 资讯分享（Share Kit）
- 平板双栏阅读（参考 multi-news-read）
- Agent 工具 news_top / news_search（AI 对话中直接获取新闻）

---

## 五、数据源与频道策略（资讯为主 → 源更丰富）

### 5.1 默认内置源（Layer 0，免 key）

| 频道 | 源 | 类型 | 稳定性 |
|------|----|------|--------|
| 推荐 | 全部启用源合并（时间排序） | — | — |
| 科技 | Hacker News Algolia | JSON 免费 | 高 |
| 科技 | 少数派 sspai.com/feed | RSS | 高 |
| 科技 | IT之家 ithome.com/rss | RSS | 高 |
| AI专题 | 科技频道按关键词（AI/大模型/LLM）过滤 | 派生频道 | 高 |
| 财经 | 36氪 36kr.com/feed | RSS | 中 |
| 国际 | BBC 中文 feeds.bbci.co.uk/zhongwen/simp/rss.xml | RSS | 高 |
| 中文综合 | 知乎日报 news-at.zhihu.com/api/4/news/latest | JSON 免费 | 中（无官方承诺） |

> 内置源清单在 NewsChannels.ets 注册表中维护，**上线前逐个实测**；失效源一键下线，不影响其他源。

### 5.2 可配置源（Layer 1/2）

- 天行数据 / 聚合数据新闻接口（用户填 key，设置页管理）
- RSSHub 公共实例 / 自建实例（URL 可填）
- 自定义 RSS 订阅（P2）

### 5.3 统一抽象（同 v1.0）

- NewsItem / NewsSource / NewsChannel 模型，全部源归一化
- NewsService.fetchFeed(channelId, page)：并发拉取 → 归一化 → 按时间合并 → 10 分钟内存缓存
- 任一源失败自动降级，参考 WebSearchService 容错风格
- 派生频道（如 AI专题）在归一化后本地过滤，不额外请求

---

## 六、技术架构与改动清单

### 6.1 新增文件

| 文件 | 职责 | 参考 |
|------|------|------|
| common/NewsModels.ets | NewsItem / NewsSource / NewsChannel / NewsDigest 模型 | LlmModels.ets |
| common/NewsChannels.ets | 频道与源注册表 + 源工厂（含派生频道过滤规则） | Difficulty.ets |
| service/NewsService.ets | 多源拉取、归一化、合并、缓存、RSS(XML) 解析 | WebSearchService.ets |
| service/NewsRepository.ets | 收藏/已读/缓存 RDB 门面 | ChatRepository.ets |
| service/NewsAiService.ets | AI 摘要/翻译/问AI/日报/推荐（prompt + 截断 + 日志） | GameAIService.ets |
| components/NewsCard.ets | 资讯卡片三态（大图/小图/纯文本） | DifficultyOption.ets |
| components/ChannelTabs.ets | 横向频道 Tabs | Chat 会话抽屉样式 |
| components/NewsDigestCard.ets | 首页 AI 今日要闻卡片（结果缓存展示） | Index 卡片样式 |
| pages/NewsDetail.ets | 详情页（ArkWeb + AI 操作条 + 摘要/问AI 面板） | LegalDoc.ets |
| pages/NewsDigest.ets | AI 今日要闻全屏页（可选） | AiCallLog.ets |
| pages/NewsFavorites.ets | 收藏/稍后读列表页 | GameHistory.ets |

### 6.2 现有文件改动

| 文件 | 改动 |
|------|------|
| pages/Index.ets | **重写为资讯首页**：问候栏（精简）+ AI 今日要闻卡 + ChannelTabs + 新闻流；移除游戏入口大卡（游戏入口改由 Games Tab 提供） |
| common/Constants.ets | navItems 第 1 项改为「资讯 📰」；Profile 标语改为「AI 资讯 · 智能对话 · 休闲游戏」 |
| pages/Profile.ets | 新增入口：收藏/稍后读、新闻设置、AI 调用记录（已有） |
| common/Navigation.ets | PageKey 增加 NewsDetail / NewsDigest（ROUTE）；pageFromString 补分支 |
| pages/AppShell.ets | routeDestination 增加 pages/NewsDetail、pages/NewsDigest、pages/NewsFavorites |
| resources/base/profile/main_pages.json | 注册上述新路由页 |
| service/DatabaseHelper.ets | DB_VERSION 13→14；新增 3 张表（见 6.4） |
| service/DataRepository.ets | 新闻设置读写转发 |
| pages/Settings.ets | 新增「资讯」分组：源开关、AI 摘要手动触发确认、日报卡显隐 |
| service/ToolRegistry.ets（P2） | Agent 工具 news_top |
| README.md / doc/DESIGN.md | 定位、功能清单、架构更新 |

### 6.3 首页（新 Index）结构

    ┌──────────────────────────────┐
    │ ☀ 早上好 · 5月20日  [👤]      │  ← 精简问候栏（保留头像→设置）
    ├──────────────────────────────┤
    │ ╭──────────────────────────╮ │
    │ │ 📰 AI 今日要闻  [生成] [→] │ │  ← 手动触发；已有结果则展示摘要
    │ ╰──────────────────────────╯ │
    ├──────────────────────────────┤
    │ [推荐] [科技] [AI专题] [财经] │  ← ChannelTabs 横向滚动
    ├──────────────────────────────┤
    │  ┌────────────────────────┐  │
    │  │ 📰 标题…      [缩略图]   │  │  ← NewsCard（LazyForEach）
    │  │ 来源 · 时间 · 摘要两行   │  │
    │  └────────────────────────┘  │
    │  …（下拉刷新 / 上拉加载）     │
    └──────────────────────────────┘

### 6.4 数据表（DatabaseHelper v14）

    -- 收藏/稍后读
    CREATE TABLE IF NOT EXISTS news_favorites (
      id TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT DEFAULT '',
      image_url TEXT DEFAULT '',
      source_name TEXT DEFAULT '',
      added_at INTEGER NOT NULL
    );

    -- 已读标记
    CREATE TABLE IF NOT EXISTS news_read (
      url TEXT PRIMARY KEY,
      read_at INTEGER NOT NULL
    );

    -- AI 今日要闻结果缓存（手动生成后本地保存，可重新生成）
    CREATE TABLE IF NOT EXISTS news_digests (
      id TEXT PRIMARY KEY,          -- 'digest-' + yyyyMMdd
      date TEXT NOT NULL,
      content TEXT NOT NULL,        -- 简报 Markdown 文本
      model_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL
    );

设置项（settings 表）：newsEnabledSources（JSON）、newsAiSummaryManual='true'（固定手动）、newsDigestEnabled、newsDigestAutoRefresh（P2）等。

### 6.5 AI 复用点（同 v1.0，摘要确认手动触发）

| 需求 | 现有能力 |
|------|----------|
| 当前模型配置 | ChatRepository.loadModels() + loadActiveModelId() + entryToConfig(model) |
| 流式摘要/翻译/问AI | LlmClient.postCompletionStream(config, messages, onDelta, onReasoning) |
| 非流式日报/推荐 | LlmClient.postCompletion(config, messages) |
| 调用记录 | AiCallLogger（场景 news_*） |
| 取消请求 | postCompletionCancelable（离开面板/页面时取消） |

---

## 七、UI/UX 设计

### 7.1 设计原则

- 与现有主题系统完全一致：themeState.palette.* + GlassStyle + 全局字号档位，深色/毛玻璃/自定义背景全部生效
- **资讯优先的信息密度**：列表项标题 2 行、摘要 2 行、来源+时间一行，缩略图 96×72 右对齐（小图卡）
- 头条/大图卡：频道首条可用大图卡（可选 Swiper 轮播，P1）
- 已读样式：标题颜色降级 + 左侧细竖线标记

### 7.2 AI 交互细节（全部手动触发，符合确认决策）

| 交互 | 细节 |
|------|------|
| AI 摘要 | 详情页操作条「🤖 摘要」→ 底部弹层 → 流式输出 → 可复制；再次点击重新生成；显示「将把文章内容发送至您配置的模型服务商」轻提示 |
| AI 翻译 | 「🌐 翻译」→ 弹层选择 英→中 / 中→英 → 流式输出译文 |
| 问 AI | 「💬 问AI」→ 面板输入问题 → 流式回答 → 可连续追问（正文作为固定 system 上下文） |
| AI 今日要闻 | 首页卡片「📰 AI 今日要闻 [生成]」→ 非流式生成 → 结果存入 news_digests 并展示在卡片内 → 可「重新生成」「朗读」「复制」 |
| 为你推荐 | 频道栏「为你推荐」→ 首次进入提示需先阅读/收藏几篇 → 生成后展示排序列表 |

### 7.3 详情页（NewsDetail.ets）

- 头部：返回 + 来源/时间 + 标题 + 头图
- 操作条：⭐收藏 / ✔已读（P0）；🤖摘要 / 🌐翻译 / 💬问AI / 🔊朗读（P1/P2）
- 正文：ArkWeb 加载原文；深色模式注入 CSS
- fallback：ArkWeb 失败 → 本地渲染标题+摘要 + 「用系统浏览器打开」

### 7.4 大屏适配

- 沿用 isSm/isMd/isLg 三档
- 平板/横屏（isLg）：资讯首页可切换**双栏**（左频道列表 + 右详情，参考 multi-news-read），P2

---

## 八、性能与稳定性

| 项 | 方案 |
|----|------|
| 长列表 | LazyForEach + 现有 LazyDataSource |
| 图片 | Image 懒加载 + 缩略图 LRU 缓存 |
| 网络 | 8s 超时、失败重试 1 次、并发上限 3 源、10 分钟缓存节流 |
| AI 请求 | 可取消；正文截断 8000 字符；摘要/翻译逐字节流渲染（复用 Chat 的流式渲染定时器思路） |
| 详情页 | 离开销毁 Web 组件与请求 |
| 后台 | P0/P1 无后台轮询；P2 评估 WorkScheduler |
| 缓存上限 | 收藏不设限；news_digests 按日期保留最近 30 条 |

---

## 九、安全与合规

- 只展示标题/摘要/封面并链接原文；正文 ArkWeb 加载原文站点，**不搬运全文**
- AI 摘要/翻译/问AI/日报 均显式提示「将把文章内容发送至您配置的模型服务商」
- 收藏/已读/日报全部本地存储，不上传第三方
- 仅需已有 ohos.permission.INTERNET
- 内置源仅选公开接口/官方 RSS；商业 API 用户自填 key

---

## 十、测试方案

- 单元：NewsServiceTest（知乎日报/HN/RSS fixture 解析 + 派生频道过滤）、NewsAiServiceTest（prompt 构造、截断、手动触发降级）、NewsRepositoryTest（收藏去重、已读、日报缓存）
- 页面：资讯首页加载/刷新/频道切换/加载更多、详情 ArkWeb 失败 fallback、收藏流程、AI 摘要流式渲染与取消、日报生成与缓存
- 回归：原 4 Tab 导航、游戏入口（Games Tab）、主题/深色/字号、返回键

---

## 十一、里程碑（重排）

| 阶段 | 内容 | 预估 |
|------|------|------|
| M1 | 数据模型 + NewsService（知乎日报/HN/RSS）+ 新 Index 资讯首页（频道+列表+刷新/加载）+ NewsDetail（ArkWeb）+ 导航接入 | 3~4 天 |
| M2 | 收藏/已读 RDB + 操作条 + 我的页新入口 + 主题/大屏适配 + 回归（游戏功能不受影响） | 2~3 天 |
| M3 | AI 摘要（手动）/翻译/问AI + AiCallLogger + 降级策略 | 2~3 天 |
| M4 | AI 今日要闻 + 为你推荐 + 自定义 RSS + 设置页「资讯」分组 | 2~4 天 |
| M5 | 文档（README/DESIGN 定位更新）、回归测试、发布 | 1~2 天 |

---

## 十二、风险与对策

| 风险 | 对策 |
|------|------|
| 第三方接口/RSS 失效 | 源注册表 + 多源冗余 + 一键下线；上线前逐源实测 |
| 首页改造影响原导航 | Index 重写但保持 PageKey.Index 语义；AppShell 分支最小改动；M1 内回归 4 Tab |
| AI token 成本 | 摘要/翻译/问AI 全手动触发；正文截断；日报显式按钮；AiCallLogger 统计 |
| ArkTS 严格模式 | 模型集中在 NewsModels.ets；JSON 全 as 转型 |
| RSS 解析 | @ohos.convertxml + 兼容层 |
| 游戏功能降级引起不满 | 方案 A 保留 Games Tab 一键可达，功能零删除 |

---

## 十三、决策记录（v2.1 已确认）

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | 导航结构 | **方案 A**：4 Tab「资讯 / AI对话 / 游戏 / 我的」 |
| 2 | 默认频道与源 | 按设计：推荐/科技/AI专题/财经/国际 + 知乎日报、HN、少数派、IT之家、36氪、BBC中文；后续可增减 |
| 3 | AI 今日要闻 | 纳入 P1，**独立全屏页 NewsDigest** |
| 4 | 为你推荐 | P1 简单版（NewsAiService.recommend 已实现，UI 接入 P1 收尾） |
| 5 | 自定义 RSS | P2 |
| 6 | 平板双栏 | P2 |
| 7 | AI 摘要 | **手动触发、默认关闭**（已确认） |
| 8 | 产品定位 | 新闻为主功能，游戏为次要功能（已确认） |

## 十四、实现进度（v2.1）

| 里程碑 | 状态 |
|--------|------|
| M1 数据模型 + NewsService + 资讯首页 + NewsDetail + 导航接入 | ✅ 已实现（待真机构建验证） |
| M2 收藏/已读 RDB + 我的页入口 + 主题适配 | ✅ 已实现（RDB v14 三张表 + NewsFavorites + Profile 入口） |
| M3 AI 摘要/翻译/问AI + AiCallLogger + 今日要闻全屏页 | ✅ 已实现（NewsAiService + NewsDetail AI 面板 + NewsDigest） |
| M4 为你推荐页面 + 设置页「资讯」分组（源开关） | ✅ 已实现 |
| M5 README + DESIGN.md + 单元测试 | ✅ 已实现（NewsServiceTest / NewsAiServiceTest / NewsRepositoryTest） |
| 真机回归 | ⏳ 待用户在 DevEco 构建验证（编译已通过，当前阻塞于本地签名证书过期） |

> P2 已全部实现：自定义 RSS 订阅（设置页管理 + 并入推荐频道）、离线缓存（news_cache 快照回退）、新闻朗读（TTS）、平板双列网格。
> 剩余：真机运行验证与按反馈修复；可选：真·列表+详情双栏（当前为双列网格）。
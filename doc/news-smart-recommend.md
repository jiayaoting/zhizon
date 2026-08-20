# 智子「智能新闻推荐」设计文档（v0.7 定稿）

> 版本：v0.7（决策点全部确认）
> 关联应用：智子（Zhizon）· HarmonyOS NEXT · ArkTS/ArkUI · API 24
> 关联文档：[news-feature-plan.md](news-feature-plan.md) / [DESIGN.md](DESIGN.md) / M1 任务清单：[news-smart-recommend-m1.md](news-smart-recommend-m1.md)
>
> **实现进度**：M1 标签+赞踩闭环 ✅ ｜ M2 权重排序 ✅ ｜ M3 外文翻译 ✅ ｜ M4 LLM 智能标签 ✅ ｜ M5 应用内「为你精选」✅
> （以上均为代码完成，待 DevEco Studio 构建与真机冒烟验证）
> **M5 系统通知（NotificationKit 推送 + 定时调度）：已出方案，用户决定暂缓，不做**
> **增强项**：个性化模式（标准/高个性化/仅热点/探索）✅ ｜ 事件 90 天清理 ✅ ｜ 隐式信号埋点（点击/阅读/收藏/分享）✅ ｜ 单篇软降权（不再硬排除）✅ ｜ 标签词典扩充至 18 类 ✅

---

## 一、概述与目标

把「推荐」相关资讯流从**纯时间排序**升级为**标签级个性化排序**：

- 每条新闻自动打标签，展示在卡片与详情页；
- 点赞 = 一键给该篇全部标签加权，之后同类多推；
- 点踩 = 弹层让用户**自己勾选**要减少的标签（默认不选中），不勾选则仅本篇降权；
- 赞/踩是**累积权重**（次数 + 时间衰减），不是二元开关，**永不永久拉黑**；
- 权重算法**默认不接入大模型**，纯本地可跑；LLM 作为可选增强（智能标签），默认关闭；
- 翻译默认用资讯功能模型，可单独设置并记忆翻译模型；
- 个性化默认作用于**全部频道**，每个频道可单独开关，动态适配频道增减。

## 二、设计原则

1. **本地优先**：权重算法、L1 标签、语言识别全部离线可跑，不依赖模型/网络；
2. **手动触发**：所有 AI 能力（翻译、LLM 标签）手动触发，不自动批量消耗；
3. **可降级**：LLM 失败/未配置/无网络时自动回退 L1 规则，不影响阅读；
4. **可解释**：标签、权重、推荐理由对用户可见可管理；
5. **隐私**：行为/画像/翻译缓存全部本地存储；调用外部模型时显式提示；
6. **防茧房**：探索槽 + 「仅热点」模式 + 频道独立浏览。

## 三、总体架构

```
┌────────────────────────────────────────────────┐
│  表现层：Index / NewsCard / NewsDetail /         │
│          NewsLikes / NewsRecommend / Settings    │
├────────────────────────────────────────────────┤
│  排序层：NewsRanker（过滤→打分→多样性→探索→缓存）  │
├────────────────────────────────────────────────┤
│  画像层：NewsProfileService（posTags/negTags/…） │
├────────────────────────────────────────────────┤
│  采集层：NewsBehavior（赞/踩/点击/阅读/翻译事件）  │
├────────────────────────────────────────────────┤
│  服务层：NewsService（打标签/语言识别/取流）       │
│          NewsAiService（标签LLM/翻译LLM）         │
├────────────────────────────────────────────────┤
│  存储层：RDB v15（标签/赞踩/画像/翻译缓存/事件）    │
└────────────────────────────────────────────────┘
```

## 四、标签体系

| 级别 | 方式 | 成本 | 生效条件 |
|------|------|------|----------|
| L1 规则标签（默认） | 频道标签 + 预置词典 `TAG_KEYWORDS` 关键词命中 + 来源标签；去重后取 3~8 个 | 0 | 始终生效 |
| L2 LLM 标签（可选） | 所选模型生成 3~8 个细粒度标签（JSON 输出），按 url 缓存 24h | 按模型计费 | 设置开启后生效；失败自动回退 L1 |

- 标签落库 `news_tags`，随频道快照（`news_cache`）缓存；
- 卡片展示 1~3 个 chips；详情页展示完整标签区，每个标签可「少推此类」；
- 语言识别：归一化时字符检测（CJK 占比 < 5% → 外文），内置源可预置语言，结果存 `NewsItem.language`（翻译功能用，M3）。

## 五、反馈模型（权重制）

| 操作 | 规则 |
|------|------|
| 👍 点赞 | 一键，自动该篇全部标签 `posTags[tag] += 1`，**不用选标签**；文章进「我的点赞」 |
| 👎 点踩 | 弹层标签多选，**默认一个都不选**；勾选标签 → 各自 `negTags[tag] += 1`；**不勾选直接确认 → 仅本篇降权**（`news_exclusions` url 级 + urlPenalty） |
| 取消赞 / 撤销踩 | 对应权重 −1（最小 0）；Toast 撤销回滚本篇与标签贡献 |
| 时间衰减 | 权重 × 0.9^(天数/7)，半衰期约一周 |

**权重语义**：赞/踩是累积数值。点踩次数越多 → 负权重越大 → 该类推送占比越低，但**永不永久拉黑**（探索槽保留 5%~10% 概率露出，用户可重新点赞拉回）。

## 六、权重算法（纯本地，默认不接大模型）

```
score(item) =
    α · Σ posW[命中标签]                  // 点赞累积正向
  − β · Σ f(negW[命中标签])               // 点踩累积负向，f = min(x, 8) 或 log(1+x)
  + γ · 频道亲和分                        // 常看频道加权
  + δ · 来源亲和分                        // 常看来源加权（可负）
  + ε · 新鲜度分                          // 24h 内高权重，7 天后衰减
  + ζ · 探索分                            // 防茧房
  − η · urlPenalty[本篇]                  // 单篇被踩降权
```

参数约定（集中在 `NewsRanker` 顶部常量，可调、可单测）：

| 参数 | 建议值 | 说明 |
|------|--------|------|
| α | 1.0 | 正标签系数 |
| β | 1.5~2.0 | 负向系数 > 正向（不喜欢更可信） |
| f(x) | min(x, 8) 或 log(1+x) | 负权重压缩曲线：次数越多扣越多但渐近平缓 |
| ε 新鲜度 | 24h 内峰值，7 天基本归零 | 时效性 |
| ζ 探索 | 每屏 5%~10% 概率 | 永不永久拉黑 + 防茧房 |
| 多样性 | 同标签每屏 ≤40%，同源连续 ≤3 条 | 防霸屏 |

**示例**（画像 posW{AI:5, 芯片:3}，negW{娱乐:6}，α=1，β=2，f=log(1+x)）：

| 候选标签 | 计算 | 得分 |
|----------|------|------|
| [AI, 芯片, 科技] | +1×(5+3) − 0 + 频道0.5 + 来源0.3 + 新鲜0.8 | ≈ 9.6（排前） |
| [娱乐, 明星] | +0 − 2×log(1+6) + 新鲜0.6 | ≈ −3.3（排后，不删除） |

「娱乐」被踩 1/3/8 次的扣分：0.69 / 1.39 / 2.20 —— 次数越多扣分越多但越来越缓，即"按次数权重决策"。

## 七、排序管线与频道个性化

```
fetchChannel(channelId)：
  if 该频道个性化开启（关闭列表不含该 id）：
      全源合并 → 打标签（L1，可选 L2）→ 过滤（仅 url 级）→ 权重打分 → 多样性 + 探索 → 缓存
  else：
      保持现有纯时间排序（现状逻辑，零影响）
```

**个性化作用域（v0.7 定稿）**：

- 默认：**全部频道启用个性化**；
- 每个频道可在设置中单独关闭（关闭 = 恢复纯时间排序）；
- 存储用**关闭列表**（settings key `newsPersonalizedChannels`，默认 `[]`）：新增频道不在列表内 → 自动默认个性化，**动态适配频道增减，无需改业务代码**；
- 设置页用 `ForEach(NEWS_CHANNELS, …)` 动态遍历频道注册表渲染开关。

## 八、外文翻译

| 项 | 设计 |
|----|------|
| 识别 | 归一化时字符检测（CJK 占比 <5% → 外文），内置源预置语言；结果存 `NewsItem.language` |
| 卡片入口 | 外文新闻显示 `EN` 徽标 + 「🌐 译成中文」→ 轻量翻译**标题+摘要**（非流式），卡片内原文/译文切换 |
| 详情页 | 复用现有全文翻译（`NewsAiService.translate`），外文新闻**默认方向自动 = 外文→中文**；中文新闻仍可中→英 |
| 缓存 | `news_translations`：卡片译 30 天 / 全文译 7 天，重复阅读零调用 |
| 触发 | 全部手动，不自动翻译 |
| 截断 | 复用 8000 字符截断；调用记入 `ai_call_logs`（scene `news:translate`） |
| 可选信号 | 主动翻译 = 弱正反馈（`ai_translate +1`，P1 可选） |

## 九、模型接入设计（三级模型，均可单独设置并记忆）

### 9.1 模型记忆位（settings 表 key）

| Key | 默认 | 用途 |
|-----|------|------|
| `newsModelId`（现有） | 跟随全局活跃模型 | 资讯功能模型：摘要/问AI/今日要闻/翻译默认 |
| `newsTagLlmEnabled` | `'false'` | 智能标签总开关，**默认关闭** |
| `newsTagModelId` | `''` | 智能标签模型，**单独记忆** |
| `newsTranslateModelId` | `''` | 翻译模型，**单独记忆** |

### 9.2 解析规则

```
智能标签模型 = newsTagLlmEnabled = true
                ? (newsTagModelId 有效 ? newsTagModelId : newsModelId)
                : 不调用
翻译模型     = newsTranslateModelId 有效 ? newsTranslateModelId : newsModelId
```

- `''` = 跟随资讯功能模型；用户改选后存具体模型 id，即"单独记忆"；
- 模型选择器第一项固定「跟随资讯模型（默认）」；
- 只列出「已启用且已配置」的模型（复用 `NewsAiService.listModels()`）；
- 三个记忆位互不影响：改资讯模型不影响已记忆的标签/翻译模型。

### 9.3 设置页 UI（设置 → 资讯）

```
┌─ AI 智能标签 ──────────────────┐
│ 智能标签         [开关] ← 默认关  │
│ 标签模型  [跟随资讯模型 ▾]        │ ← 默认跟随，可改，单独记忆
│   · 开启后：将把新闻标题/摘要发送 │
│     至所选模型服务商             │
│ 清除标签缓存       [清除]        │
├─ AI 翻译 ─────────────────────┤
│ 翻译模型  [跟随资讯模型 ▾]        │ ← 默认跟随，可改，单独记忆
│   · 将把文章内容发送至所选模型服务商│
│ 清除翻译缓存       [清除]        │
└───────────────────────────────┘
```

- 首次开启/改翻译模型时弹隐私提示；
- 降级：模型无效/调用失败 → 标签回退 L1、翻译提示失败，不影响阅读。

## 十、数据模型（DB_VERSION 14 → 15）

```sql
-- 每条新闻标签缓存（L1/L2 统一落库）
CREATE TABLE IF NOT EXISTS news_tags (
  url TEXT PRIMARY KEY,
  tags_json TEXT NOT NULL,          -- ["AI","芯片","科技"]
  source_type TEXT DEFAULT 'rule',  -- rule / llm
  model TEXT DEFAULT '',
  updated_at INTEGER NOT NULL
);

-- 赞/踩状态（UI 展示与反馈管理用）
CREATE TABLE IF NOT EXISTS news_ratings (
  url TEXT PRIMARY KEY,
  rating INTEGER NOT NULL,          -- 1=赞 / -1=踩 / 0=取消
  item_id TEXT DEFAULT '',
  title TEXT NOT NULL,
  tags_json TEXT DEFAULT '',        -- 点赞=该篇全部标签；点踩=用户勾选（可为空）
  updated_at INTEGER NOT NULL
);

-- 行为流水（可审计、可重算画像，90 天清理）
CREATE TABLE IF NOT EXISTS news_events (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  item_id TEXT DEFAULT '',
  event_type TEXT NOT NULL,         -- impression/click/read/favorite/share/like/dislike/undo/translate/...
  weight REAL DEFAULT 0,
  extra_json TEXT DEFAULT '',
  occurred_at INTEGER NOT NULL
);
CREATE INDEX idx_news_events_url ON news_events(url);
CREATE INDEX idx_news_events_time ON news_events(occurred_at);

-- 单篇排除（点踩未勾选标签时）
CREATE TABLE IF NOT EXISTS news_exclusions (
  type TEXT NOT NULL,               -- url
  value TEXT NOT NULL,
  reason TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  PRIMARY KEY (type, value)
);

-- 画像快照（posTags/negTags/categoryWeights/sourceWeights）
CREATE TABLE IF NOT EXISTS news_profile (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- 翻译缓存
CREATE TABLE IF NOT EXISTS news_translations (
  url TEXT PRIMARY KEY,
  kind TEXT NOT NULL,               -- title / body
  lang_pair TEXT NOT NULL,          -- en->zh / zh->en
  text TEXT NOT NULL,
  model TEXT DEFAULT '',
  updated_at INTEGER NOT NULL
);
```

现有表（`news_favorites` / `news_read` / `news_digests` / `news_cache` / `news_article_cache`）保持不变。

## 十一、UI/UX 全景

| 位置 | 内容 |
|------|------|
| 卡片 | 标签 chips（1~3 个）+ `EN` 徽标 + 「🌐 译成中文」（外文）+ 👍/👎 + `⋯` 菜单 |
| 点踩弹层 | 标签多选面板，**默认不选中**，按命中强度排序，确认/取消 |
| 详情页 | 标签区（每个可「少推」）+ 操作条 [👍赞] [👎踩] [⭐收藏] [🌐翻译] [🤖摘要]… |
| 我的点赞（新页） | 赞过文章列表、取消赞、转收藏 |
| 反馈管理 | 每个标签展示「赞×N 踩×N」，可删除负权重 / 清零 / 恢复 |
| 资讯统计 | 兴趣标签云 + 厌恶标签云 + 翻译次数 |
| 设置 | 个性化开关与模式（标准/高个性化/仅热点/探索）、**个性化频道逐频道开关**、三级模型选择、缓存清除、重置画像 |

## 十二、设置项清单（settings 表）

| Key | 默认 | 说明 |
|-----|------|------|
| `newsModelId` | 现有 | 资讯功能模型（摘要/翻译默认/问AI/今日要闻） |
| `newsTagLlmEnabled` | `'false'` | 智能标签开关 |
| `newsTagModelId` | `''` | 智能标签模型（空 = 跟随资讯模型） |
| `newsTranslateModelId` | `''` | 翻译模型（空 = 跟随资讯模型） |
| `newsPersonalizedChannels` | `'[]'` | **关闭个性化**的频道 id 数组（空 = 全部个性化；新增频道自动默认开） |
| `newsPersonalizedMode` | `'standard'` | 个性化模式：standard / aggressive / hot / explore |
| `newsEnabledSources` | 现有 | 源开关 |
| `newsCustomRss` | 现有 | 自定义 RSS |

## 十三、改动文件清单

| 文件 | 改动 |
|------|------|
| `common/NewsModels.ets` | `NewsItem.tags`、`NewsItem.language`、`NewsRating` 等模型 |
| `common/NewsChannels.ets` | `TAG_KEYWORDS` 预置标签词典 |
| `service/NewsService.ets` | L1 打标签管线、语言识别、频道个性化分派 |
| `service/NewsAiService.ets` | L2 标签生成（JSON）、翻译方向自动、三级模型解析 |
| `service/DatabaseHelper.ets` | v15 五张新表 |
| `service/NewsRepository.ets` | 标签/赞踩/画像/翻译缓存读写、事件写入 |
| 新增 `service/NewsBehavior.ets` | 事件埋点与权重归一化 |
| 新增 `service/NewsProfileService.ets` | 权重累积/回退/衰减 |
| 新增 `service/NewsRanker.ets` | 打分/多样性/探索/缓存 |
| `components/NewsCard.ets` | chips、徽标、译按钮、赞踩、`⋯` 菜单 |
| `pages/Index.ets` | 点踩弹层、即时移除、撤销 |
| `pages/NewsDetail.ets` / `NewsDetailPane.ets` | 标签区、赞踩、翻译方向自动 |
| 新增 `pages/NewsLikes.ets` | 我的点赞 |
| `pages/NewsStats.ets` / `pages/Settings.ets` | 画像展示、模型选择与开关、个性化频道开关、反馈管理 |
| 路由 `common/Navigation.ets` / `AppShell.ets` / `main_pages.json` | 注册 NewsLikes 等新页 |
| `entry/src/test/*` | 语言识别/标签/权重/排序/翻译缓存测试 |

## 十四、里程碑

| 阶段 | 内容 | 预估 |
|------|------|------|
| M1 | 标签 L1 + 赞/踩交互 + 点踩弹层（默认不选）+ 状态持久化 + 撤销 + 我的点赞 + 频道个性化开关 | 3~4 天 |
| M2 | 权重排序：posTags/negTags 累积+衰减、NewsRanker 打分、多样性/探索、反馈管理、统计画像 | 2~3 天 |
| M3 | 外文翻译：语言识别、卡片轻量译、详情方向自动、翻译缓存、翻译模型设置 | 2~3 天 |
| M4 | LLM 智能标签：开关（默认关）、默认跟随资讯模型、单独记忆、JSON 打标签、降级 | 1~2 天 |
| M5 | 推送（P2 可选）：个性化早报/热点通知，推送频次随标签权重收敛 | 3 天 |

## 十五、验收指标

1. 点踩勾选「AI、芯片」→ 24h 内这两类内容占比下降 ≥50% 且**不归零**；
2. 同一标签点踩 1/3/8 次呈现明显梯度差异（验证"按次数权重决策"）；
3. 点赞后同类内容占比上升；取消赞后回退；
4. 外文识别准确率 ≥95%；卡片翻译 5 秒内出译文；重复阅读零调用；
5. 智能标签默认关时零模型调用；开启后默认走资讯模型，改选后单独记忆且互不影响；
6. 关闭某频道个性化 → 该频道恢复纯时间排序；新增频道自动默认个性化；
7. 模型失效/无网络 → 自动降级 L1/提示，不影响阅读；
8. 全部行为数据本地存储，可一键重置。

## 十六、风险与对策

| 风险 | 对策 |
|------|------|
| 信息茧房 | 探索槽 + 「仅热点」模式 + 频道独立浏览 |
| 误触点踩 | Toast 撤销 + 反馈管理恢复 |
| LLM 成本 | 智能标签默认关、结果缓存、翻译缓存、截断、手动触发 |
| 模型切换混乱 | 三级模型统一「跟随资讯模型」默认 + 单独记忆 + 设置页清晰分组 |
| 标签不准 | L2 失败回退 L1；词典持续补充 |
| 频道扩展 | 关闭列表存储 + `ForEach(NEWS_CHANNELS)` 动态渲染 |
| ArkTS 严格模式 | 模型集中、JSON 全 `as` 转型（沿用现有风格） |

## 十七、决策记录（全部已确认）

| # | 决策 | 状态 |
|---|------|------|
| 1 | 点赞一键，自动全标签 +1，不选标签 | ✅ |
| 2 | 点踩弹层默认不选中；勾选标签 −1；不勾选仅本篇降权 | ✅ |
| 3 | 赞/踩是累积权重 + 时间衰减，不永久拉黑 | ✅ |
| 4 | 标签：L1 规则默认；L2 LLM 可选 | ✅ |
| 5 | 权重算法默认不接大模型；开启后默认跟随资讯模型，可改并单独记忆 | ✅ |
| 6 | 翻译默认用资讯模型，可单独设置并记忆翻译模型 | ✅ |
| 7 | AI 精排不做（权重公式已够） | ✅ |
| 8 | 翻译手动触发 + 缓存；外文默认外文→中文 | ✅ |
| 9 | 个性化默认全部频道；每频道单独开关；关闭列表存储，动态适配增减 | ✅ |
| 10 | 推送为 P2 可选 | ✅ |

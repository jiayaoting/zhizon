# 智子「智能新闻推荐」M1 开发任务清单

> 阶段目标：**标签 L1 + 赞/踩交互闭环 + 频道个性化开关**
> 依据：[news-smart-recommend.md](news-smart-recommend.md)（v0.7）
> 前置：DB_VERSION 14 → 15；全部改动遵循 ArkTS 严格模式（模型集中、JSON 全 `as` 转型）
>
> **状态**：M1 代码已完成（14 项任务全部落地），待 DevEco Studio 构建验证；M2~M4 已按设计文档继续实现。

## 一、任务拆解（建议按顺序执行）

| # | 任务 | 涉及文件 | 验收标准 |
|---|------|----------|----------|
| 1 | **数据模型扩展**：`NewsItem` 增加 `tags: string[]` 与 `language: string`；新增 `NewsRating` 模型 | `common/NewsModels.ets` | 编译通过；旧构造调用不受影响（新增字段带默认值） |
| 2 | **标签词典**：新增 `TAG_KEYWORDS`（标签→关键词映射，覆盖频道标签/来源标签/常见主题） | `common/NewsChannels.ets` | 词典覆盖 5 个频道 + 30+ 常用主题词；条目格式统一 |
| 3 | **L1 打标签管线**：`tagItems()` 按词典命中 + 频道标签 + 来源标签生成，去重后取 3~8 个；归一化后调用；`language` 检测（CJK 占比） | `service/NewsService.ets` | 每条 NewsItem.tags 非空（可 0 个兜底）；中文/英文识别正确；不抛异常 |
| 4 | **快照携带标签**：`news_cache` 序列化/反序列化增加 tags（兼容旧快照） | `service/NewsRepository.ets` | 旧缓存可读（tags 缺失不报错）；离线回退后标签仍在 |
| 5 | **数据库 v15**：新增 5 张表 DDL（news_tags / news_ratings / news_events / news_exclusions / news_profile）并加入初始化数组 | `service/DatabaseHelper.ets` | 冷启动建表成功；旧库升级不丢数据（`CREATE TABLE IF NOT EXISTS`） |
| 6 | **赞/踩仓储**：`NewsRepository` 增加 rating 状态读写（setRating/getRating/listRatings）、事件写入（recordEvent）、单篇排除读写 | `service/NewsRepository.ets` | 状态可切换（1/-1/0）；事件可查；排除可加可删 |
| 7 | **卡片点赞**：`NewsCard` 增加 👍 按钮与已赞高亮；`Index` 处理点赞（写 rating + 事件 + Toast） | `components/NewsCard.ets` / `pages/Index.ets` | 点击后按钮态立即变化；重复点击取消赞；点赞不阻塞列表滚动 |
| 8 | **卡片点踩 + 弹层**：👎 按钮 → 弹出标签多选面板（**默认不选中**，选项 = item.tags，按命中强度排序）→ 确认后：勾选标签写 rating(-1) + 事件 + 本篇移除；未勾选 → 仅 url 排除 + 本篇移除 | `components/NewsCard.ets` / `pages/Index.ets` | 不勾选也能确认（仅本篇）；勾选后所选标签随事件落库；移除即时生效 |
| 9 | **撤销**：点踩 Toast 带「撤销」→ 恢复本篇 + 回滚 rating/事件/排除 | `pages/Index.ets` | 撤销后本篇回到列表原位置附近；画像/事件无残留 |
| 10 | **详情页赞/踩**：`NewsDetail` / `NewsDetailPane` 操作条增加 👍/👎（与卡片共用仓储，点踩弹层复用） | `pages/NewsDetail.ets` / `components/NewsDetailPane.ets` | 详情页赞/踩状态与列表一致；平板双栏同步 |
| 11 | **我的点赞页**：`NewsLikes` 列表（rating=1 的文章），支持取消赞/转收藏；注册路由（Navigation / AppShell / main_pages.json）；入口放资讯页顶部与 Profile | 新增 `pages/NewsLikes.ets` + 路由文件 | 列表正确；取消赞后从列表移除；返回导航正常 |
| 12 | **频道个性化开关**：settings key `newsPersonalizedChannels`（**关闭列表**，默认 `[]`）；设置页「个性化频道」分组（总开关 + `ForEach(NEWS_CHANNELS)` 逐频道开关，动态渲染）；`NewsService.fetchChannel` 分派：关闭 → 现有逻辑；开启 → M1 占位（现有逻辑 + url 排除过滤，M2 接 Ranker） | `pages/Settings.ets` / `service/NewsService.ets` / `service/DataRepository.ets` | 默认全部开启；关某频道后该频道不再个性化（M1 阶段行为差异仅 url 排除）；新增频道自动出现在设置列表 |
| 13 | **单元测试**：标签生成（词典命中/去重/上限/容错）、语言识别、rating 状态切换与事件写入、排除读写 | `entry/src/test/NewsServiceTest.ets` / `NewsRepositoryTest.ets` | 新用例全绿；旧用例不回归 |
| 14 | **构建与冒烟**：hvigor 编译通过；真机/模拟器冒烟：赞/踩/弹层/撤销/我的点赞/频道开关 | 工程构建 | 编译 0 错误；冒烟清单逐项通过 |

## 二、M1 明确不做（留给后续里程碑）

- ❌ 权重排序打分（M2：NewsRanker + NewsProfileService）
- ❌ 点赞/点踩对画像 posTags/negTags 的实际加权（M2 生效；M1 只落库）
- ❌ 外文翻译入口（M3）
- ❌ LLM 智能标签（M4）
- ❌ 推送（M5/P2）

## 三、风险提示

- **ArkTS 严格模式**：新表行结构一律显式 interface（如 `NewsRatingRow`），JSON 解析全 `as` 转型；
- **旧缓存兼容**：`news_cache` 反序列化对缺失 tags 字段必须容忍（M1 上线后旧快照仍可读）；
- **列表性能**：赞/踩状态查询按 url 批量预载（进入首页时一次加载 rating 集合），避免逐条异步查询；
- **弹层交互**：点踩弹层确认前可取消；确认后移除动作与撤销动作需在同一状态流内完成，防止竞态。

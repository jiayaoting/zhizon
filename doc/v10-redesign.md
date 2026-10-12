# 智子 App 重构方案（v10.0 · 华为原生拟物白）

> 状态：待实施 · 版本：v1.0 · 日期：2026-10
>
> 一句话定位：**从"深色终端风个人项目"重构为"符合 HarmonyOS 设计规范的精致内容 App"**。
> 视觉上对齐华为阅读 / 智慧助手·今天 / 华为浏览器 / 华为天气 / 华为音乐；交互上吸收即刻 / 夸克 / Notion / Apple News 的优秀细节；工程上向大项目收敛。
>
> 本方案已获用户确认的边界：**全范围（视觉/信息架构/工程架构都要）、华为原生拟物白风格、保留全部功能**。多主题系统收敛为可取舍项（见 §8.1）。

---

## 目录

1. [背景与目标](#一背景与目标)
2. [设计系统（Design Token）](#二设计系统design-token)
3. [信息架构（IA）](#三信息架构ia)
4. [各页面重构规格](#四各页面重构规格)
5. [工程架构](#五工程架构)
6. [分期实施计划](#六分期实施计划)
7. [验收标准](#七验收标准)
8. [待拍板取舍项](#八待拍板取舍项)
9. [风险与回退](#九风险与回退)

---

## 一、背景与目标

### 1.1 现状问题

| 维度 | 现状 | 问题 |
|---|---|---|
| 视觉语言 | tech-dark 深色终端风 | 与 HarmonyOS 官方"拟物白"调性不符，不够精致 |
| 主题系统 | 6 套配色 + 毛玻璃 + 自定义背景 + 字号档位 | 维护面大，白底适配差（毛玻璃在白底显脏） |
| 信息架构 | 5 Tab + 38 页面 | 首页层级散（问候/简报/Tabs/卡片流堆叠），入口深浅不一 |
| 工程架构 | V1/V2 混用（@Component 与 @ComponentV2 各约 50%）、42 个静态 service、4 个超大页（2000+ 行） | 状态管理不统一（@StorageLink + 手动 bump 总线并存），超大页难维护 |

### 1.2 参考对象与借鉴点

| 参考 | 借鉴点 |
|---|---|
| **华为阅读** | 书架/内容卡的大圆角白卡、发丝分割线、阅读页留白 |
| **智慧助手·今天** | 负一屏卡片信息流节奏、卡片内分组与缩进 |
| **华为天气** | 大字号层级、插画式空态、淡色底状态区 |
| **华为音乐** | 封面卡、毛玻璃底栏（底栏保留玻璃材质） |
| **华为浏览器/智慧助手** | 输入胶囊（圆角 24vp）+ 悬浮发送钮 |
| **即刻** | 信息流节奏、长按条目的快捷操作、关注列表组织 |
| **夸克** | 轻阅读首页、顶部搜索框形态 |
| **Notion** | 简洁层级、侧栏导航的信息密度 |
| **Apple News** | 大标题 + 分组头条 |

### 1.3 目标（一句话拆解）

1. **视觉**：全站切换到华为原生拟物白（亮色为默认，深色为一套），消除终端风。
2. **IA**：功能不动，导航与首页骨架重组，核心动作 ≤2 步可达。
3. **工程**：状态管理统一 @ComponentV2，分层收敛，超大页拆分。

---

## 二、设计系统（Design Token）

> 核心策略：**先换 token，再改页面**。把设计变量从现有 `ThemePalette` 平移到新 token 体系，所有页面只依赖 token，保证全站一致且后续可整体调。

### 2.1 色彩 token（拟物白为默认，深色为一套）

| Token | 拟物白（默认） | 深色 | 用途 |
|---|---|---|---|
| `bgBase` | `#F2F4F7`（华为灰底） | `#101418` | 页面大背景 |
| `bgSurface` | `#FFFFFF` | `#1B2128` | 卡片面 |
| `bgSurface2` | `#F7F8FA` | `#232B34` | 卡内次级/输入框/列表悬浮 |
| `bgElevated` | `#FFFFFF` | `#28303A` | 弹层/浮起卡 |
| `textPrimary` | `#0F1620` | `#F0F3F6` | 主文字 |
| `textSecondary` | `#5B6570` | `#A7B1BB` | 次文字 |
| `textTertiary` | `#98A1AA` | `#67727D` | 弱文字 |
| `primary` | `#007DFF`（华为蓝） | `#4A9CFF` | 品牌主色（强调/按钮/Tab 高亮） |
| `primaryBg` | `#007DFF14` | `#4A9CFF1F` | 主色淡底（选中态/标签背景） |
| `primaryHover` | `#2B93FF` | `#5FA8FF` | 按压态 |
| `primaryOnColor` | `#FFFFFF` | `#FFFFFF` | 主色上的文字 |
| `success` | `#16A34A` | `#34C759` | 成功 |
| `warning` | `#F59E0B` | `#FFCC00` | 警告 |
| `danger` | `#E84026` | `#FF5A3C` | 危险/删除 |
| `info` | `#007DFF` | `#4A9CFF` | 信息 |
| `border` | `#0F16200F` | `#FFFFFF12` | 发丝分割线 |
| `borderStrong` | `#0F16201A` | `#FFFFFF1F` | 强边 |
| `maskOverlay` | `#0000004D` | `#00000066` | 遮罩 |
| `statusBarContentColor` | `#0F1620` | `#F0F3F6` | 状态栏文字色 |
| `navBarContentColor` | `#0F1620` | `#F0F3F6` | 导航栏文字色 |

### 2.2 形状与间距（华为规范）

| Token | 值 | 用途 |
|---|---|---|
| `radiusLg` | `20vp` | 大卡（内容聚合卡：热榜源卡、简报卡、游戏卡） |
| `radiusMd` | `16vp` | 中卡（列表卡：收藏行、搜索行、会话行） |
| `radiusSm` | `12vp` | 小卡/内嵌（标签、按钮内嵌、模型选择器） |
| `radiusCapsule` | `24vp` | 胶囊（输入框、发送钮、快捷开关） |
| `radiusXl` | `28vp` | 弹窗/半模态 |
| `pagePadding` | `16vp` | 手机页边距（统一，不再 24vp 浮动） |
| `pagePaddingLg` | `24vp` | 平板页边距 |
| `rowHeight` | `56vp` | 标准列表行高 |
| `rowHeightCompact` | `48vp` | 紧凑列表行高（热榜条目） |
| `titleBarHeight` | `64vp` | 标题区 |
| `cardGap` | `12vp` | 卡片间距 |
| `sectionGap` | `24vp` | 分组间距 |
| `dividerIndent` | `16vp` | 左缩进分割线 |
| `touchTarget` | `44vp` | 最小触控目标 |

阴影规则：**内容卡无阴影**（用分割线/淡底分隔），仅顶栏/浮动按钮用 elevation 2 轻阴影。华为列表普遍无阴影。

### 2.3 字体层级（沿用 fs* 命名，重调档值）

| Token | 值 | 用途 |
|---|---|---|
| `fsDisplay` | 32 | 页头大字（仅大标题/空态插画字，克制使用） |
| `fsXl` | 22 | 页面标题（TopBar 大标题） |
| `fsLg` | 18 | 卡片标题 / 弹窗标题 |
| `fsMd` | 16 | **正文基准** |
| `fsSm` | 14 | 次文字 / 元信息 |
| `fsXs` | 12 | 角标 / 时间 / 标签 |

原则：华为 App 正文普遍 16~17，标题不超过 22，**避免 fs3xl 满天飞**（现状很多 32 大字被滥用）。字重：标题 Bold(500~600)，正文 Regular(400)，弱化 Normal(400 浅色)。

### 2.4 材质（毛玻璃的角色变化）

| 场景 | 拟物白 | 深色 | 说明 |
|---|---|---|---|
| 底部导航 / 侧边栏 | `COMPONENT_THIN` 玻璃 | 同 | **保留**，华为底栏常用半透明玻璃 |
| 悬浮条（进度/播放/输入胶囊底） | `COMPONENT_THIN` 玻璃 | 同 | **保留** |
| 内容卡片 | ❌ 纯白卡 | ❌ 纯深色卡 | **移除**玻璃态，白底上玻璃显脏 |
| 自定义背景图开启时 | 卡片降为半透明白 | 半透明深色 | 保可读性 |

`glassEnabled` 开关语义改为：**仅控制底栏/悬浮条的玻璃材质**，不再控制内容卡。

### 2.5 动效规范（对齐 HarmonyOS 自然动效）

| 场景 | 时长 | 曲线/方式 |
|---|---|---|
| 页面转场（push/pop） | 250~300ms | 系统默认路由动画 |
| 卡片按压 | 即时 | `stateEffect` 缩放 0.98 + 透明度 0.8 |
| 列表回弹 | 系统默认 | `edgeEffect(Spring)` |
| 下拉刷新 | 系统 Refresh | 自定义指示器用 primary 色 |
| Tab 切换 | 200ms | 下划线滑动（导航）/ 淡入（内容） |
| 长按菜单 | 200ms | bindMenu 弹出 |
| 半模态（openBindSheet） | 系统默认 | 用于筛选/模型选择/快捷操作 |

原则：**能用系统默认就不手写**；手写的动效只保留按压反馈和 Tab 下划线。

### 2.6 图标规范

- **导航/操作区**：线性矢量图标（Material Symbols 风，统一 22~24vp），替换 emoji
- **内容区**：emoji 保留点缀（成就、状态、简报条），更亲切
- 矢量图标来源：用系统 SymbolGlyph（HarmonyOS 内置 symbol 库）优先，无对应时引入开源 SVG → PixelMap 资源
- 图标颜色：跟随 textSecondary，选中态跟随 primary

---

## 三、信息架构（IA）

功能全部保留，重排入口。核心原则：**热榜是门面，AI 对话是生产工具，游戏是休闲，微舆是专业工具，我的是管理**。

### 3.1 底部 Tab（5 个不变，图标改矢量）

| Tab | 键 | 矢量图标 | 说明 |
|---|---|---|---|
| 热榜 | Index | `flame` / `newspaper` | 门面，启动默认页 |
| AI对话 | Chat | `chat_bubble` | 生产工具 |
| 游戏 | Games | `stadia` / `gamepad` | 休闲 |
| 微舆 | BettaFish | `fish` / `radar` | 专业 |
| 我的 | Profile | `person` | 管理 |

### 3.2 我的页（华为"我的"经典结构）

现状：身份卡 + 3 格数据卡 + 一堆入口行（且与首页/设置入口大量重复）。改为：

```
┌─ 头部账号卡（华为账号资料 / 未登录提示，可点登录）────────────┐
├─ 热榜数据 ─┬─ 收藏 ─┬─ 阅读周报 ─┬─ 数据与存储 ─┤
├─ 游戏 ─────┬─ 成就 ─┬─ 战绩统计 ─┬─ 对局回放 ─┬─ 排行榜 ─┤
├─ AI ───────┬─ AI 模型 ─┬─ 角色模板 ─┬─ AI 调用记录 ─┤
├─ 通用 ─────┬─ 设置 ─┬─ 关于（版本/协议/许可/数据源）─┤
└────────────────────────────────────────────────────────────────┘
```

每分组是**分组卡**（SettingGroupCard），行 56vp 高 + 左侧矢量图标 + 右侧箭头。

> 入口纪律（见 §3.5）：本页**不放**热榜设置、模型配置、服务器/账号的重复直达——它们统一收在 `通用 → 设置` 对应分组；本页只留"看"（收藏/周报/成就/战绩）与"账号 + 通用"。

### 3.3 核心动作路径（≤2 步）

| 动作 | 路径 |
|---|---|
| 看热榜 | 启动 → 热榜 Tab（1 步） |
| 关注源 | 热榜 → 源卡右上角 ⭐（1 步） |
| 强制刷新 | 热榜 → 下拉（1 步，登录用户） |
| AI 摘要条目 | 热榜 → 点条目 → AI 面板（2 步） |
| 配 AI 模型 | 我的 → AI 模型（2 步） |
| 登录 NewsNow | 我的 → 热榜设置 → 账号 → 登录（3 步，接受） |

### 3.4 菜单与层级设计规范（合理性 · 易用性）

> 目标：**任何功能 ≤3 步可达，同一功能只有一处主入口，设置与数据分层清晰，菜单文案与位置一致、可预期。**

#### 3.4.1 层级总原则

| 原则 | 规则 | 反例（现状） |
|---|---|---|
| 深度上限 | 任何功能 **≤3 步** 可达 | 登录 NewsNow 现在 3 步，可接受；不新增 >3 步路径 |
| 唯一主入口 | 一个功能只有 **1 个主入口**，其余为快捷入口 | 收藏/已读/周报在"首页头像区 + 我的页 + 设置"三处都有 |
| 树状不网 | 导航是树，不做互相跳的网 | 设置里又链回首页、首页又设"去设置"快捷，易迷路 |
| 同类归组 | 设置/数据按**域**分组（热榜/对话/游戏/微舆/账号/外观/安全/存储/关于） | 现状部分混排 |
| 危险后置 | 清空/重置/退出放组末 + danger 色 + 二次确认 | 现状已做，保持 |

#### 3.4.2 菜单类型与使用场景（固定约定）

| 类型 | 用在 | 规范 |
|---|---|---|
| **底部 Tab** | 5 大顶级功能 | 一级导航，不再增减；Tab 内页面用返回键回 Tab 首页 |
| **顶部操作区** | 当前页最高频 1~3 个动作 | 搜索/设置/分享/收藏，≤3 个，矢量图标，超 3 个进 overflow |
| **长按菜单（bindMenu）** | 条目/卡片的**对象级**操作 | 3~5 项，第一行为最常用；破坏性操作（删除）放最后 + danger |
| **半模态（openBindSheet）** | 筛选/模型选择/快捷设置 | 承载"选一选"类轻决策，可拖拽高度，不用于表单长输入 |
| **overflow 菜单** | 顶栏放不下的次级动作 | 文字菜单，分组排序，危险项置底 |
| **二级设置页** | 低频、需要说明/多控件 | 从设置分组进入，页面内不再套三级菜单（必要时用半模态替代） |

**反模式（禁止）**：① 同一动作同时出现在 Tab、首页快捷、我的页、设置四处；② 顶栏堆 >3 个图标；③ 用长按做"主流程必经"操作（长按只做快捷，主流程必须有点击可达路径）；④ 弹窗里套弹窗。

#### 3.4.3 文案与一致性

| 项 | 规范 |
|---|---|
| 动作文案 | 动词开头，≤6 字（"查看全部 / 立即同步 / 清空缓存"），不用"点击这里/点我" |
| 状态文案 | 名词/状态短语（"已生成 / 同步中… / 未登录"），不用长句 |
| 位置一致性 | 同一动作在所有页**位置固定**：搜索=顶栏右上、返回=顶栏左上、主操作=右下角/底部、危险=组末 |
| 图标语义 | 一个图标一个含义（🔍 只代表搜索，⭐ 只代表收藏/关注，⚙ 只代表设置） |
| 空态引导 | 空列表给"为什么空 + 下一步做什么"（按钮直达），不只说"暂无数据" |

#### 3.4.4 设置与数据的边界（避免"设置大杂烩"）

| 类别 | 归处 | 例 |
|---|---|---|
| **数据操作**（清空/备份/恢复） | 我的 → 数据与存储 | 清空已读、清空缓存、云备份/恢复 |
| **功能配置**（开关/参数/地址） | 我的 → 设置 → 对应分组 | 服务器地址、模型配置、音效开关、Agent 开关 |
| **账号** | 我的 → 账号区（置顶） | 华为账号、NewsNow 账号 |
| **外观** | 我的 → 设置 → 外观 | 主题、背景、字号、图标 |
| **关于** | 我的 → 通用 | 版本、协议、许可、数据源说明 |

#### 3.4.5 导航一致性（返回与层级）

- Tab 内二级页 → 返回键回该 Tab 首页（已有 `onBackPress` 逻辑，保持）
- 路由子页 → 返回键回来源页
- 全站统一：返回在顶栏左上 `‹`；首页（Tab 首页）不显示返回键
- 平板侧边栏选中态 = 当前 Tab + 当前子页高亮，避免"侧边栏无反馈"

### 3.5 入口去重审计（现状 → 收敛）

| 功能 | 现状入口（重复） | 收敛为 | 处理 |
|---|---|---|---|
| 收藏 | 首页头像区 + 我的 + 设置 | **我的 → 热榜数据** | 首页快捷移除，头像区不再放收藏 |
| 已读/周报 | 我的 + 设置 | **我的 → 热榜数据 → 阅读周报** | 设置里移除阅读周报快捷 |
| 热榜设置 | 首页 ⚙ + 我的 + 设置 → 热榜 | **设置 → 热榜**（主入口）；首页 ⚙ 作快捷保留 | 我的页移除直达，统一到设置 |
| 模型配置 | 对话页顶栏 + 我的 → AI 模型 | **我的 → AI 模型**；对话页只留**模型切换 chip**（不是配置） | 职责分清：切换≠配置 |
| 清空阅读记录 | 我的 → 周报 + 设置 → 数据 | **设置 → 数据与存储** | 周报页只读统计，不放清空 |
| 服务器/账号 | 热榜设置 + 我的 | **设置 → 热榜 → 服务器/账号** | 我的页不再重复 |
| 简报/今日要闻 | 首页简报条 + 我的 | **首页简报条**（主入口） | 我的页移除 |

> 收敛原则：**"看"的快捷留在门面页，"管"的入口统一收进我的/设置**，一处主入口，其余只留一处高频快捷。

---

## 四、各页面重构规格

### 4.1 首页（热榜）— 重构优先级 P1

**现状问题**：问候栏 + 简报卡 + 视图 Tabs + 源卡片流，层级散，问候语占一层高。

**新骨架**（对齐华为阅读书架 + 智慧助手·今天）：

```
┌─ 顶栏：大标题「热榜」（fsXl=22 Bold）+ 搜索🔍 + 设置⚙ ─┐
│   （无返回键；操作区 ≤2 个矢量图标，符合 §3.4.2）          │
├─ 简报条（40vp 胶囊）：🌤 今日要闻 · 未生成/已生成 › ──────┤
│   （玻璃/淡底胶囊，点击进 NewsDigest）                    │
├─ 视图 Tabs（吸顶）：关注 | 最热 | 实时 | 国内 | 科技 |     │
│   财经 | 国际 | 体育                                     │
│   华为式下划线选中态（不再用药丸按钮）                      │
├─ 内容区：源卡片流（大圆角 20vp 白卡，间距 12vp）          │
│   ┌──────────────────────────────────────┐              │
│   │ [徽标] 微博·实时热搜            ⭐ ↻  │              │
│   │ 更新于 10:24 · 25分钟前               │              │
│   │ 1  标题标题标题标题      热度 342万   │              │
│   │ 2  标题标题标题标题                   │              │
│   │ 3  标题标题标题标题                   │              │
│   │ ── 查看全部 30 条 › ──               │              │
│   └──────────────────────────────────────┘              │
│   ...下一张源卡                                          │
└──────────────────────────────────────────────────────────┘
```

> 菜单规范落地（§3.4.2）：顶栏仅 **搜索 + 设置** 两个操作；源卡右上角 ⭐/↻ 属卡片对象级操作；**收藏/已读不再放首页头像区**（收敛到我的 → 热榜数据，见 §3.5）。

**条目行规格**（HotItemRow 改造）：
- 序号：Top3 用 `#E84026 / #F97316 / #EAB308`，其余 textTertiary，宽 20vp，居中
- 标题：fsMd=16，Regular/Medium，2 行截断，行高 22vp
- 热度 info：fsXs=12 textTertiary，右对齐，单行截断
- 时间：fsXs=12 textTertiary
- 行高：48vp（紧凑），发丝分割线带 16vp 缩进
- 已读：标题改 textTertiary + Regular

**交互**：
- 下拉刷新：当前视图全源 `latest`（已登录），未登录只拉缓存；toast 华为式
- 长按源卡片 → bindMenu：关注 / 刷新 / 源站首页 / 查看全部
- 长按条目 → bindMenu：收藏 / 翻译标题 / 分享 / 复制链接
- 平板/折叠屏：isMd 2 列、isLg 3 列源卡片瀑布；条目点击进单源榜页

**空态**（华为插画式）：
- 关注视图为空：大 emoji/插画 + 「还没有关注的源」+ 「去看最热榜」按钮
- 服务器不可达：顶部淡黄警示条（warningBg）+ 「去设置」文字钮
- 加载中：居中 LoadingProgress + 「正在加载热榜…」

### 4.2 单源榜单页（HotBoard）— P1

```
┌─ 顶栏：‹ 返回 + 源徽标 + 源名 + 更新于 HH:mm + ⭐ + 🌐 ─┐
├─ 列表：完整 30 条，同首页条目行规格                       │
└─ 下拉刷新 = 单源 latest 抓取                              ┘
```
- 序号 Top3 红色、热度右对齐、已读弱化
- 空态/错误态：插画式 + 重试按钮

### 4.3 详情页（NewsDetail）— P1

```
┌─ 顶栏：‹ 返回 + 标题（2 行截断）+ 收藏 ☆ + 分享 ⤴ ─┐
├─ 内容：ArkWeb 加载 mobileUrl，下方 AI 工具条          │
├─ AI 面板（折叠）：摘要 / 翻译 / 问AI / 朗读           │
│   模型选择器内联（chip + 半模态选择）                  │
└────────────────────────────────────────────────────────┘
```
- 标题区改华为式顶栏（大标题区域收缩）
- AI 面板用半模态 openBindSheet 承载，避免长页
- 正文抽取失败时给「仅标题可用」提示

### 4.4 AI 对话（Chat）— P2

```
┌─ 顶栏：☰ 会话抽屉 + 标题（当前会话名）+ 模型名 chip ─┐
├─ 消息流：用户气泡（primary 底 + 白字，右侧）            │
│          AI 气泡（bgSurface2 + textPrimary，左侧）      │
├─ 输入胶囊（悬浮底）：圆角 24vp 输入框 + 发送钮          │
│   上方快捷条：🎙 语音 / 🌐 联网 / 📷 OCR / 斜杠 / 预算条 │
└────────────────────────────────────────────────────────┘
```
- 会话抽屉：左滑手势 + 华为式列表（56vp 行 + 重命名/固定/删除）
- 输入条对齐华为智慧助手（胶囊 + 悬浮发送）
- Agent 步骤面板：半模态展示工具执行步骤

### 4.5 游戏中心（Games）— P2

```
┌─ 顶栏：大标题「游戏」                                     ─┐
├─ 游戏卡网格（2 列）：图标大卡（60vp 图标）+ 名称 + 难度    │
│   对齐华为游戏中心的图标大卡样式                            │
├─ 底部：历史战绩 / 回放 / 排行 / 成就 入口卡                 │
└──────────────────────────────────────────────────────────┘
```
- 游戏卡：图标（各游戏 emoji/矢量）+ 名称 + 当前难度 + 最高分
- 长按游戏卡 → 查看帮助 / 难度切换

### 4.6 微舆（BettaFish）— P3（视觉统一即可）

专业工具，信息密度优先：
- 保持现有结构与功能
- 视觉接入新 token（白底/深色卡/分割线），状态卡改淡色底状态区
- 报告查看页保持 ArkWeb，顶栏华为化

### 4.7 我的（Profile）— P3

按 §3.2 的华为"我的"经典结构重做：头部账号卡 + 4 个分组卡（热榜数据 / 游戏 / AI / 通用）。

### 4.8 设置（Settings / NewsSettings / AppearanceSettings）— P3

- 维持现有分组结构，视觉接入新 token
- 行 56vp、左矢量图标、右箭头/开关/文字
- 危险操作（清空/重置）用 danger 色文字 + 二次确认弹窗（已有）

### 4.9 其他页面

- **NewsDigest / NewsFavorites / NewsSearch / NewsLogin**：接入新 token，列表/输入华为化
- **阅读周报 / 战绩统计 / 排行 / 成就 / 回放**：图表与卡片接入新 token，数据卡统一淡色底
- **协议/关于**：纯文本页，正文 fsMd 行高 24vp 留白

---

## 五、工程架构

### 5.1 状态管理统一（最大痛点：V1/V2 混用）

**现状**：`@Component`（V1：@State/@Prop/@Link/@StorageLink/@Watch）与 `@ComponentV2`（@Local/@Param/@Event/@ObservedV2/@Trace）各约 50%，同页混用导致刷新依赖 `@StorageLink` + 手动 bump 总线并存。

**方案**：**全部迁移到 @ComponentV2**（38 页面 + 25 组件）。

| 场景 | V1（淘汰） | V2（统一） |
|---|---|---|
| 页面内状态 | @State | @Local |
| 父子传参 | @Prop / @Link | @Param / @Event |
| 跨组件共享（主题/全局） | @StorageLink / @StorageProp | @ObservedV2 + @Trace + AppStorageV2.connect |
| 深嵌套 | @Provide / @Consume | @Provider / @Consumer |
| 监听变化 | @Watch | @Monitor |

**PageRefreshBus 保留**（宿主生命周期桥：AppShell.onPageShow 广播给嵌入的 Tab 页），但把魔法 string token（如 `chatRefreshToken`）改为 AppStorageV2 中对应 @ObservedV2 状态的 `@Trace` 字段，消除手写 token。

迁移顺序：先主题/全局状态（ThemeState 已 V2，把它从 @StorageLink 引用处切到 AppStorageV2.connect），再逐页迁移游戏与对话页（最大头），最后热榜与微舆（已是 V2 居多）。

### 5.2 服务层分层收敛

现状：42 个 service 全静态类，职责清但无域边界。改为目录分层（先不改类，只挪目录 + 改 import 路径）：

```
service/
├── hot/        # 热榜域：NewsNowClient / NewsNowAuth / NewsNowSync /
│               #        HotFeedStore / NewsRepository / NewsAiService
├── chat/       # 对话域：LlmClient / ChatRepository / ToolRegistry /
│               #        AgentOrchestrator / WebSearchService / SpeechService / OnDeviceAiService
├── game/       # 游戏域：GameAIService / *Engine / Achievement / Replay / Leaderboard / Sound / SudokuSolver
├── betta/      # 微舆域：BettaFishApiClient / BettaFishSseClient / BettaFishStore
├── platform/   # 平台域：DatabaseHelper / DataRepository / SecurityService / BiometricHelper /
│               #        CryptoHelper / CloudSyncService / HuaweiAccountService / PickerAdapter /
│               #        BackgroundImporter / SoundService / LiveViewService / WindowEnvironmentProvider
└── (model 保留在 common/model)
```

约束：**域之间禁止跨域直接 import 实现**（hot 不 import game 的实现），公共能力只走 platform。为后续 HAR 分包打底。

### 5.3 依赖注入（轻量，不引框架）

静态类保留（简单可靠），但把**可替换的单例**改为可注入 Provider：

| 单例 | 接口 | 默认实现 | 测试可注入 |
|---|---|---|---|
| NewsNowClient baseUrl / HTTP | `INewsNowClient` | NewsNowClient | FakeClient（返回桩数据） |
| HotFeedStore | `IHotFeedStore` | HotFeedStore | FakeStore |
| LlmClient | `ILlmClient` | LlmClient | FakeLlm |

收益：现有 10 个单元测试可直接覆盖 Store/Repository 逻辑，不依赖网络。

### 5.4 超大页拆分（跟随 chat P2 路线图）

| 页面 | 现状 | 拆分为 |
|---|---|---|
| Chat.ets | ~2000+ 行 | Chat 页 + 会话抽屉 + 消息列表 + 输入条 + Agent 步骤面板 |
| NewsDetail.ets | 大 | 详情页 + AI 面板 + 工具条 + 模型选择器 |
| Settings.ets | 大 | 设置页 + 分组卡组件（已有 SettingGroupCard，继续推） |
| NewsSettings.ets | 大 | 设置页 + 服务器区 + 账号区 + 关注管理区组件 |

拆分原则：组件只暴露 @Param/@Event，不感知 service；页面负责取数与编排。

### 5.5 不变的部分

- 数据层（DatabaseHelper / RDB v18 / FTS / 保留策略 / 迁移）不动
- 网络层 API 契约（NewsNow 三个接口 + 同步两个接口）不动
- 业务逻辑（榜单加载编排、同步防抖、AI 调用编排）不动，只换表现层与状态管理

---

## 六、分期实施计划

原则：**每步可独立编译验证、可独立发版；先 token 后页面，先门面后长尾，工程迁移穿插在 UI 稳定后做**。

| 期 | 范围 | 关键产出 | 预估 | 验收 |
|---|---|---|---|---|
| **P0 设计令牌** | 新 token 体系接入 ThemePalette；拟物白+深色两套；玻璃降级；fs 档值重调 | Theme.ets / ThemeState / ThemeContracts 换新，全站立刻变白 | 1 天 | 亮/深色切换无错位，token 全覆盖 |
| **P1 门面三页** | 首页 / 单源榜页 / 详情页按新 IA 重做；底部导航矢量图标；空态/错误态规范化；**入口去重（首页头像区快捷收敛）** | 核心体验焕新 | 2 天 | 首页/榜页/详情对齐 §4.1~4.3 规格 + §3.4/3.5 |
| **P2 对话+游戏** | Chat 拆件 + 输入胶囊华为化；游戏卡图标大卡化；对话气泡规范化；**模型切换 chip 与"我的 → AI 模型"职责分清** | 生产与休闲体验对齐 | 2 天 | 对话/游戏对齐 §4.4~4.5 + §3.5 |
| **P3 我的+设置+微舆** | 我的页华为化分组（去重复直达）；**设置层级按 §3.4.4 边界归位**；微舆视觉统一 | 全站风格闭环 | 1 天 | 我的/设置/微舆对齐 §4.6~4.8 + §3.4.4 |
| **P4 工程收敛** | @ComponentV2 全量迁移；service 分域目录；超大页拆分 | 架构债清偿 | 2 天 | 全仓 @ComponentV2，无 V1 装饰器残留 |
| **P5 打磨** | 动效、无障碍、字体自适、真机走查 | 上架级打磨 | 1 天 | §7 全项走查通过 |

建议先做 **P0**（风险最小，立刻见效），同时并行出 **P1 首页的高保真原型**给你过目，确认风格后再全量铺。

---

## 七、验收标准（对齐华为规范逐项走查）

### 7.1 设计令牌
- [ ] 色彩/圆角/间距/字体全部来自 token，全仓无硬编码 `Color.Black` / `#FFF` / `#FFFFFF`（除 token 定义处）
- [ ] 列表行高 56vp、发丝分割线、左缩进线，视觉对齐华为阅读
- [ ] 亮/深色两套 token 切换无错位、无闪白/闪黑
- [ ] 毛玻璃只出现在底部导航/侧边栏/悬浮条，内容卡无玻璃态

### 7.2 信息架构
- [ ] 核心动作路径符合 §3.3（≤2 步）
- [ ] 首页/榜页/详情/对话/游戏/我的 符合 §4 规格

### 7.3 菜单与层级（合理性 · 易用性）
- [ ] 任何功能 **≤3 步** 可达；无新增 >3 步路径
- [ ] 每个功能**仅一处主入口**，入口去重审计表（§3.5）全部落实
- [ ] 顶栏操作 ≤3 个矢量图标；超量进 overflow，无顶栏堆叠
- [ ] 长按菜单仅作快捷，主流程必有点击可达路径；删除项置底 + danger
- [ ] 同一动作在所有页**位置/图标/文案一致**（搜索/返回/设置/收藏语义唯一）
- [ ] 数据操作、功能配置、账号、外观、关于 按 §3.4.4 边界归位，设置无"大杂烩"
- [ ] Tab 内二级页返回键回 Tab 首页；路由子页回来源页；首页不显示返回键
- [ ] 空态均含"原因 + 下一步"引导按钮

### 7.4 工程
- [ ] 38 页面 + 25 组件全部 @ComponentV2，无 @State/@Prop/@Link/@StorageLink/@Watch 残留
- [ ] service 分域目录，无跨域 import 实现
- [ ] 单元测试覆盖 Store/Repository（注入 Fake Client 后可跑）

### 7.5 自适应与兼容
- [ ] 手机（底部 Tab）/ 平板（侧边栏）/ 折叠屏自适应无回归
- [ ] 平板侧边栏选中态 = 当前主 Tab 高亮（primaryBg 药丸）
- [ ] 真机走查：华为阅读/智慧助手·今天 并排对比，风格对齐

---

## 八、待拍板取舍项（已拍板）

### 8.1 多主题系统收敛 → **采纳 A**

| 选项 | 内容 | 代价/收益 |
|---|---|---|
| **A. 收敛为 2 套（√ 已选）** | 拟物白（默认）+ 深色；自定义背景与字号档位保留；6 套配色下架 | 维护面大减，白底适配专注；失去多配色个性化 |
| B. 保留 6 配色 | 6 套配色重映射到新 token | 工作量 ×2，白底下部分配色需重调 |
| C. 全删个性化 | 只留拟物白 + 深色，删自定义背景与字号档位 | 最简，但功能后退 |

落地：`buildPalette()` 忽略 `themeId`，统一返回华为蓝双套色板；`AppearanceSettings` 移除「颜色主题」分组与 `colorThemeSelector`；`colorThemeName` / `colorThemeColor` 已删除；`ColorThemeId` 枚举与 `colorTheme` 设置键保留（Preferences 快照/回滚链路仍引用，属兼容层，不再暴露 UI）。

### 8.2 图标风格 → **采纳混合方案**

导航/操作区使用系统矢量符号（`SymbolGlyph`，集中在 `common/AppIcons.ets`），内容区保留 emoji 点缀。

> **回退开关**：`AppIcons.USE_SYMBOL_ICONS`。若真机上出现图标空白（系统符号名不匹配），把该常量改为 `false`，全站导航/操作图标立即回退为 emoji（每个图标都配了 `*Emoji` 字段），无需改动各页面。

---

## 九、风险与回退

| 风险 | 缓解 |
|---|---|
| V2 迁移量大（38+25），易引入刷新回归 | 分期做，每期独立编译验证；先迁主题/全局，再迁页面；保留 PageRefreshBus 桥接直到全迁完 |
| 拟物白下部分配色（渐变/玻璃）失效 | token 双套覆盖，P0 期全站走查；自定义背景开启时卡片降半透明保底可读性 |
| 华为规范与现有功能冲突（如热榜信息密度） | 功能优先，密度高的页（微舆/详情）只做 token 接入不做 IA 大改 |
| 矢量图标资源引入 | SymbolGlyph 优先，缺失时按需引入少量 SVG，避免大图库 |
| 回退 | 每期为独立 commit/分支，可整期回退；token 与页面改动解耦，单独回退 token 不影响页面逻辑 |

---

## 十、实施记录（进行中）

### 10.1 P0 已完成

- **双套色板重写**：`Theme.ets` 的 `darkPalette` / `lightPalette` 全部换成华为规范值（亮色为默认拟物白）；`buildPalette()` 忽略 `themeId`，品牌主色统一华为蓝（亮 `#007DFF` / 暗 `#4A9CFF`）。
- **Token 扩展**：新增 `primaryBg / primaryBgStrong / primaryBgMedium / primaryOnColor / divider / successBg / warningBg / dangerBg / maskOverlay` 与 `radiusCapsule / pagePadding / pagePaddingLg / rowHeight / rowHeightCompact / titleBarHeight / cardGap / sectionGap / dividerIndent / touchTarget`。
- **字号重调**：`fsXs 12 / fsSm 14 / fsBase 15 / fsMd 16 / fsLg 18 / fsXl 22 / fs2xl 26 / fs3xl 32`（正文基准 16）。
- **毛玻璃降级**：`GlassStyle` 中 P1/P2 内容卡一律返回纯色面，`glassBlurStyle()` 仅 P0_BAR 返回模糊；玻璃只留在底栏/侧边栏/悬浮条。
- **6 套配色下架**：移除 `AppearanceSettings` 的「颜色主题」分组与 `colorThemeSelector`，删除 `colorThemeName` / `colorThemeColor`；`ColorThemeId` 枚举与 `colorTheme` 设置键保留（偏好快照/回滚链路仍引用）。
- **修复 14 处颜色 bug**：原代码大量使用 `palette.primary + '2A'` 这类「末尾追加 alpha」写法。ArkUI 的 8 位十六进制是 **ARGB（alpha 在前）**，因此这些颜色实际渲染为**全透明**（旧版「测试胶囊无底色」即此因）。已全部改为语义 token（`primaryBg` / `primaryBgStrong` / `primaryBgMedium` / `warningBg` / `dangerBg`），全仓已无该写法。
- **图标中心**：新增 `common/AppIcons.ets`，集中声明矢量符号 + emoji 回退 + `USE_SYMBOL_ICONS` 一键回退开关 + 主导航映射 `navIcon/navEmoji`（消除底栏/侧栏重复映射）。

### 10.2 编译期校准（两个重要发现）

1. **`sys.symbol.*` 名字在编译期校验**：初版 9 个猜测名无效，编译报 `Unknown resource name 'xxx'`。已依据 SDK 权威名单 `sdk/default/openharmony/ets/build-tools/ets-loader/sysResource.js`（7354 个符号）逐个校正：
   `bubble_left→message`、`ellipsis→more`、`square_and_arrow_up→share`、`chart_bar→ranking`、`trophy→medal`、`globe→website`、`photo→camera`、`slider_horizontal_3→slider_horizontal_2`、`server_rack→externaldrive`。
2. **`stateEffect` 只存在于 Button**（`Row` 上不存在，编译报 `Property 'stateEffect' does not exist on type 'RowAttribute'`）：全仓 15 处改为通用的 `.clickEffect({ level: ClickEffectLevel.LIGHT })`。
   另确认合法：`Refresh({ builder })`（`RefreshOptions.builder?: CustomBuilder`）、`bindMenu(Array<MenuElement>)`、`swipeAction({ end: { builder, actionAreaDistance }, edgeEffect })`。

### 10.3 P1 / P3 已完成

- **首页 Index**：问候语栏 → 大标题「热榜」+ 日期（`fsXl`）+ 搜索/设置两个矢量图标；今日要闻改 40vp 胶囊条；视图 Tabs 改华为式下划线；源卡流 `radiusLg` 白卡 + 发丝边框 + `cardGap`；空态含原因与 CTA。**入口去重**：头像/收藏快捷从首页移除。
- **HotBoard / NewsDetail**：顶栏操作区 ≤3 图标 + `⋯` overflow（`bindMenu`），列表白卡化，详情页 AI 工具条移到底部玻璃栏、AI 面板与模型选择器改半模态。
- **导航 chrome**：底栏 5 Tab 矢量图标 + `primary` 选中态 + P0 玻璃、侧边栏 `primaryBg` 药丸选中态、TopBar `fsXl` 标题 + 44vp 图标按钮 + 发丝下边线（safe-area 逻辑保持）。
- **我的页**：华为式「头部账号卡 + 4 分组（热榜数据 / 游戏 / AI / 通用）」，移除热榜设置、搜索、三格大卡等重复入口，统计改为账号卡内一行 meta。
- **设置页**：分组边界归位（账号云同步 / 外观 / 热榜 / 游戏 / Agent / 微舆 / 安全与隐私 / 关于）；移除热榜组「阅读周报」、整组「数据与存储」、Agent 组「AI 角色模板」等重复入口，并删除对应 `SettingActionId` 分支与死代码。
- **热榜设置**：全页 v10 化；抽出 `components/HotSourcePicker.ets`（`@Param focusIds` + `@Event onToggleStar`）。
- **微舆**：8 个文件去玻璃、语义状态色、按钮 44vp、日志 `fontMono`、Tab 改下划线、空态带 CTA。
- **公共组件升级**：`SettingGroupCard` / `SettingRow` 升级为 v10 白卡 + 56vp 行 + 发丝分割线 + `AppIcons.forward`；删除未被引用的 `SettingSwitchRow`（死代码）。

### 10.4 P2 已完成

- **AI 对话**（6 文件）：顶栏操作区 = 模型 chip + 搜索 + `⋯` overflow（清空会话 / 模型配置）；**模型 chip 只做切换**（半模态列出可用模型 + 「跟随全局模型」），不进配置页；输入区改**单一胶囊**（`radiusCapsule` + 发丝边框 + 悬浮 48vp 圆形发送钮），胶囊内保留 图片/OCR/语音 44vp 动作；用户气泡 = `primary` + `primaryOnColor` 右下尾巴、AI 气泡 = `bgSurface2` + 左下尾巴，最大宽 280/560vp；会话抽屉 56vp 行 + `primaryBg` 高亮 + 发丝缩进分割线，管理动作改为**左滑**（固定 / 重命名 / 删除 danger）；Markdown 仅换色换字号（代码块 `bgBase`、链接 `primary`）。
- **游戏中心**（14 文件）：`Games.ets` 改 2 列**图标大卡**网格（`radiusLg` 白卡 + 60vp 图标块 + 名称/元信息 + 长按 `bindMenu` 快捷），下方「游戏数据」列表卡（战绩 / 回放 / 排行 / 成就 / 设置）；6 个数据页令牌化（难度与胜负语义色、chip 胶囊化、白卡 + 56vp 行 + `List.divider`、空态 CTA）；7 个玩法页仅动遮罩/弹层/按钮圆角与前景文字色，**棋盘与棋子配色、全部游戏逻辑零改动**。
- **修复**：`ChatSessionDrawer` 的 `swipeAction` 原先在对象字面量的箭头函数里直接声明组件树（ArkTS 不支持）→ 改为「箭头函数内调用 `@Builder` 方法」，40 条编译错误清零。

### 10.5 P4 进行中

- **已完成**：`Settings` / `BettaFishPage` / `AppearanceSettings` / `ChatConfig` / `SettingRow` / `SettingGroupCard` / `AutoLockSheet` / `PasswordSheet` 迁移到 `@ComponentV2`（含 68 处 `this.palette → this.themeState.palette`、`@Prop → @Param`、回调 → `@Event`，公共参数名保持不变，调用点零改动）；同时修掉全仓唯一一处动态 `$r()`（应用图标预览改为 6 个字面量常量）。
- **宿主刷新统一**：V2 组件无法使用 `@StorageLink + @Watch` 观察 AppShell 的刷新令牌，故扩展 `PageRefreshBus`（hot / betta / chat 三路），`AppShell.onPageShow` 与 Tab 切换改为广播；`BettaFishPage` 已订阅总线，删除了令牌轮询兜底（原先从子页返回要等下一个 3s 轮询才刷新）。
- **Theme 状态镜像修复**：`ThemeManager` 原先只有 `publishInitialBackground()` 把背景状态写进 `ThemeState`，其余 5 处只写 AppStorage，导致 V2 页面读到过期值（「正在应用 / 背景失效」提示无法更新）。新增 `publishBackgroundState()` 双写 helper 并替换全部站点，`restoreBackground()` 同时镜像 `globalBackgroundUri` / `backgroundVisibleStrength`。
- **可注入单例（§5.3）**：新增 `service/hot/HotDataProvider.ets`——`IHotDataProvider` 契约 + `NewsNowHotDataProvider` 默认实现 + `HotDataProviders` 注册表（`inject` / `reset` / `get` / `isInjected`）；`HotFeedStore` 与 `NewsNowSync` 的取数调用全部改走注册表，生产行为不变，单测可注入 Fake。新增 `entry/src/test/HotDataProviderTest.ets`（契约、注入/复位、批量取榜、单源失败模拟）。

### 10.5b P4 完成情况

- **@ComponentV2 全量迁移 ✅**：38 个页面 + 27 个组件全部 `@ComponentV2`，全仓非注释 V1 装饰器残留 **0**（`@State/@Prop/@Link/@StorageLink/@StorageProp/@Watch/@ObjectLink/@Observed`）。含 7 个玩法页、`Chat.ets`（46 `@State` + 297 处 `palette` 引用）、5 个 Chat 子组件，以及 `ChatMessage` 的 `@Observed` → `@ObservedV2` + 12 个 `@Trace`（流式按字段原地更新仍可驱动重渲染）；`MineCell` 同样观测化。首个 **V2 → V1** 与 **V2 → V2** 混合边界均已编译验证通过。
- **service 分域目录 ✅**：43 个服务文件迁入 `hot/(7) chat/(10) game/(9) betta/(3) platform/(14)`，service 根目录零残留；跨域引用统一 `../<domain>/X`，域内 `./X`，对 ets 级目录改为 `../../<dir>/`（共重写 180+ 导入语句）。
- **超大页拆分 ✅（4 个目标页均已处理）**：
  | 页面 | 处理 | 行数变化 |
  |---|---|---|
  | `NewsSettings.ets` | 抽出 `components/HotSourcePicker.ets`（源选择器：`@Param focusIds` + `@Event onToggleStar`） | 787 → 716 |
  | `Chat.ets` | 抽出 `components/AiModelPicker.ets`（模型切换半模态，含「跟随全局模型」） | 2522 → 2186 |
  | `Settings.ets` | 行渲染改用共享 `SettingRow`（升级支持矢量图标 + 开关行），删除页内 `rowIcon`/`forwardArrow`/`settingRow` 三个重复构建器 | 747 → 612 |
  | `NewsDetail.ets` | 内联模型选择浮层改用共享 `AiModelPicker`（视觉同时对齐对话页：底栏半模态） | 1182 → 1066 |
  新增可复用组件：`HotSourcePicker`、`AiModelPicker`；`SettingRow` 扩展 `useSymbol/symbol/isSwitch/switchValue/onSwitchChange` 四个参数（emoji 用法向后兼容，AppearanceSettings 无需改动）。
- **可注入单例 ✅**：见上（HotDataProvider 注册表 + Fake 注入测试）。

### 10.6 P5 状态

- 已完成：按压反馈统一 `clickEffect`；主要按钮/图标补 `accessibilityText`；字号档位与 `fs*` 联动（P0）；全仓旧样式清理（`primaryDim` / 固定圆角 8/10 / 内容卡玻璃语义全部清零，`GlassLevel.P1/P2` 仅存于 `GlassEffect.ets` 定义处）；README / DESIGN / 本文档同步 v10（含 service 分层树与新增组件）。
- **入口去重核查（§7.3）实测**：`NewsFavorites` / `NewsSearch` / `ReadingReport` / `AiModelPage` / `AppearanceSettings` 均**只有一处主入口**；`NewsSettings` 主入口为「设置 → 热榜」，另有首页 ⚙ 与离线横幅「去设置」两个受限快捷（符合 §3.5「看留门面、管收设置」）。游戏数据 5 页由游戏 Tab（`GameToolEntry.route`）与我的页双入口提供，属设计规定。
- 待真机走查（本环境无设备，无法验证，故不作为阻塞项）：
  1. `sys.symbol` 矢量图标实际渲染效果 —— 若出现空白，将 `AppIcons.USE_SYMBOL_ICONS` 置 `false` 即可全站回退 emoji；
  2. 亮/深色切换、自定义背景透出（v10 起页面根背景为不透明 `bgBase`，自定义背景不再透出游戏/热榜 Tab，需确认是否符合预期）；
  3. 玩法页遮罩改 `maskOverlay` + 白卡后的浅色可读性；
  4. 列表滚动性能与手势（含会话抽屉左滑）；
  5. `AiModelPicker` 在两个页面的半模态观感一致性。

---


## 十、附：现状 → 目标速查

| 维度 | 现状 | 目标 |
|---|---|---|
| 视觉 | tech-dark 深色终端风 | 华为原生拟物白（亮默认 + 深一套） |
| 主题 | 6 配色 + 毛玻璃 + 自定义背景 + 字号档 | 2 套 + 保留自定义背景与字号档（取舍见 §8.1） |
| 首页 | 问候+简报+Tabs+卡片流 | 大标题+简报胶囊+下划线 Tabs+源卡流 |
| 导航图标 | emoji | 矢量（导航/操作）+ emoji（内容点缀） |
| 状态管理 | V1/V2 混用 | 全 @ComponentV2 |
| service | 42 静态类平铺 | 分域目录 + 可注入单例 |
| 超大页 | Chat/NewsDetail/Settings 2000+ 行 | 拆分为页 + 组件 |
| 数据/网络契约 | RDB v18 + NewsNow API | **不动** |

---

**文档版本**：v1.0（2026-10）· 状态：待实施 · 下一步：确认 §8 取舍项后启动 P0

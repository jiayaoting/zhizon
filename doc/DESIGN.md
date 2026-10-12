# 智子（Zhizon）详细设计文档

> **版本**：v9.0.0
> **平台**：HarmonyOS NEXT（鸿蒙 6+ / 纯血鸿蒙）
> **Bundle Name**：`com.zhizon.manager`
> **开发语言**：ArkTS
> **文档状态**：v9.0 当前实现版（5 Tab 导航 + NewsNow 热榜 + 7 款游戏 + AI 对话 + 多主题系统 + 毛玻璃效果 + AI 调用记录 + 华为账号云同步 + 对局回放 + 成就系统 + 游戏音效 + LazyForEach 长列表 + 端侧 OCR + 战绩可视化 + 排行榜 + AI 对话 Agent 化 P0）

---

## 一、产品概述

### 1.1 产品定位

**智子**是一款运行于鸿蒙 6+ 系统的**轻量休闲应用**，在手机/平板上提供：

- 🎮 **游戏中心**：俄罗斯方块、2048、贪吃蛇、扫雷、数独、中国象棋，5 级难度可选，支持 AI 托管
- 💬 **AI 对话**：接入多家大模型，本地保存对话，Markdown 富文本渲染
- 📱 **全设备自适应**：手机（底部 Tab）、平板、折叠屏自动适配
- 🎨 **外观系统**：华为拟物白（默认）/ 深色两套色板 + 自定义背景 + 底栏毛玻璃 + 全局字号档位 + 矢量图标中心 AppIcons
- 📊 **游戏战绩**：分数记录与历史排行

### 1.2 用户画像

| 角色 | 典型场景 |
|------|---------|
| 休闲用户 | 碎片时间玩小游戏放松，挑战高分 |
| AI 用户 | 用可配置的大模型对话、游戏 AI 托管对弈 |
| 个性化用户 | 主题/背景/字号档位定制，打造专属界面 |

---

## 二、技术架构

### 2.1 整体架构

```
┌───────────────────────────────────────────────────────────┐
│                 AppShell 自适应主框架                      │
│   3 档断点 (isSm/isMd/isLg) + 底部 5 Tab / 侧边栏切换      │
├───────────────────────────────────────────────────────────┤
│  ArkUI 表现层（@Component 与 @ComponentV2 混合）           │
│   38 Pages + 25 Components + 全异步数据加载                │
├───────────────────────────────────────────────────────────┤
│  业务逻辑层                                                │
│   热榜：NewsNowClient / NewsNowAuth / NewsNowSync          │
│         HotFeedStore（内存态）/ NewsRepository（本地）      │
│         NewsAiService（摘要/翻译/问AI/要闻/速递）           │
│   对话：LlmClient / ChatRepository / ToolRegistry          │
│   游戏：GameAIService / ChineseChessEngine / Achievement   │
│   微舆：BettaFishApiClient / BettaFishSseClient / Store    │
│   账号：HuaweiAccountService / CloudSyncService            │
│   基础：DataRepository（门面）/ SecurityService             │
├───────────────────────────────────────────────────────────┤
│  数据访问层                                                │
│   DatabaseHelper（RDB v18）· 19 张表 + 2 张 FTS5 虚拟表     │
│   settings / game_scores / chat_* / ai_call_logs /         │
│   ai_token_stats / achievements / game_replays /           │
│   hot_favorites / hot_read / hot_digests /                 │
│   hot_article_cache / bettafish_* / defects*               │
├───────────────────────────────────────────────────────────┤
│  HarmonyOS 系统能力                                        │
│   UniversalKeystoreKit(HUKS) │ ArkData │ ArkWeb │ Network  │
│   ShareKit │ SpeechKit │ CoreVisionKit │ CloudFoundation   │
└───────────────────────────────────────────────────────────┘
```

### 2.2 技术选型

| 模块 | 技术方案 | 实现状态 |
|------|---------|---------|
| 开发语言 | ArkTS | ✅ |
| UI 框架 | ArkUI 声明式 + Stage 模型 | ✅ |
| 目标 SDK | HarmonyOS 6.1.1 (API 24)（compatible/target 均为 6.1.1(24)） | ✅ |
| 数据存储 | RelationalStore（RDB v18）+ 19 表 + 2 张 FTS5 虚拟表 | ✅ |
| 网络后端 | NewsNow 实例（热榜 HTTP API）+ 各家大模型 API（SSE/非流式） | ✅ |
| 凭据加密 | HUKS 硬件密钥库 AES-256-GCM（API Key 与 NewsNow JWT） | ✅ |
| 响应式 | @StorageLink / AppStorageV2 + display API | ✅ |
| 外观系统 | ThemePalette token 体系（拟物白 / 深色双套）+ 自定义背景 + 字号档位（v10） | ✅ |
| 毛玻璃效果 | GlassEffect 半透明背景 + 边框 | ✅ |
| 全局字号系统 | palette.fs* 8 级字号，受设置档位控制 | ✅ |
| 热榜 | NewsNow 后端 + 52 条源目录 + 视图 Tabs + 源关注同步 | ✅ |
| 游戏中心 | 7 游戏 + 5 级难度 + 历史记录 + AI 托管 + 对局回放 | ✅ |
| AI 对话 | LlmClient 多供应商 + ChatRepository 持久化 + Agent 工具化 | ✅ |
| AI 调用记录 | AiCallLogger 摘要日志 + ai_call_logs 表 + AiCallLog 页 | ✅ |
| 中国象棋 | 本地引擎 + 人机/人对AI/AI对AI 三模式 | ✅ |
| 微舆 | BettaFish 自部署服务端 + SSE 进度 + 报告查看 | ✅ |
| 账号与云同步 | Account Kit + Cloud Foundation Kit（AGC 未配置时降级本地备份） | ✅ |
| 导航系统 | NavigationFacade + PageRegistry + 类型化路由参数 | ✅ |

### 2.3 凭据加密设计

**实现文件**：[common/CryptoHelper.ets](file:///workspace/zhizon/entry/src/main/ets/common/CryptoHelper.ets)

| 特性 | 说明 |
|------|------|
| 算法 | AES-256-GCM（HUKS 硬件密钥库 + CryptoArchitectureKit 随机数） |
| 密钥存储 | HUKS 在 TEE/SE 内生成并持久化，**密钥本体不可导出**，App 仅持有别名 `zhizon_master_v2` |
| IV | 每次加密生成 12 字节随机 IV |
| 密文格式 | `v2:<base64IV>:<base64Ciphertext+AuthTag>`（末 16 字节为 GCM authTag） |
| 保护范围 | LLM API Key、联网搜索 Key、NewsNow 登录 JWT（`hot_jwt_enc`） |
| 云备份 | 凭证类键（`hot_jwt_enc` / `huaweiAccountProfile`）**排除**在云备份之外（换机无法解密） |

---

## 三、目录结构

```
zhizon/
├── .gitignore
├── README.md
├── build-profile.json5                    # 根构建配置（本地文件，仓库内为 .example 模板）
├── hvigorfile.ts
├── oh-package.json5
├── sync_app_icon.sh                       # 应用图标同步脚本
├── icon_options/                          # 图标候选素材
│
├── doc/
│   ├── DESIGN.md                          # 本文档
│   ├── newsnow-redesign.md                # 热榜模块设计（接口契约 / 同步协议 / 验收）
│   ├── cloud-sync-setup.md                # 华为账号 + 云同步接入说明
│   ├── BettaFish_HarmonyOS_设计方案.md      # 微舆服务端对接契约
│   ├── BettaFish-Zhizon-集成设计方案.md     # 微舆集成设计
│   └── chat-ux-revamp-plan.md             # AI 对话体验改造方案（已实施，历史设计稿）
│
├── AppScope/                              # 应用全局配置
│   ├── app.json5                          # BundleName + 版本
│   └── resources/base/element/string.json # app_name = "智子"
│
└── entry/                                 # 主模块
    ├── build-profile.json5
    ├── hvigorfile.ts
    ├── oh-package.json5
    └── src/
        ├── main/
        │   ├── module.json5               # UIAbility 注册 + 权限声明
        │   ├── resources/base/            # color/string/media/fonts/sounds + profile/main_pages.json（32 个路由页）
        │   └── ets/
        │       ├── entryability/EntryAbility.ets   # 入口：加密/数据库/主题初始化 + 热榜启动同步 + 退后台 flush
        │       │
        │       ├── common/（26）           # 主题、导航、模型与工具
        │       │   ├── Theme.ets / ThemeState.ets / ThemeContracts.ets  # 外观系统（ThemePalette token + 拟物白/深色双套）
        │       │   ├── AppIcons.ets                                     # 图标中心（矢量 SymbolGlyph + emoji 回退）
        │       │   ├── Navigation.ets / AppNavigator.ets                # 导航门面 + 页面注册表
        │       │   ├── Constants.ets                                    # 底部 5 Tab + 全局常量
        │       │   ├── HotModels.ets / HotSources.ets / HotFormat.ets   # 热榜模型 / 52 条源目录 / 时间格式化
        │       │   ├── PageRefreshBus.ets                               # 宿主 onPageShow 广播（Tab 嵌入页刷新）
        │       │   ├── Difficulty.ets / LlmModels.ets / MarkdownConverter.ets / SseFrameParser.ets 等
        │       │   └── CryptoHelper.ets                                 # HUKS AES-256-GCM
        │       │
        │       ├── model/（2）             # GovernanceModels（AppFailure/RecoverableResult/DefectRecord）+ Models
        │       │
        │       ├── service/（43，v10 按域分层）  # 业务服务层
        │       │   ├── hot/（7）     NewsNowClient / NewsNowAuth / NewsNowSync / HotFeedStore /
        │       │   │                 NewsRepository / NewsAiService / HotDataProvider（热榜取数接缝）
        │       │   ├── chat/（10）   LlmClient / ChatRepository / ChatViewModel / ChatExporter / ToolRegistry /
        │       │   │                 AgentOrchestrator / WebSearchService / SpeechService / OnDeviceAiService / ImageAttachment / LlmProvider（模型调用接缝）
        │       │   ├── game/（9）    GameAIService / ChineseChessEngine / ChineseChessBook / ChineseChessNotation /
        │       │   │                 GomokuEngine / SudokuSolver / AchievementService / ReplayService / LeaderboardService
        │       │   ├── betta/（3）   BettaFishApiClient / BettaFishSseClient / BettaFishStore
        │       │   └── platform/（14）DatabaseHelper（RDB v18 + 全表 CRUD + 迁移与保留策略）/ DataRepository /
        │       │                     SecurityService / BiometricHelper / BackgroundImporter / PickerAdapter /
        │       │                     CloudSyncService / HuaweiAccountService / WindowEnvironmentProvider /
        │       │                     SoundService / LiveViewService / AiCallLogger / DefectClassifier / DefectWorkflow
        │       │
        │       ├── components/（27）       # 通用组件
        │       │   ├── HotSourceCard.ets / HotItemRow.ets / HotSourceBadge.ets / HotSourcePicker.ets   # 热榜卡片族 + 源选择器
        │       │   ├── AiModelPicker.ets                                # 模型切换半模态（对话/详情复用）
        │       │   ├── TopBar.ets / FixedBottomNav.ets / SideNav.ets / SettingGroupCard.ets / SettingRow.ets
        │       │   └── GlassEffect.ets / GlobalBackgroundLayer.ets / LockOverlay.ets / Chat* 系列 / Betta* 系列 / GameAIPanel.ets 等
        │       │
        │       └── pages/（38）            # 页面
        │           ├── AppShell.ets                                     # 自适应主框架
        │           ├── Index.ets / HotBoard.ets                         # 热榜首页 / 单源榜单
        │           ├── NewsDetail.ets / NewsDigest.ets / NewsFavorites.ets / NewsSearch.ets / NewsSettings.ets / NewsLogin.ets
        │           ├── Games.ets / Tetris.ets / Game2048.ets / Snake.ets / Minesweeper.ets / Sudoku.ets / ChineseChess.ets / Gomoku.ets / GameHistory.ets / GameStats.ets / GameSettings.ets / ReplayList.ets / Leaderboard.ets
        │           ├── Chat.ets / ChatConfig.ets / AiModelPage.ets / AiRoleLibrary.ets / AiCallLog.ets
        │           ├── Profile.ets / Settings.ets / AppearanceSettings.ets / Achievements.ets / ReadingReport.ets / LegalDoc.ets
        │           └── BettaFishPage.ets / BettaFishProgress.ets / BettaFishReportView.ets / BettaFishServerConfig.ets / BettaFishSystem.ets
        │
        └── test/（13）                     # 单元测试（入口 `List.test.ets`，`hvigorw test` 可跑）
            ├── List.test.ets（套件入口）
            ├── HotModuleTest.ets / NewsNowAuthTest.ets / HotDataProviderTest.ets / LlmProviderTest.ets / NewsRepositoryTest.ets
            ├── DefectClassifierTest.ets / DefectWorkflowTest.ets / GameLaunchFacadeTest.ets / NavigationFacadeTest.ets
            ├── SudokuSolverTest.ets / WindowEnvironmentProviderTest.ets / WindowEnvironmentSnapshotTest.ets
```

> v10 工程收敛：全部 38 页面 + 27 组件已统一为 `@ComponentV2` 状态管理；`service/` 按域分层（hot / chat / game / betta / platform），域之间只允许经 platform 的公共能力交互；热榜取数与模型调用分别经 `HotDataProvider` / `LlmProvider` 注册表可注入 Fake（见 `test/HotDataProviderTest.ets`、`test/LlmProviderTest.ets`）。
> 单元测试：`hvigorw test --mode module -p module=entry`（覆盖率报告输出到 `entry/.test/default/outputs/test/reports/`）。

---

## 四、功能模块设计

### 4.1 功能全景图

```
智子 (Zhizon)
├── 0. 全网热榜（主功能，NewsNow 后端，详见「十·一」）
│   ├── 52 条源目录（微博/知乎/百度/B站/抖音/财联社/华尔街见闻/HN/GitHub …）
│   ├── 视图 Tabs（关注 / 最热 / 实时 / 国内 / 科技 / 财经 / 国际 / 体育）
│   ├── 单源榜单页（完整 30 条 + 下拉强制刷新 + 源站入口）
│   ├── 源关注 ⭐ + GitHub 登录多端同步（与 NewsNow 网页版互通）
│   ├── 收藏 / 已读 / 离线正文缓存 / 全文搜索（FTS5）
│   └── AI 摘要 / 翻译 / 文章问AI / 朗读 / 今日要闻 / 热点速递
│
├── 1. 游戏中心
│   ├── 俄罗斯方块 / 2048 / 贪吃蛇 / 扫雷 / 数独 / 中国象棋 / 五子棋
│   ├── 难度选择（5 级：超简单/简单/中等/困难/地狱）
│   ├── 游戏 AI 托管（GameAIService 决策，非流式 + 关闭思考）
│   ├── 对局回放（2048/贪吃蛇/五子棋，1x/2x/4x）
│   ├── 成就系统（15 项，达成播报音效）
│   └── 游戏历史 / 战绩可视化 / 排行榜
│
├── 2. AI 对话
│   ├── 多供应商大模型（OpenAI/Anthropic/DeepSeek/通义千问/Kimi/智谱/Ollama/自定义）
│   ├── 多会话管理（抽屉 / 重命名 / 固定 / 删除 / 跨会话搜索）
│   ├── Markdown 富文本渲染（流式）+ 斜杠命令 + Token 预算条
│   ├── 语音输入（Speech Kit）/ 朗读回复（TTS）/ 端侧 OCR（Core Vision Kit）
│   ├── 联网搜索开关 + Agent 工具化（计算器/时间/联网搜索/热榜检索）
│   ├── 会话备份恢复（JSON 导出/导入）+ 实况窗进度
│   └── AI 调用记录（AiCallLogger + AiCallLog 页）
│
├── 3. 微舆（BettaFish）
│   ├── 自部署多 Agent 舆情分析服务端对接（HTTP + SSE）
│   ├── 服务器配置管理（多套 / 连接测试）
│   ├── 分析进度（SSE 实时）/ 报告查看（HTML/MD/PDF 本地留档）
│   └── 系统状态与任务历史
│
├── 4. 多主题系统
│   ├── 两套色板（华为拟物白（默认）/ 深色）
│   ├── 亮/暗模式（跟随系统或手动）
│   ├── 自定义背景图（沙箱导入 + 强度调节）
│   ├── 毛玻璃效果（开关控制）
│   └── 字号缩放（小/标准/大，palette.fs* 全局生效）
│
├── 5. 账号与云同步
│   ├── 华为账号登录（Account Kit，openid + profile）
│   ├── 云备份/恢复（Cloud Foundation Kit：设置 + 战绩 + 成就 + 全部对话）
│   └── 未配置 AGC 时自动降级为本地备份
│
└── 6. 导航系统
    ├── 5 个主 Tab（热榜 / AI对话 / 游戏 / 微舆 / 我的）
    ├── NavigationFacade（页面注册表 + 导航验证）
    ├── 类型化路由参数
    └── 页面可用性检查
```

### 4.2 各模块详细设计

---

#### 模块 1：游戏中心

**实现位置**：[pages/Games.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Games.ets)、[pages/Tetris.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Tetris.ets)、[pages/Game2048.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Game2048.ets)、[pages/Snake.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Snake.ets)、[pages/Minesweeper.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Minesweeper.ets)、[pages/Sudoku.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Sudoku.ets)、[pages/ChineseChess.ets](file:///workspace/zhizon/entry/src/main/ets/pages/ChineseChess.ets)、[pages/GameHistory.ets](file:///workspace/zhizon/entry/src/main/ets/pages/GameHistory.ets)、[pages/Index.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Index.ets)、[common/Difficulty.ets](file:///workspace/zhizon/entry/src/main/ets/common/Difficulty.ets)、[service/GameAIService.ets](file:///workspace/zhizon/entry/src/main/ets/service/GameAIService.ets)、[service/ChineseChessEngine.ets](file:///workspace/zhizon/entry/src/main/ets/service/ChineseChessEngine.ets)

| 功能 | 实现状态 |
|------|---------|
| 游戏中心入口 | ✅ 7 游戏 + 难度选择器 + 长按查看帮助 |
| 俄罗斯方块 | ✅ 7 种方块 + 旋转/移动/消行 + 5 级难度 + AI 托管 |
| 2048 | ✅ 4x4 棋盘 + 滑动合并 + 5 级难度 + AI 托管 + 对局回放 |
| 贪吃蛇 | ✅ 方向控制 + 食物 + 碰撞检测 + 5 级难度 + AI 托管 + 对局回放 |
| 扫雷 | ✅ 逻辑推理 + 翻格/标记 + 5 级难度 + AI 托管 |
| 数独 | ✅ 数字推理 + 求解器 + 5 级难度 + AI 托管 |
| 中国象棋 | ✅ 人机/人对AI/AI对AI + 悔棋 + 记谱 + AI 提示 |
| 五子棋 | ✅ 本地引擎（5 级深度搜索）+ 大模型对弈 + 对局回放 |
| 游戏 AI 托管 | ✅ GameAIService 一次调用批量决策，非流式 + 关闭思考 |
| 游戏难度 | ✅ 5 级（超简单/简单/中等/困难/地狱） |
| GameLaunchFacade | ✅ 启动参数验证 + 路由跳转 |
| 游戏历史 / 统计 / 排行榜 | ✅ 分数记录 + 难度标记 + 排行 + 趋势图 |
| 成就与音效 | ✅ 15 项成就 + SoundPool 低时延音效 |

---

#### 模块 2：多主题系统

**实现位置**：[common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets)、[common/ThemeContracts.ets](file:///workspace/zhizon/entry/src/main/ets/common/ThemeContracts.ets)、[service/BackgroundImporter.ets](file:///workspace/zhizon/entry/src/main/ets/service/BackgroundImporter.ets)、[components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets)、[components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets)

| 功能 | 实现状态 |
|------|---------|
| 两套色板 | ✅ 华为拟物白（默认）/ 深色（v10 收敛，6 套配色下架） |
| 亮/暗模式 | ✅ 跟随系统或手动切换 |
| ThemePalette 接口 | ✅ 30+ 颜色字段 + 8 级字号 |
| 全局字号档位 | ✅ 全站统一使用 palette.fs* 系列，受设置档位控制 |
| 自定义背景 | ✅ 沙箱导入 + 强度调节 |
| 毛玻璃效果 | ✅ 半透明背景 + 边框 + 开关控制 |
| 偏好持久化 | ✅ PreferenceSnapshot + RDB |
| 偏好回滚 | ✅ PreferencePersistenceResult |

---

#### 模块 3：AI 对话

**实现位置**：[pages/Chat.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Chat.ets)、[pages/ChatConfig.ets](file:///workspace/zhizon/entry/src/main/ets/pages/ChatConfig.ets)、[common/LlmModels.ets](file:///workspace/zhizon/entry/src/main/ets/common/LlmModels.ets)、[common/MarkdownConverter.ets](file:///workspace/zhizon/entry/src/main/ets/common/MarkdownConverter.ets)、[service/ChatRepository.ets](file:///workspace/zhizon/entry/src/main/ets/service/ChatRepository.ets)、[service/LlmClient.ets](file:///workspace/zhizon/entry/src/main/ets/service/LlmClient.ets)

| 功能 | 实现状态 |
|------|---------|
| 多供应商模型 | ✅ OpenAI/Anthropic/DeepSeek/通义千问/Kimi/智谱/Ollama/自定义 |
| 模型配置 | ✅ ChatConfig 配置供应商/模型/API Key |
| 流式/非流式 | ✅ 支持流式 SSE 与非流式两种请求 |
| 思考控制 | ✅ 可关闭思考模式以提升响应速度 |
| 会话持久化 | ✅ ChatRepository 本地保存会话与消息 |
| Markdown 渲染 | ✅ 原生组件渲染（规避 RichText/Web 适配问题） |

---

#### 模块 5：AI 调用记录

**实现位置**：[pages/AiCallLog.ets](file:///workspace/zhizon/entry/src/main/ets/pages/AiCallLog.ets)、[service/AiCallLogger.ets](file:///workspace/zhizon/entry/src/main/ets/service/AiCallLogger.ets)、[service/LlmClient.ets](file:///workspace/zhizon/entry/src/main/ets/service/LlmClient.ets)、[service/DatabaseHelper.ets](file:///workspace/zhizon/entry/src/main/ets/service/DatabaseHelper.ets)

**设计要点**：仅在 LlmClient 三个公开方法（postCompletion / postCompletionCancelable / postCompletionStream）外层统一注入日志，调用方通过 `AiCallContext`（chat / game / test）声明场景，游戏托管自动带上游戏名；只记摘要（时间/场景/模型/耗时/成败/字符量/错误），**不存 prompt 与响应全文**，保护隐私。

| 功能 | 实现状态 |
|------|---------|
| 场景区分 | ✅ 聊天 / 游戏托管（含游戏名）/ 连接测试 |
| 调用摘要 | ✅ 开始/结束时间、耗时、模型、服务商、成败、错误、字符量 |
| 持久化 | ✅ `ai_call_logs` 表，按开始时间倒序，不设上限 |
| 查看页 | ✅ 列表 + 点击展开详情 + 顶栏清空（确认对话框） |
| 入口 | ✅ 我的 → AI 调用记录 |

---

#### 模块 4：导航系统

**实现位置**：[common/Navigation.ets](file:///workspace/zhizon/entry/src/main/ets/common/Navigation.ets)

| 功能 | 实现状态 |
|------|---------|
| NavigationFacade | ✅ 页面注册表 + 导航验证 |
| 主 Tab | ✅ 热榜/AI对话/游戏/微舆/我的 5 个主 Tab |
| Tab 嵌入页刷新 | ✅ PageRefreshBus（AppShell.onPageShow 广播，Index/Chat 各自刷新） |
| 类型化路由参数 | ✅ AppShellRouteParams / HotDetailRouteParams / HotBoardRouteParams / GameHistoryRouteParams / LegalDocRouteParams 等 |
| 页面可用性 | ✅ EMBEDDED（内嵌）/ ROUTE（独立路由） |
| 导航结果 | ✅ NavigationSuccess / NavigationFailure |

---

## 五、自适应布局设计

### 5.1 三档响应式断点

**核心文件**：[pages/AppShell.ets](file:///workspace/zhizon/entry/src/main/ets/pages/AppShell.ets)

| 断点 | 宽度范围 | isSm | isMd | isLg | 布局 |
|------|---------|------|------|------|------|
| **手机** | < 600vp | ✅ | ❌ | ❌ | 底部 Tab 导航 |
| **平板（紧凑）** | 600 ~ 839vp | ❌ | ✅ | ❌ | 160vp 紧凑侧边栏 |
| **平板（标准）** | ≥ 840vp | ❌ | ❌ | ✅ | 220vp 标准侧边栏 |

### 5.2 手机布局（isSm = true）

```
┌──────────────────────────────┐
│  SAFE_TOP（动态状态栏高度）    │
│  ┌────────────────────────┐  │
│  │     页面内容 (可滚动)    │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  4 个 Tab（首页/游戏/AI对话/我的）│  │
│  │  (高度 56vp)           │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- 5 个主 Tab：热榜 / AI对话 / 游戏 / 微舆 / 我的

### 5.3 平板布局（isSm = false）

```
┌────┬─────────────────────────┐
│    │  SAFE_TOP                │
│ 侧 │  ┌──────────────────┐  │
│ 边 │  │    页面内容       │  │
│ 栏 │  │    (可滚动)       │  │
│    │  └──────────────────┘  │
│ 160│                          │
│ 或 │                          │
│ 220│                          │
└────┴─────────────────────────┘
```

### 5.4 响应式实现机制

```typescript
// AppShell.ets
@StorageLink('windowEnvironmentSnapshot') environment: WindowEnvironmentSnapshot = ...;

aboutToAppear() {
  // WindowEnvironmentProvider 监听窗口尺寸变化
  // 通过 @StorageLink 自动触发全应用响应式更新
}
```

### 5.5 各页面响应式适配

| 页面 | 手机端适配 |
|------|-----------|
| Index | 游戏入口大卡纵向排列，最佳战绩 3 列横排 |
| 所有页面 | padding: `isSm ? 16 : 24` |

---

## 六、数据模型设计

### 6.1 核心实体

业务模型由各页面内联定义（如 Games.ets 的 GameEntry、Index.ets 的 HomeGameEntry/ScoreRow）。

**治理模型**：详见 [model/GovernanceModels.ets](file:///workspace/zhizon/entry/src/main/ets/model/GovernanceModels.ets)，含 `AppFailure`、`RecoverableResult`、`DefectRecord`、`FixEvidence`、`DefectStateHistory`、`FixResult`、`PreferenceSnapshot` 等。

**游戏战绩**：`ScoreEntry`（id, score, level, difficulty, createdAt），定义于 [service/DatabaseHelper.ets](file:///workspace/zhizon/entry/src/main/ets/service/DatabaseHelper.ets)。

### 6.2 数据存储方案

| 数据类型 | 存储方式 | 状态 |
|---------|---------|------|
| 应用设置 | RDB `settings` 表 | ✅ |
| 游戏分数记录 | RDB `game_scores` 表 | ✅ |
| 缺陷记录 | RDB `defects` 表 | ✅ |
| 缺陷证据 | RDB `defect_evidence` 表 | ✅ |
| 缺陷状态历史 | RDB `defect_status_history` 表 | ✅ |
| 缺陷修复结果 | RDB `defect_fix_results` 表 | ✅ |
| AI 调用日志 | RDB `ai_call_logs` 表 | ✅ |
| 加密主密钥 | preferences 持久化 | ✅ |
| 主题偏好 | RDB `settings` 表（JSON） | ✅ |

### 6.3 数据库表结构

**数据库版本**：v18（v18 丢弃全部旧 news_* 表，热榜域重建为 hot_* 表）

**settings 表**：key(PK), value（含热榜服务器地址 `hot_server_url`、关注列表 `hot_focus_meta`、加密凭证 `hot_jwt_enc`）

**热榜表**：hot_favorites(key PK, source_id, source_name, title, url, info, added_at) · hot_read(key PK, read_at) · hot_digests(id, date, content, model_name, created_at) · hot_article_cache(url PK, title, html, cached_at) · hot_articles_fts(kind, key, title, body)

**game_scores 表**：id(PK), game, score, level, difficulty, created_at

**defects 表**：defect_key(PK), title, symptom, preconditions, steps, expected_behavior, actual_behavior, device_info, source, severity, status, priority, affected_features, fix_result, created_at, updated_at

**defect_evidence 表**：evidence_id(PK), defect_key, evidence_type, conclusion, source, conditions, operator, recorded_at

**defect_status_history 表**：history_id(PK), defect_key, from_status, to_status, operator, trigger, evidence_id, recorded_at

**defect_fix_results 表**：defect_key(PK), scope, expected_behavior, failure_behavior, validation_conditions, residual_risks

**ai_call_logs 表**：id(PK), type(chat/game/test), game, model, provider, start_time, end_time, duration_ms, success, error_code, error_msg, prompt_chars, response_chars

---

## 七、UI/UX 设计规范

### 7.1 设计风格

- **风格**：tech-dark（深色终端科技风），支持多主题系统切换
- **外观系统（v10）**：拟物白（默认）/ 深色两套 token 色板 + 亮暗跟随系统或手动；自定义背景、底栏毛玻璃、全局字号档位；矢量化图标中心 `AppIcons`
- **毛玻璃效果**：通过 GlassEffect 组件实现半透明背景 + 边框，支持开关控制
- **主色（终端青绿主题，默认）**：`#00D9A3`
- **字体**：系统字体 + JetBrains Mono（代码/数字）

### 7.2 颜色规范

详见 [common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets) 与 [common/ThemeContracts.ets](file:///workspace/zhizon/entry/src/main/ets/common/ThemeContracts.ets)

**ThemePalette 接口**：30+ 颜色字段 + 8 级字号 + `isDark` 标志（区分亮/暗模式）

以下为**终端青绿主题（默认）**色值：

| 用途 | 色值 |
|------|------|
| 背景基色 | `#0A0E1A` |
| 卡片背景 | `#131826` |
| 次级背景 | `#1A2030` |
| 悬浮背景 | `#232A3D` |
| 主色（青绿） | `#00D9A3` |
| 主色半透明 | `rgba(0, 217, 163, 0.15)` |
| 成功 | `#10B981` |
| 警告 | `#F59E0B` |
| 危险 | `#EF4444` |
| 信息 | `#3B82F6` |
| 主文字 | `#E2E8F0` |
| 次文字 | `#94A3B8` |
| 三级文字 | `#8B95A7` |
| 边框 | `#2A3245` |
| 细边框 | `#1E2535` |

### 7.3 毛玻璃效果

通过 [components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets) 实现：

- **GlassLevel**：P1_CARD / P2_LIST / P3_OVERLAY 三档层级
- **GlassStyle.backgroundColor()**：根据开关状态返回半透明背景色
- **GlassStyle.borderColor()**：根据开关状态返回半透明边框色
- **开关控制**：`@StorageLink('glassEffectEnabled')` 全局状态，设置页可切换

### 7.4 安全区域

| 区域 | 值 | 说明 |
|------|---|------|
| SAFE_TOP | 动态 | 通过 WindowEnvironmentProvider 获取状态栏高度 |
| SAFE_BOTTOM | 动态 | 通过 WindowEnvironmentProvider 获取手势区域高度 |

### 7.5 字号系统

| 变量 | 值 | 用途 |
|------|---|------|
| fsXs | 10 | 标签/徽章 |
| fsSm | 12 | 副文字/时间 |
| fsBase | 13 | 列表正文 |
| fsMd | 14 | 卡片标题 |
| fsLg | 16 | 区块标题 |
| fsXl | 20 | 页面标题 |
| fs2xl | 26 | 指标大数字 |
| fs3xl | 32 | 特大数字 |

---

## 八、通用组件设计

### 8.1 组件清单（25 个，下表为主要复用组件）

| 组件 | 文件 | 说明 |
|------|------|------|
| TopBar | [components/TopBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/TopBar.ets) | 顶栏（响应式 padding + 自定义返回/菜单回调 + @BuilderParam 操作区） |
| FixedBottomNav | [components/FixedBottomNav.ets](file:///workspace/zhizon/entry/src/main/ets/components/FixedBottomNav.ets) | 手机端固定底部导航（5 Tab） |
| SideNav | [components/SideNav.ets](file:///workspace/zhizon/entry/src/main/ets/components/SideNav.ets) | 平板/2in1 侧边栏导航 |
| HotSourceCard | [components/HotSourceCard.ets](file:///workspace/zhizon/entry/src/main/ets/components/HotSourceCard.ets) | 热榜源卡片（源徽标 + 更新态 + ⭐关注 + Top5 + 查看全部） |
| HotItemRow | [components/HotItemRow.ets](file:///workspace/zhizon/entry/src/main/ets/components/HotItemRow.ets) | 榜单条目行（序号配色 + 标题 + 热度/时间 + 已读态） |
| HotSourceBadge | [components/HotSourceBadge.ets](file:///workspace/zhizon/entry/src/main/ets/components/HotSourceBadge.ets) | 源徽标（首字 + 源配色） |
| HotSourcePicker | components/HotSourcePicker.ets | 源选择器（分组 + ⭐ 关注切换；供热榜设置复用） |
| AiModelPicker | components/AiModelPicker.ets | 模型切换半模态（含「跟随全局模型」；供对话页与详情页复用） |
| GlassEffect | [components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets) | 毛玻璃效果工具（背景色/边框/模糊级别 + 低电降级） |
| GlobalBackgroundLayer | [components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets) | 全局背景层（自定义背景图 + 强度调节） |
| SettingGroupCard / SettingRow | [components/SettingGroupCard.ets](file:///workspace/zhizon/entry/src/main/ets/components/SettingGroupCard.ets) | 设置分组卡与统一行控件。`SettingRow` 入参：`icon`(emoji) / `useSymbol`+`symbol`(矢量优先) / `title` / `value` / `desc` / `showArrow` / `showDivider` / `danger` / `isSwitch`+`switchValue`(+`@Event onSwitchChange`) / `@Event rowClick`；被 Settings 与 AppearanceSettings 共用 |
| ChatSessionDrawer / ChatMessageList / ChatMessageBubble / ChatMarkdownText / ChatInputBar | components/Chat*.ets | 会话抽屉、对话列表、气泡、Markdown 渲染与输入条 |
| BettaConnectionBar / BettaEngineStatusCard / BettaForumMessageItem | components/Betta*.ets | 微舆连接状态、引擎状态卡、论坛消息项 |
| GameAIPanel / DifficultyOption | components/ | 游戏 AI 托管控制面板、难度选择项 |
| LockOverlay / PrivacyDialog / AutoLockSheet / PasswordSheet | components/ | 安全锁定遮罩、隐私协议、自动锁定时长、应用密码 |
| FontRegistry | [components/FontRegistry.ets](file:///workspace/zhizon/entry/src/main/ets/components/FontRegistry.ets) | 自定义字体注册 |

> 本轮清理删除了无引用的 `ParticleBackground.ets`（粒子背景组件）。

---

## 九、页面路由与导航

### 9.1 主框架导航（AppShell）

所有页面通过 AppShell 加载：
- 手机端：底部 Tab 切换 `currentPage`
- 平板端：侧边栏点击切换 `currentPage`
- 使用 `@Builder renderPage()` 根据 `currentPage` 渲染对应子页面

### 9.2 导航结构

**主导航（5 项）**：
- 热榜（Index）→ 单源榜单（HotBoard）/ 热榜设置（NewsSettings）/ 登录（NewsLogin）
- AI对话（Chat）→ 模型配置（ChatConfig）
- 游戏（Games）→ 7 款游戏入口 / 战绩 / 回放 / 排行榜
- 微舆（BettaFish）→ 进度 / 报告 / 服务器配置 / 系统状态
- 我的（Profile）→ 设置 / 成就 / 阅读周报 / 收藏 / AI 调用记录

### 9.3 页面跳转关系

```
AppShell (主框架)
├── Index (热榜首页：视图 Tabs + 源卡片流)
│   ├──> HotBoard (单源榜单)
│   ├──> NewsDetail (条目详情：ArkWeb + AI 面板)
│   ├──> NewsDigest (AI 今日要闻 / 热点速递)
│   ├──> NewsSearch (榜单 + 收藏 + 正文缓存检索)
│   ├──> NewsFavorites (收藏)
│   ├──> NewsSettings (服务器 / 账号 / 关注 / 数据)
│   └──> NewsLogin (GitHub 登录，ArkWeb 拦截回跳)
├── Games (游戏中心)
│   ├──> Tetris / Game2048 / Snake / Minesweeper / Sudoku / ChineseChess / Gomoku
│   ├──> GameHistory / GameStats / Leaderboard / ReplayList / GameSettings
│   └──> Achievements
├── Chat (AI对话)
│   ├──> ChatConfig (模型配置)
│   ├──> AiModelPage / AiRoleLibrary
│   └──> AiCallLog (AI 调用记录)
├── BettaFish (微舆)
│   ├──> BettaFishProgress (分析进度)
│   ├──> BettaFishReportView (报告查看)
│   ├──> BettaFishServerConfig (服务器配置)
│   └──> BettaFishSystem (系统状态)
└── Profile (我的)
    ├──> Settings / AppearanceSettings
    ├──> LegalDoc (用户协议/隐私政策/开源许可)
    ├──> ReadingReport (阅读周报)
    └──> NewsFavorites / NewsSettings / NewsSearch
```

### 9.4 子页面跳转

- **进入游戏页面**：通过 `GameLaunchFacade` 统一入口，内部进行游戏注册表查找 + 导航参数验证后跳转
- **返回**：`router.back()` 或 `router.replaceUrl()`
- **传参方式**：类型化 `RouteParams` 对象，接收方 `router.getParams() as XxxRouteParams`
- **导航结果**：`NavigationSuccess` / `NavigationFailure`，支持页面可用性检查（EMBEDDED 内嵌 / ROUTE 独立路由）

---

## 十、ArkTS 严格模式约束

| 规则 | 说明 | 应对 |
|------|------|------|
| arkts-no-any-unknown | 禁用 `any`/`unknown` | 使用显式类型标注 |
| arkts-no-untyped-obj-literals | 对象字面量需显式类型 | 使用 interface 或 Record |
| arkts-no-structural-typing | 不支持结构类型 | 使用 class + constructor |
| arkts-no-destruct-decls | 禁用解构声明 | 改用独立变量赋值 |
| arkts-no-private-identifiers | 禁用 `#` 私有标识符 | 使用 `private` 关键字 |
| arkts-no-spread | 禁用展开运算符 | 显式构建对象 / 使用 slice() |

---

## 十·一、热榜功能（NewsNow 后端 · v9.0）

> 定位：**热榜（全网榜单聚合）为应用主功能**，游戏为次要功能；AI 能力全部手动触发。
> 完整设计（接口契约 / 数据模型 / 同步协议 / 验收清单）见 [newsnow-redesign.md](newsnow-redesign.md)，本节为摘要。

### 10.1.1 功能总览

| 模块 | 说明 |
|------|------|
| 后端 | 自部署或公共 [NewsNow](https://github.com/newsnext/newsnow) 实例，App 内可配置服务器地址（默认公共实例），设置页可测活（`/api/latest`） |
| 首页（Index 重写） | 问候栏 + AI 今日要闻入口 + 视图 Tabs + 源卡片流（下拉刷新 / 单源刷新 / ⭐关注） |
| 视图 | 关注（用户标星的源）/ 最热 / 实时 / 国内 / 科技 / 财经 / 国际 / 体育 |
| 源目录 | `common/HotSources.ets` 内置 52 条源（与 NewsNow sourceId 一致，含子榜如 bilibili-hot-search）；`disable` 源不进默认视图 |
| 单源榜页 | HotBoard：完整 30 条 + 下拉强制刷新（登录时服务端真实抓取）+ ⭐ + 源站入口 |
| 详情页 | ArkWeb 加载条目 URL（优先 mobileUrl）+ 收藏/已读 + AI 摘要/翻译/问AI 面板（流式）+ 🔊 朗读 + 离线正文缓存 + 分享 |
| AI 今日要闻 | 独立全屏页，从**已加载榜单**跨源汇总（零额外网络），按日期/时段缓存（hot_digests），可重新生成/复制 |
| 收藏 | hot_favorites 表，列表页/详情页管理 |
| 搜索 | 已加载榜单内存检索 + 收藏 FTS + 离线正文 FTS（不可用时回退 LIKE）+ AI 汇总 |
| 关注同步 | NewsNow GitHub 登录（ArkWeb 拦截 OAuth 回跳取 JWT），focus 列表与网页版双向同步（10s 防抖上传 + updatedTime 新者覆盖） |
| 凭证安全 | JWT 经 HUKS AES-256-GCM 加密后落 settings（`hot_jwt_enc`），且**排除在华为云备份之外** |
| 离线策略 | 客户端不做 HTTP 缓存，榜单内存态 + 服务端 TTL；正文缓存（hot_article_cache）支持离线阅读 |
| 平板适配 | isMd 双列 / isLg 三列源卡片网格 |
| Agent 工具 | ToolRegistry 的 news_top / news_search 改为读取内存榜单（零网络） |

### 10.1.2 数据表（DatabaseHelper v18）

- hot_favorites(key PK, source_id, source_name, title, url, info, added_at) — 收藏（key = `sourceId:itemId`）
- hot_read(key PK, read_at) — 已读标记
- hot_digests(id, date, content, model_name, created_at) — AI 今日要闻/时段简报缓存
- hot_article_cache(url PK, title, html, cached_at) — 详情页正文缓存（离线阅读 + AI 上下文来源）
- hot_articles_fts(kind, key, title, body) — FTS5 全文索引（trigram → 默认分词 → LIKE 回退）
- v18 迁移会 **DROP** 旧的 11 张 news_* 表与 news_articles_fts（不保留历史数据）

### 10.1.3 服务层

| 服务 | 职责 |
|------|------|
| NewsNowClient | baseUrl 配置 + `/api/latest` 探测 + `/api/s` 单源 + `/api/s/entire` 批量（失败逐源降级）+ `/api/me/sync` 拉取/上传 |
| NewsNowAuth | JWT 加解密存取（HUKS）、用户资料、登录回跳解析、过期判定 |
| NewsNowSync | 本地 focus 读写（settings.hot_focus_meta）+ 云端 pull/push（防抖 10s、退后台 flush） |
| HotFeedStore | 各源榜单内存槽位（idle/loading/ready/error）+ 加载编排（entire 预取、懒补、30 分钟驻留刷新）+ 变更通知 |
| NewsRepository | 收藏/已读/今日要闻/正文缓存 RDB 门面 + FTS 索引与检索 |
| NewsAiService | AI 摘要/翻译/问AI/今日要闻/热点速递/搜索汇总；上下文 = 标题 + 正文（详情页抽取），场景 news_* 写入 ai_call_logs |

### 10.1.4 导航

- 主 Tab：🔥 热榜（Index）/ 🗨️ AI对话 / 🎮 游戏 / 🐟 微舆 / 👤 我的
- 路由页：pages/NewsDetail、pages/NewsDigest、pages/NewsFavorites、pages/NewsSearch、pages/NewsSettings、pages/HotBoard、pages/NewsLogin（均已注册 main_pages.json）
- 宿主刷新：AppShell.onPageShow → PageRefreshBus.emitHotShow() → IndexPage 重载已读/关注态

### 10.1.5 单元测试

- HotModuleTest：源目录检索 / 视图过滤 / displayName / 时间格式化 / HotEntry 键约定
- NewsNowAuthTest：登录回跳解析、JWT exp/主体解析、过期与畸形输入降级
- NewsRepositoryTest：今日日期键 / 标签 / 简报 id 规则

---

## 十一、开发历史

### 11.1 里程碑

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1** | 项目骨架、设计系统、导航、UI 框架 | ✅ |
| **M2** | 数据持久化（RDB v3）、CRUD、默认数据播种 | ✅ |
| **M3** | 全异步改造、响应式布局（3 档断点） | ✅ |
| **M4** | 游戏中心 + 多主题系统 | ✅ |
| **M5** | 毛玻璃效果 + 自定义背景 + 偏好持久化优化 | ✅ |
| **M6** | 移除 SSH/PVE 相关代码，清理孤儿组件，重新设计首页布局，聚焦游戏中心 | ✅ |
| **M7** | 重构导航为 4 Tab（首页/游戏/AI对话/我的），新增扫雷/数独/中国象棋，AI 对话、AI 托管，统一字号 | ✅ |
| **M8** | AI 调用记录（摘要日志 + ai_call_logs 表 + 查看/清空页 + 我的页入口） | ✅ |
| **M9** | 新闻资讯主功能（多源聚合 + 收藏/已读 + AI 摘要/翻译/问AI/今日要闻，RDB v14） | ✅ |
| **M10** | 微舆（BettaFish）集成（服务器配置 + SSE 进度 + 报告查看 + 任务历史，RDB v17） | ✅ |
| **M11** | 华为账号 + 云同步、对局回放、成就系统、游戏音效、端侧 OCR、战绩可视化、排行榜、Agent 工具化 | ✅ |
| **M12** | 资讯域重构为 NewsNow 后端热榜（源目录/视图 Tabs/单源榜页/关注多端同步；RDB v18 丢弃旧新闻域） | ✅ |
| **M13** | v10 视觉重构：拟物白+深色双套 token、毛玻璃降级、矢量图标中心、IA 与入口去重、设置边界归位、V2 状态管理收敛 | ✅ |

### 11.2 关键修复记录

| 日期 | 修复内容 |
|------|---------|
| 2026-08-05 | AppShell `@StorageLink` 响应式状态修复（默认 isSm=true 兜底） |
| 2026-08-05 | 3 档断点布局（手机底部Tab / 紧凑侧栏 / 标准侧栏） |
| 2026-08-05 | 安全区域适配（动态状态栏高度） |
| 2026-08-05 | ArkTS 严格模式合规修复 |
| 2026-08-07 | 游戏中心（俄罗斯方块 + 2048 + 贪吃蛇 + 5 级难度） |
| 2026-08-07 | 多主题系统（6 配色 + 亮/暗模式 + 自定义背景） |
| 2026-08-07 | 导航系统重构（NavigationFacade + 类型化路由参数） |
| 2026-08-07 | 缺陷追踪系统（DefectRecord + DefectWorkflow + DefectClassifier） |
| 2026-08-07 | 治理模型（GovernanceModels + PreferenceSnapshot） |
| 2026-08-11 | 毛玻璃效果实现（半透明背景 + 边框 + 开关控制） |
| 2026-08-11 | 跟随系统深色模式立即生效修复 |
| 2026-08-11 | 全局背景图设置修复（沙箱 URI 校验） |
| 2026-08-11 | 移除全部 SSH/PVE 相关代码（服务、页面、模型、终端渲染、Go Agent） |
| 2026-08-11 | 清理孤儿组件（StatusBadge/ProgressBar/MetricCard/EmptyState/NavSidebar/ArrayDataSource） |
| 2026-08-11 | 首页重新设计为游戏入口大卡 + 最佳战绩 + 难度速览 |
| 2026-08-13 | 俄罗斯方块旋转按钮位置过低被遮挡问题修复 |
| 2026-08-13 | 游戏 AI 托管速度优化（一次调用批量决策，非流式 + 关闭思考） |
| 2026-08-13 | 新增中国象棋（本地引擎 + 人机/人对AI/AI对AI 三模式 + 思考提示） |
| 2026-08-13 | 导航重构为 4 Tab（首页/游戏/AI对话/我的），移除工具箱/更多，消除重复入口 |
| 2026-08-13 | 全站字号统一为 palette.fs* 系列，设置字号档位全局生效 |
| 2026-08-13 | 新增 AI 调用记录（摘要日志 + ai_call_logs 表 + AiCallLog 查看页 + 我的页入口） |

---

## 十二、附录

### 12.1 参考资源

- HarmonyOS 开发文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/
- ArkUI 组件参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/
- ArkTS 严格模式：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-syntax-rules
- UniversalKeystoreKit（HUKS）：硬件密钥库，凭据加解密
- ArkWeb：内嵌网页与 OAuth 回跳拦截（NewsNow 登录、条目详情）
- NewsNow 项目：https://github.com/newsnext/newsnow （热榜后端，MIT）

### 12.2 文档版本

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-08-04 | 初始版本，对应 MVP 实现 |
| v2.0.0 | 2026-08-05 | 数据持久化 (RDB)、全异步改造、自适应布局 |
| v3.0.0 | 2026-08-07 | 游戏中心、多主题系统、导航系统重构、缺陷追踪系统、治理模型 |
| v4.0.0 | 2026-08-07 | 数据库 v4、MockData 移除、单元测试 |
| v5.0.0 | 2026-08-11 | 毛玻璃效果、移除全部 SSH/PVE 代码、首页布局重新设计 |
| v6.0.0 | 2026-08-11 | 清理孤儿组件、首页聚焦游戏中心，应用定位精简为游戏中心 + 多主题系统 |
| v7.0.0 | 2026-08-13 | 导航重构为 4 Tab（首页/游戏/AI对话/我的）、新增扫雷/数独/中国象棋、AI 对话、AI 托管、全站字号统一 |
| v7.1.0 | 2026-08-13 | 新增 AI 调用记录（摘要日志 + ai_call_logs 表 + 查看/清空 + 我的页入口） |
| v8.0.0 | 2026-08-19 | 新闻资讯主功能（资讯首页 + 多源聚合 + 收藏/已读 + AI 摘要/翻译/问AI + AI 今日要闻 + 为你推荐，RDB v14） |
| v9.0.0 | 2026-10-10 | 资讯域重构为 NewsNow 后端热榜：52 条源目录 / 视图 Tabs / 单源榜页 / 源关注 + GitHub 登录多端同步 / Cloudflare 403 修复；删除旧抓取-推荐-画像模块（15 个源文件，RDB v18 丢弃 11 张旧表） |
| v10.0.0 | 2026-10-11 | 视觉与架构重构（华为原生拟物白）：设计令牌双套化、毛玻璃降级、矢量图标中心、首页/榜单/详情/对话/游戏/我的/设置 IA 重排与入口去重、@ComponentV2 状态收敛；设计见 doc/v10-redesign.md |

---

**智子（Zhizon）** · HarmonyOS NEXT 原生应用 · MIT License

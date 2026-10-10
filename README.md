# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · AI 辅助开发 · 全网热榜 + AI 对话 + 游戏中心 + 多主题系统

## 项目简介

智子是一款由 **AI（大语言模型）辅助开发**的开源应用，运行于鸿蒙 6+ 系统，提供：

- 🔥 **全网热榜（主功能）**：以自部署/公共 [NewsNow](https://github.com/newsnext/newsnow) 实例为后端，聚合微博 / 知乎 / 百度 / B站 / 抖音 / 财联社 / 华尔街见闻 / Hacker News / GitHub 等 50+ 站点榜单；视图分类（关注 / 最热 / 实时 / 国内 / 科技 / 财经 / 国际 / 体育）；⭐ 关注源并支持 **GitHub 登录多端同步**（与 NewsNow 网页版数据互通）；收藏、已读标记；AI 摘要 / AI 翻译 / 文章问 AI / AI 今日要闻 / 热点速递（全部手动触发）
- 🎮 **游戏中心（次要功能）**：俄罗斯方块、2048、贪吃蛇、扫雷、数独、中国象棋、五子棋，多级难度可选，支持 AI 托管
- 🗨️ **AI 对话**：支持自行配置多家大模型（OpenAI / Anthropic / DeepSeek / 通义千问 / Kimi / 智谱 GLM / Ollama 等），SSE 流式对话
- 🎙️ **语音输入 + 朗读**：Speech Kit 语音转文字填入输入框，TTS 朗读助手回复
- 🌐 **联网搜索**：对话前可选联网检索，结果注入上下文辅助回答
- ⌘ **斜杠命令**：/翻译 /总结 /代码 等提示词预设快捷指令
- 📊 **上下文预算条**：会话 Token 用量进度可视化，接近上限预警
- 💾 **会话备份/恢复**：单会话/全部会话导出为 JSON 文件分享，支持从文件导入恢复
- 🔔 **实况窗（Live View）**：AI 对话生成与游戏 AI 托管进行中，退到后台也能看到进度
- 📱 **全设备自适应**：手机（底部 5 Tab）、平板、折叠屏自动适配
- 🎨 **多主题系统**：6 套配色 + 亮/暗模式 + 自定义背景 + 毛玻璃效果 + 全局字号档位
- 📊 **游戏战绩**：分数记录与历史排行
- 🔒 **安全加密**：API Key 与 NewsNow 登录凭证使用 HUKS AES-256-GCM 加密存储，不经过任何第三方
- 📋 **AI 调用记录**：记录聊天 / 游戏 AI 托管 / 模型测试的每次调用摘要（场景、模型、耗时、成败），"我的"页可查看与清空

## 技术栈

- **开发语言**：ArkTS
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.1.1 (API 24)
- **数据存储**：RelationalStore (RDB v18) · 热榜收藏/已读/正文缓存/AI 简报
- **网络通信**：HTTP 请求 + SSE 流式响应（OpenAI 兼容 / Anthropic 协议）；热榜走 NewsNow HTTP API
- **账号**：ArkWeb 内嵌 GitHub OAuth（NewsNow 登录），JWT 加密存储
- **加密算法**：AES-256-GCM（HUKS 密钥库，API Key 与登录凭证）
- **响应式布局**：`@StorageLink` 跨组件状态 + `display` API · 3 档断点
- **多主题**：ThemePalette 接口 + 6 色彩主题 + 亮/暗模式 + 自定义背景 + 毛玻璃开关 + palette.fs* 全局字号

## 项目结构

```
zhizon/
├── AppScope/                  # 应用全局配置（BundleName + 版本 + 图标）
├── doc/                       # 项目文档
│   ├── DESIGN.md              # 详细设计文档（架构/数据模型/UI 规范/开发历史）
│   ├── newsnow-redesign.md    # 热榜模块设计（接口契约/同步协议/实施记录）
│   ├── cloud-sync-setup.md    # 华为账号 + 云同步接入说明
│   ├── BettaFish_HarmonyOS_设计方案.md      # 微舆服务端对接契约
│   ├── BettaFish-Zhizon-集成设计方案.md     # 微舆集成设计
│   └── chat-ux-revamp-plan.md # AI 对话体验改造方案（P0/P1 已实施，P2 路线图）
│
├── entry/                     # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets   # RDB/加密/主题初始化 + 热榜启动同步 + 退后台 flush
│       │   ├── common/        # 主题、导航、模型、工具
│       │   │   ├── Theme.ets / ThemeState.ets / ThemeContracts.ets   # 多主题系统
│       │   │   ├── Navigation.ets / AppNavigator.ets                 # 导航门面 + 页面注册表
│       │   │   ├── HotModels.ets / HotSources.ets / HotFormat.ets    # 热榜模型 / 52 条源目录 / 时间格式化
│       │   │   ├── LlmModels.ets / MarkdownConverter.ets / CryptoHelper.ets …
│       │   │   └── PageRefreshBus.ets                                # 宿主 onPageShow 广播（Tab 嵌入页刷新）
│       │   ├── model/         # 通用业务模型 + 治理模型
│       │   ├── service/       # 业务服务层
│       │   │   ├── NewsNowClient.ets   # NewsNow HTTP 客户端（探测/单源/批量/同步）
│       │   │   ├── NewsNowAuth.ets     # GitHub 登录凭证（HUKS 加密）+ 回跳解析
│       │   │   ├── NewsNowSync.ets     # 关注列表本地存储 + 云端双向同步
│       │   │   ├── HotFeedStore.ets    # 榜单内存槽位 + 加载编排
│       │   │   ├── NewsRepository.ets  # 收藏/已读/正文缓存/简报 + FTS
│       │   │   ├── NewsAiService.ets   # AI 摘要/翻译/问AI/要闻/速递
│       │   │   ├── DatabaseHelper.ets  # RDB v18 + 全表 CRUD + 迁移与保留策略
│       │   │   ├── LlmClient.ets / ChatRepository.ets / ToolRegistry.ets …
│       │   │   └── CloudSyncService.ets # 华为云备份（排除本机凭证类设置）
│       │   ├── components/    # 通用组件
│       │   │   ├── HotSourceCard.ets / HotItemRow.ets / HotSourceBadge.ets   # 热榜卡片 / 条目行 / 源徽标
│       │   │   ├── TopBar.ets / FixedBottomNav.ets / GlassEffect.ets / SettingGroupCard.ets …
│       │   └── pages/         # 页面（38 个）
│       │       ├── AppShell.ets        # 自适应主框架（底部 Tab / 侧边栏）
│       │       ├── Index.ets           # 热榜首页（视图 Tabs + 源卡片流）
│       │       ├── HotBoard.ets        # 单源榜单
│       │       ├── NewsDetail.ets      # 条目详情（ArkWeb + AI 面板 + 朗读）
│       │       ├── NewsDigest.ets      # AI 今日要闻 / 热点速递
│       │       ├── NewsFavorites.ets / NewsSearch.ets / NewsSettings.ets / NewsLogin.ets
│       │       ├── Chat.ets / ChatConfig.ets / AiModelPage.ets / AiRoleLibrary.ets / AiCallLog.ets
│       │       ├── Games.ets / Tetris.ets / Game2048.ets / Snake.ets / Minesweeper.ets / Sudoku.ets / ChineseChess.ets / Gomoku.ets
│       │       ├── Profile.ets / Settings.ets / AppearanceSettings.ets / LegalDoc.ets / Achievements.ets
│       │       └── BettaFish*.ets      # 微舆（分析进度 / 报告 / 服务器配置 / 系统）
│       ├── resources/         # 资源文件（颜色/字符串/字体/音效/页面清单）
│       └── module.json5       # 模块配置与权限
│
├── build-profile.json5        # 根构建配置
├── oh-package.json5
├── LICENSE                    # MIT 开源许可 + AI 开发声明
└── README.md
```

## 页面清单

| 页面 | 说明 |
|------|------|
| AppShell | 自适应主框架（手机底部 5 Tab / 平板侧边栏） |
| Index | 热榜首页（问候栏 + AI 今日要闻入口 + 视图 Tabs + 源卡片流 + 下拉刷新/单源刷新/⭐关注） |
| Games | 游戏中心（7 游戏 + 难度选择器 + 长按查看帮助） |
| Chat | AI 对话（SSE 流式输出 + 会话管理 + 语音输入 + 联网搜索 + 斜杠命令） |
| Profile | 我的（用户信息 + 设置入口 + 关于） |
| Settings | 设置（外观 / AI 对话 / 安全 / 数据） |
| ChatConfig | AI 对话配置（服务商模板 / API Key / 模型 / 测试连接 / 联网搜索） |
| GameHistory | 游戏历史记录 |
| LegalDoc | 用户协议 / 隐私政策 / 开源许可 |
| Tetris | 俄罗斯方块（AI 托管） |
| Game2048 | 2048（AI 托管） |
| Snake | 贪吃蛇（AI 托管） |
| Minesweeper | 扫雷（AI 托管） |
| Sudoku | 数独（AI 托管） |
| ChineseChess | 中国象棋（人机 / 人对AI / AI对AI + 悔棋 + 记谱） |
| Gomoku | 五子棋（人机 / 人对AI / AI对AI + 模型可选 + 悔棋 + AI 提示） |
| AiCallLog | AI 调用记录（场景/模型/耗时/成败列表 + 详情展开 + 清空） |
| NewsDetail | 条目详情（ArkWeb 原文 + 收藏/已读 + AI 摘要/翻译/问AI/朗读 + 离线正文缓存 + 分享） |
| HotBoard | 单源榜单（完整 30 条 + 下拉强制刷新 + ⭐关注 + 源站入口） |
| NewsDigest | AI 今日要闻 / 热点速递（跨源汇总，手动生成，Markdown 渲染 + 模型切换） |
| NewsFavorites | 收藏列表 |
| NewsSearch | 热榜搜索（已加载榜单 + 收藏 + 离线正文缓存 + AI 汇总） |
| NewsSettings | 热榜设置（服务器地址 / NewsNow 账号 / 关注管理 / 数据清理 / 关于数据源） |
| NewsLogin | NewsNow GitHub 登录（ArkWeb 拦截 OAuth 回跳） |
| ReadingReport | 阅读周报（近 7 天阅读/收藏/AI 调用） |

## 热榜后端（NewsNow）

热榜数据由 [NewsNow](https://github.com/newsnext/newsnow) 服务端提供，App 只做展示与本地偏好，**不解析任何源站页面**。

**1. 准备一个服务端**（二选一）

- 自建（推荐）：仓库自带 Docker 与 Cloudflare Pages 两种部署方式
  ```bash
  git clone https://github.com/newsnext/newsnow && cd newsnow
  docker compose up          # 或按 README 部署到 Cloudflare Pages + D1
  ```
- 直接使用公共实例：`https://newsnow.busiyi.world`（默认值）

**2. 在 App 内配置**：`我的 → 热榜设置 → 后端服务器` 填入地址，点「测试连接」会请求 `{地址}/api/latest` 并显示服务版本号；地址变更后自动清空内存榜单。

**3. 登录（可选）**：`热榜设置 → NewsNow 账号 → 使用 GitHub 登录`，内嵌 ArkWeb 完成 OAuth，凭证用本机 HUKS 密钥 AES-256-GCM 加密保存。登录后：

- 下拉刷新会请求服务端**真实抓取**最新数据（未登录只能拿到服务端缓存）
- 「关注」的源列表与 NewsNow 网页版**双向同步**（标星后 10 秒防抖上传，`updatedTime` 新者覆盖）

> 接口契约、同步协议与验收清单见 [热榜模块设计文档](doc/newsnow-redesign.md)。

## AI 对话功能

- 支持 OpenAI 兼容 API（/v1/chat/completions）与 Anthropic 协议
- 内置服务商模板：OpenAI、Anthropic、DeepSeek、通义千问、Kimi、智谱 GLM、Ollama、自定义
- SSE 流式响应，实时逐字输出；亦支持非流式请求
- 可关闭思考模式以提升响应速度
- API Key 使用 AES-256-GCM 加密存储，不经过任何第三方
- 对话历史本地持久化，无上限
- 支持测试连接检验 API 可用性
- **语音输入**：麦克风按钮唤起 Speech Kit 听写，实时转文字填入输入框
- **朗读回复**：助手消息 🔊 按钮用 TTS 朗读，点击 🛑 停止
- **联网搜索**：输入区上方 🌐 开关，开启后发送前自动检索并注入上下文（接口可在模型管理中配置）
- **斜杠命令**：输入 `/` 弹出提示词预设（翻译/总结/代码/润色/解释/写作/角色/规划）
- **上下文预算条**：输入区显示会话 Token 用量进度，接近上下文上限时变色预警
- **会话备份/恢复**：抽屉中可导出 Markdown（剪贴板）、备份当前/全部会话为 JSON 文件并分享，支持从文件导入恢复
- 每次调用（聊天/游戏托管/测试）自动记录摘要日志，可在"我的 → AI 调用记录"查看与清空

## 游戏 AI 托管

- 俄罗斯方块、2048、贪吃蛇、扫雷、数独支持 AI 托管自动游玩
- 中国象棋与五子棋支持人机 / 人对AI / AI对AI 三种模式；AI 对 AI 可分别为双方选择模型，并可调对弈节奏
- 五子棋本地引擎人机对弈（5 级难度深度搜索），大模型方支持黑/白任意执子
- 扫雷 AI 托管使用本地确定性推理自动翻开安全格/标记地雷，推理僵局才调用大模型，速度大幅提升
- AI 托管默认使用非流式请求并关闭思考，一次调用返回完整动作序列，大幅提升响应速度
- AI 思考时显示思考中提示，人对弈模式支持 AI 提示与悔棋

## 实况窗（Live View）

- AI 对话生成进行中退到后台，实况窗显示生成进度（进度条 + 计时）
- 不支持的设备/系统自动降级，不影响正常功能

## 应用权限

| 权限 | 用途 |
|------|------|
| ohos.permission.INTERNET | 热榜访问 NewsNow 服务端、AI 对话连接大模型 API、微舆连接自部署服务端 |
| ohos.permission.VIBRATE | 游戏触觉反馈 |
| ohos.permission.MICROPHONE | 语音输入（语音转文字） |
| ohos.permission.ACCESS_BIOMETRIC | 生物识别解锁 |

> 自定义背景图通过系统 Picker 选择（沙箱授权 URI），无需读写媒体库权限。

## 开发环境

- DevEco Studio 6.1.1+（API 24 Release）
- HarmonyOS SDK 6.1.1（API 24）；`compatibleSdkVersion` / `targetSdkVersion` 均为 `6.1.1(24)`
- ohpm 6.1+、Node.js 18+
- 命令行构建：`build_temp.bat`（等价于 `hvigorw assembleHap --mode module -p module=entry`）

## 运行

1. 用 DevEco Studio 打开本项目
2. 配置签名（自动签名即可）
3. 连接鸿蒙设备或模拟器
4. 点击运行

## 新增能力（本轮迭代）

- 🔥 **热榜模块重构（v9.0）**：资讯域从「客户端直连 RSS/多源抓取 + 本地推荐画像」整体替换为 [NewsNow](https://github.com/newsnext/newsnow) 后端驱动的全网热榜；新增 52 条源目录、视图 Tabs、单源榜单页、源关注、NewsNow GitHub 登录与关注多端同步；**删除**旧抓取/推荐/画像模块 14 个源码文件、4 个失效测试与 7 份过期文档（DB v18 直接丢弃 11 张旧表），`.ets` 净减约 5700 行；设计见 [newsnow-redesign.md](doc/newsnow-redesign.md)
- ☁️ **华为账号 + 云同步**：接入 Account Kit（华为账号登录，获取昵称/头像）；Cloud Foundation Kit 云存储备份/恢复配置、战绩、成就与全部对话；未配置 AGC 时自动降级为本地备份，配置步骤见 [云同步接入说明](doc/cloud-sync-setup.md)
- 🎬 **对局回放**：2048、贪吃蛇、五子棋自动录制对局（动作 + 随机格/食物），「我的 → 对局回放」查看、回放（1x/2x/4x）、删除
- 🚀 **长列表性能**：会话抽屉、游戏战绩、AI 调用记录改用 `LazyForEach` 懒加载（通用 `LazyListDataSource`）
- 🏅 **成就系统**：15 项成就（游戏/对话/托管），「我的 → 成就」查看解锁进度，达成时播报音效
- 🔊 **游戏音效**：SoundPool 低时延短音效（消除/吃食物/胜利/失败/成就），「设置 → 游戏 → 游戏音效」开关
- 📷 **端侧 AI（Core Vision Kit）**：聊天输入条「📷」按钮选图，端侧 OCR 识别文字（不出网）并填入输入框，可继续让 AI 翻译/总结
- 📈 **战绩可视化**：「我的 → 战绩统计」，按游戏查看总局数/最高分/平均分/胜率与最近 20 局得分趋势图（Canvas 绘制）
- 🏆 **排行榜**：「我的 → 排行榜」，本地高分榜；Game Service Kit 云端排行预留（待 AGC 游戏服务开放后接入）
- 🤖 **AI 对话 Agent 化（P0）**：「设置 → Agent → Agent 模式」开启后，AI 可主动调用工具（计算器 / 当前时间 / 联网搜索 / 热榜检索）分步完成任务，展示工具执行步骤，可停止；关闭时保持原纯文本对话

## 详细文档

| 文档 | 内容 |
|------|------|
| [详细设计文档](doc/DESIGN.md) | 架构分层、目录结构、功能模块、数据模型、UI 规范、开发历史 |
| [热榜模块设计](doc/newsnow-redesign.md) | NewsNow 接口契约、数据模型、登录与同步协议、实施记录与真机实测结论 |
| [云同步接入说明](doc/cloud-sync-setup.md) | 华为账号登录 + AGC 云存储桶配置步骤、载荷范围与隐私说明 |
| [微舆服务端对接契约](doc/BettaFish_HarmonyOS_设计方案.md) | BettaFish 服务端接口、SSE 事件结构、导出接口 |
| [微舆集成设计](doc/BettaFish-Zhizon-集成设计方案.md) | 微舆在智子中的页面、状态与数据设计 |
| [AI 对话改造方案](doc/chat-ux-revamp-plan.md) | 对话体验改造（P0/P1 已实施）；含未完成的 P2 组件化路线图 |

## AI 开发声明

本应用由 **AI（大语言模型）辅助开发**。开发过程中，AI 参与了代码生成、架构设计、界面布局、文档撰写、测试用例生成等环节，所有 AI 生成内容均经过人类开发者审核与确认。本应用的开源性质不因 AI 参与开发而改变。

## 引用与修改要求

引用或修改本应用代码时，请遵守以下要求：

1. 保留原始版权声明与 MIT 许可声明
2. 在显著位置注明出处，包括原始 GitHub 仓库地址：https://github.com/jiayaoting/zhizon
3. 不得移除或隐藏本应用中的开源许可信息与版权声明

## 项目地址

- **GitHub**: https://github.com/jiayaoting/zhizon

## License

本项目基于 MIT License 开源发布。详见 [LICENSE](LICENSE) 文件。

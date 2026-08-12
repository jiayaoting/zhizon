# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · AI 辅助开发 · 游戏中心 + AI 对话 + 多主题系统

## 项目简介

智子是一款由 **AI（大语言模型）辅助开发**的开源应用，运行于鸿蒙 6+ 系统，提供：

- 🎮 **游戏中心**：俄罗斯方块、2048、贪吃蛇、扫雷、打砖块、数独，多级难度可选
- 🗨️ **AI 对话**：支持自行配置 OpenAI 兼容大模型 API Key（DeepSeek / 通义千问 / Kimi / 智谱 / Ollama 等），SSE 流式对话
- 📱 **全设备自适应**：手机（底部 Tab）、平板、折叠屏自动适配
- 🎨 **多主题系统**：6 套配色 + 亮/暗模式 + 自定义背景 + 毛玻璃效果
- 📊 **游戏战绩**：分数记录与历史排行
- 🔒 **安全加密**：API Key 使用 AES-256-GCM 加密存储，不经过任何第三方

## 技术栈

- **开发语言**：ArkTS
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.1.1 (API 24)
- **数据存储**：RelationalStore (RDB v4) · 5 张持久化表
- **网络通信**：HTTP 请求 + SSE 流式响应（OpenAI 兼容 API）
- **加密算法**：AES-256-GCM（API Key 加密存储）
- **响应式布局**：`@StorageLink` 跨组件状态 + `display` API · 3 档断点
- **多主题**：ThemePalette 接口 + 6 色彩主题 + 亮/暗模式 + 自定义背景 + 毛玻璃开关

## 项目结构

```
zhizon/
├── AppScope/                  # 应用全局配置
│   ├── app.json5              # BundleName + 版本
│   └── resources/
│
├── doc/
│   └── DESIGN.md              # 详细设计文档
│
├── entry/                     # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/  # UIAbility（RDB 初始化 + 沉浸式状态栏 + 主题加载）
│       │   │   └── EntryAbility.ets
│       │   │
│       │   ├── common/        # 主题、常量、导航、难度、模型 (8 个文件)
│       │   │   ├── Theme.ets              # 多主题系统（ThemePalette + 6 配色 + 亮/暗）
│       │   │   ├── ThemeContracts.ets     # 主题契约（ThemeMode + ThemePreference）
│       │   │   ├── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
│       │   │   ├── Navigation.ets         # NavigationFacade + 页面注册表 + 路由参数
│       │   │   ├── CryptoHelper.ets       # AES-256-GCM 加密/解密
│       │   │   ├── Difficulty.ets         # 游戏难度定义 + GameLaunchFacade
│       │   │   ├── LlmModels.ets          # 大模型服务商模板 + 对话消息 + 配置模型
│       │   │   └── FailureHandling.ets    # 错误处理工具
│       │   │
│       │   ├── model/         # 数据模型 (2 个文件)
│       │   │   └── GovernanceModels.ets   # 治理模型（缺陷追踪 + 偏好快照）
│       │   │
│       │   ├── service/       # 业务服务层 (9 个文件)
│       │   │   ├── DatabaseHelper.ets     # RDB v4 + 5 表 CRUD
│       │   │   ├── DataRepository.ets     # 数据门面 + 缺陷管理 + 偏好持久化
│       │   │   ├── LlmClient.ets          # 大模型客户端（OpenAI 兼容 + SSE 流式）
│       │   │   ├── ChatRepository.ets     # API Key 加密存取 + 对话历史持久化
│       │   │   ├── BackgroundImporter.ets # 自定义背景图导入
│       │   │   ├── WindowEnvironmentProvider.ets # 窗口环境感知
│       │   │   ├── DefectWorkflow.ets     # 缺陷状态机工作流
│       │   │   ├── DefectClassifier.ets   # 缺陷分类器
│       │   │   └── PickerAdapter.ets      # 文件选择器适配
│       │   │
│       │   ├── components/    # 通用组件 (5 个)
│       │   │   ├── TopBar.ets              # 顶栏（响应式）
│       │   │   ├── DifficultyOption.ets    # 难度选择项
│       │   │   ├── FixedBottomNav.ets      # 固定底部导航
│       │   │   ├── GlassEffect.ets         # 毛玻璃效果工具
│       │   │   └── GlobalBackgroundLayer.ets # 全局背景层
│       │   │
│       │   └── pages/         # 页面 (13 个)
│       │       ├── AppShell.ets           # 自适应主框架
│       │       ├── Index.ets              # 首页（游戏入口 + 最佳战绩）
│       │       ├── Settings.ets           # 设置（含 AI 对话配置入口）
│       │       ├── More.ets               # 更多菜单
│       │       ├── Games.ets              # 游戏中心
│       │       ├── Tetris.ets             # 俄罗斯方块
│       │       ├── Game2048.ets           # 2048
│       │       ├── Snake.ets              # 贪吃蛇
│       │       ├── Minesweeper.ets        # 扫雷
│       │       ├── Breakout.ets           # 打砖块
│       │       ├── Sudoku.ets             # 数独
│       │       ├── Chat.ets               # AI 对话（搜索 + 流式输出）
│       │       ├── ChatConfig.ets         # AI 对话配置（服务商/Key/模型）
│       │       ├── GameHistory.ets        # 游戏历史记录
│       │       └── LegalDoc.ets           # 法律文档（用户协议/隐私政策/开源许可）
│       │
│       ├── resources/         # 资源文件
│       └── module.json5       # 模块配置
│   │
│   └── src/test/              # 单元测试 (6 个)
│       ├── DefectClassifierTest.ets
│       ├── DefectWorkflowTest.ets
│       ├── GameLaunchFacadeTest.ets
│       ├── NavigationFacadeTest.ets
│       ├── WindowEnvironmentProviderTest.ets
│       └── WindowEnvironmentSnapshotTest.ets
│
├── build-profile.json5        # 根构建配置
├── oh-package.json5
├── LICENSE                    # MIT 开源许可 + AI 开发声明
└── README.md
```

## 页面清单

| 页面 | 说明 |
|------|------|
| AppShell | 自适应主框架（手机底部 Tab / 平板侧边栏） |
| Index | 首页（欢迎区 + 游戏入口大卡 + 最佳战绩 + 难度速览） |
| Settings | 设置（主题 + 背景 + 毛玻璃 + 深色模式 + AI 对话配置） |
| More | 更多菜单入口（设置 + AI 对话） |
| Games | 游戏中心（6 游戏 + 多级难度） |
| Tetris | 俄罗斯方块 |
| Game2048 | 2048 |
| Snake | 贪吃蛇 |
| Minesweeper | 扫雷 |
| Breakout | 打砖块 |
| Sudoku | 数独 |
| Chat | AI 对话（搜索 + 流式输出 + 角色筛选） |
| ChatConfig | AI 对话配置（服务商模板 / API Key / 模型 / 测试连接） |
| GameHistory | 游戏历史记录 |
| LegalDoc | 用户协议 / 隐私政策 / 开源许可 |

## AI 对话功能

- 支持 OpenAI 兼容 API（/v1/chat/completions）
- 内置服务商模板：OpenAI、DeepSeek、通义千问、Kimi、智谱 GLM、Ollama
- SSE 流式响应，实时逐字输出
- API Key 使用 AES-256-GCM 加密存储，不经过任何第三方
- 对话历史本地持久化，无上限
- 支持聊天记录搜索与角色筛选（全部/用户/助手）
- 支持测试连接检验 API 可用性

## 应用权限

| 权限 | 用途 |
|------|------|
| ohos.permission.INTERNET | AI 对话功能连接大模型 API |
| ohos.permission.READ_MEDIA | 选择自定义背景图 |
| ohos.permission.WRITE_MEDIA | 保存自定义背景图 |
| ohos.permission.VIBRATE | 游戏触觉反馈 |

## 开发环境

- DevEco Studio 6.0+
- HarmonyOS SDK 6.1+ (API 24)
- ohpm 5.0+

## 运行

1. 用 DevEco Studio 打开本项目
2. 配置签名（自动签名即可）
3. 连接鸿蒙设备或模拟器
4. 点击运行

## 详细文档

完整的架构设计、数据模型、UI 规范等详见 [详细设计文档](doc/DESIGN.md)。

## AI 开发声明

本应用由 **AI（大语言模型）辅助开发**。开发过程中，AI 参与了代码生成、架构设计、界面布局、文档撰写、测试用例生成等环节，所有 AI 生成内容均经过人类开发者审核与确认。本应用的开源性质不因 AI 参与开发而改变。

## 引用与修改要求

引用或修改本应用代码时，请遵守以下要求：

1. 保留原始版权声明与 MIT 许可声明
2. 在显著位置注明出处，包括原始 GitHub 仓库地址：https://github.com/jiayaoting/zhizon
3. 若修改后发布，请在修改处或文档中注明修改内容与修改时间
4. 不得移除或隐藏本应用中的开源许可信息与版权声明

## 项目地址

- **GitHub**: https://github.com/jiayaoting/zhizon

## License

本项目基于 MIT License 开源发布。详见 [LICENSE](LICENSE) 文件。
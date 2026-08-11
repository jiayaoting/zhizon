# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · 快捷命令库 + 休闲娱乐 + 告警通知

## 项目简介

智子是一款运行于鸿蒙 6+ 系统的**轻量工具应用**，提供：

- ⚡ **快捷命令库**：分类管理常用命令，一键复制，使用次数统计
- 🎮 **游戏中心**：俄罗斯方块、2048、贪吃蛇，5 级难度可选
- 🔔 **告警通知**：告警记录查看与处理，三色分级展示
- 📱 **全设备自适应**：手机（底部 Tab）、平板、折叠屏自动适配
- 🎨 **多主题系统**：6 套配色 + 亮/暗模式 + 自定义背景 + 毛玻璃效果

## 技术栈

- **开发语言**：ArkTS
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.1.1 (API 24)
- **数据存储**：RelationalStore (RDB v4) · 6 张持久化表
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
│       │   ├── common/        # 主题、常量、导航、难度 (7 个文件)
│       │   │   ├── Theme.ets              # 多主题系统（ThemePalette + 6 配色 + 亮/暗）
│       │   │   ├── ThemeContracts.ets     # 主题契约（ThemeMode + ThemePreference）
│       │   │   ├── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
│       │   │   ├── Navigation.ets         # NavigationFacade + 页面注册表 + 路由参数
│       │   │   ├── CryptoHelper.ets       # AES-256-GCM 加密/解密
│       │   │   ├── Difficulty.ets         # 游戏难度定义 + GameLaunchFacade
│       │   │   └── FailureHandling.ets    # 错误处理工具
│       │   │
│       │   ├── model/         # 数据模型 (2 个文件)
│       │   │   ├── Models.ets             # Command + Alert + Stats 接口
│       │   │   └── GovernanceModels.ets   # 治理模型（缺陷追踪 + 偏好快照）
│       │   │
│       │   ├── service/       # 业务服务层 (7 个文件)
│       │   │   ├── DatabaseHelper.ets     # RDB v4 + 6 表 CRUD + 默认数据
│       │   │   ├── DataRepository.ets     # 数据门面 + 格式化 + 缺陷管理 + 偏好持久化
│       │   │   ├── BackgroundImporter.ets # 自定义背景图导入
│       │   │   ├── WindowEnvironmentProvider.ets # 窗口环境感知
│       │   │   ├── DefectWorkflow.ets     # 缺陷状态机工作流
│       │   │   ├── DefectClassifier.ets   # 缺陷分类器
│       │   │   └── PickerAdapter.ets      # 文件选择器适配
│       │   │
│       │   ├── components/    # 通用组件 (10 个)
│       │   │   ├── NavSidebar.ets          # 导航侧栏（compact 模式）
│       │   │   ├── TopBar.ets              # 顶栏（响应式）
│       │   │   ├── StatusBadge.ets         # 状态徽章
│       │   │   ├── ProgressBar.ets         # 进度条（阈值变色）
│       │   │   ├── MetricCard.ets          # 指标卡
│       │   │   ├── EmptyState.ets          # 空状态
│       │   │   ├── DifficultyOption.ets    # 难度选择项
│       │   │   ├── FixedBottomNav.ets      # 固定底部导航
│       │   │   ├── GlassEffect.ets         # 毛玻璃效果工具
│       │   │   └── GlobalBackgroundLayer.ets # 全局背景层
│       │   │
│       │   └── pages/         # 页面 (11 个)
│       │       ├── AppShell.ets           # 自适应主框架
│       │       ├── Index.ets              # 首页仪表盘
│       │       ├── Commands.ets           # 快捷命令库
│       │       ├── Alerts.ets             # 告警中心
│       │       ├── Settings.ets           # 设置
│       │       ├── More.ets               # 更多菜单
│       │       ├── Games.ets              # 游戏中心
│       │       ├── Tetris.ets             # 俄罗斯方块
│       │       ├── Game2048.ets           # 2048
│       │       ├── Snake.ets              # 贪吃蛇
│       │       └── GameHistory.ets        # 游戏历史记录
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
└── oh-package.json5
```

## 页面清单

| 页面 | 说明 |
|------|------|
| AppShell | 自适应主框架（手机底部 Tab / 平板侧边栏） |
| Index | 首页仪表盘（欢迎区 + 应用概览 + 快速操作 + 最近告警） |
| Commands | 快捷命令库（分类管理 + 一键复制） |
| Alerts | 告警中心（三色分级 + 标记已处理） |
| Settings | 设置（主题 + 背景 + 毛玻璃 + 深色模式） |
| More | 更多菜单入口 |
| Games | 游戏中心（3 游戏 + 5 级难度） |
| Tetris | 俄罗斯方块 |
| Game2048 | 2048 |
| Snake | 贪吃蛇 |
| GameHistory | 游戏历史记录 |

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

## License

MIT

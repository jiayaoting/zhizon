# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · SSH 连接 Linux + Proxmox VE 管理 + 休闲娱乐

## 项目简介

智子是一款面向运维工程师、家庭实验室玩家、中小团队的**一体化服务器管理工具**，运行于鸿蒙 6+ 系统，提供：

- 🔐 **SSH 终端**：双模通信（直连 + Agent），远程连接任意 Linux 服务器，多会话管理
- 🖥️ **PVE 管理**：通过 Proxmox VE REST API 管理虚拟机/容器/存储/集群
- 📊 **资源监控**：实时查看服务器与虚拟机的 CPU/内存/磁盘/网络
- 📁 **SFTP 文件管理**：双栏文件浏览、上传下载
- 🔔 **告警通知**：资源异常、虚拟机状态变化主动推送
- ⚡ **批量操作**：多服务器命令执行、VM 批量开关机
- 🎮 **游戏中心**：俄罗斯方块、2048、贪吃蛇，5 级难度可选
- 📱 **全设备自适应**：手机（底部 Tab）、平板（侧边栏）、折叠屏自动适配
- 🎨 **多主题系统**：6 套配色 + 亮/暗模式 + 自定义背景

## 技术栈

- **开发语言**：ArkTS + Go（Agent 端）
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.1.1 (API 24)
- **数据存储**：RelationalStore (RDB v4) · 10 张持久化表
- **响应式布局**：`@StorageLink` 跨组件状态 + `display` API · 3 档断点
- **PVE API**：`@kit.NetworkKit` HTTP 调 REST API（Ticket / API Token 认证）
- **SSH 通信**：双模引擎
  - 直连模式：`@ohos/libssh` 原生 SSH 库
  - Agent 模式：Go Agent（HTTP + WebSocket）
- **凭据加密**：AES-256-GCM (CryptoArchitectureKit)
- **终端渲染**：AnsiParser + TerminalBuffer + TerminalView 自绘组件
- **多主题**：ThemePalette 接口 + 6 色彩主题 + 亮/暗模式 + 自定义背景

## 项目结构

```
zhizon/
├── agent/                     # Go Agent（服务端代理）
│   ├── go.mod
│   ├── go.sum
│   └── main.go                # HTTP + WebSocket 服务（1001 行）
│
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
│       │   ├── common/        # 主题、常量、导航、加密、难度 (7 个文件)
│       │   │   ├── Theme.ets              # 多主题系统（ThemePalette + 6 配色 + 亮/暗）
│       │   │   ├── ThemeContracts.ets     # 主题契约（ThemeMode + ThemePreference）
│       │   │   ├── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
│       │   │   ├── Navigation.ets         # NavigationFacade + 页面注册表 + 路由参数
│       │   │   ├── CryptoHelper.ets       # AES-256-GCM 凭据加密/解密
│       │   │   ├── Difficulty.ets         # 游戏难度定义 + GameLaunchFacade
│       │   │   └── FailureHandling.ets    # 错误处理工具
│       │   │
│       │   ├── model/         # 数据模型 (2 个文件)
│       │   │   ├── Models.ets             # 17 个 interface + 2 个 type
│       │   │   └── GovernanceModels.ets   # 治理模型（缺陷追踪 + 远程结果 + 偏好快照）
│       │   │
│       │   ├── service/       # 业务服务层 (13 个文件)
│       │   │   ├── DatabaseHelper.ets     # RDB v4 + 10 表 CRUD + 迁移 + 默认数据
│       │   │   ├── DataRepository.ets     # 数据门面 + 格式化 + 缺陷管理 + 偏好持久化
│       │   │   ├── SshService.ets         # AgentClient + AgentEngine + DirectEngine + SshService
│       │   │   ├── PveService.ets         # PveClient + PveService 门面
│       │   │   ├── BackgroundImporter.ets # 自定义背景图导入
│       │   │   ├── WindowEnvironmentProvider.ets # 窗口环境感知
│       │   │   ├── DefectWorkflow.ets     # 缺陷状态机工作流
│       │   │   ├── DefectClassifier.ets   # 缺陷分类器
│       │   │   ├── PickerAdapter.ets      # 文件选择器适配
│       │   │   ├── PveTransportAdapter.ets # PVE 传输适配
│       │   │   ├── RemoteOperation.ets    # 远程操作抽象
│       │   │   ├── RemoteResultAdapter.ets # 远程结果适配
│       │   │   └── SshService_new.ets     # SSH 服务重构版（WIP）
│       │   │
│       │   ├── terminal/      # 终端渲染模块 (3 个文件)
│       │   │   ├── AnsiParser.ets         # ANSI 转义序列解析器
│       │   │   ├── TerminalBuffer.ets     # 终端缓冲区管理
│       │   │   └── TerminalView.ets       # 终端渲染组件
│       │   │
│       │   ├── components/    # 通用组件 (9 个)
│       │   │   ├── NavSidebar.ets          # 导航侧栏（compact 模式）
│       │   │   ├── TopBar.ets              # 顶栏（响应式）
│       │   │   ├── StatusBadge.ets         # 状态徽章
│       │   │   ├── ProgressBar.ets         # 进度条（阈值变色）
│       │   │   ├── MetricCard.ets          # 指标卡
│       │   │   ├── EmptyState.ets          # 空状态
│       │   │   ├── DifficultyOption.ets    # 难度选择项
│       │   │   ├── FixedBottomNav.ets      # 固定底部导航
│       │   │   └── GlobalBackgroundLayer.ets # 全局背景层
│       │   │
│       │   └── pages/         # 页面 (20 个)
│       │       ├── AppShell.ets           # 自适应主框架
│       │       ├── Index.ets              # 总览仪表盘
│       │       ├── Servers.ets            # SSH 服务器列表
│       │       ├── ServerDetail.ets       # 服务器监控详情
│       │       ├── ServerForm.ets         # 添加/编辑服务器表单
│       │       ├── Terminal.ets           # SSH 终端（多会话）
│       │       ├── Files.ets              # SFTP 文件管理
│       │       ├── Pve.ets                # PVE 集群列表
│       │       ├── PveNodeDetail.ets      # PVE 节点详情
│       │       ├── VmDetail.ets           # 虚拟机详情
│       │       ├── Commands.ets           # 快捷命令库
│       │       ├── Batch.ets              # 批量操作
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
│   └── src/test/              # 单元测试 (8 个)
│       ├── DefectClassifierTest.ets
│       ├── DefectWorkflowTest.ets
│       ├── GameLaunchFacadeTest.ets
│       ├── NavigationFacadeTest.ets
│       ├── RemoteOperationTest.ets
│       ├── RemoteResultAdapterTest.ets
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
| Index | 总览仪表盘 |
| Servers | SSH 服务器列表（自动检测状态） |
| ServerDetail | 服务器监控详情 |
| ServerForm | 添加/编辑服务器（双模配置 + 凭据加密） |
| Terminal | SSH 终端（多会话 + 命令执行 + 快捷命令） |
| Files | SFTP 文件管理 |
| Pve | PVE 集群列表 |
| PveNodeDetail | PVE 节点详情（VM/存储/任务/系统 4 Tab） |
| VmDetail | 虚拟机详情（概览/快照/硬件/历史 4 Tab） |
| Commands | 快捷命令库 |
| Batch | 批量操作 |
| Alerts | 告警中心 |
| Settings | 设置（7 分组 + 多主题 + 背景） |
| More | 更多菜单入口 |
| Games | 游戏中心（3 游戏 + 5 级难度） |
| Tetris | 俄罗斯方块 |
| Game2048 | 2048 |
| Snake | 贪吃蛇 |
| GameHistory | 游戏历史记录 |

## Go Agent

在每台被管理的 Linux 服务器上部署轻量级 Go Agent，App 通过 HTTP/WebSocket 与之通信。

**端点**（默认端口 9527）：

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/metrics` | GET | 系统指标（CPU/内存/磁盘/网络） |
| `/api/exec` | POST | 执行 Shell 命令 |
| `/api/files` | GET | 列出目录文件 |
| `/api/files/upload` | POST | 上传文件（multipart） |
| `/api/files/upload-base64` | POST | 上传文件（base64 JSON） |
| `/api/files/download` | GET | 下载文件 |
| `/api/files/mkdir` | POST | 创建目录 |
| `/api/files/delete` | POST | 删除文件 |
| `/ws/terminal` | WS | WebSocket 终端中继 |
| `/ws/ssh` | WS | SSH 网关（Agent 代理 SSH 连接） |

**启动**：

```bash
cd agent && go build -o zhizon-agent .
./zhizon-agent -port 9527 -host 0.0.0.0 -token your-token
```

## 开发环境

- DevEco Studio 6.0+
- HarmonyOS SDK 6.1+ (API 24)
- ohpm 5.0+
- Go 1.21+（编译 Agent）

## 运行

1. 用 DevEco Studio 打开本项目
2. 配置签名（自动签名即可）
3. 连接鸿蒙设备或模拟器
4. 点击运行

## 详细文档

完整的架构设计、数据模型、API 对接说明等详见 [详细设计文档](doc/DESIGN.md)。

## License

MIT

# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · SSH 连接 Linux + Proxmox VE 管理

## 项目简介

智子是一款面向运维工程师、家庭实验室玩家、中小团队的**一体化服务器管理工具**，运行于鸿蒙 6+ 系统，提供：

- 🔐 **SSH 终端**：远程连接任意 Linux 服务器，多标签会话，快捷命令栏
- 🖥️ **PVE 管理**：通过 Proxmox VE REST API 管理虚拟机/容器/存储/集群
- 📊 **资源监控**：实时查看服务器与虚拟机的 CPU/内存/磁盘/网络
- 📁 **SFTP 文件管理**：双栏文件浏览、上传下载
- 🔔 **告警通知**：资源异常、虚拟机状态变化主动推送
- ⚡ **批量操作**：多服务器命令执行、VM 批量开关机
- 📱 **全设备自适应**：手机（底部 Tab）、平板（侧边栏）、折叠屏自动适配

## 技术栈

- **开发语言**：ArkTS + Go（Agent 端）
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.1.1 (API 24)
- **数据存储**：RelationalStore (RDB) · 5 张持久化表
- **响应式布局**：`@StorageLink` 跨组件状态 + `display` API · 3 档断点
- **PVE API**：`@kit.NetworkKit` HTTP 调 REST API（Ticket / API Token 认证）
- **服务器通信**：Go Agent（HTTP + WebSocket）
  - 系统指标采集：`gopsutil/v3`
  - WebSocket 终端中继：`gorilla/websocket`

## 项目结构

```
zhizon/
├── agent/                     # Go Agent（服务端代理）
│   ├── go.mod
│   └── main.go                # HTTP + WebSocket 服务
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
│       │   ├── entryability/  # UIAbility（RDB 初始化 + 沉浸式状态栏）
│       │   ├── common/        # 主题（Theme.ets）+ 常量（Constants.ets）
│       │   ├── model/         # 数据模型（13 interface）
│       │   ├── service/       # 业务服务层
│       │   │   ├── DatabaseHelper.ets  # RDB 5 表 CRUD
│       │   │   ├── DataRepository.ets  # 数据门面
│       │   │   ├── PveService.ets       # PVE API 客户端
│       │   │   ├── SshService.ets       # Agent 通信
│       │   │   └── MockData.ets         # Mock 数据
│       │   ├── components/    # 通用组件（6 个）
│       │   │   ├── NavSidebar.ets       # 导航侧栏（compact 模式）
│       │   │   ├── TopBar.ets           # 顶栏（响应式）
│       │   │   ├── StatusBadge.ets      # 状态徽章
│       │   │   ├── ProgressBar.ets      # 进度条（阈值变色）
│       │   │   ├── MetricCard.ets       # 指标卡
│       │   │   └── EmptyState.ets       # 空状态
│       │   └── pages/         # 页面（13 个）
│       │       ├── AppShell.ets         # 自适应主框架
│       │       ├── Index.ets            # 总览仪表盘
│       │       ├── Servers.ets          # SSH 服务器列表
│       │       ├── ServerDetail.ets     # 服务器监控详情
│       │       ├── Terminal.ets         # SSH 终端
│       │       ├── Files.ets            # SFTP 文件管理
│       │       ├── Pve.ets              # PVE 集群列表
│       │       ├── PveNodeDetail.ets    # PVE 节点详情
│       │       ├── VmDetail.ets         # 虚拟机详情
│       │       ├── Commands.ets         # 快捷命令库
│       │       ├── Batch.ets            # 批量操作
│       │       ├── Alerts.ets           # 告警中心
│       │       └── Settings.ets         # 设置
│       ├── resources/         # 资源文件
│       └── module.json5       # 模块配置
│
├── build-profile.json5        # 根构建配置
└── oh-package.json5
```

## 页面清单

| 页面 | 说明 |
|------|------|
| AppShell | 自适应主框架（手机底部 Tab / 平板侧边栏） |
| Index | 总览仪表盘 |
| Servers | SSH 服务器列表 |
| ServerDetail | 服务器监控详情 |
| Terminal | SSH 终端（多会话 + 快捷命令） |
| Files | SFTP 文件管理 |
| Pve | PVE 集群列表 |
| PveNodeDetail | PVE 节点详情（VM/存储/任务/系统 4 Tab） |
| VmDetail | 虚拟机详情（概览/快照/硬件/历史 4 Tab） |
| Commands | 快捷命令库 |
| Batch | 批量操作 |
| Alerts | 告警中心 |
| Settings | 设置 |

## Go Agent

在每台被管理的 Linux 服务器上部署轻量级 Go Agent，App 通过 HTTP/WebSocket 与之通信。

**端点**（默认端口 9527）：

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/metrics` | GET | 系统指标（CPU/内存/磁盘/网络） |
| `/api/exec` | POST | 执行 Shell 命令 |
| `/api/files` | GET | 列出目录文件 |
| `/api/files/upload` | POST | 上传文件 |
| `/api/files/download` | GET | 下载文件 |
| `/api/files/mkdir` | POST | 创建目录 |
| `/api/files/delete` | POST | 删除文件 |
| `/ws/terminal` | WS | WebSocket 终端中继 |

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

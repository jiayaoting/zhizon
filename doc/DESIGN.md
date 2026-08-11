# 智子（Zhizon）详细设计文档

> **版本**：v4.0.0
> **平台**：HarmonyOS NEXT（鸿蒙 6+ / 纯血鸿蒙）
> **Bundle Name**：`com.zhizon.manager`
> **开发语言**：ArkTS
> **文档状态**：v4.0 当前实现版（游戏中心 + 多主题系统 + 终端渲染 + 缺陷追踪 + 治理模型）

---

## 一、产品概述

### 1.1 产品定位

**智子**是一款运行于鸿蒙 6+ 系统的**一体化服务器管理工具**，面向运维工程师、家庭实验室玩家、中小团队管理员，在手机/平板上同时提供：

- 🔐 **SSH 终端**：远程连接任意 Linux 服务器，执行命令
- 🖥️ **PVE 管理**：通过 Proxmox VE REST API 管理虚拟机/容器/存储/集群
- 📊 **资源监控**：实时查看服务器与虚拟机的 CPU/内存/磁盘/网络
- 📁 **SFTP 文件管理**：双栏文件浏览、上传下载
- 🔔 **告警通知**：资源异常、虚拟机状态变化主动推送
- ⚡ **批量操作**：多服务器命令执行、VM 批量开关机
- 📱 **全设备自适应**：手机（底部 Tab）、平板（侧边栏）、折叠屏（紧凑侧栏）

### 1.2 用户画像

| 角色 | 典型场景 |
|------|---------|
| 家庭实验室玩家 | PVE 跑虚拟机/CT，手机随时开关机、看状态 |
| 中小企业运维 | 管理几台物理机 + 几十个 VM，移动办公 |
| 开发者 | 远程登开发机、调试、查看日志 |
| DevOps 工程师 | 批量操作、自动化脚本、监控告警 |

### 1.3 与同类产品差异化

| 对比项 | Termius | ServerCat | **智子** |
|--------|---------|-----------|---------|
| SSH 终端 | ✅ | ✅ | ✅ |
| PVE 原生管理 | ❌ | ❌ | ✅ |
| 鸿蒙原生 | ❌ | ❌ | ✅ |
| 离线密钥管理 | ✅ | ✅ | ✅ |
| 多端同步 | ✅(云) | ❌ | 本地优先 |
| 自适应布局 | ❌ | ❌ | ✅ |

---

## 二、技术架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              AppShell 自适应主框架                │
│  3 档断点 (isSm/isMd/isLg) @StorageLink 响应式   │
├─────────────────────────────────────────────────┤
│                  ArkUI 表现层                    │
│   20 Pages + 9 Components + @State 状态管理     │
│   全异步数据加载 (aboutToAppear + await)         │
├─────────────────────────────────────────────────┤
│                  业务逻辑层                      │
│   SshService (策略门面) │ PveService (PveClient) │
│   DataRepository (CRUD 门面 + 辅助函数)         │
│   CryptoHelper (AES-256-GCM 凭据加密)           │
│   BackgroundImporter (沙箱背景图导入)           │
│   DefectWorkflow (缺陷状态机)                   │
│   WindowEnvironmentProvider (窗口环境感知)       │
├─────────────────────────────────────────────────┤
│              引擎层 (双模通信)                   │
│   SshEngine 接口                                │
│   ├─ AgentEngine (封装 AgentClient)             │
│   └─ DirectEngine (@ohos/libssh 直连)           │
├─────────────────────────────────────────────────┤
│                  数据访问层                      │
│   DatabaseHelper (RDB Store v4) │ 10 张持久化表 │
│   servers / pve_clusters / commands / alerts /   │
│   settings / game_scores / defects /            │
│   defect_evidence / defect_history /            │
│   defect_fix_results                            │
├─────────────────────────────────────────────────┤
│              远程通信层                          │
│   Go Agent (HTTP + WebSocket) │ @ohos/libssh    │
│   /api/metrics /api/exec /api/files             │
│   /api/files/upload-base64 /ws/terminal /ws/ssh │
├─────────────────────────────────────────────────┤
│            HarmonyOS 系统能力                    │
│   NetworkKit │ CryptoArchitectureKit │ ArkData  │
│   @ohos/libssh │ PromptAction │ display API     │
└─────────────────────────────────────────────────┘
```

### 2.2 双模通信架构

智子支持两种 SSH 通信模式，通过 `SshEngine` 接口统一抽象：

| 模式 | 引擎 | 通信方式 | 适用场景 |
|------|------|---------|---------|
| **Agent 模式** | `AgentEngine` | HTTP + WebSocket → Go Agent | 已部署 Agent 的服务器 |
| **直连模式** | `DirectEngine` | @ohos/libssh 原生 SSH 直连 | 未部署 Agent 的快速连接 |

**策略门面设计**：
- `SshService` 根据 `server.connectionMode` 选择引擎
- 每个服务器独立维护引擎实例（`Map<serverId, SshEngine>`）
- 引擎懒加载，首次调用时创建
- 对 UI 层完全透明，切换模式不影响交互

**SshEngine 接口方法**：

| 方法 | 说明 |
|------|------|
| `connect(config)` | 建立连接 |
| `disconnect()` | 断开连接 |
| `isConnected()` | 查询连接状态 |
| `exec(cmd, timeout?)` | 执行命令 |
| `openTerminal(cols?, rows?)` | 开启终端 |
| `onTerminalData(cb)` | 注册终端数据回调 |
| `sendTerminalInput(data)` | 发送终端输入 |
| `closeTerminal()` | 关闭终端 |
| `resizeTerminal?(cols, rows)` | 调整终端大小（可选） |
| `getMetrics()` | 获取指标 |
| `listFiles(path)` | 列出文件 |
| `uploadFile(local, remote, onProgress?)` | 上传文件 |
| `downloadFile(remote, local, onProgress?)` | 下载文件 |

**DirectEngine 特点**：
- 基于 `@ohos/libssh` 原生 SSH 库，支持密码和密钥认证
- 连接成功检测：通过 `waitForCallback` 包装 callback Promise（原生层 `startSSHClient` 进入死循环，Promise 永不 resolve）
- 支持 `exec` 命令执行、`getMetrics` 系统指标、`listFiles` SFTP 只读文件列表
- 30s keepalive 心跳保持连接
- **终端降级**：流式终端、SFTP 上传/下载均降级到 Agent 模式

**AgentEngine 特点**：
- 封装 `AgentClient`（HTTP 客户端，默认端口 9527）
- WebSocket 终端 + SSH 网关（`/ws/ssh`）
- 支持连接事件回调、resize、传输进度

### 2.3 技术选型

| 模块 | 技术方案 | 实现状态 |
|------|---------|---------|
| 开发语言 | ArkTS + Go (Agent) | ✅ |
| UI 框架 | ArkUI 声明式 + Stage 模型 | ✅ |
| 目标 SDK | HarmonyOS 6.1.1 (API 24) | ✅ |
| 数据存储 | RelationalStore (RDB v4) + 10 表 | ✅ |
| SSH 通信 | 双模：AgentEngine + DirectEngine | ✅ |
| 凭据加密 | AES-256-GCM (CryptoArchitectureKit) | ✅ |
| PVE API | `@kit.NetworkKit` HTTP 调 REST API | ✅ |
| 服务器指标 | Go Agent gopsutil / DirectEngine exec 命令解析 | ✅ |
| 文件管理 | Go Agent HTTP API / DirectEngine SFTP 只读 | ✅ |
| 命令执行 | SshEngine.exec (双模路由) | ✅ |
| 响应式 | @StorageLink 跨组件状态 + display API | ✅ |
| 终端渲染 | AnsiParser + TerminalBuffer + TerminalView | ✅ |
| 多主题系统 | ThemePalette + 6 配色 + 亮/暗模式 | ✅ |
| 游戏中心 | 3 游戏 + 5 级难度 + 历史记录 | ✅ |
| 缺陷追踪 | DefectRecord + DefectWorkflow + DefectClassifier | ✅ |
| 导航系统 | NavigationFacade + PageRegistry + 类型化路由参数 | ✅ |
| 图表渲染 | 自绘 Canvas | 🚧 规划 |
| 后台保活 | BackgroundTaskKit | 🚧 规划 |

### 2.4 凭据加密设计

**实现文件**：[common/CryptoHelper.ets](file:///workspace/zhizon/entry/src/main/ets/common/CryptoHelper.ets)（113 行）

| 特性 | 说明 |
|------|------|
| 算法 | AES-256-GCM (CryptoArchitectureKit) |
| 密钥存储 | preferences 持久化（应用沙箱） |
| 首次运行 | 自动生成 256 位随机密钥并持久化 |
| IV | 每次加密生成 12 字节随机 IV |
| 密文格式 | `v1:<base64IV>:<base64Ciphertext+AuthTag>` |
| 初始化时机 | `EntryAbility.onWindowStageCreate`（延迟初始化避免 "build context for init fail"） |

**GcmParamsSpec 参数**：
- `iv: { data: Uint8Array }` — 12 字节随机 IV
- `aad: { data: new Uint8Array(0) }` — 空附加认证数据
- `authTag: { data: new Uint8Array(0) }` — 加密时传空，authTag 附加在 doFinal 输出末尾
- `algName: 'GcmParamsSpec'`

---

## 三、目录结构

```
zhizon/
├── .gitignore
├── README.md
├── build-profile.json5                    # 根构建配置
├── hvigorfile.ts
├── oh-package.json5
├── agent/                                 # Go Agent（服务端代理）
│   ├── go.mod
│   ├── go.sum
│   └── main.go                            # 1001 行，含 HTTP + WebSocket + SSH 网关
│
├── doc/
│   └── DESIGN.md                          # 本文档
│
├── AppScope/                              # 应用全局配置
│   ├── app.json5                          # BundleName + 版本
│   └── resources/base/element/
│       └── string.json                    # app_name = "智子"
│
└── entry/                                 # 主模块
    ├── build-profile.json5
    ├── hvigorfile.ts
    ├── oh-package.json5
    ├── obfuscation-rules.txt
    └── src/main/
        ├── module.json5                   # UIAbility 注册
        ├── resources/
        │   └── base/
        │       ├── element/color.json
        │       ├── element/string.json
        │       └── profile/main_pages.json  # 9 路由（AppShell + ServerDetail + PveNodeDetail + VmDetail + ServerForm + Tetris + Game2048 + Snake + GameHistory）
        │
        └── ets/
            ├── entryability/
            │   └── EntryAbility.ets       # 应用入口（延迟初始化加密+数据库）
            │
            ├── common/                    # 🎨 主题与常量（7 个）
            │   ├── Theme.ets              # 多主题系统 + ThemePalette + 6 配色 + 亮/暗模式
            │   ├── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
            │   ├── CryptoHelper.ets       # AES-256-GCM 凭据加密/解密
            │   ├── Difficulty.ets         # 游戏难度定义（5 级：超简单/简单/中等/困难/地狱）
            │   ├── FailureHandling.ets    # 统一失败处理（AppFailure + RecoverableResult）
            │   ├── Navigation.ets         # 导航系统（NavigationFacade + 类型化路由参数）
            │   └── ThemeContracts.ets     # 主题契约接口（ThemePalette + PreferenceSnapshot）
            │
            ├── model/                     # 📦 数据模型（2 个）
            │   ├── Models.ets             # 17 个 interface + type（含 ConnEvent/TransferProgress/AnsiSegment/TerminalSession）
            │   └── GovernanceModels.ets   # 治理模型（AppFailure + RecoverableResult + RemoteResult + DefectRecord 等）
            │
            ├── service/                   # 🔧 业务服务层（13 个）
            │   ├── DatabaseHelper.ets    # RDB Store v4 + 10 表 CRUD + 默认数据播种
            │   ├── DataRepository.ets    # 数据门面 + 格式化工具 + PVE 代理方法
            │   ├── PveService.ets         # PveClient + PveService 门面
            │   ├── SshService.ets         # AgentClient + AgentEngine + DirectEngine + SshService 门面
            │   ├── SshService_new.ets     # SSH 服务重构版（WIP）
            │   ├── BackgroundImporter.ets # 沙箱背景图导入 + 强度调节
            │   ├── DefectClassifier.ets   # 缺陷分类器
            │   ├── DefectWorkflow.ets     # 缺陷状态机工作流
            │   ├── PickerAdapter.ets      # 选择器适配器
            │   ├── PveTransportAdapter.ets # PVE 传输适配器
            │   ├── RemoteOperation.ets   # 远程操作封装
            │   ├── RemoteResultAdapter.ets # 远程结果适配器
            │   └── WindowEnvironmentProvider.ets # 窗口环境感知
            │
            ├── terminal/                  # 🖥️ 终端渲染模块（3 个）
            │   ├── AnsiParser.ets        # ANSI 转义序列解析（颜色/加粗/斜体/下划线）
            │   ├── TerminalBuffer.ets    # 终端缓冲区（行管理 + 滚动）
            │   └── TerminalView.ets      # 终端渲染组件（Mono 字体 + 状态着色 + 自动滚动）
            │
            ├── components/                # 🧩 通用组件 (9 个)
            │   ├── NavSidebar.ets         # 左侧导航栏（支持 compact 模式）
            │   ├── TopBar.ets             # 顶栏（响应式 padding）
            │   ├── StatusBadge.ets        # 状态徽章
            │   ├── ProgressBar.ets        # 进度条（阈值变色）
            │   ├── MetricCard.ets         # 指标卡
            │   ├── EmptyState.ets         # 空状态占位
            │   ├── DifficultyOption.ets   # 难度选择项（图标 + 标签 + 描述 + 选中态）
            │   ├── FixedBottomNav.ets     # 固定底部导航（手机端 5 Tab + 更多）
            │   └── GlobalBackgroundLayer.ets # 全局背景层（自定义背景图 + 强度调节）
            │
            ├── pages/                     # 📱 20 个页面
            │   ├── AppShell.ets           # 自适应主框架（底部Tab / 侧边栏切换）
            │   ├── Index.ets              # 总览仪表盘
            │   ├── Servers.ets            # SSH 服务器列表（自动检测状态）
            │   ├── ServerDetail.ets       # 服务器监控详情
            │   ├── ServerForm.ets         # 添加/编辑服务器表单
            │   ├── Terminal.ets           # SSH 终端（多会话 + 命令执行）
            │   ├── Files.ets              # SFTP 文件管理
            │   ├── Pve.ets                # PVE 集群列表 + 添加对话框
            │   ├── PveNodeDetail.ets      # PVE 节点详情
            │   ├── VmDetail.ets           # 虚拟机详情
            │   ├── Commands.ets           # 快捷命令库
            │   ├── Batch.ets              # 批量操作
            │   ├── Alerts.ets             # 告警中心
            │   ├── Settings.ets           # 设置
            │   ├── More.ets               # 更多功能入口
            │   ├── Games.ets              # 游戏中心入口（3 游戏 + 难度选择器）
            │   ├── Tetris.ets             # 俄罗斯方块（7 种方块 + 旋转/移动/消行）
            │   ├── Game2048.ets           # 2048（4x4 棋盘 + 滑动合并）
            │   ├── Snake.ets              # 贪吃蛇（方向控制 + 食物 + 碰撞检测）
            │   └── GameHistory.ets        # 游戏历史记录（分数 + 难度 + 排行）
            │
            └── test/                      # 🧪 单元测试（8 个）
                ├── DefectClassifier.test.ets
                ├── DefectWorkflow.test.ets
                ├── GameLaunch.test.ets
                ├── Navigation.test.ets
                ├── RemoteOperation.test.ets
                ├── RemoteResultAdapter.test.ets
                ├── WindowEnvironmentProvider.test.ets
                └── WindowEnvironmentSnapshot.test.ets
```

---

## 四、功能模块设计

### 4.1 功能全景图

```
智子 (Zhizon)
├── 1. SSH 服务器管理
│   ├── 服务器列表（分组筛选 + 自动检测状态 + 资源指标）
│   ├── 服务器监控详情（4 指标 + 趋势占位 + Top 进程 + 相关告警）
│   ├── 添加/编辑服务器（密码/密钥认证，直连/Agent 双模）
│   ├── 分组与标签
│   └── 凭据加密存储（AES-256-GCM）
│
├── 2. SSH 终端
│   ├── 多会话标签 Tab（切换不同服务器）
│   ├── 命令输入与 exec 执行
│   ├── 终端输出区域（Mono 字体，自动滚动）
│   ├── 自定义服务器选择弹窗
│   └── 连接状态实时显示
│
├── 3. PVE 集群管理
│   ├── PVE 集群列表（同步状态 + 节点 VM/CT 计数）
│   ├── 添加集群对话框（表单 + Scroll + 移动端适配）
│   ├── PVE 节点详情（4 Tab：VM/存储/任务/系统信息）
│   └── 虚拟机详情（4 Tab：概览/快照/硬件/历史）
│
├── 4. SFTP 文件管理
│   ├── 双栏布局（本地/远程）
│   ├── 面包屑导航
│   ├── 文件列表（emoji + 名称 + 修改时间 + 大小 + 权限）
│   ├── 传输队列
│   └── 自定义服务器选择弹窗
│
├── 5. 资源监控
│   ├── MetricCard 数字卡
│   ├── ProgressBar 进度条（阈值变色）
│   └── 状态徽章
│
├── 6. 快捷命令库
│   ├── 分类（7 种） + 命令卡片网格
│   ├── 复制到剪贴板
│   └── 使用次数统计
│
├── 7. 批量操作
│   ├── 多服务器勾选 + 命令输入
│   ├── 常用模板
│   └── 并行执行结果
│
├── 8. 告警中心
│   ├── 三色统计 + 过滤标签
│   ├── 告警卡片
│   └── 标记已处理
│
├── 9. 系统设置
│   ├── 常规（端口/超时/重连）
│   ├── 外观（主题/字号/字体）
│   ├── 终端（字体/光标/滚屏/256色）
│   ├── 安全（生物识别/指纹校验）
│   ├── 通知（推送/勿扰/阈值）
│   ├── 数据（导出/导入/备份）
│   └── 关于（版本/更新/协议）
│
├── 10. 游戏中心
│   ├── 俄罗斯方块（5 级难度 + 触屏手势 + 按钮双控制）
│   ├── 2048（5 级难度 + 滑动操作）
│   ├── 贪吃蛇（5 级难度 + 方向控制）
│   ├── 游戏难度选择（5 级：超简单/简单/中等/困难/地狱）
│   └── 游戏历史记录（分数 + 难度 + 排行）
│
├── 11. 多主题系统
│   ├── 6 套配色（终端青绿/海洋蓝/日落橙/极光紫/樱花粉/自然绿）
│   ├── 亮/暗模式（跟随系统或手动）
│   ├── 自定义背景图（沙箱导入 + 强度调节）
│   └── 字号缩放（小/标准/大）
│
└── 12. 缺陷追踪
    ├── 缺陷记录（症状/步骤/预期/实际/设备信息）
    ├── 状态机（分析中→待修复→待验证→已确认）
    ├── 验证证据（静态/代码/设备/用户确认）
    └── 修复结果（影响范围/验证条件/残余风险）
```

### 4.2 各模块详细设计

---

#### 模块 1：SSH 服务器管理

**实现位置**：[pages/Servers.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Servers.ets)（507 行）、[pages/ServerForm.ets](file:///workspace/zhizon/entry/src/main/ets/pages/ServerForm.ets)（501 行）、[pages/ServerDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/ServerDetail.ets)（375 行）

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 服务器列表展示 | ✅ 卡片式，含状态点 + StatusBadge + CPU/内存/磁盘进度条 |
| 分组筛选 | ✅ 6 分组（全部/生产/测试/监控/备份/CI/CD） |
| 添加/编辑服务器 | ✅ ServerForm 完整表单（名称/地址/端口/用户名/密码/密钥/连接模式/Agent Token） |
| 连接测试 | ✅ testConnectionEx 返回 TestResult(ok + message) |
| 自动检测状态 | ✅ aboutToAppear 加载后自动并发检测所有服务器 |
| 服务器详情 | ✅ 头部卡 + 4 指标 + 趋势占位 + Top 进程 + 相关告警 |
| 连接终端 | ✅ 跳转 Terminal 页面 |
| 快速操作 | ✅ 连接/终端/详情三按钮 |

---

#### 模块 2：SSH 终端

**实现位置**：[pages/Terminal.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Terminal.ets)（505 行）

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 多会话 Tab | ✅ 顶部 Tab 切换多个服务器会话 |
| 命令输入与执行 | ✅ TextInput + 发送按钮，通过 SshService.exec 执行 |
| 终端输出 | ✅ 黑底 + Mono 字体，自动滚动 |
| 连接状态 | ✅ 状态点 + "已连接"/"未连接" 显示 |
| 重连按钮 | ✅ 未连接时显示"重新连接"按钮 |
| 服务器选择 | ✅ 自定义弹窗（名称/地址/模式标签/状态点/箭头） |
| 加载状态 | ✅ LoadingProgress + "连接中..." |
| 初始信息 | ✅ getTerminalOutput 获取 uptime/free -h/df 等系统信息 |

---

#### 模块 3：PVE 集群管理（核心差异化）

**实现位置**：[pages/Pve.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Pve.ets)、[pages/PveNodeDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/PveNodeDetail.ets)、[pages/VmDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/VmDetail.ets)、[service/PveService.ets](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets)（370 行）

**3.1 PVE 集群列表**

| 功能 | 实现状态 |
|------|---------|
| 集群卡片 | ✅ 集群名 + 状态 + host:port + 版本 + 最后同步 |
| 节点统计 | ✅ VM 总数/CT 总数聚合显示 |
| 添加 PVE 集群 | ✅ 对话框（名称/地址/端口/用户名/密码，表单 Scroll + 移动端 88% 宽度） |
| 删除集群 | ✅ 长按或点击删除按钮 |

**3.2 PVE 节点详情**

| Tab | 功能 |
|-----|------|
| **虚拟机** | 搜索 + 5 过滤标签 + VM 列表（状态/资源/操作按钮） |
| **存储池** | 类型徽章 + 容量进度条 |
| **任务中心** | 任务列表 + 状态 + 进度条 |
| **系统信息** | 内核/版本/CPU/内存/磁盘/网络/运行时长 |

**3.3 虚拟机详情**

| 区域 | 功能 |
|------|------|
| 头部卡 | 类型图标 + 名称 + 状态 + 元信息 |
| 操作按钮组 | 启动/停止/重启/暂停/恢复 |
| 4 指标卡 | CPU/内存/磁盘/网络 |
| Tab 概览 | 系统信息 + 标签 + 最近操作 |
| Tab 快照 | 创建快照 + 回滚/删除 |
| Tab 硬件 | 处理器/内存/存储/网络 |
| Tab 历史 | 按 vmid 过滤任务 |

---

#### 模块 4：SFTP 文件管理

**实现位置**：[pages/Files.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Files.ets)（627 行）

| 功能 | 实现状态 |
|------|---------|
| 双栏布局 | ✅ 本地 + 远程 |
| 面包屑导航 | ✅ / > root > logs |
| 文件项展示 | ✅ emoji + 名称 + 修改时间 + 大小 + 权限 |
| 传输队列 | ✅ 2 条 mock 记录 + 进度条 |
| 服务器选择 | ✅ 自定义弹窗（替代原来 Select 下拉） |
| 上传/下载 | 🚧 UI 占位 |

---

#### 模块 5：快捷命令库

**实现位置**：[pages/Commands.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Commands.ets)

| 功能 | 实现状态 |
|------|---------|
| 分类列表 | ✅ 7 分类 + 计数徽章，横滑胶囊栏（手机）/ 侧栏（平板） |
| 命令卡片 | ✅ 网格布局，mono 字体显示命令内容 |
| 使用次数 | ✅ 按 uses 排序，点击自增 |
| 复制命令 | ✅ promptAction.showToast |

---

#### 模块 6：批量操作

**实现位置**：[pages/Batch.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Batch.ets)

| 功能 | 实现状态 |
|------|---------|
| 服务器勾选 | ✅ 复选框 + 全选/取消 |
| 命令输入 | ✅ TextArea + 模板快捷插入 |
| 常用模板 | ✅ 4 模板（系统信息/磁盘检查/服务重启/日志查看） |
| 执行结果 | ✅ 并行执行 + 展开详情 |
| 响应式 | ✅ 手机端紧凑样式，md 尺寸下减小间距 |

---

#### 模块 7：告警中心

**实现位置**：[pages/Alerts.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Alerts.ets)

| 功能 | 实现状态 |
|------|---------|
| 三色统计 | ✅ 严重/警告/信息 MetricCard |
| 过滤标签 | ✅ 5 种（全部/未处理/严重/警告/信息） |
| 告警卡片 | ✅ 左侧 3px 色条 + 标题 + 详情 + 来源 + 时间 |
| 标记已处理 | ✅ 局部覆盖 + 已处理 opacity 0.5 |
| 全部已读 | ✅ 一键标记 |

---

#### 模块 8：系统设置

**实现位置**：[pages/Settings.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Settings.ets)

**7 个分组**：

| 分组 | 配置项 | 持久化 |
|------|--------|--------|
| 常规 | SSH 端口 / 超时 / 自动重连(开关) | ✅ RDB |
| 外观 | 主题 / 字号 / 字体 | 仅 UI |
| 终端 | 默认字体 / 光标 / 滚屏 / 256 色(开关) | ✅ RDB |
| 安全 | 生物识别(开关) / 自动锁定 / 指纹校验(开关) | ✅ RDB |
| 通知 | 告警推送(开关) / 勿扰 / 阈值 | ✅ RDB |
| 数据 | 导出/导入/清除/自动备份(开关) | 🚧 |
| 关于 | 版本 / 更新 / 协议 / 反馈 | 仅展示 |

---

#### 模块 9：游戏中心

**实现位置**：[pages/Games.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Games.ets)、[pages/Tetris.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Tetris.ets)（794 行）、[pages/Game2048.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Game2048.ets)（592 行）、[pages/Snake.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Snake.ets)（636 行）、[pages/GameHistory.ets](file:///workspace/zhizon/entry/src/main/ets/pages/GameHistory.ets)（213 行）、[common/Difficulty.ets](file:///workspace/zhizon/entry/src/main/ets/common/Difficulty.ets)（201 行）

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 游戏中心入口 | ✅ 3 游戏 + 难度选择器 |
| 俄罗斯方块 | ✅ 7 种方块 + 旋转/移动/消行 + 5 级难度 |
| 2048 | ✅ 4x4 棋盘 + 滑动合并 + 5 级难度 |
| 贪吃蛇 | ✅ 方向控制 + 食物 + 碰撞检测 + 5 级难度 |
| 游戏难度 | ✅ 5 级（超简单/简单/中等/困难/地狱） |
| GameLaunchFacade | ✅ 启动参数验证 + 路由跳转 |
| 游戏历史 | ✅ 分数记录 + 难度标记 + 排行 |

---

#### 模块 10：多主题系统

**实现位置**：[common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets)（758 行）、[common/ThemeContracts.ets](file:///workspace/zhizon/entry/src/main/ets/common/ThemeContracts.ets)、[service/BackgroundImporter.ets](file:///workspace/zhizon/entry/src/main/ets/service/BackgroundImporter.ets)、[components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets)

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 6 套配色 | ✅ CYAN/OCEAN/SUNSET/AURORA/SAKURA/FOREST |
| 亮/暗模式 | ✅ 跟随系统或手动切换 |
| ThemePalette 接口 | ✅ 30+ 颜色字段 + 8 级字号 |
| 自定义背景 | ✅ 沙箱导入 + 强度调节 |
| 偏好持久化 | ✅ PreferenceSnapshot + RDB |
| 偏好回滚 | ✅ PreferencePersistenceResult |

---

#### 模块 11：终端渲染模块

**实现位置**：[terminal/AnsiParser.ets](file:///workspace/zhizon/entry/src/main/ets/terminal/AnsiParser.ets)（269 行）、[terminal/TerminalBuffer.ets](file:///workspace/zhizon/entry/src/main/ets/terminal/TerminalBuffer.ets)（121 行）、[terminal/TerminalView.ets](file:///workspace/zhizon/entry/src/main/ets/terminal/TerminalView.ets)（206 行）

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| ANSI 解析 | ✅ 颜色/加粗/斜体/下划线 |
| 终端缓冲区 | ✅ 行管理 + 滚动 |
| 终端渲染 | ✅ Mono 字体 + 状态着色 + 自动滚动 |

---

#### 模块 12：缺陷追踪

**实现位置**：[model/GovernanceModels.ets](file:///workspace/zhizon/entry/src/main/ets/model/GovernanceModels.ets)（135 行）、[service/DefectWorkflow.ets](file:///workspace/zhizon/entry/src/main/ets/service/DefectWorkflow.ets)（137 行）、[service/DefectClassifier.ets](file:///workspace/zhizon/entry/src/main/ets/service/DefectClassifier.ets)

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 缺陷记录 | ✅ DefectRecord 完整字段 |
| 状态机 | ✅ 6 状态（分析中/待信息/待修复/待验证/已确认/未复现） |
| 验证证据 | ✅ 4 类型（静态/代码/设备/用户确认） |
| 修复结果 | ✅ 影响范围 + 验证条件 + 残余风险 |
| 状态历史 | ✅ DefectStateHistory 变更记录 |

---

#### 模块 13：导航系统

**实现位置**：[common/Navigation.ets](file:///workspace/zhizon/entry/src/main/ets/common/Navigation.ets)（376 行）

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| NavigationFacade | ✅ 页面注册表 + 导航验证 |
| 类型化路由参数 | ✅ 7 种 RouteParams 类 |
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
│  SAFE_TOP = 34vp              │
│  ┌────────────────────────┐  │
│  │     页面内容 (可滚动)    │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  5 个 Tab + 更多  ⋯    │  │
│  │  (高度 56vp)           │  │
│  │  SAFE_BOTTOM = 12vp    │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- 5 个主 Tab：总览 / SSH 服务器 / PVE 集群 / SSH 终端 / 告警中心
- "更多"按钮展开：文件管理 / 快捷命令 / 批量操作 / 设置
- 更多菜单带半透明遮罩，点击关闭

### 5.3 平板布局（isSm = false）

```
┌────┬─────────────────────────┐
│    │  SAFE_TOP = 34vp        │
│ 侧 │  ┌──────────────────┐  │
│ 边 │  │    页面内容       │  │
│ 栏 │  │    (可滚动)       │  │
│    │  └──────────────────┘  │
│ 160│                          │
│ 或 │  SAFE_BOTTOM = 12vp     │
│ 220│                          │
└────┴─────────────────────────┘
```

- **紧凑模式**（isMd）：NavSidebar 仅显示图标 + 选中指示条
- **标准模式**（isLg）：NavSidebar 显示图标 + 文字 + 选中装饰条 + 用户信息

### 5.4 响应式实现机制

```typescript
// AppShell.ets
@StorageLink('isSm') isSm: boolean = true;   // 默认 true（安全兜底）
@StorageLink('isMd') isMd: boolean = false;
@StorageLink('isLg') isLg: boolean = false;

aboutToAppear() {
  const d = display.getDefaultDisplaySync();
  const vpWidth = px2vp(d.width);
  this.applyWidth(vpWidth);  // 立即赋值，触发全应用响应式
}
```

### 5.5 各页面响应式适配

| 页面 | 手机端适配 |
|------|-----------|
| Index | 统计卡 2×2 网格，平板 1×4 横排 |
| Servers | 分组标签横滑，padding 16vp |
| Terminal | 服务器选择弹窗 92% 宽度，最大 500px |
| Pve | 添加对话框 maxHeight 85%，宽度 88% |
| Commands | 分类横滑胶囊栏 |
| Batch | 紧凑 padding，文字截断 |
| 所有页面 | padding: `isSm ? 16 : 24` |

---

## 六、数据模型设计

### 6.1 核心实体

详见 [model/Models.ets](file:///workspace/zhizon/entry/src/main/ets/model/Models.ets)（217 行），共 17 个 interface + type，新增 `ConnEvent`、`TransferProgress`、`AnsiSegment`、`TerminalSession`：

| 实体 | 说明 | 关键字段 |
|------|------|---------|
| `Server` | SSH 服务器 | id, host, port, username, authType, connectionMode, agentToken, privateKeyPath, password?, privateKeyContent?, group, tags, os, status, metrics |
| `ServerMetrics` | 服务器指标 | cpu, mem, disk, netIn, netOut, load, uptime |
| `TestResult` | 连接测试结果 | ok, message |
| `SshKey` | SSH 密钥 | id, name, type(rsa/ed25519/ecdsa), fingerprint |
| `PveCluster` | PVE 集群 | id, host, port, username, authType, verifyTls, version, nodes[] |
| `PveNode` | PVE 物理节点 | node, status, cpu, maxcpu, mem, maxmem, disk, maxdisk, vmCount, ctCount |
| `Vm` | 虚拟机/容器 | vmid, name, node, type(qemu/lxc), status, cpu, mem, maxmem, maxdisk, netin, netout |
| `Storage` | 存储池 | name, type(dir/lvmthin/zfs/nfs), node, used, total, status |
| `PveTask` | PVE 任务 | id, node, upid, type, status, progress, startTime |
| `Snapshot` | VM 快照 | name, vmid, date, size, desc |
| `Command` | 快捷命令 | id, name, cmd, category, uses |
| `Alert` | 告警 | id, level(critical/warning/info), source, title, detail, resolved |
| `FileItem` | 文件项 | name, type(dir/file), size, modified, perms |
| `TransferItem` | 传输项 | id, name, direction, progress, status, speed |
| `Stats` | 统计聚合 | total, online, warning, offline, alerts, pveNodes, vmTotal, vmRunning... |
| `TerminalSession` | 终端会话 | id, serverName, cwd, history[] |
| `ConnEvent` | 连接事件 | type, message, timestamp |
| `TransferProgress` | 传输进度 | transferred, total, speed |
| `AnsiSegment` | ANSI 解析段 | text, color, bold, italic, underline |

**治理模型**：详见 [model/GovernanceModels.ets](file:///workspace/zhizon/entry/src/main/ets/model/GovernanceModels.ets)（135 行），含 `AppFailure`、`RecoverableResult`、`RemoteResult`、`DefectRecord`、`DefectEvidence`、`DefectStateHistory`、`DefectFixResult` 等。

### 6.2 数据存储方案

| 数据类型 | 存储方式 | 状态 |
|---------|---------|------|
| SSH 服务器配置 | RDB `servers` 表 | ✅ |
| 加密凭据 | AES-256-GCM 加密后存 RDB | ✅ |
| PVE 集群配置 | RDB `pve_clusters` 表 | ✅ |
| 快捷命令 | RDB `commands` 表 | ✅ |
| 告警记录 | RDB `alerts` 表 | ✅ |
| 应用设置 | RDB `settings` 表 | ✅ |
| 游戏分数记录 | RDB `game_scores` 表 | ✅ |
| 缺陷记录 | RDB `defects` 表 | ✅ |
| 缺陷证据 | RDB `defect_evidence` 表 | ✅ |
| 缺陷状态历史 | RDB `defect_status_history` 表 | ✅ |
| 缺陷修复结果 | RDB `defect_fix_results` 表 | ✅ |
| 加密主密钥 | preferences 持久化 | ✅ |
| 服务器实时指标 | exec 命令解析 / Agent API 实时获取 | ✅ |
| PVE 节点/VM 数据 | PVE REST API 实时获取 | ✅ |

### 6.3 数据库表结构

**数据库版本**：v4

**servers 表 (v4)**：id(PK), name, host, port, username, auth_type, password_enc, key_id, key_content, grp, tags, os, created_at, last_connected, connection_mode(默认 'direct'), agent_token, private_key_path

**pve_clusters 表**：id(PK), name, host, port, username, auth_type, password_enc, token_id, token_secret_enc, verify_tls, created_at, last_sync

**commands 表**：id(PK), name, cmd, category, uses, created_at

**alerts 表**：id(PK), level, source, title, detail, time, resolved, created_at

**settings 表**：key(PK), value

**game_scores 表**：id(PK), game, score, level, difficulty, created_at

**defects 表**：defect_key(PK), title, symptom, preconditions, steps, expected_behavior, actual_behavior, device_info, source, severity, status, priority, affected_features, fix_result, created_at, updated_at

**defect_evidence 表**：evidence_id(PK), defect_key, evidence_type, conclusion, source, conditions, operator, recorded_at

**defect_status_history 表**：history_id(PK), defect_key, from_status, to_status, operator, trigger, evidence_id, recorded_at

**defect_fix_results 表**：defect_key(PK), scope, expected_behavior, failure_behavior, validation_conditions, residual_risks

### 6.4 初始默认数据

由 `DatabaseHelper.seedDefaults()` 在首次启动时播种（已移除 MockData，全量真实数据）：

| 数据 | 数量 | 说明 |
|------|------|------|
| SSH 服务器 | 6 | 涵盖 online/warning/offline 三种状态 |
| 快捷命令 | 12 | 7 个分类 |

---

## 七、UI/UX 设计规范

### 7.1 设计风格

- **风格**：tech-dark（深色终端科技风），支持多主题系统切换
- **多主题系统**：6 套配色（ColorThemeId 枚举：CYAN/OCEAN/SUNSET/AURORA/SAKURA/FOREST），亮/暗模式（跟随系统或手动）
- **主色（终端青绿主题，默认）**：`#00D9A3`
- **强调色**：紫色 `#8B5CF6`（PVE 专属）、信息蓝 `#3B82F6`
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
| 紫色（PVE） | `#8B5CF6` |
| 主文字 | `#E2E8F0` |
| 次文字 | `#94A3B8` |
| 三级文字 | `#8B95A7` |
| 表面背景 | `#131826` |
| 表面背景2 | `#1A2030` |
| 悬浮背景 | `#232A3D` |
| 边框 | `#2A3245` |
| 细边框 | `#1E2535` |

### 7.3 进度条阈值变色

```typescript
function progressColor(value: number): string {
  if (value >= 85) return '#EF4444'; // danger
  if (value >= 65) return '#F59E0B'; // warning
  return '#10B981';                   // success
}
```

### 7.4 状态徽章映射

由 `statusInfo()` 函数处理，覆盖 9 种状态：

| 状态 | 文字 | 颜色 |
|------|------|------|
| online / running / success / active | 在线/运行中/成功/可用 | `#10B981` 绿色 |
| warning / paused | 告警/已暂停 | `#F59E0B` 橙色 |
| offline / stopped / failed | 离线/已停止/失败 | `#8B95A7` / `#EF4444` |

### 7.5 安全区域

| 区域 | 值 | 说明 |
|------|---|------|
| SAFE_TOP | 34vp | 避开状态栏（动态岛/刘海） |
| SAFE_BOTTOM | 12vp | 避开手势操作区域 |

### 7.6 字号系统

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

### 8.1 组件清单（9 个）

| 组件 | 文件 | 说明 |
|------|------|------|
| NavSidebar | [components/NavSidebar.ets](file:///workspace/zhizon/entry/src/main/ets/components/NavSidebar.ets) | 左侧导航栏，支持 `compact` 紧凑模式 |
| TopBar | [components/TopBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/TopBar.ets) | 顶栏，`@StorageLink('isSm')` 响应式 padding |
| StatusBadge | [components/StatusBadge.ets](file:///workspace/zhizon/entry/src/main/ets/components/StatusBadge.ets) | 状态徽章，状态点 + 文字 |
| ProgressBar | [components/ProgressBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/ProgressBar.ets) | 进度条，阈值自动变色 |
| MetricCard | [components/MetricCard.ets](file:///workspace/zhizon/entry/src/main/ets/components/MetricCard.ets) | 指标卡，标题 + 大数字 + 单位 + 副标 |
| EmptyState | [components/EmptyState.ets](file:///workspace/zhizon/entry/src/main/ets/components/EmptyState.ets) | 空状态占位，图标 + 标题 + 描述 |
| DifficultyOption | [components/DifficultyOption.ets](file:///workspace/zhizon/entry/src/main/ets/components/DifficultyOption.ets) | 难度选择项（图标 + 标签 + 描述 + 选中态） |
| FixedBottomNav | [components/FixedBottomNav.ets](file:///workspace/zhizon/entry/src/main/ets/components/FixedBottomNav.ets) | 固定底部导航（手机端 5 Tab + 更多） |
| GlobalBackgroundLayer | [components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets) | 全局背景层（自定义背景图 + 强度调节） |

---

## 九、页面路由与导航

### 9.1 主框架导航（AppShell）

所有页面通过 AppShell 加载：
- 手机端：底部 Tab 切换 `currentPage`
- 平板端：侧边栏点击切换 `currentPage`
- 使用 `@Builder renderPage()` 根据 `currentPage` 渲染对应子页面

### 9.2 子页面跳转

- **进入详情页**：通过 `NavigationFacade` 统一入口（替代直接 `router.pushUrl`），内部进行页面注册表查找 + 导航参数验证后跳转
- **返回**：`router.back()` 或 `router.replaceUrl()`
- **传参方式**：类型化 `RouteParams` 对象（7 种类型），接收方 `router.getParams() as XxxRouteParams`
- **导航结果**：`NavigationSuccess` / `NavigationFailure`，支持页面可用性检查（EMBEDDED 内嵌 / ROUTE 独立路由）

### 9.3 页面跳转关系

```
AppShell (主框架)
├── Index (总览)
│   ├──> Servers ──> ServerDetail ──> Terminal
│   ├──> Servers ──> ServerForm (添加/编辑)
│   ├──> Pve ──> PveNodeDetail ──> VmDetail
│   └──> Alerts
├── Terminal
├── Files
├── Commands
├── Batch
├── Alerts
├── Settings
└── More
    └──> Games ──> Tetris / Game2048 / Snake ──> GameHistory
```

---

## 十、SshService 详细设计

**实现文件**：[service/SshService.ets](file:///workspace/zhizon/entry/src/main/ets/service/SshService.ets)（1138 行）

### 10.1 类结构

| 类 | 行数 | 说明 |
|------|------|------|
| `SshError` | 11-19 | SSH 错误类型，带错误码 `code` |
| `AgentClient` | 69-221 | Agent HTTP 通信客户端 |
| `AgentEngine` | 228-482 | 封装 AgentClient 为 SshEngine |
| `DirectEngine` | 490-799 | 基于 @ohos/libssh 的直连引擎 |
| `SshService` | 808-1138 | 静态方法门面，策略路由 |

### 10.2 错误码常量

| 常量 | 值 | 说明 |
|------|---|------|
| `SSH_ERR_AUTH_FAIL` | 1001 | 认证失败 |
| `SSH_ERR_TIMEOUT` | 1002 | 连接超时 |
| `SSH_ERR_HOST_UNREACH` | 1003 | 主机不可达 |
| `SSH_ERR_KEY_INVALID` | 1004 | 密钥无效 |
| `SSH_ERR_PERMISSION` | 1005 | 权限不足 |
| `SSH_ERR_PROTOCOL` | 1006 | 协议错误 |
| `SSH_ERR_HTTP` | 1007 | HTTP 通信错误 |
| `AGENT_ERR_UNREACH` | 2001 | Agent 不可达 |
| `AGENT_ERR_TOKEN` | 2002 | Agent Token 错误 |

### 10.3 SshService 门面方法

| 方法 | 功能 | 实现方式 |
|------|------|---------|
| `testConnection(server)` | 测试连接 | 调用 testConnectionEx，返回 boolean |
| `testConnectionEx(server)` | 测试连接（含错误信息） | 创建引擎 → connect → 失败清理引擎，返回 `TestResult(ok, message)` |
| `exec(server, cmd)` | 执行命令 | 双模路由 |
| `getMetrics(server)` | 获取指标 | 双模路由（含空值兜底） |
| `listFiles(server, path)` | 列出文件 | 双模路由 |
| `getTerminalOutput(server)` | 获取初始终端输出 | exec 执行 uptime/free -h/df/whoami/hostname |
| `openTerminal(server)` | 开启流式终端 | Agent 模式 WebSocket，直连模式降级 |
| `uploadFile(server, local, remote)` | 上传文件 | 双模路由 |
| `downloadFile(server, remote, local)` | 下载文件 | 双模路由 |
| `disconnect(server)` | 断开连接 | 清理引擎缓存 |
| `hydrateCredentials(server)` | 凭据解密 | 从加密存储解密密码/私钥到内存态，返回 `RemoteResult` |

### 10.4 DirectEngine.waitForCallback

解决原生层 `startSSHClient` 死循环 Promise 永不 resolve 的问题：

```typescript
private static waitForCallback(ssh, host, port, keyPath, ms): Promise<number> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (!settled) { settled = true; reject(new Error('超时')); }
    }, ms);
    ssh.startSSHClient(host, port, keyPath, (event) => {
      if (!settled) { settled = true; clearTimeout(timer); resolve(event); }
    });
  });
}
```

通过 callback 事件判断连接结果，15 秒超时兜底。

### 10.5 AgentClient 端点

| 端点 | 方法 | 功能 | 认证 |
|------|------|------|------|
| `/api/health` | GET | 健康检查 | ❌ |
| `/api/metrics` | GET | 系统指标 | ✅ X-Auth-Token |
| `/api/exec` | POST | 执行命令（30s 超时） | ✅ |
| `/api/files` | GET | 列出目录 | ✅ |
| `/api/files/upload` | POST | 上传文件（100MB 限制） | ✅ |
| `/api/files/upload-base64` | POST | 上传文件（base64 编码，小文件） | ✅ |
| `/api/files/download` | GET | 下载文件 | ✅ |
| `/api/files/mkdir` | POST | 创建目录 | ✅ |
| `/api/files/delete` | POST | 删除文件 | ✅ |
| `/ws/terminal` | WS | WebSocket 终端（60s 心跳） | ✅ |
| `/ws/ssh` | WS | WebSocket SSH 网关（Agent 代理 SSH，用于直连模式降级） | ✅ |

---

## 十一、PVE API 客户端

**实现文件**：[service/PveService.ets](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets)（370 行）

### 11.1 PveClient 核心方法

| 方法 | 功能 |
|------|------|
| `login(username, password)` | 密码认证获取 Ticket + CSRF Token |
| `loginWithToken(tokenId, secret)` | API Token 认证 |
| `getNodes()` | 获取所有节点及其状态 |
| `getVms(node)` | 获取节点下所有 QEMU VM |
| `getCts(node)` | 获取节点下所有 LXC CT |
| `vmAction(node, vmid, action)` | VM 操作（start/shutdown/stop/reboot/suspend/resume） |
| `ctAction(node, vmid, action)` | CT 操作 |
| `createSnapshot(node, vmid, name, desc)` | 创建快照 |
| `getSnapshots(node, vmid)` | 获取快照列表 |
| `deleteSnapshot(node, vmid, snapName)` | 删除快照 |
| `getStorages(node)` | 获取存储池列表 |
| `getTasks(node)` | 获取任务列表 |
| `getVersion()` | 获取集群版本 |

### 11.2 PveService 门面方法

| 方法 | 功能 |
|------|------|
| `getClusters()` | 获取所有集群配置（本地） |
| `syncCluster(cluster)` | 同步单个集群 |
| `getVms(cluster, node?)` | 获取 VM 列表（自动登录） |
| `getStorages(cluster, node)` | 获取存储池 |
| `getTasks(cluster, node)` | 获取任务列表 |
| `vmAction(cluster, node, vmid, type, action)` | VM/CT 操作 |
| `createSnapshot(cluster, node, vmid, name, desc)` | 创建快照 |
| `getSnapshots(cluster, node, vmid)` | 获取快照列表 |

### 11.3 PVE API 关键接口

| 功能 | Method | 路径 |
|------|--------|------|
| 登录获取 Ticket | POST | `/access/ticket` |
| 集群版本 | GET | `/version` |
| 集群节点列表 | GET | `/nodes` |
| 节点状态 | GET | `/nodes/{node}/status` |
| VM 列表 | GET | `/nodes/{node}/qemu` |
| CT 列表 | GET | `/nodes/{node}/lxc` |
| VM 状态 | GET | `/nodes/{node}/qemu/{vmid}/status/current` |
| VM 启动 | POST | `/nodes/{node}/qemu/{vmid}/status/start` |
| VM 关机 | POST | `/nodes/{node}/qemu/{vmid}/status/shutdown` |
| VM 强制停止 | POST | `/nodes/{node}/qemu/{vmid}/status/stop` |
| VM 重启 | POST | `/nodes/{node}/qemu/{vmid}/status/reboot` |
| 存储列表 | GET | `/nodes/{node}/storage` |
| 任务列表 | GET | `/nodes/{node}/tasks` |

---

## 十二、Go Agent 设计

**实现文件**：[agent/main.go](file:///workspace/zhizon/agent/main.go)（1001 行）

### 12.1 架构

Agent 是运行在被管理 Linux 服务器上的轻量级 Go 进程，App 通过 HTTP/WebSocket 与它通信。

**技术栈**：
- 标准库 `net/http`（无第三方框架）
- `gorilla/websocket`（WebSocket 支持）
- `gopsutil/v3`（系统指标采集）

### 12.2 安全特性

- **Token 认证**：所有接口（除 /api/health）需 `X-Auth-Token` 头
- **路径防穿越**：`safePath()` 校验路径在 root 范围内
- **命令超时**：30s context 超时自动 kill
- **上传限制**：100MB MaxBytesReader
- **删除保护**：禁止删除 root 目录
- **日志中间件**：记录请求耗时

### 12.3 端点清单

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/metrics` | GET | 系统指标 |
| `/api/exec` | POST | 执行命令 |
| `/api/files` | GET | 列出目录 |
| `/api/files/upload` | POST | 上传文件 |
| `/api/files/upload-base64` | POST | 上传文件（base64 编码） |
| `/api/files/download` | GET | 下载文件 |
| `/api/files/mkdir` | POST | 创建目录 |
| `/api/files/delete` | POST | 删除文件 |
| `/ws/terminal` | WS | WebSocket 终端 |
| `/ws/ssh` | WS | WebSocket SSH 网关（`wsSSHGateway`，Agent 代理 SSH 连接，用于直连模式降级） |

### 12.4 启动方式

```bash
./zhizon-agent -port 9527 -host 0.0.0.0 -token zhizon-agent -root /
```

---

## 十三、ArkTS 严格模式约束

| 规则 | 说明 | 应对 |
|------|------|------|
| arkts-no-any-unknown | 禁用 `any`/`unknown` | 使用显式类型标注 |
| arkts-no-untyped-obj-literals | 对象字面量需显式类型 | 使用 interface 或 Record |
| arkts-no-structural-typing | 不支持结构类型 | SshError 改为 Error 传入 reject |
| arkts-no-destruct-decls | 禁用解构声明 | 改用独立变量赋值 |
| arkts-no-private-identifiers | 禁用 `#` 私有标识符 | 使用 `private` 关键字 |
| arkts-no-spread | 禁用展开运算符 | 显式构建对象 |

---

## 十四、开发历史

### 14.1 里程碑

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1** | 项目骨架、设计系统、导航、12 页面 UI | ✅ |
| **M2** | 数据持久化（RDB v3）、5 张表、CRUD、默认数据播种 | ✅ |
| **M3** | Go Agent、SshService 双模引擎、凭据加密 AES-256-GCM | ✅ |
| **M4** | PVE API 真实对接（PveClient + PveService） | ✅ |
| **M5** | 全异步改造、响应式布局（3 档断点） | ✅ |
| **M6** | DirectEngine SSH 直连可用、ServerForm 完整表单、Terminal 命令执行 | ✅ |
| **M7** | 监控告警、后台保活 | 🚧 |
| **M8** | 游戏中心 + 多主题系统 + 终端渲染模块 + 缺陷追踪系统 | ✅ |

### 14.2 关键修复记录

| 日期 | 修复内容 |
|------|---------|
| 2026-08-05 | AppShell `@StorageLink` 响应式状态修复（默认 isSm=true 兜底） |
| 2026-08-05 | 3 档断点布局（手机底部Tab / 紧凑侧栏 / 标准侧栏） |
| 2026-08-05 | 安全区域适配（SAFE_TOP=34, SAFE_BOTTOM=12） |
| 2026-08-05 | ArkTS 严格模式合规修复（69 处编译错误） |
| 2026-08-05 | 双模通信改造：SshEngine 接口、AgentEngine + DirectEngine |
| 2026-08-06 | DirectEngine.waitForCallback 修复 libssh 死循环 Promise 问题 |
| 2026-08-06 | CryptoHelper.encrypt 修复 GcmParamsSpec 参数格式（algName/authTag） |
| 2026-08-06 | EntryAbility 延迟初始化修复 "build context for init fail" |
| 2026-08-06 | Servers.ets 自动并发检测所有服务器连接状态 |
| 2026-08-06 | Terminal.ets 完整重写（多会话 + exec 命令 + 自定义选择弹窗） |
| 2026-08-06 | Files.ets 服务器选择器改为自定义弹窗 |
| 2026-08-06 | ServerForm.ets 连接测试改用 testConnectionEx 显示详细错误 |
| 2026-08-07 | 游戏中心（俄罗斯方块 + 2048 + 贪吃蛇 + 5 级难度） |
| 2026-08-07 | 多主题系统（6 配色 + 亮/暗模式 + 自定义背景） |
| 2026-08-07 | 终端渲染模块（AnsiParser + TerminalBuffer + TerminalView） |
| 2026-08-07 | 导航系统重构（NavigationFacade + 类型化路由参数） |
| 2026-08-07 | 缺陷追踪系统（DefectRecord + DefectWorkflow + DefectClassifier） |
| 2026-08-07 | 数据库 v4（game_scores + defects 4 表） |
| 2026-08-07 | 治理模型（GovernanceModels + RemoteResult + PreferenceSnapshot） |
| 2026-08-07 | 单元测试（8 个测试文件） |
| 2026-08-07 | 删除 MockData.ets，全量真实数据 |

---

## 十五、代码统计

### 15.1 文件规模

| 文件 | 行数 | 说明 |
|------|------|------|
| SshService.ets | 1138 | SSH 双模引擎 + 门面 |
| SshService_new.ets | 1053 | SSH 服务重构版（WIP） |
| DatabaseHelper.ets | 875 | RDB v4 数据库 |
| Tetris.ets | 794 | 俄罗斯方块 |
| Theme.ets | 758 | 多主题系统 |
| Files.ets | 683 | SFTP 文件管理 |
| Snake.ets | 636 | 贪吃蛇 |
| VmDetail.ets | 617 | 虚拟机详情 |
| PveNodeDetail.ets | 594 | PVE 节点详情 |
| Game2048.ets | 592 | 2048 |
| Pve.ets | 582 | PVE 集群列表 |
| Terminal.ets | 582 | SSH 终端 |
| Servers.ets | 545 | 服务器列表 |
| ServerForm.ets | 536 | 服务器表单 |
| Settings.ets | 534 | 设置 |
| Index.ets | 498 | 总览仪表盘 |
| DataRepository.ets | 448 | 数据仓库门面 |
| ServerDetail.ets | 420 | 服务器详情 |
| Navigation.ets | 376 | 导航系统 |
| Batch.ets | 375 | 批量操作 |
| PveService.ets | 338 | PVE API 客户端 |
| AnsiParser.ets | 269 | ANSI 解析器 |
| Alerts.ets | 269 | 告警中心 |
| Models.ets | 217 | 数据模型 |
| GameHistory.ets | 213 | 游戏历史 |
| TerminalView.ets | 206 | 终端渲染组件 |
| Difficulty.ets | 201 | 难度定义 |
| AppShell.ets | 194 | 自适应主框架 |
| main.go | 1001 | Go Agent |
| 其他文件 | ~3000 | GovernanceModels + 9 组件 + 7 common + 4 service + terminal + tests |
| **总计** | **~16,864** | |

### 15.2 文件清单

| 类型 | 数量 | 说明 |
|------|------|------|
| 配置文件 | 8 | build-profile / oh-package / module.json5 / ... |
| 资源文件 | 3 | color.json / string.json / main_pages.json |
| ArkTS 代码 | 55 | 1 EntryAbility + 7 common + 2 model + 13 service + 3 terminal + 9 components + 20 pages |
| 测试文件 | 8 | DefectClassifier/DefectWorkflow/GameLaunch/Navigation/RemoteOperation/RemoteResultAdapter/WindowEnvironmentProvider/WindowEnvironmentSnapshot |
| Go Agent | 3 | go.mod / go.sum / main.go |
| 文档 | 2 | README.md + doc/DESIGN.md |
| **合计** | **~69** | |

---

## 十六、附录

### 16.1 参考资源

- Proxmox VE API 文档：https://pve.proxmox.com/wiki/Proxmox_VE_API
- Go gopsutil 文档：https://pkg.go.dev/github.com/shirou/gopsutil/v3
- HarmonyOS 开发文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/
- ArkUI 组件参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/
- ArkTS 严格模式：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-syntax-rules
- @ohos/libssh：HarmonyOS 原生 SSH 库
- CryptoArchitectureKit：HarmonyOS 加密框架

### 16.2 文档版本

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-08-04 | 初始版本，对应 MVP 实现 |
| v1.1.0 | 2026-08-05 | 数据持久化 (RDB)、Go Agent、PVE API 集成、全异步改造 |
| v1.2.0 | 2026-08-05 | 自适应布局（3 档断点）、响应式安全区域、ArkTS 严格模式合规 |
| v2.0.0 | 2026-08-05 | 双模通信改造：SshEngine 接口、AgentEngine + DirectEngine |
| v3.0.0 | 2026-08-06 | SSH 直连可用、凭据加密 AES-256-GCM、ServerForm 完整表单、Terminal 命令执行、自定义选择弹窗、文档全面更新（代码行数/新增模块/修复记录） |
| v4.0.0 | 2026-08-07 | 游戏中心（3 游戏 + 5 级难度）、多主题系统（6 配色 + 亮/暗 + 自定义背景）、终端渲染模块、导航系统重构、缺陷追踪系统、数据库 v4、治理模型、8 个单元测试、MockData 移除 |

---

**智子（Zhizon）** · HarmonyOS NEXT 原生应用 · MIT License

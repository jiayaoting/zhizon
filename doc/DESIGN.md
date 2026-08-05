# 智子（Zhizon）详细设计文档

> **版本**：v1.2.0
> **平台**：HarmonyOS NEXT（鸿蒙 6+ / 纯血鸿蒙）
> **Bundle Name**：`com.zhizon.manager`
> **开发语言**：ArkTS
> **文档状态**：v1.2 实现版（MVP + 响应式 + Agent 通信）

---

## 一、产品概述

### 1.1 产品定位

**智子**是一款运行于鸿蒙 6+ 系统的**一体化服务器管理工具**，面向运维工程师、家庭实验室玩家、中小团队管理员，在手机/平板上同时提供：

- 🔐 **SSH 终端**：远程连接任意 Linux 服务器，执行命令（Agent WebSocket 中继）
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
│   9 Pages + 6 Components + @State 状态管理      │
│   全异步数据加载 (aboutToAppear + await)         │
├─────────────────────────────────────────────────┤
│                  业务逻辑层                      │
│   SshService (AgentClient) │ PveService (PveClient) │
│   DataRepository (CRUD 门面 + 辅助函数)         │
├─────────────────────────────────────────────────┤
│                  数据访问层                      │
│   DatabaseHelper (RDB Store) │ 5 张持久化表     │
│   servers / pve_clusters / commands / alerts / settings │
├─────────────────────────────────────────────────┤
│              远程通信层 (Agent)                  │
│   Go Agent (HTTP + WebSocket)                   │
│   /api/metrics /api/exec /api/files /ws/terminal│
├─────────────────────────────────────────────────┤
│            HarmonyOS 系统能力                    │
│   NetworkKit │ ArkData │ PromptAction           │
└─────────────────────────────────────────────────┘
```

### 2.2 技术选型

| 模块 | 技术方案 | 实现状态 |
|------|---------|---------|
| 开发语言 | ArkTS + Go (Agent) | ✅ |
| UI 框架 | ArkUI 声明式 + Stage 模型 | ✅ |
| 目标 SDK | HarmonyOS 6.0.0 (API 12+) | ✅ |
| 数据存储 | RelationalStore (RDB) + 5 表 | ✅ |
| SSH 终端 | Go Agent WebSocket 中继 | ✅ |
| PVE API | `@kit.NetworkKit` HTTP 调 REST API | ✅ |
| 服务器指标 | Go Agent gopsutil 采集 | ✅ |
| 文件管理 | Go Agent HTTP API | ✅ |
| 命令执行 | Go Agent /api/exec | ✅ |
| 响应式 | @StorageLink 跨组件状态 + display API | ✅ |
| 图表渲染 | 自绘 Canvas | 🚧 规划 |
| 后台保活 | BackgroundTaskKit | 🚧 规划 |
| 加密存储 | @kit.CryptoArchitectureKit + AES-256-GCM | 🚧 规划 |

### 2.3 PVE API 对接说明

PVE 提供 RESTful API，基础信息：

- **API 地址**：`https://<pve-host>:8006/api2/json/`
- **认证方式**：Ticket（用户名 + 密码换取）或 API Token
- **API 版本**：v2（兼容 PVE 7.x / 8.x）
- **数据格式**：JSON

**关键接口清单**（已封装于 [PveService.ets](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets) 中的 `PveClient` 类）：

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
| VM 快照 (GET) | GET | `/nodes/{node}/qemu/{vmid}/snapshot` |
| VM 快照 (POST) | POST | `/nodes/{node}/qemu/{vmid}/snapshot` |
| VM 快照 (DELETE) | DELETE | `/nodes/{node}/qemu/{vmid}/snapshot/{snapName}` |
| CT 启动/关机/重启 | POST | `/nodes/{node}/lxc/{vmid}/status/{action}` |
| 存储列表 | GET | `/nodes/{node}/storage` |
| 任务列表 | GET | `/nodes/{node}/tasks` |

**PveClient 核心方法**：

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

**PveService 门面方法**：

| 方法 | 功能 |
|------|------|
| `getClusters()` | 获取所有集群配置（本地） |
| `syncCluster(cluster)` | 同步单个集群（登录+拉节点+VM/CT 数量） |
| `getVms(cluster, node?)` | 获取 VM 列表（自动登录） |
| `getStorages(cluster, node)` | 获取存储池 |
| `getTasks(cluster, node)` | 获取任务列表 |
| `vmAction(cluster, node, vmid, type, action)` | VM/CT 操作 |
| `createSnapshot(cluster, node, vmid, name, desc)` | 创建快照 |
| `getSnapshots(cluster, node, vmid)` | 获取快照列表 |

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
│   └── main.go                            # 694 行，含 HTTP + WebSocket
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
        │       └── profile/main_pages.json  # 12 页面路由
        │
        └── ets/
            ├── entryability/
            │   └── EntryAbility.ets       # 应用入口（RDB 初始化 + 沉浸式状态栏）
            │
            ├── common/                    # 🎨 主题与常量
            │   ├── Theme.ets              # AppTheme + progressColor() + statusInfo()
            │   └── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
            │
            ├── model/                     # 📦 数据模型
            │   └── Models.ets             # 13 个 interface + 1 个 type
            │
            ├── service/                   # 🔧 业务服务层
            │   ├── DatabaseHelper.ets    # RDB Store 5 表 CRUD + 默认数据播种
            │   ├── DataRepository.ets    # 数据门面 + 格式化工具 + PVE 代理方法
            │   ├── PveService.ets         # PveClient + PveService 门面
            │   ├── SshService.ets         # AgentClient + SshService 门面
            │   └── MockData.ets           # 全量 Mock 数据
            │
            ├── components/                # 🧩 通用组件 (6 个)
            │   ├── NavSidebar.ets         # 左侧导航栏（支持 compact 模式）
            │   ├── TopBar.ets             # 顶栏（响应式 padding）
            │   ├── StatusBadge.ets        # 状态徽章
            │   ├── ProgressBar.ets        # 进度条（阈值变色）
            │   ├── MetricCard.ets         # 指标卡
            │   └── EmptyState.ets         # 空状态占位
            │
            └── pages/                     # 📱 9 个主页面 + 3 个详情页
                ├── AppShell.ets           # 自适应主框架（底部Tab / 侧边栏切换）
                ├── Index.ets              # 总览仪表盘
                ├── Servers.ets            # SSH 服务器列表
                ├── ServerDetail.ets       # 服务器监控详情
                ├── Terminal.ets           # SSH 终端（多会话 + 快捷命令）
                ├── Files.ets              # SFTP 文件管理
                ├── Pve.ets                # PVE 集群列表 + 添加对话框
                ├── PveNodeDetail.ets      # PVE 节点详情（VM/存储/任务/系统 4 Tab）
                ├── VmDetail.ets           # 虚拟机详情（概览/快照/硬件/历史 4 Tab）
                ├── Commands.ets           # 快捷命令库
                ├── Batch.ets              # 批量操作
                ├── Alerts.ets             # 告警中心
                └── Settings.ets           # 设置
```

---

## 四、功能模块设计

### 4.1 功能全景图

```
智子 (Zhizon)
├── 1. SSH 服务器管理
│   ├── 服务器列表（分组筛选 + 状态 + 资源指标）
│   ├── 服务器监控详情（4 指标 + 趋势 + Top 进程 + 相关告警）
│   ├── 添加服务器（密码/密钥认证）
│   └── 分组与标签
│
├── 2. SSH 终端
│   ├── 多标签会话 Tab
│   ├── 终端仿真（黑底青绿 + 错误红 + 提示符绿）
│   ├── 快捷命令横滑栏
│   ├── 命令输入与发送
│   └── 底部 padding 防 Tab 遮挡
│
├── 3. PVE 集群管理
│   ├── PVE 集群列表（同步状态 + 节点 VM/CT 计数）
│   ├── 添加集群对话框（表单 + Scroll + 移动端适配）
│   ├── PVE 节点详情（4 Tab）
│   │   ├── 虚拟机列表（搜索 + 过滤 + 操作）
│   │   ├── 存储池（类型 + 容量进度条）
│   │   ├── 任务中心（状态 + 进度条）
│   │   └── 系统信息
│   └── 虚拟机详情（4 Tab）
│       ├── 概览（系统信息 + 操作）
│       ├── 快照（创建/删除）
│       ├── 硬件配置
│       └── 历史任务
│
├── 4. SFTP 文件管理
│   ├── 双栏布局（本地/远程）
│   ├── 面包屑导航
│   ├── 文件列表
│   └── 传输队列
│
├── 5. 资源监控
│   ├── MetricCard 数字卡
│   ├── ProgressBar 进度条（阈值变色）
│   └── 状态徽章
│
├── 6. 快捷命令库
│   ├── 分类（全部/系统/进程/网络/Docker/安全/服务）
│   ├── 命令卡片网格
│   ├── 复制到剪贴板
│   └── 使用次数统计
│
├── 7. 批量操作
│   ├── 多服务器勾选
│   ├── 命令输入区
│   ├── 常用模板
│   └── 并行执行结果
│
├── 8. 告警中心
│   ├── 三色统计
│   ├── 过滤标签
│   ├── 告警卡片
│   └── 标记已处理
│
└── 9. 系统设置
    ├── 常规（端口/超时/重连）
    ├── 外观（主题/字号/字体）
    ├── 终端（字体/光标/滚屏/256色）
    ├── 安全（生物识别/指纹校验）
    ├── 通知（推送/勿扰/阈值）
    ├── 数据（导出/导入/备份）
    └── 关于（版本/更新/协议）
```

### 4.2 各模块详细设计

---

#### 模块 1：SSH 服务器管理

**实现位置**：[pages/Servers.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Servers.ets)、[pages/ServerDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/ServerDetail.ets)

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 服务器列表展示 | ✅ 卡片式，含状态点 + StatusBadge + CPU/内存/磁盘进度条 |
| 分组筛选 | ✅ 6 分组（全部/生产/测试/监控/备份/CI/CD） |
| 添加服务器 | 🚧 UI 占位（点击 toast） |
| 服务器详情 | ✅ 头部卡 + 4 指标 + 趋势占位 + Top 进程 + 相关告警 |
| 连接终端 | ✅ 跳转 Terminal 页面 |
| 快速操作 | ✅ 连接/终端/详情三按钮 |

---

#### 模块 2：SSH 终端

**实现位置**：[pages/Terminal.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Terminal.ets)

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 多会话 Tab | ✅ 顶部 Tab 切换多个服务器会话 |
| 终端仿真 | ✅ 黑底 (#000) + 青绿 (#00D9A3) + 提示符绿 (#00FF88) + 错误红 (#EF4444) |
| 命令输入 | ✅ TextInput + 发送按钮 |
| 快捷命令栏 | ✅ 横滑滚动，8 条预置命令 |
| 底部安全区 | ✅ padding(68vp) 防止被 Tab 遮挡 |
| 错误高亮 | ✅ `isErrorLine()` 检测错误/失败关键字变红 |

---

#### 模块 3：PVE 集群管理（核心差异化）

**实现位置**：[pages/Pve.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Pve.ets)、[pages/PveNodeDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/PveNodeDetail.ets)、[pages/VmDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/VmDetail.ets)

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

**实现位置**：[pages/Files.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Files.ets)

| 功能 | 实现状态 |
|------|---------|
| 双栏布局 | ✅ 本地 + 远程 |
| 面包屑导航 | ✅ / > root > logs |
| 文件项展示 | ✅ emoji + 名称 + 修改时间 + 大小 + 权限 |
| 传输队列 | ✅ 2 条 mock 记录 + 进度条 |
| 上传下载 | 🚧 UI 占位 |

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
│    │  │                  │  │
│ 160│  └──────────────────┘  │
│ 或 │                          │
│ 220│  SAFE_BOTTOM = 12vp     │
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

private applyWidth(w: number) {
  this.isSm = w < 600;
  this.isMd = w >= 600 && w < 840;
  this.isLg = w >= 840;
}
```

**关键设计**：
- `@StorageLink` 跨组件共享状态，AppShell 一处赋值，所有页面响应
- 默认 `isSm = true`，防止 `display` API 失败时手机错误渲染侧边栏
- `onAreaChange` 运行时检测宽度变化（窗口旋转/折叠屏展开）
- 页面内部使用 `this.isSm ? 16 : 24` 条件 padding 适配

### 5.5 各页面响应式适配

| 页面 | 手机端适配 |
|------|-----------|
| Index | 统计卡 2×2 网格，平板 1×4 横排 |
| Servers | 分组标签横滑，padding 16vp |
| Terminal | 底部 padding 68vp 防 Tab 遮挡，快捷命令横滑 |
| Pve | 添加对话框 maxHeight 85%，宽度 88% |
| PveNodeDetail | 标签横滑，padding 16vp |
| Commands | 分类横滑胶囊栏 |
| Batch | 紧凑 padding，文字截断 |
| 所有页面 | padding: `isSm ? 16 : 24` |

---

## 六、数据模型设计

### 6.1 核心实体

详见 [model/Models.ets](file:///workspace/zhizon/entry/src/main/ets/model/Models.ets)，共 13 个 interface + 1 个 type：

| 实体 | 说明 | 关键字段 |
|------|------|---------|
| `Server` | SSH 服务器 | id, host, port, username, authType, group, tags, os, status, metrics |
| `ServerMetrics` | 服务器指标 | cpu, mem, disk, netIn, netOut, load, uptime |
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
| `Stats` | 统计聚合 | total, online, warning, offline, alerts, pveNodes, vmTotal, vmRunning... |
| `TerminalSession` | 终端会话 | id, serverName, cwd, history[] |

### 6.2 数据存储方案

| 数据类型 | 存储方式 | 状态 |
|---------|---------|------|
| SSH 服务器配置 | RDB `servers` 表 | ✅ |
| PVE 集群配置 | RDB `pve_clusters` 表 | ✅ |
| 快捷命令 | RDB `commands` 表 | ✅ |
| 告警记录 | RDB `alerts` 表 | ✅ |
| 应用设置 | RDB `settings` 表 | ✅ |
| 服务器实时指标 | Go Agent `/api/metrics` 实时获取 | ✅ |
| PVE 节点/VM 数据 | PVE REST API 实时获取 | ✅ |
| 文件列表 | Go Agent `/api/files` 实时获取 | ✅ |

### 6.3 数据库表结构

**servers 表**：id(PK), name, host, port, username, auth_type, password_enc, key_id, grp, tags, os, created_at, last_connected

**pve_clusters 表**：id(PK), name, host, port, username, auth_type, password_enc, token_id, token_secret_enc, verify_tls, created_at, last_sync

**commands 表**：id(PK), name, cmd, category, uses, created_at

**alerts 表**：id(PK), level, source, title, detail, time, resolved, created_at

**settings 表**：key(PK), value

### 6.4 初始默认数据

由 `DatabaseHelper.seedDefaults()` 在首次启动时播种：

| 数据 | 数量 | 说明 |
|------|------|------|
| SSH 服务器 | 6 | 涵盖 online/warning/offline 三种状态 |
| 快捷命令 | 12 | 7 个分类 |

---

## 七、UI/UX 设计规范

### 7.1 设计风格

- **风格**：tech-dark（深色终端科技风）
- **主色**：终端青绿 `#00D9A3`
- **强调色**：紫色 `#8B5CF6`（PVE 专属）、信息蓝 `#3B82F6`
- **字体**：系统字体 + JetBrains Mono（代码/数字）

### 7.2 颜色规范

详见 [common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets)

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

### 8.1 组件清单（6 个）

| 组件 | 文件 | 说明 |
|------|------|------|
| NavSidebar | [components/NavSidebar.ets](file:///workspace/zhizon/entry/src/main/ets/components/NavSidebar.ets) | 左侧导航栏，支持 `compact` 紧凑模式 |
| TopBar | [components/TopBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/TopBar.ets) | 顶栏，`@StorageLink('isSm')` 响应式 padding |
| StatusBadge | [components/StatusBadge.ets](file:///workspace/zhizon/entry/src/main/ets/components/StatusBadge.ets) | 状态徽章，状态点 + 文字 |
| ProgressBar | [components/ProgressBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/ProgressBar.ets) | 进度条，阈值自动变色 |
| MetricCard | [components/MetricCard.ets](file:///workspace/zhizon/entry/src/main/ets/components/MetricCard.ets) | 指标卡，标题 + 大数字 + 单位 + 副标 |
| EmptyState | [components/EmptyState.ets](file:///workspace/zhizon/entry/src/main/ets/components/EmptyState.ets) | 空状态占位，图标 + 标题 + 描述 |

### 8.2 NavSidebar 双模式

```typescript
// 紧凑模式（compact=true）
Column({ space: 4 }) {
  Text(item.icon).fontSize(20)     // 仅图标
  Column().width(16).height(3)    // 选中指示条
}

// 标准模式（compact=false）
Row({ space: 10 }) {
  Text(item.icon).fontSize(18)
  Text(item.label).fontSize(13)   // 图标 + 文字
  Divider().height(16)            // 选中装饰条
}
```

### 8.3 StatusBadge 尺寸

```typescript
// 尺寸由 badgeSize 属性控制
small:  圆点 5vp, 文字 10px, padding 6/2
normal: 圆点 6vp, 文字 11px, padding 8/2
```

---

## 九、页面路由与导航

### 9.1 主框架导航（AppShell）

**所有页面通过 AppShell 加载**，不再使用 NavSidebar 独立布局。

- 手机端：底部 Tab 切换 `currentPage`
- 平板端：侧边栏点击切换 `currentPage`
- 使用 `@Builder renderPage()` 根据 `currentPage` 渲染对应子页面

### 9.2 子页面跳转

- **进入详情页**：`router.pushUrl({ url: 'pages/XxxDetail', params: { id: xxx } })`
- **返回**：`router.back()` 或 `router.replaceUrl()`
- **传参方式**：`params` 对象，接收方 `router.getParams() as SomeParams`

### 9.3 页面跳转关系

```
AppShell (主框架)
├── Index (总览)
│   ├──> Servers ──> ServerDetail ──> Terminal
│   ├──> Pve ──> PveNodeDetail ─┬─> VmDetail
│   ├──> Alerts
│   └──> (其他工具页)
├── Terminal
├── Files
├── Commands
├── Batch
├── Alerts
└── Settings
```

---

## 十、Go Agent 设计

### 10.1 架构

Agent 是运行在被管理 Linux 服务器上的轻量级 Go 进程，App 通过 HTTP/WebSocket 与它通信。

**技术栈**：
- 标准库 `net/http`（无第三方框架）
- `gorilla/websocket`（WebSocket 支持）
- `gopsutil/v3`（系统指标采集：CPU/内存/磁盘/网络/负载/运行时长）

### 10.2 Agent 端点（默认端口 9527）

| 端点 | 方法 | 功能 | 认证 |
|------|------|------|------|
| `/api/health` | GET | 健康检查 | ❌ 免认证 |
| `/api/metrics` | GET | CPU/内存/磁盘/网络/负载/运行时长 | ✅ X-Auth-Token |
| `/api/exec` | POST | 执行 Shell 命令（30s 超时） | ✅ X-Auth-Token |
| `/api/files` | GET | 列出目录文件 | ✅ X-Auth-Token |
| `/api/files/upload` | POST | 上传文件（最大 100MB） | ✅ X-Auth-Token |
| `/api/files/download` | GET | 下载文件 | ✅ X-Auth-Token |
| `/api/files/mkdir` | POST | 创建目录 | ✅ X-Auth-Token |
| `/api/files/delete` | POST | 删除文件/目录 | ✅ X-Auth-Token |
| `/ws/terminal` | WS | WebSocket 终端中继（60s 心跳） | ✅ X-Auth-Token |

### 10.3 安全特性

- **Token 认证**：所有接口（除 /api/health）需 `X-Auth-Token` 头
- **路径防穿越**：`safePath()` 校验路径在 root 范围内
- **命令超时**：30s context 超时自动 kill
- **上传限制**：100MB MaxBytesReader
- **删除保护**：禁止删除 root 目录
- **CORS 支持**：开发环境允许所有来源
- **日志中间件**：记录请求耗时

### 10.4 启动方式

```bash
./zhizon-agent -port 9527 -host 0.0.0.0 -token zhizon-agent -root /
```

### 10.5 代码规模

- **main.go**：694 行
- 包含：CPU 后台采样、健康检查、指标采集、命令执行、文件管理、WebSocket 终端、优雅关闭

---

## 十一、SshService 设计

### 11.1 AgentClient

封装与 Go Agent 的 HTTP 通信：

| 方法 | 功能 |
|------|------|
| `healthCheck()` | GET `/api/health` |
| `getMetrics()` | GET `/api/metrics` → `ServerMetrics` |
| `exec(cmd)` | POST `/api/exec` → 命令输出字符串 |
| `listFiles(dirPath)` | GET `/api/files` → `FileItem[]` |
| `mkdir(dirPath)` | POST `/api/files/mkdir` |
| `deleteFile(filePath)` | POST `/api/files/delete` |

### 11.2 SshService 门面

| 方法 | 功能 |
|------|------|
| `testConnection(server)` | 健康检查 |
| `exec(server, cmd)` | 执行命令 |
| `getMetrics(server)` | 获取指标（含空值兜底） |
| `listFiles(server, dirPath)` | 列出文件 |
| `getTerminalOutput(server)` | 获取初始终端输出（uptime + free -h + df） |

---

## 十二、关键技术方案

### 12.1 PVE API 客户端

[PveClient](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets) 完整实现：

- **认证**：支持 Ticket（密码）和 API Token 两种方式
- **请求封装**：统一 `request()` 方法处理 Cookie/CSRF/Token 头
- **错误处理**：try-catch + null 返回，上层安全降级
- **类型安全**：ArkTS 要求对象字面量对应显式类，使用 `Record<string, Object>` 传递

### 12.2 终端显示

Terminal 页面采用分层颜色方案：

```typescript
// 终端行颜色
isErrorLine(line) → '#EF4444'   // 错误行红色
isPromptLine(line) → '#00FF88'  // 提示符浅绿色
default → '#00D9A3'              // 正常输出青绿色
```

### 12.3 构建配置

项目使用 ArkTS 严格模式，主要约束：

| 规则 | 说明 | 应对 |
|------|------|------|
| arkts-no-standalone-this | 独立函数禁用 `this` | 使用静态类名访问 |
| arkts-no-destruct-decls | 禁用解构声明 | 改用独立 `await` |
| arkts-no-untyped-obj-literals | 对象字面量需显式类型 | 使用 Record 或 Map |
| arkts-no-as-const | 禁用 `as const` | 直接赋字面量 |
| arkts-no-any-unknown | 禁用 `any`/`unknown` | 使用显式类型 |
| arkts-no-spread | 禁用展开运算符 | 显式构建对象 |

---

## 十三、开发计划

### 13.1 里程碑

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1** | 项目骨架、设计系统、导航、12 页面 UI | ✅ 完成 |
| **M2** | 数据持久化（RDB）、5 张表、CRUD、默认数据播种 | ✅ 完成 |
| **M3** | Go Agent（HTTP + WebSocket + gopsutil）、SshService 对接 | ✅ 完成 |
| **M4** | PVE API 真实对接（PveClient + PveService）、VM/CT/存储/快照/任务 | ✅ 完成 |
| **M5** | 全异步改造、Loading 状态、响应式布局（3 档断点） | ✅ 完成 |
| **M6** | 监控告警、加密存储、后台保活 | 🚧 规划 |
| **M7** | VM 控制台、SFTP 增强、批量操作增强 | 🚧 规划 |
| **M8** | 性能优化、安全加固、上架准备 | 🚧 规划 |

### 13.2 已完成关键修复

| 日期 | 修复内容 |
|------|---------|
| 2026-08-05 | AppShell `@StorageLink` 响应式状态修复（默认 isSm=true 兜底） |
| 2026-08-05 | 3 档断点布局（手机底部Tab / 紧凑侧栏 / 标准侧栏） |
| 2026-08-05 | 安全区域适配（SAFE_TOP=34, SAFE_BOTTOM=12） |
| 2026-08-05 | Terminal 底部 padding 68vp 防 Tab 遮挡 |
| 2026-08-05 | PVE 添加对话框 Scroll 化 + maxHeight 85% |
| 2026-08-05 | 终端错误行红色高亮（isErrorLine） |
| 2026-08-05 | textTertiary 提亮（#64748B → #8B95A7）改善对比度 |
| 2026-08-05 | ArkTS 严格模式合规修复（69 处编译错误） |

---

## 十四、文件清单与代码统计

### 14.1 文件清单

| 类型 | 数量 | 说明 |
|------|------|------|
| 配置文件 | 8 | build-profile / oh-package / module.json5 / ... |
| 资源文件 | 3 | color.json / string.json / main_pages.json |
| Go Agent | 3 | go.mod / go.sum / main.go |
| ArkTS 代码 | 23 | EntryAbility + 2 common + 5 service + 1 model + 6 components + 9 pages + 1 AppShell |
| 文档 | 2 | README.md + doc/DESIGN.md |
| **合计** | **39** | |

### 14.2 代码规模（约）

| 文件 | 行数 |
|------|------|
| main.go (Agent) | 694 |
| Models.ets | 176 |
| DatabaseHelper.ets | 469 |
| PveService.ets | 425 |
| SshService.ets | 165 |
| AppShell.ets | 226 |
| NavSidebar.ets | 128 |
| Terminal.ets | ~350 |
| Index.ets | 438 |
| Servers.ets | 272 |
| 其他页面/组件 | ~2000 |
| **总计** | **~5,000** |

---

## 十五、附录

### 15.1 参考资源

- Proxmox VE API 文档：https://pve.proxmox.com/wiki/Proxmox_VE_API
- Go gopsutil 文档：https://pkg.go.dev/github.com/shirou/gopsutil/v3
- HarmonyOS 开发文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/
- ArkUI 组件参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/
- ArkTS 严格模式：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-syntax-rules

### 15.2 文档版本

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-08-04 | 初始版本，对应 MVP 实现 |
| v1.1.0 | 2026-08-05 | 数据持久化 (RDB)、Go Agent、PVE API 集成、全异步改造 |
| v1.2.0 | 2026-08-05 | 自适应布局（3 档断点）、响应式安全区域、ArkTS 严格模式合规、终端错误高亮、颜色对比度优化、文档全面更新 |

---

**智子（Zhizon）** · HarmonyOS NEXT 原生应用 · MIT License

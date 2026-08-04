# 智子（Zhizon）详细设计文档

> **版本**：v1.0.0
> **平台**：HarmonyOS NEXT（鸿蒙 6+ / 纯血鸿蒙）
> **Bundle Name**：`com.zhizon.manager`
> **开发语言**：ArkTS
> **文档状态**：v1.0 实现版（MVP）

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

---

## 二、技术架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────┐
│                  ArkUI 表现层                    │
│   12 Pages + 5 Components + @State 状态管理      │
├─────────────────────────────────────────────────┤
│                  业务逻辑层                      │
│   SshService │ PveService │ DataRepository       │
├─────────────────────────────────────────────────┤
│                  数据访问层                      │
│   MockData │ Preferences │ RelationalStore (规划)│
├─────────────────────────────────────────────────┤
│                  原生能力层 (NAPI)               │
│   libssh2 (规划) │ libssh │ OpenSSL              │
├─────────────────────────────────────────────────┤
│            HarmonyOS 系统能力                    │
│   NetworkKit │ NotificationKit │ BackgroundTask  │
└─────────────────────────────────────────────────┘
```

### 2.2 技术选型

| 模块 | 技术方案 | 实现状态 |
|------|---------|---------|
| 开发语言 | ArkTS | ✅ |
| UI 框架 | ArkUI 声明式 + Stage 模型 | ✅ |
| 目标 SDK | HarmonyOS 6.0.0 (API 12+) | ✅ |
| 数据存储 | Preferences + RelationalStore | 🚧 规划 |
| SSH 协议 | NAPI 封装 libssh2 | 🚧 规划（已写接口骨架） |
| PVE API | `@ohos.net.http` 调 REST API | 🚧 规划（已写 PveClient） |
| 图表渲染 | 自绘 Canvas | 🚧 规划 |
| 终端仿真 | Xterm.js 移植 / 自研 | 🚧 规划 |
| 后台保活 | BackgroundTaskKit | 🚧 规划 |
| 加密存储 | @ohos.security.cryptoHash + AES-256-GCM | 🚧 规划 |

### 2.3 PVE API 对接说明

PVE 提供 RESTful API，基础信息：

- **API 地址**：`https://<pve-host>:8006/api2/json/`
- **认证方式**：Ticket（用户名 + 密码换取）或 API Token
- **API 版本**：v2（兼容 PVE 7.x / 8.x）
- **数据格式**：JSON

**关键接口清单**（已封装于 [PveService.ets](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets)）：

| 功能 | Method | 路径 |
|------|--------|------|
| 登录获取 Ticket | POST | `/access/ticket` |
| 集群节点列表 | GET | `/nodes` |
| 节点状态 | GET | `/nodes/{node}/status` |
| 节点 RRD 数据 | GET | `/nodes/{node}/rrd` |
| VM 列表 | GET | `/nodes/{node}/qemu` |
| CT 列表 | GET | `/nodes/{node}/lxc` |
| VM 状态 | GET | `/nodes/{node}/qemu/{vmid}/status/current` |
| VM 启动 | POST | `/nodes/{node}/qemu/{vmid}/status/start` |
| VM 关机 | POST | `/nodes/{node}/qemu/{vmid}/status/shutdown` |
| VM 强制停止 | POST | `/nodes/{node}/qemu/{vmid}/status/stop` |
| VM 重启 | POST | `/nodes/{node}/qemu/{vmid}/status/reboot` |
| VM 快照 | GET/POST | `/nodes/{node}/qemu/{vmid}/snapshot` |
| VM 控制台 | GET | `/nodes/{node}/qemu/{vmid}/vncproxy` |
| 存储列表 | GET | `/nodes/{node}/storage` |
| 网络配置 | GET | `/nodes/{node}/network` |
| 任务日志 | GET | `/nodes/{node}/tasks` |
| 集群状态 | GET | `/cluster/resources` |

---

## 三、目录结构

```
zhizon/
├── .gitignore
├── README.md
├── build-profile.json5                    # 根构建配置
├── hvigorfile.ts
├── oh-package.json5
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
            │   └── EntryAbility.ets       # 应用入口（沉浸式状态栏）
            │
            ├── common/                    # 🎨 主题与常量
            │   ├── Theme.ets              # AppTheme + progressColor/statusInfo
            │   └── Constants.ets          # 导航项/尺寸常量
            │
            ├── model/                     # 📦 数据模型
            │   └── Models.ets             # Server/PveCluster/Vm/Storage/Alert/...
            │
            ├── service/                   # 🔧 业务服务层
            │   ├── MockData.ets           # Mock 全量数据
            │   ├── DataRepository.ets     # 数据门面 + formatUptime/formatSize
            │   ├── SshService.ets         # SSH 服务（含真实 API 注释）
            │   └── PveService.ets         # PVE REST API 客户端
            │
            ├── components/                # 🧩 通用组件
            │   ├── NavSidebar.ets         # 左侧导航栏
            │   ├── TopBar.ets             # 顶栏
            │   ├── StatusBadge.ets        # 状态徽章
            │   ├── ProgressBar.ets        # 进度条
            │   └── MetricCard.ets         # 指标卡
            │
            └── pages/                     # 📱 12 个页面
                ├── Index.ets              # 总览仪表盘
                ├── Servers.ets            # SSH 服务器列表
                ├── ServerDetail.ets       # 服务器监控详情
                ├── Terminal.ets           # SSH 终端
                ├── Files.ets              # SFTP 文件管理
                ├── Pve.ets                # PVE 集群列表
                ├── PveNodeDetail.ets      # PVE 节点详情
                ├── VmDetail.ets           # 虚拟机详情
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
│   ├── 服务器列表（分组筛选）
│   ├── 服务器监控详情
│   ├── 添加服务器（密码/密钥认证）
│   ├── 分组与标签
│   └── 快速连接
│
├── 2. SSH 终端
│   ├── 多会话左侧栏
│   ├── 多标签终端
│   ├── 终端仿真（黑底青绿）
│   ├── 快捷命令栏
│   └── 命令输入与发送
│
├── 3. PVE 集群管理
│   ├── PVE 集群列表
│   ├── PVE 节点详情（4 Tab）
│   │   ├── 虚拟机列表（VM/CT）
│   │   ├── 存储池
│   │   ├── 任务中心
│   │   └── 系统信息
│   └── 虚拟机详情（4 Tab）
│       ├── 概览（系统信息+操作记录）
│       ├── 快照（创建/回滚/删除）
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
│   ├── 服务器指标卡（CPU/内存/磁盘/网络）
│   ├── VM 实时指标
│   ├── PVE 节点指标
│   └── 进程列表（Top 进程）
│
├── 6. 快捷命令库
│   ├── 分类侧栏（7 分类）
│   ├── 命令卡片网格
│   ├── 复制到剪贴板
│   └── 运行命令
│
├── 7. 批量操作
│   ├── 多服务器勾选
│   ├── 命令输入区
│   ├── 常用模板
│   └── 并行执行结果
│
├── 8. 告警中心
│   ├── 三色统计（严重/警告/信息）
│   ├── 过滤标签
│   ├── 告警卡片
│   └── 标记已处理
│
└── 9. 系统设置
    ├── 常规（端口/超时/重连）
    ├── 外观（主题/字号/字体）
    ├── 终端（字体/光标/滚屏）
    ├── 安全（主密码/生物识别/指纹校验）
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
| 服务器列表展示 | ✅ 卡片式，含状态点+StatusBadge+资源进度条 |
| 分组筛选 | ✅ 6 分组（全部/生产/测试/监控/备份/CI/CD） |
| 添加服务器 | 🚧 UI 占位（点击 toast） |
| 服务器详情 | ✅ 头部卡 + 4 指标 + 趋势占位 + Top 进程 + 相关告警 |
| 连接终端 | ✅ 跳转 Terminal 页面 |
| 分组与标签 | ✅ OS 标签 + 分组标签 + tags 数组 |

**数据模型**：

```typescript
interface Server {
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  authType: 'password' | 'key';
  group?: string;
  tags: string[];
  os?: string;
  status: 'online' | 'warning' | 'offline';
  metrics: {
    cpu: number; mem: number; disk: number;
    netIn: number; netOut: number;
    load: number; uptime: number;
  };
  lastConnected?: number;
  createdAt: number;
}
```

---

#### 模块 2：SSH 终端

**实现位置**：[pages/Terminal.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Terminal.ets)

**功能列表**：

| 功能 | 实现状态 |
|------|---------|
| 多会话左侧栏 | ✅ 3 会话（prod-web-01/prod-db-master/dev-test-01），含 cwd 路径 |
| 多标签 Tab | ✅ 顶部 Tab 切换 |
| 终端仿真 | 🚧 Mock 文本展示（黑底 #000 + 青绿 #00D9A3 + 提示符浅绿 #00FF88） |
| 命令输入 | ✅ TextInput + 发送按钮 |
| 快捷命令栏 | ✅ 8 条（ls -la/cd /top/df -h/free -h/docker ps/uptime/cat /etc/os-release） |
| 会话保活 | 🚧 规划（BackgroundTaskKit） |

**说明**：真实终端仿真需后续用 NAPI + Xterm.js 移植或自研字符网格组件实现。

---

#### 模块 3：PVE 集群管理（核心差异化）

**实现位置**：[pages/Pve.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Pve.ets)、[pages/PveNodeDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/PveNodeDetail.ets)、[pages/VmDetail.ets](file:///workspace/zhizon/entry/src/main/ets/pages/VmDetail.ets)

**3.1 PVE 集群列表**

| 功能 | 实现状态 |
|------|---------|
| 集群卡片 | ✅ 集群名+健康徽章+host:port+版本+最后同步 |
| 节点卡片 | ✅ 紫色装饰条+CPU/内存/磁盘进度条+VM/CT 数量 |
| 节点详情跳转 | ✅ 传参 clusterId+node |
| 添加 PVE 节点 | 🚧 UI 占位 |

**3.2 PVE 节点详情（4 Tab）**

| Tab | 功能 |
|-----|------|
| **虚拟机** | 搜索框 + 5 过滤标签（全部/运行中/已停止/QEMU/LXC）+ VM 列表（VMID/类型图标/状态/资源/操作按钮） |
| **存储池** | 类型徽章（dir灰/lvmthin蓝/zfs紫/nfs橙）+ 容量进度条 |
| **任务中心** | 类型+目标+状态徽章+进度条（running 脉冲）+错误提示 |
| **系统信息** | 内核/PVE 版本/CPU 型号/总内存/总磁盘/网络接口/运行时长 |

**3.3 虚拟机详情**

| 区域 | 功能 |
|------|------|
| 头部卡 | 64×64 类型图标（Q紫/L青绿）+ 名称 + 状态 + 元信息 |
| 操作按钮组 | running→停止/重启/暂停/控制台；stopped→启动/克隆/删除；paused→恢复/停止 |
| 4 指标卡 | CPU/内存/磁盘IO/网络 |
| Tab 概览 | 系统信息 + 标签 + 最近操作 |
| Tab 快照 | 创建快照 + 回滚/删除 |
| Tab 硬件 | 6 分组（处理器/内存/存储/网络/显示/其他） |
| Tab 历史 | 按 node+vmid 过滤任务 |

---

#### 模块 4：SFTP 文件管理

**实现位置**：[pages/Files.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Files.ets)

| 功能 | 实现状态 |
|------|---------|
| 双栏布局 | ✅ 本地（5 占位目录）+ 远程（DataRepository.getFiles） |
| 面包屑导航 | ✅ / > root > logs |
| 文件项展示 | ✅ 📁/📄 emoji + 名称 + 修改时间 + 大小 + 权限 |
| 传输队列 | ✅ 2 条 mock 传输记录 + 进度条 |
| 上传下载 | 🚧 UI 占位 |

---

#### 模块 5：资源监控

**实现位置**：贯穿 Index/ServerDetail/PveNodeDetail/VmDetail

**指标维度**：

| 对象 | 指标 |
|------|------|
| SSH 服务器 | CPU/内存/磁盘/网络/负载/进程数 |
| PVE 节点 | CPU(核数)/内存(已用/总量)/磁盘(已用/总量)/网络 |
| VM/CT | CPU/内存/磁盘IO(读/写)/网络(入/出)/运行时长 |

**图表类型**：
- ✅ MetricCard 数字卡
- ✅ ProgressBar 进度条（阈值变色）
- 🚧 Canvas 折线图（规划）

---

#### 模块 6：快捷命令库

**实现位置**：[pages/Commands.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Commands.ets)

| 功能 | 实现状态 |
|------|---------|
| 分类侧栏 | ✅ 7 分类（全部/系统/进程/网络/Docker/安全/服务）+ 计数徽章 |
| 命令卡片 | ✅ Flex wrap 网格，每卡 280 宽 |
| 命令内容 | ✅ mono 字体 + bgSurface2 背景 + 可点击复制 |
| 复制 | ✅ promptAction.showToast |
| 运行 | 🚧 UI 占位 |
| 添加命令 | 🚧 UI 占位 |

---

#### 模块 7：批量操作

**实现位置**：[pages/Batch.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Batch.ets)

| 功能 | 实现状态 |
|------|---------|
| 服务器勾选 | ✅ Stack 模拟复选框 + 全选/取消 |
| 命令输入 | ✅ TextArea + TextAreaController |
| 常用模板 | ✅ 4 模板（系统信息/磁盘检查/服务重启/日志查看） |
| 执行结果 | ✅ Mock 生成（3 台成功，1 台失败）+ 可展开 |

---

#### 模块 8：告警中心

**实现位置**：[pages/Alerts.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Alerts.ets)

| 功能 | 实现状态 |
|------|---------|
| 三色统计 | ✅ 严重(danger)/警告(warning)/信息(info) MetricCard |
| 过滤标签 | ✅ 5 种（全部/未处理/严重/警告/信息） |
| 告警卡片 | ✅ 左侧 3px 色条 + 标题 + 详情 + 来源 + 时间 |
| 标记已处理 | ✅ 局部 @State 覆盖 + 已处理 opacity 0.5 |
| 全部已读 | ✅ 按钮 |

---

#### 模块 9：系统设置

**实现位置**：[pages/Settings.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Settings.ets)

**7 个分组**：

| 分组 | 配置项 |
|------|--------|
| 常规 | 默认 SSH 端口 / 连接超时 / 自动重连(开关) |
| 外观 | 主题 / 字号 / 字体 |
| 终端 | 默认字体 / 光标样式 / 滚屏行数 / 256 色(开关) |
| 安全 | 主密码 / 生物识别解锁(开关) / 自动锁定 / 主机指纹校验(开关) |
| 通知 | 告警推送(开关) / 勿扰时段 / 阈值配置 |
| 数据 | 导出配置 / 导入配置 / 清除缓存 / 自动备份(开关) |
| 关于 | 版本 / 检查更新 / 用户协议 / 隐私政策 / 开源许可 / 反馈 |

---

## 五、数据模型设计

### 5.1 核心实体

详见 [model/Models.ets](file:///workspace/zhizon/entry/src/main/ets/model/Models.ets)，关键实体：

| 实体 | 说明 |
|------|------|
| `Server` | SSH 服务器（含 metrics 子对象） |
| `SshKey` | SSH 密钥 |
| `PveCluster` | PVE 集群（含 nodes 数组） |
| `PveNode` | PVE 集群内物理节点 |
| `Vm` | 虚拟机/容器（qemu/lxc） |
| `Storage` | 存储池（dir/lvmthin/zfs/nfs） |
| `PveTask` | PVE 任务 |
| `Snapshot` | VM 快照 |
| `Command` | 快捷命令 |
| `Alert` | 告警 |
| `FileItem` | 文件项 |
| `Stats` | 统计聚合 |
| `TerminalSession` | 终端会话 |

### 5.2 数据存储方案

| 数据类型 | 存储方式 | 状态 |
|---------|---------|------|
| Mock 数据 | 内存常量 MockData | ✅ |
| 服务器/密钥/PVE 配置 | Preferences | 🚧 规划 |
| 命令历史、操作日志 | RelationalStore | 🚧 规划 |
| 临时监控数据 | 内存 + 文件缓存 | 🚧 规划 |
| 文件缓存 | 应用沙箱 | 🚧 规划 |

### 5.3 Mock 数据规模

| 数据 | 数量 | 说明 |
|------|------|------|
| SSH 服务器 | 6 | 涵盖 online/warning/offline 三种状态 |
| PVE 集群 | 1 | homelab-cluster |
| PVE 物理节点 | 3 | pve1/pve2/pve3 |
| 虚拟机/容器 | 11 | QEMU + LXC，涵盖 running/stopped/paused |
| 存储池 | 6 | dir/lvmthin/zfs/nfs 四种类型 |
| PVE 任务 | 6 | running/success/failed 三种状态 |
| 快照 | 4 | 分布在 3 个 VM |
| 快捷命令 | 12 | 7 个分类 |
| 告警 | 6 | critical/warning/info 三级 |
| 文件 | 12 | 含目录与文件 |

---

## 六、UI/UX 设计规范

### 6.1 设计风格

- **风格**：tech-dark（深色终端科技风）
- **主色**：终端青绿 `#00D9A3`
- **强调色**：紫色 `#8B5CF6`（PVE 专属）、信息蓝 `#3B82F6`
- **字体**：系统字体 + JetBrains Mono（代码/数字）

### 6.2 颜色规范

详见 [common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets)

| 用途 | 色值 |
|------|------|
| 背景基色 | `#0A0E1A` |
| 卡片背景 | `#131826` |
| 次级背景 | `#1A2030` |
| 主色 | `#00D9A3` |
| 成功 | `#10B981` |
| 警告 | `#F59E0B` |
| 危险 | `#EF4444` |
| 信息 | `#3B82F6` |
| 紫色（PVE） | `#8B5CF6` |
| 主文字 | `#E2E8F0` |
| 次文字 | `#94A3B8` |
| 三级文字 | `#64748B` |

### 6.3 进度条阈值变色

```typescript
function progressColor(value: number): string {
  if (value >= 85) return '#EF4444'; // danger
  if (value >= 65) return '#F59E0B'; // warning
  return '#10B981';                   // success
}
```

### 6.4 状态徽章映射

```typescript
const statusMap = {
  online:   { text: '在线',   color: '#10B981' },
  warning:  { text: '告警',   color: '#F59E0B' },
  offline:  { text: '离线',   color: '#64748B' },
  running:  { text: '运行中', color: '#10B981' },
  stopped:  { text: '已停止', color: '#EF4444' },
  paused:   { text: '已暂停', color: '#F59E0B' },
  success:  { text: '成功',   color: '#10B981' },
  failed:   { text: '失败',   color: '#EF4444' },
  active:   { text: '可用',   color: '#10B981' }
};
```

### 6.5 响应式适配

| 设备 | 布局 |
|------|------|
| 手机（竖屏） | 左侧栏 220 + 单栏内容 |
| 手机（横屏） | 同上 |
| 平板 | 同上（侧栏更宽） |
| 折叠屏 | 同上 |

> 当前为统一布局，后续可加入媒体查询适配。

---

## 七、通用组件设计

### 7.1 组件清单

| 组件 | 文件 | 说明 |
|------|------|------|
| NavSidebar | [components/NavSidebar.ets](file:///workspace/zhizon/entry/src/main/ets/components/NavSidebar.ets) | 左侧导航栏，含 Logo + 9 菜单项 + 用户信息 |
| TopBar | [components/TopBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/TopBar.ets) | 顶栏，标题+副标题+@BuilderParam actions |
| StatusBadge | [components/StatusBadge.ets](file:///workspace/zhizon/entry/src/main/ets/components/StatusBadge.ets) | 状态徽章，状态点+文字 |
| ProgressBar | [components/ProgressBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/ProgressBar.ets) | 进度条，阈值自动变色 |
| MetricCard | [components/MetricCard.ets](file:///workspace/zhizon/entry/src/main/ets/components/MetricCard.ets) | 指标卡，标题+大数字+单位+副标+徽章 |

### 7.2 使用示例

```typescript
// TopBar + actions 用法
@Builder actionsBuilder() {
  Button('刷新')
    .fontSize(12)
    .fontColor(AppTheme.textSecondary)
    .backgroundColor(AppTheme.bgSurface2)
    .borderRadius(6)
}

build() {
  Row() {
    NavSidebar({
      activeKey: this.activeNav,
      onSelect: (key: string) => {
        router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
      }
    })
    Column() {
      TopBar({ title: '标题', subtitle: '副标题' }) {
        this.actionsBuilder()
      }
      // ...
    }
  }
}
```

---

## 八、页面路由与导航

### 8.1 路由配置

详见 [resources/base/profile/main_pages.json](file:///workspace/zhizon/entry/src/main/resources/base/profile/main_pages.json)

```json
{
  "src": [
    "pages/Index",
    "pages/Servers",
    "pages/ServerDetail",
    "pages/Terminal",
    "pages/Files",
    "pages/Pve",
    "pages/PveNodeDetail",
    "pages/VmDetail",
    "pages/Commands",
    "pages/Batch",
    "pages/Alerts",
    "pages/Settings"
  ]
}
```

### 8.2 导航策略

- **侧栏切换主页面**：`router.replaceUrl`（避免栈堆积）
- **进入子页面**：`router.pushUrl`（保留返回栈）
- **传参方式**：`router.pushUrl({ url: 'pages/Xxx', params: { id: xxx } })`，接收方 `router.getParams() as Record<string, string>`

### 8.3 页面跳转关系

```
Index ─┬─> Servers ──> ServerDetail ──> Terminal
       │              └─> Terminal
       │
       ├─> Pve ──> PveNodeDetail ─┬─> VmDetail
       │                           └─> Terminal (SSH 连接节点)
       │
       ├─> Alerts
       └─> (其他工具页直接跳转)
```

---

## 九、安全设计

### 9.1 密钥与密码存储（规划）

```
用户主密码（用户输入）
  └─ 派生密钥（PBKDF2, 10000 轮）
      └─ AES-256-GCM 加密
          ├─ SSH 私钥
          ├─ 服务器密码
          ├─ PVE 密码/API Token
          └─ 应用配置
```

### 9.2 生物识别解锁（规划）

- 启动应用 → 生物识别（指纹/面容）→ 解密主密钥
- 主密钥仅在内存中，应用退出即清除

### 9.3 网络安全

- PVE 自签名证书：用户可选跳过 TLS 校验（`verifyTls` 字段）
- SSH 主机指纹：首次连接记录，变更时告警（规划）
- 所有网络请求强制 HTTPS/SSH 加密

---

## 十、关键技术方案

### 10.1 SSH 协议实现（规划）

```
ArkTS 层
  └─ SshService 类
      ├─ connect(config)
      ├─ exec(command)
      ├─ shell() → 终端流
      └─ sftp() → 文件操作
           │
NAPI 层（C/C++）
  └─ libssh2 封装
      ├─ 会话管理
      ├─ 通道复用
      └─ 加密握手
```

**当前实现**：[SshService.ets](file:///workspace/zhizon/entry/src/main/ets/service/SshService.ets) 已写好接口骨架，方法返回 Mock 数据。

### 10.2 PVE API 客户端

[PveService.ets](file:///workspace/zhizon/entry/src/main/ets/service/PveService.ets) 已封装 `PveClient` 类，包含：

- `login(username, password)` — 获取 Ticket
- `getNodes()` — 集群节点列表
- `getVms(node)` — VM 列表
- `vmAction(node, vmid, action)` — VM 启停
- `createSnapshot(node, vmid, name)` — 创建快照

当前返回 Mock 数据，后续替换为真实 `@ohos.net.http` 调用。

### 10.3 终端仿真（规划）

**方案对比**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| 移植 Xterm.js | 功能完整 | JS 库较大，性能一般 |
| 自研字符网格 | 性能好、可控 | 工作量大，需处理 ANSI |
| WebView + Xterm.js | 快速实现 | 性能差、交互割裂 |

**推荐方案**：自研轻量终端组件（基于 ArkUI Canvas）

---

## 十一、Mock 数据说明

详见 [service/MockData.ets](file:///workspace/zhizon/entry/src/main/ets/service/MockData.ets)

### 11.1 SSH 服务器（6 台）

| ID | 名称 | 状态 | OS | 用途 |
|----|------|------|----|----|
| srv-001 | prod-web-01 | online | Ubuntu 22.04 | 生产 Web |
| srv-002 | prod-db-master | warning | Debian 12 | 生产 DB（CPU 78%） |
| srv-003 | dev-test-01 | online | Ubuntu 24.04 | 测试 |
| srv-004 | monitor-grafana | online | CentOS 9 | 监控 |
| srv-005 | backup-storage | offline | Alpine 3.19 | 备份（离线） |
| srv-006 | ci-runner-01 | online | Ubuntu 22.04 | CI/CD |

### 11.2 PVE 集群（1 集群 × 3 节点 × 11 VM）

| 节点 | CPU 核数 | 内存 | VM 数 | CT 数 |
|------|---------|------|-------|-------|
| pve1 | 16 | 64GB | 12 | 8 |
| pve2 | 16 | 64GB | 8 | 5 |
| pve3 | 8 | 32GB | 6 | 3 |

VM 清单涵盖：ubuntu-web、debian-db、alpine-dns、centos-redis、win10-office、haos-homeassistant、opnsense-fw、k8s-master/worker1/worker2、gitlab-ci

---

## 十二、开发计划

### 12.1 里程碑

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1: 基础框架** | 项目骨架、设计系统、导航、12 页面 UI | ✅ 完成 |
| **M2: SSH 核心** | NAPI libssh2、终端组件、服务器管理 | 🚧 规划 |
| **M3: PVE 集成** | PVE API 真实对接、节点/VM 管理 | 🚧 规划 |
| **M4: 监控告警** | 监控图表、告警系统、通知推送 | 🚧 规划 |
| **M5: 高级功能** | SFTP、批量操作、文件管理 | 🚧 规划 |
| **M6: 优化发布** | 性能优化、安全加固、上架准备 | 🚧 规划 |

### 12.2 优先级排序

- **P0（已完成）**：项目骨架、12 页面 UI、Mock 数据、主题系统
- **P1（下一步）**：SSH 协议层（libssh2 NAPI）、PVE 真实 API、数据持久化
- **P2（增强）**：监控图表、告警通知、SFTP
- **P3（可选）**：VM 控制台、集群迁移、Webhook 告警

---

## 十三、风险评估

| 风险 | 等级 | 应对 |
|------|------|------|
| libssh2 在鸿蒙编译困难 | 高 | 预先验证 NAPI 编译链；备选 libssh |
| 终端性能不足 | 中 | 自研轻量终端；限制滚动行数 |
| PVE API 版本兼容 | 低 | 仅支持 PVE 7.x+，API v2 |
| 后台保活被系统限制 | 中 | 引导用户加入电池白名单 |
| 密钥泄露 | 高 | AES-256 + 生物识别 + 内存隔离 |

---

## 十四、附录

### 14.1 文件清单

| 类型 | 数量 | 说明 |
|------|------|------|
| 配置文件 | 8 | build-profile/oh-package/module.json5/... |
| 资源文件 | 3 | color.json/string.json/main_pages.json |
| ArkTS 代码 | 24 | EntryAbility + 2 common + 4 service + 1 model + 5 components + 12 pages |
| 文档 | 2 | README.md + doc/DESIGN.md |
| **合计** | **40** | |

### 14.2 代码规模

- **总行数**：4,773 行
- **最大文件**：VmDetail.ets（517 行）
- **平均文件**：约 200 行

### 14.3 参考资源

- Proxmox VE API 文档：https://pve.proxmox.com/wiki/Proxmox_VE_API
- libssh2 文档：https://www.libssh2.org/docs/
- HarmonyOS 开发文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/
- ArkUI 组件参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/

---

## 文档版本

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-08-04 | 初始版本，对应 MVP 实现（40 文件 / 4773 行） |

---

**智子（Zhizon）** · HarmonyOS NEXT 原生应用 · MIT License

# 微舆（BettaFish）鸿蒙客户端 App 设计方案

> 版本：v1.0
> 目标系统：HarmonyOS 6.1.1(24)（API 24）
> 服务端：自部署 BettaFish（微舆）多 Agent 舆情分析系统
> 文档状态：方案设计稿（未进入编码）

---

## 目录

1. [项目概述](#1-项目概述)
2. [需求与范围](#2-需求与范围)
3. [技术选型](#3-技术选型)
4. [总体架构](#4-总体架构)
5. [服务端对接方案](#5-服务端对接方案)
6. [连接配置方案](#6-连接配置方案)
7. [功能模块与页面设计](#7-功能模块与页面设计)
8. [自适应布局设计](#8-自适应布局设计)
9. [数据模型设计](#9-数据模型设计)
10. [关键技术实现方案](#10-关键技术实现方案)
11. [工程目录结构](#11-工程目录结构)
12. [异常与容错设计](#12-异常与容错设计)
13. [安全与隐私设计](#13-安全与隐私设计)
14. [开发里程碑](#14-开发里程碑)
15. [附录](#15-附录)

---

## 1. 项目概述

### 1.1 背景

BettaFish（微舆）是一个开源的创新型多 Agent 舆情分析系统：用户只需像聊天一样提出分析需求，系统会自动调度 Query Engine（网页搜索）、Media Engine（多模态分析）、Insight Engine（私有数据库挖掘）三个分析 Agent 并行研究，通过 ForumEngine（论坛主持人）进行"论坛式"协作讨论，最后由 ReportEngine 生成精美的交互式 HTML 舆情分析报告。

用户已自行部署 BettaFish 服务端（默认监听 `0.0.0.0:5000`，Docker 方式或源码方式运行），希望拥有一款鸿蒙原生 App，摆脱浏览器束缚，在手机 / 平板 / 折叠屏上随时连接并操作这套系统。

### 1.2 目标

- 在 HarmonyOS 6.1.1(24) 上构建原生 ArkUI 应用，作为 BettaFish 的移动端控制台。
- 覆盖"连接配置 → 发起分析 → 论坛实况 → 报告生成 → 报告查看/导出 → 系统管理"的完整闭环。
- 服务器地址（协议 / IP / 域名 / 端口）完全由用户自行配置，不硬编码。
- 一码多端，自适应手机、平板、折叠屏三种形态。

### 1.3 设计原则

| 原则 | 说明 |
|------|------|
| 原生优先 | 页面使用 ArkUI 原生组件构建，报告渲染采用 Web 组件承载（HTML 报告为服务端产物，WebView 是最优解） |
| 实时但不脆弱 | 优先 SSE 流式接收进度事件，失败时自动降级为轮询 |
| 配置驱动 | 所有服务端地址参数均由用户配置并本地持久化，支持多服务器配置切换 |
| 容错优先 | 服务端 Agent 运行耗时较长（分钟级），App 端需处理超时、断连、取消、重连 |
| 最小侵入 | 不改动服务端代码，完全基于 BettaFish 现有 HTTP/SSE 接口对接 |

---

## 2. 需求与范围

### 2.1 功能需求（完整版）

| 编号 | 模块 | 功能 | 说明 |
|------|------|------|------|
| F1 | 连接配置 | 服务器配置 | 协议(http/https)、IP/域名、端口自配置，支持多套配置保存与切换 |
| F2 | 连接配置 | 连接测试 | 点击测试连通性，显示服务端版本与系统状态 |
| F3 | 分析 | 发起分析 | 对话式输入分析需求，提交 `POST /api/search` |
| F4 | 分析 | 系统/引擎状态 | 展示系统是否启动、各引擎(Query/Media/Insight/Forum)运行状态 |
| F5 | 分析 | 一键启动系统 | 服务端未启动时提示并调用 `POST /api/system/start` |
| F6 | 论坛 | 论坛实况 | 实时滚动展示 Agent 论坛消息（HOST/QUERY/MEDIA/INSIGHT） |
| F7 | 报告 | 生成报告 | 引擎就绪后触发 `POST /api/report/generate`，返回 task_id |
| F8 | 报告 | 生成进度 | SSE 实时接收 status/progress/stage/log 事件，展示进度条与阶段日志 |
| F9 | 报告 | 取消任务 | 取消进行中的报告生成任务 |
| F10 | 报告 | 报告查看 | WebView 渲染最终 HTML 报告 |
| F11 | 报告 | 导出下载 | 导出 HTML/Markdown/PDF 到本地（文件选择器选目录保存） |
| F12 | 报告 | 历史记录 | 本机运行过的分析/报告任务历史，可再次打开或下载 |
| F13 | 系统管理 | 引擎启停 | 单个引擎(insight/media/query/forum)启动/停止 |
| F14 | 系统管理 | 系统关停 | 调用系统优雅关停接口 |
| F15 | 系统管理 | 运行日志 | 查看引擎输出日志与报告引擎日志 |
| F16 | 设置 | 配置查看 | 查看/修改服务端 .env 关键配置（仅列出官方接口允许的字段） |

### 2.2 非功能需求

| 类别 | 要求 |
|------|------|
| 系统版本 | compileSdk / targetSdk 均为 `6.1.1(24)`，compatibleSdk 建议 `6.1.1(24)`（如需兼容旧机可下调至 `5.1.1(19)` 并按需回退 API） |
| 设备形态 | 手机（竖屏）、平板、折叠屏（展开态），支持横竖屏切换 |
| 性能 | 论坛轮询间隔 ≥3s；SSE 心跳 15s 内保持连接；列表虚拟滚动 |
| 稳定性 | SSE 断线自动重连（Last-Event-ID 续传）；接口超时可配置（默认 10s 连接 / 30s 读取） |
| 安全 | 仅保存服务端地址与用户本机偏好，不缓存 API 密钥；HTTPS 优先，明文 HTTP 通过网络安全配置显式放行 |
| 国际化 | 首版中文（与服务端一致） |

---

## 3. 技术选型

| 维度 | 选择 | 理由 |
|------|------|------|
| 系统/API | HarmonyOS 6.1.1(24) | 用户指定 |
| IDE | DevEco Studio 6.1.1 Release | 官方配套工具链（Hvigor 6.24.4 / ohpm 6.1.2.285 / modelVersion 6.1.1） |
| 应用模型 | Stage 模型 + EntryAbility | 官方推荐，HarmonyOS NEXT 标准范式 |
| UI 框架 | ArkUI 声明式（ArkTS） | 原生能力、状态管理完善 |
| 状态管理 | State Management V2（`@ObservedV2`/`@Trace`/`@Provider`/`@Consumer`）+ AppStorage | API 12 起成熟，V2 对组件级状态追踪更精细；AppStorage 承担全局配置 |
| 网络 | `@ohos.net.http`（HTTP + SSE 流式）+ 轮询兜底 | 服务端无 Socket.IO 原生通道需求（论坛用 HTTP 轮询即可），无需引入 WebSocket |
| 报告渲染 | `@ohos.web.webview` Web 组件 | 报告是服务端生成的交互式 HTML，WebView `loadUrl`/`loadData` 直接承载 |
| 文件保存 | `@ohos.file.picker`（DocumentViewPicker） | 系统文件选择器选择目录保存导出文件，避免沙箱路径暴露 |
| 持久化 | `@ohos.data.preferences` | 保存服务器配置、历史任务、偏好设置 |
| 本地存储路径 | `@ohos.file.fs` + 应用沙箱 `files/` | 缓存报告 HTML、导出中间文件 |

> 说明：State Management V2 中 `@ObservedV2` + `@Trace` 用于响应式数据类，`@Provider`/`@Consumer` 用于跨层共享；`AppStorage` 或 `PersistentStorage` 承接全局连接配置。为降低学习成本也可统一采用 V1（`@State`/`@Link`/`@Provide`），但推荐 V2 面向未来。

---

## 4. 总体架构

### 4.1 分层架构

```
┌───────────────────────────────────────────────────────────────┐
│                         表现层（ArkUI 页面）                     │
│  AnalysisPage / ForumPage / ReportListPage / ReportViewPage    │
│  SystemManagePage / ServerConfigPage / SettingsPage / AboutPage│
├───────────────────────────────────────────────────────────────┤
│                      ViewModel 层（状态编排）                    │
│  AnalysisViewModel / ForumViewModel / ReportViewModel          │
│  SystemViewModel / ServerConfigViewModel                       │
├───────────────────────────────────────────────────────────────┤
│                       服务层（Service）                         │
│  ApiClient(HTTP封装) │ SseClient(SSE解析) │ ForumPoller(轮询)   │
│  ReportExporter(导出) │ ConfigStore(持久化) │ ConnectionProbe    │
├───────────────────────────────────────────────────────────────┤
│                      数据模型层（Model）                         │
│  ServerConfig / EngineStatus / SystemStatus / ForumMessage     │
│  ReportTask / ReportEvent / ReportHistoryItem                  │
├───────────────────────────────────────────────────────────────┤
│                 平台能力层（HarmonyOS SDK）                      │
│  @ohos.net.http │ @ohos.web.webview │ @ohos.file.picker         │
│  @ohos.data.preferences │ @ohos.file.fs │ 网络安全配置           │
└───────────────────────────────────────────────────────────────┘
                          │ HTTP / SSE
┌───────────────────────────────────────────────────────────────┐
│           自部署 BettaFish 服务端（Flask :5000）                 │
│  /api/*  REST │ /api/report/*  REST+SSE │ 静态报告资源           │
└───────────────────────────────────────────────────────────────┘
```

### 4.2 模块职责

| 模块 | 职责 | 关键类/文件 |
|------|------|------------|
| ApiClient | 统一 HTTP 请求封装：JSON 序列化、超时、错误映射、BaseURL 注入 | `services/ApiClient.ets` |
| SseClient | SSE 流式连接：数据分块累积、帧解析、事件分发、断线重连（Last-Event-ID） | `services/SseClient.ets` |
| ForumPoller | 论坛日志增量轮询（基于 position），解析并分发 ForumMessage | `services/ForumPoller.ets` |
| ReportExporter | 报告下载/导出：HTML/MD/PDF 拉取 → 沙箱缓存 → 文件选择器保存 | `services/ReportExporter.ets` |
| ConfigStore | 服务器配置与历史任务的读写、多配置管理 | `services/ConfigStore.ets` |
| ConnectionProbe | 连通性测试与系统状态探测 | `services/ConnectionProbe.ets` |

---

## 5. 服务端对接方案

### 5.1 服务端现状（已核实源码）

- 主应用：Flask + Flask-SocketIO，默认监听 `0.0.0.0:5000`，服务端已启用 `eventlet` 补丁以支持流式断开安全。
- ReportEngine 以 Blueprint 挂载在 `/api/report` 前缀下，提供 REST + SSE 接口。
- 分析流程：`/api/search` 把 query 分发给运行中的 Streamlit Agent（8501/8502/8503）→ 各 Agent 写报告与日志 → `/api/report/generate` 检查输入文件就绪后生成 HTML 报告。
- 结论：**App 只需直连 Flask 主端口（5000）即可完成全部功能，无需改动服务端。** 部署时需确保该端口对 App 所在设备可达（局域网/公网/NAT/反向代理均可）。

### 5.2 接口清单（App 实际使用）

| # | 方法 | 路径 | 用途 | 说明 |
|---|------|------|------|------|
| 1 | GET | `/api/system/status` | 系统启动状态 | `{success, started, starting}`，连接测试用它 |
| 2 | POST | `/api/system/start` | 一键启动系统 | 返回 `{success, message, logs}` |
| 3 | POST | `/api/system/shutdown` | 优雅关停系统 | 返回 `{success, message, ports}` |
| 4 | GET | `/api/status` | 各引擎状态 | `{insight/media/query/forum: {status, port, output_lines}}` |
| 5 | GET | `/api/output/<app_name>` | 引擎输出日志 | `app_name ∈ {insight, media, query}` |
| 6 | POST | `/api/search` | 提交分析需求 | body `{query}` → `{success, query, results}` |
| 7 | GET | `/api/forum/log` | 论坛全部消息 | 返回 `parsed_messages[]`（结构化） |
| 8 | POST | `/api/forum/log/history` | 论坛增量消息 | body `{position, max_lines}` → `{log_lines[], position, has_more}` |
| 9 | GET | `/api/config` | 读取服务端配置 | `{success, config:{KEY:value}}` |
| 10 | POST | `/api/config` | 修改服务端配置 | 仅白名单 CONFIG_KEYS，写入 .env |
| 11 | GET | `/api/report/status` | 报告引擎状态 | `{initialized, engines_ready, files_found[], missing_files[], current_task}` |
| 12 | POST | `/api/report/generate` | 启动报告生成 | body `{query, custom_template}` → `{task_id, stream_url, task}` |
| 13 | GET | `/api/report/progress/<task_id>` | 轮询任务进度 | `{success, task}`（SSE 降级方案） |
| 14 | GET | `/api/report/stream/<task_id>` | SSE 实时事件流 | 见 5.4；支持 `Last-Event-ID` 断点续传 |
| 15 | GET | `/api/report/result/<task_id>` | 报告 HTML | 直接返回 `text/html`，可直接供 WebView 加载 |
| 16 | GET | `/api/report/result/<task_id>/json` | 报告 HTML(JSON) | `{success, task, html_content}` |
| 17 | GET | `/api/report/download/<task_id>` | 下载 HTML 附件 | `Content-Disposition: attachment` |
| 18 | POST | `/api/report/cancel/<task_id>` | 取消任务 | 仅 running/pending 有效 |
| 19 | GET | `/api/report/templates` | 模板列表 | 报告中可让用户选择模板名 |
| 20 | GET | `/api/report/export/md/<task_id>` | 导出 Markdown | 附件下载 |
| 21 | GET | `/api/report/export/pdf/<task_id>` | 导出 PDF | 附件下载（需服务端 Pango 依赖） |
| 22 | GET | `/api/report/log` | 报告引擎日志 | 支持 `?lines=` 等参数 |

### 5.3 ReportTask 数据结构（服务端 to_dict 契约）

```json
{
  "task_id": "report_1756...",
  "query": "武汉大学舆情",
  "status": "running",              // pending/running/completed/error/cancelled
  "progress": 42,
  "error_message": "",
  "created_at": "2026-08-25T03:00:00.000000",
  "updated_at": "2026-08-25T03:05:00.000000",
  "has_result": false,
  "report_file_ready": false,
  "report_file_name": "",
  "report_file_path": "",
  "state_file_ready": false,
  "state_file_path": "",
  "ir_file_ready": false,
  "ir_file_path": "",
  "markdown_file_ready": false,
  "markdown_file_name": "",
  "markdown_file_path": ""
}
```

### 5.4 SSE 事件流契约

请求：`GET {baseUrl}/api/report/stream/{task_id}`，可选请求头 `Last-Event-ID: <lastId>`。

响应：`Content-Type: text/event-stream`，每帧格式：

```
id: 12
event: progress
data: {"id":12,"type":"progress","task_id":"report_...","timestamp":"...","payload":{"progress":42}}
```

事件类型（`event` 字段）：

| event | payload 关键字段 | 说明 |
|-------|-----------------|------|
| `status` | `{status, progress, error_message, hint, task}` | 状态变更（含终态 completed/error/cancelled） |
| `progress` | `{progress, ...}` | 进度数值 |
| `stage` | `{message, stage, files?, attempt?}` | 阶段提示（prepare/io_ready/data_loaded/agent_running…） |
| `log` | `{line, level, timestamp, message, module, function}` | 报告引擎实时日志 |
| `warning` | `{message, stage}` | 告警（如"更换更强 LLM"提示） |
| `heartbeat` | `{status}` | 15s 心跳（`id` 为 `hb-...`，非数字） |

**终态判定**：`event.type ∈ {completed, error, cancelled}`，或 `payload.status ∈ STREAM_TERMINAL_STATUSES`。心跳间隔 15s，终态后 120s 空闲自动收口。

**帧解析要点**：
- 帧分隔符：空行 `\n\n`；
- `id:` / `event:` / `data:` 行累积；`data` 为 JSON；
- 以 `:` 开头的行为注释（心跳为 `:ping` 类），忽略；
- `id` 为 `hb-...` 时不可解析为数字，需字符串化存储；
- 服务端 `data` 中 `id` 字段才是真正的递增数字事件号（客户端以 `payload` 内 `id` 作为 Last-Event-ID 依据）。

---

## 6. 连接配置方案

> 用户明确要求：**IP/端口/域名由用户自行配置。**

### 6.1 配置项

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| name | string | "默认服务器" | 配置别名，支持多套 |
| scheme | enum | `http` | `http` / `https` |
| host | string | "" | IP 或域名（如 `192.168.1.100` / `betta.example.com`） |
| port | number | 5000 | 服务端口（默认 5000） |
| basePath | string | "" | 可选反向代理子路径前缀 |
| timeoutSec | number | 10 | 连接超时（s） |
| isCurrent | boolean | - | 是否为当前激活配置 |

`baseUrl = scheme + "://" + host + ":" + port + basePath`

### 6.2 交互流程

1. 首次启动：无配置 → 引导页直达"服务器配置"页。
2. 填写协议 / IP / 域名 / 端口 → 点击 **测试连接**。
3. 测试逻辑：`GET {baseUrl}/api/system/status`，成功且 `success=true` 即通过；失败给出分类提示（网络不可达 / 超时 / 非 BettaFish 服务 / 未授权）。
4. 保存：写入 Preferences（`PersistentStorage` 同步到 AppStorage），多套配置可切换。

### 6.3 网络配置（关键工程项）

由于 BettaFish 通常以明文 HTTP 部署在局域网，需要在工程中显式放行：

1. `module.json5` 声明 `ohos.permission.INTERNET`。
2. 新建网络安全配置文件 `resources/base/profile/network_security_config.json`：

```json
{
  "network-security-config": {
    "base-config": {
      "cleartextTrafficPermitted": true
    }
  }
}
```

3. `module.json5` 的 `metadata` 中引用：

```json5
"metadata": [
  {
    "name": "network_security_config",
    "resource": "$profile:network_security_config"
  }
]
```

> HTTPS 部署时建议后续收紧为 `cleartextTrafficPermitted: false` 并按域名配置证书信任。

---

## 7. 功能模块与页面设计

### 7.1 信息架构

```
微舆（BettaFish 客户端）
├── ① 分析（默认页）
│   ├── 服务器连接状态卡（未连接→引导配置）
│   ├── 系统/引擎状态摘要（Query / Media / Insight / Forum）
│   ├── 对话式输入区（输入框 + 常用示例问题）
│   └── 提交后 → 分析进行中视图
│       ├── 引擎工作状态（三 Agent + 主持人）
│       ├── 阶段日志流（实时）
│       └── 操作：查看论坛 / 生成报告（就绪时点亮） / 取消
├── ② 论坛
│   └── Agent 论坛实时动态（HOST 主持人 / QUERY / MEDIA / INSIGHT 消息流）
├── ③ 报告
│   ├── 报告历史列表（本机任务记录）
│   ├── 报告查看（WebView 渲染 HTML）
│   │   └── 操作：导出 PDF / 导出 MD / 下载 HTML / 分享
│   └── 模板选择（生成报告前可选模板）
└── ④ 设置
    ├── 服务器配置（多配置管理 / 测试连接）
    ├── 系统管理（启动系统 / 关停系统 / 引擎启停 / 运行日志）
    ├── 报告引擎（状态 / 日志 / 清空日志）
    └── 关于
```

### 7.2 页面明细

| 页面 | 路由 | 核心元素 | 数据来源 |
|------|------|----------|----------|
| MainTabPage | `/` | Tabs（分析/论坛/报告/设置）+ Navigation 容器 | AppStorage 配置 |
| ServerConfigPage | `/server-config` | 表单、测试连接按钮、配置列表、切换 | ConfigStore |
| AnalysisPage | `/analysis` | 状态卡、输入框、提交按钮 | SystemViewModel |
| AnalysisProgressPage | `/analysis/progress?taskId=` | 进度条、Agent 状态、日志流、操作按钮 | AnalysisViewModel + SseClient |
| ForumPage | `/forum` | 消息列表（LazyForEach 虚拟滚动）、来源过滤 | ForumViewModel + ForumPoller |
| ReportListPage | `/reports` | 历史任务列表、状态徽标、入口 | ReportViewModel + ConfigStore |
| ReportViewPage | `/reports/view?taskId=` | Web 组件、导出菜单 | ReportViewModel + ReportExporter |
| TemplatePickerPage | `/reports/templates` | 模板卡片列表 | GET `/api/report/templates` |
| SystemManagePage | `/system` | 引擎开关、日志查看器 | SystemViewModel |
| SettingsPage | `/settings` | 分组设置项 | ConfigStore |
| AboutPage | `/about` | 版本、开源链接、免责声明 | 静态 |

### 7.3 核心交互流程

**流程 A：完整分析链路（主流程）**

```
[分析页] 输入需求 query
   │ POST /api/search {query}
   │ （若系统未启动：POST /api/system/start 先行）
   ▼
[分析进行中] 三个 Agent 并行研究
   │ 轮询 GET /api/status（引擎仍 running）
   │ + 论坛页 POST /api/forum/log/history（position 增量）实时看讨论
   ▼
[引擎就绪] 轮询 GET /api/report/status → engines_ready=true
   │ 用户点"生成报告"（或开启自动生成）
   ▼
[报告生成] POST /api/report/generate {query}
   │ 得到 task_id
   ▼
[进度监听] GET /api/report/stream/{task_id}（SSE）
   │ 实时渲染 progress / stage / log 事件
   │ SSE 断线 → 重连（Last-Event-ID）→ 失败降级轮询 progress
   ▼
[终态] completed
   ▼
[报告查看] WebView 加载 {baseUrl}/api/report/result/{task_id}
   │ 或 loadData(html_content)
   ▼
[导出] export/md、export/pdf、download → 文件选择器保存到用户目录
```

**流程 B：连接配置**

```
[设置-服务器配置]
  填写 scheme/host/port → 测试连接(GET /api/system/status)
  → 通过则保存(Preferences) → 切回主界面自动刷新状态
```

**流程 C：系统管理**

```
[系统管理页]
  显示 started/starting 与四引擎状态(轮询 GET /api/status)
  → 一键启动(POST /api/system/start，返回启动日志流展示)
  → 单个引擎 start/stop → 关停(POST /api/system/shutdown)
```

---

## 8. 自适应布局设计

### 8.1 断点策略（ArkUI GridRow breakpoints）

| 断点 | 宽度 | 设备 | 布局策略 |
|------|------|------|----------|
| sm | < 600vp | 手机竖屏 | 单列堆叠，底部 Tab 导航 |
| md | 600~840vp | 折叠屏展开/小平板 | 双列：导航栏(≤320vp) + 内容区 |
| lg | > 840vp | 平板 | 双列/三列，侧边栏固定导航 |

### 8.2 实现要点

- 主框架采用 **`Navigation` + `NavDestination`**，`NavigationMode.Auto` 自动切换堆叠/分栏模式；手机默认堆叠，平板/折叠屏默认分栏。
- 底部导航：手机用 `Tabs`（底部 bar），md/lg 用侧边 `Navigation`（侧栏索引）承载"分析/论坛/报告/设置"。
- 内容区使用 `GridRow`/`GridCol` 声明式栅格，按断点控制卡片列数（分析卡片 1/2/3 列）。
- 折叠屏展开态监听：`window.on('windowSizeChange')` 与 `getWindowStageLastX()`（折叠状态）结合刷新断点。
- 字号/间距统一走 `$r('app.float.xxx')` 资源 + vp 单位，避免缩放失真。
- 报告 WebView 宽度自适应容器，启用 JS，缩放跟随系统。

---

## 9. 数据模型设计

```typescript
// 服务器配置
interface ServerConfig {
  id: string;            // uuid
  name: string;          // 别名
  scheme: 'http' | 'https';
  host: string;          // IP 或域名
  port: number;
  basePath: string;      // 可选前缀
  timeoutSec: number;
  isCurrent: boolean;
}

// 引擎状态（GET /api/status 单项）
interface EngineStatus {
  appName: 'insight' | 'media' | 'query' | 'forum';
  status: 'running' | 'stopped' | 'starting';
  port: number;
  outputLines: number;
}

// 系统状态（GET /api/system/status）
interface SystemStatus {
  started: boolean;
  starting: boolean;
}

// 论坛消息（GET /api/forum/log → parsed_messages[]）
interface ForumMessage {
  type: 'host' | 'agent';
  sender: string;        // "Forum Host" / "Query Engine" ...
  content: string;
  timestamp: string;     // HH:mm:ss
  source: 'HOST' | 'QUERY' | 'MEDIA' | 'INSIGHT';
}

// 报告任务（服务端 to_dict 同构）
interface ReportTask {
  taskId: string;
  query: string;
  status: ReportTaskStatus;   // pending|running|completed|error|cancelled
  progress: number;
  errorMessage: string;
  createdAt: string;
  updatedAt: string;
  hasResult: boolean;
  reportFileReady: boolean;
  reportFileName: string;
  reportFilePath: string;
  markdownFileReady: boolean;
  markdownFileName: string;
  markdownFilePath: string;
  irFileReady: boolean;
  stateFileReady: boolean;
}

// SSE 事件（服务端帧 data 同构）
interface ReportEvent {
  id: number;
  type: ReportEventType;  // status|progress|stage|log|warning|heartbeat|completed|error|cancelled
  taskId: string;
  timestamp: string;
  payload: Record<string, Object>;
}

// 本地历史项
interface ReportHistoryItem {
  taskId: string;
  query: string;
  status: string;
  createdAt: number;      // epoch ms
  baseUrl: string;        // 生成时所属服务器，用于回看
  savedAt: number;
}
```

> ArkTS 注意：禁用 `any`/`unknown` 未收窄使用，`Record<string, Object>` 需配合类型收窄访问；服务端返回字段需显式声明 interface 对齐。

---

## 10. 关键技术实现方案

### 10.1 ApiClient（HTTP 封装）

- 基于 `@ohos.net.http.createHttp()` 封装 `request<T>(method, path, body?, timeout?)`。
- 每次请求前注入 `ConfigStore.getCurrentBaseUrl()`；`Content-Type: application/json; charset=utf-8`。
- 统一响应处理：HTTP 200 + `success` 字段判定；错误码映射为业务异常（`SERVER_UNREACHABLE / TIMEOUT / NOT_BETTAFISH / TASK_BUSY / ENGINE_NOT_READY`）。
- 单例复用 HttpRequest 实例，注意并发时 `destroy()` 策略；超时 `connectTimeout` 默认 10s、`readTimeout` 默认 30s（SSE 单独配置）。

### 10.2 SseClient（SSE 流式客户端）

ArkTS 无原生 SSE API，利用 `http.HttpRequest.on('dataReceive')` 增量回调实现：

```
┌──────────┐  dataReceive(ArrayBuffer)  ┌──────────┐
│ HTTP 连接 │ ─────────────────────────▶ │ 字节缓冲  │
└──────────┘                            └────┬─────┘
                                             │ UTF-8 解码
                                             ▼
                                        ┌──────────┐
                                        │ 帧解析器   │  split("\n\n")
                                        └────┬─────┘
                                             ▼
                                   ┌────────────────────┐
                                   │ id/event/data 累积   │
                                   │ → ReportEvent       │
                                   └────────────────────┘
```

- 初始化：`request.on('dataReceive')` + `request.on('headersReceive')`；`request.request(url, { expectDataType: HttpDataType.STRING, header: {'Accept': 'text/event-stream'} })`。
- 断线重连：捕获错误码（如 `NET_STREAM_ERROR`/超时）→ 指数退避重连（1s/2s/4s/8s，上限 30s）→ 重连时携带 `Last-Event-ID: <最后成功事件id>`（服务端会回放历史事件）。
- 终态判定后主动 `destroy()` 连接。
- 心跳超时（>45s 无任何帧）视为连接假死，触发重连。
- **降级策略**：SSE 连续失败 ≥3 次 → 切换为 `GET /api/report/progress/{taskId}` 每 2s 轮询，任务终态即停。

### 10.3 ForumPoller（论坛增量轮询）

- 以 `POST /api/forum/log/history` 为主：请求体 `{position: lastPosition, max_lines: 200}`，响应 `{log_lines[], position, has_more}`；`position` 为服务端文件字节偏移，客户端持续保存。
- 本地解析格式：`[HH:MM:SS] [SOURCE] content`，SOURCE ∈ HOST/QUERY/MEDIA/INSIGHT（与服务端 `parse_forum_log_line` 正则一致），解析失败的行归为 `raw` 消息。
- 首次进入论坛页用 `GET /api/forum/log` 拉取全量 `parsed_messages` 初始化。
- 轮询间隔 3s；页面隐藏（`onPageHide`/Tab 切换）时暂停，恢复时按 position 续拉。
- 消息渲染：HOST 居中主持人卡片、三 Agent 分别以不同颜色头像与左/右气泡区分；支持按来源过滤与"仅看主持人"。

### 10.4 WebView 报告渲染

- 优先 `webController.loadUrl(`${baseUrl}/api/report/result/${taskId}`)`：服务端直接返回 `text/html`，页面内相对资源（图片/图表 SVG 内嵌）正常。
- 备选 `loadData(htmlContent, 'text/html', 'UTF-8')`：来自 `/result/{taskId}/json` 的 `html_content`，离线缓存场景使用。
- Web 组件配置：`javaScriptAccess(true)`、`domStorageAccess(true)`、缩放允许、`mediaPlaybackGesture`（报告内视频）。
- 报告打开前的**本地缓存**：保存 HTML 到沙箱 `files/reports/{taskId}.html`，断网可回看（历史列表加载缓存）。
- 注意：报告可能包含服务端外链资源，页面加载依赖网络；`onErrorReceive` 展示加载失败引导。

### 10.5 导出下载（ReportExporter）

| 类型 | 接口 | 保存方式 |
|------|------|----------|
| HTML | `GET /api/report/download/{taskId}` | 下载流 → 沙箱缓存 → `DocumentViewPicker.save()` 选目录 |
| Markdown | `GET /api/report/export/md/{taskId}` | 同上 |
| PDF | `GET /api/report/export/pdf/{taskId}` | 同上（服务端需安装 Pango；失败给出提示与报告页截图替代方案） |

- 下载使用 `http` 请求 + `response.receiveMessage`（文件大时流式写入 `@ohos.file.fs`）。
- 保存用 `picker.DocumentViewPicker().save()`，`documentSaveOptions` 指定 `newFileNames` 与 `fileSuffixChoices`。
- 保存结果回调里更新历史记录 `savedAt` 与文件路径，供"已保存"标识。

### 10.6 状态管理方案（V2 + AppStorage）

- 全局：`PersistentStorage.persistProp('serverConfigs', ...)` 管理多配置；`@StorageLink('currentServer')` 在页面间共享当前连接。
- ViewModel：`@ObservedV2 class AnalysisViewModel { @Trace runningTask: ReportTask; @Trace agents: Map<string, EngineStatus>; }`，页面 `@Consumer(AnalysisVM)` 订阅。
- SSE 事件在 Service 层回调 → ViewModel 更新 `@Trace` 属性 → 触发 UI 刷新。
- 列表性能：论坛/日志流使用 `LazyForEach` + `@Reusable` 列表项；日志行超过阈值(如 500)时截断头部。

### 10.7 时序：报告生成进度页

```
ReportViewModel                      SseClient                       服务端
     │  submit()                        │                              │
     ├─ POST /api/report/generate ──────▶                              │
     │ ◀──── {task_id, stream_url} ──────┤                              │
     ├─ connect(stream_url) ─────────────▶  GET /stream/{task_id}      │
     │ ◀─ dataReceive chunks ──────────────── (SSE 帧) ──────────────── │
     │     帧解析 → ReportEvent          │                              │
     │  type=progress → progress@Trace  │                              │
     │  type=log → 追加日志流            │                              │
     │  type=stage → 阶段文案            │                              │
     │  type=completed → 停止流          │                              │
     └─ onTerminal → 跳报告查看页        │                              │
```

---

## 11. 工程目录结构

```
BettaFishHarmonyOS/
├── AppScope/
│   ├── app.json5                        # bundleName: com.example.bettafish
│   └── resources/base/element/string.json, media/
├── entry/
│   ├── build-profile.json5              # compileSdk 6.1.1(24), target 6.1.1(24)
│   ├── hvigorfile.ts
│   ├── oh-package.json5
│   └── src/main/
│       ├── module.json5                 # 权限 INTERNET + network_security_config 引用
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets
│       │   ├── pages/
│       │   │   ├── MainTabPage.ets
│       │   │   ├── AnalysisPage.ets
│       │   │   ├── AnalysisProgressPage.ets
│       │   │   ├── ForumPage.ets
│       │   │   ├── ReportListPage.ets
│       │   │   ├── ReportViewPage.ets
│       │   │   ├── TemplatePickerPage.ets
│       │   │   ├── SystemManagePage.ets
│       │   │   ├── ServerConfigPage.ets
│       │   │   ├── SettingsPage.ets
│       │   │   └── AboutPage.ets
│       │   ├── components/
│       │   │   ├── EngineStatusCard.ets
│       │   │   ├── ForumMessageItem.ets
│       │   │   ├── ReportTaskItem.ets
│       │   │   ├── LogLineItem.ets
│       │   │   └── ConnectionStateBar.ets
│       │   ├── viewmodel/
│       │   │   ├── AnalysisViewModel.ets
│       │   │   ├── ForumViewModel.ets
│       │   │   ├── ReportViewModel.ets
│       │   │   ├── SystemViewModel.ets
│       │   │   └── ServerConfigViewModel.ets
│       │   ├── services/
│       │   │   ├── ApiClient.ets
│       │   │   ├── SseClient.ets
│       │   │   ├── ForumPoller.ets
│       │   │   ├── ReportExporter.ets
│       │   │   ├── ConfigStore.ets
│       │   │   └── ConnectionProbe.ets
│       │   ├── models/
│       │   │   └── Models.ets          # 第9章全部 interface
│       │   └── common/
│       │       ├── Constants.ets       # API 路径常量、错误码
│       │       ├── Logger.ets
│       │       └── TimeUtils.ets
│       └── resources/
│           ├── base/profile/main_pages.json
│           ├── base/profile/network_security_config.json
│           ├── base/element/string.json, color.json, float.json
│           └── base/media/ (图标)
```

---

## 12. 异常与容错设计

| 场景 | 处理策略 |
|------|----------|
| 服务器不可达 | 连接态 UI 显示"未连接"，提供一键重试与跳转配置；不阻塞其他页面 |
| SSE 断流 | Last-Event-ID 重连 + 指数退避；3 次失败降级轮询 progress |
| 分析请求无运行引擎 | `/api/search` 返回"没有运行中的应用" → 引导一键启动系统 |
| 报告输入未就绪 | `/api/report/generate` 返回 `missing_files[]` → 提示去论坛页等待并轮询 `/api/report/status` |
| 任务已在运行 | generate 返回 400 + current_task → 提示"已有任务进行中"，支持跳转监听 |
| 终态但页面丢失 | 历史列表依据本地 ReportHistoryItem 重新拉 progress/result |
| 导出 PDF 失败 | 提示服务端依赖缺失（Pango），给出 MD/HTML 备选导出 |
| 超时/取消 | 网络层统一超时；`cancel` 接口 + 本地清理 SSE |
| 配置格式非法 | 表单校验（host 必填、port 1-65535、URL 组装合法性） |
| 明文 HTTP 被拦截 | 网络安全配置已放行 cleartext；HTTPS 自签证书场景提示导入证书到系统信任区（文档附录说明） |

---

## 13. 安全与隐私设计

- **不存储任何密钥**：App 只保存服务器地址与用户偏好；服务端 API 密钥管理仍在服务端 Web 端完成（或经 `/api/config` 由用户在 App 内显式操作）。
- **本地数据**：Preferences 中服务器配置仅本机可读；报告缓存仅在沙箱 `files/`。
- **传输安全**：默认提示用户优先 HTTPS；提供网络安全配置放行明文（局域网自部署场景必需）。
- **日志脱敏**：App 日志不打印 host 完整地址、不打印请求体中的敏感字段。
- **权限最小化**：仅申请 `ohos.permission.INTERNET`，不申请存储读写全局权限（文件保存走系统 Picker）。
- **合规**：App 内声明"本应用仅连接用户自部署服务，数据由用户掌控"。

---

## 14. 开发里程碑

| 阶段 | 里程碑 | 交付内容 |
|------|--------|----------|
| M1 | 工程骨架 | DevEco 工程创建（SDK 6.1.1(24)）、导航框架、自适应布局骨架、连接配置页 + 持久化 |
| M2 | 服务层 | ApiClient、ConnectionProbe、系统状态/引擎状态页、系统启动流程 |
| M3 | 分析链路 | 发起分析、论坛轮询与实况页、SSE 客户端、进度页 |
| M4 | 报告链路 | 报告生成/模板选择、WebView 查看、本地历史、导出（HTML/MD/PDF） |
| M5 | 打磨验收 | 系统管理页、日志查看、异常/容错全覆盖、多设备真机联调、上架材料 |

每个里程碑以"真机/模拟器（API 24）可演示"为完成标准。

---

## 15. 附录

### 15.1 工程关键配置示例

**entry/build-profile.json5（关键字段）**

```json5
{
  "app": {
    "products": [
      {
        "name": "default",
        "compatibleSdkVersion": "6.1.1(24)",
        "compileSdkVersion": "6.1.1(24)",
        "targetSdkVersion": "6.1.1(24)"
      }
    ]
  }
}
```

**module.json5（关键字段）**

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ],
    "metadata": [
      {
        "name": "network_security_config",
        "resource": "$profile:network_security_config"
      }
    ]
  }
}
```

### 15.2 部署提示（给用户）

- 确保 BettaFish Flask 主端口（默认 5000）对手机/平板可达：局域网直连、公网 IP、或反向代理均可。
- 若为公网 HTTP 部署，强烈建议前置 HTTPS 反代（Caddy/Nginx）以保护请求内容。
- SSE 需要流式 WSGI 支持，项目源码已启用 eventlet；Docker 部署按官方 README 即可。
- App 与 BettaFish 之间无需打通 8501-8503 端口（仅服务端内部调用）。

### 15.3 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| SSE 在部分代理/网络被缓存 | 进度不实时 | 服务端已设 `Cache-Control: no-cache`；客户端另有轮询兜底 |
| 服务端任务注册表仅保留最近 5 个任务 | 历史任务接口失效 | 客户端本地持久化历史（ReportHistoryItem），文件仍在服务端 final_reports |
| 报告 HTML 体积大 | WebView 加载慢 | 服务端返回即渲染，本地缓存后二次打开走本地文件 |
| 服务端无"报告列表"接口 | 报告管理弱 | 首版基于本机历史；后续可在服务端加 `GET /api/reports` 扩展（最小侵入） |
| 论坛日志为文件追加 | 高并发轮询压力 | 3s 间隔 + position 增量 + 页面可见时才轮询 |

### 15.4 后续增强（可选）

- WebSocket/Socket.IO 直连论坛（替代轮询）——需引入 engine.io 协议实现，收益有限暂缓。
- 推送通知：报告生成完成时本地通知提醒。
- 多语言（中/英）。
- 深色模式与主题换肤。
- 桌面/平板横屏专用布局（大屏看板模式）。

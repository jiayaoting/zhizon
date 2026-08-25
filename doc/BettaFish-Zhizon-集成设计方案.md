# 智子（Zhizon）集成 BettaFish（微舆）功能设计方案

> 版本：v1.1
> 目标应用：智子（HarmonyOS NEXT · API 24 · Stage 模型）
> 依据：《BettaFish_HarmonyOS_设计方案.md》（服务端对接契约以其为准）
> 状态：设计稿（未进入编码）

---

## 0. 决策确认记录（已确认）

| 决策项 | 结论 | 状态 |
|--------|------|------|
| 入口形态 | 新增第 5 个主 Tab「微舆」（MainNavKey.BettaFish） | ✅ 已确认 |
| 页面结构 | BettaFishPage Hub 内嵌 分析/论坛/报告 三 Tab + 独立子页（进度/报告查看/服务器配置/系统管理） | ✅ 已确认 |
| 数据存储 | RDB v17 新增 bettafish_servers / bettafish_history 两表（DB_VERSION 16→17） | ✅ 已确认 |

---

## 1. 背景与目标

BettaFish（微舆）是自部署的多 Agent 舆情分析系统（Flask 主端口 5000，无需改造服务端）。
用户已按《BettaFish_HarmonyOS_设计方案》验证过接口契约，现要求把该能力**集成进智子 App**，
而不是另起一个独立应用。

集成目标：

1. 在智子内提供完整的「连接配置 → 发起分析 → 论坛实况 → 报告生成 → 报告查看/导出 → 系统管理」闭环；
2. 最大化复用智子现有工程能力（HTTP/SSE、Web 组件、文件 Picker、RDB、主题、自适应布局、语音、实况窗）；
3. 与智子既有功能（AI 对话、资讯、我的页、设置）互相打通，而非孤立的新模块；
4. 一码多端：手机（底部 5 Tab）/ 平板 / 折叠屏 / 2in1 自动适配。

---

## 2. 现状盘点（智子可复用资产）

| 能力 | 智子现有实现 | 集成用途 |
|------|--------------|----------|
| HTTP 客户端 | service/LlmClient.ets（@kit.NetworkKit http，含超时/HTTP1.1/错误映射） | 新写 BettaFishApiClient 时沿用其写法与经验 |
| SSE 流式 | LlmClient 内私有 extractSseEvents / sseDataFromEvent（requestInStream + dataReceive） | 提取为共享 common/SseFrameParser.ets，供 BettaFishSseClient 复用 |
| Web 渲染 | pages/NewsDetail.ets / Chat.ets（@kit.ArkWeb webview） | 报告 HTML 查看页直接复用该模式 |
| 文件保存 | Chat.ets 备份导入导出（picker.DocumentViewPicker + @ohos.file.fs） | 报告 HTML/MD/PDF 导出 |
| 持久化 | service/DatabaseHelper.ets（RDB v16、CREATE TABLE IF NOT EXISTS、tableHasColumn 迁移） | 新增 bettafish_servers / bettafish_history 两表，DB_VERSION 16→17 |
| 设置项 | common/SettingModels.ets（SettingGroup/SettingItem/SettingActionId，数据驱动 + 搜索） | 设置页新增「微舆」分组 |
| 导航 | common/Navigation.ets（MainNavKey/PageKey/PAGE_REGISTRY）+ AppShell.ets（renderPage / routeDestination）+ main_pages.json | 新增第 5 个主 Tab 与子页路由 |
| 主题/自适应 | ThemeState（palette / isSm / isWideNav / isLandscape）+ GlassStyle + GridRow | 新页面全部走现有主题体系 |
| 语音输入 | service/SpeechService.ets | 分析需求输入支持语音 |
| 实况窗 | service/LiveViewService.ets | 分析/报告生成退后台时展示进度（增强项） |
| AI 对话 | Chat + ChatRepository + MarkdownConverter | 报告/分析摘要一键「发到 AI 对话」 |

差异点（相对独立版设计方案）：

- 智子已有 4 个主 Tab（资讯 / AI对话 / 游戏 / 我的），本方案新增第 5 个 Tab「微舆」；
- 智子用 RDB + DataRepository 风格持久化（非 Preferences），服务器配置与历史任务落 RDB 新表；
- 智子页面以 @ComponentV2 + @Local + 静态 Service 为主，不引入独立 ViewModel 框架，保持一致；
- 服务端明文 HTTP：需先验证现有 Ollama http 配置是否已放行（见 §10）。

---

## 3. 集成形态与信息架构

### 3.1 入口方案对比

| 方案 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| A. 新增第 5 个主 Tab「微舆」（推荐） | MainNavKey.BettaFish，底部导航/侧边栏各加一项 | 功能体量大（分析/论坛/报告/系统管理），独立 Tab 空间充足、闭环完整；与独立版设计文档的信息架构一致 | 底部 Tab 从 4 变 5，图标文字需精简（两字 Tab 可接受） |
| B. 「我的」页入口 + 路由子页 | Profile 新增分组入口，全部子页 router push | 对现有导航零侵入 | 层级深、无独立空间；分析/论坛实时性页面被折叠在子路由里体验差 |
| C. 并入「AI对话」Tab | 分析当作一种对话场景 | 交互轻量 | 与论坛实况、报告管理等强状态页面冲突，信息架构混乱 |

**结论：采用方案 A。** 手机底部 Tab 变为 5 个（资讯 / AI对话 / 游戏 / 微舆 / 我的），大屏侧边栏同理；
「设置 → 微舆」提供服务器配置/系统管理入口，形成双入口（Tab Hub 顶栏状态卡 + 设置分组）。

### 3.2 信息架构

微舆 Tab（BettaFishPage = Hub）
├── 顶栏：当前服务器状态卡（未配置→引导去配置；未连接→一键重连）
├── 内嵌 Tabs（手机为顶部横向 Tab，平板/折叠屏为左右分栏）
│   ├── ① 分析
│   │   ├── 系统/引擎状态摘要（Query / Media / Insight / Forum 四引擎灯）
│   │   ├── 对话式输入区（文本 + 语音 + 示例问题）
│   │   └── 提交 → BettaFishProgressPage（引擎工作状态 + 阶段日志 + 取消 + 生成报告）
│   ├── ② 论坛
│   │   └── Agent 论坛实况（HOST / QUERY / MEDIA / INSIGHT 消息流，来源过滤，3s 增量轮询）
│   └── ③ 报告
│       ├── 本机历史列表（状态徽标 + 打开/导出/删除）
│       └── → BettaFishReportViewPage（WebView 渲染 HTML + 导出 MD/PDF/HTML + 发到 AI 对话）
└── 设置入口（⚙）→ BettaFishServerConfigPage / BettaFishSystemPage

### 3.3 路由与页面清单

| 页面 | 形态 | 路由/注册 |
|------|------|-----------|
| BettaFishPage（Hub，含分析/论坛/报告内嵌页） | EMBEDDED | PageKey.BettaFish，mainPage(MainNavKey.BettaFish) |
| BettaFishProgressPage（分析进度 + SSE） | ROUTE | pages/BettaFishProgress |
| BettaFishReportViewPage（WebView 报告） | ROUTE | pages/BettaFishReportView |
| BettaFishServerConfigPage（多配置 + 测试连接） | ROUTE | pages/BettaFishServerConfig |
| BettaFishSystemPage（系统启停 + 引擎开关 + 日志） | ROUTE | pages/BettaFishSystem |

> 说明：分析/论坛/报告三块作为 Hub 内嵌 Tabs（保持实时状态常驻，切 Tab 不销毁连接状态）；
> 进度页、报告页、配置页、系统页按智子现有习惯用 AppNavigator.push('pages/…') 路由。

---

## 4. 总体架构与目录

### 4.1 分层

表现层（pages/ + components/）
  BettaFishPage(Hub) / BettaFishProgressPage / BettaFishReportViewPage
  BettaFishServerConfigPage / BettaFishSystemPage
  BettaConnectionBar / BettaEngineStatusCard / BettaForumMessageItem / BettaReportTaskItem
服务层（service/）
  BettaFishApiClient（HTTP+SSE 请求） / BettaFishSseClient（SSE+降级轮询）
  BettaFishForumPoller（增量轮询） / BettaFishExporter（导出） / BettaFishStore（RDB 持久化）
数据模型层（common/）
  BettaFishModels.ets（ServerConfig / EngineStatus / SystemStatus / ForumMessage /
                      ReportTask / ReportEvent / HistoryItem）
平台能力层
  @kit.NetworkKit(http) │ @kit.ArkWeb(Web) │ @kit.CoreFileKit(picker/fs) │ RDB v17
                              │ HTTP / SSE
                  自部署 BettaFish（Flask :5000，不改动服务端）

### 4.2 新增目录（落到现有 ets 树内）

entry/src/main/ets/
├── common/
│   ├── SseFrameParser.ets          # 共享 SSE 帧解析（LlmClient 亦可迁移复用）
│   └── BettaFishModels.ets
├── service/
│   ├── BettaFishApiClient.ets      # REST 请求封装 + baseUrl 注入
│   ├── BettaFishSseClient.ets      # SSE 流式 + Last-Event-ID 重连 + 轮询降级
│   ├── BettaFishForumPoller.ets    # 论坛增量轮询（position）
│   ├── BettaFishExporter.ets       # HTML/MD/PDF 下载 + DocumentViewPicker 保存
│   └── BettaFishStore.ets          # 服务器配置/历史任务/偏好（RDB 读写门面）
├── components/
│   ├── BettaConnectionBar.ets      # 连接状态条（未连接/已连接/测试中）
│   ├── BettaEngineStatusCard.ets   # 引擎状态灯卡片
│   ├── BettaForumMessageItem.ets   # 论坛消息气泡（按来源着色）
│   └── BettaReportTaskItem.ets     # 报告历史列表项
└── pages/
    ├── BettaFishPage.ets
    ├── BettaFishProgress.ets
    ├── BettaFishReportView.ets
    ├── BettaFishServerConfig.ets
    └── BettaFishSystem.ets

---

## 5. 数据设计

### 5.1 RDB 变更（DatabaseHelper.ets，DB_VERSION 16 → 17）

新增两张表（沿用 CREATE TABLE IF NOT EXISTS + tableHasColumn 迁移风格）：

~~~sql
CREATE TABLE IF NOT EXISTS bettafish_servers (
  id TEXT PRIMARY KEY,            -- generateId('betta')
  name TEXT NOT NULL,
  scheme TEXT NOT NULL,           -- http | https
  host TEXT NOT NULL,             -- IP 或域名
  port INTEGER NOT NULL,
  base_path TEXT DEFAULT '',
  timeout_sec INTEGER DEFAULT 10,
  is_current INTEGER DEFAULT 0,
  forum_position INTEGER DEFAULT 0,   -- 论坛增量轮询断点（按服务器保存）
  created_at INTEGER,
  updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS bettafish_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT NOT NULL,
  query TEXT,
  status TEXT,                    -- pending|running|completed|error|cancelled
  progress INTEGER DEFAULT 0,
  base_url TEXT,                  -- 生成时所属服务器，用于回看
  server_id TEXT,
  created_at INTEGER,             -- epoch ms
  updated_at INTEGER,
  saved_at INTEGER,               -- 最近一次导出时间
  local_html_path TEXT DEFAULT '',-- 沙箱缓存 files/bettafish/{taskId}.html
  local_md_path TEXT DEFAULT '',
  local_pdf_path TEXT DEFAULT ''
);
~~~

设置项（沿用 settings 表 + DataRepository.getSetting/setSetting 风格，或收敛进 BettaFishStore）：

- bettafish_current_server_id：当前激活配置
- bettafish_auto_start：提交分析前系统未启动时是否自动一键启动（默认 true）
- bettafish_auto_generate：引擎就绪后是否自动生成报告（默认 false）
- bettafish_template：默认报告模板名

### 5.2 数据模型（common/BettaFishModels.ets）

与独立版设计文档 §9 对齐，ArkTS 显式 interface/class、禁用裸 any：

~~~typescript
export class BettaServerConfig {
  id: string = '';
  name: string = '默认服务器';
  scheme: string = 'http';          // 'http' | 'https'
  host: string = '';
  port: number = 5000;
  basePath: string = '';
  timeoutSec: number = 10;
  isCurrent: boolean = false;
  forumPosition: number = 0;
}

export class BettaEngineStatus {
  appName: string = '';             // insight | media | query | forum
  status: string = 'stopped';       // running | stopped | starting
  port: number = 0;
  outputLines: number = 0;
}

export class BettaSystemStatus {
  started: boolean = false;
  starting: boolean = false;
}

export class BettaForumMessage {
  type: string = 'agent';           // host | agent | raw
  sender: string = '';
  content: string = '';
  timestamp: string = '';
  source: string = '';              // HOST | QUERY | MEDIA | INSIGHT | RAW
}

export class BettaReportTask {
  taskId: string = '';
  query: string = '';
  status: string = 'pending';       // pending|running|completed|error|cancelled
  progress: number = 0;
  errorMessage: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  hasResult: boolean = false;
  reportFileReady: boolean = false;
  reportFileName: string = '';
  reportFilePath: string = '';
  markdownFileReady: boolean = false;
  markdownFileName: string = '';
  markdownFilePath: string = '';
}

export class BettaReportEvent {
  id: string = '';                  // 服务端帧 id（可能是 'hb-...'，字符串化存储）
  type: string = '';                // status|progress|stage|log|warning|heartbeat|completed|error|cancelled
  taskId: string = '';
  timestamp: string = '';
  payload: Record<string, Object> = {};   // 读取时做类型收窄
}

export class BettaHistoryItem {
  taskId: string = '';
  query: string = '';
  status: string = '';
  progress: number = 0;
  baseUrl: string = '';
  serverId: string = '';
  createdAt: number = 0;
  savedAt: number = 0;
  localHtmlPath: string = '';
  localMdPath: string = '';
  localPdfPath: string = '';
}
~~~

---

## 6. 服务层设计

### 6.1 BettaFishApiClient

- 静态方法 + BettaStore.getCurrentServer() 注入 baseUrl：scheme://host:port + basePath；
- request<T>(method, path, body?, timeout?)：http.createHttp()，JSON 头，HTTP 1.1、usingCache: false
  （沿用 LlmClient 的经验，规避 netstack HTTP/2 连接复用缺陷）；
- 统一结果类型 BettaApiResult<T>（ok / data / code / message），错误码映射：
  SERVER_UNREACHABLE / TIMEOUT / NOT_BETTAFISH / TASK_BUSY / ENGINE_NOT_READY；
- 覆盖接口（对应设计文档 §5.2 清单，# 为文档编号）：

| 方法 | 接口 |
|------|------|
| systemStatus / systemStart / systemShutdown | #1 #2 #3 |
| engineStatus（四引擎） | #4 |
| engineOutput(appName) | #5 |
| submitSearch(query) | #6 |
| forumLogAll / forumLogHistory(position, maxLines) | #7 #8 |
| reportStatus / reportGenerate / reportProgress / reportCancel / reportTemplates | #11 #12 #13 #18 #19 |
| reportResultJson / reportDownload / reportExportMd / reportExportPdf | #16 #17 #20 #21 |
| configGet / configSet（F16，白名单字段，列入二期） | #9 #10 |

### 6.2 BettaFishSseClient（报告进度流）

- 复用 LlmClient 的流式经验：requestInStream + on('dataReceive') + dataEnd 兜底超时；
- 帧解析抽到 common/SseFrameParser.ets（split 空行 + id/event/data 累积，心跳 hb-... 字符串化，
  注释行忽略）——首版可先复制 LlmClient 实现，稳定后再让 LlmClient 也迁移过去；
- 断线重连：指数退避 1s/2s/4s/8s（上限 30s），重连携带 Last-Event-ID: <最后成功事件 id>；
- 心跳看门狗：45s 无任何帧判定假死触发重连；
- 降级策略：连续失败 ≥3 次 → 切 GET /api/report/progress/{taskId} 每 2s 轮询，终态即停；
- 终态判定：事件 type ∈ {completed, error, cancelled} 或 payload.status ∈ 终态集合，随后 destroy()。

### 6.3 BettaFishForumPoller

- 首次全量 GET /api/forum/log，之后 POST /api/forum/log/history {position, max_lines:200} 增量续拉；
  position 持久化到 bettafish_servers.forum_position（按服务器隔离）；
- 轮询间隔 3s；页面隐藏/Tab 切换时暂停（onPageHide），恢复时按 position 续拉；
- 解析失败的原始行归为 raw 消息，不丢失。

### 6.4 BettaFishExporter

- 下载：http 请求 + response.receiveMessage 流式写入沙箱 files/bettafish/{taskId}.xxx；
- 保存：picker.DocumentViewPicker().save() + documentSaveOptions（沿用 Chat.ets 导入导出模式）；
- PDF 失败（服务端缺 Pango）提示并给出 MD/HTML 兜底；
- 保存成功后回写 bettafish_history 的 saved_at 与本地路径。

### 6.5 BettaFishStore

- listServers / saveServer / deleteServer / setCurrent / getCurrent；
- upsertHistory / listHistory / updateHistoryStatus / deleteHistory；
- 读偏好 getSetting('bettafish_*', default) 风格与 DataRepository 一致。

---

## 7. 关键时序

主流程（分析 → 报告）：

~~~
[BettaFishPage-分析] 输入 query
   │ 若系统未启动且 bettafish_auto_start=true → POST /api/system/start
   │ POST /api/search {query}
   ▼
[BettaFishProgressPage] 三 Agent 并行研究
   │ 轮询 GET /api/status（引擎灯）+ ForumPoller 增量刷论坛
   │ 引擎就绪（GET /api/report/status → engines_ready=true）
   │ 点「生成报告」（或 bettafish_auto_generate 自动）
   ▼
POST /api/report/generate {query, custom_template} → task_id
   │ BettaFishSseClient.connect(GET /api/report/stream/{task_id})
   │   status/progress/stage/log/warning → 进度条 + 阶段文案 + 日志流
   │   断线 → Last-Event-ID 重连 → 失败降级轮询 progress
   ▼
终态 completed → 写 bettafish_history
   ▼
[BettaFishReportViewPage] Web 组件 loadUrl(baseUrl/api/report/result/{taskId})
   │ 本地缓存 files/bettafish/{taskId}.html（离线可回看）
   ▼
导出 HTML/MD/PDF（DocumentViewPicker）｜ 分享 ｜ 发到 AI 对话
~~~

连接配置：填 scheme/host/port → 测试连接（GET /api/system/status）→ 保存（RDB）→ Hub 状态卡刷新。

---

## 8. 页面设计要点

| 页面 | 核心元素 | 数据来源 |
|------|----------|----------|
| BettaFishPage | 连接状态卡 + 内嵌 Tabs（分析/论坛/报告） | BettaFishStore + BettaFishApiClient |
| 分析视图（Hub 内嵌） | 四引擎灯、对话输入（含语音）、示例问题、提交 | systemStatus / engineStatus / submitSearch |
| BettaFishProgressPage | 进度条、阶段文案、Agent 状态、日志流（LazyForEach）、取消、生成报告 | BettaFishSseClient + ApiClient |
| 论坛视图（Hub 内嵌） | 消息列表（LazyForEach）、来源过滤、仅看主持人 | BettaFishForumPoller |
| 报告视图（Hub 内嵌） | 历史列表（状态徽标/打开/导出/删除） | BettaFishStore |
| BettaFishReportViewPage | Web 组件（javaScriptAccess + domStorageAccess）、导出菜单、发到 AI 对话 | reportResult + BettaFishExporter |
| BettaFishServerConfigPage | 配置表单、多配置列表、测试连接、切换/删除 | BettaFishStore |
| BettaFishSystemPage | 系统启动/关停、四引擎启停、输出日志查看、报告引擎日志 | ApiClient |

全部页面复用 ThemeState.palette、GlassStyle 卡片与 TopBar；
列表类（论坛消息、历史、日志）用 LazyForEach（智子已有 LazyDataSource 可复用）。

---

## 9. 自适应布局

- 断点沿用智子现有 ThemeState.isSm/isMd/isLg/isWideNav，不另建断点体系；
- Hub：sm 单列 + 顶部内嵌 Tab；md/lg 采用 GridRow/GridCol 双列（左侧论坛/分析，右侧报告）或侧边栏 + 内容区；
- 手机底部导航 5 Tab（资讯 / AI对话 / 游戏 / 微舆 / 我的），大屏 SideNav 同源 AppConstants.navItems；
- 报告 WebView 宽度自适应容器，缩放跟随系统。

---

## 10. 安全与权限

1. ohos.permission.INTERNET 智子已声明（module.json5），无需新增权限；
2. 明文 HTTP：BettaFish 通常部署在局域网。先验证智子现有 Ollama http:// 配置是否已可直连；
   若默认策略已放行则跳过，否则新增 resources/base/profile/network_security_config.json
   （cleartextTrafficPermitted: true）并在 module.json5 metadata 引用；
3. 不缓存任何 API 密钥（服务端密钥管理仍在服务端 Web 端完成）；
4. 日志脱敏：hilog 不打印完整 host 地址；配置切换时不上报明文内容；
5. 仅服务器地址、历史任务、本地报告缓存落盘（沙箱 files/），走系统 Picker 导出。

---

## 11. 异常与容错

| 场景 | 处理 |
|------|------|
| 服务器不可达/超时 | 状态卡「未连接」+ 一键重试 + 跳转配置；不阻塞其他 Tab |
| SSE 断流 | Last-Event-ID 重连 + 指数退避；3 次失败降级轮询 progress |
| /api/search 无运行引擎 | 提示并引导一键启动（或按 bettafish_auto_start 自动执行） |
| generate 输入未就绪 | 返回 missing_files[] → 提示去论坛等待并轮询 report/status |
| 已有任务在跑 | generate 400 + current_task → 提示并跳转监听该任务 |
| 任务终态但页面丢失 | 历史列表依据 bettafish_history 重新拉 progress/result |
| 服务端只保留最近 5 个任务 | 客户端本地历史 + 沙箱 HTML 缓存保证回看 |
| PDF 导出失败（缺 Pango） | 提示并给 MD/HTML 兜底 |
| 分析/生成耗时长、切后台 | 返回前台后重连/续拉；增强：LiveViewService 实况窗显示进度 |

---

## 12. 与智子既有功能联动（特色增强）

- 发到 AI 对话：报告页「发到 AI 对话」把报告摘要/HTML 文本插入 Chat 会话，用现有 MarkdownConverter 渲染；
- 实况窗：报告生成进行中退后台，复用 LiveViewService 展示进度（有现成实现，改动小）；
- 语音输入：分析输入区复用 SpeechService 语音转文字；
- AI 调用记录：BettaFish 的提交/测试连接可接入 AiCallLogger（场景 bettafish），「我的」统一查看；
- 主题一致性：新页面全部使用现有 palette/GlassStyle，深色模式、字号档位、自定义背景自动生效；
- 设置搜索：「微舆」分组自动进入 Settings 搜索索引（SettingModels 数据驱动天然支持）。

---

## 13. 文件改动清单

### 13.1 修改现有文件

| 文件 | 改动 |
|------|------|
| entry/src/main/ets/common/Navigation.ets | 新增 MainNavKey.BettaFish、PageKey.BettaFish；PAGE_REGISTRY 增加 Hub EMBEDDED 项；isMainNavKey/mainPage/pageFromString 同步扩展；增加 BettaFish 子页路由参数类 |
| entry/src/main/ets/common/Constants.ets | AppConstants.navItems 增加 new NavItem(MainNavKey.BettaFish, '微舆', '🐟') |
| entry/src/main/ets/pages/AppShell.ets | imports + renderPage 增加 BettaFish Hub 分支 + routeDestination 增加 4 个子页分支 |
| entry/src/main/resources/base/profile/main_pages.json | 追加 4 个 BettaFish 子页路由 |
| entry/src/main/ets/common/SettingModels.ets | SettingActionId 增加 BETTA_SERVER = 19、BETTA_SYSTEM = 20 等 |
| entry/src/main/ets/pages/Settings.ets | 新增「微舆」分组（服务器配置 / 系统管理 / 清空本地历史）与 onAction 分支 |
| entry/src/main/ets/pages/Profile.ets | （可选）「AI」分组加一行「微舆舆情分析」直达 BettaFish Tab |
| entry/src/main/ets/service/DatabaseHelper.ets | DB_VERSION 16→17；新增两张表的 CREATE SQL 并注册；沿用 tableHasColumn 迁移模式 |
| entry/src/main/module.json5 | （按 §10 判断）新增 network_security_config metadata |

### 13.2 新增文件

common/：SseFrameParser.ets、BettaFishModels.ets
service/：BettaFishApiClient.ets、BettaFishSseClient.ets、BettaFishForumPoller.ets、BettaFishExporter.ets、BettaFishStore.ets
components/：BettaConnectionBar.ets、BettaEngineStatusCard.ets、BettaForumMessageItem.ets、BettaReportTaskItem.ets
pages/：BettaFishPage.ets、BettaFishProgress.ets、BettaFishReportView.ets、BettaFishServerConfig.ets、BettaFishSystem.ets

---

## 14. 里程碑与验收

| 阶段 | 里程碑 | 交付 | 验收 |
|------|--------|------|------|
| M1 | 工程骨架 | 5th Tab、Hub 占位、路由注册、RDB v17 两表、ServerConfig 页（测试连接）、连接状态卡 | 手机/平板可配置并测试连接 BettaFish，重启后配置保留 |
| M2 | 服务层 + 系统管理 | BettaFishApiClient、系统状态/引擎状态、一键启动/关停、引擎启停、日志查看 | 系统管理页可完成启停闭环 |
| M3 | 分析链路 | 发起分析、论坛增量轮询与实况、SSE 进度页、取消 | 完整跑通 search → 论坛实况 → 引擎就绪 |
| M4 | 报告链路 | 生成报告、SSE 进度/阶段/日志、WebView 查看、本地历史、导出 HTML/MD/PDF、发到 AI 对话 | 报告全链路 + 断网回看历史 |
| M5 | 打磨验收 | 容错全覆盖（重连/降级/任务冲突）、自适应与主题、实况窗、真机联调 | API 24 真机可演示完整闭环 |

每个里程碑以「真机/模拟器（API 24）可演示」为完成标准，优先完成 M1 验证导航与 RDB 迁移无回归。

---

## 15. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 明文 HTTP 被默认拦截 | 局域网直连失败 | 先验证 Ollama http 现状；必要时加 network_security_config 放行 |
| SSE 经代理/网络被缓存 | 进度不实时 | 服务端 no-cache + 客户端轮询兜底 |
| 服务端任务注册表仅 5 条 | 历史不可回看 | 本地 bettafish_history + 沙箱 HTML 缓存 |
| 报告 HTML 体积大 | WebView 加载慢 | 首开即渲染 + 本地缓存二次直读 |
| 论坛日志文件追加、长连接 | 轮询压力/耗电 | 3s 间隔 + position 增量 + 页面隐藏暂停 |
| 5 Tab 底部导航拥挤 | 触达/可读性下降 | 图标 + 两字标签、isLandscape 时压缩高度（现有 FixedBottomNav 已自适应） |
| RDB 版本升级引入回归 | 旧数据异常 | 沿用 CREATE IF NOT EXISTS + tableHasColumn 迁移，M1 先做回归验证 |

---

## 附录 A：路由接线示例（Navigation.ets 增量）

~~~typescript
// MainNavKey 增加
BettaFish = 'BettaFish'

// PageKey 增加
BettaFish = 'BettaFish',
BettaFishProgress = 'BettaFishProgress',
BettaFishReportView = 'BettaFishReportView',
BettaFishServerConfig = 'BettaFishServerConfig',
BettaFishSystem = 'BettaFishSystem'

// PAGE_REGISTRY 增加
new PageRegistration(PageKey.BettaFish, MainNavKey.BettaFish, PageAvailability.EMBEDDED, 'pages/AppShell')

// mainPage(BettaFish) → PageKey.BettaFish；isMainNavKey 增加 BettaFish 分支
// pageFromString 增加 BettaFish 各 PageKey 分支
~~~

## 附录 B：SSE 帧解析复用建议

common/SseFrameParser.ets 提供 parse(buffer): { events, consumed }，
首版实现与 LlmClient 私有实现等价（兼容 \r\n 与 \n 分隔）；LlmClient 后续可平滑迁移，
避免两套解析逻辑漂移。

---

## 附录 C：M1 骨架落地记录（2026-08-25）

M1（第 5 个 Tab、Hub、路由、RDB v17、服务器配置页、连接状态卡）已落地，产物如下：

- 新增：common/BettaFishModels.ets、common/SseFrameParser.ets（M3 时引入）、
  service/BettaFishStore.ets、service/BettaFishApiClient.ets、
  components/BettaConnectionBar.ets、pages/BettaFishPage.ets、
  pages/BettaFishProgress.ets（占位）、pages/BettaFishReportView.ets（占位）、
  pages/BettaFishServerConfig.ets、pages/BettaFishSystem.ets（占位）
  （注意：路由文件名不带 Page 后缀，与 main_pages.json 的路由名一一对应，如 ChatConfig.ets 惯例）
- 修改：common/Navigation.ets（MainNavKey.BettaFish + PageKey + PAGE_REGISTRY + 路由参数类）、
  common/Constants.ets（navItems 第 5 项）、pages/AppShell.ets（renderPage/routeDestination/bettaRefreshToken）、
  resources/base/profile/main_pages.json、common/SettingModels.ets（BETTA_SERVER/BETTA_SYSTEM）、
  pages/Settings.ets（微舆分组）、service/DatabaseHelper.ets（DB_VERSION 16→17 两表）
- 待办：module.json5 明文 HTTP 放行（先验证 Ollama http 现状）、Profile「我的」页入口（可选）、
  M2 系统管理 / M3 分析链路 / M4 报告链路

---

## 附录 D：M2-M4 完整闭环落地记录

分析 → 论坛 → 报告生成 → 查看 → 导出的主链路已实现：

- 服务层：BettaFishApiClient（系统启停/引擎状态/发起分析/论坛全量+增量/报告生成+进度+取消/下载导出）、
  BettaFishSseClient（requestInStream + dataReceive 增量解析、Last-Event-ID 指数退避重连、
  3 次失败回调降级轮询）、common/SseFrameParser.ets（共享帧解析）
- 组件：BettaEngineStatusCard（引擎灯卡）、BettaForumMessageItem（按来源着色气泡）
- 页面：
  - BettaFishPage：分析 Tab（引擎状态 3s 刷新 + 输入 + 示例问题 + 自动启动系统后 POST /api/search）、
    论坛 Tab（全量拉取 + 3s 轮询 + 来源过滤）、报告 Tab（本地历史列表/打开/删除）
  - BettaFishProgress：引擎与报告状态轮询 → 生成报告 → SSE 进度/阶段/日志 → 终态弹窗 → 报告页；SSE 降级轮询 progress
  - BettaFishReportView：Web 组件渲染 /api/report/result/{taskId} + 复制链接 + 导出 HTML/MD/PDF（沙箱缓存 → DocumentViewPicker）
  - BettaFishSystem：系统启动/关停（二次确认）、四引擎状态、报告引擎状态与日志、引擎输出日志查看
- 报告历史：终态时 upsertHistory（bettafish_history），导出成功回写 saved_at 与本地路径

---

*本文档与《BettaFish_HarmonyOS_设计方案.md》配套使用：服务端接口契约、SSE 事件结构、导出接口等
以独立版文档 §5/§10 为准，本文档只描述智子工程内的集成落地方式。*

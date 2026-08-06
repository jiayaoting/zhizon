---
name: zhizon-ssh-full-implementation
overview: 为智子（HarmonyOS NEXT 纯血鸿蒙 App）实现完整的 SSH 功能：设备端直连（@ohos/libssh 三方库）与 Agent 模式并存，覆盖密码/密钥认证、ANSI 交互式终端、多会话标签页、SFTP 带进度传输、连接历史持久化、超时检测与自动重连、终端自适应。
design:
  styleKeywords:
    - 深色科技
    - 终端青绿
    - 高信息密度
    - 等宽字体
    - 响应式多栏
    - 状态色语义
  fontSystem:
    fontFamily: JetBrains Mono
    heading:
      size: 20px
      weight: 600
    subheading:
      size: 14px
      weight: 500
    body:
      size: 13px
      weight: 400
  colorSystem:
    primary:
      - "#00D9A3"
      - "#00F0B5"
    background:
      - "#0A0E1A"
      - "#131826"
      - "#000000"
    text:
      - "#E2E8F0"
      - "#94A3B8"
      - "#8B95A7"
    functional:
      - "#10B981"
      - "#F59E0B"
      - "#EF4444"
      - "#3B82F6"
todos:
  - id: setup-deps-db
    content: 接入 @ohos/libssh 依赖、补 module.json5 INTERNET 权限、DB v3 迁移（key_content 列 + password_enc 写入）、新增 CryptoHelper 与 DataRepository 凭据/历史方法
    status: completed
  - id: verify-libssh-api
    content: 用 [subagent:code-explorer] 核实 @ohos/libssh 包内 .d.ts 真实 API，输出签名清单供引擎实现
    status: completed
    dependencies:
      - setup-deps-db
  - id: rewrite-direct-engine
    content: 重写 DirectEngine：libssh 密码/密钥认证、PTY 交互、resize、SFTP 分块传输+进度、心跳与自动重连
    status: completed
    dependencies:
      - verify-libssh-api
  - id: upgrade-agent-engine
    content: 增强 AgentEngine 与 agent/main.go：WS 协议加 resize/认证参数，x/crypto/ssh+creack/pty 网关，SFTP 分块中转
    status: completed
    dependencies:
      - verify-libssh-api
  - id: terminal-interactive
    content: 实现 AnsiParser/TerminalBuffer/TerminalView 组件，重构 Terminal 页为多会话交互式终端（标签页、自适应、重连横幅）
    status: completed
    dependencies:
      - rewrite-direct-engine
      - upgrade-agent-engine
  - id: files-sftp
    content: 改造 Files 页接入真实 SFTP：服务器选择、目录导航、filePicker 上传/下载、传输进度队列
    status: completed
    dependencies:
      - rewrite-direct-engine
      - upgrade-agent-engine
  - id: server-form-history
    content: 实现 ServerForm 表单页（密码/密钥、PEM 粘贴+文件导入、直连/Agent 选择、测试连接）与服务器列表历史记录一键重连
    status: completed
    dependencies:
      - setup-deps-db
  - id: verify-integration
    content: 端到端联调：密码/密钥连接、交互终端 ANSI 渲染、多会话切换、SFTP 传输、超时自动重连、尺寸自适应验证
    status: completed
    dependencies:
      - terminal-interactive
      - files-sftp
      - server-form-history
---

## 用户需求

纯血鸿蒙 App 的 SSH 功能从"界面展示"升级为完整可用，需实现：

1. **SSH 连接与认证**：支持密码、私钥（PEM 粘贴 / 文件选择器导入）两种认证方式，连接本地持久化存储
2. **交互式终端**：命令输入 + 实时输出，支持常见 ANSI 转义序列（SGR 颜色/样式）渲染，多会话标签页同时维护多个连接
3. **SFTP 文件传输**：真实列目录/上传/下载，含进度显示
4. **可靠性**：连接超时检测、自动重连、重连状态提示、终端尺寸自适应
5. **性能**：所有网络操作异步执行，不阻塞 UI

## 需求澄清（用户已确认）

- **连接模式**：两者结合 —— 直连模式用 ohpm 三方库 `@ohos/libssh` 在设备端真实 SSH；Agent 模式保留并增强（PTY 交互终端）
- **私钥管理**：粘贴 PEM 内容 + 文件选择器导入两种方式均支持，加密持久化到应用沙箱
- **改造范围**：保留并兼容现有 Agent 模式

## 核心功能

- 服务器添加/编辑表单（密码/密钥认证、直连/Agent 模式选择、测试连接）
- 交互式终端（ANSI 渲染、多会话标签页、窗口自适应、自动重连横幅）
- SFTP 双栏文件管理（目录导航、上传/下载进度队列）
- 历史记录查看与一键快速重连

## 技术选型

- 沿用现有技术栈：HarmonyOS 6.1.1 (API 24) + ArkTS 严格模式 + ArkUI 声明式 + Stage 模型
- 新增依赖：`@ohos/libssh`（ohpm，基于 libssh-0.11.1 的 NAPI 封装，提供密码/密钥认证、PTY shell、SFTP 上传下载/进度回调）
- Agent 侧（Go）：`golang.org/x/crypto/ssh`（SSH 客户端网关）+ `github.com/creack/pty`（PTY 交互终端）
- 加密存储：`@kit.CryptoArchitectureKit`（AES-256-GCM 加密密码与私钥内容）
- 并发：异步 Promise 天然不阻塞 UI；libssh 阻塞式 NAPI 调用放入 `@ohos.taskpool`/Worker 承载会话生命周期

## 总体架构

保持"直连 + Agent"双模架构（与 `doc/DESIGN.md` v2.0.0 一致），改造点：

```mermaid
graph TD
  A[Terminal 页 多会话标签页] --> B[SshService 门面<br/>Map&lt;sessionId, engine&gt;]
  A --> C[AnsiParser<br/>SGR/CSI 解析]
  B --> D[DirectEngine<br/>@ohos/libssh 真实 SSH]
  B --> E[AgentEngine<br/>WebSocket + HTTP]
  D --> F[libssh NAPI: 认证/PTY/SFTP]
  E --> G[agent/main.go 增强<br/>x/crypto/ssh 网关 + creack/pty]
  H[Files 页 SFTP] --> B
  I[Servers 页 表单/历史] --> J[DataRepository<br/>加密密钥 + 连接历史]
```

## 核心设计决策

1. **`@ohos/libssh` 集成前置验证**：ohpm install 后必须先以包内 `.d.ts` 为准核对实际 API（README 摘要仅为参考），确认 `SshClient.connect/openShell/onData/resizeSsh`、`SftpSession.upload/download/progress` 等真实签名；若部分 API 与摘要不符，按实际能力裁剪实现并保留降级路径
2. **SshEngine 接口扩展**（策略模式不变）：新增 `resizeTerminal(cols, rows)`、`onConnectionEvent(cb)`（connected/disconnected/error/reconnecting）、传输进度回调；`ServerConfig` 增加 `password`/`privateKeyContent` 字段
3. **DirectEngine 重写**：删除 TCP 端口探测降级逻辑，改为 libssh 真实会话（密码/密钥认证 → PTY shell → onData 流 → 输入写入 → resize；SFTP 列目录/分块上传下载 + 进度）；keepalive 心跳 + 断开检测 + 自动重连（读取 settings 开关与超时）
4. **AgentEngine 增强**：WS 协议新增 `resize`、认证参数消息；文件传输保持 HTTP 接口但改为分块传输
5. **agent/main.go 增强**：新增 SSH 网关模式 —— 客户端经 WS 发送连接参数（密码/密钥），Agent 侧用 `x/crypto/ssh` 建连 + `creack/pty` 开启 PTY shell，双向转发字节流，支持 resize 消息；SFTP 中转走分块 + 进度
6. **数据层 v3 迁移**：`DB_VERSION` 升至 3，servers 表新增 `key_content` 列（私钥内容）；补齐 `password_enc` 写入（AES-256-GCM 加密，密钥由设备派生并持久化）；`DataRepository` 增加 `saveCredentials`/`getPassword`/`getKeyContent` 方法
7. **ANSI 渲染**：自研轻量 `AnsiParser` —— 流式缓冲处理 UTF-8 多字节分片；SGR 解析为前景/背景色（16 色/256 色映射到主题色板）与粗体/斜体/下划线样式；CSI 光标控制降级为行追加模式；输出为 `AnsiSegment[]`（text + fg/bg/bold/italic/underline），由 ArkUI `Text` + `Span` 子组件分段着色渲染
8. **多会话**：`SshService` 维护 `Map<sessionId, {engine, server, buffer}>`；终端页用自定义标签栏（或 `Tabs`）切换，后台会话保持连接；页面销毁仅断开当前页管理、会话由服务层持有
9. **终端尺寸自适应**：终端可视区 `onAreaChange` 计算 cols/rows（按字体宽高估算），变化时调用 `resizeTerminal`；直连走 libssh resize API，Agent 走 WS resize 消息
10. **线程模型**：网络与 libssh 调用全部经异步封装（Worker 承载 libssh 会话生命周期 + 消息回传字节流），UI 只消费回调数据，满足"不阻塞 UI"

## 实施注意

- **性能**：终端输出流做批量追加（帧合并 + 节流，避免每字节触发重渲染）；SFTP 分块读写（如 64KB/块）避免大文件 OOM；ANSI 解析 O(n) 单遍扫描
- **日志**：沿用 `console.info/error` 分级；不打印密码/私钥内容、Agent token 等敏感字段
- **爆炸半径控制**：`DatabaseHelper` v3 迁移沿用"安全执行、列已存在忽略"模式；`ServerConfig`/`SshEngine` 接口扩展保持向后兼容（新增字段可选、新方法有默认实现或由门面兜底）；旧 Agent 协议路径保留
- **安全**：密码/私钥仅存加密密文（`key_content`/`password_enc` 列），内存中用完即清；日志与错误消息脱敏

## 目录结构

```
entry/src/main/ets/
├── model/Models.ets                     # [MODIFY] TerminalSession 扩展为可用模型（serverId/engine/buffer 引用）；新增 KeyAuthType 等
├── common/
│   ├── Theme.ets                        # [MODIFY] 新增 ANSI 16/256 色板映射、终端配色常量
│   └── CryptoHelper.ets                 # [NEW] AES-256-GCM 加密/解密（CryptoArchitectureKit），密钥派生与持久化
├── service/
│   ├── SshService.ets                   # [MODIFY] ServerConfig 增 password/privateKeyContent；SshEngine 增 resize/事件/进度接口；SshService 增多会话注册、reconnect、事件分发
│   ├── DirectEngine.ets                 # [NEW] 从 SshService.ets 拆出：libssh 真实 SSH 引擎（认证/PTY/SFTP/心跳/重连），Worker 承载会话
│   ├── AgentEngine.ets                  # [MODIFY] 从 SshService.ets 拆出并增强：WS 协议加 resize/认证参数，文件分块传输
│   ├── DatabaseHelper.ets               # [MODIFY] DB_VERSION=3；servers 表新增 key_content 列；读写 password_enc/key_content；getServers 映射新列
│   └── DataRepository.ets               # [MODIFY] 新增 savePassword/getPassword/saveKeyContent/getKeyContent、getConnectionHistory（按 lastConnected 排序）
├── terminal/
│   ├── AnsiParser.ets                   # [NEW] 流式 ANSI 解析器：UTF-8 缓冲、SGR→AnsiSegment、CSI 降级
│   ├── TerminalBuffer.ets               # [NEW] 行模型缓冲区：行数组 + 样式段、滚动上限（settings scrollLines）、光标行管理
│   └── TerminalView.ets                 # [NEW] 可复用终端组件：Text+Span 渲染 AnsiSegment、触摸键盘 Ctrl+C 等、onAreaChange 计算尺寸、输入行
├── pages/
│   ├── Terminal.ets                     # [MODIFY] 重构为多会话容器：标签栏 + TerminalView × N、重连状态横幅、会话管理
│   ├── Files.ets                        # [MODIFY] 接入真实 SFTP：服务器选择、远程目录导航、filePicker 上传、保存下载、进度队列
│   ├── Servers.ets                      # [MODIFY] 历史记录分组展示、卡片快捷"一键重连"；添加按钮跳转表单
│   ├── ServerForm.ets                   # [NEW] 添加/编辑表单：认证方式切换、密码/私钥（TextArea 粘贴 + DocumentViewPicker 导入）、连接模式选择、测试连接
│   └── Settings.ets                     # [MODIFY] 常规组接入真实持久化与跳转（超时/自动重连已有，补密钥管理入口）
├── agent/main.go                        # [MODIFY] 新增 SSH 网关：/ws/ssh 或扩展 /ws/terminal 协议（x/crypto/ssh 认证、creack/pty、resize 消息、SFTP 分块中转）
└── module.json5                         # [MODIFY] 补充 INTERNET 网络权限
entry/oh-package.json5                   # [MODIFY] dependencies 增加 @ohos/libssh
doc/DESIGN.md                            # [MODIFY] 更新技术选型表（libssh 由"规划"改为"已实现"）、补充 v3 数据模型与 WS 协议说明
```

## 关键代码结构

```typescript
// SshEngine 扩展接口（保持向后兼容）
export interface SshEngine {
  connect(config: ServerConfig): Promise<boolean>;
  disconnect(): Promise<void>;
  isConnected(): boolean;
  exec(command: string, timeout?: number): Promise<string>;
  openTerminal(cols?: number, rows?: number): Promise<void>;
  onTerminalData(callback: (data: string) => void): void;
  sendTerminalInput(data: string): void;
  resizeTerminal(cols: number, rows: number): void;         // 新增
  onConnectionEvent(callback: (event: ConnEvent) => void): void; // 新增
  closeTerminal(): void;
  getMetrics(): Promise<ServerMetrics>;
  listFiles(path: string): Promise<FileItem[]>;
  uploadFile(localPath: string, remotePath: string, onProgress?: (p: TransferProgress) => void): Promise<void>;
  downloadFile(remotePath: string, localPath: string, onProgress?: (p: TransferProgress) => void): Promise<void>;
}

export interface ConnEvent { type: 'connected' | 'disconnected' | 'error' | 'reconnecting'; message: string; }
export interface TransferProgress { transferred: number; total: number; percent: number; }

// ANSI 渲染段
export interface AnsiSegment {
  text: string;
  fg?: string; bg?: string;
  bold?: boolean; italic?: boolean; underline?: boolean;
}
```

## 设计风格

延续现有深色终端科技风（AppTheme：背景 #0A0E1A、主色 #00D9A3 青绿），终端区纯黑底、等宽字体，营造专业终端质感。整体为"深色科技 / 数据监控 / 终端工具"风格，交互聚焦、信息密度高、响应式自适应。

## 页面规划（核心 4 页）

### 1. 终端页（多会话重构）

- 顶部 TopBar（服务器名 + 连接状态点）
- 会话标签栏：横向可滚动 Tab（会话名 + 关闭按钮），当前会话主色高亮下划线；右侧"+"新建会话
- 重连状态横幅：断开/重连中时在标签栏下显示（警告色），成功后自动消失
- 终端内容区：纯黑背景，Text+Span 富文本渲染 ANSI 颜色；输出区 + 输入行（mono 字体、青绿光标）
- 底部快捷命令横向滚动条 + 输入框 + 发送按钮（沿用现有布局）
- 多会话自适应断点（isSm/isMd/isLg）控制标签栏密度与输入区宽度

### 2. 文件管理页（SFTP 接入）

- 顶部 TopBar + 服务器选择下拉（当前会话服务器，直连/Agent 均支持）
- 远程目录面包屑导航（可点击跳转）
- 文件列表行：图标 + 名称 + 修改时间 + 大小 + 权限位，目录双击进入
- 底部传输队列：进度条 + 速度 + 状态徽章（running/success/failed），传输完成自动移除/置灰
- 上传用系统文件选择器（DocumentViewPicker），下载保存至用户选择的沙箱目录

### 3. 服务器列表页（历史 + 快捷重连）

- 分组筛选标签（沿用）+ 卡片布局
- 卡片底部"连接"按钮升级为"一键重连"（读取加密凭据直接连）
- 新增"最近连接"区块：按 lastConnected 排序展示最近 5 台，点击直接进入终端
- "添加服务器"按钮跳转表单页

### 4. 添加/编辑服务器表单页（新建）

- 分段控件：密码认证 / 密钥认证 切换
- 密钥认证区：TextArea 粘贴 PEM + "从文件导入"按钮（DocumentViewPicker），导入后显示指纹摘要
- 连接模式：Agent（推荐）/ 直连 分段选择
- 表单校验（主机/用户名/端口）+"测试连接"按钮 + 保存

## Agent 扩展

### SubAgent

- **code-explorer**
- 目的：在 ohpm install @ohos/libssh 后，遍历包内 `.d.ts` 与源码，核实 NAPI 封装的真实 API 签名（connect/认证、openShell/onData、resize、SFTP upload/download/progress、事件回调），并核对 agent/main.go 中 x/crypto/ssh 与 creack/pty 的可用接口
- 预期产出：输出准确的 API 调用清单与类型定义，直接作为 DirectEngine 与 Agent 网关实现的编码依据，避免按 README 摘要臆造 API
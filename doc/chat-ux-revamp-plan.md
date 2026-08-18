# 智子（Zhizon）AI 对话体验改造方案

> 版本：v1.4　|　状态：DevEco 首轮编译 17 个错误已全部修复（未类型化对象字面量 ×4、ClickEvent.stopPropagation 不存在、pasteboard.PasteRecord/getPrimaryRecord 不存在、TopBar 多 @BuilderParam 破坏尾随闭包 ×8、ChatTab 缺 @Component、重复 @Builder）；预检扫描（无类型字面量/可选链/非空断言/@Prop 函数类型）干净；待办：用户在 DevEco 重新编译确认
> 依据：现有代码走读 + GitHub 开源项目调研（2025-06）

---

## 0. 结论摘要

现有 AI 对话在「能用」层面已经不错：多模型配置、SSE 流式、思考折叠、Markdown 渲染、复制/分享/多选/搜索/重试/停止都有。
但与主流开源 AI 客户端相比，差距集中在 **五个体验断层**：

| 断层 | 现状 | 主流做法（参考项目） |
|---|---|---|
| 会话组织 | 只有一条永久对话，无多会话 | 会话列表 + 重命名/固定/删除/跨会话搜索（NextChat、Lobe Chat、Chatbox） |
| 流式渲染 | 流式中是纯文本打字机，结束后才转 Markdown | 边流边渲染 Markdown / 代码块（Lobe Chat、chat-ui） |
| 输入区 | 单行 TextInput，无图片、无模板、无状态 | 多行自动增高 + 附件 + 预设/斜杠命令 + Token 计数（Chatbox、Lobe Chat） |
| 消息操作 | 仅长按复制/分享/删除、失败重试 | 单条再生/编辑重发/代码块复制/上下文菜单（NextChat、LibreChat） |
| 过程反馈 | 无连接状态、无耗时/Token 展示 | 状态指示 + Token 用量 + 错误内联重试（Open WebUI、Cherry Studio） |

---

## 1. 现状盘点（代码依据）

### 1.1 已有能力

| 能力 | 位置 | 说明 |
|---|---|---|
| 多服务商/多模型配置 | common/LlmModels.ets、pages/ChatConfig.ets | OpenAI/Anthropic/DeepSeek/Qwen/Kimi/GLM/Ollama/自定义，AES-256-GCM 加密 Key |
| SSE 流式 + 思考控制 | service/LlmClient.ets（postCompletionStream） | 流式正文 + 独立 reasoning 增量回调 |
| Markdown 原生渲染 | common/MarkdownConverter.ets + Chat.ets 内 MarkdownText | 标题/列表/表格/引用/代码块/行内样式 |
| 思考过程折叠 | Chat.ets MessageBubble | 默认收起、展开限高滚动 |
| 消息操作 | Chat.ets | 长按复制/分享/删除、多选批量、搜索过滤、全屏查看、失败重试、流式停止 |
| 历史持久化 | service/ChatRepository.ets | 偏好存储单条线性历史（键 llmChatHistory），上下文按字符/4 截断 |

### 1.2 结构性短板

1. **无会话（Session）概念**：ChatRepository 只有 loadHistory/saveHistory 单条历史，换主题/清空即丢；无法按话题组织、无法跨会话检索。
2. **流式阶段不渲染 Markdown**：useMarkdown() 明确要求 !isStreaming，长回答流式期间是整段纯文本，体验割裂。
3. **输入区功能单薄**：单行 TextInput（代码里固定 44 高度），无自动增高、无图片附件（配置里有 visionEnabled 但 UI 无入口）、无预设/斜杠命令。
4. **代码块体验弱**：无语言标注、无复制按钮、无语法高亮（只有统一底色）。
5. **过程无反馈**：连接中/生成中无状态区分、无耗时与 Token 用量展示（LlmTokenUsage 已解析但 UI 未用）。
6. **Chat.ets 1590 行单体组件**：气泡、输入、搜索、多选、全屏、模型选择全部堆在一个文件，迭代成本高。
7. **Markdown 渲染能力上限**：无任务列表、无图片、无数学公式、无 Mermaid；表格只是文本行拼接。

---

## 2. 参考项目调研

### 2.1 跨平台 Web / 桌面（UX 范式来源）

| 项目 | 仓库 | 借鉴点 |
|---|---|---|
| **Lobe Chat** | https://github.com/lobehub/lobe-chat | 会话/话题两级组织、@ 提及模型、斜杠命令、流式 Markdown + 代码块复制、Token 用量、思维链展示 |
| **ChatGPT-Next-Web (NextChat)** | https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web | 会话列表 + 重命名/固定/搜索、提示词市场、消息「重发/编辑」、上下文长度预算条 |
| **Open WebUI** | https://github.com/open-webui/open-webui | 工作区/知识库、消息操作菜单、连接状态与流式光标、多会话检索 |
| **LibreChat** | https://github.com/danny-avila/LibreChat | 预设（Presets）、消息树/分支、跨模型切换不丢上下文 |
| **HuggingChat (chat-ui)** | https://github.com/huggingface/chat-ui | 简洁移动端优先布局、流式 Markdown 渲染、代码复制按钮 |
| **Chatbox** | https://github.com/Bin-Huang/chatbox | 移动端多会话抽屉 + 输入区多行增高 + 附件，最贴近手机交互 |
| **Cherry Studio** | https://github.com/CherryHQ/cherry-studio | 桌面多模型统一管理、知识库、助手（Agent）预设，功能分层参考 |

### 2.2 鸿蒙原生同类（架构直接参考）

| 项目 | 仓库 | 借鉴点 |
|---|---|---|
| **ChatCube** | https://github.com/LongLiveY96/chatcube | 鸿蒙 NEXT 原生 AI 客户端：13+ 服务商、工具调用、流式；会话模型与 ArkTS 组件拆分方式 |
| **GoodChat-Harmony** | https://github.com/ImGoodBai/Goodchat-Harmony | 鸿蒙 Agent 应用：聊天 + 图像生成 + 搜索的导航组织 |

### 2.3 UI 组件库（交互实现参考）

| 项目 | 仓库 | 借鉴点 |
|---|---|---|
| **assistant-ui** | https://github.com/assistant-ui/assistant-ui | 消息列表虚拟化、流式 diff 渲染、消息操作栏的组件化设计 |

> 注：星标数随月份变动，不列具体数值；Lobe Chat / NextChat / Open WebUI 均为数万级高星项目，可直接按链接查看最新状态。

---

## 3. 改造方案

### 3.0 总体原则

- **移动端优先**：参考 Chatbox / HuggingChat 的窄屏范式，不做桌面管理台式的复杂布局。
- **原生组件优先**：延续现有「纯 ArkUI 渲染 Markdown」路线，不引入 WebView 常驻（保留全屏 WebView 作为兜底查看器）。
- **渐进式落地**：P0 解决「不好用」的痛点，P1 补「高级功能」，P2 做「打磨与重构」；每阶段可独立发版。
- **数据兼容**：RDB 升 v5 迁移 + 旧偏好历史一次性迁入会话表，不丢用户数据。

### 3.1 P0 核心体验（改造主力，预计 2~3 个迭代）

#### P0-1 多会话管理
- 目标：从「一条对话」升级为「会话列表 + 当前会话」。
- 内容：
  - 新建会话、会话重命名（自动取首条用户消息前 20 字）、删除、固定置顶、按时间排序；
  - 左上角会话列表抽屉（手机）/ 侧栏（平板），会话内消息互不影响；
  - 清空对话改为「删除当前会话」，不再污染其他会话。
- 数据：RDB v9 新增 chat_sessions（id、title、created_at、updated_at、pinned、active_model_id）+ chat_messages（id、session_id、role、content、reasoning、time、status、error_code、model_id、model_name、token 列），旧 llmChatHistory 迁移为默认会话（实际当前库版本为 v8，故新表为 v9）。
- 涉及：DatabaseHelper.ets、ChatRepository.ets（重写为 Session/Messages 仓储）、LlmModels.ets（新增 SessionModel、ChatMessage 加 sessionId/status/tokens）、Chat.ets（会话抽屉）、AppShell.ets。
- 参考：NextChat 会话列表、Chatbox 移动端抽屉。

#### P0-2 流式 Markdown 渲染
- 目标：流式过程中即可看到标题/列表/代码块排版，而不是等结束后跳变。
- 内容：
  - MarkdownConverter 改为「增量可重入」：按换行/代码栅栏切块，已闭合的块直接渲染，未闭合块用流式样式；
  - 渲染节流：SSE 增量按约 50ms 合并一次刷新（当前每次 delta 都触发 scroll + 整串拼接，长回答会卡顿）；
  - 代码块流式期间显示语言标签 + 「复制」按钮（复制当前已生成内容）。
- 涉及：MarkdownConverter.ets（增量解析）、Chat.ets MessageBubble（isStreaming 分支改为流式 MarkdownText）、LlmClient.ets（增量缓冲合并）。
- 参考：Lobe Chat、HuggingChat 的流式渲染；assistant-ui 的 diff 渲染思路。

#### P0-3 输入区升级
- 目标：输入从「一个框一个按钮」变成「可承载内容与状态的输入条」。
- 内容：
  - TextArea 自动增高（1~5 行），回车发送、换行另设（手机软键盘回车 = 发送）；
  - 发送键随输入/流式状态切换：可发送 → 生成中（停止）→ 等待中（Loading）；
  - 输入区上方加「+ 附件」：启用 visionEnabled 的模型可拍/选图（photoAccessHelper + 压缩），以 base64 或 URL 形式进 messages（OpenAI/Claude 格式）；
  - Token 计数：按字符/4 估算当前输入，接近上下文上限时变色提示（复用 contextTokensIn）；
  - 快捷入口：当前模型名 chip + 「预设」chip（见 P1-1）。
- 涉及：Chat.ets inputBar、新增 components/ChatInputBar.ets、LlmClient.ets（多模态 content 数组格式）、LlmModels.ets（ChatRequestMessage 支持数组 content）。
- 参考：Chatbox 输入条、Lobe Chat 附件与 @ 菜单。

#### P0-4 消息操作补全
- 目标：长按菜单对齐主流客户端。
- 内容（现有基础上新增）：
  - 用户消息：**编辑并重发**（编辑原文 → 重新请求，替换该条及其后所有回复）；
  - 助手消息：**重新生成**（只替换本条回复）；失败重试沿用现有；
  - 代码块内：独立复制按钮 + 全选；
  - 消息上下文菜单改为半屏 ActionSheet 或气泡菜单（现有长按面板可保留，补两项即可）。
- 涉及：Chat.ets（retry/regenerate 逻辑复用 send 流程）、新增 components/MessageActions.ets。
- 参考：NextChat 重发/编辑、LibreChat 消息分支。

#### P0-5 过程与状态反馈
- 目标：用户随时知道「在连接、在生成、用了多少」。
- 内容：
  - 状态行：连接中… → 生成中…（计时）→ 完成（耗时 + Token）；
  - 助手气泡下方展示 token 用量（输入/输出/缓存，来自 LlmResult.tokenUsage，已解析好）；
  - 错误内联化：失败消息气泡内显示错误码 + 重试按钮（现有 ⚠️ 请求失败 文案可保留，补充 errorCode）；
  - 超时/取消区分「用户停止」与「网络中断」。
- 涉及：Chat.ets MessageBubble、LlmClient.ets（错误码归一）、LlmModels.ets（LlmResult 已有 tokenUsage）。
- 参考：Open WebUI 状态指示、Lobe Chat 用量展示。

### 3.2 P1 进阶能力（预计 2~3 个迭代）

#### P1-1 预设与提示词
- 系统提示词编辑（ChatConfig 增加 System Prompt 字段，随模型配置保存）；
- 预设（Preset）：内置「代码审查/翻译/文案/写作」等模板，输入区可一键套用；
- 斜杠命令：输入 / 弹出命令列表（/clear、/new、/preset:xxx）；
- 可选 @模型：多模型会话中指定本条用哪个模型（Lobe Chat 风格，ArkTS 实现成本中等，可后置）。
- 涉及：ChatConfig.ets、LlmModels.ets（LlmConfig 加 systemPrompt）、新增 components/SlashCommandMenu.ets。
- 参考：NextChat 提示词市场、LibreChat Presets。

#### P1-2 代码块增强
- 解析代码围栏语言（MarkdownConverter 提取语言），头部显示语言 + 复制；
- 轻量语法高亮：按语言做关键字/字符串/注释 token 着色（纯 ArkTS 正则实现，不引第三方）；
- 代码块流式完成前显示「正在生成代码…」占位。
- 涉及：MarkdownConverter.ets（围栏语言解析）、新增 components/CodeBlock.ets。
- 参考：HuggingChat、Lobe Chat 代码块。

#### P1-3 Token 与上下文可视化
- 每会话「上下文占用条」：已用/预算（估算 vs contextTokensIn），点击可查看构成；
- 长会话自动摘要提示：接近上限时建议「开新会话」或「压缩上文」（先提示，压缩实现可后置）。
- 涉及：ChatRepository.requestMessages（改为返回预算占用）、Chat.ets 顶部、新增 components/ContextBar.ets。
- 参考：NextChat 上下文预算条。

#### P1-4 搜索增强
- 现有消息内搜索升级：关键词高亮、命中定位；
- 新增跨会话搜索（会话列表页顶部，SQL LIKE 或内存过滤）。
- 涉及：Chat.ets searchBar、ChatRepository（跨会话查询）。
- 参考：LibreChat message search。

#### P1-5 导出 / 导入
- 会话导出为 Markdown / JSON（系统分享面板复用现有 systemShare 代码）；
- 导入 JSON 恢复会话（安全校验，拒绝脚本内容）。
- 涉及：Chat.ets、新增 service/ChatExporter.ets、Settings.ets 入口。
- 参考：Chatbox 导入导出。

### 3.3 P2 打磨与重构（持续迭代）

- **组件化重构**：Chat.ets 拆分为 pages/ChatPage.ets（编排）+ components/ChatMessageList.ets / ChatMessageBubble.ets / ChatInputBar.ets / CodeBlock.ets / SessionDrawer.ets / ContextBar.ets；逻辑抽 service/ChatViewModel.ets（状态机：idle / connecting / streaming / stopped / error）。
- **性能**：长列表 LazyForEach + 消息项缓存；流式滚动节流（500ms 一次 scrollEdge）；增量渲染避免整串重排。
- **无障碍/细节**：读屏标签、震动反馈（Vibrator）、深色代码块配色随主题、刘海屏输入区安全区适配。
- **可选进阶（明确可不做）**：本地知识库/RAG（Open WebUI 范式，工程量较大）、Web 搜索工具调用（ChatCube 已示范 tool calling，可作二期）、语音输入（TTS/ASR Kit）、会话分支树。

---

## 4. 数据与架构改动清单

| 改动 | 类型 | 说明 |
|---|---|---|
| RDB v9：chat_sessions / chat_messages | 迁移 | DatabaseHelper 版本升 9，建表 + 从 llmChatHistory 迁移旧数据 |
| ChatRepository 重写 | 重构 | loadSessions / createSession / appendMessage / updateMessage / deleteSession / searchSessions |
| ChatMessage 扩展 | 兼容 | 加 sessionId/status/modelId/tokenUsage，旧数据补默认值 |
| LlmConfig 扩展 | 兼容 | 加 systemPrompt、presetId（可选） |
| Chat.ets 拆分 | 重构 | 按 P2 组件化，功能不变前提下分步拆 |
| MarkdownConverter 增量化 | 重构 | 纯函数改造，便于单测 |

## 5. 里程碑建议

| 里程碑 | 内容 | 验收标准 |
|---|---|---|
| M1（P0 子集） | 多会话 + 流式 Markdown + 状态反馈 | 可建 3+ 会话互不干扰；长回答流式全程有排版；连接/生成/停止状态清晰 |
| M2（P0 完成） | 输入区升级 + 消息操作补全 | 可编辑重发、重新生成、附图片（vision 模型）；输入自动增高 |
| M3（P1） | 预设/提示词、代码块、Token 可视化、搜索、导入导出 | 每条助手消息可见 token；代码块可复制；跨会话可搜 |
| M4（P2） | 组件化重构 + 性能 + 无障碍 | Chat.ets 拆完；千行长回答无卡顿 |

## 6. 风险与注意事项

- **RDB 迁移**：v8 → v9 必须幂等（IF NOT EXISTS / 迁移标志位），升级失败回退旧偏好读取。
- **ArkTS 严格模式**：无 any、无第三方运行时依赖；语法高亮/增量解析必须纯 TS 实现并过编译。
- **流式性能**：增量合并与渲染节流是 P0 的关键技术点，建议先在单测里压长文本。
- **多模态成本**：图片 base64 会显著涨 token，附件入口需提示估算成本（复用 AiCallLogger 的统计能力）。
- **范围控制**：RAG/工具调用/语音属于「可做可不做」，建议等 M1~M2 落地后再评估，避免一次铺太大。

## 7. 参考链接汇总

- Lobe Chat：https://github.com/lobehub/lobe-chat
- ChatGPT-Next-Web：https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web
- Open WebUI：https://github.com/open-webui/open-webui
- LibreChat：https://github.com/danny-avila/LibreChat
- HuggingChat (chat-ui)：https://github.com/huggingface/chat-ui
- Chatbox：https://github.com/Bin-Huang/chatbox
- Cherry Studio：https://github.com/CherryHQ/cherry-studio
- ChatCube（鸿蒙原生）：https://github.com/LongLiveY96/chatcube
- GoodChat-Harmony（鸿蒙原生）：https://github.com/ImGoodBai/Goodchat-Harmony
- assistant-ui：https://github.com/assistant-ui/assistant-ui

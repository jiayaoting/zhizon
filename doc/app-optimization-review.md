# 智子（Zhizon）应用优化评审报告

> 评审对象：HarmonyOS NEXT 原生应用（ArkTS / ArkUI，Stage 模型，API 24）
> 评审范围：性能、数据层、安全、UX、工程化 + 新功能建议
> 配套文档：doc/ux-review-and-features.md（UX 缺陷 + 新功能清单）

---

## 一、总体评价

代码整体质量**高于同类个人项目**：流式输出有 60ms 刷新节流、Markdown 解析有 250ms 节流 + span 缓存（曾修复过 OOM）、新闻流/会话抽屉/战绩已用 LazyForEach、游戏定时器大多在 aboutToDisappear 清理、API Key 用 HUKS AES-256-GCM 加密、RDB 查询大多带 limit 并关闭 ResultSet。

主要风险集中在三处：**聊天消息列表未懒加载**（会话越长越卡）、**数据库层全表扫描/迁移/无保留策略**（数据增长后劣化）、**云同步覆盖式恢复与密码哈希强度**（安全与数据丢失风险）。

---

## 二、可优化项（按严重度）

### P0 必须修复

| 类别 | 位置 | 问题 | 建议 |
| --- | --- | --- | --- |
| 性能 | pages/Chat.ets:1752 + service/ChatRepository.ets:287 | 消息列表用 List+ForEach 一次渲染全部历史，DB 查询无 LIMIT，会话越长越卡、内存越大 | 改 LazyForEach；只加载最近 N 条，滚动到顶部再补载 |
| 数据 | service/DatabaseHelper.ets:474-520；ChatRepository.ets:316 | 计数全部拉全表循环（getAiHostCount / getChatMessageCount / countRows）；每次发消息都全扫 chat_messages | 改 querySql 执行 `SELECT COUNT(*)`（已核实本 SDK 的 relationalStore 无 store.count 方法） |
| 数据 | service/DatabaseHelper.ets:289-375 | 建表/迁移不在 onUpgrade 回调里，每次启动重复执行注定失败的 ALTER 且 catch{} 静默吞错，失败仍把 version 置为 15 | 迁入 onUpgrade/onDowngrade，按版本分步、记日志、加事务 |
| 数据 | CloudSyncService.ets:156-207 | 恢复直接清空覆盖（replaceAllSettings + clearGameScoresAll + 覆盖成就），无校验和/时间比对/回滚；损坏文件直接抛异常；导入丢失会话 id 造成重复 | 加校验和 + 原子写 + 按 id 合并 + 超时容错 + 恢复前确认预览 |
| 安全 | service/SecurityService.ets:137-148 | 主密码用单轮 SHA-256+盐，非 KDF；verify 无次数限制、非恒时比较 | 改 PBKDF2/scrypt（cryptoFramework 已支持），恒时比较 + 失败节流 |
| 数据 | chat_messages(image_data base64)、ai_call_logs、news_read、news_article_cache、chat_agent_steps、game_replays | 全部无上限增长，仅 news_events 有 90 天清理 | 加保留期/行数上限/LRU；删会话时级联清理 agent_steps |

### P1 建议尽快

| 类别 | 位置 | 问题 | 建议 |
| --- | --- | --- | --- |
| 性能 | pages/Chat.ets:48-127,713,850,931 | messages 整体赋值触发 List 全量 diff；输入框每敲一键 inputText 变化 → 整页重渲染 | 输入状态下沉到 ChatInputBar 子组件；增删消息走 DataSource.add/remove/change |
| 性能 | pages/Tetris.ets:798-878；Snake.ets:902-872 | 每次下落/移动在 build 内重建 200 格数组并全量 ForEach diff，每格挂 .animation，高等级掉帧 | 缓存 display 数组仅变化时重建，或改 Canvas；删逐格动画 |
| 性能 | pages/Chat.ets:131-141,1929-1930 | chatPhase/elapsedSeconds 每秒变更 + 60ms flush 整条重渲染 + scrollToBottom | 状态收敛进小组件；滚动节流到 250ms |
| 性能 | GlobalBackgroundLayer.ets:46；ParticleBackground.ets:11；ChatMessageBubble.ets:194,208 | 全屏 backdropBlur(24) + 160 粒子持续动画 + 每气泡再叠模糊，GPU/发热高 | 模糊降级为局部；粒子减半且仅前台；低电量自动禁用 |
| 性能 | pages/Index.ets:167-168,281-289 | 上拉重拉 100 条 merge 后 source.replace 全量重载；单条点踩/撤销也整表刷新 | 偏移分页增量 add；单条操作走 change/remove |
| 网络 | service/WebSearchService.ets:30-44 | HttpRequest 仅成功路径 destroy，超时/异常路径泄漏 | try/finally（参照 LlmClient.ets:599-604） |
| 安全 | service/ChatRepository.ets:126-133 | 每次 loadModels 解密全部模型 Key，实际只用激活模型，明文常驻内存 | 按需解密激活模型，用后清引用 |
| 数据 | DatabaseHelper.ets（全文件） | 仅 chat_messages(session,time)、news_events 两个索引；game_scores(game,score)、ai_call_logs(start_time)、news_read(read_at)、news_favorites(added_at) 缺索引 | 补建索引 |
| 数据 | DatabaseHelper.ets:1112-1123 | news_read 每次阅读删+插两次写且无上限 | 改 upsert/REPLACE + 保留上限 |
| 健壮性 | DatabaseHelper.ets 数十处空 catch | 收藏/已读/打标失败无感知 | 至少 hilog.warn，关键路径上抛 UI 提示 |
| 网络 | LlmClient.ets:527-534,678-684 | 流式超时定时器不清理，截断内容被当成功返回 | 超时返回 TIMEOUT 错误 + clearTimeout |
| UX | pages/AppShell.ets:113-153（renderPage if 切换） | 切 Tab 会销毁重建 ChatTab，流式生成中切走 → 状态机/实况窗/回调断链，生成结果可能不落 UI | 保持 ChatTab 挂载（Visibility 切换）或把生成状态外提到 service |
| 架构 | common/AppNavigator.ets + pages/AppShell.ets | 双导航体系：AppShell 状态切换 + router.pushUrl 路由页，未使用 Navigation/NavPathStack | 统一迁移到 Navigation 组件，获得系统级转场/返回/深链 |

### P2 / P3 优化项

| 类别 | 位置 | 问题 | 建议 |
| --- | --- | --- | --- |
| 性能 | 全仓 @Reusable 0 处 | 气泡/卡片/单元格高频重建 | 纯展示子组件（只传基本类型+回调）加 @Reusable |
| 工程 | Chat.ets 2165 行、ChineseChess.ets 1828、Snake.ets 1751、Gomoku.ets 1643、ChatConfig.ets 1624 | 单文件过大，职责耦合难维护 | 按 Board 渲染 / AI 面板 / 回放 / 弹层 / 服务拆分 |
| 健壮性 | Gomoku.ets:144；ChineseChess.ets:244；Sudoku.ets:610；Chat.ets:158,180 | aboutToDisappear 未停 thinkTimer/stepDelay/hintTip/滚动 setTimeout，依赖 onPageHide 兜底 | 统一在 aboutToDisappear 全量兜底 |
| 性能 | Chat.ets:2134-2145 | 全屏 Markdown 用 Web 组件固定 height 2000 嵌 Scroll，双层滚动冲突且每次重新 loadData | 复用 ChatMarkdownText 或给 Web 真实高度 |
| 性能 | Index.ets:88-115 | 每卡片每次渲染对 readUrls/likedUrls indexOf，O(n·m) | 改 Set/Map |
| 性能 | Snake.ets:1422-1456 | 回放 16ms 定时器每帧最多 200 个事件，回放卡顿 | 每帧限 N 个事件 |
| 记账 | LlmClient.ets:218-313 | Agent 工具调用不走 AiCallLogger，token 统计漏计 | 补调用日志 |
| 性能 | ChatRepository.ets:397-414 | 会话搜索 N+1：遍历全部会话加载全部消息内存匹配 | 改 SQL LIKE / 引入 FTS |
| 安全 | DatabaseHelper.ets:345 | news_events 清理用字符串拼数字 | 参数化 |
| 安全 | CryptoHelper.ets:67-75,129-134 | finishSession 失败未 abortSession，HUKS 会话泄漏 | try/finally abort |
| 网络 | NewsService.ets:73,94,320 | 全源 Promise.all 并发抓取，搜索每次触发全源 | 并发池（≤4）+ 去抖 |
| 实况窗 | service/LiveViewService.ets | 全局单一 liveViewId + active 标志，聊天与游戏 AI 同时进行时互相覆盖，关闭一个会误关另一个 | 按 event 维度管理多个实况窗，close 用对应 event/id |
| 文档 | README.md / DESIGN.md / codebase-structure.md | 已漂移：RDB v4→v15、页面 16→30+、测试 6→12、README 权限表含未声明的 READ_MEDIA/WRITE_MEDIA | 同步文档，权限表以 module.json5 为准 |

---

## 三、UX 可感知问题（摘要，详见 doc/ux-review-and-features.md）

1. **死入口**："检查更新"恒提示已是最新、"反馈"提示即将上线、失败回退"用系统浏览器打开"只弹 Toast 不跳转
2. **字号过小**：fsXs=10fp、部分标签 9fp，弱视用户不可读
3. **对比度不足**：#94A3B8 叠 #F5F6FA 约 2.4:1，低于 WCAG AA 4.5:1
4. **权限被拒无出路**：麦克风被拒仅 Toast，永久拒绝后无"去设置"引导
5. **加载态缺失**：Settings loading 未用于 UI、NewsDetail 正文无加载/超时提示、Profile 统计失败静默显示 0
6. **空态不统一**：Chat 欢迎语固定提示"请先配置 API"，已配置用户被误导
7. **触控目标过小**：TopBar 按钮 32×32、详情页 7 连排按钮 < 44vp 最小热区
8. **国际化硬编码**：页面文案全中文硬编码，string.json 仅 10 条
9. **2in1 未适配**：module 声明 2in1，游戏/聊天仍纯触控
10. **错误透出**：Chat 气泡直接拼接原始 errorMessage（如 401）

---

## 四、建议新增的实用功能 / 特性

| 功能 | 价值 | 落地要点（Kit/API） | 优先级 |
| --- | --- | --- | --- |
| 资讯服务卡片 | 桌面直达今日要闻/早报，免开 App，提升日活 | Form Kit + 定时刷新（已有实况窗可复用进度逻辑） | P0 |
| AI 早报推送 | 每天自动生成要闻简报推通知，形成使用习惯 | Background Tasks Kit + NewsAiService + Notification Kit | P1 |
| 稍后读提醒 | 收藏文章设时准点提醒 | Reminder Agent Manager + Notification Kit | P1 |
| 意图直达 | 系统分享/小艺"用智子读这篇文章" | Intents Kit（URL/分享意图），配合 NewsDetail 路由 | P1 |
| 跨端续读 | 手机↔平板/PC 无缝续读文章与对话 | Continuation Kit + UDMF（结合现有云同步） | P1 |
| 后台听资讯 | 锁屏/后台持续朗读并受媒体控制 | AVSession Kit + Background Tasks Kit（现有 TTS 扩展） | P1 |
| 桌面快捷方式 | 长按图标直达对话/要闻/游戏 | shortcuts_config.json | P2 |
| 扫码直达 | 扫二维码直接打开文章/参与活动 | Scan Kit | P2 |
| 壁纸取色主题 | 跟随系统壁纸动态生成主题色 | Wallpaper Kit 取色 + 现有 ThemePalette 扩展 | P2 |
| 日历联动 | 阅读目标/游戏打卡写入系统日历 | Calendar Kit | P2 |
| 智子要闻元服务 | 免安装轻量要闻体验 | 元服务 + Form Kit | P2 |
| 系统 Agent 协作 | 小艺/系统 Agent 调用智子资讯与对话能力 | Agent Framework Kit | P2 |

补充（基于现有功能的增强，不算全新功能）：
- **聊天/资讯全文搜索**：现有跨会话搜索是 N+1 全量加载，升级为 SQLite FTS5 后体验质变
- **会话"无痕/只读"模式**：结合现有锁定与导出能力，聊天记录可选不落盘
- **阅读周报**：NewsStats 已有统计基础，扩展为每周阅读/收藏/AI 使用时长可视化报表
- **AI 角色模板库**：现有提示词预设基础上内置一批角色/场景模板，一键写入系统提示词

---

## 五、建议实施顺序

1. **第一批（性能/数据，1~2 周）**：Chat 消息列表 LazyForEach+分页；计数改 store.count；迁移入 onUpgrade；补索引；数据保留策略
2. **第二批（安全/健壮性，1 周）**：CloudSync 恢复保护；密码改 KDF；WebSearchService try/finally；LlmClient 超时修正；空 catch 补日志
3. **第三批（UX/架构，2~3 周）**：导航统一 Navigation；ChatTab 保活；输入状态局部化；字号/对比度/触控目标修复；拆大文件
4. **第四批（新功能，按 P0/P1 排期）**：资讯服务卡片 → AI 早报推送 → 意图直达 → 跨端续读 → 后台听资讯

---

## 六、本轮已实施修复（对应「一、最值得优先优化的 8 件事」）

> 实施时间：本轮会话；全部为代码改动，**未在 DevEco 编译/真机验证**（本环境无 hvigor/SDK），需按文末清单验证。
> 补充说明：本 SDK（API 24）的 relationalStore 经核实**没有 store.count() 与 onUpgrade 回调**，因此分别改为 querySql COUNT(*) 与「启动时版本门控事务迁移」。

| # | 优化项 | 改动文件 | 实现摘要 |
| --- | --- | --- | --- |
| 1 | Chat 消息列表懒加载 | pages/Chat.ets、service/ChatRepository.ets、components/ChatMessageList.ets | 新增 loadMessagesWindow/loadMessagesBefore/countMessages（倒序分页+COUNT(*)）；列表只加载最近 50 条、LazyForEach 渲染、上滑到顶补载并保持滚动位置；搜索/导入/删除/切会话/新建等全部接入分页与数据源同步 |
| 2 | Chat 渲染隔离 | pages/Chat.ets、components/ChatMessageList.ets | 消息列表抽成独立组件（数据源驱动），输入框按键、生成计时等高频父组件状态变化不再重建整条消息列表 |
| 3 | Tetris/Snake 棋盘性能 | pages/Tetris.ets、pages/Snake.ets | 棋盘显示数组改为缓存（仅在落块/消行/移动等事件时重建）；移除 200/256 个逐格隐式动画；消行动画收敛为 animateTo 事件动画、食物动画收敛为单节点覆盖层 |
| 4 | 模糊/粒子降级 | components/GlassEffect.ets、GlobalBackgroundLayer.ets、ParticleBackground.ets、ChatMessageBubble.ets | 新增 FxBudget.isLowBattery()（电量<20%）；低电量：全屏 backdropBlur→0、粒子不启动、气泡 blur 关闭；正常档 blur 24→12、粒子 160→80 |
| 5 | RDB 计数优化 | service/DatabaseHelper.ets | getAiHostCount/getChatMessageCount/countRows 改为 SELECT COUNT(*)（querySql+bindArgs，finally close） |
| 6 | 迁移版本化 | service/DatabaseHelper.ets | 新增 migrateSchema()：读 store.version、事务包裹、逐列做存在性检查、成功才置 DB_VERSION，失败回滚+hilog.error+保持 version 下次重试 |
| 7 | 数据保留策略 | service/DatabaseHelper.ets、service/ChatRepository.ets | applyRetentionPolicy()：agent_steps 90d、ai_call_logs 90d、news_read 90d、article_cache 30d、replays 180d、news_events 90d、chat_messages 按 settings chatRetentionDays（默认 365，0=不清理）；删除会话级联清理 agent_steps；news_read 改 INSERT OR REPLACE 单次写 |
| 8 | CloudSync 恢复保护 | service/CloudSyncService.ets、service/ChatExporter.ets、pages/Settings.ets | 备份载荷加 SHA-256 checksum 与恢复校验（旧备份无校验则注明）；tmp+rename 原子写；云任务 60s 超时；恢复前 restorePreview + AlertDialog 确认；恢复改为合并式（settings 逐 key、战绩按 id 补缺、成就取并集/max、会话 v3 按 id+消息 id 去重） |
| 附加 | 索引 | service/DatabaseHelper.ets | 新增 game_scores(game,score)、ai_call_logs(start_time)、news_read(read_at)、news_favorites(added_at) 4 个索引 |

### 需要在 DevEco 验证（按优先级）

1. **编译**：Sync + assembleHap，ArkTS 严格模式无报错（重点文件：Chat.ets、ChatMessageList.ets、ChatRepository.ets、DatabaseHelper.ets、CloudSyncService.ets、ChatExporter.ets、Settings.ets、Tetris.ets、Snake.ets、GlassEffect.ets）。
2. **聊天分页**：新建超 50 条消息的会话 → 只渲染最近 50 条；上滑到顶补载更早消息且位置不跳；流式输出、停止、重试、重新生成、多选删除、搜索、切会话、导入导出均回归。
3. **数据库**：新装启动无迁移失败日志、version=15；旧库升级补列成功；四个计数方法与改造前数值一致；PRAGMA index_list 见 4 个新索引；同一 url 连点已读无冲突。
4. **保留策略**：settings 里把 chatRetentionDays 设为 1 并插入旧数据，重启验证清理；0 不清理；清 ai_call_logs 后 ai_token_stats 累计不变。
5. **云同步**：备份文件含 64 位 hex checksum 且无 .tmp 残留；恢复前弹摘要确认框；篡改备份 → 校验失败且本地数据零变化；旧备份可恢复并提示「未校验」；同一备份连续恢复两次会话/消息不重复；断网时 60s 内超时降级不卡 UI。
6. **游戏手感**：Tetris 消行动画、Snake 蛇身滑动与食物脉冲观感不变；HELL 难度连续游玩不掉帧。
7. **低电量降级**：电量 <20% 时粒子不渲染、全屏模糊与气泡 blur 关闭；≥20% 恢复原视觉；模拟器无电量信息时按非低电量处理不崩溃。

---

## 七、本轮新增功能（4 项）

| 功能 | 实现 | 关键文件 |
| --- | --- | --- |
| 1. 聊天/资讯全文搜索（FTS5） | 数据库 v16 起探测创建 FTS5 虚拟表（trigram 分词优先，默认分词兜底），设备不支持时自动回退 LIKE；聊天：会话内搜索覆盖整个会话历史（非仅加载窗口）、跨会话搜索按相关度排序（GROUP BY + bm25），删除原 N+1 全量加载；资讯：收藏（标题/摘要）+ 离线正文缓存（标题/正文）本地全文搜索，NewsSearch 新增「本地收藏·缓存」模式。索引在增删改消息/收藏/缓存时同步维护，首次搜索前全量重建一次 | DatabaseHelper、ChatRepository、NewsRepository、Chat.ets、NewsSearch.ets |
| 2. 会话无痕模式 | 全局开关（设置→安全与隐私）+ 会话级标记（会话抽屉 🔒 按钮）；无痕状态下消息/Agent 步骤不写入数据库与 FTS，界面显示 🕶️ 提示条；会话级标记持久化到 chat_sessions.incognito（v16 迁移） | DatabaseHelper、ChatRepository、Chat.ets、ChatSessionDrawer、Settings.ets、LlmModels |
| 3. 阅读周报可视化 | 新页面 ReadingReport：近 7 天阅读/收藏/AI 资讯调用统计卡 + Canvas 柱状图 + 本地规则周报文案；入口：我的→资讯→阅读周报、设置→资讯→阅读周报 | ReadingReport.ets（新）、DatabaseHelper（WeeklyReadingStats）、Profile.ets、Settings.ets、AppShell/main_pages |
| 4. AI 角色模板库 | 新页面 AiRoleLibrary：8 个内置角色 + 自定义角色（新建/删除/持久化到设置 aiRoleTemplates）；一键把角色 system prompt 应用到当前模型（ChatRepository.updateModelSystemPrompt）；入口：会话抽屉 🎭、我的→AI→AI 角色模板、设置→Agent→AI 角色模板 | AiRoleLibrary.ets、RoleTemplates.ets（新）、ChatRepository、ChatSessionDrawer、Profile.ets、Settings.ets、AppShell/main_pages |

### 新增功能验证清单（DevEco）

1. 编译：Rebuild 确认 0 error（重点 ArkTS 严格规则：无 any、无未类型化字面量）。
2. FTS：启动日志无 FTS 创建失败告警说明 trigram 可用；聊天页搜索 >3 字关键词可命中整段历史（含未加载窗口的旧消息）；会话抽屉跨会话搜索按相关度排序；新闻搜索「本地收藏·缓存」模式可搜收藏标题与已缓存正文；设备不支持 FTS 时（日志告警）确认 LIKE 兜底仍可搜。
3. 无痕：设置开启全局无痕→发消息→退出重进应用，消息不出现；会话抽屉对某会话开 🔒→该会话消息不落库；无痕时消息列表、停止、重试、重新生成正常；关闭无痕后新消息恢复保存。
4. 阅读周报：有数据时 4 卡数值正确、Canvas 图正常；全零时空态文案；深色/浅色主题正常。
5. 角色库：8 内置角色可应用并 toast 成功；未配置模型时提示先配置；新建自定义角色保存后可删除，重启仍在；应用后到 ChatConfig 查看模型 system prompt 已更新。
6. 回归：既有会话搜索、ChatConfig、云同步备份（v3 不受影响）、资讯收藏/缓存清空均正常。

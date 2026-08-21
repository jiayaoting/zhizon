# 智子 UX 评审与功能建议

抽查：README/DESIGN/module.json5、app.json5、Settings/Profile/NewsDetail/Chat、resources。

## 一、UX 缺陷（10 项）

1. **死入口**："检查更新"恒提示"已是最新版本"、"反馈"提示"即将上线"；详情失败回退页"用系统浏览器打开原文"只弹 Toast 不跳转。
2. **字号过小**：fsXs=10fp、部分标签 9fp（操作条/统计格/计数），弱视用户不可读。
3. **亮色对比度不足**：#94A3B8 叠 #F5F6FA 约 2.4:1，低于 WCAG AA 4.5:1，时间/说明/占位符大面积使用。
4. **权限被拒无出路**：麦克风被拒仅 Toast，永久拒绝后无"去设置"引导。
5. **加载态缺失**：Settings 的 loading 未用于 UI；NewsDetail 正文无加载/超时提示；Profile 统计失败静默显示 0。
6. **空态不统一**：Chat 欢迎语固定提示"请先配置 API"，已配置用户仍被误导。
7. **触控目标过小**：TopBar 按钮 32×32、详情 7 连排操作按钮，低于 44vp 最小热区。
8. **国际化硬编码**：页面文案全量中文硬编码，string.json 仅 10 条，无多语言资源与本地化日期。
9. **2in1 未适配**：module 声明 2in1，游戏/聊天仍纯触控；ArkWeb 返回手势可能与站内历史冲突。
10. **原始错误透出**：Chat 气泡直接拼接 errorMessage（如 401），应分级提示＋可复制详情。

## 二、新功能建议（12 项）

| 功能 | 价值 | 落地要点（Kit/API） | 级 |
| --- | --- | --- | --- |
| 资讯服务卡片 | 桌面直达要闻/早报，免开 App | Form Kit＋定时刷新 | P0 |
| 稍后读提醒 | 收藏文章设时准点提醒 | Reminder Agent Manager＋Notification Kit | P1 |
| 跨端续读 | 手机↔平板/PC 无缝续读 | Continuation Kit＋UDMF | P1 |
| AI 早报推送 | 每日后台生成早报推通知 | Background Tasks Kit＋NewsAiService | P1 |
| 意图直达 | 小艺/分享面板"用智子读文章" | Intents Kit（URL/分享意图） | P1 |
| 后台听资讯 | 锁屏/后台持续朗读并受媒体控制 | AVSession Kit＋Background Tasks Kit | P1 |
| 桌面快捷方式 | 长按图标直达对话/要闻/游戏 | shortcuts_config.json | P2 |
| 扫码直达 | 扫二维码直接打开文章 | Scan Kit | P2 |
| 壁纸取色主题 | 跟随系统壁纸动态生成主题色 | Wallpaper Kit 壁纸取色＋ThemePalette | P2 |
| 日历联动 | 阅读目标/游戏打卡写入系统日历 | Calendar Kit | P2 |
| 智子要闻元服务 | 免安装轻量要闻体验 | 元服务＋Form Kit | P2 |
| 系统 Agent 协作 | 小艺/系统 Agent 调用智子资讯能力 | Agent Framework Kit | P2 |

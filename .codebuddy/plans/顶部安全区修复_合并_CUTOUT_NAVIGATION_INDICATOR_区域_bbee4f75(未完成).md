---
name: 顶部安全区修复：合并 CUTOUT/NAVIGATION_INDICATOR 区域
overview: 修复 EntryAbility 中只读取 TYPE_SYSTEM 的缺陷，合并 TYPE_CUTOUT（挖孔/刘海）和 TYPE_NAVIGATION_INDICATOR（手势条），并在 loadContent 之后重新计算，确保 AppStorage 中的 statusBarHeight/navBarHeight 始终是真正的安全区最大值。
todos:
  - id: rewrite-entryability-safearea
    content: 重写 EntryAbility.ets 的安全区读取逻辑：合并 TYPE_SYSTEM/TYPE_CUTOUT/TYPE_NAVIGATION_INDICATOR 三个区域，初始化阶段同步写入 AppStorage，loadContent 完成回调再写一次，avoidAreaChange 按 type 分类缓存后合并输出，加上 SAFE_TOP_MIN=44 / SAFE_BOTTOM_MIN=24 兜底
    status: pending
---

## 修复背景

用户反馈：尽管已在前轮为 ArkTS 编译错误与基础安全区做了修复，实际运行的两张截图（ServerForm 添加服务器页、AppShell SSH 服务器页）依然存在：

- 顶部：系统状态栏/挖孔区（时间、淘、100 电量、已接单）与 TopBar 内容重叠。"添加服务器" 标题、"SSH 服务器" 标题被压在屏幕最顶端
- 底部：截图 1 底部"添加服务器"按钮与底部黑色手势条几乎贴边，未留出有效呼吸空间；截图 2 底部 Tab 虽在但同样贴近底部指示条

## 根因

- `EntryAbility` 仅读取 `window.AvoidAreaType.TYPE_SYSTEM` 一个区域，忽略了 `TYPE_CUTOUT`（挖孔/灵动岛）与 `TYPE_NAVIGATION_INDICATOR`（底部导航指示条/手势条）。挖孔设备上刘海/灵动岛在 `TYPE_SYSTEM` 的 `topRect` 之外；手势导航设备上 `TYPE_SYSTEM.bottomRect.height` 经常为 0，需要叠加 `TYPE_NAVIGATION_INDICATOR`
- `applySafeArea` 在 `loadContent` 之前就执行，但 AppStorage 默认值（20/12 vp）已被各组件 `@StorageLink` 锁定为初始渲染基线。即便后续事件触发了更新，**首次布局**的 padding 已经定型，看起来"修复无效"

## 修复目标

1. 顶部安全区高度 = `max(TYPE_SYSTEM.topRect, TYPE_CUTOUT.topRect)`，并保证最低兜底值（44 vp）
2. 底部安全区高度 = `max(TYPE_SYSTEM.bottomRect, TYPE_NAVIGATION_INDICATOR.bottomRect)`，并保证最低兜底值（24 vp）
3. 初始化时机：在 `getMainWindow` 拿到、设置全屏后**立即**写入 AppStorage，再 `loadContent`；并在 `loadContent` 完成回调里**再写一次**作为双保险
4. `avoidAreaChange` 回调按 type 分类维护本地状态后再合并写出，避免连续回调互相覆盖
5. 保留原有所有 `@StorageLink('statusBarHeight')` / `@StorageLink('navBarHeight')` 用法（不破坏调用方）

## 实施策略

仅修改 `EntryAbility.ets` 一处文件，扩展安全区读取与合并逻辑；调用方组件（TopBar、NavSidebar、AppShell、ServerForm、ServerDetail、PveNodeDetail、VmDetail）均不动。

## 关键决策

- **三区域合并**：`TYPE_SYSTEM` + `TYPE_CUTOUT` + `TYPE_NAVIGATION_INDICATOR` 三个 `AvoidArea` 对象的 `topRect.height` 与 `bottomRect.height` 分别取最大值
- **兜底最小值**：在 vp 单位下设置 `SAFE_TOP_MIN=44`、`SAFE_BOTTOM_MIN=24`，防止设备上报异常（极小或 0）时仍被遮挡
- **初始化时序**：在 `getMainWindow().then` 内的 `setWindowLayoutFullScreen(true)` 之后**同步立即**读取并写入 AppStorage；`loadContent` 完成回调里**再次**读取并写入，保证页面首帧渲染时数据已就绪
- **本地缓存 + 事件分类合并**：`avoidAreaChange` 回调按 `info.type` 更新本地三个 raw 高度缓存，再统一合并写出，避免单一事件只带一种 type 时把其他 type 的数据冲掉
- **单位换算**：`px / density` 等价于 `px2vp(px)`，沿用现有写法
- **错误兜底**：`try/catch` 保持不变；异常时 fallback 到 `SAFE_TOP_MIN/SAFE_BOTTOM_MIN`，保证不出现 0 高度

## 性能 & 可靠性

- `avoidAreaChange` 在折叠屏展开/收起、横竖屏切换时会高频触发，但每次只做几次 max 运算 + 两次 AppStorage 写入，开销可忽略
- AppStorage 写入会驱动所有 `@StorageLink` 组件重渲染——但仅 padding 数值变化，无大范围重绘
- 不引入新依赖、不新增组件、不改变任何 UI 视觉

## 目录与文件

仅修改一个文件：

- `entry/src/main/ets/entryability/EntryAbility.ets`（`onWindowStageCreate` 内 try/catch 块全部重写）
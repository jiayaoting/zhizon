# 智子「我的」与「设置」页面 UX 评审与优化方案

> 评审对象：
> - `entry/src/main/ets/pages/Profile.ets`（319 行，底部 Tab「我的」）
> - `entry/src/main/ets/pages/Settings.ets`（2240 行，设置页）
> - 配套：`common/Theme.ets`（色板）、`components/GlassEffect.ets`（玻璃卡片）、`components/TopBar.ets`、`pages/AppShell.ets`（导航容器）
>
> 评审视角：对标鸿蒙系统「设置」、华为应用市场/会员中心「我的」等成熟页面，从**易用性、信息架构、视觉一致性、无障碍、可维护性**五个维度给出结论。所有改动点均标注了现有代码位置，并给出可直接使用的 ArkTS 片段。

---

## 一、TL;DR（一页结论）

1. **职责错位**：「我的」页同时承担"业务入口 + 系统设置 + 关于"，而「设置」页承担"全部功能配置"。成熟鸿蒙应用的分工是：
   - **「我的」= 身份 + 业务中心**（头像/账号/数据概览 + 资讯、游戏等业务入口 + 右上角"设置"齿轮）
   - **「设置」= 系统配置中心**（账号/外观/功能/安全/数据/关于，支持搜索与二级页）
2. **列表视觉不统一**：两个页面都用 `Column + Row` 手拼列表行，无分隔线、无按压反馈、无统一图标列；成熟鸿蒙设置页是"图标 + 标题 + 当前值 + chevron/开关 + 分隔线"的统一行模型。
3. **页面过载**：Settings.ets 单文件 2240 行、单屏铺 60+ 控件，资讯组和外观组各约 170 行，内嵌表单（RSS 输入、模型选择器）——成熟应用会把复杂表单拆进二级页，主列表只留索引。
4. **危险操作无确认**：清空阅读记录、清空资讯缓存、重置推荐画像、退出华为账号都是点击即执行。
5. **存在空实现入口**：设置-数据组里的「导出配置 / 导入配置 / 清除缓存」点击无任何功能。
6. 其他：版本号硬编码、顶栏/弹层样式不一致、缺少无障碍语义、缺少按压反馈、无搜索、无惰性列表。

**Top 优先级**：
| 级别 | 事项 | 位置 |
|---|---|---|
| P0 | 危险操作加确认、移除空入口、账号退出加确认、版本号动态化 | Settings.ets |
| P0 | 「我的」身份卡显示账号态 + 设置齿轮统一入口 | Profile.ets |
| P1 | 设置页拆二级页（外观/资讯/安全），主页变为分组索引 | Settings.ets + AppShell.ets |
| P1 | 「关于」组从「我的」迁移到「设置」 | Profile.ets / Settings.ets |
| P2 | 统一行组件（图标+分隔线+按压反馈）、弹层样式统一、统计卡升级 | 两个页面 |
| P3 | 无障碍语义、List 惰性渲染、数据驱动配置模型、文件拆分 | 两个页面 |

---

## 二、现状盘点与问题清单

### 2.1 「我的」页（Profile.ets）

**当前结构**（build 顺序）：
```
┌─ headerCard（头像 + 应用名"智子" + 副标题 + "设置 ›"文字链）
├─ 三格统计（⭐收藏 / 👁已读 / 🤖AI调用）
├─ 📰 资讯组（收藏稍后读/点赞/推荐/画像/统计）
├─ 🎮 游戏组（成就/回放/排行榜）
├─ ⚙️ 系统组（设置 / AI 模型）
└─ ℹ️ 关于组（版本/检查更新/用户协议/隐私政策/开源许可/反馈）
```

**问题清单**：

| # | 问题 | 位置 | 类型 |
|---|---|---|---|
| P-A1 | 头部显示的是**应用名**"智子"而非用户身份；头像点击直接进设置页，不符合"身份卡"心智 | L100-118 | 易用性 |
| P-A2 | 没有登录态展示：华为账号昵称已存在（Settings 中 `HuaweiAccountService.getStoredProfile()`），「我的」应显示昵称/登录入口 | L100-118 | 易用性 |
| P-A3 | "设置"入口有两个且形式不一致：头部文字链"设置 ›" + 系统组"设置"行 | L114、L253 | 一致性 |
| P-A4 | 三格统计用 emoji（⭐👁🤖）当图标，与主题色不搭、视觉噪音大；数值无主次层级 | L124-158 | 美观 |
| P-A5 | 统计格子不可点击：收藏数可跳收藏页、AI 调用数可跳 AiCallLog、已读可跳统计页 | L124-128 | 易用性 |
| P-A6 | 入口行只有纯文字 + `›`，无图标列，扫读效率低 | L160-191 | 易用性/美观 |
| P-A7 | 分组标题 emoji 与文字混排（📰🎮⚙️ℹ️），而设置页分组又不用 emoji，两页不一致 | L196/222/246/269 | 一致性 |
| P-A8 | 「关于」组（版本/协议/隐私/开源/反馈）放在「我的」，成熟应用一律放「设置-关于」 | L266-288 | 信息架构 |
| P-A9 | 「检查更新」/「反馈」是 toast 占位（"已是最新版本"/"即将上线"），属于半成品功能入口 | L52-66 | 易用性 |
| P-A10 | 头像等元素无 `accessibilityText`；整页无 `accessibilityRole` 语义 | L73-98 等 | 无障碍 |
| P-A11 | 「AI 模型」配置入口放在「我的-系统」，与设置页内容割裂 | L254 | 信息架构 |

### 2.2 「设置」页（Settings.ets）

**当前结构**（build 顺序）：
```
TopBar("设置", "智子 v1.0.0", showBack)
└─ Scroll
   ├─ 📰 资讯组（~170 行：源开关/频道/模式/画像/翻译模型/智能标签/RSS 表单/清空数据）
   ├─ 游戏组（仅 1 行：游戏设置）
   ├─ 外观组（~100 行：颜色主题/深色模式/背景图+滑块/毛玻璃/液态玻璃/字号/字体/图标/头像）
   ├─ Agent 组（1 开关）
   ├─ 安全组（主密码/生物识别/自动锁定）
   └─ 数据组（华为账号/备份/恢复/导出/导入/清除缓存/自动备份）
```
另有 7 个自绘底部弹层：字号/字体/应用图标/头像/主密码/自动锁定/OPML 导入。

**问题清单**：

| # | 问题 | 位置 | 类型 |
|---|---|---|---|
| P-B1 | 单文件 2240 行、单屏 60+ 控件，可维护性差，滚动性能一般（非惰性渲染） | 全文 | 可维护/性能 |
| P-B2 | 分组顺序混乱：资讯→游戏→外观→Agent→安全→数据。成熟顺序：账号/云同步→外观→功能(资讯/游戏)→安全→数据→关于 | L1851-2199 | 信息架构 |
| P-B3 | 资讯组过载：内嵌 RSS 表单（两个 TextInput + 添加按钮）、两个 NewsModelSelector、多行说明文字 | L1851-2024 | 易用性 |
| P-B4 | 外观组过载：颜色圆点选择器 + 两个开关 + 背景图/滑块 + 两个玻璃开关 + 4 个选择行，混在一个卡片里 | L2037-2137 | 易用性 |
| P-B5 | 危险操作无确认：清空阅读记录(L2009)、清空资讯缓存(L2014)、重置推荐画像(L1882) 点击即执行 | 三处 | 易用性 |
| P-B6 | 已登录时点击"华为账号"行**直接退出登录**，无确认 | L2176-2182 | 易用性（高危） |
| P-B7 | 「导出配置 / 导入配置 / 清除缓存」为空实现，点击只弹 toast 标签名 | L2189-2191 | 易用性 |
| P-B8 | 备份/恢复无进度态：`syncBusy` 已存在但 UI 上没有 LoadingProgress / 按钮禁用 | L2183-2188 | 易用性 |
| P-B9 | 版本号硬编码 `'智子 v1.0.0'`，升级版本后不同步（`AppConstants.appVersion` 已存在） | L1846 | 一致性 |
| P-B10 | 行模型不统一：`valueRow`/背景行/内联开关混用；无分隔线、无按压反馈（`stateStyles`） | L1005-1052 | 视觉 |
| P-B11 | 说明文字大量散落（fsXs 灰色小字），在资讯组尤为密集，视觉噪音大 | L1856-1939 | 美观 |
| P-B12 | 弹层样式不统一：字号/字体/图标/头像用圆角 24 + 玻璃，主密码/自动锁定用圆角 16 + 纯色，高度 70% vs 自适应 | L1210-1841 | 一致性 |
| P-B13 | 分组标题 emoji 使用不一致：资讯组 '📰 资讯'，其余组无 emoji | L1851 | 一致性 |
| P-B14 | 无「关于」分组（版本/协议/隐私/开源/反馈全在「我的」） | — | 信息架构 |
| P-B15 | 无搜索；无二级页（除 NewsSourceSettings/NewsChannelSettings/GameSettings 外全部平铺） | 全文 | 易用性 |
| P-B16 | 无障碍缺失：行无 accessibilityText/Role，Toggle 无标签，滑块无提示 | 全文 | 无障碍 |
| P-B17 | 字号只有手动 5 档，无"跟随系统字号"（成熟鸿蒙设置标配） | L97-98 | 功能 |
| P-B18 | TopBar 与 Scroll 分离，无分组粘性标题（`ListItemGroup` 可做吸顶分组头） | L1843-1850 | 视觉 |

---

## 三、成熟鸿蒙应用怎么做（对标结论）

调研鸿蒙系统「设置」、华为应用市场/会员中心「我的」、以及 ArkUI 官方推荐写法，可归纳为 6 个共识：

1. **分组列表 + 二级页**：主设置页是"分组索引"，每一行只放一个入口；复杂表单放二级页（Navigation push）。不要在主列表内嵌输入框。
2. **统一行模型**：`图标（24vp 圆角底） + 标题 + 可选副标题/当前值 + 右侧控件（chevron / Switch / 值）`，行高 ≥ 48vp，组内用分隔线，组间留白；点击有按压反馈。
3. **数据驱动配置**：把设置项声明为 `SettingGroup[]` 描述符数组（id/title/icon/value/type/action），列表用 `ForEach` 渲染——这样"搜索设置"只是对数组做 filter。
4. **身份卡模式**：「我的」页顶部是身份卡（头像、昵称、ID/账号、登录入口），右上角一个"设置"齿轮，业务分组在下面，系统设置与"关于"不出现。
5. **安全操作有确认**：清空、重置、退出登录一律弹确认框，且用红色按钮表示危险。
6. **无障碍与细节**：点击热区 ≥ 44vp、图标/开关有 accessibility 语义、文字三级层级（主 16/14、次 13、辅 12）、危险文字用 danger 色、版本号从常量读取。

ArkUI 落地对应：
- `List` + `ListItem` + `ListItemGroup`（分组、吸顶标题、惰性渲染）
- `Navigation`/`NavDestination`（二级页）
- `bindSheet`/半模态或统一自绘弹层（圆角、安全区、过渡动画一致）
- `.stateStyles({ pressed: ... })` 按压反馈、`.accessibilityText/.accessibilityRole`
- `Toggle`（Switch）、`Slider`、`Divider`

---

## 四、目标信息架构

### 4.1 「我的」页（重构后）

```
┌─ 身份卡
│   [头像]  昵称 / 华为账号（未登录 → "点击登录"）   ⚙️(设置齿轮)
│   [收藏] [已读] [AI 调用]  ← 三格可点击
├─ 资讯（我的收藏/点赞/推荐/画像/统计）
├─ 游戏（成就/回放/排行榜）
└─ 服务（云同步状态 → 设置-账号；AI 模型 → 设置-对话）
（关于/系统设置不再出现在本页）
```

### 4.2 「设置」页（重构后）

```
设置（TopBar + 搜索框）
├─ 账号与云同步（华为账号/自动备份/立即备份/立即恢复）
├─ 外观（主题色/深色模式/背景图/玻璃/字号/字体/图标/头像 → 二级页）
├─ 资讯（源设置/频道/个性化模式/画像/翻译模型/智能标签/RSS → 二级页）
├─ 游戏（游戏设置）
├─ Agent（Agent 模式开关）
├─ 安全与隐私（主密码/生物识别/自动锁定 → 二级页）
├─ 数据与存储（清空阅读记录/清空缓存 → 确认弹窗）
└─ 关于（版本/检查更新/用户协议/隐私政策/开源许可/反馈）
```

---

## 五、具体改造方案（按优先级）

### P0 易用性修复（低风险，可立即做）

**1. 危险操作统一加确认**（Settings.ets）
清空阅读记录、清空资讯缓存、重置推荐画像，改造为确认后执行：

```ts
// Settings.ets 内新增（或抽到公共 FailureHandling 工具）
private confirmDanger(title: string, message: string, onOk: () => void): void {
  promptAction.showDialog({
    title: title,
    message: message,
    buttons: [
      { text: '取消', color: '#888888' },
      { text: title, color: '#E84026' }   // 危险按钮用红色
    ]
  }).then((result: promptAction.ShowDialogSuccessResponse) => {
    if (result.index === 1) onOk();
  }).catch(() => {});
}

// 使用示例（替换 L2009 的原 onClick）
this.valueRow('清空阅读记录', '', () => {
  this.confirmDanger('清空阅读记录', '将删除全部已读记录，此操作不可恢复。', () => {
    NewsRepository.clearRead().then(() => { this.toast('已清空阅读记录'); });
  });
})
```

**2. 移除空实现入口**（Settings.ets L2189-2191）
「导出配置 / 导入配置 / 清除缓存」删除，或在数据组内合并为一行"配置备份与恢复"说明（功能上线再启用）。

**3. 华为账号行：登录/退出分离**（Settings.ets L2176-2182）
- 未登录：点击 → 登录（现状保留）
- 已登录：点击 → 弹出账号信息（昵称/同步时间）+ 「退出登录」红色确认按钮，而不是直接退出。

**4. 备份/恢复进度态**（Settings.ets L2183-2188）
`syncBusy` 已存在，补 UI：行右侧显示 `LoadingProgress()`，操作期间禁用行点击：

```ts
Row() {
  Text('立即备份').layoutWeight(1).fontSize(this.palette.fsBase)
  if (this.syncBusy) {
    LoadingProgress().width(18).height(18)
  } else {
    Text(this.cloudSyncLast).fontSize(this.palette.fsSm).fontColor(this.palette.textTertiary)
    Text('›').fontSize(this.palette.fsMd).fontColor(this.palette.textTertiary)
  }
}
.width('100%')
.height(48)
.padding({ left: 12, right: 12 })
.onClick(() => { if (!this.syncBusy) this.onCloudBackup(); })
```

**5. 版本号动态化**（Settings.ets L1846）
```ts
import { AppConstants } from '../common/Constants';
// ...
TopBar({ title: '设置', subtitle: AppConstants.appName + ' v' + AppConstants.appVersion, showBack: true, onBackTap: this.onBack })
```

**6. 「我的」身份卡升级**（Profile.ets L68-136）
- 读取 `HuaweiAccountService.getStoredProfile()`，已登录显示昵称，未登录显示"未登录 · 点击登录"；
- 头像点击 → 编辑头像（复用 Settings 的头像选择弹层，或跳设置-外观-头像）；
- 右上角"设置 ›"改为圆形图标按钮（齿轮），删除系统组里的"设置"行（去重）。

```ts
// 头部右侧：统一设置入口
Row() {
  Text('⚙')
    .fontSize(18)
    .fontFamily(this.themeState.palette.fontSans)
    .fontColor(this.themeState.palette.primary)
}
.width(36).height(36)
.borderRadius(18)
.backgroundColor(this.themeState.palette.primaryDim)
.justifyContent(FlexAlign.Center)
.alignItems(VerticalAlign.Center)
.accessibilityText('设置')
.onClick(() => { this.onNavigate('Settings'); })
```

### P1 信息架构重构（中等工作量）

**7. 设置页拆二级页**（推荐顺序：外观 → 资讯 → 安全）
- 新增 `pages/AppearanceSettings.ets`：颜色主题、深色模式、背景图、玻璃、字号、字体、图标、头像（把 Settings.ets L2037-2137 及 4 个弹层搬过去，状态与持久化逻辑一并迁移）；
- 新增 `pages/NewsSettings.ets`：资讯组（L1851-2024）全部搬过去，RSS 表单、模型选择器随之入二级页；
- 主 Settings 页只保留：`分组索引行 + 账号/Agent/安全/数据/关于`；
- 注册路由：`common/Navigation.ets` PageKey 增加 `AppearanceSettings`、`NewsSettings`，`AppShell.ets` `routeDestination` 增加分支（本应用用 AppNavigator 内嵌路由，无需改 main_pages.json）。

**8. 「关于」迁移**（Profile.ets L266-288 → Settings.ets 新增关于组）
- 「我的」删除关于组；设置页末尾新增 `GroupCard({ title: '关于' })`，内容为现有 aboutRows（版本/检查更新/协议/隐私/开源/反馈），版本行显示 `AppConstants.appVersion`。

**9. 「我的」三格统计可点击**（Profile.ets L124-128）
```ts
Row() {
  this.statCell('⭐', this.stats.favoriteCount, '收藏', () => AppNavigator.push('pages/NewsFavorites'))
  this.statCell('👁', this.stats.readCount, '已读', () => AppNavigator.push('pages/NewsStats'))
  this.statCell('🤖', this.stats.aiCallCount, 'AI 调用', () => AppNavigator.push('pages/AiCallLog'))
}
```

### P2 视觉与一致性

**10. 统一行组件**（Settings/Profile 共用）
新建 `components/SettingRow.ets`（示意，按项目 @Component/@Prop 风格）：

```ts
// components/SettingRow.ets
@Component
export struct SettingRow {
  @Prop icon: string = '';          // 可选 emoji/符号
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop showArrow: boolean = true;
  @Prop showDivider: boolean = true;
  @Prop danger: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  onClick: () => void = () => {};

  build() {
    Column() {
      Row({ space: 12 }) {
        if (this.icon.length > 0) {
          Text(this.icon)
            .fontSize(16)
            .width(32).height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.palette.primaryDim)
        }
        Text(this.title)
          .fontSize(this.palette.fsBase)
          .fontColor(this.danger ? this.palette.danger : this.palette.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
            .margin({ right: 6 })
        }
        if (this.showArrow) {
          Text('›').fontSize(this.palette.fsMd).fontColor(this.palette.textTertiary)
        }
      }
      .width('100%')
      .height(48)                      // 热区 ≥ 48vp
      .padding({ left: 12, right: 12 })
      .onClick(() => { this.onClick(); })
      .stateStyles({                   // 按压反馈
        pressed: { .backgroundColor(this.palette.bgHover) }
      })
      if (this.showDivider) {
        Divider().color(this.palette.borderSubtle).strokeWidth(0.5).margin({ left: 12 })
      }
    }
    .width('100%')
  }
}
```

> 注意：`stateStyles` 内联样式写法需以 DevEco SDK 实际支持为准（API 10+ 支持）；若编译报错可退化为 `.onTouch` 手动切换背景色。

**11. 分组标题统一**：去掉正文中的 emoji 混排，改用"分组头 + 图标容器"或纯文字小标题；两页共用 `GroupCard` 样式（标题字号 fsMd + Bold + 组间距 16）。

**12. 弹层样式统一**：所有底部弹层统一圆角 24、玻璃/纯色跟随 glassEnabled、底部 padding 使用 `navBarHeight` 安全区、关闭按钮统一放右上角；把 7 个弹层抽成公共 `BottomSheet` 容器（遮罩 + 面板 + 过渡动画）。

**13. 统计卡视觉升级**（Profile.ets L139-158）：数值用 fsLg + Bold + primary 色，图标改为 24vp 圆角底图标容器（与行组件一致），格子间加 1px 分隔线或圆角卡片留白。

### P3 无障碍 / 性能 / 可维护

**14. 无障碍**：
- 头像、设置齿轮、统计格、每个设置行补 `.accessibilityText(...)`（内容 = 标题 + 当前值 + 状态）；
- Toggle 行补 `.accessibilityRole(AccessibilityRole.SWITCH)` + 状态；
- 危险按钮补 `.accessibilityText('清空阅读记录，危险操作')`。

**15. 列表惰性渲染**：主设置页改用 `List + ListItemGroup`（分组标题可吸顶），行数多时天然惰性；「我的」页条目少可保持 Scroll。

**16. 数据驱动配置模型**：新增 `common/SettingModels.ets`，用描述符数组声明分组与行：

```ts
interface SettingItem {
  key: string;
  title: string;
  icon: string;
  value?: string;
  type: 'nav' | 'switch' | 'danger';
  desc?: string;
}
interface SettingGroup {
  title: string;
  items: SettingItem[];
}
```

主页面 `ForEach` 渲染；实现"搜索设置"只需对 `items` 做 `title/desc` 关键词过滤。

**17. 文件拆分**：Settings.ets 按"页面骨架 / 外观子页 / 资讯子页 / 安全子页 / 弹层组件 / 数据加载"拆分，目标单文件 < 600 行。

---

## 六、分期实施路线

| 阶段 | 内容 | 预估 |
|---|---|---|
| **M1（易用性补课）** | P0 全部：确认弹窗、移除空入口、账号退出确认、进度态、版本动态化、我的页齿轮统一 | 0.5~1 天 |
| **M2（信息架构）** | 设置拆二级页（外观/资讯/安全）、关于迁移、身份卡升级、统计可点击 | 2~3 天 |
| **M3（视觉打磨）** | SettingRow 统一组件、分组头统一、弹层统一、统计卡升级 | 1~2 天 |
| **M4（体验细节）** | 无障碍、搜索设置、List 惰性渲染、数据驱动重构、文件拆分 | 2~3 天 |

建议 M1 立即执行（低风险高收益）；M2 涉及路由注册（Navigation.ets + AppShell.ets），需连同回归测试一起做。

---

## 七、参考资料

- 鸿蒙系统设置页 UI 实现（列表 + Switch + 分组）：https://harmonyosdev.csdn.net/6a4d1e3710ee7a33f288dde7.html
- 通用设置列表组件设计与实践（数据驱动）：https://ost.51cto.com/posts/45740
- ArkUI ListItemGroup 分组列表完全指南：https://ost.51cto.com/posts/43351
- HarmonyOS 二级页面列表设计与实现：https://bbs.huaweicloud.com/blogs/455997
- HarmonyOS 设计规范与设计指南（官方）：https://developer.huawei.com/consumer/cn/design/
- 华为开发者问答：设置列表组件选型：https://developer.huawei.com.cn/consumer/cn/forum/topic/0208215706616838386

---

*文档生成日期：与本次评审同日。代码行号以评审时工作区版本为准，实施前请重新核对。*

---

## 八、实施记录（M1 · P0 已完成）

已按本方案 **M1（P0 易用性补课）** 落地以下改动（2026 年，代码行号以当前工作区为准）：

| 改动 | 文件 |
|---|---|
| 危险操作统一确认：重置推荐画像、清空阅读记录、清空资讯缓存（红色确认按钮） | `entry/src/main/ets/pages/Settings.ets` |
| 华为账号行：未登录→登录；已登录→账号信息弹窗 + 「退出登录」红色确认，不再直接退出 | 同上 |
| 立即备份/立即恢复：同步中显示 `LoadingProgress` 并禁用点击（复用已有 `syncBusy`） | 同上 |
| 移除空实现入口：导出配置 / 导入配置 / 清除缓存 | 同上 |
| TopBar 版本号动态化：`AppConstants.appName + ' v' + AppConstants.appVersion`，不再硬编码 | 同上 |
| 「我的」身份卡升级：显示华为账号昵称/未登录态，点击身份区可登录或进入设置；右上角改为圆形齿轮按钮 | `entry/src/main/ets/pages/Profile.ets` |
| 「我的」系统组去掉重复「设置」行，组标题改为「🤖 AI」（仅保留 AI 模型入口） | 同上 |

> 说明：P3-17 组件化已实施（见下）。剩余可选项：`ListItemGroup` 粘性分组标题（与当前卡片式设计语言冲突，未采用）、「跟随系统字号」、「检查更新/反馈」真实能力接入（功能开发，需后端/市场 SDK）。

### P1 信息架构（已完成）

| 改动 | 文件 |
|---|---|
| 设置页拆二级页：「外观设置」（颜色主题/深色模式/背景图/玻璃效果/字号/字体/图标/头像 + 4 个弹层） | 新增 `pages/AppearanceSettings.ets` |
| 设置页拆二级页：「资讯设置」（源/频道/个性化/翻译与标签模型/RSS/OPML） | 新增 `pages/NewsSettings.ets` |
| 设置主页收敛为分组索引：账号与云同步 / 外观 / 资讯 / 游戏 / Agent / 安全与隐私 / 数据与存储 / 关于（2240 行 → 796 行） | `pages/Settings.ets` 重写 |
| 分组卡片抽为共享组件 | 新增 `components/SettingGroupCard.ets` |
| 「关于」组从「我的」迁移到「设置」（版本/检查更新/协议/隐私/开源/反馈，版本行不再显示箭头） | `pages/Profile.ets`、`pages/Settings.ets` |
| 「我的」三格统计可点击：收藏→收藏页、已读→资讯统计、AI 调用→AiCallLog，并补 accessibilityText | `pages/Profile.ets` |
| 新页面注册到路由表 | `resources/base/profile/main_pages.json` |

### P2 视觉与一致性（已完成）

| 改动 | 文件 |
|---|---|
| 统一行模型：`valueRow/toggleRow/groupRow` 升级为「32vp 圆角图标容器 + 48 行高 + 按压反馈（stateStyles）+ accessibilityText」，全部入口行配图标 | `pages/Settings.ets`、`pages/AppearanceSettings.ets`、`pages/NewsSettings.ets`、`pages/Profile.ets` |
| 分组标题去 emoji，统一为纯文字标题（资讯/游戏/AI），与设置页分组风格一致 | `pages/Profile.ets` |
| 弹层样式统一：主密码/自动锁定/OPML 弹层由圆角 16 + 纯色改为圆角 24 + 玻璃（跟随 glassEnabled），全部弹层底部按 `navBarHeight` 预留安全区 | `pages/Settings.ets`、`pages/NewsSettings.ets`、`pages/AppearanceSettings.ets` |
| 深色模式/背景图/玻璃效果等内联行同步为 48 行高 + 圆角 8 | `pages/AppearanceSettings.ets` |
| 「我的」三格统计视觉升级：图标放入 28vp 主色圆底容器、格子间距 8、补齐无障碍 | `pages/Profile.ets` |
| 备份/恢复进度行升级为统一行样式（图标容器 + 按压反馈 + 无障碍） | `pages/Settings.ets` |

> 说明：共享 `SettingRow` 组件化留作 P3 后续（当前以各页 `@Builder` 落地统一行模型，视觉已一致）。

### P3 无障碍 / 性能 / 可维护（已完成）

| 改动 | 文件 |
|---|---|
| 数据驱动配置模型：`SettingRowKind / SettingActionId / SettingItem / SettingGroup` + `settingMatches` 搜索匹配 | 新增 `common/SettingModels.ets` |
| 设置主页改数据驱动渲染：`visibleGroups()` 按当前状态构造分组，`ForEach` 渲染，`onAction/onSwitch` 统一分发 | `pages/Settings.ets` |
| 「搜索设置」：顶部搜索框，按标题/描述/当前值过滤分组与行，无结果给出空态提示；备份/恢复行按「备份/恢复」关键词参与过滤 | `pages/Settings.ets` |
| List 惰性渲染：主设置页由 Scroll+Column 改为 `List + ListItem`（卡片粒度惰性，宽屏 720vp 居中） | `pages/Settings.ets` |
| 无障碍补全：危险操作行（清空阅读记录/清空资讯缓存/重置推荐画像）红字 + accessibilityText 追加「，危险操作」；全部行此前已具备 accessibilityText | `pages/Settings.ets`、`pages/NewsSettings.ets` |
| 文件拆分：2240 行 → 920 行（弹层组件化与共享 SettingRow 留作可选后续） | `pages/Settings.ets` |

> 说明：关于「我的」页保持 Scroll（条目少，无需惰性）。

### P3-17 组件化收尾（已完成）

| 改动 | 文件 |
|---|---|
| 共享行组件：`SettingRow`（图标+标题+值+箭头+描述+危险态）与 `SettingSwitchRow`（开关行），内聚 48 行高/按压反馈/无障碍 | 新增 `components/SettingRow.ets` |
| 主密码弹窗组件化：`PasswordSheet`（mode/busy/error/input/confirm + 4 个事件回调） | 新增 `components/PasswordSheet.ets` |
| 自动锁定弹窗组件化：`AutoLockSheet`（currentLabel + onSelect/onCancel） | 新增 `components/AutoLockSheet.ets` |
| 四个页面删除各自重复的 `valueRow/toggleRow/groupRow` 构建器，统一使用共享组件（约 30 处调用点） | `Settings.ets`、`AppearanceSettings.ets`、`NewsSettings.ets`、`Profile.ets` |
| Settings.ets：920 行 → 653 行（弹层/行组件外置后清理未使用导入） | `pages/Settings.ets` |

> 至此全部计划项完成：M1 易用性 → P1 信息架构 → P2 视觉统一 → P3 数据驱动/搜索/无障碍 → P3-17 组件化。唯一未做的是 `ListItemGroup` 粘性分组标题——当前为「卡片内分组」设计语言，吸顶标题会与其冲突，如需系统设置式平铺列表可另行立项。
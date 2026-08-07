---
name: ui-redesign-immersive
overview: 对智子 App 进行全面 UI 重构：升级 SDK 至 API 26 以支持沉浸光感、建立响应式深浅色主题系统、重新设计首页与导航层级、支持自定义背景图主题
design:
  styleKeywords:
    - 沉浸光感
    - 科技风
    - 毛玻璃材质
    - 光影层次
    - 弹性交互
    - 深色/浅色双模
    - 多色彩主题
    - 现代简约
  fontSystem:
    fontFamily: HarmonyOS Sans
    heading:
      size: 20px
      weight: 700
    subheading:
      size: 16px
      weight: 600
    body:
      size: 13px
      weight: 400
  colorSystem:
    primary:
      - "#00D9A3"
      - "#3B82F6"
      - "#F59E0B"
      - "#8B5CF6"
      - "#EC4899"
      - "#10B981"
    background:
      - "#0A0E1A"
      - "#131826"
      - "#232A3D"
      - "#F5F6FA"
      - "#FFFFFF"
      - "#F0F1F5"
    text:
      - "#E2E8F0"
      - "#94A3B8"
      - "#1A202C"
      - "#64748B"
    functional:
      - "#10B981"
      - "#F59E0B"
      - "#EF4444"
      - "#3B82F6"
todos:
  - id: upgrade-sdk
    content: 升级SDK到API 26：修改build-profile.json5和entry/build-profile.json5的targetSdkVersion为26，同步更新module.json5添加沉浸光感metadata配置
    status: completed
  - id: rebuild-theme-system
    content: 重建响应式主题系统：重写common/Theme.ets，定义ThemePalette接口、6种颜色主题的深色/浅色共12套完整色板、ThemeManager单例管理器
    status: completed
    dependencies:
      - upgrade-sdk
  - id: update-entry-ability
    content: 改造EntryAbility.ets：添加onConfigurationUpdate监听系统深色模式变化，初始化ThemeManager，动态设置状态栏颜色，在AppStorage中写入初始色板
    status: completed
    dependencies:
      - rebuild-theme-system
  - id: refactor-components
    content: 改造6个通用组件：TopBar/NavSidebar/MetricCard/ProgressBar/StatusBadge/EmptyState添加@StorageLink响应式主题引用，NavSidebar和MetricCard集成沉浸光感材质效果
    status: completed
    dependencies:
      - rebuild-theme-system
  - id: redesign-appshell
    content: 重构AppShell导航框架：精简为5+1底部Tab结构，添加背景图层Stack支持自定义背景图，底部Tab栏集成ULTRA_THIN沉浸光感效果
    status: completed
    dependencies:
      - refactor-components
  - id: redesign-index
    content: 全新设计首页Index.ets：欢迎区+核心指标轮播+快速操作网格+最近活动时间线+服务器快照，集成沉浸光感卡片效果
    status: completed
    dependencies:
      - refactor-components
      - redesign-appshell
  - id: refactor-all-pages
    content: 改造全部19个页面文件的AppTheme静态引用为@StorageLink响应式主题，TerminalView终端区关闭光感保持传统风格
    status: completed
    dependencies:
      - refactor-components
  - id: redesign-settings
    content: 重建设置页面Settings.ets：新增颜色主题选择器(6色圆盘)、深色模式跟随开关、背景图设置入口(全局+分页面)、字号滑块
    status: completed
    dependencies:
      - refactor-all-pages
---

## 用户需求

对"智子"App进行全面UI重构，打造美观、现代化、具有沉浸光感效果的服务器管理工具。

### 核心需求

1. **沉浸光感效果**：按照华为HarmonyOS"沉浸光感"设计指南，为应用组件添加systemMaterial沉浸材质效果，包括全局开启和关键组件的精细化光感设置。

2. **深色模式跟随系统**：应用自动跟随HarmonyOS系统深色/浅色模式切换，不再固定为深色主题。

3. **多颜色主题选择**：提供6种预设颜色主题（终端青绿/海洋蓝/日落橙/极光紫/樱花粉/自然绿），用户可在设置中自由切换。

4. **自定义背景图**：支持灵活的背景图配置——可设置全局默认背景，也可为不同页面分别指定背景图，背景图带半透明遮罩层以保证内容可读性。

5. **首页重新设计**：全新首页布局，包含欢迎区、核心指标概览、快速操作入口、最近活动时间线，替代现有仪表盘风格。

6. **页面层级优化**：重新组织10个一级导航项的层次结构，使导航更清晰合理。

7. **SDK升级**：从API 24升级到API 26，以启用沉浸光感等新特性。

### 视觉期望

- 界面具有现代感、光影层次感，使用沉浸光感材质让卡片和按钮呈现毛玻璃般的通透效果
- 支持完整的浅色/深色双模式，色彩过渡自然
- 用户可自定义主色调，打造个性化外观
- 背景图功能让用户可以用自己的图片作为应用背景

## 技术栈

- **开发语言**：ArkTS (HarmonyOS Stage模型)
- **UI框架**：ArkUI声明式开发
- **目标SDK**：API 26 (HarmonyOS 7)
- **状态管理**：@StorageLink / @StorageProp 全局响应式
- **数据持久化**：RelationalStore (RDB) + preferences
- **沉浸光感**：@kit.ArkUI systemMaterial + uiMaterial.ImmersiveMaterial

## 实现方案

### 整体策略

采用**渐进式重构**策略，分五个层次推进：

1. SDK升级与基础设施搭建
2. 响应式主题系统构建（核心）
3. 沉浸光感效果集成
4. 页面与导航重构
5. 设置页面与用户配置入口

### 响应式主题系统架构

**核心设计**：将现有的静态`AppTheme`类改造为基于`@StorageLink`的响应式主题系统。

**三层架构**：

- **底层：ThemePalette** - 定义6种颜色主题 + 深色/浅色各一套色板（共12套色板），每套包含40+颜色变量
- **中层：ThemeManager** - 单例管理器，负责读取/保存用户主题偏好，计算当前生效色板（结合系统深色模式 + 用户选择的颜色主题），将结果写入AppStorage
- **上层：UI层** - 所有组件通过`@StorageLink('theme')`或`@StorageProp('theme')`获取当前色板，替代原有的`AppTheme.xxx`静态引用

**主题切换流程**：

```
用户选择主题 → ThemeManager.setColorTheme(themeId)
  → 持久化到RDB settings表
  → 计算当前色板（颜色主题 + 系统深色模式）
  → AppStorage.set('themePalette', palette)
  → 所有@StorageLink('themePalette')的组件自动刷新UI

系统深色模式变化 → EntryAbility.onConfigurationUpdate
  → ThemeManager.onSystemDarkModeChange(isDark)
  → 重新计算色板
  → AppStorage.set('themePalette', palette)
  → UI自动更新
```

### 沉浸光感集成策略

- **全局开启**：在module.json5中配置metadata，使Dialog/Toast/Chip/Select/Toggle/Slider等系统组件自动获得光感效果
- **组件级精细控制**：
- NavSidebar：使用REGULAR样式，带applyShadow
- 首页卡片：使用THIN样式 + interactive弹性交互
- 按钮组：使用ULTRA_THIN样式 + colorInvert自动反色
- 弹窗/Sheet：使用THICK样式突出层次
- 终端区域：关闭光感（Material.empty）保持传统终端风格

### 背景图系统设计

- **存储**：使用preferences存储背景配置JSON（{ global: string, pages: Record<string, string> }）
- **实现**：在AppShell的renderPage外层包裹Stack，底层放置背景图层
- **遮罩**：深色模式下使用rgba(0,0,0,0.4)遮罩，浅色模式下使用rgba(255,255,255,0.5)遮罩
- **图片源**：支持从用户相册选择，保存到应用沙箱，使用file://路径加载

### 首页新设计

**布局结构**（自上而下）：

1. **欢迎区**：用户头像 + 问候语 + 日期 + 快捷搜索
2. **核心指标轮播**：4个关键指标（服务器总数/在线数/PVE节点/活跃告警）横向滑动卡片，带沉浸光感效果
3. **快速操作区**：2x3网格（SSH终端/PVE管理/文件管理/快捷命令/批量操作/告警中心），大图标+文字
4. **最近活动时间线**：最近5条操作记录（连接/命令执行/告警），时间轴样式
5. **服务器状态快照**：在线服务器横向滚动列表

### 导航层级优化

**新的一级导航结构**（从10项精简重组为更清晰的层次）：

- **首页**（新设计的总览仪表盘）
- **服务器**（合并原SSH服务器 + SSH终端，作为服务器管理的统一入口）
- **PVE集群**（保持不变）
- **工具箱**（合并文件管理/快捷命令/批量操作）
- **告警**（告警中心）
- **设置**（设置 + 游戏中心作为子项）

手机端底部Tab精简为5项（首页/服务器/PVE集群/工具箱/告警），"更多"包含设置。

### 26个文件的改造模式

所有直接引用`AppTheme.xxx`的文件统一改造为：

- 组件内添加`@StorageLink('themePalette') themePalette: ThemePalette = defaultLightPalette`
- 将`AppTheme.bgBase`替换为`this.themePalette.bgBase`
- 将`AppTheme.textPrimary`替换为`this.themePalette.textPrimary`
- 以此类推，覆盖所有颜色/字号/间距属性

## 实施细节

### 性能考量

- 主题切换仅修改AppStorage中一个对象引用，ArkUI的@StorageLink机制自动触发增量更新，无需手动刷新
- 背景图使用缓存机制，避免重复加载
- 沉浸光感效果由系统渲染，性能开销极低

### 兼容性

- 保留现有所有业务逻辑不变（SSH连接、PVE API、数据持久化等）
- 仅修改UI层和主题层
- SDK升级后验证@ohos/libssh等依赖兼容性

### 日志

- 复用现有hilog，在EntryAbility中添加主题切换日志
- 主题变更时记录：`hilog.info(DOMAIN, 'Theme', '切换主题: color=%{public}s, dark=%{public}s', themeId, isDark)`

## 目录结构

```
entry/src/main/ets/
├── common/
│   ├── Theme.ets              # [MODIFY] 完全重写：ThemePalette接口 + 6套颜色色板 + 深色/浅色各12套 + ThemeManager单例
│   ├── Constants.ets          # [MODIFY] 新增导航项定义（新结构）+ 背景配置接口
│   └── CryptoHelper.ets       # [保持不变]
├── model/
│   └── Models.ets             # [MODIFY] 新增BackgroundConfig、ThemeConfig、ActivityLog等接口
├── entryability/
│   └── EntryAbility.ets       # [MODIFY] 添加系统深色模式监听(onConfigurationUpdate)、初始化ThemeManager、动态状态栏颜色
├── pages/
│   ├── AppShell.ets           # [MODIFY] 重构导航结构(6项主tab)、添加背景图层Stack、集成主题响应、沉浸光感底部栏
│   ├── Index.ets              # [MODIFY] 完全重新设计：欢迎区+指标轮播+快速操作+活动时间线+服务器快照
│   ├── Settings.ets           # [MODIFY] 新增主题选择器(6色预览)、背景图设置(全局+分页面)、深色模式跟随开关
│   ├── Servers.ets            # [MODIFY] 响应式主题改造 + 沉浸光感卡片
│   ├── Terminal.ets           # [MODIFY] 响应式主题改造，终端区保持暗色
│   ├── Files.ets              # [MODIFY] 响应式主题改造
│   ├── Pve.ets                # [MODIFY] 响应式主题改造 + 沉浸光感卡片
│   ├── Alerts.ets             # [MODIFY] 响应式主题改造
│   ├── Commands.ets           # [MODIFY] 响应式主题改造
│   ├── Batch.ets              # [MODIFY] 响应式主题改造
│   ├── Games.ets              # [MODIFY] 响应式主题改造
│   ├── ServerDetail.ets       # [MODIFY] 响应式主题改造
│   ├── ServerForm.ets         # [MODIFY] 响应式主题改造
│   ├── PveNodeDetail.ets      # [MODIFY] 响应式主题改造
│   ├── VmDetail.ets           # [MODIFY] 响应式主题改造
│   ├── Tetris.ets             # [MODIFY] 响应式主题改造
│   ├── Game2048.ets           # [MODIFY] 响应式主题改造
│   ├── Snake.ets              # [MODIFY] 响应式主题改造
│   └── GameHistory.ets        # [MODIFY] 响应式主题改造
├── components/
│   ├── TopBar.ets             # [MODIFY] 响应式主题改造 + 沉浸光感效果
│   ├── NavSidebar.ets         # [MODIFY] 响应式主题改造 + 沉浸光感(REGULAR+shadow)
│   ├── MetricCard.ets         # [MODIFY] 响应式主题改造 + 沉浸光感(THIN+interactive)
│   ├── ProgressBar.ets        # [MODIFY] 响应式主题改造（progressColor使用当前色板）
│   ├── StatusBadge.ets        # [MODIFY] 响应式主题改造（statusInfo使用当前色板）
│   └── EmptyState.ets         # [MODIFY] 响应式主题改造
├── terminal/
│   ├── TerminalView.ets       # [MODIFY] 响应式主题改造，终端区关闭光感
│   ├── AnsiParser.ets         # [保持不变]
│   └── TerminalBuffer.ets     # [保持不变]
└── service/
    └── DatabaseHelper.ets     # [MODIFY] 新增theme_settings表或扩展现有settings表
```

```
entry/src/main/
├── module.json5               # [MODIFY] 添加沉浸光感metadata配置
└── resources/
    └── base/
        ├── element/
        │   └── color.json     # [MODIFY] 更新start_window_background为动态适配
        └── profile/
            └── main_pages.json # [保持不变]
```

```
build-profile.json5            # [MODIFY] 根配置：targetSdkVersion升级到API 26
entry/build-profile.json5      # [MODIFY] 模块配置同步升级
```

## 关键代码结构

### ThemePalette接口（新Theme.ets核心）

```typescript
// 完整色板接口，覆盖所有UI颜色需求
export interface ThemePalette {
  // 背景层次
  bgBase: string;
  bgSurface: string;
  bgSurface2: string;
  bgElevated: string;
  bgHover: string;
  // 边框
  borderSubtle: string;
  borderDefault: string;
  borderStrong: string;
  // 文字
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  // 主色系
  primary: string;
  primaryHover: string;
  primaryDim: string;
  // 状态色
  success: string;
  warning: string;
  danger: string;
  info: string;
  purple: string;
  // 系统
  statusBarContentColor: string;
  isDark: boolean;
  // 字号/间距/圆角（保持不变）
  radiusSm: string;
  radiusMd: string;
  radiusLg: string;
  radiusXl: string;
  sp1: string;
  sp2: string;
  sp3: string;
  sp4: string;
  sp5: string;
  sp6: string;
  sp8: string;
  fsXs: number;
  fsSm: number;
  fsBase: number;
  fsMd: number;
  fsLg: number;
  fsXl: number;
  fs2xl: number;
  fs3xl: number;
  fontSans: string;
  fontMono: string;
}

// 6种颜色主题ID
export enum ColorThemeId {
  CYAN = 'cyan',       // 终端青绿 #00D9A3
  OCEAN = 'ocean',     // 海洋蓝 #3B82F6
  SUNSET = 'sunset',   // 日落橙 #F59E0B
  AURORA = 'aurora',   // 极光紫 #8B5CF6
  SAKURA = 'sakura',   // 樱花粉 #EC4899
  FOREST = 'forest'    // 自然绿 #10B981
}
```

### ThemeManager单例

```typescript
export class ThemeManager {
  private static instance: ThemeManager;
  private currentColorTheme: ColorThemeId = ColorThemeId.CYAN;
  private isSystemDark: boolean = true;
  private context: Context | null = null;

  static getInstance(): ThemeManager { ... }
  init(context: Context): Promise<void> { ... }  // 从RDB加载用户偏好
  setColorTheme(themeId: ColorThemeId): void { ... }  // 保存+RDB+更新AppStorage
  onSystemDarkModeChange(isDark: boolean): void { ... }  // 系统回调
  getPalette(): ThemePalette { ... }  // 根据当前colorTheme+isSystemDark计算色板
  setBackgroundImage(pageKey: string, uri: string): void { ... }
  getBackgroundImage(pageKey: string): string { ... }
}
```

## 设计风格

### 整体风格定位

采用**沉浸光感科技风**设计语言，融合HarmonyOS 7的沉浸光感材质特性，打造具有空间层次感、光影通透感的服务器管理工具。设计兼顾深色/浅色双模式，支持6种颜色主题切换，让工具既专业严谨又充满个性。

### 设计原则

- **光影层次**：利用systemMaterial的5级材质厚度（ULTRA_THIN到ULTRA_THICK）构建清晰的Z轴空间层次
- **色彩灵动**：6种主色调各具特色，每种色调在深色/浅色模式下自动适配最佳对比度
- **弹性交互**：卡片和按钮启用interactive弹性形变，按压时产生微妙的缩放反馈
- **内容优先**：背景图采用半透明遮罩，确保文字始终清晰可读
- **自适应布局**：手机底部Tab / 平板侧边栏，保持现有的三档响应式断点

### 页面规划

#### 页面1：全新首页（Index）

**欢迎区**：顶部用户头像+动态问候语（根据时段显示"早上好/下午好/晚上好"）+ 日期显示，背景使用REGULAR材质营造悬浮感。

**核心指标轮播**：4个关键指标卡片横向Scroll，每张卡片使用THIN沉浸光感材质 + interactive弹性效果。指标包括：SSH服务器总数/在线数、PVE节点数、运行中VM数、未处理告警数。数字使用等宽字体大号展示，带渐变色数值。

**快速操作区**：2x3网格布局，6个入口（终端/PVE/文件/命令/批量/告警）。每个入口为圆角方形图标区 + 文字标签，使用ULTRA_THIN材质 + colorInvert自动反色，点击时interactive弹性反馈。

**最近活动时间线**：左侧时间轴竖线 + 右侧活动卡片，展示最近5条操作记录。每张卡片使用THIN材质，左侧带状态色条（绿=成功/橙=警告/红=失败）。

**服务器状态快照**：横向滚动在线服务器列表，每项显示名称+状态点+CPU/内存微型进度条，使用THIN材质卡片。

#### 页面2：设置页面（Settings）

**外观分组**重新设计：

- **颜色主题选择器**：6个圆形色块横向排列，当前选中带白色边框+勾选图标，点击即时切换预览
- **深色模式**：跟随系统/浅色/深色 三选一SegmentedButton
- **背景图设置**：全局背景/分页面背景两个子项，点击进入图片选择器（系统相册），带预览缩略图
- **字号设置**：小/标准/大 三档滑块

其他分组（常规/终端/安全/通知/数据/关于）保持现有结构，仅做响应式主题改造。

#### 页面3：AppShell框架

**手机端底部Tab**：5个主Tab（首页/服务器/PVE/工具箱/告警），图标+文字，使用ULTRA_THIN材质 + colorInvert，选中态使用主色高亮。

**平板端侧边栏**：NavSidebar使用REGULAR沉浸光感材质 + applyShadow投影，营造悬浮层次感。Logo区域使用THICK材质突出品牌。

**背景图层**：在renderPage外层包裹Stack，底层渲染背景图（如有配置）+ 半透明遮罩，内容层在上方正常渲染。

### 沉浸光感应用策略

| 组件/区域 | 材质样式 | 附加效果 | 说明 |
| --- | --- | --- | --- |
| NavSidebar | REGULAR | applyShadow | 侧边栏悬浮层次 |
| 首页指标卡片 | THIN | interactive | 弹性按压反馈 |
| 快速操作入口 | ULTRA_THIN | colorInvert + interactive | 自动反色文字 |
| 设置分组卡片 | THIN | - | 通透卡片效果 |
| 底部Tab栏 | ULTRA_THIN | colorInvert | 毛玻璃效果 |
| 弹窗/Dialog | THICK | - | 全局metadata自动生效 |
| Toggle/Slider | 全局自动 | - | metadata自动生效 |
| 终端区域 | Material.empty | - | 保持传统黑底终端风格 |
| 游戏页面 | Material.empty | - | 游戏需要精确色彩控制 |


### 6种颜色主题

| 主题 | 主色 | 适用氛围 |
| --- | --- | --- |
| 终端青绿 | #00D9A3 | 经典终端科技风 |
| 海洋蓝 | #3B82F6 | 专业稳重 |
| 日落橙 | #F59E0B | 温暖活力 |
| 极光紫 | #8B5CF6 | 神秘高端 |
| 樱花粉 | #EC4899 | 柔和个性 |
| 自然绿 | #10B981 | 清新自然 |


每种主题在深色模式下背景色系偏冷暗，在浅色模式下偏暖亮，主色调保持一致性。
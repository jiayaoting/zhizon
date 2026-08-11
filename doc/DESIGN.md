# 智子（Zhizon）详细设计文档

> **版本**：v6.0.0
> **平台**：HarmonyOS NEXT（鸿蒙 6+ / 纯血鸿蒙）
> **Bundle Name**：`com.zhizon.manager`
> **开发语言**：ArkTS
> **文档状态**：v6.0 当前实现版（游戏中心 + 多主题系统 + 毛玻璃效果 + 缺陷追踪）

---

## 一、产品概述

### 1.1 产品定位

**智子**是一款运行于鸿蒙 6+ 系统的**轻量休闲应用**，在手机/平板上提供：

- 🎮 **游戏中心**：俄罗斯方块、2048、贪吃蛇，5 级难度可选
- 📱 **全设备自适应**：手机（底部 Tab）、平板、折叠屏自动适配
- 🎨 **多主题系统**：6 套配色 + 亮/暗模式 + 自定义背景 + 毛玻璃效果开关
- 📊 **游戏战绩**：分数记录与历史排行

### 1.2 用户画像

| 角色 | 典型场景 |
|------|---------|
| 休闲用户 | 碎片时间玩小游戏放松，挑战高分 |
| 工具爱好者 | 个性化主题定制，打造专属界面 |

---

## 二、技术架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              AppShell 自适应主框架                │
│  3 档断点 (isSm/isMd/isLg) @StorageLink 响应式   │
├─────────────────────────────────────────────────┤
│                  ArkUI 表现层                    │
│   9 Pages + 5 Components + @State 状态管理      │
│   全异步数据加载 (aboutToAppear + await)         │
├─────────────────────────────────────────────────┤
│                  业务逻辑层                      │
│   DataRepository (CRUD 门面 + 辅助函数)          │
│   BackgroundImporter (沙箱背景图导入)            │
│   DefectWorkflow (缺陷状态机)                    │
│   WindowEnvironmentProvider (窗口环境感知)       │
├─────────────────────────────────────────────────┤
│                  数据访问层                      │
│   DatabaseHelper (RDB Store v4) │ 5 张持久化表  │
│   settings / game_scores /                      │
│   defects / defect_evidence / defect_history /  │
│   defect_fix_results                            │
├─────────────────────────────────────────────────┤
│            HarmonyOS 系统能力                    │
│   CryptoArchitectureKit │ ArkData │ display API │
│   PromptAction │ BackgroundTaskKit              │
└─────────────────────────────────────────────────┘
```

### 2.2 技术选型

| 模块 | 技术方案 | 实现状态 |
|------|---------|---------|
| 开发语言 | ArkTS | ✅ |
| UI 框架 | ArkUI 声明式 + Stage 模型 | ✅ |
| 目标 SDK | HarmonyOS 6.1.1 (API 24) | ✅ |
| 数据存储 | RelationalStore (RDB v4) + 5 表 | ✅ |
| 凭据加密 | AES-256-GCM (CryptoArchitectureKit) | ✅ |
| 响应式 | @StorageLink 跨组件状态 + display API | ✅ |
| 多主题系统 | ThemePalette + 6 配色 + 亮/暗模式 | ✅ |
| 毛玻璃效果 | GlassEffect 半透明背景 + 边框 | ✅ |
| 游戏中心 | 3 游戏 + 5 级难度 + 历史记录 | ✅ |
| 缺陷追踪 | DefectRecord + DefectWorkflow + DefectClassifier | ✅ |
| 导航系统 | NavigationFacade + PageRegistry + 类型化路由参数 | ✅ |

### 2.3 凭据加密设计

**实现文件**：[common/CryptoHelper.ets](file:///workspace/zhizon/entry/src/main/ets/common/CryptoHelper.ets)

| 特性 | 说明 |
|------|------|
| 算法 | AES-256-GCM (CryptoArchitectureKit) |
| 密钥存储 | preferences 持久化（应用沙箱） |
| 首次运行 | 自动生成 256 位随机密钥并持久化 |
| IV | 每次加密生成 12 字节随机 IV |
| 密文格式 | `v1:<base64IV>:<base64Ciphertext+AuthTag>` |

---

## 三、目录结构

```
zhizon/
├── .gitignore
├── README.md
├── codebase-structure.md
├── build-profile.json5                    # 根构建配置
├── hvigorfile.ts
├── oh-package.json5
│
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
        │       └── profile/main_pages.json  # 5 路由（AppShell + Tetris + Game2048 + Snake + GameHistory）
        │
        └── ets/
            ├── entryability/
            │   └── EntryAbility.ets       # 应用入口（延迟初始化加密+数据库）
            │
            ├── common/                    # 主题与常量（7 个）
            │   ├── Theme.ets              # 多主题系统 + ThemePalette + 6 配色 + 亮/暗模式
            │   ├── Constants.ets          # 导航项 + 断点常量 + 尺寸常量
            │   ├── CryptoHelper.ets       # AES-256-GCM 加密/解密
            │   ├── Difficulty.ets         # 游戏难度定义（5 级：超简单/简单/中等/困难/地狱）
            │   ├── FailureHandling.ets    # 统一失败处理（AppFailure + RecoverableResult）
            │   ├── Navigation.ets         # 导航系统（NavigationFacade + 类型化路由参数）
            │   └── ThemeContracts.ets     # 主题契约接口（ThemePalette + PreferenceSnapshot）
            │
            ├── model/                     # 数据模型（1 个）
            │   └── GovernanceModels.ets   # 治理模型（AppFailure + RecoverableResult + DefectRecord 等）
            │
            ├── service/                   # 业务服务层（7 个）
            │   ├── DatabaseHelper.ets    # RDB Store v4 + 5 表 CRUD
            │   ├── DataRepository.ets    # 数据门面 + 缺陷管理 + 偏好持久化
            │   ├── BackgroundImporter.ets # 沙箱背景图导入 + 强度调节
            │   ├── DefectClassifier.ets   # 缺陷分类器
            │   ├── DefectWorkflow.ets     # 缺陷状态机工作流
            │   ├── PickerAdapter.ets      # 选择器适配器
            │   └── WindowEnvironmentProvider.ets # 窗口环境感知
            │
            ├── components/                # 通用组件 (5 个)
            │   ├── TopBar.ets             # 顶栏（响应式 padding）
            │   ├── DifficultyOption.ets   # 难度选择项（图标 + 标签 + 描述 + 选中态）
            │   ├── FixedBottomNav.ets     # 固定底部导航
            │   ├── GlassEffect.ets        # 毛玻璃效果工具（半透明背景 + 边框）
            │   └── GlobalBackgroundLayer.ets # 全局背景层（自定义背景图 + 强度调节）
            │
            ├── pages/                     # 9 个页面
            │   ├── AppShell.ets           # 自适应主框架（底部Tab / 侧边栏切换）
            │   ├── Index.ets              # 首页（欢迎区 + 游戏入口大卡 + 最佳战绩 + 难度速览）
            │   ├── Settings.ets           # 设置（主题 + 背景 + 毛玻璃 + 深色模式）
            │   ├── More.ets               # 更多功能入口（设置）
            │   ├── Games.ets              # 游戏中心入口（3 游戏 + 难度选择器）
            │   ├── Tetris.ets             # 俄罗斯方块（7 种方块 + 旋转/移动/消行）
            │   ├── Game2048.ets           # 2048（4x4 棋盘 + 滑动合并）
            │   ├── Snake.ets              # 贪吃蛇（方向控制 + 食物 + 碰撞检测）
            │   └── GameHistory.ets        # 游戏历史记录（分数 + 难度 + 排行）
            │
            └── test/                      # 单元测试（6 个）
                ├── DefectClassifierTest.ets
                ├── DefectWorkflowTest.ets
                ├── GameLaunchFacadeTest.ets
                ├── NavigationFacadeTest.ets
                ├── WindowEnvironmentProviderTest.ets
                └── WindowEnvironmentSnapshotTest.ets
```

---

## 四、功能模块设计

### 4.1 功能全景图

```
智子 (Zhizon)
├── 1. 游戏中心
│   ├── 俄罗斯方块（5 级难度 + 触屏手势 + 按钮双控制）
│   ├── 2048（5 级难度 + 滑动操作）
│   ├── 贪吃蛇（5 级难度 + 方向控制）
│   ├── 游戏难度选择（5 级：超简单/简单/中等/困难/地狱）
│   └── 游戏历史记录（分数 + 难度 + 排行）
│
├── 2. 多主题系统
│   ├── 6 套配色（终端青绿/海洋蓝/日落橙/极光紫/樱花粉/自然绿）
│   ├── 亮/暗模式（跟随系统或手动）
│   ├── 自定义背景图（沙箱导入 + 强度调节）
│   ├── 毛玻璃效果（开关控制）
│   └── 字号缩放（小/标准/大）
│
├── 3. 缺陷追踪
│   ├── 缺陷记录（症状/步骤/预期/实际/设备信息）
│   ├── 状态机（分析中→待修复→待验证→已确认）
│   ├── 验证证据（静态/代码/设备/用户确认）
│   └── 修复结果（影响范围/验证条件/残余风险）
│
└── 4. 导航系统
    ├── NavigationFacade（页面注册表 + 导航验证）
    ├── 类型化路由参数
    └── 页面可用性检查
```

### 4.2 各模块详细设计

---

#### 模块 1：游戏中心

**实现位置**：[pages/Games.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Games.ets)、[pages/Tetris.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Tetris.ets)、[pages/Game2048.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Game2048.ets)、[pages/Snake.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Snake.ets)、[pages/GameHistory.ets](file:///workspace/zhizon/entry/src/main/ets/pages/GameHistory.ets)、[pages/Index.ets](file:///workspace/zhizon/entry/src/main/ets/pages/Index.ets)、[common/Difficulty.ets](file:///workspace/zhizon/entry/src/main/ets/common/Difficulty.ets)

| 功能 | 实现状态 |
|------|---------|
| 首页游戏入口 | ✅ 3 游戏大卡 + 开始按钮 + 最佳战绩 + 难度速览 |
| 游戏中心入口 | ✅ 3 游戏 + 难度选择器 |
| 俄罗斯方块 | ✅ 7 种方块 + 旋转/移动/消行 + 5 级难度 |
| 2048 | ✅ 4x4 棋盘 + 滑动合并 + 5 级难度 |
| 贪吃蛇 | ✅ 方向控制 + 食物 + 碰撞检测 + 5 级难度 |
| 游戏难度 | ✅ 5 级（超简单/简单/中等/困难/地狱） |
| GameLaunchFacade | ✅ 启动参数验证 + 路由跳转 |
| 游戏历史 | ✅ 分数记录 + 难度标记 + 排行 |

---

#### 模块 2：多主题系统

**实现位置**：[common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets)、[common/ThemeContracts.ets](file:///workspace/zhizon/entry/src/main/ets/common/ThemeContracts.ets)、[service/BackgroundImporter.ets](file:///workspace/zhizon/entry/src/main/ets/service/BackgroundImporter.ets)、[components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets)、[components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets)

| 功能 | 实现状态 |
|------|---------|
| 6 套配色 | ✅ CYAN/OCEAN/SUNSET/AURORA/SAKORA/FOREST |
| 亮/暗模式 | ✅ 跟随系统或手动切换 |
| ThemePalette 接口 | ✅ 30+ 颜色字段 + 8 级字号 |
| 自定义背景 | ✅ 沙箱导入 + 强度调节 |
| 毛玻璃效果 | ✅ 半透明背景 + 边框 + 开关控制 |
| 偏好持久化 | ✅ PreferenceSnapshot + RDB |
| 偏好回滚 | ✅ PreferencePersistenceResult |

---

#### 模块 3：缺陷追踪

**实现位置**：[model/GovernanceModels.ets](file:///workspace/zhizon/entry/src/main/ets/model/GovernanceModels.ets)、[service/DefectWorkflow.ets](file:///workspace/zhizon/entry/src/main/ets/service/DefectWorkflow.ets)、[service/DefectClassifier.ets](file:///workspace/zhizon/entry/src/main/ets/service/DefectClassifier.ets)

| 功能 | 实现状态 |
|------|---------|
| 缺陷记录 | ✅ DefectRecord 完整字段 |
| 状态机 | ✅ 6 状态（分析中/待信息/待修复/待验证/已确认/未复现） |
| 验证证据 | ✅ 4 类型（静态/代码/设备/用户确认） |
| 修复结果 | ✅ 影响范围 + 验证条件 + 残余风险 |
| 状态历史 | ✅ DefectStateHistory 变更记录 |

---

#### 模块 4：导航系统

**实现位置**：[common/Navigation.ets](file:///workspace/zhizon/entry/src/main/ets/common/Navigation.ets)

| 功能 | 实现状态 |
|------|---------|
| NavigationFacade | ✅ 页面注册表 + 导航验证 |
| 类型化路由参数 | ✅ AppShellRouteParams + GameHistoryRouteParams |
| 页面可用性 | ✅ EMBEDDED（内嵌）/ ROUTE（独立路由） |
| 导航结果 | ✅ NavigationSuccess / NavigationFailure |

---

## 五、自适应布局设计

### 5.1 三档响应式断点

**核心文件**：[pages/AppShell.ets](file:///workspace/zhizon/entry/src/main/ets/pages/AppShell.ets)

| 断点 | 宽度范围 | isSm | isMd | isLg | 布局 |
|------|---------|------|------|------|------|
| **手机** | < 600vp | ✅ | ❌ | ❌ | 底部 Tab 导航 |
| **平板（紧凑）** | 600 ~ 839vp | ❌ | ✅ | ❌ | 160vp 紧凑侧边栏 |
| **平板（标准）** | ≥ 840vp | ❌ | ❌ | ✅ | 220vp 标准侧边栏 |

### 5.2 手机布局（isSm = true）

```
┌──────────────────────────────┐
│  SAFE_TOP（动态状态栏高度）    │
│  ┌────────────────────────┐  │
│  │     页面内容 (可滚动)    │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  3 个 Tab（首页/工具箱/更多）│  │
│  │  (高度 56vp)           │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- 3 个主 Tab：首页 / 工具箱 / 更多

### 5.3 平板布局（isSm = false）

```
┌────┬─────────────────────────┐
│    │  SAFE_TOP                │
│ 侧 │  ┌──────────────────┐  │
│ 边 │  │    页面内容       │  │
│ 栏 │  │    (可滚动)       │  │
│    │  └──────────────────┘  │
│ 160│                          │
│ 或 │                          │
│ 220│                          │
└────┴─────────────────────────┘
```

### 5.4 响应式实现机制

```typescript
// AppShell.ets
@StorageLink('windowEnvironmentSnapshot') environment: WindowEnvironmentSnapshot = ...;

aboutToAppear() {
  // WindowEnvironmentProvider 监听窗口尺寸变化
  // 通过 @StorageLink 自动触发全应用响应式更新
}
```

### 5.5 各页面响应式适配

| 页面 | 手机端适配 |
|------|-----------|
| Index | 游戏入口大卡纵向排列，最佳战绩 3 列横排 |
| 所有页面 | padding: `isSm ? 16 : 24` |

---

## 六、数据模型设计

### 6.1 核心实体

业务模型由各页面内联定义（如 Games.ets 的 GameEntry、Index.ets 的 HomeGameEntry/ScoreRow）。

**治理模型**：详见 [model/GovernanceModels.ets](file:///workspace/zhizon/entry/src/main/ets/model/GovernanceModels.ets)，含 `AppFailure`、`RecoverableResult`、`DefectRecord`、`FixEvidence`、`DefectStateHistory`、`FixResult`、`PreferenceSnapshot` 等。

**游戏战绩**：`ScoreEntry`（id, score, level, difficulty, createdAt），定义于 [service/DatabaseHelper.ets](file:///workspace/zhizon/entry/src/main/ets/service/DatabaseHelper.ets)。

### 6.2 数据存储方案

| 数据类型 | 存储方式 | 状态 |
|---------|---------|------|
| 应用设置 | RDB `settings` 表 | ✅ |
| 游戏分数记录 | RDB `game_scores` 表 | ✅ |
| 缺陷记录 | RDB `defects` 表 | ✅ |
| 缺陷证据 | RDB `defect_evidence` 表 | ✅ |
| 缺陷状态历史 | RDB `defect_status_history` 表 | ✅ |
| 缺陷修复结果 | RDB `defect_fix_results` 表 | ✅ |
| 加密主密钥 | preferences 持久化 | ✅ |
| 主题偏好 | RDB `settings` 表（JSON） | ✅ |

### 6.3 数据库表结构

**数据库版本**：v4

**settings 表**：key(PK), value

**game_scores 表**：id(PK), game, score, level, difficulty, created_at

**defects 表**：defect_key(PK), title, symptom, preconditions, steps, expected_behavior, actual_behavior, device_info, source, severity, status, priority, affected_features, fix_result, created_at, updated_at

**defect_evidence 表**：evidence_id(PK), defect_key, evidence_type, conclusion, source, conditions, operator, recorded_at

**defect_status_history 表**：history_id(PK), defect_key, from_status, to_status, operator, trigger, evidence_id, recorded_at

**defect_fix_results 表**：defect_key(PK), scope, expected_behavior, failure_behavior, validation_conditions, residual_risks

---

## 七、UI/UX 设计规范

### 7.1 设计风格

- **风格**：tech-dark（深色终端科技风），支持多主题系统切换
- **多主题系统**：6 套配色（ColorThemeId 枚举：CYAN/OCEAN/SUNSET/AURORA/SAKURA/FOREST），亮/暗模式（跟随系统或手动）
- **毛玻璃效果**：通过 GlassEffect 组件实现半透明背景 + 边框，支持开关控制
- **主色（终端青绿主题，默认）**：`#00D9A3`
- **字体**：系统字体 + JetBrains Mono（代码/数字）

### 7.2 颜色规范

详见 [common/Theme.ets](file:///workspace/zhizon/entry/src/main/ets/common/Theme.ets) 与 [common/ThemeContracts.ets](file:///workspace/zhizon/entry/src/main/ets/common/ThemeContracts.ets)

**ThemePalette 接口**：30+ 颜色字段 + 8 级字号 + `isDark` 标志（区分亮/暗模式）

以下为**终端青绿主题（默认）**色值：

| 用途 | 色值 |
|------|------|
| 背景基色 | `#0A0E1A` |
| 卡片背景 | `#131826` |
| 次级背景 | `#1A2030` |
| 悬浮背景 | `#232A3D` |
| 主色（青绿） | `#00D9A3` |
| 主色半透明 | `rgba(0, 217, 163, 0.15)` |
| 成功 | `#10B981` |
| 警告 | `#F59E0B` |
| 危险 | `#EF4444` |
| 信息 | `#3B82F6` |
| 主文字 | `#E2E8F0` |
| 次文字 | `#94A3B8` |
| 三级文字 | `#8B95A7` |
| 边框 | `#2A3245` |
| 细边框 | `#1E2535` |

### 7.3 毛玻璃效果

通过 [components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets) 实现：

- **GlassLevel**：P1_CARD / P2_LIST / P3_OVERLAY 三档层级
- **GlassStyle.backgroundColor()**：根据开关状态返回半透明背景色
- **GlassStyle.borderColor()**：根据开关状态返回半透明边框色
- **开关控制**：`@StorageLink('glassEffectEnabled')` 全局状态，设置页可切换

### 7.4 安全区域

| 区域 | 值 | 说明 |
|------|---|------|
| SAFE_TOP | 动态 | 通过 WindowEnvironmentProvider 获取状态栏高度 |
| SAFE_BOTTOM | 动态 | 通过 WindowEnvironmentProvider 获取手势区域高度 |

### 7.5 字号系统

| 变量 | 值 | 用途 |
|------|---|------|
| fsXs | 10 | 标签/徽章 |
| fsSm | 12 | 副文字/时间 |
| fsBase | 13 | 列表正文 |
| fsMd | 14 | 卡片标题 |
| fsLg | 16 | 区块标题 |
| fsXl | 20 | 页面标题 |
| fs2xl | 26 | 指标大数字 |
| fs3xl | 32 | 特大数字 |

---

## 八、通用组件设计

### 8.1 组件清单（5 个）

| 组件 | 文件 | 说明 |
|------|------|------|
| TopBar | [components/TopBar.ets](file:///workspace/zhizon/entry/src/main/ets/components/TopBar.ets) | 顶栏，`@StorageLink('isSm')` 响应式 padding |
| DifficultyOption | [components/DifficultyOption.ets](file:///workspace/zhizon/entry/src/main/ets/components/DifficultyOption.ets) | 难度选择项（图标 + 标签 + 描述 + 选中态） |
| FixedBottomNav | [components/FixedBottomNav.ets](file:///workspace/zhizon/entry/src/main/ets/components/FixedBottomNav.ets) | 固定底部导航 |
| GlassEffect | [components/GlassEffect.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlassEffect.ets) | 毛玻璃效果工具（半透明背景 + 边框 + 开关） |
| GlobalBackgroundLayer | [components/GlobalBackgroundLayer.ets](file:///workspace/zhizon/entry/src/main/ets/components/GlobalBackgroundLayer.ets) | 全局背景层（自定义背景图 + 强度调节） |

---

## 九、页面路由与导航

### 9.1 主框架导航（AppShell）

所有页面通过 AppShell 加载：
- 手机端：底部 Tab 切换 `currentPage`
- 平板端：侧边栏点击切换 `currentPage`
- 使用 `@Builder renderPage()` 根据 `currentPage` 渲染对应子页面

### 9.2 导航结构

**主导航（3 项）**：
- 首页（Index）
- 工具箱（Toolbox）→ 游戏中心
- 更多（More）→ 设置

### 9.3 页面跳转关系

```
AppShell (主框架)
├── Index (首页)
│   └──> Games (游戏中心) ──> Tetris / Game2048 / Snake ──> GameHistory
├── Toolbox (工具箱)
│   └──> Games ──> Tetris / Game2048 / Snake ──> GameHistory
└── More (更多)
    └──> Settings
```

### 9.4 子页面跳转

- **进入游戏页面**：通过 `NavigationFacade` 统一入口，内部进行页面注册表查找 + 导航参数验证后跳转
- **返回**：`router.back()` 或 `router.replaceUrl()`
- **传参方式**：类型化 `RouteParams` 对象，接收方 `router.getParams() as XxxRouteParams`
- **导航结果**：`NavigationSuccess` / `NavigationFailure`，支持页面可用性检查（EMBEDDED 内嵌 / ROUTE 独立路由）

---

## 十、ArkTS 严格模式约束

| 规则 | 说明 | 应对 |
|------|------|------|
| arkts-no-any-unknown | 禁用 `any`/`unknown` | 使用显式类型标注 |
| arkts-no-untyped-obj-literals | 对象字面量需显式类型 | 使用 interface 或 Record |
| arkts-no-structural-typing | 不支持结构类型 | 使用 class + constructor |
| arkts-no-destruct-decls | 禁用解构声明 | 改用独立变量赋值 |
| arkts-no-private-identifiers | 禁用 `#` 私有标识符 | 使用 `private` 关键字 |
| arkts-no-spread | 禁用展开运算符 | 显式构建对象 / 使用 slice() |

---

## 十一、开发历史

### 11.1 里程碑

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1** | 项目骨架、设计系统、导航、UI 框架 | ✅ |
| **M2** | 数据持久化（RDB v3）、CRUD、默认数据播种 | ✅ |
| **M3** | 全异步改造、响应式布局（3 档断点） | ✅ |
| **M4** | 游戏中心 + 多主题系统 + 缺陷追踪系统 | ✅ |
| **M5** | 毛玻璃效果 + 自定义背景 + 偏好持久化优化 | ✅ |
| **M6** | 移除 SSH/PVE 相关代码，清理孤儿组件，重新设计首页布局，聚焦游戏中心 | ✅ |

### 11.2 关键修复记录

| 日期 | 修复内容 |
|------|---------|
| 2026-08-05 | AppShell `@StorageLink` 响应式状态修复（默认 isSm=true 兜底） |
| 2026-08-05 | 3 档断点布局（手机底部Tab / 紧凑侧栏 / 标准侧栏） |
| 2026-08-05 | 安全区域适配（动态状态栏高度） |
| 2026-08-05 | ArkTS 严格模式合规修复 |
| 2026-08-07 | 游戏中心（俄罗斯方块 + 2048 + 贪吃蛇 + 5 级难度） |
| 2026-08-07 | 多主题系统（6 配色 + 亮/暗模式 + 自定义背景） |
| 2026-08-07 | 导航系统重构（NavigationFacade + 类型化路由参数） |
| 2026-08-07 | 缺陷追踪系统（DefectRecord + DefectWorkflow + DefectClassifier） |
| 2026-08-07 | 治理模型（GovernanceModels + PreferenceSnapshot） |
| 2026-08-11 | 毛玻璃效果实现（半透明背景 + 边框 + 开关控制） |
| 2026-08-11 | 跟随系统深色模式立即生效修复 |
| 2026-08-11 | 全局背景图设置修复（沙箱 URI 校验） |
| 2026-08-11 | 移除全部 SSH/PVE 相关代码（服务、页面、模型、终端渲染、Go Agent） |
| 2026-08-11 | 清理孤儿组件（StatusBadge/ProgressBar/MetricCard/EmptyState/NavSidebar/ArrayDataSource） |
| 2026-08-11 | 首页重新设计为游戏入口大卡 + 最佳战绩 + 难度速览 |

---

## 十二、附录

### 12.1 参考资源

- HarmonyOS 开发文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/
- ArkUI 组件参考：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/
- ArkTS 严格模式：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-syntax-rules
- CryptoArchitectureKit：HarmonyOS 加密框架

### 12.2 文档版本

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0.0 | 2026-08-04 | 初始版本，对应 MVP 实现 |
| v2.0.0 | 2026-08-05 | 数据持久化 (RDB)、全异步改造、自适应布局 |
| v3.0.0 | 2026-08-07 | 游戏中心、多主题系统、导航系统重构、缺陷追踪系统、治理模型 |
| v4.0.0 | 2026-08-07 | 数据库 v4、MockData 移除、单元测试 |
| v5.0.0 | 2026-08-11 | 毛玻璃效果、移除全部 SSH/PVE 代码、首页布局重新设计 |
| v6.0.0 | 2026-08-11 | 清理孤儿组件、首页聚焦游戏中心，应用定位精简为游戏中心 + 多主题系统 |

---

**智子（Zhizon）** · HarmonyOS NEXT 原生应用 · MIT License

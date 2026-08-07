---
name: fix-missing-closing-braces
overview: 修复三个 ArkTS 文件中 build() 方法缺失的闭合括号，解决编译错误 '}' expected。
todos:
  - id: fix-pve-node-detail
    content: 在 PveNodeDetail.ets 第554行后插入 `}` 闭合 Stack()
    status: completed
  - id: fix-server-detail
    content: 在 ServerDetail.ets 第392行后插入 `}` 闭合 Stack()
    status: completed
  - id: fix-vm-detail
    content: 在 VmDetail.ets 第583行后插入 `}` 闭合 Stack()
    status: completed
  - id: verify-build
    content: 验证三个文件编译通过
    status: completed
    dependencies:
      - fix-pve-node-detail
      - fix-server-detail
      - fix-vm-detail
---

## 用户需求

修复项目编译错误：三个 ArkTS 页面文件（PveNodeDetail.ets、ServerDetail.ets、VmDetail.ets）的 `build()` 方法中 `Stack()` 组件缺少闭合 `}`，导致 `'}' expected` 编译错误。

## 核心功能

在每个受影响文件的 `build()` 方法中，于 `FixedBottomNav({...})` 组件声明之前插入缺失的 `}`，用于闭合 `Stack()` 组件，使嵌套结构正确。

## 技术方案

### 问题分析

三个文件的 `build()` 方法内组件嵌套结构完全一致：

```
Column() {                          // 外层 Column
  Stack() {                         // Stack（缺失闭合括号）
    GlobalBackgroundLayer()
    Row() {                         // Row
    Column() {                      // 内层 Column
      TopBar({...})
      if (loading) {...} else if (...) {...}
    }                               // 关闭内层 Column
    .layoutWeight(1)...             // 内层 Column 属性链
  }                                 // 关闭 Row
  .layoutWeight(1)...               // Row 属性链
  【缺少 } 关闭 Stack】              // ← 缺失
  FixedBottomNav({...})             // 应在外层 Column 内、Stack 外
}                                   // 关闭外层 Column
```

当前代码在 Row 属性链结束后，直接写 `FixedBottomNav`，导致 Stack 未闭合。FixedBottomNav 应该是外层 Column 的子组件、Stack 的兄弟组件。

### 修复方案

在每个文件的 `FixedBottomNav({...})` 调用之前，插入一个 `}` 来闭合 `Stack()`。插入点紧接在 `.backgroundColor(Color.Transparent)` 行之后。

### 受影响文件

1. `entry/src/main/ets/pages/PveNodeDetail.ets` — 在第 554 行后插入 `}`
2. `entry/src/main/ets/pages/ServerDetail.ets` — 在第 392 行后插入 `}`
3. `entry/src/main/ets/pages/VmDetail.ets` — 在第 583 行后插入 `}`
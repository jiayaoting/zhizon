---
name: ssh-direct-mode-default
overview: 隐藏 Agent 模式入口（代码保留），默认使用直连模式；增强分段选择器视觉对比度；优化测试连接失败提示
todos:
  - id: switch-defaults
    content: 切换所有 connectionMode 默认值：ServerForm.ets @State 初始值、Settings.ets 初始值和加载默认值、SshService.ets toConfig 和 getEngine fallback、DatabaseHelper.ets SQL DDL 和读写 fallback，全部从 agent 改为 direct
    status: completed
  - id: hide-agent-ui
    content: 隐藏 Agent 模式入口：ServerForm.ets 连接模式卡片去掉分段选择器改为固定显示直连模式标签，Settings.ets 连接设置卡片同样处理。AgentEngine/AgentClient 代码完整保留
    status: completed
    dependencies:
      - switch-defaults
  - id: enhance-segmented-contrast
    content: 增强分段选择器视觉对比度：segmented Builder 中未选中项 .fontColor 从 AppTheme.textSecondary 改为 AppTheme.textPrimary
    status: completed
  - id: improve-error-feedback
    content: 优化 testConnection 失败提示：ServerForm.ets 中连接失败时给出 SSH 端口、防火墙等直连模式专项排查建议
    status: completed
    dependencies:
      - switch-defaults
---

## 用户需求

1. **Agent 模式暂不可用**：Agent 模式需要目标服务器部署 `zhizon-agent` 服务（端口 9527），当前不具备使用条件。关闭 Agent 模式入口，但代码保留不删除，待后续条件成熟再开放
2. **默认使用直连模式**：将所有默认值从 `agent` 改为 `direct`，包括表单、数据库、设置页、服务层
3. **分段选择器视觉修复**：直连模式在深色主题下文字颜色与背景对比度低，看起来像灰色不可选。增强未选中项的视觉对比度
4. **测试连接失败提示优化**：直连模式失败时给出 SSH 端口、防火墙等排查建议

## 技术方案

### 修改范围

涉及 4 个文件，所有改动遵循"代码保留、入口隐藏、默认值切换"原则：

| 文件 | 修改内容 |
| --- | --- |
| `entry/src/main/ets/pages/ServerForm.ets` | 默认值改 direct、连接模式卡片仅显示直连模式、增强 segmented 对比度、优化失败提示 |
| `entry/src/main/ets/pages/Settings.ets` | 默认值改 direct、连接设置卡片仅显示直连模式 |
| `entry/src/main/ets/service/SshService.ets` | `toConfig()` 和 `getEngine()` 默认值改 direct |
| `entry/src/main/ets/service/DatabaseHelper.ets` | SQL 默认值、读取默认值、写入默认值均改 direct |


### 实施策略

**1. 默认值全线切换为 direct**

`connectionMode` 的默认值分布在多个位置，需要一次性全部更新：

- ServerForm 表单 `@State` 初始值
- Settings 设置页状态初始值和加载默认值
- SshService 中 `toConfig()` 和 `getEngine()` 的 fallback
- DatabaseHelper SQL DDL `DEFAULT 'direct'` 和读写 fallback

**2. 隐藏 Agent 模式入口（代码保留）**

- ServerForm 连接模式卡片：不再显示双选项分段选择器，改为固定显示"直连模式"标签 + 说明文字
- Settings 连接设置卡片：同上，固定显示直连模式
- `AgentEngine`、`AgentClient`、`agent/` 目录代码完全保留不动

**3. 分段选择器视觉增强**

`segmented` Builder 是共享组件，同时用于认证方式切换（密码/密钥）。将未选中项文字色从 `AppTheme.textSecondary` 改为 `AppTheme.textPrimary`，增强对比度。两处使用场景（认证方式 + 连接模式）均受益。

**4. 测试连接失败优化**

`testConnection()` 中失败时，提示信息明确指向 SSH 相关排查：检查 SSH 服务状态、端口是否正确、防火墙是否放行。
---
name: ssh-connection-mode-fix
overview: 诊断并修复 SSH 连接模式的两个问题：(1) Agent 模式连接失败——增加更明确的错误提示和部署指引；(2) 直连模式视觉上像不可选——增强未选中选项的视觉对比度
todos:
  - id: enhance-segmented-visual
    content: 增强 ServerForm.ets 中 segmented Builder 未选中项的视觉对比度，将文字色从 textSecondary 改为 textPrimary
    status: pending
  - id: improve-agent-error-msg
    content: 优化 SshService.ets 中 AgentEngine.connect() 的错误消息，区分连接拒绝和网络不可达场景
    status: pending
  - id: enhance-test-connection-feedback
    content: 改进 ServerForm.ets 中 testConnection() 的失败提示，根据 connectionMode 给出针对性排查建议
    status: pending
    dependencies:
      - improve-agent-error-msg
  - id: add-mode-description
    content: 在 ServerForm.ets 连接模式卡片中增加各模式的前置条件说明和 Agent 部署指引
    status: pending
---

## 用户需求

新增 SSH 服务器时存在两个问题需要修复：

1. **Agent 模式连接失败**：IP、账号、密码均正确，但 agent 模式测试连接失败。根因是 Agent 模式要求目标服务器运行 `zhizon-agent` Go 服务（端口 9527），用户可能未部署该服务。当前错误提示不够友好，未引导用户排查和部署 Agent。

2. **直连模式视觉上像不可选**：分段选择器中"直连模式"选项在深色主题下使用了 `AppTheme.textSecondary`（#94A3B8）文字色和 `AppTheme.bgSurface2`（#1A2030）背景色，视觉上与禁用状态相似，用户误以为不可点击。实际上功能正常。

## 修复目标

- 改进 Agent 模式连接失败时的错误提示，提供清晰的 Agent 部署指引
- 增强"连接模式"分段选择器未选中选项的视觉对比度，消除"灰色不可用"的错觉
- 在测试连接失败时根据 `connectionMode` 给出针对性排查建议
- 在"连接模式"卡片中增加各模式的简要说明，帮助用户理解两种模式的区别和前置条件

## 技术方案

### 修改范围

仅涉及两个文件：

1. **`entry/src/main/ets/pages/ServerForm.ets`** — 改进连接测试错误提示、增强分段选择器视觉对比度、增加模式说明
2. **`entry/src/main/ets/service/SshService.ets`** — 为 `AgentEngine.connect()` 和 `SshService.testConnection()` 提供更丰富的错误信息，支持区分 agent 模式和直连模式的错误提示

### 实施策略

#### 1. 分段选择器视觉增强（ServerForm.ets）

当前 `segmented` Builder 中未选中项的样式：

```typescript
.fontColor(selected === idx ? AppTheme.bgBase : AppTheme.textSecondary)  // #94A3B8
.backgroundColor(selected === idx ? AppTheme.primary : AppTheme.bgSurface2)  // #1A2030
```

问题：`textSecondary`（#94A3B8）在 `bgSurface2`（#1A2030）背景上对比度不足。

修复：将未选中项的文字色改为 `AppTheme.textPrimary`（#E2E8F0），保持足够的视觉对比度。同时为未选中项增加微弱的边框或 hover 态效果（可选，`segmented` 是共享 Builder，需要评估影响范围）。

该 Builder 在 ServerForm 中用于两个地方：认证方式切换、连接模式切换。两处均应受益于对比度增强。

#### 2. 连接模式说明增强（ServerForm.ets）

在"连接模式"卡片中，将现有的简短说明替换为更详细的信息，包括：

- Agent 模式需要目标服务器运行 zhizon-agent 服务（端口 9527）
- 直连模式直接使用 SSH 协议连接，无需额外部署
- 当用户选择 Agent 模式时额外显示 Agent 部署指引

#### 3. 测试连接错误信息增强（ServerForm.ets）

修改 `testConnection()` 方法，根据 `this.connectionMode` 生成不同的失败提示：

- **Agent 模式失败**：提示检查目标服务器是否已部署并启动 `zhizon-agent` 服务、端口 9527 是否可达
- **直连模式失败**：提示检查 SSH 服务是否运行、防火墙是否放行 SSH 端口

#### 4. AgentEngine 错误信息优化（SshService.ets）

在 `AgentEngine.connect()` 中，捕获网络错误时区分"连接被拒绝"（目标可达但端口未监听）和"超时/不可达"（网络不通），提供更精确的错误消息。`SshService.testConnection()` 中在捕获异常时也传递模式信息。

### 关键决策

- **不修改 `segmented` Builder 签名**：保持通用性，仅调整颜色常量引用
- **不新增组件**：所有改动在现有文件内完成
- **保持向后兼容**：`AgentEngine` 和 `SshService` 的 API 签名不变，仅增强错误消息内容
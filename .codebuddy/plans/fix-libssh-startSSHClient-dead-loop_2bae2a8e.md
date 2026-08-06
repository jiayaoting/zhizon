---
name: fix-libssh-startSSHClient-dead-loop
overview: 修复 @ohos/libssh 的 startSSHClient 原生层死循环导致 Promise 永不 resolve 的问题。原生层在 SSH 连接成功后进入 while(!isStop) 死循环，只有调用 stopSSHClient 才能退出，导致连接成功却超时。方案：通过 callback 判断连接状态，不依赖 Promise resolve。
todos:
  - id: fix-callback-connect
    content: 修改 SshService.ets 中 DirectEngine.connect()：新增 waitForCallback() 方法通过 callback 事件判断连接结果，修改 connect() 调用 waitForCallback 替代 raceTimeout，连接成功后立即返回 true
    status: completed
  - id: verify-lint
    content: 编译验证：检查 lint 错误，确保类型定义正确
    status: completed
    dependencies:
      - fix-callback-connect
---

## 问题描述

直连模式 SSH 测试连接始终提示"连接超时（12秒）"，但用其他 SSH 客户端软件可以正常连接同一台服务器。

## 根因分析（已通过源码确认）

`@ohos/libssh` 原生层 `startSSHClient` 的 NAPI 实现存在设计缺陷：

1. execute 回调中，SSH 连接成功后进入 `while(!isStop) { sleep(1); }` 死循环
2. 只有调用 `stopSSHClient()` 将 `isStop` 设为 `true`，execute 回调才会退出
3. 只有 execute 回调退出后，complete 回调才会执行 `napi_resolve_deferred()` resolve Promise
4. 结果：即使 TCP + SSH 认证全部成功，Promise 也永不 resolve

我们的 `raceTimeout` 在 15 秒后正确 reject 了，表现形式是"超时"——但连接实际上已经建立了。

## 修复目标

让 `DirectEngine.connect()` 不依赖 `startSSHClient` 返回的 Promise 来获取结果，改为通过 callback 参数来判断连接成功或失败。保持 15 秒超时兜底以处理网络不可达场景。

## 技术方案

### 修复策略

将 `DirectEngine.connect()` 从"等待 Promise resolve"改为"等待 callback 事件"：

1. **新增 `waitForCallback()` 方法**：用 `new Promise` 包装 callback 事件

- callback event=0（`SSH2_START_SUCCESS`）→ resolve()
- callback event≠0（`SSH2_START_FAILED`）→ reject()
- 15 秒超时 → reject()（处理网络不可达）

2. **修改 `connect()` 方法**：调用 `waitForCallback()` 替代 `raceTimeout()`，连接成功后直接 `return true`

3. **保留 `raceTimeout()` 方法**（已不再使用，可清理，但保留不影响）

### 关键常量

- callback event=0 → 连接成功
- callback event≠0 → 连接失败

### 需要修改的文件

仅 `entry/src/main/ets/service/SshService.ets` 一个文件，修改 `DirectEngine` 类的 `connect()` 方法及相关辅助方法。
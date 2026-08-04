# 智子 (Zhizon)

> HarmonyOS NEXT 原生应用 · SSH 连接 Linux + Proxmox VE 管理

## 项目简介

智子是一款面向运维工程师、家庭实验室玩家、中小团队的**一体化服务器管理工具**，运行于鸿蒙 6+ 系统，提供：

- 🔐 **SSH 终端**：远程连接任意 Linux 服务器，多标签会话
- 🖥️ **PVE 管理**：通过 Proxmox VE REST API 管理虚拟机/容器/存储/集群
- 📊 **资源监控**：实时查看服务器与虚拟机的 CPU/内存/磁盘/网络
- 📁 **SFTP 文件管理**：双栏文件浏览、上传下载
- 🔔 **告警通知**：资源异常、虚拟机状态变化主动推送
- ⚡ **批量操作**：多服务器命令执行、VM 批量开关机

## 技术栈

- **开发语言**：ArkTS
- **UI 框架**：ArkUI 声明式 + Stage 模型
- **目标 SDK**：HarmonyOS 6.0 (API 12+)
- **数据存储**：Preferences + RelationalStore
- **网络**：NetworkKit (HTTP) + NAPI (libssh2 规划中)

## 项目结构

```
zhizon/
├── AppScope/              # 应用全局配置
├── entry/                 # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/   # UIAbility
│       │   ├── common/         # 主题与常量
│       │   ├── model/          # 数据模型
│       │   ├── service/        # 业务服务
│       │   ├── components/     # 通用组件
│       │   └── pages/          # 页面
│       ├── resources/          # 资源文件
│       └── module.json5        # 模块配置
└── build-profile.json5        # 构建配置
```

## 页面清单

| 页面 | 说明 |
|------|------|
| Index | 总览仪表盘 |
| Servers | SSH 服务器列表 |
| ServerDetail | 服务器监控详情 |
| Terminal | SSH 终端 |
| Files | SFTP 文件管理 |
| Pve | PVE 集群列表 |
| PveNodeDetail | PVE 节点详情 |
| VmDetail | 虚拟机详情 |
| Commands | 快捷命令库 |
| Batch | 批量操作 |
| Alerts | 告警中心 |
| Settings | 设置 |

## 开发环境

- DevEco Studio 6.0+
- HarmonyOS SDK 6.0+
- ohpm 5.0+

## 运行

1. 用 DevEco Studio 打开本项目
2. 配置签名（自动签名即可）
3. 连接鸿蒙设备或模拟器
4. 点击运行

## 说明

当前为 MVP 骨架版本，使用 Mock 数据。SSH 协议层（libssh2 NAPI 封装）和真实 PVE API 对接在后续版本实现。

## License

MIT

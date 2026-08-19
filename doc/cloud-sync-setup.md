# 华为账号 + 云同步接入说明

> 智子云同步采用「**Account Kit（华为账号）** + **Cloud Foundation Kit 云存储（AppGallery Connect 云存储桶）**」方案。
>
> 说明：Huawei Drive Kit（用户个人华为云空间/云盘）**在 HarmonyOS NEXT 中暂未开放**，因此数据文件存放在开发者自己的 AGC 云存储桶中，并用华为账号的 OpenID/UnionID 作为用户隔离依据（当前版本为单文件备份 zhizon-backup-v3.json，多用户隔离可在后续把 OpenID 拼入云路径）。

## 1. 代码已实现的部分

- service/HuaweiAccountService.ets：登录 / 获取资料 / 取消授权（scopes: openid + profile）
- service/CloudSyncService.ets：备份载荷组装（设置 + 战绩 + 成就 + 全部对话）、上传/下载、恢复
- pages/Settings.ets → 「数据」分组：华为账号、立即备份、立即恢复
- 未配置 AGC 或云侧不可用时，自动降级为**本地备份**（写入应用 cache 目录）

## 2. 上线前需要做的事

1. 在 AppGallery Connect 创建应用并开通 Cloud Foundation Kit → 云存储。
2. 创建/绑定一个存储桶（bucket 名称 9–63 位小写字母数字与短横线）。
3. 下载 agconnect-services.json 放入 entry/src/main/resources/rawfile/（或按 DevEco 向导配置）。
4. 在 CloudSyncService.ets 中把 cloudStorage.bucket() 改为 cloudStorage.bucket('你的桶名')（如需指定非默认桶）。
5. 在 AGC 中为「华为账号服务」开启 openid + profile 两个 scope。
6. 真机（需登录华为账号）运行，进入「设置 → 数据」验证登录、备份、恢复。

## 3. 云路径与隐私

- 云文件：zhizon-backup-v3.json
- 载荷包含：本地偏好、战绩、成就、AI 对话全文（含思考过程）
- 建议后续在云路径中加入 openId 前缀实现多账号隔离，并对敏感对话加密后上传

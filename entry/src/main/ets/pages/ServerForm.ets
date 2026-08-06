// 智子 - 添加/编辑 SSH 服务器表单
// 支持：密码/密钥认证切换、PEM 粘贴 + 文件选择器导入、Agent/直连模式选择、测试连接、加密持久化
import { router, promptAction } from '@kit.ArkUI';
import { picker, fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DataRepository, generateId } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { Server, ServerMetrics } from '../model/Models';

const EMPTY_METRICS: ServerMetrics = {
  cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0
};

// 表单分组卡片
@Component
struct FormCard {
  @Prop title: string;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(AppTheme.fsMd)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }
}

@Entry
@Component
export struct ServerFormPage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  // 编辑模式
  private serverId: string = '';
  private isEdit: boolean = false;

  // 基本信息
  @State name: string = '';
  @State host: string = '';
  @State port: string = '22';
  @State username: string = '';
  @State group: string = '';
  @State tags: string = '';

  // 认证
  @State authType: 'password' | 'key' = 'password';
  @State password: string = '';
  @State pemContent: string = '';
  @State pemFileHint: string = '';

  // 连接模式（Agent 模式暂不可用，默认直连）
  @State connectionMode: 'direct' | 'agent' = 'direct';

  // 交互状态
  @State testing: boolean = false;
  @State saving: boolean = false;
  @State testResult: string = '';
  @State testOk: boolean = false;

  private base64: util.Base64Helper = new util.Base64Helper();

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, string>;
    this.serverId = params?.serverId || '';
    if (this.serverId) {
      this.isEdit = true;
      await this.loadForEdit();
    }
  }

  // 编辑模式：加载服务器信息与已保存凭据
  private async loadForEdit(): Promise<void> {
    try {
      const server = await DataRepository.getServer(this.serverId);
      if (!server) {
        promptAction.showToast({ message: '未找到该服务器' });
        router.back();
        return;
      }
      this.name = server.name;
      this.host = server.host;
      this.port = String(server.port);
      this.username = server.username;
      this.group = server.group || '';
      this.tags = server.tags.join(',');
      this.authType = server.authType;
      this.connectionMode = server.connectionMode;
      if (server.authType === 'password') {
        this.password = await DataRepository.getPassword(this.serverId);
      } else {
        this.pemContent = await DataRepository.getKeyContent(this.serverId);
        if (this.pemContent) {
          this.pemFileHint = '已从加密存储加载';
        }
      }
    } catch (e) {
      console.error('loadForEdit failed:', JSON.stringify(e));
    }
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // ========== 校验 ==========

  private validate(): string {
    if (!this.name.trim()) return '请输入服务器名称';
    if (!this.host.trim()) return '请输入主机地址';
    const portNum = Number(this.port);
    if (!portNum || portNum < 1 || portNum > 65535) return '端口无效（1-65535）';
    if (!this.username.trim()) return '请输入用户名';
    if (this.authType === 'password' && !this.password) return '请输入密码';
    if (this.authType === 'key' && !this.pemContent.trim()) return '请粘贴或导入私钥内容';
    return '';
  }

  // ========== 私钥导入（文件选择器） ==========

  // 从 PEM 内容提取指纹摘要（SHA-256，xx:xx 冒号分隔）
  private async computeFingerprint(pem: string): Promise<string> {
    try {
      const md = cryptoFramework.createMd('SHA256');
      const encoder = new util.TextEncoder();
      await md.update({ data: encoder.encodeInto(pem) });
      const digest = await md.digest();
      const hex: string[] = [];
      for (let i = 0; i < digest.data.length; i++) {
        hex.push(digest.data[i].toString(16).padStart(2, '0'));
      }
      return hex.join(':');
    } catch (e) {
      console.error('computeFingerprint failed:', JSON.stringify(e));
      return '';
    }
  }

  // 识别密钥类型
  private detectKeyType(pem: string): string {
    if (pem.includes('OPENSSH PRIVATE KEY')) return 'OpenSSH';
    if (pem.includes('BEGIN RSA PRIVATE KEY')) return 'RSA (PKCS#1)';
    if (pem.includes('BEGIN EC PRIVATE KEY')) return 'EC';
    if (pem.includes('BEGIN PRIVATE KEY')) return 'PEM (PKCS#8)';
    return 'PEM';
  }

  // 使用系统文件选择器导入私钥文件
  private async importKeyFile(): Promise<void> {
    try {
      const context = getContext(this);
      const documentPicker = new picker.DocumentViewPicker(context);
      const result = await documentPicker.select({ maxSelectNumber: 1 });
      if (!result || result.length === 0) return;
      const uri = result[0];
      const content = await this.readUriText(uri);
      if (!content.trim()) {
        this.toast('文件内容为空');
        return;
      }
      this.pemContent = content;
      const fp = await this.computeFingerprint(content);
      const type = this.detectKeyType(content);
      this.pemFileHint = `${type} · SHA256:${fp ? fp.substring(0, 20) + '…' : '无法计算'}`;
      this.toast('私钥已导入');
    } catch (e) {
      console.error('importKeyFile failed:', JSON.stringify(e));
      this.toast('导入私钥失败');
    }
  }

  // 读取 picker 选中文件（content:// uri）的文本内容
  private async readUriText(uri: string): Promise<string> {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      const readLen = fileIo.readSync(file.fd, buf);
      const decoder = new util.TextDecoder();
      return decoder.decodeToString(new Uint8Array(buf).slice(0, readLen));
    } finally {
      fileIo.closeSync(file);
    }
  }

  // ========== 测试连接 ==========

  private async testConnection(): Promise<void> {
    const err = this.validate();
    if (err) {
      this.toast(err);
      return;
    }
    this.testing = true;
    this.testResult = '';
    this.testOk = false;
    try {
      // 构造内存态 Server（凭据仅存在于本次调用，不落库）
      const server: Server = {
        id: this.isEdit ? this.serverId : 'test-tmp',
        name: this.name.trim(),
        host: this.host.trim(),
        port: Number(this.port),
        username: this.username.trim(),
        authType: this.authType,
        connectionMode: this.connectionMode,
        group: this.group.trim() || undefined,
        tags: this.tags ? this.tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0) : [],
        password: this.authType === 'password' ? this.password : undefined,
        privateKeyContent: this.authType === 'key' ? this.pemContent.trim() : undefined,
        status: 'offline',
        metrics: EMPTY_METRICS,
        createdAt: Date.now()
      };
      const ok = await SshService.testConnection(server);
      this.testOk = ok;
      if (ok) {
        this.testResult = '连接成功 ✓';
      } else {
        this.testResult = '连接失败，请检查：\n1. SSH 服务是否已启动（端口 ' + this.port + '）\n2. 防火墙是否放行该端口\n3. 主机地址、用户名、密码是否正确';
      }
      this.toast(ok ? '连接成功' : '连接失败，请检查 SSH 服务和网络配置');
    } catch (e) {
      console.error('testConnection failed:', JSON.stringify(e));
      this.testResult = '连接测试异常';
    } finally {
      this.testing = false;
    }
  }

  // ========== 保存 ==========

  private async save(): Promise<void> {
    const err = this.validate();
    if (err) {
      this.toast(err);
      return;
    }
    this.saving = true;
    try {
      const now = Date.now();
      if (this.isEdit) {
        await DataRepository.updateServer(this.serverId, {
          name: this.name.trim(),
          host: this.host.trim(),
          port: Number(this.port),
          username: this.username.trim(),
          authType: this.authType,
          connectionMode: this.connectionMode,
          group: this.group.trim() || '',
          tags: this.tags ? this.tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0) : []
        });
        // 凭据仅在用户输入时更新；清空即删除
        await DataRepository.saveCredentials(this.serverId, this.password, this.pemContent.trim());
        this.toast('已保存');
      } else {
        const server: Server = {
          id: generateId('srv'),
          name: this.name.trim(),
          host: this.host.trim(),
          port: Number(this.port),
          username: this.username.trim(),
          authType: this.authType,
          connectionMode: this.connectionMode,
          group: this.group.trim() || undefined,
          tags: this.tags ? this.tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0) : [],
          password: this.authType === 'password' ? this.password : undefined,
          privateKeyContent: this.authType === 'key' ? this.pemContent.trim() : undefined,
          status: 'offline',
          metrics: EMPTY_METRICS,
          createdAt: now
        };
        await DataRepository.addServer(server);
        this.toast('服务器已添加');
      }
      // 通知服务器列表刷新
      AppStorage.setOrCreate('serversDirty', Date.now());
      router.back();
    } catch (e) {
      console.error('save failed:', JSON.stringify(e));
      this.toast('保存失败，请重试');
    } finally {
      this.saving = false;
    }
  }

  // ========== UI 组件 ==========

  // 输入行：标签 + 输入框
  @Builder inputRow(label: string, value: string, placeholder: string,
    onChange: (v: string) => void, type: InputType = InputType.Normal) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.textSecondary)
      TextInput({ text: value, placeholder: placeholder })
        .fontSize(13)
        .fontColor(AppTheme.textPrimary)
        .placeholderColor(AppTheme.textTertiary)
        .backgroundColor(AppTheme.bgSurface2)
        .borderRadius(6)
        .height(42)
        .type(type)
        .showPasswordIcon(true)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 分段选择器（两个选项）
  @Builder segmented(label: string, options: string[], selected: number, onSelect: (idx: number) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.textSecondary)
      Row({ space: 4 }) {
        ForEach(options, (opt: string, idx: number) => {
          Text(opt)
            .fontSize(12)
            .fontColor(selected === idx ? AppTheme.bgBase : AppTheme.textPrimary)
            .fontWeight(selected === idx ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .backgroundColor(selected === idx ? AppTheme.primary : AppTheme.bgSurface2)
            .onClick(() => onSelect(idx))
        }, (opt: string) => opt)
      }
      .width('100%')
      .padding(4)
      .borderRadius(8)
      .backgroundColor(AppTheme.bgSurface2)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder actionsBuilder() {
    Row({ space: 8 }) {
      Button(this.testing ? '测试中…' : '测试连接')
        .fontSize(12)
        .fontColor(this.testing ? AppTheme.textTertiary : AppTheme.primary)
        .backgroundColor(this.testing ? AppTheme.bgSurface2 : AppTheme.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .enabled(!this.testing && !this.saving)
        .onClick(() => {
          this.testConnection();
        })
      Button(this.saving ? '保存中…' : this.isEdit ? '保存' : '添加')
        .fontSize(12)
        .fontColor(AppTheme.bgBase)
        .backgroundColor(AppTheme.primary)
        .borderRadius(6)
        .height(28)
        .padding({ left: 12, right: 12 })
        .enabled(!this.testing && !this.saving)
        .onClick(() => {
          this.save();
        })
    }
  }

  build() {
    Column() {
      TopBar({
        title: this.isEdit ? '编辑服务器' : '添加服务器',
        subtitle: this.isEdit ? this.host || this.serverId : 'SSH / SFTP 连接配置',
        showBack: true
      }) {
        this.actionsBuilder()
      }
      Scroll() {
        Column({ space: 16 }) {
          // 基本信息
          FormCard({ title: '基本信息' }) {
            Column({ space: 10 }) {
              this.inputRow('服务器名称', this.name, '如 prod-web-01', (v: string) => { this.name = v; })
              this.inputRow('主机地址', this.host, '如 192.168.1.10 或 example.com', (v: string) => { this.host = v; })
              this.inputRow('端口', this.port, '22', (v: string) => { this.port = v; },
                InputType.Number)
              this.inputRow('用户名', this.username, '如 root', (v: string) => { this.username = v; })
              this.inputRow('分组（可选）', this.group, '如 生产 / 测试', (v: string) => { this.group = v; })
              this.inputRow('标签（可选，逗号分隔）', this.tags, '如 web,nginx', (v: string) => { this.tags = v; })
            }
            .width('100%')
          }

          // 认证方式
          FormCard({ title: '认证方式' }) {
            Column({ space: 10 }) {
              this.segmented('认证方式', ['密码认证', '密钥认证'],
                this.authType === 'password' ? 0 : 1, (idx: number) => {
                  this.authType = idx === 0 ? 'password' : 'key';
                })
              if (this.authType === 'password') {
                this.inputRow('密码', this.password, '请输入登录密码', (v: string) => { this.password = v; },
                  InputType.Password)
              } else {
                Column({ space: 6 }) {
                  Text('私钥内容（PEM）')
                    .fontSize(12)
                    .fontColor(AppTheme.textSecondary)
                  TextArea({ text: this.pemContent, placeholder: '粘贴 PEM 私钥内容，或以 -----BEGIN OPENSSH PRIVATE KEY----- 开头' })
                    .fontSize(12)
                    .fontColor(AppTheme.textPrimary)
                    .placeholderColor(AppTheme.textTertiary)
                    .backgroundColor(AppTheme.bgSurface2)
                    .borderRadius(6)
                    .height(140)
                    .fontFamily(AppTheme.fontMono)
                    .onChange((v: string) => { this.pemContent = v; })
                  Row({ space: 8 }) {
                    Button('📄 从文件导入')
                      .fontSize(11)
                      .fontColor(AppTheme.info)
                      .backgroundColor('rgba(59, 130, 246, 0.12)')
                      .borderRadius(6)
                      .height(30)
                      .padding({ left: 10, right: 10 })
                      .onClick(() => {
                        this.importKeyFile();
                      })
                    if (this.pemFileHint) {
                      Text(this.pemFileHint)
                        .fontSize(10)
                        .fontColor(AppTheme.success)
                        .fontFamily(AppTheme.fontMono)
                        .layoutWeight(1)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
          }

          // 连接模式（Agent 模式暂不可用，仅支持直连）
          FormCard({ title: '连接模式' }) {
            Column({ space: 10 }) {
              Row() {
                Text('直连模式')
                  .fontSize(12)
                  .fontColor(AppTheme.bgBase)
                  .fontWeight(FontWeight.Bold)
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .borderRadius(6)
                  .backgroundColor(AppTheme.primary)
              }
              .width('100%')
              .padding(4)
              .borderRadius(8)
              .backgroundColor(AppTheme.bgSurface2)
              Text('直连模式在设备端直接发起 SSH 连接，无需在目标服务器部署额外服务。')
                .fontSize(10)
                .fontColor(AppTheme.textTertiary)
                .width('100%')
              Text('提示：请确保目标服务器 SSH 服务已启动，且防火墙放行了对应端口。')
                .fontSize(10)
                .fontColor(AppTheme.info)
                .width('100%')
            }
            .width('100%')
          }

          // 测试结果
          if (this.testResult) {
            Row({ space: 8 }) {
              Text(this.testOk ? '✅' : '⚠️')
                .fontSize(14)
              Text(this.testResult)
                .fontSize(12)
                .fontColor(this.testOk ? AppTheme.success : AppTheme.danger)
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(this.testOk ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)')
            .alignItems(VerticalAlign.Center)
          }

          // 底部保存按钮
          Button(this.saving ? '保存中…' : this.isEdit ? '保存修改' : '添加服务器')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.bgBase)
            .backgroundColor(AppTheme.primary)
            .borderRadius(8)
            .enabled(!this.testing && !this.saving)
            .onClick(() => {
              this.save();
            })
        }
        .padding(this.isSm ? 16 : 24)
        .width('100%')
        .margin({ bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .height('100%')
    .padding({ bottom: this.navBarHeight })
    .backgroundColor(AppTheme.bgBase)
  }
}

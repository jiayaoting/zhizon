// 智子 - 微舆 服务器配置页（多配置管理 + 测试连接）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { BettaFishStore } from '../service/BettaFishStore';
import { BettaFishApiClient } from '../service/BettaFishApiClient';
import { BettaServerConfig } from '../common/BettaFishModels';

@ComponentV2
@Entry
export struct BettaFishServerConfigPage {
  @Local name: string = '默认服务器';
  @Local scheme: string = 'http';
  @Local host: string = '';
  @Local port: string = '5000';
  @Local basePath: string = '';
  @Local timeoutSec: string = '10';
  @Local editingId: string = '';
  @Local serverList: BettaServerConfig[] = [];
  @Local testing: boolean = false;
  @Local testResult: string = '';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  aboutToAppear(): void {
    this.loadList();
  }

  private async loadList(): Promise<void> {
    try {
      this.serverList = await BettaFishStore.listServers();
    } catch (e) {
      this.serverList = [];
    }
  }

  private formConfig(): BettaServerConfig {
    const config = new BettaServerConfig();
    config.id = this.editingId;
    config.name = this.name.trim().length > 0 ? this.name.trim() : '默认服务器';
    config.scheme = this.scheme;
    config.host = this.host.trim();
    config.port = Number.parseInt(this.port) > 0 ? Number.parseInt(this.port) : 5000;
    config.basePath = this.basePath.trim();
    config.timeoutSec = Number.parseInt(this.timeoutSec) > 0 ? Number.parseInt(this.timeoutSec) : 10;
    config.isCurrent = this.editingId.length === 0;
    return config;
  }

  private validate(config: BettaServerConfig): string {
    if (config.host.length === 0) return '请填写服务器 IP 或域名';
    if (config.port < 1 || config.port > 65535) return '端口范围 1-65535';
    if (config.basePath.length > 0 && !config.basePath.startsWith('/')) return '路径前缀需以 / 开头（如 /bettafish）';
    return '';
  }

  private async onTest(): Promise<void> {
    const config = this.formConfig();
    const error = this.validate(config);
    if (error.length > 0) {
      this.testResult = error;
      return;
    }
    this.testing = true;
    this.testResult = '正在测试连接…';
    const result = await BettaFishApiClient.systemStatus(config);
    this.testing = false;
    if (result.ok && result.data !== null) {
      const statusText: string = result.data.started ? '系统已启动' :
        (result.data.starting ? '系统启动中' : '系统未启动');
      this.testResult = '连接成功（' + BettaFishApiClient.buildBaseUrl(config) + '）· ' + statusText;
      promptAction.showToast({ message: '连接成功 · ' + statusText });
    } else {
      this.testResult = '连接失败：' + result.message;
      promptAction.showToast({ message: '连接失败：' + result.message });
    }
  }

  private async onSave(): Promise<void> {
    const config = this.formConfig();
    const error = this.validate(config);
    if (error.length > 0) {
      promptAction.showToast({ message: error });
      return;
    }
    try {
      await BettaFishStore.saveServer(config);
      promptAction.showToast({ message: '已保存服务器配置' });
      this.resetForm();
      await this.loadList();
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  private resetForm(): void {
    this.editingId = '';
    this.name = '默认服务器';
    this.scheme = 'http';
    this.host = '';
    this.port = '5000';
    this.basePath = '';
    this.timeoutSec = '10';
    this.testResult = '';
  }

  private editServer(server: BettaServerConfig): void {
    this.editingId = server.id;
    this.name = server.name;
    this.scheme = server.scheme;
    this.host = server.host;
    this.port = server.port.toString();
    this.basePath = server.basePath;
    this.timeoutSec = server.timeoutSec.toString();
    this.testResult = '';
  }

  private async switchServer(server: BettaServerConfig): Promise<void> {
    await BettaFishStore.setCurrent(server.id);
    await this.loadList();
    promptAction.showToast({ message: '已切换到 ' + server.name });
  }

  private async removeServer(server: BettaServerConfig): Promise<void> {
    promptAction.showDialog({
      title: '删除服务器配置',
      message: '删除「' + server.name + '」？本地历史记录不会删除。',
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '删除', color: '#E84026' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        await BettaFishStore.deleteServer(server.id);
        await this.loadList();
        promptAction.showToast({ message: '已删除' });
      }
    }).catch(() => {
    });
  }

  @Builder
  schemeChip(label: string, value: string) {
    Text(label)
      .fontSize(this.themeState.palette.fsBase)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.scheme === value ? Color.White : this.themeState.palette.textSecondary)
      .fontWeight(this.scheme === value ? FontWeight.Medium : FontWeight.Regular)
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .borderRadius(18)
      .backgroundColor(this.scheme === value ? this.themeState.palette.primary : this.themeState.palette.bgSurface2)
      .onClick(() => { this.scheme = value; })
  }

  @Builder
  label(text: string) {
    Text(text)
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.textTertiary)
      .width('100%')
  }

  @Builder
  textField(placeholder: string, value: string, onChange: (v: string) => void, type: InputType = InputType.Normal) {
    TextInput({ placeholder: placeholder, text: value })
      .width('100%')
      .height(42)
      .fontSize(this.themeState.palette.fsBase)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.textPrimary)
      .placeholderColor(this.themeState.palette.textTertiary)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .borderRadius(10)
      .type(type)
      .onChange((v: string) => { onChange(v); })
  }

  @Builder
  formCard() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text(this.editingId.length > 0 ? '编辑配置' : '新增配置')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        if (this.editingId.length > 0) {
          Text('取消编辑')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .onClick(() => { this.resetForm(); })
        }
      }
      .width('100%')

      this.label('配置名称')
      this.textField('如：家里服务器', this.name, (v: string) => { this.name = v; })

      this.label('协议')
      Row({ space: 10 }) {
        this.schemeChip('HTTP', 'http')
        this.schemeChip('HTTPS', 'https')
      }
      .width('100%')

      this.label('服务器 IP / 域名')
      this.textField('如 192.168.1.100 或 betta.example.com', this.host, (v: string) => { this.host = v; })

      Row({ space: 12 }) {
        Column({ space: 6 }) {
          this.label('端口')
          this.textField('5000', this.port, (v: string) => { this.port = v; }, InputType.Number)
        }
        .layoutWeight(1)
        Column({ space: 6 }) {
          this.label('连接超时（秒）')
          this.textField('10', this.timeoutSec, (v: string) => { this.timeoutSec = v; }, InputType.Number)
        }
        .layoutWeight(1)
      }
      .width('100%')

      this.label('路径前缀（可选，反向代理用）')
      this.textField('如 /bettafish，留空表示根路径', this.basePath, (v: string) => { this.basePath = v; })

      if (this.testResult.length > 0) {
        Text(this.testResult)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.testResult.startsWith('连接成功') ? this.themeState.palette.primary :
            this.themeState.palette.danger)
          .width('100%')
      }

      Row({ space: 12 }) {
        Button(this.testing ? '测试中…' : '测试连接')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .backgroundColor(Color.Transparent)
          .fontColor(this.themeState.palette.primary)
          .border({ width: 1, color: this.themeState.palette.primary })
          .layoutWeight(1)
          .height(40)
          .enabled(!this.testing)
          .onClick(() => { this.onTest(); })
        Button('保存')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .backgroundColor(this.themeState.palette.primary)
          .layoutWeight(1)
          .height(40)
          .onClick(() => { this.onSave(); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
  }

  @Builder
  serverItem(server: BettaServerConfig) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(server.isCurrent ? '✅' : '⚪')
          .fontSize(14)
          .fontFamily(this.themeState.palette.fontSans)
        Text(server.name)
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        if (server.isCurrent) {
          Text('当前')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
            .backgroundColor(this.themeState.palette.primaryDim)
        }
      }
      .width('100%')

      Text(BettaFishApiClient.buildBaseUrl(server))
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 10 }) {
        Text('编辑')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .onClick(() => { this.editServer(server); })
        Text('设为当前')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(server.isCurrent ? this.themeState.palette.textTertiary : this.themeState.palette.primary)
          .enabled(!server.isCurrent)
          .onClick(() => { this.switchServer(server); })
        Blank()
        Text('删除')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.danger)
          .onClick(() => { this.removeServer(server); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
  }

  build() {
    Column() {
      TopBar({ title: '微舆 · 服务器配置', subtitle: '支持多套配置，随时切换', showBack: true }) {
        Column()
      }
      Scroll() {
        Column({ space: 14 }) {
          this.formCard()

          if (this.serverList.length > 0) {
            Column({ space: 8 }) {
              Text('已保存配置（' + this.serverList.length.toString() + '）')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              ForEach(this.serverList, (server: BettaServerConfig) => {
                this.serverItem(server)
              }, (server: BettaServerConfig) => server.id)
            }
            .width('100%')
          }
          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 14 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

// 智子 - 微舆 服务器配置页（多配置管理 + 测试连接）
// v10：表单卡/列表卡改 bgSurface + 发丝边框（无玻璃/无阴影）；输入框 44vp，主按钮 primary 胶囊；
//      测试结果用 success/danger 语义淡底；当前服务器行 primaryBg 高亮。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { BettaFishStore } from '../service/betta/BettaFishStore';
import { BettaFishApiClient } from '../service/betta/BettaFishApiClient';
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
        { text: '取消', color: this.themeState.palette.textSecondary },
        { text: '删除', color: this.themeState.palette.danger }
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
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.scheme === value ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      .fontWeight(this.scheme === value ? FontWeight.Medium : FontWeight.Regular)
      .height(40)
      .padding({ left: 20, right: 20 })
      .borderRadius(this.themeState.palette.radiusCapsule)
      .backgroundColor(this.scheme === value ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface2)
      .border({ width: 0.5, color: this.scheme === value ? this.themeState.palette.primary : this.themeState.palette.divider })
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
      .height(44)
      .fontSize(this.themeState.palette.fsMd)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.textPrimary)
      .placeholderColor(this.themeState.palette.textTertiary)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .borderRadius(this.themeState.palette.radiusSm)
      .type(type)
      .onChange((v: string) => { onChange(v); })
  }

  @Builder
  formCard() {
    Column({ space: this.themeState.palette.sp3 }) {
      Row({ space: this.themeState.palette.sp3 }) {
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
            .height(44)
            .padding({ left: this.themeState.palette.sp2, right: this.themeState.palette.sp2 })
            .onClick(() => { this.resetForm(); })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.label('配置名称')
      this.textField('如：家里服务器', this.name, (v: string) => { this.name = v; })

      Column({ space: this.themeState.palette.sp2 }) {
        this.label('协议')
        Row({ space: this.themeState.palette.sp3 }) {
          this.schemeChip('HTTP', 'http')
          this.schemeChip('HTTPS', 'https')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.label('服务器 IP / 域名')
      this.textField('如 192.168.1.100 或 betta.example.com', this.host, (v: string) => { this.host = v; })

      Row({ space: this.themeState.palette.sp3 }) {
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
          .fontColor(this.testResult.startsWith('连接成功') ? this.themeState.palette.success :
            this.themeState.palette.danger)
          .width('100%')
          .padding(this.themeState.palette.sp3)
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.testResult.startsWith('连接成功') ? this.themeState.palette.successBg :
            this.themeState.palette.dangerBg)
      }

      Row({ space: this.themeState.palette.sp3 }) {
        Button(this.testing ? '测试中…' : '测试连接')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .layoutWeight(1)
          .height(44)
          .enabled(!this.testing)
          .onClick(() => { this.onTest(); })
        Button('保存')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .layoutWeight(1)
          .height(44)
          .onClick(() => { this.onSave(); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(this.themeState.palette.sp4)
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
  }

  // 服务器行：当前项 primaryBg 高亮；动作 44vp 触控目标
  @Builder
  serverItem(server: BettaServerConfig) {
    Column({ space: 6 }) {
      Row({ space: this.themeState.palette.sp3 }) {
        Row() {
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(server.isCurrent ? AppIcons.check : AppIcons.server)
              .fontSize(18)
              .fontColor([server.isCurrent ? this.themeState.palette.primary : this.themeState.palette.textTertiary])
          } else {
            Text(server.isCurrent ? AppIcons.checkEmoji : AppIcons.serverEmoji)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
          }
        }
        .width(32)
        .height(32)
        .borderRadius(this.themeState.palette.radiusSm)
        .backgroundColor(server.isCurrent ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        Text(server.name)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (server.isCurrent) {
          Text('当前')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(this.themeState.palette.radiusSm)
            .backgroundColor(this.themeState.palette.primaryBg)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(BettaFishApiClient.buildBaseUrl(server))
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: this.themeState.palette.sp4 }) {
        Text('编辑')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .height(44)
          .padding({ left: this.themeState.palette.sp1, right: this.themeState.palette.sp1 })
          .onClick(() => { this.editServer(server); })
        Text('设为当前')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(server.isCurrent ? this.themeState.palette.textTertiary : this.themeState.palette.primary)
          .height(44)
          .padding({ left: this.themeState.palette.sp1, right: this.themeState.palette.sp1 })
          .enabled(!server.isCurrent)
          .onClick(() => { this.switchServer(server); })
        Blank()
        Text('删除')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.danger)
          .height(44)
          .padding({ left: this.themeState.palette.sp1, right: this.themeState.palette.sp1 })
          .onClick(() => { this.removeServer(server); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4,
      top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp1 })
    .backgroundColor(server.isCurrent ? this.themeState.palette.primaryBg : Color.Transparent)
    .border({ width: { bottom: 0.5 }, color: this.themeState.palette.divider })
  }

  build() {
    Column() {
      TopBar({ title: '微舆 · 服务器配置', subtitle: '支持多套配置，随时切换', showBack: true }) {
        Column()
      }
      Scroll() {
        Column({ space: this.themeState.palette.sectionGap }) {
          this.formCard()

          if (this.serverList.length > 0) {
            Column({ space: this.themeState.palette.sp2 }) {
              Text('已保存配置（' + this.serverList.length.toString() + '）')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Column() {
                ForEach(this.serverList, (server: BettaServerConfig) => {
                  this.serverItem(server)
                }, (server: BettaServerConfig) => server.id)
              }
              .width('100%')
              .borderRadius(this.themeState.palette.radiusLg)
              .backgroundColor(this.themeState.palette.bgSurface)
              .border({ width: 0.5, color: this.themeState.palette.divider })
              .clip(true)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          Column().height(this.themeState.palette.sp5)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp3 })
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

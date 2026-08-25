// 智子 - BettaFish 连接状态条（微舆 Hub 顶栏）
// 状态机：unconfigured（未配置） / checking（测试中） / connected（已连接） / error（连接失败）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';

@ComponentV2
export struct BettaConnectionBar {
  @Param state: string = 'unconfigured';   // unconfigured | checking | connected | error
  @Param serverName: string = '';
  @Param detail: string = '';
  @Event onConfigTap: () => void = () => {};
  @Event onRetryTap: () => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private stateIcon(): string {
    if (this.state === 'connected') return '🟢';
    if (this.state === 'checking') return '⏳';
    if (this.state === 'error') return '🔴';
    return '⚪';
  }

  private stateTitle(): string {
    if (this.state === 'connected') return '已连接 ' + this.serverName;
    if (this.state === 'checking') return '正在连接 ' + this.serverName;
    if (this.state === 'error') return '连接失败 · ' + this.serverName;
    return '尚未配置服务器';
  }

  build() {
    Row({ space: 12 }) {
      Text(this.stateIcon())
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
      Column({ space: 2 }) {
        Text(this.stateTitle())
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.state === 'connected') {
        Text('⚙')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .borderRadius(18)
          .backgroundColor(this.themeState.palette.primaryDim)
          .accessibilityText('服务器配置')
          .onClick(() => { this.onConfigTap(); })
      } else if (this.state === 'error') {
        Text('重试')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.themeState.palette.primaryDim)
          .onClick(() => { this.onRetryTap(); })
        Text('⚙')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .borderRadius(18)
          .backgroundColor(this.themeState.palette.primaryDim)
          .onClick(() => { this.onConfigTap(); })
      } else {
        Text('去配置')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.themeState.palette.primaryDim)
          .onClick(() => { this.onConfigTap(); })
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.stateTitle())
  }
}

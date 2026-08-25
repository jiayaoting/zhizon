// 智子 - BettaFish 引擎状态卡
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { BettaEngineStatus } from '../common/BettaFishModels';

@ComponentV2
export struct BettaEngineStatusCard {
  @Param engine: BettaEngineStatus = new BettaEngineStatus();
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private statusColor(): string {
    if (this.engine.status === 'running') return '#22C55E';
    if (this.engine.status === 'starting') return '#F59E0B';
    return '#9CA3AF';
  }

  private statusLabel(): string {
    if (this.engine.status === 'running') return '运行中';
    if (this.engine.status === 'starting') return '启动中';
    return '已停止';
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Circle()
          .width(10)
          .height(10)
          .fill(this.statusColor())
        Text(this.engine.appName.toUpperCase())
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      Text(this.statusLabel())
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.statusColor())
        .width('100%')
      if (this.engine.port > 0) {
        Text('端口 ' + this.engine.port.toString())
          .fontSize(this.themeState.palette.fsXs - 1)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
      }
    }
    .layoutWeight(1)
    .padding(12)
    .borderRadius(12)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
    .alignItems(HorizontalAlign.Start)
  }
}

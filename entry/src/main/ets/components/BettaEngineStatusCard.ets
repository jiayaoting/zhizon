// 智子 - BettaFish 引擎状态卡
// v10：状态点/状态字用语义色（success / warning / textTertiary），卡内小块用对应淡底 + 发丝边框。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { BettaEngineStatus } from '../common/BettaFishModels';

@ComponentV2
export struct BettaEngineStatusCard {
  @Param engine: BettaEngineStatus = new BettaEngineStatus();
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private statusColor(): string {
    if (this.engine.status === 'running') return this.themeState.palette.success;
    if (this.engine.status === 'starting') return this.themeState.palette.warning;
    return this.themeState.palette.textTertiary;
  }

  // 状态淡底（运行中/启动中/已停止）
  private statusBg(): string {
    if (this.engine.status === 'running') return this.themeState.palette.successBg;
    if (this.engine.status === 'starting') return this.themeState.palette.warningBg;
    return this.themeState.palette.bgSurface2;
  }

  private statusLabel(): string {
    if (this.engine.status === 'running') return '运行中';
    if (this.engine.status === 'starting') return '启动中';
    return '已停止';
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: this.themeState.palette.sp2 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.statusColor())
        Text(this.engine.appName.toUpperCase())
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      Text(this.statusLabel())
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.statusColor())
        .width('100%')
      if (this.engine.port > 0) {
        Text('端口 ' + this.engine.port.toString())
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
      }
    }
    .layoutWeight(1)
    .padding(this.themeState.palette.sp3)
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(this.statusBg())
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(HorizontalAlign.Start)
  }
}

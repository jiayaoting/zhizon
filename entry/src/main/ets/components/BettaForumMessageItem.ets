// 智子 - BettaFish 论坛消息气泡（按来源着色）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { BettaForumMessage } from '../common/BettaFishModels';

@ComponentV2
export struct BettaForumMessageItem {
  @Param message: BettaForumMessage = new BettaForumMessage();
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private sourceColor(): string {
    if (this.message.source === 'HOST') return '#F59E0B';
    if (this.message.source === 'QUERY') return '#3B82F6';
    if (this.message.source === 'MEDIA') return '#8B5CF6';
    if (this.message.source === 'INSIGHT') return '#10B981';
    return '#9CA3AF';
  }

  private senderLabel(): string {
    if (this.message.sender.length > 0) return this.message.sender;
    if (this.message.source.length > 0) return this.message.source;
    return 'Agent';
  }

  build() {
    Row({ space: 10 }) {
      Text(this.message.source.length > 0 ? this.message.source.substring(0, 2) : 'AG')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(Color.White)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .borderRadius(15)
        .backgroundColor(this.sourceColor())
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(this.senderLabel())
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.sourceColor())
            .fontWeight(FontWeight.Medium)
          if (this.message.timestamp.length > 0) {
            Text(this.message.timestamp)
              .fontSize(this.themeState.palette.fsXs - 1)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
        }
        .width('100%')
        Text(this.message.content)
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 8, bottom: 8 })
  }
}

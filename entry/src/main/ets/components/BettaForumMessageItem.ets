// 智子 - BettaFish 论坛消息气泡（按来源着色）
// v10：来源色改语义 token（HOST=warning / QUERY=info / MEDIA=purple / INSIGHT=success），头像用主色上的文字色；行末发丝分割线。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { BettaForumMessage } from '../common/BettaFishModels';

@ComponentV2
export struct BettaForumMessageItem {
  @Param message: BettaForumMessage = new BettaForumMessage();
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private sourceColor(): string {
    if (this.message.source === 'HOST') return this.themeState.palette.warning;
    if (this.message.source === 'QUERY') return this.themeState.palette.info;
    if (this.message.source === 'MEDIA') return this.themeState.palette.purple;
    if (this.message.source === 'INSIGHT') return this.themeState.palette.success;
    return this.themeState.palette.textTertiary;
  }

  private senderLabel(): string {
    if (this.message.sender.length > 0) return this.message.sender;
    if (this.message.source.length > 0) return this.message.source;
    return 'Agent';
  }

  build() {
    Row({ space: this.themeState.palette.sp3 }) {
      Text(this.message.source.length > 0 ? this.message.source.substring(0, 2) : 'AG')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .fontWeight(FontWeight.Medium)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.sourceColor())
      Column({ space: 4 }) {
        Row({ space: this.themeState.palette.sp2 }) {
          Text(this.senderLabel())
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.sourceColor())
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.message.timestamp.length > 0) {
            Text(this.message.timestamp)
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text(this.message.content)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
    .border({ width: { bottom: 0.5 }, color: this.themeState.palette.divider })
  }
}

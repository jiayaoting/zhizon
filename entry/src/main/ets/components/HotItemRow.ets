// 智子 - 榜单条目行（v10：华为拟物白规范）
// 契约保持不变：@Param entry / rank / read / showDivider，@Event onOpen
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { HotEntry, HotItem } from '../common/HotModels';
import { hotRelativeTime } from '../common/HotFormat';

@ComponentV2
export struct HotItemRow {
  @Param entry: HotEntry = new HotEntry('', new HotItem('', '', '', '', 0, ''), '', '');
  @Param rank: number = 0;        // 从 1 开始；0 = 不显示序号
  @Param read: boolean = false;
  @Param showDivider: boolean = false;
  @Event onOpen: (entry: HotEntry) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // Top3 序号配色（内容强调色，保持不变）
  private rankColor(): string {
    if (this.rank === 1) return '#E84026';
    if (this.rank === 2) return '#F97316';
    if (this.rank === 3) return '#EAB308';
    return this.themeState.palette.textTertiary;
  }

  build() {
    Column() {
      Row({ space: this.themeState.palette.sp2 }) {
        if (this.rank > 0) {
          Text(this.rank.toString())
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.rankColor())
            .fontWeight(this.rank <= 3 ? FontWeight.Bold : FontWeight.Normal)
            .width(20)
            .textAlign(TextAlign.Center)
        }

        Column({ space: 3 }) {
          Text(this.entry.item.title)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.read ? this.themeState.palette.textTertiary : this.themeState.palette.textPrimary)
            .fontWeight(this.read ? FontWeight.Normal : FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)

          if (this.entry.item.info.length > 0 || this.entry.item.pubDate > 0) {
            Row({ space: this.themeState.palette.sp2 }) {
              if (this.entry.item.info.length > 0) {
                Text(this.entry.item.info)
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              } else {
                Blank()
              }
              if (this.entry.item.pubDate > 0) {
                Text(hotRelativeTime(this.entry.item.pubDate))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
            }
            .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2, left: 2, right: 2 })
      .alignItems(VerticalAlign.Top)

      if (this.showDivider) {
        Divider()
          .color(this.themeState.palette.divider)
          .strokeWidth(0.5)
          .margin({ left: this.rank > 0 ? 28 : 0 })
      }
    }
    .width('100%')
    .onClick(() => {
      this.onOpen(this.entry);
    })
  }
}

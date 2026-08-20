// 智子 - 资讯卡片（小图卡/纯文本卡，主题化）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { NewsItem } from '../common/NewsModels';

// 相对时间格式化
function formatNewsTime(ts: number): string {
  const diff: number = Date.now() - ts;
  if (diff < 60000) return '刚刚';
  const min: number = Math.floor(diff / 60000);
  if (min < 60) return min.toString() + ' 分钟前';
  const hours: number = Math.floor(min / 60);
  if (hours < 24) return hours.toString() + ' 小时前';
  const days: number = Math.floor(hours / 24);
  if (days === 1) return '昨天';
  if (days < 7) return days.toString() + ' 天前';
  const d: Date = new Date(ts);
  return (d.getMonth() + 1).toString() + '-' + d.getDate().toString();
}

@ComponentV2
export struct NewsCard {
  @Param item: NewsItem = new NewsItem('', '', '', '', '', '', '', '', 0);
  @Param read: boolean = false;
  @Event onOpen: (item: NewsItem) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local imgFailed: boolean = false;

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.item.title)
          .fontSize(this.themeState.palette.fsMd + 1)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.read ? this.themeState.palette.textTertiary : this.themeState.palette.textPrimary)
          .fontWeight(this.read ? FontWeight.Normal : FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.sourceName + ' · ' + formatNewsTime(this.item.publishedAt))
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ top: 2 })
        if (this.item.summary.length > 0) {
          Text(this.item.summary)
            .fontSize(this.themeState.palette.fsSm - 1)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.item.imageUrl.length > 0) {
        if (this.imgFailed) {
          // 图片加载失败占位
          Stack() {
            Column()
              .width(96)
              .height(72)
              .borderRadius(8)
              .linearGradient({
                angle: 135,
                colors: [[this.themeState.palette.bgSurface2, 0.0], [this.themeState.palette.bgHover, 1.0]]
              })
            Text('📰')
              .fontSize(22)
              .fontFamily(this.themeState.palette.fontSans)
          }
        } else {
          Image(this.item.imageUrl)
            .width(96)
            .height(72)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .onError(() => {
              this.imgFailed = true;
            })
        }
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.onOpen(this.item); })
  }
}

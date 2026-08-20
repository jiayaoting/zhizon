// 智子 - 资讯卡片（小图卡/纯文本卡，主题化）
// v0.7：标签 chips + 点赞/点踩按钮（个性化反馈）
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
  @Param liked: boolean = false;
  @Param disliked: boolean = false;
  // 外文翻译（M3）：translationText 由列表页缓存提供
  @Param translationText: string = '';
  @Param translating: boolean = false;
  @Event onOpen: (item: NewsItem) => void = () => {};
  @Event onLike: (item: NewsItem) => void = () => {};
  @Event onDislike: (item: NewsItem) => void = () => {};
  @Event onTranslate: (item: NewsItem) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local imgFailed: boolean = false;
  @Local showTranslated: boolean = false;

  private isForeign(): boolean {
    return this.item.language !== undefined && this.item.language.length > 0 && this.item.language !== 'zh';
  }

  @Builder
  tagChip(tag: string) {
    Text('#' + tag)
      .fontSize(this.themeState.palette.fsXs - 1)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.primary)
      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
      .borderRadius(8)
      .backgroundColor(this.themeState.palette.primary + '1A')
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.item.title)
            .fontSize(this.themeState.palette.fsMd + 1)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.read ? this.themeState.palette.textTertiary : this.themeState.palette.textPrimary)
            .fontWeight(this.read ? FontWeight.Normal : FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            Text(this.item.sourceName + ' · ' + formatNewsTime(this.item.publishedAt))
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
            if (this.isForeign()) {
              Text('EN')
                .fontSize(9)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .borderRadius(4)
                .backgroundColor(this.themeState.palette.primary + '1A')
            }
          }
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
      .padding({ left: 14, right: 14, top: 14 })

      Row({ space: 8 }) {
        // 标签 chips（最多 2 个）
        if (this.item.tags !== undefined && this.item.tags.length > 0) {
          ForEach(this.item.tags.slice(0, 2), (tag: string) => {
            this.tagChip(tag)
          }, (tag: string) => tag)
        } else {
          Text('')
            .fontSize(1)
        }
        // 外文翻译入口（M3）
        if (this.isForeign()) {
          if (this.translating) {
            Text('翻译中…')
              .fontSize(11)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .padding(6)
          } else if (this.translationText.length === 0) {
            Text('🌐 译成中文')
              .fontSize(11)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primary)
              .padding(6)
              .onClick(() => { this.onTranslate(this.item); })
          } else {
            Text(this.showTranslated ? '🌐 译文' : '🌐 已译')
              .fontSize(11)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.showTranslated ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
              .padding(6)
              .onClick(() => { this.showTranslated = !this.showTranslated; })
          }
        }
        Blank()
        // 赞 / 踩
        Text(this.liked ? '👍' : '👍🏻')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .opacity(this.liked ? 1 : 0.55)
          .padding(6)
          .onClick(() => { this.onLike(this.item); })
        Text(this.disliked ? '👎' : '👎🏻')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .opacity(this.disliked ? 1 : 0.55)
          .padding(6)
          .onClick(() => { this.onDislike(this.item); })
      }
      .width('100%')
      .padding({ left: 12, right: 10, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      // 译文（缓存命中后展示，可切换原文/译文）
      if (this.showTranslated && this.translationText.length > 0) {
        Text(this.translationText)
          .fontSize(this.themeState.palette.fsSm - 1)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 10 })
      }
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .onClick(() => { this.onOpen(this.item); })
  }
}

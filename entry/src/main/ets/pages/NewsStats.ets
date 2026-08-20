// 智子 - 资讯统计（收藏 / 已读 / AI 资讯调用）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsRepository, NewsStats } from '../service/NewsRepository';
import { NewsService } from '../service/NewsService';
import { NewsItem } from '../common/NewsModels';

@ComponentV2
@Entry
export struct NewsStatsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local stats: NewsStats = { favoriteCount: 0, readCount: 0, aiCallCount: 0 };
  @Local loading: boolean = true;

  aboutToAppear(): void {
    this.loadStats();
  }

  private async loadStats(): Promise<void> {
    try {
      this.stats = await NewsRepository.stats();
    } catch (e) {
    }
    this.loading = false;
  }

  private async clearRead(): Promise<void> {
    await NewsRepository.clearRead();
    this.loadStats();
    promptAction.showToast({ message: '已清空阅读记录' });
  }

  // 把当前资讯流（推荐频道前 50 条）全部标记为已读
  private async markAllRead(): Promise<void> {
    try {
      const items: NewsItem[] = await NewsService.fetchChannel('recommend', 50, false);
      for (let i: number = 0; i < items.length; i++) {
        await NewsRepository.markRead(items[i].url);
      }
      this.loadStats();
      promptAction.showToast({ message: '已将 ' + items.length.toString() + ' 篇资讯标记为已读' });
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试' });
    }
  }

  @Builder
  statCard(icon: string, value: number, label: string) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
      Text(value.toString())
        .fontSize(this.themeState.palette.fs2xl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
    }
    .layoutWeight(1)
    .padding(16)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      TopBar({ title: '资讯统计', subtitle: '阅读行为均保存在本地', showBack: true })

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            this.statCard('⭐', this.stats.favoriteCount, '收藏')
            this.statCard('👁', this.stats.readCount, '已读')
            this.statCard('🤖', this.stats.aiCallCount, 'AI 资讯调用')
          }
          .width('100%')

          Row() {
            Column({ space: 4 }) {
              Text('清空阅读记录')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text('已读标记将被清除，不影响收藏与简报')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('清空')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(this.themeState.palette.danger)
              .borderRadius(14)
              .height(32)
              .onClick(() => { this.clearRead(); })
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
          .alignItems(VerticalAlign.Center)

          Row() {
            Column({ space: 4 }) {
              Text('标记全部已读')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text('将当前资讯流（推荐频道）全部标记为已读')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('标记')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(this.themeState.palette.primary)
              .borderRadius(14)
              .height(32)
              .onClick(() => { this.markAllRead(); })
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
          .alignItems(VerticalAlign.Center)

          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
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

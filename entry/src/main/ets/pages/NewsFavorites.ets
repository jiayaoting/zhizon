// 智子 - 热榜收藏列表页
// 设计文档：doc/newsnow-redesign.md §9
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { HotEntry, HotDetailRouteParams } from '../common/HotModels';
import { NewsRepository } from '../service/hot/NewsRepository';
import { HotSourceBadge } from '../components/HotSourceBadge';

@ComponentV2
@Entry
export struct NewsFavoritesPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local favorites: HotEntry[] = [];
  @Local loading: boolean = true;

  aboutToAppear(): void {
    this.loadFavorites();
  }

  private async loadFavorites(): Promise<void> {
    this.loading = true;
    try {
      this.favorites = await NewsRepository.listFavorites();
    } catch (e) {
      this.favorites = [];
    }
    this.loading = false;
  }

  private openDetail(entry: HotEntry): void {
    AppNavigator.push('pages/NewsDetail', new HotDetailRouteParams(entry.key, entry.sourceId,
      entry.sourceName, entry.item.title, entry.item.url, entry.item.info));
  }

  private async removeFavorite(entry: HotEntry): Promise<void> {
    await NewsRepository.removeFavorite(entry.key);
    await this.loadFavorites();
    promptAction.showToast({ message: '已取消收藏' });
  }

  private async clearAll(): Promise<void> {
    if (this.favorites.length === 0) return;
    await NewsRepository.clearFavorites();
    await this.loadFavorites();
    promptAction.showToast({ message: '已清空收藏' });
  }

  @Builder
  favRow(entry: HotEntry) {
    Row({ space: 10 }) {
      HotSourceBadge({ sourceId: entry.sourceId, badgeSize: 28 })

      Column({ space: 4 }) {
        Text(entry.item.title)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(entry.sourceName +
          (entry.item.info.length > 0 ? ' · ' + entry.item.info : ''))
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('✕')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .padding(10)
        .onClick(() => { this.removeFavorite(entry); })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 1, color: this.themeState.palette.borderSubtle })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      TopBar({ title: '收藏', showBack: true }) {
        Row({ space: 8 }) {
          Text('🗑')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .padding(6)
            .onClick(() => { this.clearAll(); })
        }
      }

      if (this.favorites.length === 0 && !this.loading) {
        Column({ space: 10 }) {
          Text('⭐')
            .fontSize(46)
            .fontFamily(this.themeState.palette.fontSans)
          Text('暂无收藏')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
          Text('在热榜条目详情页点击收藏，稍后再读')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.favorites, (entry: HotEntry) => {
            ListItem() {
              this.favRow(entry)
            }
            .onClick(() => { this.openDetail(entry); })
          }, (entry: HotEntry) => entry.key)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .layoutWeight(1)
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

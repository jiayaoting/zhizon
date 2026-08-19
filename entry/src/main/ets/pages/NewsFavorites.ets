// 智子 - 收藏/稍后读列表页
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { NewsItem, NewsDetailRouteParams } from '../common/NewsModels';
import { NewsRepository } from '../service/NewsRepository';
import { LazyListDataSource } from '../common/LazyDataSource';
import { NewsCard } from '../components/NewsCard';

@ComponentV2
@Entry
export struct NewsFavoritesPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local favorites: NewsItem[] = [];
  @Local loading: boolean = true;

  private source: LazyListDataSource<NewsItem> = new LazyListDataSource<NewsItem>([]);

  aboutToAppear(): void {
    this.loadFavorites();
  }

  aboutToDisappear(): void {
    // 单次拉取，无持久资源需要释放
  }

  private async loadFavorites(): Promise<void> {
    this.loading = true;
    try {
      this.favorites = await NewsRepository.listFavorites();
      this.source.replace(this.favorites);
    } catch (e) {
      this.favorites = [];
      this.source.replace([]);
    }
    this.loading = false;
  }

  private openDetail(item: NewsItem): void {
    AppNavigator.push('pages/NewsDetail', new NewsDetailRouteParams(item));
  }

  private async removeFavorite(item: NewsItem): Promise<void> {
    await NewsRepository.removeFavorite(item.url);
    this.loadFavorites();
    promptAction.showToast({ message: '已取消收藏' });
  }

  private async clearAll(): Promise<void> {
    if (this.favorites.length === 0) return;
    await NewsRepository.clearFavorites();
    this.loadFavorites();
    promptAction.showToast({ message: '已清空收藏' });
  }

  build() {
    Column() {
      TopBar({ title: '收藏 / 稍后读', showBack: true }) {
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
          Text('在新闻详情页点击 ☆ 收藏感兴趣的文章')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          LazyForEach(this.source, (item: NewsItem) => {
            ListItem() {
              Row({ space: 8 }) {
                NewsCard({
                  item: item,
                  read: false,
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); }
                })
                .layoutWeight(1)
                Text('✕')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .padding(10)
                  .onClick(() => { this.removeFavorite(item); })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }, (item: NewsItem) => item.id)
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

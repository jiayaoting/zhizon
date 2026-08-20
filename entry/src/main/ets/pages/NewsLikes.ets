// 智子 - 我的点赞（点赞过的新闻列表；可取消赞 / 转收藏）
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
export struct NewsLikesPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local items: NewsItem[] = [];
  @Local loading: boolean = true;

  private source: LazyListDataSource<NewsItem> = new LazyListDataSource<NewsItem>([]);

  aboutToAppear(): void {
    this.loadLikes();
  }

  aboutToDisappear(): void {
    // 单次拉取，无持久资源需要释放
  }

  private async loadLikes(): Promise<void> {
    this.loading = true;
    try {
      this.items = await NewsRepository.listLikedItems();
      this.source.replace(this.items);
    } catch (e) {
      this.items = [];
      this.source.replace([]);
    }
    this.loading = false;
  }

  private openDetail(item: NewsItem): void {
    AppNavigator.push('pages/NewsDetail', new NewsDetailRouteParams(item));
  }

  private async unlike(item: NewsItem): Promise<void> {
    await NewsRepository.removeRating(item.url);
    await NewsRepository.recordEvent('undo', item, 0, '');
    this.loadLikes();
    promptAction.showToast({ message: '已取消点赞' });
  }

  private async favorite(item: NewsItem): Promise<void> {
    await NewsRepository.addFavorite(item);
    promptAction.showToast({ message: '已收藏' });
  }

  build() {
    Column() {
      TopBar({ title: '我的点赞', subtitle: '点赞内容正在影响推荐', showBack: true })

      if (this.items.length === 0 && !this.loading) {
        Column({ space: 10 }) {
          Text('👍')
            .fontSize(46)
            .fontFamily(this.themeState.palette.fontSans)
          Text('还没有点赞记录')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
          Text('在新闻卡片或详情页点赞，之后会多推同类内容')
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
                  liked: true,
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); }
                })
                .layoutWeight(1)
                Column({ space: 10 }) {
                  Text('⭐')
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .padding(6)
                    .onClick(() => { this.favorite(item); })
                  Text('✕')
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .padding(6)
                    .onClick(() => { this.unlike(item); })
                }
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

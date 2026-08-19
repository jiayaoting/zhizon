// 智子 - 首页（AI 资讯流 · 主功能界面）
// 问候栏 + AI 今日要闻入口 + 频道 Tabs + 新闻卡片流（下拉刷新/上拉加载）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsItem, NewsChannel, NewsDetailRouteParams } from '../common/NewsModels';
import { NEWS_CHANNELS } from '../common/NewsChannels';
import { NewsService } from '../service/NewsService';
import { NewsRepository } from '../service/NewsRepository';
import { LazyListDataSource } from '../common/LazyDataSource';
import { NewsCard } from '../components/NewsCard';
import { NewsDetailPane } from '../components/NewsDetailPane';
import { DataRepository } from '../service/DataRepository';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';

@ComponentV2
export struct IndexPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local currentTime: string = '';
  @Local greeting: string = '';
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Local channelId: string = 'recommend';
  @Local items: NewsItem[] = [];
  @Local loading: boolean = true;
  @Local error: boolean = false;
  @Local refreshing: boolean = false;
  @Local loadingMore: boolean = false;
  @Local hasDigestToday: boolean = false;
  @Local readUrls: string[] = [];
  // 平板双栏：右侧当前阅读的文章（手机模式不使用）
  @Local selectedItem: NewsItem | null = null;
  @Event onNavigate: (key: string) => void = () => {};

  private source: LazyListDataSource<NewsItem> = new LazyListDataSource<NewsItem>([]);

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadAvatar();
    this.loadReadUrls();
    this.checkDigest();
    this.loadFeed(false);
  }

  aboutToDisappear(): void {
    // 数据由 NewsService 内存缓存管理，无持久资源需要释放
  }

  private async loadAvatar(): Promise<void> {
    this.avatarId = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
  }

  private async loadReadUrls(): Promise<void> {
    try {
      this.readUrls = await NewsRepository.listReadUrls();
    } catch (e) {
    }
  }

  private async checkDigest(): Promise<void> {
    try {
      const digest = await NewsRepository.todayDigest();
      this.hasDigestToday = digest !== null;
    } catch (e) {
      this.hasDigestToday = false;
    }
  }

  private isRead(item: NewsItem): boolean {
    return this.readUrls.indexOf(item.url) >= 0;
  }

  private async loadFeed(force: boolean): Promise<void> {
    this.loading = true;
    this.error = false;
    const items: NewsItem[] = await NewsService.fetchChannel(this.channelId, 50, force);
    this.items = items;
    this.source.replace(items);
    this.loading = false;
    if (items.length === 0) {
      this.error = true;
    }
  }

  private async doRefresh(): Promise<void> {
    this.refreshing = true;
    await this.loadReadUrls();
    const items: NewsItem[] = await NewsService.fetchChannel(this.channelId, 50, true);
    this.items = items;
    this.source.replace(items);
    this.refreshing = false;
    if (items.length === 0) {
      promptAction.showToast({ message: '暂时没有新内容' });
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.loading || this.items.length === 0) return;
    this.loadingMore = true;
    const more: NewsItem[] = await NewsService.fetchChannel(this.channelId, 100, true);
    const merged: NewsItem[] = NewsService.merge([this.items, more], 200);
    this.items = merged;
    this.source.replace(merged);
    this.loadingMore = false;
  }

  private openDetail(item: NewsItem): void {
    if (this.readUrls.indexOf(item.url) < 0) {
      this.readUrls = this.readUrls.concat([item.url]);
    }
    NewsRepository.markRead(item.url).catch(() => {
    });
    if (this.themeState.isLg) {
      // 平板/2in1：右侧内嵌阅读（真·双栏）
      this.selectedItem = item;
    } else {
      AppNavigator.push('pages/NewsDetail', new NewsDetailRouteParams(item));
    }
  }

  private getGreeting(): string {
    const h: number = new Date().getHours();
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  private formatNow(): string {
    const d: Date = new Date();
    const pad = (n: number) => n < 10 ? '0' + n.toString() : n.toString();
    const weekDays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return d.getFullYear().toString() + '年' + pad(d.getMonth() + 1) + '月' + pad(d.getDate()) +
      '日 星期' + weekDays[d.getDay()];
  }

  // ==================== 问候栏 ====================
  @Builder
  header() {
    Row() {
      Column() {
        Text(this.greeting)
          .fontSize(this.themeState.palette.fsXl + 4)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.currentTime)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 搜索入口
      Row() {
        Text('🔍')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ right: 10 })
      .onClick(() => {
        AppNavigator.push('pages/NewsSearch');
      })

      // 收藏入口
      Row() {
        Text('⭐')
          .fontSize(this.themeState.palette.fsXl)
          .fontFamily(this.themeState.palette.fontSans)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ right: 10 })
      .onClick(() => {
        AppNavigator.push('pages/NewsFavorites');
      })

      // 用户头像（点击进入设置）
      Stack() {
        if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
          Image(this.avatarUri)
            .width(40)
            .height(40)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
            .border({ width: 1.5, color: '#80FFFFFF' })
        } else {
          Column()
            .width(40)
            .height(40)
            .borderRadius(20)
            .linearGradient({
              angle: 135,
              colors: [[avatarColors(this.avatarId)[0], 0.0], [avatarColors(this.avatarId)[1], 1.0]]
            })
            .shadow({ radius: 12, color: avatarColors(this.avatarId)[0] + '55', offsetX: 0, offsetY: 4 })
          Text('Z')
            .fontSize(16)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
      }
      .onClick(() => {
        this.onNavigate('Settings');
      })
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
      top: this.themeState.statusBarHeight + 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== AI 今日要闻入口卡 ====================
  @Builder
  digestCard() {
    Row({ space: 12 }) {
      Column() {
        Text('📰')
          .fontSize(30)
          .fontFamily(this.themeState.palette.fontSans)
      }
      .width(52)
      .height(52)
      .borderRadius(14)
      .backgroundColor(this.themeState.palette.primary + '1A')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text('AI 今日要闻')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.hasDigestToday ? '今日简报已生成，点击查看' : '一键生成当天热点简报（大模型）')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 16, bottom: 4 })
    .onClick(() => {
      AppNavigator.push('pages/NewsDigest');
    })
  }

  // ==================== 列表页脚 ====================
  @Builder
  listFooter() {
    Row() {
      if (this.loadingMore) {
        LoadingProgress()
          .width(18)
          .height(18)
      } else {
        Text('— 已加载全部 —')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
  }

  // ==================== 频道栏 ====================
  @Builder
  channelBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(NEWS_CHANNELS, (channel: NewsChannel) => {
          Row({ space: 4 }) {
            Text(channel.icon)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
            Text(channel.name)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.channelId === channel.id ? this.themeState.palette.textPrimary :
                this.themeState.palette.textSecondary)
              .fontWeight(this.channelId === channel.id ? FontWeight.Bold : FontWeight.Normal)
          }
          .height(34)
          .padding({ left: 14, right: 14 })
          .justifyContent(FlexAlign.Center)
          .borderRadius(17)
          .backgroundColor(this.channelId === channel.id ? this.themeState.palette.primary + '2A' :
            this.themeState.palette.bgSurface2)
          .border({ width: this.channelId === channel.id ? 1.5 : 0,
            color: this.channelId === channel.id ? this.themeState.palette.primary : Color.Transparent })
          .onClick(() => {
            if (this.channelId === channel.id) return;
            this.channelId = channel.id;
            this.loadFeed(false);
          })
        }, (channel: NewsChannel) => channel.id)
      }
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  // ==================== 资讯列表区（useGrid=true 双列；false 单列） ====================
  @Builder
  newsBody(useGrid: boolean) {
    if (this.loading && this.items.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在加载资讯…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.error && this.items.length === 0) {
      Column({ space: 12 }) {
        Text('📡')
          .fontSize(44)
          .fontFamily(this.themeState.palette.fontSans)
        Text('资讯加载失败')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
        Text('请检查网络后重试')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
        Button('重新加载')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(16)
          .height(32)
          .margin({ top: 4 })
          .onClick(() => {
            this.loadFeed(true);
          })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: this.refreshing }) {
        if (useGrid) {
          // 双列网格（平板竖屏 / 手机横屏）
          Grid() {
            LazyForEach(this.source, (item: NewsItem) => {
              GridItem() {
                NewsCard({
                  item: item,
                  read: this.isRead(item),
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); }
                })
              }
            }, (item: NewsItem) => item.id)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10 })
          .onReachEnd(() => {
            this.loadMore();
          })
        } else {
          // 单列列表（手机竖屏 / 双栏左列）
          List({ space: 10 }) {
            LazyForEach(this.source, (item: NewsItem) => {
              ListItem() {
                NewsCard({
                  item: item,
                  read: this.isRead(item),
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); }
                })
              }
            }, (item: NewsItem) => item.id)
            ListItem() {
              this.listFooter()
            }
          }
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10 })
          .onReachEnd(() => {
            this.loadMore();
          })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.doRefresh();
      })
    }
  }

  build() {
    Column() {
      this.header()

      if (this.themeState.isLg) {
        // 平板 / 2in1：左侧列表 + 右侧详情（真·双栏）
        Row() {
          Column() {
            this.digestCard()
            this.channelBar()
            this.newsBody(false)
          }
          .width('38%')
          .height('100%')

          Column() {
            if (this.selectedItem !== null) {
              // key 变化强制重建面板，确保文章切换时内容刷新
              ForEach([this.selectedItem], (item: NewsItem) => {
                NewsDetailPane({ item: item })
              }, (item: NewsItem) => item.id + '|' + item.url)
            } else {
              Column({ space: 10 }) {
                Text('📰')
                  .fontSize(40)
                  .fontFamily(this.themeState.palette.fontSans)
                Text('在左侧选择一篇新闻阅读详情')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        this.digestCard()
        this.channelBar()
        this.newsBody(this.themeState.isMd)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

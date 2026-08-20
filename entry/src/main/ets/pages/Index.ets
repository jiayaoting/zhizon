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
import { NewsAiService } from '../service/NewsAiService';
import { LazyListDataSource } from '../common/LazyDataSource';
import { NewsCard } from '../components/NewsCard';
import { NewsDetailPane } from '../components/NewsDetailPane';
import { NewsDislikePanel } from '../components/NewsDislikePanel';
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
  // 个性化反馈（v0.7）
  @Local likedUrls: string[] = [];
  @Local dislikedUrls: string[] = [];
  @Local dislikeTarget: NewsItem | null = null;
  @Local undoVisible: boolean = false;
  @Local undoItem: NewsItem | null = null;
  @Local undoIndex: number = -1;
  @Local undoTags: string[] = [];
  @Local undoExcluded: boolean = false;
  private undoTimer: number = -1;
  // 外文翻译（M3）：卡片轻量译结果缓存（内存态）
  @Local translations: Record<string, string> = {};
  @Local translatingUrls: string[] = [];
  // 平板双栏：右侧当前阅读的文章（手机模式不使用）
  @Local selectedItem: NewsItem | null = null;
  @Event onNavigate: (key: string) => void = () => {};

  private source: LazyListDataSource<NewsItem> = new LazyListDataSource<NewsItem>([]);

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadAvatar();
    this.loadReadUrls();
    this.loadRatingStates();
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

  // ==================== 点赞 / 点踩（v0.7） ====================

  private async loadRatingStates(): Promise<void> {
    try {
      const ratings = await NewsRepository.listRatings();
      const likes: string[] = [];
      const dislikes: string[] = [];
      for (let i: number = 0; i < ratings.length; i++) {
        if (ratings[i].rating === 1) likes.push(ratings[i].url);
        else if (ratings[i].rating === -1) dislikes.push(ratings[i].url);
      }
      this.likedUrls = likes;
      this.dislikedUrls = dislikes;
    } catch (e) {
    }
  }

  private isLiked(item: NewsItem): boolean {
    return this.likedUrls.indexOf(item.url) >= 0;
  }

  private isDisliked(item: NewsItem): boolean {
    return this.dislikedUrls.indexOf(item.url) >= 0;
  }

  private async toggleLike(item: NewsItem): Promise<void> {
    try {
      const liked: boolean = this.likedUrls.indexOf(item.url) >= 0;
      if (liked) {
        await NewsRepository.removeRating(item.url);
        await NewsRepository.recordEvent('undo', item, 0, '');
        this.likedUrls = this.likedUrls.filter((u: string) => u !== item.url);
        promptAction.showToast({ message: '已取消点赞' });
      } else {
        await NewsRepository.setRating(item, 1, item.tags === undefined ? [] : item.tags);
        this.likedUrls = this.likedUrls.concat([item.url]);
        this.dislikedUrls = this.dislikedUrls.filter((u: string) => u !== item.url);
        promptAction.showToast({ message: '已点赞，之后会多推同类内容' });
      }
    } catch (e) {
    }
  }

  private openDislike(item: NewsItem): void {
    this.dislikeTarget = item;
  }

  private async confirmDislike(item: NewsItem, tags: string[]): Promise<void> {
    this.dislikeTarget = null;
    try {
      await NewsRepository.setRating(item, -1, tags);
      const excluded: boolean = tags.length === 0;
      if (excluded) {
        await NewsRepository.excludeUrl(item.url, 'dislike-no-tag');
      }
      this.likedUrls = this.likedUrls.filter((u: string) => u !== item.url);
      if (this.dislikedUrls.indexOf(item.url) < 0) {
        this.dislikedUrls = this.dislikedUrls.concat([item.url]);
      }
      // 从当前流移除
      let idx: number = -1;
      for (let i: number = 0; i < this.items.length; i++) {
        if (this.items[i].url === item.url) {
          idx = i;
          break;
        }
      }
      this.undoItem = item;
      this.undoIndex = idx;
      this.undoTags = tags.slice();
      this.undoExcluded = excluded;
      const next: NewsItem[] = [];
      for (let i: number = 0; i < this.items.length; i++) {
        if (this.items[i].url !== item.url) next.push(this.items[i]);
      }
      this.items = next;
      this.source.replace(next);
      this.showUndo();
    } catch (e) {
    }
  }

  private showUndo(): void {
    this.undoVisible = true;
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer);
    }
    this.undoTimer = setTimeout(() => {
      this.undoVisible = false;
      this.undoItem = null;
      this.undoTimer = -1;
    }, 5000);
  }

  private async undoDislike(): Promise<void> {
    if (this.undoItem === null) return;
    const item: NewsItem = this.undoItem;
    try {
      await NewsRepository.removeRating(item.url);
      if (this.undoExcluded) {
        await NewsRepository.unexcludeUrl(item.url);
      }
      NewsService.clearExclusionCache();
      this.dislikedUrls = this.dislikedUrls.filter((u: string) => u !== item.url);
      // 恢复文章到原位置附近
      const restored: NewsItem[] = this.items.slice();
      const pos: number = this.undoIndex >= 0 && this.undoIndex < restored.length ? this.undoIndex : 0;
      restored.splice(pos, 0, item);
      this.items = restored;
      this.source.replace(restored);
      this.undoVisible = false;
      this.undoItem = null;
      if (this.undoTimer >= 0) {
        clearTimeout(this.undoTimer);
        this.undoTimer = -1;
      }
      promptAction.showToast({ message: '已撤销' });
    } catch (e) {
    }
  }

  private dismissUndo(): void {
    this.undoVisible = false;
    this.undoItem = null;
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer);
      this.undoTimer = -1;
    }
  }

  // ==================== 外文翻译（M3） ====================

  private async onTranslateItem(item: NewsItem): Promise<void> {
    if (this.translatingUrls.indexOf(item.url) >= 0) return;
    // 缓存优先（news_translations，30 天有效）
    const cached: string = await NewsRepository.getTitleTranslation(item.url);
    if (cached.length > 0) {
      this.translations[item.url] = cached;
      return;
    }
    const config = await NewsAiService.getTranslateConfig();
    if (config === null) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.translatingUrls = this.translatingUrls.concat([item.url]);
    try {
      const result = await NewsAiService.translateTitle(config, item);
      if (result.success && result.content.length > 0) {
        this.translations[item.url] = result.content;
        NewsRepository.saveTitleTranslation(item, result.content, config.displayName).catch(() => {
        });
      } else {
        promptAction.showToast({ message: '翻译失败，请重试' });
      }
    } catch (e) {
      promptAction.showToast({ message: '翻译失败，请重试' });
    }
    this.translatingUrls = this.translatingUrls.filter((u: string) => u !== item.url);
  }

  private translationOf(item: NewsItem): string {
    return this.translations[item.url] === undefined ? '' : this.translations[item.url];
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
    // 隐式信号：点击 +1（阅读事件在详情页加载时记录）
    NewsRepository.recordEvent('click', item, 1, '').catch(() => {
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

      // 我的点赞入口
      Row() {
        Text('👍')
          .fontSize(this.themeState.palette.fsMd + 2)
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
        AppNavigator.push('pages/NewsLikes');
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

  // ==================== 头条轮播（推荐频道） ====================
  @Builder
  headlineSwiper() {
    Swiper() {
      ForEach(this.items.slice(0, 4), (item: NewsItem) => {
        Row({ space: 12 }) {
          Stack() {
            Column()
              .width(72)
              .height(72)
              .borderRadius(14)
              .linearGradient({
                angle: 135,
                colors: [[this.themeState.palette.primary, 0.0], [this.themeState.palette.purple, 1.0]]
              })
            Text('📰')
              .fontSize(28)
              .fontFamily(this.themeState.palette.fontSans)
          }
          .width(72)
          .height(72)

          Column({ space: 4 }) {
            Text(item.title)
              .fontSize(this.themeState.palette.fsMd + 1)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.sourceName + ' · ' + (item.summary.length > 0 ? item.summary.substring(0, 30) : '头条'))
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(14)
        .borderRadius(12)
        .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
        .onClick(() => { this.openDetail(item); })
      }, (item: NewsItem) => item.id)
    }
    .width('100%')
    .height(100)
    .indicator(new DotIndicator().bottom(6).color(this.themeState.palette.bgSurface2)
      .selectedColor(this.themeState.palette.primary))
    .autoPlay(true)
    .loop(true)
    .interval(5000)
    .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
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
                  liked: this.isLiked(item),
                  disliked: this.isDisliked(item),
                  translationText: this.translationOf(item),
                  translating: this.translatingUrls.indexOf(item.url) >= 0,
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); },
                  onLike: (likedItem: NewsItem): void => { this.toggleLike(likedItem); },
                  onDislike: (dislikedItem: NewsItem): void => { this.openDislike(dislikedItem); },
                  onTranslate: (trItem: NewsItem): void => { this.onTranslateItem(trItem); }
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
                  liked: this.isLiked(item),
                  disliked: this.isDisliked(item),
                  translationText: this.translationOf(item),
                  translating: this.translatingUrls.indexOf(item.url) >= 0,
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); },
                  onLike: (likedItem: NewsItem): void => { this.toggleLike(likedItem); },
                  onDislike: (dislikedItem: NewsItem): void => { this.openDislike(dislikedItem); },
                  onTranslate: (trItem: NewsItem): void => { this.onTranslateItem(trItem); }
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

  @Builder
  dislikeOverlay() {
    if (this.dislikeTarget !== null) {
      ForEach([this.dislikeTarget], (target: NewsItem) => {
        NewsDislikePanel({
          item: target,
          onConfirm: (item: NewsItem, tags: string[]): void => { this.confirmDislike(item, tags); },
          onCancel: (): void => { this.dislikeTarget = null; }
        })
      }, (target: NewsItem) => target.url)
    }
  }

  @Builder
  undoBar() {
    if (this.undoVisible && this.undoItem !== null) {
      Column() {
        Row({ space: 10 }) {
          Text(this.undoTags.length > 0 ?
            '已减少「' + this.undoTags.join('、') + '」类推送' : '已减少本篇推荐')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('撤销')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .fontWeight(FontWeight.Medium)
            .padding(6)
            .onClick(() => { this.undoDislike(); })
          Text('✕')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .padding(6)
            .onClick(() => { this.dismissUndo(); })
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
        bottom: this.themeState.isLg ? 20 : 78 })
    }
  }

  build() {
    Stack() {
      Column() {
      this.header()

      if (this.themeState.isLg) {
        // 平板 / 2in1：左侧列表 + 右侧详情（真·双栏）
        Row() {
          Column() {
            this.digestCard()
            if (this.channelId === 'recommend' && this.items.length > 0) {
              this.headlineSwiper()
            }
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
        if (this.channelId === 'recommend' && this.items.length > 0) {
          this.headlineSwiper()
        }
        this.channelBar()
        this.newsBody(this.themeState.isMd)
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      this.dislikeOverlay()
      this.undoBar()
    }
    .width('100%')
    .height('100%')
  }
}

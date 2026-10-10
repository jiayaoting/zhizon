// 智子 - 首页（热榜 · 主功能界面）
// 视图 Tabs（关注/最热/实时/各分类）+ 源卡片流（下拉刷新/单源刷新/关注）
// 设计文档：doc/newsnow-redesign.md §9.1
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { HotEntry, HotViewKey, HOT_VIEWS, HotViewDef, HotDetailRouteParams, HotBoardRouteParams } from '../common/HotModels';
import { HotFeedStore } from '../service/HotFeedStore';
import { NewsNowSync } from '../service/NewsNowSync';
import { NewsNowAuth } from '../service/NewsNowAuth';
import { NewsRepository } from '../service/NewsRepository';
import { DataRepository } from '../service/DataRepository';
import { PageRefreshBus } from '../common/PageRefreshBus';
import { HotSources } from '../common/HotSources';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';
import { HotSourceCard } from '../components/HotSourceCard';

@ComponentV2
export struct IndexPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local currentTime: string = '';
  @Local greeting: string = '';
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Local viewKey: HotViewKey = HotViewKey.Hottest;
  @Local sourceIds: string[] = [];
  @Local starredIds: string[] = [];
  @Local readKeys: string[] = [];
  @Local loading: boolean = true;
  @Local refreshing: boolean = false;
  @Local tick: number = 0;
  @Local hasDigestToday: boolean = false;
  @Local loggedIn: boolean = false;
  @Event onNavigate: (key: string) => void = () => {};

  private onChange = (): void => {
    this.tick = this.tick + 1;
  };

  // 从详情页/设置页返回：刷新已读与关注态
  private onHostShow = (): void => {
    this.loadLocal().then(() => {
      this.tick = this.tick + 1;
    });
    HotFeedStore.refreshIfStale(this.viewKey);
  };

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    HotFeedStore.addChangeListener(this.onChange);
    PageRefreshBus.onHotShow(this.onHostShow);
    this.loadLocal();
    this.loadView(false);
  }

  aboutToDisappear(): void {
    HotFeedStore.removeChangeListener(this.onChange);
    PageRefreshBus.offHotShow(this.onHostShow);
  }

  private async loadLocal(): Promise<void> {
    this.avatarId = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
    this.loggedIn = await NewsNowAuth.isLoggedIn();
    try {
      this.starredIds = await NewsNowSync.focusIds();
    } catch (e) {
      this.starredIds = [];
    }
    try {
      this.readKeys = await NewsRepository.listReadKeys();
    } catch (e) {
      this.readKeys = [];
    }
    try {
      this.hasDigestToday = (await NewsRepository.todayDigest()) !== null;
    } catch (e) {
      this.hasDigestToday = false;
    }
  }

  private async loadView(force: boolean): Promise<void> {
    this.loading = true;
    await HotFeedStore.refreshFocusCache();
    this.sourceIds = await HotFeedStore.sourceIds(this.viewKey);
    await HotFeedStore.ensureView(this.viewKey, force);
    this.loading = false;
    this.tick = this.tick + 1;
  }

  private async switchView(key: HotViewKey): Promise<void> {
    if (this.viewKey === key) return;
    this.viewKey = key;
    this.sourceIds = await HotFeedStore.sourceIds(key);
    this.tick = this.tick + 1;
    if (this.sourceIds.length === 0) return;
    await HotFeedStore.ensureView(key, false);
  }

  private async doRefresh(): Promise<void> {
    this.refreshing = true;
    await this.loadLocal();
    if (this.sourceIds.length === 0) {
      await this.loadView(true);
    } else {
      await HotFeedStore.refreshView(this.viewKey);
    }
    this.refreshing = false;
    this.tick = this.tick + 1;
    if (!this.loggedIn) {
      promptAction.showToast({ message: '登录后可强制刷新最新数据' });
    }
  }

  private async toggleStar(sourceId: string): Promise<void> {
    const starred: boolean = await NewsNowSync.toggleStar(sourceId);
    this.starredIds = await NewsNowSync.focusIds();
    promptAction.showToast({ message: starred ? '已关注，可在「关注」视图查看' : '已取消关注' });
    if (this.viewKey === HotViewKey.Focus) {
      this.sourceIds = await HotFeedStore.sourceIds(HotViewKey.Focus);
    }
    this.tick = this.tick + 1;
  }

  private openEntry(entry: HotEntry): void {
    if (this.readKeys.indexOf(entry.key) < 0) {
      this.readKeys = this.readKeys.concat([entry.key]);
    }
    NewsRepository.markRead(entry.key).catch(() => {
    });
    AppNavigator.push('pages/NewsDetail', new HotDetailRouteParams(entry.key, entry.sourceId,
      entry.sourceName, entry.item.title, entry.item.url, entry.item.info));
  }

  private openBoard(sourceId: string): void {
    AppNavigator.push('pages/HotBoard', new HotBoardRouteParams(sourceId, HotSources.nameOf(sourceId)));
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
    const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
    const weekDays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return d.getFullYear().toString() + '年' + pad(d.getMonth() + 1) + '月' + pad(d.getDate()) +
      '日 星期' + weekDays[d.getDay()];
  }

  // ==================== 问候栏 ====================
  @Builder
  header() {
    Row() {
      Row({ space: 8 }) {
        Text(this.greeting)
          .fontSize(this.themeState.palette.fsXl + 2)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.currentTime)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)

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
      top: Math.max(this.themeState.statusBarHeight, 44) + 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== AI 今日要闻入口 ====================
  @Builder
  digestCard() {
    Row({ space: 10 }) {
      Text('📰')
        .fontSize(20)
        .fontFamily(this.themeState.palette.fontSans)
      Text('AI 今日要闻')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Blank()
      Text(this.hasDigestToday ? '已生成 ›' : '生成今日简报 ›')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
    .margin({ top: 8, bottom: 4 })
    .onClick(() => {
      AppNavigator.push('pages/NewsDigest');
    })
  }

  // ==================== 服务器离线横幅 ====================
  @Builder
  offlineBanner() {
    if (!HotFeedStore.isServerOnline()) {
      Row({ space: 8 }) {
        Text('⚠️')
          .fontSize(this.themeState.palette.fsSm)
        Text('无法连接热榜服务器')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .layoutWeight(1)
        Text('去设置')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .onClick(() => {
            AppNavigator.push('pages/NewsSettings');
          })
      }
      .width('100%')
      .height(38)
      .padding({ left: 12, right: 12 })
      .borderRadius(10)
      .backgroundColor(this.themeState.palette.warning + '22')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 6 })
    }
  }

  // ==================== 视图 Tabs ====================
  @Builder
  viewBar() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(HOT_VIEWS, (view: HotViewDef) => {
          Row({ space: 4 }) {
            Text(view.icon)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
            Text(view.name)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.viewKey === view.key ? this.themeState.palette.textPrimary :
                this.themeState.palette.textSecondary)
              .fontWeight(this.viewKey === view.key ? FontWeight.Bold : FontWeight.Normal)
          }
          .height(40)
          .padding({ left: 16, right: 16 })
          .justifyContent(FlexAlign.Center)
          .borderRadius(20)
          .backgroundColor(this.viewKey === view.key ? this.themeState.palette.primary + '2A' :
            this.themeState.palette.bgSurface2)
          .border({ width: this.viewKey === view.key ? 1.5 : 0,
            color: this.viewKey === view.key ? this.themeState.palette.primary : Color.Transparent })
          .onClick(() => {
            this.switchView(view.key);
          })
        }, (view: HotViewDef) => view.key)
      }
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 4 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  // ==================== 卡片内容区 ====================
  @Builder
  feedBody(useGrid: boolean) {
    if (this.loading && this.sourceIds.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在加载热榜…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.sourceIds.length === 0) {
      this.emptyState()
    } else {
      Refresh({ refreshing: this.refreshing }) {
        if (useGrid) {
          Grid() {
            ForEach(this.sourceIds, (sourceId: string) => {
              GridItem() {
                HotSourceCard({
                  sourceId: sourceId,
                  starred: this.starredIds.indexOf(sourceId) >= 0,
                  limit: 5,
                  readKeys: this.readKeys,
                  tick: this.tick,
                  onToggleStar: (id: string): void => { this.toggleStar(id); },
                  onOpenEntry: (e: HotEntry): void => { this.openEntry(e); },
                  onOpenBoard: (id: string): void => { this.openBoard(id); },
                  onRefresh: (id: string): void => {
                    HotFeedStore.refreshSource(id, true).then(() => {
                      this.tick = this.tick + 1;
                    });
                  }
                })
              }
            }, (sourceId: string) => sourceId + ':' + this.tick.toString())
          }
          .columnsTemplate(this.themeState.isLg ? '1fr 1fr 1fr' : '1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
            top: 8, bottom: 12 })
        } else {
          List({ space: 10 }) {
            ForEach(this.sourceIds, (sourceId: string) => {
              ListItem() {
                HotSourceCard({
                  sourceId: sourceId,
                  starred: this.starredIds.indexOf(sourceId) >= 0,
                  limit: 5,
                  readKeys: this.readKeys,
                  tick: this.tick,
                  onToggleStar: (id: string): void => { this.toggleStar(id); },
                  onOpenEntry: (e: HotEntry): void => { this.openEntry(e); },
                  onOpenBoard: (id: string): void => { this.openBoard(id); },
                  onRefresh: (id: string): void => {
                    HotFeedStore.refreshSource(id, true).then(() => {
                      this.tick = this.tick + 1;
                    });
                  }
                })
              }
            }, (sourceId: string) => sourceId + ':' + this.tick.toString())
            ListItem() {
              Row() {
                Text('— 已加载全部源 —')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
              .width('100%')
              .height(44)
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
            top: 8, bottom: 12 })
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
  emptyState() {
    Column({ space: 12 }) {
      Text(this.viewKey === HotViewKey.Focus ? '⭐' : '📭')
        .fontSize(44)
        .fontFamily(this.themeState.palette.fontSans)
      Text(this.viewKey === HotViewKey.Focus ? '还没有关注的源' : '该分类暂无可用源')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
      Text(this.viewKey === HotViewKey.Focus ? '点击任意源卡片右上角 ⭐ 添加关注' : '试试其他视图')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
      if (this.viewKey === HotViewKey.Focus) {
        Button('去看最热榜')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(16)
          .height(32)
          .margin({ top: 4 })
          .onClick(() => {
            this.switchView(HotViewKey.Hottest);
          })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      this.header()
      this.digestCard()
      this.offlineBanner()
      this.viewBar()
      this.feedBody(this.themeState.isMd || this.themeState.isLg)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

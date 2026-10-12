// 智子 - 首页（热榜 · 主功能界面）· v10 华为原生拟物白
// 大标题 + 今日要闻胶囊 + 下划线视图 Tabs + 源卡片流（下拉刷新 / 单源刷新 / ⭐关注）
// 设计文档：doc/v10-redesign.md §3.4 / §4.1；接口契约：doc/newsnow-redesign.md
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { HotEntry, HotViewKey, HOT_VIEWS, HotViewDef, HotDetailRouteParams, HotBoardRouteParams } from '../common/HotModels';
import { HotFeedStore } from '../service/hot/HotFeedStore';
import { NewsNowSync } from '../service/hot/NewsNowSync';
import { NewsNowAuth } from '../service/hot/NewsNowAuth';
import { NewsRepository } from '../service/hot/NewsRepository';
import { PageRefreshBus } from '../common/PageRefreshBus';
import { HotSources } from '../common/HotSources';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { HotSourceCard } from '../components/HotSourceCard';

@ComponentV2
export struct IndexPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local todayLabel: string = '';
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
    this.todayLabel = this.formatToday();
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
    promptAction.showToast({ message: starred ? '已关注' : '已取消关注' });
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

  private formatToday(): string {
    const d: Date = new Date();
    const weekDays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return (d.getMonth() + 1).toString() + '月' + d.getDate().toString() + '日 星期' + weekDays[d.getDay()];
  }

  // 图标按钮（矢量优先，emoji 回退）
  @Builder
  iconButton(icon: Resource, emoji: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(44)
    .height(44)
    .borderRadius(this.themeState.palette.radiusSm)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // ==================== 大标题栏（无返回；操作区 2 个图标）====================
  @Builder
  header() {
    Row({ space: 4 }) {
      Column({ space: 2 }) {
        Text('热榜')
          .fontSize(this.themeState.palette.fsXl)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.todayLabel)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.iconButton(AppIcons.search, AppIcons.searchEmoji, (): void => {
        AppNavigator.push('pages/NewsSearch');
      })
      this.iconButton(AppIcons.settings, AppIcons.settingsEmoji, (): void => {
        AppNavigator.push('pages/NewsSettings');
      })
    }
    .width('100%')
    .padding({
      left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      top: Math.max(this.themeState.statusBarHeight, 44) + 8,
      bottom: 4
    })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== AI 今日要闻（胶囊条）====================
  @Builder
  digestBar() {
    Row({ space: this.themeState.palette.sp2 }) {
      Text('🌤')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
      Text('AI 今日要闻')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Blank()
      Text(this.hasDigestToday ? '已生成' : '生成今日简报')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.forward)
          .fontSize(16)
          .fontColor([this.themeState.palette.textTertiary])
      } else {
        Text(AppIcons.forwardEmoji)
          .fontSize(this.themeState.palette.fsSm)
          .fontColor(this.themeState.palette.textTertiary)
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 14, right: 12 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      AppNavigator.push('pages/NewsDigest');
    })
  }

  // ==================== 服务器不可达提示 ====================
  @Builder
  offlineBanner() {
    if (!HotFeedStore.isServerOnline()) {
      Row({ space: this.themeState.palette.sp2 }) {
        Text(AppIcons.warningEmoji)
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
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(this.themeState.palette.radiusSm)
      .backgroundColor(this.themeState.palette.warningBg)
      .alignItems(VerticalAlign.Center)
    }
  }

  // ==================== 视图 Tabs（华为式下划线）====================
  @Builder
  viewTab(view: HotViewDef) {
    Column({ space: 5 }) {
      Text(view.name)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.viewKey === view.key ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .fontWeight(this.viewKey === view.key ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
      Row()
        .width(20)
        .height(2.5)
        .borderRadius(2)
        .backgroundColor(this.viewKey === view.key ? this.themeState.palette.primary : Color.Transparent)
    }
    .height(42)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.switchView(view.key);
    })
  }

  @Builder
  viewBar() {
    Scroll() {
      Row({ space: this.themeState.palette.sp5 }) {
        ForEach(HOT_VIEWS, (view: HotViewDef) => {
          this.viewTab(view)
        }, (view: HotViewDef) => view.key)
      }
      .padding({
        left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        top: 4
      })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor(this.themeState.palette.bgBase)
  }

  // ==================== 源卡片 ====================
  @Builder
  sourceCard(sourceId: string) {
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

  // ==================== 内容区 ====================
  @Builder
  feedBody(useGrid: boolean) {
    if (this.loading && this.sourceIds.length === 0) {
      Column({ space: this.themeState.palette.sp3 }) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(this.themeState.palette.primary)
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
                this.sourceCard(sourceId)
              }
            }, (sourceId: string) => sourceId + ':' + this.tick.toString())
          }
          .columnsTemplate(this.themeState.isLg ? '1fr 1fr 1fr' : '1fr 1fr')
          .columnsGap(this.themeState.palette.cardGap)
          .rowsGap(this.themeState.palette.cardGap)
          .width('100%')
          .padding({
            left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: this.themeState.palette.sp2,
            bottom: this.themeState.palette.sp4
          })
        } else {
          List({ space: this.themeState.palette.cardGap }) {
            ForEach(this.sourceIds, (sourceId: string) => {
              ListItem() {
                this.sourceCard(sourceId)
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
          .padding({
            left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: this.themeState.palette.sp2,
            bottom: this.themeState.palette.sp4
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

  // 空态：原因 + 下一步 CTA
  @Builder
  emptyState() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text(this.viewKey === HotViewKey.Focus ? '⭐' : '📭')
        .fontSize(48)
        .fontFamily(this.themeState.palette.fontSans)
      Text(this.viewKey === HotViewKey.Focus ? '还没有关注的源' : '该分类暂无可用源')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text(this.viewKey === HotViewKey.Focus ? '在源卡片右上角点 ⭐ 即可关注' : '换个视图看看')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      if (this.viewKey === HotViewKey.Focus) {
        Text('去看最热榜')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Medium)
          .height(44)
          .padding({ left: 24, right: 24 })
          .borderRadius(this.themeState.palette.radiusCapsule)
          .backgroundColor(this.themeState.palette.primary)
          .textAlign(TextAlign.Center)
          .margin({ top: this.themeState.palette.sp1 })
          .onClick(() => {
            this.switchView(HotViewKey.Hottest);
          })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: this.themeState.palette.pagePadding, right: this.themeState.palette.pagePadding })
  }

  build() {
    Column() {
      this.header()
      Column({ space: this.themeState.palette.sp2 }) {
        this.digestBar()
        this.offlineBanner()
      }
      .width('100%')
      .padding({
        left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        top: this.themeState.palette.sp1,
        bottom: this.themeState.palette.sp1
      })
      this.viewBar()
      this.feedBody(this.themeState.isMd || this.themeState.isLg)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

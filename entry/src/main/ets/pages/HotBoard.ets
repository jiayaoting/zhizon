// 智子 - 单源榜单页（v10 华为原生拟物白）
// 顶栏：‹ 返回 + 源徽标 + 源名/更新时间 + ⭐ 关注 + ⋯（源站首页 / 复制榜单链接 / 刷新）
// 列表：白卡（bgSurface + radiusLg + 发丝边） + HotItemRow 统一条目行 + 下拉刷新 = 单源 latest 抓取
// 设计文档：doc/v10-redesign.md §4.2；数据流沿用 doc/newsnow-redesign.md §9.2
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { HotEntry, HotBoardRouteParams, HotDetailRouteParams } from '../common/HotModels';
import { HotSources, HotSourceDef } from '../common/HotSources';
import { hotClockTime } from '../common/HotFormat';
import { HotFeedStore, BoardSlot, SlotStatus } from '../service/hot/HotFeedStore';
import { NewsNowSync } from '../service/hot/NewsNowSync';
import { NewsRepository } from '../service/hot/NewsRepository';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { HotSourceBadge } from '../components/HotSourceBadge';
import { HotItemRow } from '../components/HotItemRow';

@ComponentV2
@Entry
export struct HotBoardPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local sourceId: string = '';
  @Local tick: number = 0;
  @Local refreshing: boolean = false;
  @Local starred: boolean = false;
  @Local readKeys: string[] = [];

  private onChange = (): void => {
    this.tick = this.tick + 1;
  };

  aboutToAppear(): void {
    const params: HotBoardRouteParams | null =
      AppNavigator.getParam('pages/HotBoard') as HotBoardRouteParams | null;
    if (params !== null) {
      this.sourceId = params.sourceId;
    }
    HotFeedStore.addChangeListener(this.onChange);
    this.loadState();
    if (this.sourceId.length > 0) {
      const slot: BoardSlot = HotFeedStore.slotOf(this.sourceId);
      if (slot.status === SlotStatus.Idle) {
        HotFeedStore.refreshSource(this.sourceId, false);
      }
    }
  }

  aboutToDisappear(): void {
    HotFeedStore.removeChangeListener(this.onChange);
  }

  private async loadState(): Promise<void> {
    this.starred = await NewsNowSync.isStarred(this.sourceId);
    try {
      this.readKeys = await NewsRepository.listReadKeys();
    } catch (e) {
      this.readKeys = [];
    }
    this.tick = this.tick + 1;
  }

  private slot(): BoardSlot {
    return HotFeedStore.slotOf(this.sourceId);
  }

  private entries(): HotEntry[] {
    return HotFeedStore.entriesOf(this.sourceId);
  }

  private async toggleStar(): Promise<void> {
    this.starred = await NewsNowSync.toggleStar(this.sourceId);
    promptAction.showToast({ message: this.starred ? '已关注' : '已取消关注' });
  }

  private async doRefresh(): Promise<void> {
    this.refreshing = true;
    await HotFeedStore.refreshSource(this.sourceId, true);
    this.refreshing = false;
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

  private openHome(): void {
    const def: HotSourceDef | null = HotSources.byId(this.sourceId);
    if (def === null || def.home.length === 0) return;
    AppNavigator.push('pages/NewsDetail', new HotDetailRouteParams('', this.sourceId,
      HotSources.nameOf(this.sourceId), def.name, def.home, ''));
  }

  // 复制榜单链接（源站首页地址）
  private async copyBoardLink(): Promise<void> {
    const def: HotSourceDef | null = HotSources.byId(this.sourceId);
    const link: string = def === null ? '' : def.home;
    if (link.length === 0) {
      promptAction.showToast({ message: '该源暂无榜单链接' });
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制榜单链接' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // 页边距：手机 pagePadding(16vp) / 大屏 pagePaddingLg(24vp)
  private pagePad(): string {
    return this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg;
  }

  // 顶栏图标动作：≥44vp 触控区（icon/emoji 为固定入参；状态在各自 builder 内读取，避免按值传参不刷新）
  @Builder
  barIcon(icon: Resource, emoji: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(18)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(onTap)
  }

  // 关注：已关注用主色实心星（一个图标一个含义；在 builder 内直接读状态，保证选中态刷新）
  @Builder
  starButton() {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(this.starred ? AppIcons.starFill : AppIcons.star)
          .fontSize(22)
          .fontColor([this.starred ? this.themeState.palette.primary : this.themeState.palette.textSecondary])
      } else {
        Text(this.starred ? AppIcons.starFillEmoji : AppIcons.starEmoji)
          .fontSize(18)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.starred ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(this.starred ? '取消关注' : '关注')
    .onClick(() => {
      this.toggleStar();
    })
  }

  // overflow 菜单：顶栏只留 ≤3 个图标，次级动作收进 ⋯
  private overflowMenu(): MenuElement[] {
    const homeIcon: ResourceStr = USE_SYMBOL_ICONS ? AppIcons.globe : AppIcons.globeEmoji;
    const linkIcon: ResourceStr = USE_SYMBOL_ICONS ? AppIcons.link : AppIcons.linkEmoji;
    const refreshIcon: ResourceStr = USE_SYMBOL_ICONS ? AppIcons.refresh : AppIcons.refreshEmoji;
    const items: MenuElement[] = [
      { value: '源站首页', icon: homeIcon, action: (): void => { this.openHome(); } },
      { value: '复制榜单链接', icon: linkIcon, action: (): void => { this.copyBoardLink(); } },
      { value: '刷新', icon: refreshIcon, action: (): void => { this.doRefresh(); } }
    ];
    return items;
  }

  @Builder
  moreButton() {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.more)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(AppIcons.moreEmoji)
          .fontSize(20)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .accessibilityText('更多操作')
    .bindMenu(this.overflowMenu())
  }

  @Builder
  topBar() {
    Row({ space: this.themeState.palette.sp2 }) {
      this.barIcon(AppIcons.back, AppIcons.backEmoji, (): void => {
        AppNavigator.pop();
      })

      HotSourceBadge({ sourceId: this.sourceId, badgeSize: 32 })

      Column({ space: 2 }) {
        Text(HotSources.nameOf(this.sourceId))
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.updatedLabel())
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

      // 关注：已关注用主色实心星（一个图标一个含义）
      this.starButton()

      this.moreButton()
    }
    .width('100%')
    .padding({
      left: this.pagePad(), right: this.pagePad(),
      top: Math.max(this.themeState.statusBarHeight, 44) + 6, bottom: 6
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR,
      this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
    .border({
      width: { bottom: 0.5 },
      color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette)
    })
  }

  private updatedLabel(): string {
    const slot: BoardSlot = this.slot();
    if (slot.data === null) return '加载中…';
    const t: string = hotClockTime(slot.data.updatedTime);
    if (t.length === 0) return '';
    return (slot.data.fromCache ? '缓存更新于 ' : '更新于 ') + t;
  }

  // 下拉刷新指示器：系统 Refresh 默认指示器无法染色，用自定义 builder 走主色
  @Builder
  refreshIndicator() {
    Row() {
      LoadingProgress()
        .width(22)
        .height(22)
        .color(this.themeState.palette.primary)
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  loadingState() {
    Column({ space: this.themeState.palette.sp3 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(this.themeState.palette.primary)
      Text('正在加载热榜…')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 空态/错误态：插画字 + 原因 + 下一步 CTA
  @Builder
  emptyState() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('📡')
        .fontSize(56)
      Text(this.slot().error.length > 0 ? this.slot().error : '这个榜单暂时没有内容')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
      Text('可能是网络不通或服务端暂无数据，可重新加载试试')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      Button('重新加载')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.themeState.palette.primary)
        .borderRadius(this.themeState.palette.radiusCapsule)
        .height(this.themeState.palette.touchTarget)
        .padding({ left: 28, right: 28 })
        .margin({ top: this.themeState.palette.sp1 })
        .onClick(() => {
          HotFeedStore.refreshSource(this.sourceId, false);
        })
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: this.themeState.palette.sp8, right: this.themeState.palette.sp8 })
    .justifyContent(FlexAlign.Center)
  }

  // 榜单白卡：无阴影，靠发丝边与分割线分层
  @Builder
  listCard() {
    Column() {
      List({ space: 0 }) {
        ForEach(this.entries(), (entry: HotEntry, index: number) => {
          ListItem() {
            Column() {
              HotItemRow({
                entry: entry,
                rank: index + 1,
                read: this.readKeys.indexOf(entry.key) >= 0,
                showDivider: index < this.entries().length - 1,
                onOpen: (e: HotEntry): void => { this.openEntry(e); }
              })
            }
            .width('100%')
            .constraintSize({ minHeight: this.themeState.palette.rowHeightCompact })
            .justifyContent(FlexAlign.Center)
          }
        }, (entry: HotEntry) => entry.key + ':' + this.tick.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 14, top: this.themeState.palette.sp1, bottom: this.themeState.palette.sp2 })
    .backgroundColor(this.themeState.palette.bgSurface)
    .borderRadius(this.themeState.palette.radiusLg)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .clip(true)
  }

  @Builder
  body() {
    if (this.slot().status === SlotStatus.Loading && this.slot().data === null) {
      this.loadingState()
    } else if (this.entries().length === 0) {
      this.emptyState()
    } else {
      Refresh({ refreshing: this.refreshing, builder: this.refreshIndicator() }) {
        this.listCard()
      }
      .layoutWeight(1)
      .width('100%')
      .padding({
        left: this.pagePad(), right: this.pagePad(), top: this.themeState.palette.sp2,
        bottom: Math.max(16, this.themeState.navBarHeight)
      })
      .onRefreshing(() => {
        this.doRefresh();
      })
    }
  }

  build() {
    Column() {
      this.topBar()
      this.body()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

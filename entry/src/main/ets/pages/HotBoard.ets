// 智子 - 单源榜单页（完整 30 条 + 下拉强制刷新 + 关注/源站入口）
// 设计文档：doc/newsnow-redesign.md §9.2
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { HotEntry, HotBoardRouteParams, HotDetailRouteParams } from '../common/HotModels';
import { HotSources, HotSourceDef } from '../common/HotSources';
import { hotClockTime } from '../common/HotFormat';
import { HotFeedStore, BoardSlot, SlotStatus } from '../service/HotFeedStore';
import { NewsNowSync } from '../service/NewsNowSync';
import { NewsRepository } from '../service/NewsRepository';
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

  @Builder
  topBar() {
    Row({ space: 10 }) {
      Text('‹')
        .fontSize(26)
        .fontColor(this.themeState.palette.textPrimary)
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          AppNavigator.pop();
        })

      HotSourceBadge({ sourceId: this.sourceId, badgeSize: 30 })

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
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.starred ? '⭐' : '☆')
        .fontSize(this.themeState.palette.fsLg)
        .padding(6)
        .onClick(() => {
          this.toggleStar();
        })

      Text('🌐')
        .fontSize(this.themeState.palette.fsMd)
        .padding(6)
        .onClick(() => {
          this.openHome();
        })
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? 12 : 20, right: this.themeState.isSm ? 12 : 20,
      top: Math.max(this.themeState.statusBarHeight, 44) + 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  private updatedLabel(): string {
    const slot: BoardSlot = this.slot();
    if (slot.data === null) return '加载中…';
    const t: string = hotClockTime(slot.data.updatedTime);
    if (t.length === 0) return '';
    return (slot.data.fromCache ? '缓存更新于 ' : '刚刚更新 ') + t;
  }

  @Builder
  body() {
    if (this.slot().status === SlotStatus.Loading && this.slot().data === null) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在加载…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.entries().length === 0) {
      Column({ space: 12 }) {
        Text('📡')
          .fontSize(44)
        Text(this.slot().error.length > 0 ? this.slot().error : '暂无数据')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
        Button('重新加载')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(16)
          .height(32)
          .onClick(() => {
            HotFeedStore.refreshSource(this.sourceId, false);
          })
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: this.refreshing }) {
        List({ space: 0 }) {
          ForEach(this.entries(), (entry: HotEntry, index: number) => {
            ListItem() {
              HotItemRow({
                entry: entry,
                rank: index + 1,
                read: this.readKeys.indexOf(entry.key) >= 0,
                showDivider: index < this.entries().length - 1,
                onOpen: (e: HotEntry): void => { this.openEntry(e); }
              })
            }
          }, (entry: HotEntry) => entry.key + ':' + this.tick.toString())
        }
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, bottom: 16 })
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
      this.topBar()
      this.body()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

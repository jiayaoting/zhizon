// 智子 - 热榜源卡片（v10：华为拟物白白卡 + 矢量操作图标）
// 契约保持不变：@Param sourceId / starred / limit / readKeys / tick，
// @Event onToggleStar / onOpenEntry / onOpenBoard / onRefresh
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { HotEntry } from '../common/HotModels';
import { HotSources } from '../common/HotSources';
import { hotClockTime } from '../common/HotFormat';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { BoardSlot, SlotStatus, HotFeedStore } from '../service/hot/HotFeedStore';
import { HotSourceBadge } from './HotSourceBadge';
import { HotItemRow } from './HotItemRow';

@ComponentV2
export struct HotSourceCard {
  @Param sourceId: string = '';
  @Param starred: boolean = false;
  @Param limit: number = 5;         // 展示条数（首页 5，单源页全部）
  @Param readKeys: string[] = [];
  @Param tick: number = 0;          // 外部状态版本号，用于强制刷新
  @Event onToggleStar: (sourceId: string) => void = () => {};
  @Event onOpenEntry: (entry: HotEntry) => void = () => {};
  @Event onOpenBoard: (sourceId: string) => void = () => {};
  @Event onRefresh: (sourceId: string) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private slot(): BoardSlot {
    return HotFeedStore.slotOf(this.sourceId);
  }

  private isRead(key: string): boolean {
    return this.readKeys.indexOf(key) >= 0;
  }

  private visibleEntries(): HotEntry[] {
    const all: HotEntry[] = HotFeedStore.entriesOf(this.sourceId);
    return all.length <= this.limit ? all : all.slice(0, this.limit);
  }

  private updatedLabel(): string {
    const slot: BoardSlot = this.slot();
    if (slot.data === null) return '';
    const t: string = hotClockTime(slot.data.updatedTime);
    if (t.length === 0) return '';
    return (slot.data.fromCache ? '更新于 ' : '刚刚更新 ') + t;
  }

  // 卡片头：源徽标 + 源名/更新时间 + ⭐ + ↻
  @Builder
  cardHeader() {
    Row({ space: this.themeState.palette.sp2 }) {
      HotSourceBadge({ sourceId: this.sourceId, badgeSize: 28 })

      Column({ space: 2 }) {
        Text(HotSources.nameOf(this.sourceId))
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.updatedLabel())
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 关注（已关注用主色实心星）
      Row() {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(this.starred ? AppIcons.starFill : AppIcons.star)
            .fontSize(20)
            .fontColor([this.starred ? this.themeState.palette.primary : this.themeState.palette.textTertiary])
        } else {
          Text(this.starred ? AppIcons.starFillEmoji : AppIcons.starEmoji)
            .fontSize(this.themeState.palette.fsMd)
        }
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onToggleStar(this.sourceId);
      })

      // 单源刷新
      Row() {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(AppIcons.refresh)
            .fontSize(19)
            .fontColor([this.themeState.palette.textSecondary])
        } else {
          Text(AppIcons.refreshEmoji)
            .fontSize(this.themeState.palette.fsMd)
            .fontColor(this.themeState.palette.textSecondary)
        }
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onRefresh(this.sourceId);
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  body() {
    if (this.slot().status === SlotStatus.Loading && this.slot().data === null) {
      Row({ space: this.themeState.palette.sp2 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.themeState.palette.primary)
        Text('加载中…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .height(64)
      .justifyContent(FlexAlign.Center)
    } else if (this.slot().data === null) {
      Column({ space: this.themeState.palette.sp1 }) {
        Text(this.slot().error.length > 0 ? this.slot().error : '暂无数据')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
        Text('点击重试')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
      }
      .width('100%')
      .height(76)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onRefresh(this.sourceId);
      })
    } else {
      ForEach(this.visibleEntries(), (entry: HotEntry, index: number) => {
        HotItemRow({
          entry: entry,
          rank: index + 1,
          read: this.isRead(entry.key),
          showDivider: index < this.visibleEntries().length - 1,
          onOpen: (e: HotEntry): void => { this.onOpenEntry(e); }
        })
      }, (entry: HotEntry) => entry.key + ':' + this.tick.toString())

      // 查看全部（仅首页限流时显示）
      if (this.limit > 0 && HotFeedStore.entriesOf(this.sourceId).length > this.limit) {
        Row({ space: 4 }) {
          Text('查看全部 ' + HotFeedStore.entriesOf(this.sourceId).length.toString() + ' 条')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(AppIcons.forward)
              .fontSize(14)
              .fontColor([this.themeState.palette.primary])
          } else {
            Text(AppIcons.forwardEmoji)
              .fontSize(this.themeState.palette.fsXs)
              .fontColor(this.themeState.palette.primary)
          }
        }
        .width('100%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onOpenBoard(this.sourceId);
        })
      }
    }
  }

  build() {
    Column({ space: 2 }) {
      this.cardHeader()
      this.body()
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 8 })
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
  }
}

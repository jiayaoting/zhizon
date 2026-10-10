// 智子 - 热榜源卡片（源徽标 + 时间 + ⭐关注 + 条目列表 + 查看全部）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { HotEntry } from '../common/HotModels';
import { HotSources } from '../common/HotSources';
import { hotClockTime } from '../common/HotFormat';
import { BoardSlot, SlotStatus, HotFeedStore } from '../service/HotFeedStore';
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

  @Builder
  cardHeader() {
    Row({ space: 10 }) {
      HotSourceBadge({ sourceId: this.sourceId, badgeSize: 28 })

      Column({ space: 2 }) {
        Text(HotSources.nameOf(this.sourceId))
          .fontSize(this.themeState.palette.fsMd)
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
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 关注星
      Text(this.starred ? '⭐' : '☆')
        .fontSize(this.themeState.palette.fsLg)
        .padding(6)
        .onClick(() => {
          this.onToggleStar(this.sourceId);
        })

      // 单源刷新
      Text('↻')
        .fontSize(this.themeState.palette.fsLg)
        .fontColor(this.themeState.palette.textSecondary)
        .padding(6)
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
      Row({ space: 8 }) {
        LoadingProgress()
          .width(18)
          .height(18)
        Text('加载中…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .height(60)
      .justifyContent(FlexAlign.Center)
    } else if (this.slot().data === null) {
      Column({ space: 8 }) {
        Text(this.slot().error.length > 0 ? this.slot().error : '暂无数据')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
        Text('点击重试')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
      }
      .width('100%')
      .height(70)
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
        Row() {
          Text('查看全部 ' + HotFeedStore.entriesOf(this.sourceId).length.toString() + ' 条')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
        }
        .width('100%')
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onOpenBoard(this.sourceId);
        })
      }
    }
  }

  build() {
    Column({ space: 4 }) {
      this.cardHeader()
      this.body()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
  }
}

// 智子 - 热榜源选择器（v10「管理源」列表；从 NewsSettings 拆出，见 doc/v10-redesign.md §5.4）
// 契约：仅暴露 @Param focusIds + @Event onToggleStar，不感知 service（取数/编排仍在页面）。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { HotSources } from '../common/HotSources';
import { HotSourceBadge } from './HotSourceBadge';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

// 分组顺序固定：国内 → 科技 → 财经 → 国际 → 体育
const PICKER_COLUMNS: string[] = ['china', 'tech', 'finance', 'world', 'sports'];

@ComponentV2
export struct HotSourcePicker {
  @Param focusIds: string[] = [];
  @Event onToggleStar: (sourceId: string) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private starred(sourceId: string): boolean {
    return this.focusIds.indexOf(sourceId) >= 0;
  }

  // 星标切换：已关注 = primary 实心星；未关注 = textTertiary 线框星。触控目标 44vp。
  @Builder
  starToggle(sourceId: string) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(this.starred(sourceId) ? AppIcons.starFill : AppIcons.star)
          .fontSize(20)
          .fontColor([this.starred(sourceId) ? this.themeState.palette.primary :
            this.themeState.palette.textTertiary])
      } else {
        Text(this.starred(sourceId) ? AppIcons.starFillEmoji : AppIcons.starEmoji)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.starred(sourceId) ? this.themeState.palette.primary :
            this.themeState.palette.textTertiary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.starred(sourceId) ? '取消关注' : '关注')
    .onClick(() => {
      this.onToggleStar(sourceId);
    })
  }

  // 单行：徽标 + 名称 + 星标；行高 48vp，行间发丝分割线左缩进 dividerIndent
  @Builder
  sourceRow(sourceId: string, showDivider: boolean) {
    Column({ space: 0 }) {
      if (showDivider) {
        Divider()
          .color(this.themeState.palette.divider)
          .strokeWidth(0.5)
          .margin({ left: this.themeState.palette.dividerIndent })
      }
      Row({ space: this.themeState.palette.sp3 }) {
        HotSourceBadge({ sourceId: sourceId, badgeSize: 28 })
        Text(HotSources.nameOf(sourceId))
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        this.starToggle(sourceId)
      }
      .width('100%')
      .height(this.themeState.palette.rowHeightCompact)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  build() {
    Column({ space: this.themeState.palette.sp4 }) {
      ForEach(PICKER_COLUMNS, (column: string) => {
        Column({ space: 0 }) {
          Text(HotSources.groupLabel(column))
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ bottom: this.themeState.palette.sp1 })
          ForEach(HotSources.byColumn(column), (sourceId: string, index: number) => {
            this.sourceRow(sourceId, index > 0)
          }, (sourceId: string) => sourceId)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (column: string) => column)
    }
    .width('100%')
  }
}

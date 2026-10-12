// 智子 - 大屏侧边导航（v10 华为原生拟物白 · 2in1 / 平板横屏 / isLg 时替代底部导航）
// 条目与底部导航完全一致（同 5 项、同图标）；选中态 = primaryBg 胶囊 + primary 文字/图标。
// 玻璃材质仅此级（P0_BAR）保留。
import { AppConstants, NavItem, SIDEBAR_WIDTH } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct SideNav {
  @Param selectedKey: MainNavKey = MainNavKey.Index;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onSelect: (key: MainNavKey) => void = () => {};

  // Tab 键 → 矢量图标：统一走 AppIcons（与底部导航一对一，同一图标同一含义）
  private itemColor(key: MainNavKey): string {
    return key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textSecondary;
  }

  @Builder
  navItem(item: NavItem) {
    Row({ space: this.themeState.palette.sp3 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.navIcon(item.key))
          .fontSize(22)
          .fontColor([this.itemColor(item.key)])
          .accessibilityLevel('no')
      } else {
        Text(AppIcons.navEmoji(item.key))
          .fontSize(20)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.itemColor(item.key))
      }
      Text(item.label)
        .fontSize(this.themeState.palette.fsBase)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.itemColor(item.key))
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
    }
    .width('100%')
    .height(this.themeState.palette.rowHeightCompact)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusMd)
    .backgroundColor(item.key === this.selectedKey ? this.themeState.palette.primaryBg : Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(item.label + (item.key === this.selectedKey ? '，已选中' : ''))
    .onClick(() => {
      this.onSelect(item.key);
    })
  }

  build() {
    Column() {
      // 顶部品牌区
      Column({ space: 4 }) {
        Row({ space: 10 }) {
          Text('🧠')
            .fontSize(this.themeState.palette.fsXl)
          Text(AppConstants.appName)
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(VerticalAlign.Center)

        Text('全网热榜 · 智能对话 · 休闲游戏')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: this.themeState.palette.sp4,
        right: this.themeState.palette.sp4,
        top: this.themeState.statusBarHeight + 16,
        bottom: this.themeState.palette.sp5
      })

      Divider()
        .strokeWidth(0.5)
        .color(this.themeState.palette.divider)
        .margin({ bottom: this.themeState.palette.sp3 })

      // 导航项
      Column({ space: 6 }) {
        ForEach(AppConstants.navItems, (item: NavItem) => {
          this.navItem(item)
        }, (item: NavItem) => item.key)
      }
      .width('100%')
      .padding({ left: this.themeState.palette.sp2, right: this.themeState.palette.sp2 })

      Blank()

      // 底部版本信息
      Text('v' + AppConstants.appVersion)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .padding({ bottom: this.themeState.palette.sp4 })
    }
    .width(SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
    .border({ width: { right: 1 }, color: this.themeState.palette.divider })
  }
}

// 智子 - 底部导航（v10 华为原生拟物白 · 手机）
// 5 个一级 Tab 不变（数据源仍为 AppConstants.navItems），图标统一走 AppIcons 矢量（emoji 回退）。
// 玻璃材质仅此级（P0_BAR）保留。
import { AppConstants, NavItem } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct FixedBottomNav {
  @Param selectedKey: MainNavKey = MainNavKey.Index;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onSelect: (key: MainNavKey) => void = () => {};


  // 栏高 ≈ 56vp + 底部安全区（横屏收矮，仍保证 ≥44vp 触控）
  private barHeight(): number {
    return this.themeState.isLandscape ? 44 : 56 + this.themeState.navBarHeight;
  }

  private iconColor(key: MainNavKey): string {
    return key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textSecondary;
  }

  @Builder
  navItem(item: NavItem) {
    Column({ space: 2 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.navIcon(item.key))
          .fontSize(24)
          .fontColor([this.iconColor(item.key)])
          .accessibilityLevel('no')
      } else {
        Text(AppIcons.navEmoji(item.key))
          .fontSize(20)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.iconColor(item.key))
      }
      Text(item.label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.iconColor(item.key))
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .accessibilityText(item.label + (item.key === this.selectedKey ? '，已选中' : ''))
    .onClick(() => {
      this.onSelect(item.key);
    })
  }

  build() {
    Column() {
      // 顶部发丝分割线（区分底栏与内容）
      Divider()
        .strokeWidth(0.5)
        .color(this.themeState.palette.divider)

      Row() {
        ForEach(AppConstants.navItems, (item: NavItem) => {
          this.navItem(item)
        }, (item: NavItem) => item.key)
      }
      .width('100%')
      .height(this.barHeight())
      .padding({ left: this.themeState.palette.sp1, right: this.themeState.palette.sp1 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
  }
}

import { AppConstants, NavItem } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';

@ComponentV2
export struct FixedBottomNav {
  @Param selectedKey: MainNavKey = MainNavKey.Index;
          @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onSelect: (key: MainNavKey) => void = () => {};

  @Builder
  navItem(item: NavItem) {
    Column({ space: 2 }) {
      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(item.key === this.selectedKey ? this.themeState.palette.primary : Color.Transparent)
        .animation({ duration: 250, curve: Curve.EaseInOut })
      Text(item.icon)
        .fontSize(this.themeState.isLandscape ? this.themeState.palette.fsLg : this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
        .animation({ duration: 250, curve: Curve.EaseInOut })
      Text(item.label)
        .fontSize(this.themeState.isLandscape ? this.themeState.palette.fsXs - 1 : this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 250, curve: Curve.EaseInOut })
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(item.key === this.selectedKey ? this.themeState.palette.primaryDim : Color.Transparent)
    .borderRadius(6)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .animation({ duration: 250, curve: Curve.EaseInOut })
    .accessibilityText(item.label + (item.key === this.selectedKey ? '，已选中' : ''))
    .onClick(() => {
      this.onSelect(item.key);
    })
  }

  build() {
    Column() {
      Row() {
        ForEach(AppConstants.navItems, (item: NavItem) => {
          this.navItem(item)
        }, (item: NavItem) => item.key)
      }
      .width('100%')
      .height(this.themeState.isLandscape ? 44 : 56 + this.themeState.navBarHeight)
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .border({ width: { top: 1 }, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
    }
    .width('100%')
  }
}

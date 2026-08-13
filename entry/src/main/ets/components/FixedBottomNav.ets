import { AppConstants, NavItem } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';

@Component
export struct FixedBottomNav {
  @Prop selectedKey: MainNavKey;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isLandscape') isLandscape: boolean = false;
  onSelect: (key: MainNavKey) => void = () => {};

  @Builder
  navItem(item: NavItem) {
    Column({ space: 2 }) {
      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(item.key === this.selectedKey ? this.palette.primary : Color.Transparent)
        .animation({ duration: 250, curve: Curve.EaseInOut })
      Text(item.icon)
        .fontSize(this.isLandscape ? this.palette.fsLg : this.palette.fsXl)
        .fontFamily(this.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textTertiary)
        .animation({ duration: 250, curve: Curve.EaseInOut })
      Text(item.label)
        .fontSize(this.isLandscape ? this.palette.fsXs - 1 : this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textTertiary)
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 250, curve: Curve.EaseInOut })
    }
    .layoutWeight(1)
    .height(this.isLandscape ? 44 : 56)
    .backgroundColor(item.key === this.selectedKey ? this.palette.primaryDim : Color.Transparent)
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
      .height(this.isLandscape ? 44 : 56)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
      .border({ width: { top: 1 }, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
      Row()
        .width('100%')
        .height(Math.max(0, this.navBarHeight))
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
    }
    .width('100%')
  }
}

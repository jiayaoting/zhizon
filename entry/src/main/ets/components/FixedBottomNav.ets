import { AppConstants, NavItem } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct FixedBottomNav {
  @Prop selectedKey: MainNavKey;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  onSelect: (key: MainNavKey) => void = () => {};

  @Builder
  navItem(item: NavItem) {
    Column({ space: 2 }) {
      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(item.key === this.selectedKey ? this.palette.primary : Color.Transparent)
      Text(item.icon)
        .fontSize(20)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textTertiary)
      Text(item.label)
        .fontSize(10)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textTertiary)
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(56)
    .backgroundColor(item.key === this.selectedKey ? this.palette.primaryDim : Color.Transparent)
    .borderRadius(6)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
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
      .height(56)
      .backgroundColor(this.palette.bgSurface)
      .border({ width: { top: 1 }, color: this.palette.borderSubtle })
      Row()
        .width('100%')
        .height(Math.max(0, this.navBarHeight))
        .backgroundColor(this.palette.bgSurface)
    }
    .width('100%')
  }
}

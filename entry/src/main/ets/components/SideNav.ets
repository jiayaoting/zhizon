// 智子 - 大屏侧边导航（2in1 / 平板横屏 / isLg 时替代底部导航）
import { AppConstants, NavItem } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';

@Component
export struct SideNav {
  @Prop selectedKey: MainNavKey;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  onSelect: (key: MainNavKey) => void = () => {};

  @Builder
  navItem(item: NavItem) {
    Row({ space: 12 }) {
      Text(item.icon)
        .fontSize(this.palette.fsXl)
        .fontFamily(this.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textTertiary)
      Text(item.label)
        .fontSize(this.palette.fsBase)
        .fontFamily(this.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.palette.primary : this.palette.textSecondary)
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (item.key === this.selectedKey) {
        Text('●')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.primary)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .backgroundColor(item.key === this.selectedKey ? this.palette.primaryDim : Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .animation({ duration: 250, curve: Curve.EaseInOut })
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
            .fontSize(this.palette.fsXl)
          Text(AppConstants.appName)
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(VerticalAlign.Center)
        Text('休闲游戏 · AI 对话 · 个性化外观')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 16, bottom: 20 })

      // 导航项
      Column({ space: 6 }) {
        ForEach(AppConstants.navItems, (item: NavItem) => {
          this.navItem(item)
        }, (item: NavItem) => item.key)
      }
      .width('100%')
      .padding({ left: 10, right: 10 })

      Blank()

      // 底部版本信息
      Text('v' + AppConstants.appVersion)
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .padding({ bottom: 16 })
    }
    .width(220)
    .height('100%')
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
    .border({ width: { right: 1 }, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
  }
}
// 智子 - 通用组件：左侧导航栏（沉浸光感版）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { AppConstants, NavItem } from '../common/Constants';

@Component
export struct NavSidebar {
  @Prop activeKey: string;
  @Prop compact: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  onSelect: (key: string) => void = () => {};

  @Builder navItem(item: NavItem, isActive: boolean) {
    if (this.compact) {
      Column({ space: 4 }) {
        Text(item.icon)
          .fontSize(20)
          .fontColor(isActive ? this.palette.primary : this.palette.textSecondary)
        if (isActive) {
          Column()
            .width(16)
            .height(3)
            .borderRadius(1.5)
            .backgroundColor(this.palette.primary)
        }
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .borderRadius(6)
      .backgroundColor(isActive ? this.palette.primaryDim : Color.Transparent)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => this.onSelect(item.key))
    } else {
      Row({ space: 10 }) {
        Text(item.icon)
          .fontSize(18)
        Text(item.label)
          .fontSize(13)
          .fontColor(isActive ? this.palette.primary : this.palette.textSecondary)
          .fontWeight(isActive ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
        if (isActive) {
          Divider()
            .vertical(true)
            .height(16)
            .strokeWidth(2)
            .color(this.palette.primary)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(6)
      .backgroundColor(isActive ? this.palette.primaryDim : Color.Transparent)
      .onClick(() => this.onSelect(item.key))
    }
  }

  build() {
    Column() {
      // Logo
      Row({ space: 8 }) {
        Stack() {
          Text('智')
            .fontSize(18)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .linearGradient({
          angle: 135,
          colors: [[this.palette.primary, 0], [this.palette.primaryHover, 1]]
        })
        if (!this.compact) {
          Text('智子')
            .fontSize(16)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
        }
      }
      .width('100%')
      .padding({ left: this.compact ? 0 : 16, right: this.compact ? 0 : 16, top: this.statusBarHeight + 20, bottom: 20 })
      .justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)

      Divider().color(this.palette.borderSubtle)

      // 导航项
      Scroll() {
        Column({ space: 2 }) {
          ForEach(AppConstants.navItems, (item: NavItem) => {
            this.navItem(item, item.key === this.activeKey)
          })
        }
        .padding({ left: this.compact ? 6 : 8, right: this.compact ? 6 : 8, top: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部用户信息
      Divider().color(this.palette.borderSubtle)
      Row({ space: 10 }) {
        Circle({ width: 30, height: 30 })
          .fill(this.palette.bgElevated)
        if (!this.compact) {
          Column() {
            Text('jiayaoting')
              .fontSize(12)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Medium)
            Text('个人版')
              .fontSize(10)
              .fontColor(this.palette.textTertiary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: this.compact ? 0 : 16, right: this.compact ? 0 : 16, top: 12, bottom: 16 })
      .justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgSurface)
    .border({ width: { right: 1 }, color: this.palette.borderSubtle })
  }
}

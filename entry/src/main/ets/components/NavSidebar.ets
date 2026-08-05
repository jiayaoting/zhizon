// 智子 - 通用组件：左侧导航栏

import { AppTheme } from '../common/Theme';
import { AppConstants, NavItem } from '../common/Constants';

@Component
export struct NavSidebar {
  @Prop activeKey: string;
  @Prop compact: boolean = false;
  onSelect: (key: string) => void = () => {};

  @Builder navItem(item: NavItem, isActive: boolean) {
    if (this.compact) {
      // 紧凑模式：仅图标
      Column({ space: 4 }) {
        Text(item.icon)
          .fontSize(20)
          .fontColor(isActive ? AppTheme.primary : AppTheme.textSecondary)
        if (isActive) {
          Column()
            .width(16)
            .height(3)
            .borderRadius(1.5)
            .backgroundColor(AppTheme.primary)
        }
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .borderRadius(6)
      .backgroundColor(isActive ? AppTheme.primaryDim : Color.Transparent)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => this.onSelect(item.key))
    } else {
      Row({ space: 10 }) {
        Text(item.icon)
          .fontSize(18)
        Text(item.label)
          .fontSize(13)
          .fontColor(isActive ? AppTheme.primary : AppTheme.textSecondary)
          .fontWeight(isActive ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
        if (isActive) {
          Divider()
            .vertical(true)
            .height(16)
            .strokeWidth(2)
            .color(AppTheme.primary)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(6)
      .backgroundColor(isActive ? AppTheme.primaryDim : Color.Transparent)
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
            .fontColor(AppTheme.bgBase)
            .fontWeight(FontWeight.Bold)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .linearGradient({
          angle: 135,
          colors: [[AppTheme.primary, 0], ['#00B88A', 1]]
        })
        if (!this.compact) {
          Text('智子')
            .fontSize(16)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Bold)
        }
      }
      .width('100%')
      .padding({ left: this.compact ? 0 : 16, right: this.compact ? 0 : 16, top: 20, bottom: 20 })
      .justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)

      Divider().color(AppTheme.borderSubtle)

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
      Divider().color(AppTheme.borderSubtle)
      Row({ space: 10 }) {
        Circle({ width: 30, height: 30 })
          .fill(AppTheme.bgElevated)
        if (!this.compact) {
          Column() {
            Text('jiayaoting')
              .fontSize(12)
              .fontColor(AppTheme.textPrimary)
              .fontWeight(FontWeight.Medium)
            Text('个人版')
              .fontSize(10)
              .fontColor(AppTheme.textTertiary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: this.compact ? 0 : 16, right: this.compact ? 0 : 16, top: 12, bottom: 16 })
      .justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)
    }
    .height('100%')
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: { right: 1 }, color: AppTheme.borderSubtle })
  }
}

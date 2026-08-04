// 智子 - 通用组件：左侧导航栏

import { AppTheme } from '../common/Theme';
import { AppConstants } from '../common/Constants';

@Component
export struct NavSidebar {
  @Prop activeKey: string;
  onSelect: (key: string) => void = () => {};

  @Builder navItem(item: { key: string; label: string; icon: Resource }, isActive: boolean) {
    Row({ space: 10 }) {
      SymbolGlyph(item.icon)
        .fontSize(18)
        .fontColor(isActive ? AppTheme.primary : AppTheme.textSecondary)
        .fontWeight(isActive ? FontWeight.Bold : FontWeight.Regular)
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
        Text('智子')
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })

      Divider().color(AppTheme.borderSubtle)

      // 导航项
      Scroll() {
        Column({ space: 2 }) {
          ForEach(AppConstants.navItems, (item) => {
            this.navItem(item, item.key === this.activeKey)
          })
        }
        .padding({ left: 8, right: 8, top: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部用户信息
      Divider().color(AppTheme.borderSubtle)
      Row({ space: 10 }) {
        Circle({ width: 30, height: 30 })
          .fill(AppTheme.bgElevated)
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
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    }
    .width(220)
    .height('100%')
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: { right: 1 }, color: AppTheme.borderSubtle })
  }
}

// 智子 - 通用组件：状态徽章（沉浸光感版）
import { ThemePalette, defaultLightPalette, statusInfo } from '../common/Theme';

@Component
export struct StatusBadge {
  @Prop status: string;
  @Prop badgeSize: string = 'normal';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  build() {
    Row({ space: 4 }) {
      Circle({ width: this.badgeSize === 'small' ? 5 : 6, height: this.badgeSize === 'small' ? 5 : 6 })
        .fill(statusInfo(this.status, this.palette).dotColor)
      Text(statusInfo(this.status, this.palette).text)
        .fontSize(this.badgeSize === 'small' ? 10 : 11)
        .fontColor(statusInfo(this.status, this.palette).color)
        .fontWeight(FontWeight.Medium)
    }
    .padding({
      left: this.badgeSize === 'small' ? 6 : 8,
      right: this.badgeSize === 'small' ? 6 : 8,
      top: 2,
      bottom: 2
    })
    .borderRadius(10)
    .backgroundColor(this.status === 'online' || this.status === 'running' || this.status === 'success' || this.status === 'active'
      ? 'rgba(16, 185, 129, 0.12)'
      : this.status === 'warning' || this.status === 'paused'
        ? 'rgba(245, 158, 11, 0.12)'
        : 'rgba(239, 68, 68, 0.12)')
  }
}

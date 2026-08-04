// 智子 - 通用组件：状态徽章

import { AppTheme, statusInfo } from '../common/Theme';

@Component
export struct StatusBadge {
  @Prop status: string;
  @Prop size: string = 'normal'; // normal | small

  build() {
    Row({ space: 4 }) {
      Circle({ width: this.size === 'small' ? 5 : 6, height: this.size === 'small' ? 5 : 6 })
        .fill(statusInfo(this.status).dotColor)
      Text(statusInfo(this.status).text)
        .fontSize(this.size === 'small' ? 10 : 11)
        .fontColor(statusInfo(this.status).color)
        .fontWeight(FontWeight.Medium)
    }
    .padding({
      left: this.size === 'small' ? 6 : 8,
      right: this.size === 'small' ? 6 : 8,
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

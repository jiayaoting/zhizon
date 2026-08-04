// 智子 - 通用组件：空状态占位
import { AppTheme } from '../common/Theme';

@Component
export struct EmptyState {
  @Prop icon: string = '📭';
  @Prop title: string = '暂无数据';
  @Prop desc: string = '';

  build() {
    Column({ space: 8 }) {
      Text(this.icon)
        .fontSize(48)
      Text(this.title)
        .fontSize(14)
        .fontColor(AppTheme.textSecondary)
        .fontWeight(FontWeight.Medium)
      if (this.desc) {
        Text(this.desc)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
      }
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

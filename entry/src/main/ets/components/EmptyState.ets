// 智子 - 通用组件：空状态占位（沉浸光感版）
import { ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct EmptyState {
  @Prop icon: string = '📭';
  @Prop title: string = '暂无数据';
  @Prop desc: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  build() {
    Column({ space: 8 }) {
      Text(this.icon)
        .fontSize(48)
      Text(this.title)
        .fontSize(14)
        .fontColor(this.palette.textSecondary)
        .fontWeight(FontWeight.Medium)
      if (this.desc) {
        Text(this.desc)
          .fontSize(11)
          .fontColor(this.palette.textTertiary)
      }
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

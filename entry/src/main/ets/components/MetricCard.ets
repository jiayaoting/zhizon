// 智子 - 通用组件：指标卡

import { AppTheme } from '../common/Theme';

@Component
export struct MetricCard {
  @Prop title: string;
  @Prop value: string;
  @Prop unit: string = '';
  @Prop sub: string = '';
  @Prop color: string = AppTheme.primary;
  @Prop badgeText?: string;

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.title)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .layoutWeight(1)
        if (this.badgeText) {
          Text(this.badgeText)
            .fontSize(10)
            .fontColor(AppTheme.textSecondary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .backgroundColor(AppTheme.bgSurface2)
        }
      }
      .width('100%')

      Row({ space: 2 }) {
        Text(this.value)
          .fontSize(22)
          .fontColor(this.color)
          .fontWeight(FontWeight.Bold)
          .fontFamily(AppTheme.fontMono)
        if (this.unit) {
          Text(this.unit)
            .fontSize(11)
            .fontColor(AppTheme.textTertiary)
        }
      }

      if (this.sub) {
        Text(this.sub)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
      }
    }
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }
}

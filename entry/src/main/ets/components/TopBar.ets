// 智子 - 通用组件：顶栏

import { AppTheme } from '../common/Theme';

@Component
export struct TopBar {
  @Prop title: string;
  @Prop subtitle: string = '';
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder emptyActions() {}

  build() {
    Row({ space: 12 }) {
      Column() {
        Text(this.title)
          .fontSize(20)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(AppTheme.textTertiary)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.actions()
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
  }
}

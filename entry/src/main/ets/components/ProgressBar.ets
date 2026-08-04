// 智子 - 通用组件：进度条

import { AppTheme, progressColor } from '../common/Theme';

@Component
export struct ProgressBar {
  @Prop value: number;       // 0~100
  @Prop showLabel: boolean = false;
  @Prop barHeight: number = 6;
  @Prop customColor?: string;

  build() {
    Column({ space: 4 }) {
      if (this.showLabel) {
        Row() {
          Blank()
          Text(`${Math.round(this.value)}%`)
            .fontSize(10)
            .fontColor(this.customColor || progressColor(this.value))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
      }
      Stack({ alignContent: Alignment.Start }) {
        // 背景
        Column()
          .width('100%')
          .height(this.barHeight)
          .borderRadius(this.barHeight / 2)
          .backgroundColor(AppTheme.bgSurface2)
        // 前景
        Column()
          .width(`${Math.max(0, Math.min(100, this.value))}%`)
          .height(this.barHeight)
          .borderRadius(this.barHeight / 2)
          .backgroundColor(this.customColor || progressColor(this.value))
      }
      .width('100%')
      .height(this.barHeight)
    }
    .width('100%')
  }
}

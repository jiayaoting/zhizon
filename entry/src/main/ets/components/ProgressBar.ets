// 智子 - 通用组件：进度条（沉浸光感版）
import { ThemePalette, defaultLightPalette, progressColor } from '../common/Theme';

@Component
export struct ProgressBar {
  @Prop value: number;
  @Prop showLabel: boolean = false;
  @Prop barHeight: number = 6;
  @Prop customColor: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  build() {
    Column({ space: 4 }) {
      if (this.showLabel) {
        Row() {
          Blank()
          Text(`${Math.round(this.value)}%`)
            .fontSize(10)
            .fontColor(this.customColor || progressColor(this.value, this.palette))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
      }
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(this.barHeight)
          .borderRadius(this.barHeight / 2)
          .backgroundColor(this.palette.bgSurface2)
        Column()
          .width(`${Math.max(0, Math.min(100, this.value))}%`)
          .height(this.barHeight)
          .borderRadius(this.barHeight / 2)
          .backgroundColor(this.customColor || progressColor(this.value, this.palette))
      }
      .width('100%')
      .height(this.barHeight)
    }
    .width('100%')
  }
}

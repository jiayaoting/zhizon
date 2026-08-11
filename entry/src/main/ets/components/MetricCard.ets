// 智子 - 通用组件：指标卡（沉浸光感版）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';

@Component
export struct MetricCard {
  @Prop title: string;
  @Prop value: string;
  @Prop unit: string = '';
  @Prop sub: string = '';
  @Prop color: string = '#00D9A3';
  @Prop badgeText: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.title)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .layoutWeight(1)
        if (this.badgeText) {
          Text(this.badgeText)
            .fontSize(10)
            .fontColor(this.palette.textSecondary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
        }
      }
      .width('100%')

      Row({ space: 2 }) {
        Text(this.value)
          .fontSize(22)
          .fontColor(this.color)
          .fontWeight(FontWeight.Bold)
          .fontFamily(this.palette.fontMono)
        if (this.unit) {
          Text(this.unit)
            .fontSize(11)
            .fontColor(this.palette.textTertiary)
        }
      }

      if (this.sub) {
        Text(this.sub)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
      }
    }
    .padding(16)
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
    .alignItems(HorizontalAlign.Start)
  }
}

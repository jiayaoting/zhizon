// 智子 - 通用组件：顶栏（沉浸光感版）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { router } from '@kit.ArkUI';

@Component
export struct TopBar {
  @Prop title: string;
  @Prop subtitle: string = '';
  @Prop showBack: boolean = false;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder emptyActions() {}

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor(this.palette.textSecondary)
            .fontWeight(FontWeight.Bold)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())
      }

      Column() {
        Text(this.title)
          .fontSize(20)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(this.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.actions()
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: this.statusBarHeight + 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
    .border({ width: { bottom: 1 }, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
  }
}

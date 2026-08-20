// 智子 - 通用分组卡片（设置 / 我的等页面共用）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';

@Component
export struct SettingGroupCard {
  @Prop title: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(this.palette.fsMd)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontSans)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
    .alignItems(HorizontalAlign.Start)
  }
}

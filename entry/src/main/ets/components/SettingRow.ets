// 智子 - 统一设置行组件（图标容器 + 48 行高 + 按压反馈 + 无障碍）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle } from './GlassEffect';

@Component
export struct SettingRow {
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop desc: string = '';
  @Prop showArrow: boolean = true;
  @Prop danger: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  rowClick: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        if (this.icon.length > 0) {
          Text(this.icon)
            .fontSize(16)
            .fontFamily(this.palette.fontSans)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.palette.primaryDim)
        }
        Text(this.title)
          .fontSize(this.palette.fsBase)
          .fontColor(this.danger ? this.palette.danger : this.palette.textPrimary)
          .fontFamily(this.palette.fontSans)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontSans)
            .margin({ right: 6 })
            .maxLines(1)
        }
        if (this.showArrow) {
          Text('›')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .borderRadius(8)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
      .onClick(() => { this.rowClick(); })
      .stateStyles({
        pressed: {
          .backgroundColor(this.palette.bgHover)
        }
      })
      .accessibilityText(this.title + (this.value.length > 0 ? '，' + this.value : '') + (this.danger ? '，危险操作' : ''))
      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .width('100%')
          .padding({ left: 12 })
      }
    }
    .width('100%')
  }
}

@Component
export struct SettingSwitchRow {
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop isOn: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  onSwitchChange: (v: boolean) => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row({ space: 12 }) {
        if (this.icon.length > 0) {
          Text(this.icon)
            .fontSize(16)
            .fontFamily(this.palette.fontSans)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.palette.primaryDim)
        }
        Text(this.title)
          .fontSize(this.palette.fsBase)
          .fontColor(this.palette.textPrimary)
          .fontFamily(this.palette.fontSans)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .selectedColor(this.palette.primary)
          .onChange((v: boolean) => { this.onSwitchChange(v); })
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .borderRadius(8)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
      .stateStyles({
        pressed: {
          .backgroundColor(this.palette.bgHover)
        }
      })
      .accessibilityText(this.title + (this.isOn ? '，已开启' : '，已关闭'))
      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .width('100%')
          .padding({ left: 12 })
      }
    }
    .width('100%')
  }
}

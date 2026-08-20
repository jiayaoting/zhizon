// 智子 - 主密码弹窗（设置/修改/验证）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';

@Component
export struct PasswordSheet {
  @Prop mode: string = 'set';
  @Prop busy: boolean = false;
  @Prop error: string = '';
  @Prop input: string = '';
  @Prop confirm: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  onCancel: () => void = () => {};
  onInputChange: (v: string) => void = () => {};
  onConfirmChange: (v: string) => void = () => {};
  onConfirmTap: () => void = () => {};

  build() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.onCancel(); })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 12 }) {
        Row() {
          Blank()
          Text('✕')
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .padding(8)
            .onClick(() => { this.onCancel(); })
        }
        .width('100%')
        .padding({ right: 4, top: 4 })

        Text(this.mode === 'set' ? '设置主密码' :
          (this.mode === 'change' ? '修改主密码' : '验证主密码'))
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text(this.mode === 'verify' ? '请输入当前主密码以继续操作' :
          '设置后可用于解锁应用，至少 4 位')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .width('100%')

        TextInput({ text: this.input, placeholder: '请输入密码' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface)
          .borderRadius(8)
          .border({ width: 1, color: this.palette.borderSubtle })
          .height(44)
          .type(InputType.Password)
          .width('100%')
          .onChange((value: string) => { this.onInputChange(value); })

        if (this.mode === 'set' || this.mode === 'change') {
          TextInput({ text: this.confirm, placeholder: '请再次输入密码' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(44)
            .type(InputType.Password)
            .width('100%')
            .onChange((value: string) => { this.onConfirmChange(value); })
        }

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.danger)
            .width('100%')
        }

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.palette.bgSurface2)
            .fontColor(this.palette.textPrimary)
            .borderRadius(8)
            .onClick(() => { this.onCancel(); })
          Button(this.busy ? '处理中…' : '确认')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.palette.primary)
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .enabled(!this.busy)
            .onClick(() => { this.onConfirmTap(); })
        }
        .width('100%')

        Text('主密码仅以加盐哈希保存在本机，无法找回，请妥善保管。')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.25)', offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }
}

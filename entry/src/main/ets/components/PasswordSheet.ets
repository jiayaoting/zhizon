// 智子 - 主密码弹窗（设置/修改/验证）
// V2（P4）：入参统一 @Param，全局 UI 状态走 themeState；回调统一 @Event（参数名与契约保持不变）
// v10 polish：遮罩/输入框/按钮圆角改语义 token，主色上的文字改 primaryOnColor
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';

@ComponentV2
export struct PasswordSheet {
  @Param mode: string = 'set';
  @Param busy: boolean = false;
  @Param error: string = '';
  @Param input: string = '';
  @Param confirm: string = '';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onCancel: () => void = () => {};
  @Event onInputChange: (v: string) => void = () => {};
  @Event onConfirmChange: (v: string) => void = () => {};
  @Event onConfirmTap: () => void = () => {};

  build() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.themeState.palette.maskOverlay)
        .onClick(() => { this.onCancel(); })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 12 }) {
        Row() {
          Blank()
          Text('✕')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .padding(8)
            .accessibilityText('关闭')
            .onClick(() => { this.onCancel(); })
        }
        .width('100%')
        .padding({ right: 4, top: 4 })

        Text(this.mode === 'set' ? '设置主密码' :
          (this.mode === 'change' ? '修改主密码' : '验证主密码'))
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text(this.mode === 'verify' ? '请输入当前主密码以继续操作' :
          '设置后可用于解锁应用，至少 4 位')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')

        TextInput({ text: this.input, placeholder: '请输入密码' })
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .placeholderColor(this.themeState.palette.textTertiary)
          .backgroundColor(this.themeState.palette.bgSurface)
          .borderRadius(this.themeState.palette.radiusSm)
          .border({ width: 1, color: this.themeState.palette.borderSubtle })
          .height(this.themeState.palette.touchTarget)
          .type(InputType.Password)
          .width('100%')
          .onChange((value: string) => { this.onInputChange(value); })

        if (this.mode === 'set' || this.mode === 'change') {
          TextInput({ text: this.confirm, placeholder: '请再次输入密码' })
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .placeholderColor(this.themeState.palette.textTertiary)
            .backgroundColor(this.themeState.palette.bgSurface)
            .borderRadius(this.themeState.palette.radiusSm)
            .border({ width: 1, color: this.themeState.palette.borderSubtle })
            .height(this.themeState.palette.touchTarget)
            .type(InputType.Password)
            .width('100%')
            .onChange((value: string) => { this.onConfirmChange(value); })
        }

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
            .width('100%')
        }

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .fontColor(this.themeState.palette.textPrimary)
            .borderRadius(this.themeState.palette.radiusSm)
            .onClick(() => { this.onCancel(); })
          Button(this.busy ? '处理中…' : '确认')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.themeState.palette.primary)
            .fontColor(this.themeState.palette.primaryOnColor)
            .borderRadius(this.themeState.palette.radiusSm)
            .enabled(!this.busy)
            .onClick(() => { this.onConfirmTap(); })
        }
        .width('100%')

        Text('主密码仅以加盐哈希保存在本机，无法找回，请妥善保管。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.themeState.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
      .shadow({ radius: 24, color: this.themeState.palette.maskOverlay, offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }
}

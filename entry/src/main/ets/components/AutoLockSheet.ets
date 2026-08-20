// 智子 - 自动锁定选择弹窗
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';
import { autoLockLabel, AUTO_LOCK_OPTIONS } from '../service/SecurityService';

@Component
export struct AutoLockSheet {
  @Prop currentLabel: string = '关闭';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  onCancel: () => void = () => {};
  onOptionSelect: (value: number) => void = () => {};

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
      Column({ space: 4 }) {
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

        Text('自动锁定')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

        ForEach(AUTO_LOCK_OPTIONS, (value: number) => {
          Row() {
            Text(autoLockLabel(value))
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .layoutWeight(1)
            if (this.currentLabel === autoLockLabel(value)) {
              Text('✓')
                .fontSize(this.palette.fsLg)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor(this.currentLabel === autoLockLabel(value) ? this.palette.primaryDim : this.palette.bgSurface)
          .border({ width: this.currentLabel === autoLockLabel(value) ? 1 : 0,
            color: this.currentLabel === autoLockLabel(value) ? this.palette.primary : Color.Transparent })
          .onClick(() => { this.onOptionSelect(value); })
        }, (value: number) => value.toString())

        Text('开启后，应用切到后台超过设定时间将锁定，需主密码或生物识别解锁。')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
          .padding({ left: 4, right: 4, top: 8 })
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

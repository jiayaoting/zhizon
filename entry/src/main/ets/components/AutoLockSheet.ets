// 智子 - 自动锁定选择弹窗
// V2（P4）：入参统一 @Param，全局 UI 状态走 themeState；回调统一 @Event（参数名与契约保持不变）
// v10 polish：遮罩/圆角/选中态改为语义 token（maskOverlay / radiusSm / radiusXl / primaryBgStrong）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';
import { autoLockLabel, AUTO_LOCK_OPTIONS } from '../service/platform/SecurityService';

@ComponentV2
export struct AutoLockSheet {
  @Param currentLabel: string = '关闭';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onCancel: () => void = () => {};
  @Event onOptionSelect: (value: number) => void = () => {};

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
      Column({ space: 4 }) {
        Row() {
          Blank()
          Text('✕')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .padding(8)
            .onClick(() => { this.onCancel(); })
        }
        .width('100%')
        .padding({ right: 4, top: 4 })

        Text('自动锁定')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

        ForEach(AUTO_LOCK_OPTIONS, (value: number) => {
          Row() {
            Text(autoLockLabel(value))
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .layoutWeight(1)
            if (this.currentLabel === autoLockLabel(value)) {
              Text('✓')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .padding(12)
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.currentLabel === autoLockLabel(value) ?
            this.themeState.palette.primaryBgStrong : this.themeState.palette.bgSurface)
          .border({ width: this.currentLabel === autoLockLabel(value) ? 1 : 0,
            color: this.currentLabel === autoLockLabel(value) ? this.themeState.palette.primary : Color.Transparent })
          .onClick(() => { this.onOptionSelect(value); })
        }, (value: number) => value.toString())

        Text('开启后，应用切到后台超过设定时间将锁定，需主密码或生物识别解锁。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
          .padding({ left: 4, right: 4, top: 8 })
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

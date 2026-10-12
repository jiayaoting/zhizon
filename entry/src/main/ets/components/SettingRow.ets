// 智子 - 统一设置行组件（v10：56vp 行高 + 发丝分割线 + 华为式图标容器 + 无障碍）
// 契约向后兼容：icon(emoji 内容图标) / title / value / desc / showArrow / danger / rowClick
// 新增可选 showDivider（默认 true，行间发丝分割线，符合华为列表样式）
// v10 扩展：useSymbol + symbol（矢量图标优先）、isSwitch + switchValue + onSwitchChange（开关行）
// V2（P4）：入参统一 @Param，回调统一 @Event（rowClick 名称保持不变，调用方无需改动）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct SettingRow {
  @Param icon: string = '';
  @Param title: string = '';
  @Param value: string = '';
  @Param desc: string = '';
  @Param showArrow: boolean = true;
  @Param danger: boolean = false;
  @Param showDivider: boolean = true;
  // 矢量图标（useSymbol=true 时优先于 emoji）
  @Param useSymbol: boolean = false;
  @Param symbol: Resource = $r('sys.symbol.gearshape');
  // 开关行（isSwitch=true 时右侧渲染 Toggle，替代 value + 箭头）
  @Param isSwitch: boolean = false;
  @Param switchValue: boolean = false;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event rowClick: () => void = () => {};
  @Event onSwitchChange: (value: boolean) => void = () => {};

  build() {
    Column({ space: this.themeState.palette.sp1 }) {
      Row({ space: this.themeState.palette.sp3 }) {
        if (this.useSymbol) {
          if (USE_SYMBOL_ICONS) {
            Row() {
              SymbolGlyph(this.symbol)
                .fontSize(22)
                .fontColor([this.themeState.palette.textSecondary])
                .accessibilityLevel('no')
            }
            .width(24)
            .height(24)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          } else if (this.icon.length > 0) {
            Text(this.icon)
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.themeState.palette.bgSurface2)
          }
        } else if (this.icon.length > 0) {
          Text(this.icon)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(this.themeState.palette.radiusSm)
            .backgroundColor(this.themeState.palette.bgSurface2)
        }
        Text(this.title)
          .fontSize(this.themeState.palette.fsMd)
          .fontColor(this.danger ? this.themeState.palette.danger : this.themeState.palette.textPrimary)
          .fontFamily(this.themeState.palette.fontSans)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.isSwitch) {
          Toggle({ type: ToggleType.Switch, isOn: this.switchValue })
            .selectedColor(this.themeState.palette.primary)
            .onChange((v: boolean) => { this.onSwitchChange(v); })
        } else {
          if (this.value.length > 0) {
            Text(this.value)
              .fontSize(this.themeState.palette.fsSm)
              .fontColor(this.themeState.palette.textTertiary)
              .fontFamily(this.themeState.palette.fontSans)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 160 })
          }
          if (this.showArrow) {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.forward)
                .fontSize(16)
                .fontColor([this.themeState.palette.textTertiary])
                .accessibilityLevel('no')
            } else {
              Text(AppIcons.forwardEmoji)
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
          }
        }
      }
      .width('100%')
      .height(this.themeState.palette.rowHeight)
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.rowClick(); })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .accessibilityText(this.title + (this.value.length > 0 ? '，' + this.value : '') +
        (this.isSwitch ? (this.switchValue ? '，已开启' : '，已关闭') : '') + (this.danger ? '，危险操作' : ''))

      if (this.desc.length > 0) {
        Text(this.desc)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .padding({ left: this.useSymbol || this.icon.length > 0 ? 44 : 0 })
      }

      if (this.showDivider) {
        Divider()
          .color(this.themeState.palette.divider)
          .strokeWidth(0.5)
          .margin({ left: this.icon.length > 0 ? 44 : 0 })
      }
    }
    .width('100%')
  }
}

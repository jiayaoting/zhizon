// 智子 - 通用组件：顶栏（沉浸光感版）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { AppNavigator } from '../common/AppNavigator';

@ComponentV2
export struct TopBar {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param showBack: boolean = false;
  // 自定义返回回调：嵌入子页（非路由压栈）时，由宿主提供返回逻辑；缺省时回退到 AppNavigator.pop()
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onBackTap: () => void = () => { AppNavigator.pop(); };
          @BuilderParam actions: () => void = this.emptyActions;

  @Builder emptyActions() {}

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
            .fontWeight(FontWeight.Bold)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => { this.onBackTap(); })
      }

      Column() {
        Text(this.title)
          .fontSize(this.themeState.palette.fsXl)
          .fontColor(this.themeState.palette.textPrimary)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(this.themeState.palette.fsXs)
            .fontColor(this.themeState.palette.textTertiary)
            .fontFamily(this.themeState.palette.fontSans)
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
    .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: this.themeState.statusBarHeight + 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
    .border({ width: { bottom: 1 }, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
  }
}

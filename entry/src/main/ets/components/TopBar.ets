// 智子 - 通用组件：顶栏（v10 华为原生拟物白）
// 大标题 fsXl Bold + 可选副标题 fsXs；左侧可选 菜单/返回 40×40 钮；右侧 @BuilderParam actions（尾随闭包语法保持不变）。
// 玻璃材质仅此级（P0_BAR）保留。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel, glassBlurStyle } from './GlassEffect';
import { AppNavigator } from '../common/AppNavigator';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct TopBar {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param showBack: boolean = false;
  // 自定义返回回调：嵌入子页（非路由压栈）时，由宿主提供返回逻辑；缺省时回退到 AppNavigator.pop()
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onBackTap: () => void = () => { AppNavigator.pop(); };
  // 左侧菜单按钮（会话列表等入口）：布尔开关 + 事件回调，不引入第二个 @BuilderParam（会破坏尾随闭包语法）
  @Param showLeading: boolean = false;
  @Event onLeadingTap: () => void = () => {};
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder emptyActions() {}

  // 左右安全边距：手机 16vp / 大屏 24vp
  private horizontalPadding(): string {
    return this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg;
  }

  build() {
    Column() {
      Row({ space: this.themeState.palette.sp2 }) {
        if (this.showLeading) {
          Row() {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.list)
                .fontSize(22)
                .fontColor([this.themeState.palette.textPrimary])
            } else {
              Text(AppIcons.listEmoji)
                .fontSize(18)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
            }
          }
          .width(40)
          .height(40)
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .accessibilityText('会话列表')
          .onClick(() => { this.onLeadingTap(); })
        }
        if (this.showBack) {
          Row() {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.back)
                .fontSize(24)
                .fontColor([this.themeState.palette.textPrimary])
            } else {
              Text(AppIcons.backEmoji)
                .fontSize(22)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width(40)
          .height(40)
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .accessibilityText('返回')
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
      // 标题区高度 ≈ titleBarHeight（64vp），左右按钮 40×40 落在 ≥44vp 行内
      .height(this.themeState.palette.titleBarHeight)
      .padding({ left: this.horizontalPadding(), right: this.horizontalPadding() })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // 全屏沉浸：状态栏安全区兜底（避免个别设备上报异常导致内容与状态栏重叠）
    .padding({ top: Math.max(this.themeState.statusBarHeight, 44) })
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
    .border({ width: { bottom: 0.5 }, color: this.themeState.palette.divider })
  }
}

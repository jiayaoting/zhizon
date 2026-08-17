// 智子 - 大屏侧边导航（2in1 / 平板横屏 / isLg 时替代底部导航）
import { AppConstants, NavItem, SIDEBAR_WIDTH } from '../common/Constants';
import { MainNavKey } from '../common/Navigation';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';

@ComponentV2
export struct SideNav {
  @Param selectedKey: MainNavKey = MainNavKey.Index;
        @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onSelect: (key: MainNavKey) => void = () => {};

  @Builder
  navItem(item: NavItem) {
    Row({ space: 12 }) {
      Text(item.icon)
        .fontSize(this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
      Text(item.label)
        .fontSize(this.themeState.palette.fsBase)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(item.key === this.selectedKey ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .fontWeight(item.key === this.selectedKey ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (item.key === this.selectedKey) {
        Text('●')
          .fontSize(this.themeState.palette.fsXs)
          .fontColor(this.themeState.palette.primary)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .borderRadius(10)
    .backgroundColor(item.key === this.selectedKey ? this.themeState.palette.primaryDim : Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .animation({ duration: 250, curve: Curve.EaseInOut })
    .accessibilityText(item.label + (item.key === this.selectedKey ? '，已选中' : ''))
    .onClick(() => {
      this.onSelect(item.key);
    })
  }

  build() {
    Column() {
      // 顶部品牌区
      Column({ space: 4 }) {
        Row({ space: 10 }) {
          Text('🧠')
            .fontSize(this.themeState.palette.fsXl)
          Text(AppConstants.appName)
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(VerticalAlign.Center)
        Text('休闲游戏 · AI 对话 · 个性化外观')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: this.themeState.statusBarHeight + 16, bottom: 20 })

      // 导航项
      Column({ space: 6 }) {
        ForEach(AppConstants.navItems, (item: NavItem) => {
          this.navItem(item)
        }, (item: NavItem) => item.key)
      }
      .width('100%')
      .padding({ left: 10, right: 10 })

      Blank()

      // 底部版本信息
      Text('v' + AppConstants.appVersion)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .padding({ bottom: 16 })
    }
    .width(SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
    .border({ width: { right: 1 }, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
  }
}

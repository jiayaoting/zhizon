// 智子 - 游戏设置（子页：游戏相关设置集中管理）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { SoundService } from '../service/platform/SoundService';

@ComponentV2
@Entry
export struct GameSettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local soundEnabled: boolean = true;

  aboutToAppear(): void {
    this.soundEnabled = SoundService.isEnabled();
  }

  private async onSoundToggle(v: boolean): Promise<void> {
    this.soundEnabled = v;
    await SoundService.setEnabled(v);
    promptAction.showToast({ message: v ? '游戏音效已开启' : '游戏音效已关闭' });
  }

  build() {
    Column() {
      TopBar({ title: '游戏设置', showBack: true })

      Scroll() {
        Row() {
          Column({ space: this.themeState.palette.sp3 }) {
            Row({ space: this.themeState.palette.sp3 }) {
              // 左侧矢量图标（音效），与游戏中心列表行一致
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(AppIcons.speaker)
                    .fontSize(20)
                    .fontColor([this.themeState.palette.primary])
                } else {
                  Text(AppIcons.speakerEmoji)
                    .fontSize(16)
                    .fontFamily(this.themeState.palette.fontSans)
                }
              }
              .width(32)
              .height(32)
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.themeState.palette.primaryBg)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)

              Text('游戏音效')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.soundEnabled })
                .selectedColor(this.themeState.palette.primary)
                .onChange((v: boolean) => { this.onSoundToggle(v); })
            }
            .width('100%')
            .height(this.themeState.palette.rowHeight)
            .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
            .backgroundColor(this.themeState.palette.bgSurface)
            .borderRadius(this.themeState.palette.radiusLg)
            .border({ width: 0.5, color: this.themeState.palette.divider })

            Text('开启后，消除/吃食物/胜利/失败等场景播放短音效（可随时关闭）。')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')
              .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })

            Column().height(this.themeState.palette.sp5)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({
            left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: this.themeState.palette.sp3
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

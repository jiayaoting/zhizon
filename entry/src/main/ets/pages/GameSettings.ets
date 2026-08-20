// 智子 - 游戏设置（子页：游戏相关设置集中管理）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { SoundService } from '../service/SoundService';

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
          Column({ space: 12 }) {
            Row() {
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
            .padding(14)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

            Text('开启后，消除/吃食物/胜利/失败等场景播放短音效（可随时关闭）。')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')
              .padding({ left: 4, right: 4 })

            Column().height(20)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
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

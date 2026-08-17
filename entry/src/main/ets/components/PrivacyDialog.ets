// 智子 - 隐私政策与用户协议同意弹窗
// 首次启动时展示，用户同意后方可进入应用
import { AppNavigator } from '../common/AppNavigator';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { DataRepository } from '../service/DataRepository';
import { LegalDocRouteParams } from '../common/Navigation';

const PRIVACY_CONSENT_KEY = 'privacy_consent_accepted';

@ComponentV2
export struct PrivacyDialog {
      @Local visible: boolean = false;
  @Local agreed: boolean = false;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onConsent: () => void = () => {};

  aboutToAppear(): void {
    this.checkConsent();
  }

  private async checkConsent(): Promise<void> {
    const accepted = await DataRepository.getSetting(PRIVACY_CONSENT_KEY, 'false');
    if (accepted === 'true') {
      this.onConsent();
    } else {
      this.visible = true;
    }
  }

  private async accept(): Promise<void> {
    if (!this.agreed) return;
    await DataRepository.setSetting(PRIVACY_CONSENT_KEY, 'true');
    this.visible = false;
    this.onConsent();
  }

  private openLegalDoc(type: string): void {
    AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams(type));
  }

  build() {
    if (this.visible) {
      Stack() {
        // 半透明遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000066')
          .onClick(() => {}) // 阻止点击穿透

        // 弹窗卡片
        Column() {
        // 标题区域
        Column({ space: 8 }) {
          Text('欢迎使用智子')
            .fontSize(this.themeState.palette.fsXl)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.themeState.palette.fontSans)
          Text('在使用前，请阅读并同意以下条款')
            .fontSize(this.themeState.palette.fsSm)
            .fontColor(this.themeState.palette.textSecondary)
            .fontFamily(this.themeState.palette.fontSans)
        }
        .width('100%')
        .padding({ bottom: 16 })
        .alignItems(HorizontalAlign.Center)

        // 协议内容摘要
        Column({ space: 10 }) {
          Text('本应用为开源软件，由 AI 辅助开发，遵循 MIT 许可协议发布。')
            .fontSize(this.themeState.palette.fsSm)
            .fontColor(this.themeState.palette.textPrimary)
            .fontFamily(this.themeState.palette.fontSans)
            .lineHeight(20)

          Text('您的游戏数据和设置偏好仅存储在设备本地，不会上传至任何服务器。')
            .fontSize(this.themeState.palette.fsSm)
            .fontColor(this.themeState.palette.textPrimary)
            .fontFamily(this.themeState.palette.fontSans)
            .lineHeight(20)

          Text('本应用仅在您主动授权时访问媒体文件权限（设置自定义背景图）和振动权限（游戏触觉反馈）。')
            .fontSize(this.themeState.palette.fsSm)
            .fontColor(this.themeState.palette.textPrimary)
            .fontFamily(this.themeState.palette.fontSans)
            .lineHeight(20)
        }
        .width('100%')
        .padding(14)
        .borderRadius(8)
        .backgroundColor(this.themeState.palette.bgSurface)

        // 查看完整协议
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          Text('查看完整')
            .fontSize(this.themeState.palette.fsXs)
            .fontColor(this.themeState.palette.textTertiary)
            .fontFamily(this.themeState.palette.fontSans)
            .margin({ right: 12 })
          Text('用户协议')
            .fontSize(this.themeState.palette.fsXs)
            .fontColor(this.themeState.palette.primary)
            .fontFamily(this.themeState.palette.fontSans)
            .margin({ right: 12 })
            .onClick(() => { this.openLegalDoc('agreement'); })
          Text('隐私政策')
            .fontSize(this.themeState.palette.fsXs)
            .fontColor(this.themeState.palette.primary)
            .fontFamily(this.themeState.palette.fontSans)
            .margin({ right: 12 })
            .onClick(() => { this.openLegalDoc('privacy'); })
          Text('开源许可')
            .fontSize(this.themeState.palette.fsXs)
            .fontColor(this.themeState.palette.primary)
            .fontFamily(this.themeState.palette.fontSans)
            .onClick(() => { this.openLegalDoc('license'); })
        }
        .width('100%')
        .padding({ top: 12, bottom: 8 })

        // 同意复选框
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Checkbox, isOn: $$this.agreed })
            .width(18)
            .height(18)
          Text('我已阅读并同意以上条款')
            .fontSize(this.themeState.palette.fsSm)
            .fontColor(this.themeState.palette.textPrimary)
            .fontFamily(this.themeState.palette.fontSans)
            .onClick(() => {
              this.agreed = !this.agreed;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 12, bottom: 16 })

        // 同意按钮
        Button('同意并继续')
          .width('100%')
          .height(44)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.agreed ? this.themeState.palette.primary : '#888888')
          .borderRadius(22)
          .enabled(this.agreed)
          .onClick(() => {
            this.accept();
          })
      }
      .width(this.themeState.isSm ? '88%' : '70%')
      .constraintSize({ maxWidth: 400 })
      .padding(24)
      .borderRadius(16)
      .backgroundColor(this.themeState.palette.bgElevated)
      .shadow({ radius: 24, color: '#00000033', offsetX: 0, offsetY: 8 })
      .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
      .clip(true)
    }
  }
}

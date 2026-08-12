// 智子 - 锁屏覆盖层（主密码 + 生物识别解锁）
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { SecurityService } from '../service/SecurityService';
import { BiometricHelper } from '../service/BiometricHelper';

@Component
export struct LockOverlay {
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isSm') isSm: boolean = false;
  @State passwordInput: string = '';
  @State errorText: string = '';
  @State authenticating: boolean = false;
  onUnlocked: () => void = () => {};

  private async tryUnlock(): Promise<void> {
    const pwd: string = this.passwordInput.trim();
    if (pwd.length === 0) {
      this.errorText = '请输入密码';
      return;
    }
    this.authenticating = true;
    const ok: boolean = await SecurityService.verifyPassword(pwd);
    this.authenticating = false;
    if (ok) {
      SecurityService.unlock();
      this.passwordInput = '';
      this.errorText = '';
      this.onUnlocked();
    } else {
      this.errorText = '密码错误，请重试';
      this.passwordInput = '';
    }
  }

  private async tryBiometric(): Promise<void> {
    if (this.authenticating) return;
    if (!(await SecurityService.isBiometricEnabled())) {
      promptAction.showToast({ message: '请使用主密码解锁' });
      return;
    }
    if (!BiometricHelper.isSupported()) {
      promptAction.showToast({ message: '设备不支持生物识别，请使用密码解锁' });
      return;
    }
    this.authenticating = true;
    const ok: boolean = await BiometricHelper.authenticate('验证身份以解锁应用');
    this.authenticating = false;
    if (ok) {
      SecurityService.unlock();
      this.passwordInput = '';
      this.errorText = '';
      this.onUnlocked();
    }
  }

  build() {
    Stack() {
      Column({ space: 16 }) {
        // 顶部留白
        Blank()

        Text('🔒')
          .fontSize(56)
          .fontFamily(this.palette.fontSans)

        Text('智子已锁定')
          .fontSize(this.palette.fsXl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)

        Text('请输入主密码解锁')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)

        TextInput({ text: this.passwordInput, placeholder: '主密码' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface)
          .borderRadius(10)
          .border({ width: 1, color: this.palette.borderSubtle })
          .height(46)
          .type(InputType.Password)
          .width(this.isSm ? '80%' : '60%')
          .onChange((value: string) => { this.passwordInput = value; })
          .onSubmit(() => { this.tryUnlock(); })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.danger)
        }

        Button(this.authenticating ? '解锁中…' : '解锁')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .height(42)
          .width(this.isSm ? '80%' : '60%')
          .backgroundColor(this.palette.primary)
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .enabled(!this.authenticating)
          .onClick(() => { this.tryUnlock(); })

        Row({ space: 6 }) {
          Text('🔐')
            .fontSize(14)
            .fontFamily(this.palette.fontSans)
          Text('生物识别解锁')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.primary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .borderRadius(10)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => { this.tryBiometric(); })

        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

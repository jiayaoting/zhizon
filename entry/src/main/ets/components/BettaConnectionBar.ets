// 智子 - BettaFish 连接状态条（微舆 Hub 顶栏）
// 状态机：unconfigured（未配置） / checking（测试中） / connected（已连接） / error（连接失败）
// v10：状态卡改「淡色底状态区」——按状态取 success / warning / danger 语义色 + 对应淡底；无玻璃、无阴影。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct BettaConnectionBar {
  @Param state: string = 'unconfigured';   // unconfigured | checking | connected | error
  @Param serverName: string = '';
  @Param detail: string = '';
  @Event onConfigTap: () => void = () => {};
  @Event onRetryTap: () => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // 状态点颜色（语义色）
  private statusColor(): string {
    if (this.state === 'connected') return this.themeState.palette.success;
    if (this.state === 'checking') return this.themeState.palette.warning;
    if (this.state === 'error') return this.themeState.palette.danger;
    return this.themeState.palette.textTertiary;
  }

  // 状态区淡底
  private statusBg(): string {
    if (this.state === 'connected') return this.themeState.palette.successBg;
    if (this.state === 'checking') return this.themeState.palette.warningBg;
    if (this.state === 'error') return this.themeState.palette.dangerBg;
    return this.themeState.palette.bgSurface2;
  }

  private stateTitle(): string {
    if (this.state === 'connected') return '已连接 ' + this.serverName;
    if (this.state === 'checking') return '正在连接 ' + this.serverName;
    if (this.state === 'error') return '连接失败 · ' + this.serverName;
    return '尚未配置服务器';
  }

  // 服务器配置入口（44vp 触控目标）
  @Builder
  configButton() {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.settings)
          .fontSize(20)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(AppIcons.settingsEmoji)
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(44)
    .height(44)
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(this.themeState.palette.bgSurface)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText('服务器配置')
    .onClick(() => { this.onConfigTap(); })
  }

  // 文字动作：主操作 primary 填充，次操作 bgSurface2
  @Builder
  textAction(label: string, primaryFill: boolean, onTap: () => void) {
    Text(label)
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(primaryFill ? this.themeState.palette.primaryOnColor : this.themeState.palette.textPrimary)
      .fontWeight(FontWeight.Medium)
      .height(44)
      .padding({ left: 16, right: 16 })
      .borderRadius(this.themeState.palette.radiusCapsule)
      .backgroundColor(primaryFill ? this.themeState.palette.primary : this.themeState.palette.bgSurface)
      .textAlign(TextAlign.Center)
      .onClick(onTap)
  }

  build() {
    Row({ space: this.themeState.palette.sp3 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.statusColor())

      Column({ space: 2 }) {
        Text(this.stateTitle())
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.state === 'connected') {
        this.configButton()
      } else if (this.state === 'error') {
        this.textAction('重试', false, (): void => { this.onRetryTap(); })
        this.configButton()
      } else {
        this.textAction('去配置', true, (): void => { this.onConfigTap(); })
      }
    }
    .width('100%')
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp2,
      top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.statusBg())
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.stateTitle())
  }
}

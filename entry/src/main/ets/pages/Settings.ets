// 智子 - 设置页面（沉浸光感重构版）
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette, ColorThemeId, colorThemeName, colorThemeColor,
  ThemeManager, ThemeMode, PreferenceMutationResult, PreferenceFailureReason } from '../common/Theme';
import { BackgroundDisplayState } from '../common/Theme';
import { DataRepository } from '../service/DataRepository';
import { PickerAdapter, ImagePickResult, ImagePickState } from '../service/PickerAdapter';

import { TopBar } from '../components/TopBar';

// 分组卡片组件
@Component
struct GroupCard {
  @Prop title: string;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(this.palette.fsMd)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct SettingsPage {
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isDarkMode') isDarkMode: boolean = true;
  @StorageLink('followSystemDark') followSystemDark: boolean = true;
  @StorageLink('colorThemeId') colorThemeId: string = 'cyan';
  @StorageLink('backgroundDisplayState') backgroundDisplayState: BackgroundDisplayState = BackgroundDisplayState.INVALID;

  // 常规
  @State autoReconnect: boolean = true;
  @State defaultSshPort: string = '22';
  @State connectionTimeout: string = '30s';
  // 连接设置
  @State defaultConnectionMode: string = 'direct';
  // 外观
  @State fontSizeSetting: string = '标准';
  @State fontFamily: string = 'JetBrains Mono';
  // 终端
  @State color256: boolean = true;
  @State defaultFont: string = 'JetBrains Mono';
  @State cursorStyle: string = '块状';
  @State scrollLines: string = '1000';
  // 安全
  @State biometricUnlock: boolean = false;
  @State hostKeyVerify: boolean = true;
  @State autoLock: string = '5 分钟';
  // 通知
  @State alertPush: boolean = true;
  @State doNotDisturb: string = '22:00-08:00';
  @State cpuThreshold: string = '85%';
  @State memoryThreshold: string = '90%';
  @State diskThreshold: string = '95%';
  // 数据
  @State autoBackup: boolean = false;

  // 主题颜色选项
  private themeColors: ColorThemeId[] = [
    ColorThemeId.CYAN, ColorThemeId.OCEAN, ColorThemeId.SUNSET,
    ColorThemeId.AURORA, ColorThemeId.SAKURA, ColorThemeId.FOREST
  ];

  // 背景图设置
  @State showBgSettings: boolean = false;
  @State globalBgUri: string = '';
  @State backgroundStrength: number = 50;

  async aboutToAppear(): Promise<void> {
    this.loading = true;
    try {
      const autoReconnectVal = await DataRepository.getSetting('autoReconnect', 'true');
      this.autoReconnect = autoReconnectVal === 'true';
      const color256Val = await DataRepository.getSetting('color256', 'true');
      this.color256 = color256Val === 'true';
      const biometricUnlockVal = await DataRepository.getSetting('biometricUnlock', 'false');
      this.biometricUnlock = biometricUnlockVal === 'true';
      const hostKeyVerifyVal = await DataRepository.getSetting('hostKeyVerify', 'true');
      this.hostKeyVerify = hostKeyVerifyVal === 'true';
      const alertPushVal = await DataRepository.getSetting('alertPush', 'true');
      this.alertPush = alertPushVal === 'true';
      const autoBackupVal = await DataRepository.getSetting('autoBackup', 'false');
      this.autoBackup = autoBackupVal === 'true';

      this.defaultSshPort = await DataRepository.getSetting('defaultSshPort', '22');
      this.connectionTimeout = await DataRepository.getSetting('connectionTimeout', '30s');
      this.defaultConnectionMode = await DataRepository.getSetting('defaultConnectionMode', 'direct');
      this.fontSizeSetting = await DataRepository.getSetting('fontSize', '标准');
      this.fontFamily = await DataRepository.getSetting('fontFamily', 'JetBrains Mono');
      this.defaultFont = await DataRepository.getSetting('defaultFont', 'JetBrains Mono');
      this.cursorStyle = await DataRepository.getSetting('cursorStyle', '块状');
      this.scrollLines = await DataRepository.getSetting('scrollLines', '1000');
      this.autoLock = await DataRepository.getSetting('autoLock', '5 分钟');
      this.doNotDisturb = await DataRepository.getSetting('doNotDisturb', '22:00-08:00');
      this.cpuThreshold = await DataRepository.getSetting('cpuThreshold', '85%');
      this.memoryThreshold = await DataRepository.getSetting('memoryThreshold', '90%');
      this.diskThreshold = await DataRepository.getSetting('diskThreshold', '95%');

      // 加载背景图配置
      const background = ThemeManager.getInstance().getGlobalBackground();
      this.globalBgUri = background.globalUri;
      this.backgroundStrength = background.visibleStrength;
    } finally {
      this.loading = false;
    }
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 打开系统文件选择器选取背景图
  private async pickBackgroundImage(): Promise<void> {
    const picked: ImagePickResult = await PickerAdapter.pickSingleImage();
    if (picked.state === ImagePickState.CANCELLED) return;
    if (picked.state === ImagePickState.FAILED) {
      this.toast('选择背景图失败');
      return;
    }
    const manager = ThemeManager.getInstance();
    manager.beginBackgroundCandidate(picked.uri);
    const mutation: PreferenceMutationResult = await manager.importBackgroundCandidate(picked.uri);
    this.applyPreferenceResult(mutation);
    if (mutation.success) {
      this.toast('背景图已设置');
    } else if (mutation.reason === PreferenceFailureReason.PERSISTENCE_FAILED) {
      this.toast('设置未保存，请重试');
    } else {
      this.toast('无法读取所选图片，请重新选择');
    }
  }

  private async updateFollowSystem(follow: boolean): Promise<void> {
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setFollowSystem(follow);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(follow ? '已开启跟随系统深色模式' : '已切换为手动模式');
    } else {
      this.toast('设置未保存，请重试');
    }
  }

  private async updateManualMode(isDark: boolean): Promise<void> {
    const mode = isDark ? ThemeMode.DARK : ThemeMode.LIGHT;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setManualMode(mode);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(isDark ? '已切换为深色模式' : '已切换为浅色模式');
    } else {
      this.toast('设置未保存，请重试');
    }
  }

  private async clearBackground(): Promise<void> {
    const result: PreferenceMutationResult = await ThemeManager.getInstance().clearGlobalBackground();
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast('背景图已清除');
    } else {
      this.toast('设置未保存，请重试');
    }
  }

  private async saveBackgroundStrength(value: number): Promise<void> {
    const strength = Math.round(value);
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setBackgroundStrength(strength);
    this.applyPreferenceResult(result);
    if (!result.success) {
      this.toast('设置未保存，请重试');
    }
  }

  private async updateColorTheme(themeId: ColorThemeId): Promise<void> {
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setColorTheme(themeId);
    this.applyPreferenceResult(result);
    if (!result.success) this.toast('设置未保存，请重试');
  }

  private applyPreferenceResult(result: PreferenceMutationResult): void {
    if (result.published || result.restored) {
      this.globalBgUri = result.snapshot.backgroundUri;
      this.backgroundStrength = result.snapshot.backgroundStrength;
      this.followSystemDark = result.snapshot.followSystem;
      this.colorThemeId = result.snapshot.colorThemeId;
    }
  }

  @Builder valueRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.palette.textPrimary)
        .layoutWeight(1)
      if (value) {
        Text(value)
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
          .margin({ right: 6 })
      }
      Text('›')
        .fontSize(14)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(this.palette.bgSurface2)
    .onClick(() => this.toast(value ? `${label}：${value}` : label))
  }

  @Builder toggleRow(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.palette.textPrimary)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.palette.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(this.palette.bgSurface2)
  }

  // 颜色主题选择器
  @Builder colorThemeSelector() {
    Row({ space: 10 }) {
      ForEach(this.themeColors, (themeId: ColorThemeId) => {
        Column() {
          Stack() {
            Circle({ width: 36, height: 36 })
              .fill(colorThemeColor(themeId))
            if (this.colorThemeId === themeId) {
              Text('✓')
                .fontSize(14)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          Text(colorThemeName(themeId))
            .fontSize(9)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Center)
        .onClick(async () => {
          await this.updateColorTheme(themeId);
        })
      }, (themeId: ColorThemeId) => themeId)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
  }

  // 深色模式设置
  @Builder darkModeSettings() {
    Column({ space: 8 }) {
      this.toggleRow('跟随系统深色模式', this.followSystemDark, async (v: boolean) => {
        await this.updateFollowSystem(v);
      })
      if (!this.followSystemDark) {
        this.toggleRow('深色模式', this.isDarkMode, async (v: boolean) => {
          await this.updateManualMode(v);
        })
      }
    }
    .width('100%')
  }

  // 背景图设置
  @Builder backgroundSettings() {
    Column({ space: 8 }) {
      Row() {
        Text('全局背景图')
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        if (this.backgroundDisplayState === BackgroundDisplayState.LOADING) {
          Text('正在应用')
            .fontSize(12)
            .fontColor(this.palette.primary)
        } else if (this.backgroundDisplayState === BackgroundDisplayState.INVALID && this.globalBgUri) {
          Text('背景失效，请重新选择')
            .fontSize(12)
            .fontColor(this.palette.warning)
        } else if (this.globalBgUri) {
          Text('已设置')
            .fontSize(12)
            .fontColor(this.palette.success)
        } else {
          Text('未设置')
            .fontSize(12)
            .fontColor(this.palette.textTertiary)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 11, bottom: 11 })
      .borderRadius(6)
      .backgroundColor(this.palette.bgSurface2)
      .onClick(() => {
        this.pickBackgroundImage();
      })

      if (this.globalBgUri) {
        Row() {
          Text('清除背景图')
            .fontSize(13)
            .fontColor(this.palette.danger)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 11, bottom: 11 })
        .borderRadius(6)
        .backgroundColor(this.palette.bgSurface2)
        .onClick(async () => {
          await this.clearBackground();
        })
      }

      Row() {
        Text('可见强度')
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        Text(`${this.backgroundStrength}%`)
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
      Slider({ value: this.backgroundStrength, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.palette.primary)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.backgroundStrength = Math.round(value);
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.saveBackgroundStrength(this.backgroundStrength);
          }
        })
    }
    .width('100%')
  }

  @Builder actionsBuilder() {}

  build() {
    Column() {
      TopBar({ title: '设置', subtitle: '智子 v1.0.0' }) {
        this.actionsBuilder()
      }
      Scroll() {
          Column({ space: 16 }) {
            // 常规
            GroupCard({ title: '常规' }) {
              Column({ space: 8 }) {
                this.valueRow('默认 SSH 端口', this.defaultSshPort)
                this.valueRow('连接超时', this.connectionTimeout)
                this.toggleRow('自动重连', this.autoReconnect, (v: boolean) => {
                  this.autoReconnect = v;
                  DataRepository.setSetting('autoReconnect', v ? 'true' : 'false');
                  this.toast(`自动重连：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 连接设置
            GroupCard({ title: '连接设置' }) {
              Column({ space: 8 }) {
                Row() {
                  Text('连接模式')
                    .fontSize(13)
                    .fontColor(this.palette.textPrimary)
                    .layoutWeight(1)
                  Text('直连模式')
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(5)
                    .backgroundColor(this.palette.primary)
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                .borderRadius(6)
                .backgroundColor(this.palette.bgSurface2)
                Text('直连模式在设备端直接发起 SSH 连接。Agent 模式暂不可用。')
                  .fontSize(10)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
              }
              .width('100%')
            }

            // 外观（新设计）
            GroupCard({ title: '外观' }) {
              Column({ space: 12 }) {
                // 颜色主题选择器
                Text('颜色主题')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.colorThemeSelector()

                // 深色模式
                Text('深色模式')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.darkModeSettings()

                // 背景图
                Text('背景图')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.backgroundSettings()

                this.valueRow('字号', this.fontSizeSetting)
                this.valueRow('字体', this.fontFamily)
              }
              .width('100%')
            }

            // 终端
            GroupCard({ title: '终端' }) {
              Column({ space: 8 }) {
                this.valueRow('默认字体', this.defaultFont)
                this.valueRow('光标样式', this.cursorStyle)
                this.valueRow('滚屏行数', this.scrollLines)
                this.toggleRow('256 色', this.color256, (v: boolean) => {
                  this.color256 = v;
                  DataRepository.setSetting('color256', v ? 'true' : 'false');
                  this.toast(`256 色：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 安全
            GroupCard({ title: '安全' }) {
              Column({ space: 8 }) {
                this.valueRow('主密码', '已设置')
                this.toggleRow('生物识别解锁', this.biometricUnlock, (v: boolean) => {
                  this.biometricUnlock = v;
                  DataRepository.setSetting('biometricUnlock', v ? 'true' : 'false');
                  this.toast(`生物识别解锁：${v ? '已开启' : '已关闭'}`);
                })
                this.valueRow('自动锁定', this.autoLock)
                this.toggleRow('主机指纹校验', this.hostKeyVerify, (v: boolean) => {
                  this.hostKeyVerify = v;
                  DataRepository.setSetting('hostKeyVerify', v ? 'true' : 'false');
                  this.toast(`主机指纹校验：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 通知
            GroupCard({ title: '通知' }) {
              Column({ space: 8 }) {
                this.toggleRow('告警推送', this.alertPush, (v: boolean) => {
                  this.alertPush = v;
                  DataRepository.setSetting('alertPush', v ? 'true' : 'false');
                  this.toast(`告警推送：${v ? '已开启' : '已关闭'}`);
                })
                this.valueRow('勿扰时段', this.doNotDisturb)
                this.valueRow('CPU 阈值', this.cpuThreshold)
                this.valueRow('内存阈值', this.memoryThreshold)
                this.valueRow('磁盘阈值', this.diskThreshold)
              }
              .width('100%')
            }

            // 数据
            GroupCard({ title: '数据' }) {
              Column({ space: 8 }) {
                this.valueRow('导出配置', '')
                this.valueRow('导入配置', '')
                this.valueRow('清除缓存', '')
                this.toggleRow('自动备份', this.autoBackup, (v: boolean) => {
                  this.autoBackup = v;
                  DataRepository.setSetting('autoBackup', v ? 'true' : 'false');
                  this.toast(`自动备份：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 关于
            GroupCard({ title: '关于' }) {
              Column({ space: 8 }) {
                this.valueRow('版本', '1.0.0')
                this.valueRow('检查更新', '')
                this.valueRow('用户协议', '')
                this.valueRow('隐私政策', '')
                this.valueRow('开源许可', '')
                this.valueRow('反馈', '')
              }
              .width('100%')
            }
          }
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 0, bottom: 80 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

// 智子 - 设置页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { DataRepository } from '../service/DataRepository';

import { TopBar } from '../components/TopBar';

// 分组卡片组件
@Component
struct GroupCard {
  @Prop title: string;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(AppTheme.fsMd)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct SettingsPage {
  @State loading: boolean = true;

  // 常规
  @State autoReconnect: boolean = true;
  @State defaultSshPort: string = '22';
  @State connectionTimeout: string = '30s';
  // 外观
  @State theme: string = '深色';
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
  @StorageLink('isSm') isSm: boolean = false;

  async aboutToAppear(): Promise<void> {
    this.loading = true;
    try {
      // 加载开关类设置
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

      // 加载值类设置
      this.defaultSshPort = await DataRepository.getSetting('defaultSshPort', '22');
      this.connectionTimeout = await DataRepository.getSetting('connectionTimeout', '30s');
      this.theme = await DataRepository.getSetting('theme', '深色');
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
    } finally {
      this.loading = false;
    }
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 普通值/操作项：左标签 + 右值 + 右箭头
  @Builder valueRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
      if (value) {
        Text(value)
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
          .margin({ right: 6 })
      }
      Text('›')
        .fontSize(14)
        .fontColor(AppTheme.textTertiary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(AppTheme.bgSurface2)
    .onClick(() => this.toast(value ? `${label}：${value}` : label))
  }

  // 开关项（使用 $state 双向绑定）
  @Builder toggleRow(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(AppTheme.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(AppTheme.bgSurface2)
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

            // 外观
            GroupCard({ title: '外观' }) {
              Column({ space: 8 }) {
                this.valueRow('主题', this.theme)
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
          .padding(this.isSm ? 16 : 24)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}
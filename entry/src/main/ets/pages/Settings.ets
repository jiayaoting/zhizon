// 智子 - 设置页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';

@Entry
@Component
struct SettingsPage {
  @State activeNav: string = 'Settings';
  // 常规
  @State autoReconnect: boolean = true;
  // 终端
  @State color256: boolean = true;
  // 安全
  @State biometricUnlock: boolean = false;
  @State hostKeyVerify: boolean = true;
  // 通知
  @State alertPush: boolean = true;
  // 数据
  @State autoBackup: boolean = false;

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 分组卡片
  @Builder groupCard(title: string, content: () => void) {
    Column({ space: 12 }) {
      Text(title)
        .fontSize(AppTheme.fsMd)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
      content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
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
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(12)
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
    Row() {
      NavSidebar({ activeKey: this.activeNav, onSelect: (key: string) => {
        router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
      }})
      Column() {
        TopBar({ title: '设置', subtitle: '智子 v1.0.0' }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            // 常规
            this.groupCard('常规') {
              Column({ space: 8 }) {
                this.valueRow('默认 SSH 端口', '22')
                this.valueRow('连接超时', '30s')
                this.toggleRow('自动重连', this.autoReconnect, (v: boolean) => {
                  this.autoReconnect = v;
                  this.toast(`自动重连：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 外观
            this.groupCard('外观') {
              Column({ space: 8 }) {
                this.valueRow('主题', '深色')
                this.valueRow('字号', '标准')
                this.valueRow('字体', 'JetBrains Mono')
              }
              .width('100%')
            }

            // 终端
            this.groupCard('终端') {
              Column({ space: 8 }) {
                this.valueRow('默认字体', 'JetBrains Mono')
                this.valueRow('光标样式', '块状')
                this.valueRow('滚屏行数', '1000')
                this.toggleRow('256 色', this.color256, (v: boolean) => {
                  this.color256 = v;
                  this.toast(`256 色：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 安全
            this.groupCard('安全') {
              Column({ space: 8 }) {
                this.valueRow('主密码', '已设置')
                this.toggleRow('生物识别解锁', this.biometricUnlock, (v: boolean) => {
                  this.biometricUnlock = v;
                  this.toast(`生物识别解锁：${v ? '已开启' : '已关闭'}`);
                })
                this.valueRow('自动锁定', '5 分钟')
                this.toggleRow('主机指纹校验', this.hostKeyVerify, (v: boolean) => {
                  this.hostKeyVerify = v;
                  this.toast(`主机指纹校验：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 通知
            this.groupCard('通知') {
              Column({ space: 8 }) {
                this.toggleRow('告警推送', this.alertPush, (v: boolean) => {
                  this.alertPush = v;
                  this.toast(`告警推送：${v ? '已开启' : '已关闭'}`);
                })
                this.valueRow('勿扰时段', '22:00-08:00')
                this.valueRow('CPU 阈值', '85%')
                this.valueRow('内存阈值', '90%')
                this.valueRow('磁盘阈值', '95%')
              }
              .width('100%')
            }

            // 数据
            this.groupCard('数据') {
              Column({ space: 8 }) {
                this.valueRow('导出配置', '')
                this.valueRow('导入配置', '')
                this.valueRow('清除缓存', '')
                this.toggleRow('自动备份', this.autoBackup, (v: boolean) => {
                  this.autoBackup = v;
                  this.toast(`自动备份：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 关于
            this.groupCard('关于') {
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
          .padding(24)
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
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

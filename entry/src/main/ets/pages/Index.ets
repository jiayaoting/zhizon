// 智子 - 首页（沉浸光感版）
// 欢迎区 + 应用概览 + 快速操作网格 + 最近告警
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { AppConstants, ToolboxItem } from '../common/Constants';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { DataRepository } from '../service/DataRepository';
import { Alert, Stats, Command } from '../model/Models';

const emptyStats: Stats = {
  total: 0, online: 0, warning: 0, offline: 0, alerts: 0
};

@Component
export struct IndexPage {
  @State currentTime: string = '';
  @State greeting: string = '';
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @State stats: Stats = emptyStats;
  @State commands: Command[] = [];
  @State alerts: Alert[] = [];
  @State loading: boolean = true;
  onNavigate: (key: string) => void = () => {};

  // 快速操作入口
  private quickActions: ToolboxItem[] = AppConstants.toolboxItems;
  // 可玩游戏数（俄罗斯方块 / 2048 / 贪吃蛇）
  private readonly gameCount: number = 3;

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadData();
  }

  aboutToDisappear(): void {
    // 概览数据为单次拉取，无持久资源需要释放
  }

  private async loadData() {
    try {
      const stats = await DataRepository.getStats();
      const commands = await DataRepository.getCommands();
      const alerts = await DataRepository.getAlerts();
      this.stats = stats;
      this.commands = commands;
      this.alerts = alerts;
    } finally {
      this.loading = false;
    }
  }

  private getGreeting(): string {
    const h = new Date().getHours();
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  private formatNow(): string {
    const d = new Date();
    const pad = (n: number) => n < 10 ? `0${n}` : `${n}`;
    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];
    return `${d.getFullYear()}年${pad(d.getMonth() + 1)}月${pad(d.getDate())}日 星期${weekDays[d.getDay()]}`;
  }

  private alertColor(level: string): string {
    if (level === 'critical') return this.palette.danger;
    if (level === 'warning') return this.palette.warning;
    return this.palette.info;
  }

  // ==================== 欢迎区 ====================
  @Builder
  welcomeSection() {
    Row() {
      Column() {
        Text(this.greeting)
          .fontSize(24)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.currentTime)
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 用户头像
      Stack() {
        Circle({ width: 40, height: 40 })
          .fill(this.palette.bgElevated)
          .border({ width: 2, color: this.palette.primary })
        Text('Z')
          .fontSize(16)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 应用概览统计 ====================
  @Builder
  overviewStats() {
    Column({ space: 0 }) {
      Row() {
        Text('应用概览')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Row({ space: 10 }) {
        // 快捷命令
        Column({ space: 6 }) {
          Text('⚡')
            .fontSize(20)
          Text(`${this.commands.length}`)
            .fontSize(24)
            .fontColor(this.palette.primary)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
          Text('快捷命令')
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .borderRadius(12)
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.onNavigate('Commands');
        })

        // 游戏中心
        Column({ space: 6 }) {
          Text('🎮')
            .fontSize(20)
          Text(`${this.gameCount}`)
            .fontSize(24)
            .fontColor(this.palette.warning)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
          Text('款游戏')
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .borderRadius(12)
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.onNavigate('Games');
        })

        // 未处理告警
        Column({ space: 6 }) {
          Text('🔔')
            .fontSize(20)
          Text(`${this.stats.alerts}`)
            .fontSize(24)
            .fontColor(this.stats.alerts > 0 ? this.palette.danger : this.palette.success)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
          Text('未处理告警')
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .borderRadius(12)
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.onNavigate('Alerts');
        })
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 快速操作网格 ====================
  @Builder
  quickActionsGrid() {
    Column({ space: 0 }) {
      // 标题
      Row() {
        Text('快速操作')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Grid() {
        ForEach(this.quickActions, (item: ToolboxItem) => {
          GridItem() {
            Column({ space: 8 }) {
              Text(item.icon)
                .fontSize(28)
              Text(item.label)
                .fontSize(11)
                .fontColor(this.palette.textSecondary)
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.desc)
                .fontSize(9)
                .fontColor(this.palette.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ top: 18, bottom: 18 })
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.onNavigate(item.key);
            })
          }
        }, (item: ToolboxItem) => item.key)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 最近告警 ====================
  @Builder
  recentAlerts() {
    Column({ space: 0 }) {
      Row() {
        Text('最近告警')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('查看全部 ›')
          .fontSize(12)
          .fontColor(this.palette.primary)
          .onClick(() => {
            this.onNavigate('Alerts');
          })
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Column({ space: 8 }) {
        ForEach(this.alerts.slice(0, 3), (a: Alert) => {
          Row() {
            // 左侧色条
            Column()
              .width(3)
              .height('100%')
              .backgroundColor(this.alertColor(a.level))
              .borderRadius(1.5)

            Column({ space: 4 }) {
              Row() {
                Text(a.title)
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(a.time)
                  .fontSize(10)
                  .fontColor(this.palette.textTertiary)
                  .fontFamily(this.palette.fontMono)
              }
              .width('100%')

              Text(a.source)
                .fontSize(10)
                .fontColor(this.palette.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .padding({ left: 12, top: 10, bottom: 10, right: 12 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .borderRadius(10)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
        }, (a: Alert) => a.id)

        if (this.alerts.length === 0) {
          Text('暂无告警，一切正常 ✓')
            .fontSize(13)
            .fontColor(this.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(20)
        }
      }
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.palette.primary)
          Text('加载中...')
            .fontSize(14)
            .fontColor(this.palette.textSecondary)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 20 }) {
            // 欢迎区
            this.welcomeSection()

            // 应用概览统计
            this.overviewStats()

            // 快速操作网格
            this.quickActionsGrid()

            // 最近告警
            this.recentAlerts()

            // 底部留白
            Column().height(20)
          }
          .width('100%')
          .padding({ top: this.statusBarHeight + (this.isSm ? 16 : 24) })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
    }
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

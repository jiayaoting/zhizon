// 智子 - 全新首页（沉浸光感版）
// 欢迎区 + 核心指标轮播 + 快速操作网格 + 最近活动时间线 + 服务器快照
import { ThemePalette, defaultLightPalette, ThemeManager } from '../common/Theme';
import { AppConstants, ToolboxItem } from '../common/Constants';
import { MetricCard } from '../components/MetricCard';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { DataRepository } from '../service/DataRepository';
import { Server, PveCluster, Alert, Stats, PveNode } from '../model/Models';

const emptyStats: Stats = {
  total: 0, online: 0, warning: 0, offline: 0, alerts: 0,
  pveNodes: 0, vmTotal: 0, vmRunning: 0, vmStopped: 0,
  ctTotal: 0, runningTasks: 0
};

@Component
export struct IndexPage {
  @State currentTime: string = '';
  @State greeting: string = '';
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @State stats: Stats = emptyStats;
  @State servers: Server[] = [];
  @State alerts: Alert[] = [];
  @State loading: boolean = true;
  onNavigate: (key: string) => void = () => {};

  // 快速操作入口
  private quickActions: ToolboxItem[] = AppConstants.toolboxItems;

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadData();
  }

  private async loadData() {
    try {
      const stats = await DataRepository.getStats();
      const servers = await DataRepository.getServers();
      const alerts = await DataRepository.getAlerts();
      this.stats = stats;
      this.servers = servers;
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

  // ==================== 核心指标轮播 ====================
  @Builder
  metricsCarousel() {
    Scroll() {
      Row({ space: 10 }) {
        // 服务器总数
        Column() {
          Row() {
            Text('🖥️')
              .fontSize(14)
            Text('SSH 服务器')
              .fontSize(11)
              .fontColor(this.palette.textTertiary)
              .margin({ left: 6 })
          }
          Text(`${this.stats.total}`)
            .fontSize(28)
            .fontColor(this.palette.primary)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
            .margin({ top: 8 })
          Text(`在线 ${this.stats.online} · 告警 ${this.stats.warning}`)
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
        }
        .width(140)
        .padding(14)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.onNavigate('Servers');
        })

        // PVE 节点
        Column() {
          Row() {
            Text('🗂️')
              .fontSize(14)
            Text('PVE 节点')
              .fontSize(11)
              .fontColor(this.palette.textTertiary)
              .margin({ left: 6 })
          }
          Text(`${this.stats.pveNodes}`)
            .fontSize(28)
            .fontColor(this.palette.purple)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
            .margin({ top: 8 })
          Text(`VM ${this.stats.vmTotal} · CT ${this.stats.ctTotal}`)
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
        }
        .width(140)
        .padding(14)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.onNavigate('Pve');
        })

        // 运行中 VM
        Column() {
          Row() {
            Text('▶️')
              .fontSize(14)
            Text('运行中 VM')
              .fontSize(11)
              .fontColor(this.palette.textTertiary)
              .margin({ left: 6 })
          }
          Text(`${this.stats.vmRunning}`)
            .fontSize(28)
            .fontColor(this.palette.info)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
            .margin({ top: 8 })
          Text(`停止 ${this.stats.vmStopped}`)
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
        }
        .width(140)
        .padding(14)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
        .alignItems(HorizontalAlign.Start)

        // 未处理告警
        Column() {
          Row() {
            Text('🔔')
              .fontSize(14)
            Text('未处理告警')
              .fontSize(11)
              .fontColor(this.palette.textTertiary)
              .margin({ left: 6 })
          }
          Text(`${this.stats.alerts}`)
            .fontSize(28)
            .fontColor(this.palette.danger)
            .fontWeight(FontWeight.Bold)
            .fontFamily(this.palette.fontMono)
            .margin({ top: 8 })
          Text(`任务 ${this.stats.runningTasks}`)
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
        }
        .width(140)
        .padding(14)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.onNavigate('Alerts');
        })
      }
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
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
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .borderRadius(12)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.onNavigate(item.key);
            })
          }
        }, (item: ToolboxItem) => item.key)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 服务器状态快照 ====================
  @Builder
  serverSnapshot() {
    Column({ space: 0 }) {
      Row() {
        Text('服务器状态')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.stats.online}/${this.stats.total} 在线`)
          .fontSize(12)
          .fontColor(this.palette.primary)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.servers.slice(0, 6), (s: Server) => {
            Column({ space: 8 }) {
              // 状态点 + 名称
              Row({ space: 6 }) {
                Circle({ width: 7, height: 7 })
                  .fill(s.status === 'online' ? this.palette.success
                    : s.status === 'warning' ? this.palette.warning
                    : this.palette.textTertiary)
                Text(s.name)
                  .fontSize(12)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')

              // 微型进度条
              Column({ space: 3 }) {
                Row({ space: 2 }) {
                  Text('CPU')
                    .fontSize(9)
                    .fontColor(this.palette.textTertiary)
                    .width(26)
                  ProgressBar({ value: s.metrics.cpu, barHeight: 3 })
                    .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row({ space: 2 }) {
                  Text('MEM')
                    .fontSize(9)
                    .fontColor(this.palette.textTertiary)
                    .width(26)
                  ProgressBar({ value: s.metrics.mem, barHeight: 3 })
                    .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
            }
            .width(130)
            .padding(12)
            .borderRadius(10)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.onNavigate('Servers');
            })
          }, (s: Server) => s.id)
        }
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
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

            // 核心指标轮播
            this.metricsCarousel()

            // 快速操作网格
            this.quickActionsGrid()

            // 服务器状态快照
            this.serverSnapshot()

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

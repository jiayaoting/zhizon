// 智子 - 服务器监控详情页
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme, progressColor } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { MetricCard } from '../components/MetricCard';
import { DataRepository, formatUptime } from '../service/DataRepository';
import { Server, Alert } from '../model/Models';

interface ServerDetailParams {
  serverId: string;
}

// Top 进程假数据
interface TopProcess {
  pid: number;
  name: string;
  cpu: number;
  mem: number;
}

@Entry
@Component
struct ServerDetailPage {
  @State activeNav: string = 'Servers';
  @State server: Server | null = null;
  private alerts: Alert[] = DataRepository.getAlerts();
  private topProcesses: TopProcess[] = [
    { pid: 1234, name: 'nginx', cpu: 12.5, mem: 4.2 },
    { pid: 2345, name: 'mysqld', cpu: 8.3, mem: 18.6 },
    { pid: 3456, name: 'node', cpu: 5.1, mem: 6.8 },
    { pid: 4567, name: 'redis-server', cpu: 2.4, mem: 1.2 },
    { pid: 5678, name: 'systemd', cpu: 0.5, mem: 0.8 }
  ];

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.server = DataRepository.getServer(params?.serverId || '') || null;
  }

  // 告警级别颜色
  private alertColor(level: string): string {
    if (level === 'critical') return AppTheme.danger;
    if (level === 'warning') return AppTheme.warning;
    return AppTheme.info;
  }

  @Builder actionsBuilder() {
    Row({ space: 8 }) {
      Button('刷新')
        .fontSize(12)
        .fontColor(AppTheme.textSecondary)
        .backgroundColor(AppTheme.bgSurface2)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          promptAction.showToast({ message: '已刷新' });
        })
      Button('终端')
        .fontSize(12)
        .fontColor(AppTheme.primary)
        .backgroundColor(AppTheme.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          if (this.server) {
            router.pushUrl({ url: 'pages/Terminal', params: { serverName: this.server.name } }).catch(() => {});
          }
        })
    }
  }

  // Top 进程行
  @Builder processRow(p: TopProcess) {
    Row() {
      Text(`${p.pid}`)
        .fontSize(11)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(60)
      Text(p.name)
        .fontSize(12)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
      Text(`${p.cpu.toFixed(1)}%`)
        .fontSize(11)
        .fontColor(AppTheme.primary)
        .fontFamily(AppTheme.fontMono)
        .width(70)
      Text(`${p.mem.toFixed(1)}%`)
        .fontSize(11)
        .fontColor(AppTheme.info)
        .fontFamily(AppTheme.fontMono)
        .width(70)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // 相关告警行
  @Builder alertRow(a: Alert) {
    Row() {
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.alertColor(a.level))
      Column({ space: 4 }) {
        Text(a.title)
          .fontSize(12)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(a.detail)
          .fontSize(10)
          .fontColor(AppTheme.textSecondary)
        Text(`${a.source} · ${a.time}`)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
      }
      .layoutWeight(1)
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(8)
    .backgroundColor(AppTheme.bgSurface2)
  }

  build() {
    Row() {
      NavSidebar({
        activeKey: this.activeNav,
        onSelect: (key: string) => {
          router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
        }
      })
      Column() {
        if (this.server) {
          TopBar({
            title: this.server.name,
            subtitle: `${this.server.host}:${this.server.port} · ${this.server.os}`
          }) {
            this.actionsBuilder()
          }
          Scroll() {
            Column({ space: 16 }) {
              // 头部卡片
              Row({ space: 16 }) {
                Column({ space: 4 }) {
                  Text(this.server.name)
                    .fontSize(AppTheme.fs2xl)
                    .fontColor(AppTheme.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Text(this.server.os || '-')
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 8 }) {
                  StatusBadge({ status: this.server.status })
                  Text(`运行 ${formatUptime(this.server.metrics.uptime)}`)
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                  Text(`负载 ${this.server.metrics.load.toFixed(2)}`)
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                    .fontFamily(AppTheme.fontMono)
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(16)
              .borderRadius(10)
              .backgroundColor(AppTheme.bgSurface)
              .border({ width: 1, color: AppTheme.borderSubtle })
              .alignItems(VerticalAlign.Center)

              // 4 指标卡
              Row({ space: 12 }) {
                MetricCard({
                  title: 'CPU',
                  value: String(this.server.metrics.cpu),
                  unit: '%',
                  color: progressColor(this.server.metrics.cpu)
                }).layoutWeight(1)
                MetricCard({
                  title: '内存',
                  value: String(this.server.metrics.mem),
                  unit: '%'
                }).layoutWeight(1)
                MetricCard({
                  title: '磁盘',
                  value: String(this.server.metrics.disk),
                  unit: '%',
                  color: AppTheme.warning
                }).layoutWeight(1)
                MetricCard({
                  title: '网络',
                  value: String(this.server.metrics.netIn),
                  unit: 'Mbps',
                  color: AppTheme.success
                }).layoutWeight(1)
              }
              .width('100%')

              // 资源使用趋势区
              Column({ space: 8 }) {
                Text('最近 24 小时趋势')
                  .fontSize(AppTheme.fsMd)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Row() {
                  Text('趋势图占位')
                    .fontSize(12)
                    .fontColor(AppTheme.textTertiary)
                }
                .width('100%')
                .height(120)
                .borderRadius(8)
                .backgroundColor(AppTheme.bgSurface2)
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // Top 进程
              Column({ space: 8 }) {
                Text('Top 进程')
                  .fontSize(AppTheme.fsMd)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Column({ space: 0 }) {
                  // 表头
                  Row() {
                    Text('PID')
                      .fontSize(10)
                      .fontColor(AppTheme.textTertiary)
                      .width(60)
                    Text('进程名')
                      .fontSize(10)
                      .fontColor(AppTheme.textTertiary)
                      .layoutWeight(1)
                    Text('CPU')
                      .fontSize(10)
                      .fontColor(AppTheme.textTertiary)
                      .width(70)
                    Text('内存')
                      .fontSize(10)
                      .fontColor(AppTheme.textTertiary)
                      .width(70)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .alignItems(VerticalAlign.Center)

                  ForEach(this.topProcesses, (p: TopProcess) => {
                    this.processRow(p)
                  }, (p: TopProcess) => String(p.pid))
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .borderRadius(10)
                .backgroundColor(AppTheme.bgSurface)
                .border({ width: 1, color: AppTheme.borderSubtle })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 相关告警
              Column({ space: 8 }) {
                Text('相关告警')
                  .fontSize(AppTheme.fsMd)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                ForEach(
                  this.alerts.filter(a => a.source.includes(this.server!.name)),
                  (a: Alert) => { this.alertRow(a) },
                  (a: Alert) => a.id
                )
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .padding(24)
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        } else {
          Column() {
            Text('服务器不存在')
              .fontSize(AppTheme.fsMd)
              .fontColor(AppTheme.textTertiary)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(AppTheme.bgBase)
    }
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

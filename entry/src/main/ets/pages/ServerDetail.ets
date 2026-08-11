// 智子 - 服务器监控详情页
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemePalette, defaultLightPalette, progressColor } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { Server, Alert, ServerMetrics } from '../model/Models';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationFacade,
  NavigationSource, ServerDetailParameterResult, ServerDetailRouteParams, mainPage } from '../common/Navigation';
import { RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from '../service/RemoteResultAdapter';

// Top 进程（后续由真实 SSH 命令获取）
interface TopProcess {
  pid: number;
  name: string;
  cpu: number;
  mem: number;
}

@Entry
@Component
struct ServerDetailPage {
  @State server: Server | null = null;
  @State alerts: Alert[] = [];
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @State topProcesses: TopProcess[] = [];

  async aboutToAppear() {
    const params: ServerDetailRouteParams | null = router.getParams() as ServerDetailRouteParams | null;
    const parsed: ServerDetailParameterResult = NavigationFacade.serverDetailParameters(params);
    if (!parsed.valid || parsed.value === null) {
      this.loading = false;
      promptAction.showToast({ message: '服务器参数无效，已返回上一页' });
      router.back();
      return;
    }
    const detailParams: ServerDetailRouteParams = parsed.value;
    this.server = await DataRepository.getServer(detailParams.serverId) || null;
    this.alerts = await DataRepository.getAlerts();
    this.loading = false;

    // 拉取实时指标
    if (this.server) {
      await this.refreshMetrics();
    }
  }

  aboutToDisappear(): void {
    // 指标拉取为单次短连接请求，无持久资源需要释放
  }

  // 从 Agent 拉取实时指标
  private async refreshMetrics(): Promise<void> {
    if (!this.server) return;
    try {
      const result: RemoteResult<ServerMetrics> = await SshService.getMetrics(this.server);
      if (!result.success || result.value === null) {
        RemoteResultAdapter.logFailure('server-metrics', result);
        promptAction.showToast({ message: RemoteResultAdapter.publicMessage(result) });
        return;
      }
      const metrics: ServerMetrics = result.value;
      this.server = {
        id: this.server.id,
        name: this.server.name,
        host: this.server.host,
        port: this.server.port,
        username: this.server.username,
        authType: this.server.authType,
        connectionMode: this.server.connectionMode,
        agentToken: this.server.agentToken,
        privateKeyPath: this.server.privateKeyPath,
        group: this.server.group,
        tags: this.server.tags,
        os: this.server.os,
        status: metrics.cpu > 0 ? 'online' : 'offline',
        metrics: metrics,
        lastConnected: this.server.lastConnected,
        createdAt: this.server.createdAt
      };
    } catch (e) {
      hilog.error(0x9201, 'ServerDetail', '%{public}s', 'operation=metrics category=REMOTE_PROTOCOL code=METRICS_LOAD_FAILED rollback=preserved');
    }
  }

  // 告警级别颜色
  private alertColor(level: string): string {
    if (level === 'critical') return this.palette.danger;
    if (level === 'warning') return this.palette.warning;
    return this.palette.info;
  }

  private selectMain(key: MainNavKey): void {
    const previous: NavigationState = new NavigationState(PageKey.ServerDetail, MainNavKey.Servers);
    NavigationFacade.openPage(previous, mainPage(key), NavigationSource.MAIN_NAV, true).then((result: NavigationResult) => {
      if (!result.success) promptAction.showToast({ message: '页面打开失败，请重试或返回' });
    });
  }

  @Builder actionsBuilder() {
    Row({ space: 8 }) {
      Button('刷新')
        .fontSize(12)
        .fontColor(this.palette.textSecondary)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          this.refreshMetrics().then(() => {
            promptAction.showToast({ message: '指标已刷新' });
          });
        })
      Button('终端')
        .fontSize(12)
        .fontColor(this.palette.primary)
        .backgroundColor(this.palette.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          if (this.server) {
            const previous: NavigationState = new NavigationState(PageKey.ServerDetail, MainNavKey.Servers);
            NavigationFacade.openTerminal(previous, this.server.id, '').then((result: NavigationResult) => {
              if (!result.success) promptAction.showToast({ message: '终端打开失败，请重试或返回' });
            });
          }
        })
    }
  }

  // Top 进程行
  @Builder processRow(p: TopProcess) {
    Row() {
      Text(`${p.pid}`)
        .fontSize(11)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontMono)
        .width(60)
      Text(p.name)
        .fontSize(12)
        .fontColor(this.palette.textPrimary)
        .layoutWeight(1)
      Text(`${p.cpu.toFixed(1)}%`)
        .fontSize(11)
        .fontColor(this.palette.primary)
        .fontFamily(this.palette.fontMono)
        .width(70)
      Text(`${p.mem.toFixed(1)}%`)
        .fontSize(11)
        .fontColor(this.palette.info)
        .fontFamily(this.palette.fontMono)
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
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(a.detail)
          .fontSize(10)
          .fontColor(this.palette.textSecondary)
        Text(`${a.source} · ${a.time}`)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontMono)
      }
      .layoutWeight(1)
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(8)
    .backgroundColor(this.palette.bgSurface2)
  }

  build() {
    Column() {
      Stack() {
        GlobalBackgroundLayer()
        Row() {
        Column() {
        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.palette.primary)
            Text('加载中...')
              .fontSize(12)
              .fontColor(this.palette.textTertiary)
              .margin({ top: 12 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.server) {
          TopBar({
            title: this.server.name,
            subtitle: `${this.server.host}:${this.server.port} · ${this.server.os}`,
            showBack: true
          }) {
            this.actionsBuilder()
          }
          Scroll() {
            Column({ space: 16 }) {
              // 头部卡片
              Row({ space: 16 }) {
                Column({ space: 4 }) {
                  Text(this.server.name)
                    .fontSize(this.palette.fs2xl)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Text(this.server.os || '-')
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 8 }) {
                  StatusBadge({ status: this.server.status })
                  Text(`运行 ${formatUptime(this.server.metrics.uptime)}`)
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                  Text(`负载 ${this.server.metrics.load.toFixed(2)}`)
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                    .fontFamily(this.palette.fontMono)
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(16)
              .borderRadius(10)
              .backgroundColor(this.palette.bgSurface)
              .border({ width: 1, color: this.palette.borderSubtle })
              .alignItems(VerticalAlign.Center)

              // 4 指标卡
              Row({ space: 12 }) {
                MetricCard({
                  title: 'CPU',
                  value: String(this.server.metrics.cpu),
                  unit: '%',
                  color: progressColor(this.server.metrics.cpu, this.palette)
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
                  color: this.palette.warning
                }).layoutWeight(1)
                MetricCard({
                  title: '网络',
                  value: String(this.server.metrics.netIn),
                  unit: 'Mbps',
                  color: this.palette.success
                }).layoutWeight(1)
              }
              .width('100%')

              // 资源使用趋势区
              Column({ space: 8 }) {
                Text('最近 24 小时趋势')
                  .fontSize(this.palette.fsMd)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Row() {
                  Text('趋势图占位')
                    .fontSize(12)
                    .fontColor(this.palette.textTertiary)
                }
                .width('100%')
                .height(120)
                .borderRadius(8)
                .backgroundColor(this.palette.bgSurface2)
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // Top 进程
              Column({ space: 8 }) {
                Text('Top 进程')
                  .fontSize(this.palette.fsMd)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Column({ space: 0 }) {
                  // 表头
                  Row() {
                    Text('PID')
                      .fontSize(10)
                      .fontColor(this.palette.textTertiary)
                      .width(60)
                    Text('进程名')
                      .fontSize(10)
                      .fontColor(this.palette.textTertiary)
                      .layoutWeight(1)
                    Text('CPU')
                      .fontSize(10)
                      .fontColor(this.palette.textTertiary)
                      .width(70)
                    Text('内存')
                      .fontSize(10)
                      .fontColor(this.palette.textTertiary)
                      .width(70)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .alignItems(VerticalAlign.Center)

                  if (this.topProcesses.length === 0) {
                    Column({ space: 6 }) {
                      Text('📊')
                        .fontSize(24)
                      Text('暂无进程数据')
                        .fontSize(11)
                        .fontColor(this.palette.textTertiary)
                      Text('连接终端后执行 "top -bn1" 获取')
                        .fontSize(10)
                        .fontColor(this.palette.textTertiary)
                    }
                    .width('100%')
                    .padding({ top: 20, bottom: 20 })
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)
                  } else {
                    ForEach(this.topProcesses, (p: TopProcess) => {
                      this.processRow(p)
                    }, (p: TopProcess) => String(p.pid))
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .borderRadius(10)
                .backgroundColor(this.palette.bgSurface)
                .border({ width: 1, color: this.palette.borderSubtle })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              // 相关告警
              Column({ space: 8 }) {
                Text('相关告警')
                  .fontSize(this.palette.fsMd)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                if (this.alerts.filter(a => a.source.includes(this.server!.name)).length === 0) {
                  EmptyState({ icon: '✅', title: '暂无告警', desc: '该服务器运行正常' })
                } else {
                  ForEach(
                    this.alerts.filter(a => a.source.includes(this.server!.name)),
                    (a: Alert) => { this.alertRow(a) },
                    (a: Alert) => a.id
                  )
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .padding(this.isSm ? 16 : 24)
            .width('100%')
            .padding({ bottom: this.isSm ? 80 : 24 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        } else {
          Column() {
            Text('服务器不存在')
              .fontSize(this.palette.fsMd)
              .fontColor(this.palette.textTertiary)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(Color.Transparent)
      }
      FixedBottomNav({
        selectedKey: MainNavKey.Servers,
        onSelect: (key: MainNavKey): void => { this.selectMain(key); }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

// 智子 - 总览仪表盘页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { MetricCard } from '../components/MetricCard';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { DataRepository } from '../service/DataRepository';
import { Server, PveCluster, Alert, PveNode } from '../model/Models';

@Entry
@Component
struct IndexPage {
  @State activeNav: string = 'Index';
  private stats = DataRepository.getStats();
  private clusters: PveCluster[] = DataRepository.getPveClusters();
  private servers: Server[] = DataRepository.getServers();
  private alerts: Alert[] = DataRepository.getAlerts();

  // 告警级别颜色
  private alertColor(level: string): string {
    if (level === 'critical') return AppTheme.danger;
    if (level === 'warning') return AppTheme.warning;
    return AppTheme.info;
  }

  // 状态点颜色
  private statusDotColor(status: string): string {
    if (status === 'online') return AppTheme.success;
    if (status === 'warning') return AppTheme.warning;
    return AppTheme.textTertiary;
  }

  @Builder actionsBuilder() {
    Button('刷新')
      .fontSize(12)
      .fontColor(AppTheme.textSecondary)
      .backgroundColor(AppTheme.bgSurface2)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        promptAction.showToast({ message: '数据已刷新' });
      })
  }

  // 区块标题行（带跳转链接）
  @Builder sectionTitle(title: string, linkText: string, route: string) {
    Row() {
      Text(title)
        .fontSize(AppTheme.fsLg)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(linkText)
        .fontSize(12)
        .fontColor(AppTheme.primary)
        .onClick(() => {
          router.replaceUrl({ url: `pages/${route}` }).catch(() => {});
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // PVE 集群卡片
  @Builder clusterCard(c: PveCluster) {
    Column({ space: 12 }) {
      // 集群名 + 状态 + 地址
      Row() {
        Text(c.name)
          .fontSize(AppTheme.fsMd)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
        StatusBadge({ status: 'online', size: 'small' })
        Blank()
        Text(`${c.host}:${c.port}`)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 版本
      Text(c.version)
        .fontSize(11)
        .fontColor(AppTheme.textSecondary)
        .fontFamily(AppTheme.fontMono)

      // 三等分小统计：节点数 / VM 数 / CT 数
      Row() {
        Column() {
          Text(`${c.nodes.length}`)
            .fontSize(AppTheme.fsLg)
            .fontColor(AppTheme.primary)
            .fontWeight(FontWeight.Bold)
            .fontFamily(AppTheme.fontMono)
          Text('节点')
            .fontSize(10)
            .fontColor(AppTheme.textTertiary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(`${c.nodes.reduce((s: number, n: PveNode) => s + n.vmCount, 0)}`)
            .fontSize(AppTheme.fsLg)
            .fontColor(AppTheme.info)
            .fontWeight(FontWeight.Bold)
            .fontFamily(AppTheme.fontMono)
          Text('VM')
            .fontSize(10)
            .fontColor(AppTheme.textTertiary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(`${c.nodes.reduce((s: number, n: PveNode) => s + n.ctCount, 0)}`)
            .fontSize(AppTheme.fsLg)
            .fontColor(AppTheme.purple)
            .fontWeight(FontWeight.Bold)
            .fontFamily(AppTheme.fontMono)
          Text('CT')
            .fontSize(10)
            .fontColor(AppTheme.textTertiary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 节点标签行
      Row({ space: 8 }) {
        ForEach(c.nodes, (n: PveNode) => {
          Row({ space: 4 }) {
            Text(n.node)
              .fontSize(10)
              .fontColor(AppTheme.textSecondary)
            Text(`CPU ${(n.cpu * 100).toFixed(0)}%`)
              .fontSize(10)
              .fontColor(AppTheme.primary)
              .fontFamily(AppTheme.fontMono)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .borderRadius(6)
          .backgroundColor(AppTheme.bgSurface2)
        }, (n: PveNode) => n.id)
      }
      .width('100%')
    }
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }

  // 服务器卡片
  @Builder serverCard(s: Server) {
    Row({ space: 12 }) {
      // 左侧：状态点 + 名称 + 标签
      Column() {
        Row({ space: 6 }) {
          Circle({ width: 8, height: 8 }).fill(this.statusDotColor(s.status))
          Text(s.name)
            .fontSize(AppTheme.fsMd)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(VerticalAlign.Center)

        Row({ space: 4 }) {
          ForEach(s.tags, (t: string) => {
            Text(t)
              .fontSize(9)
              .fontColor(AppTheme.textTertiary)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(4)
              .backgroundColor(AppTheme.bgSurface2)
          }, (t: string) => t)
        }
        .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧：CPU / 内存 / 磁盘 3 个进度条
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('CPU')
            .fontSize(9)
            .fontColor(AppTheme.textTertiary)
          ProgressBar({ value: s.metrics.cpu, height: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('内存')
            .fontSize(9)
            .fontColor(AppTheme.textTertiary)
          ProgressBar({ value: s.metrics.mem, height: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text('磁盘')
            .fontSize(9)
            .fontColor(AppTheme.textTertiary)
          ProgressBar({ value: s.metrics.disk, height: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('50%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      router.pushUrl({ url: 'pages/ServerDetail', params: { serverId: s.id } }).catch(() => {});
    })
  }

  // 告警行
  @Builder alertRow(a: Alert) {
    Row() {
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.alertColor(a.level))

      Column({ space: 6 }) {
        Row() {
          Text(a.title)
            .fontSize(13)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(a.time)
            .fontSize(11)
            .fontColor(AppTheme.textTertiary)
            .fontFamily(AppTheme.fontMono)
        }
        .width('100%')

        Text(a.detail)
          .fontSize(11)
          .fontColor(AppTheme.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(a.source)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
      }
      .layoutWeight(1)
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
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
        TopBar({ title: '总览', subtitle: '2026-08-04 09:15' }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            // 顶部 4 统计卡
            Row({ space: 12 }) {
              MetricCard({
                title: 'SSH 服务器',
                value: String(this.stats.total),
                color: AppTheme.primary,
                badgeText: `在线 ${this.stats.online}`
              }).layoutWeight(1)
              MetricCard({
                title: 'PVE 节点',
                value: String(this.stats.pveNodes),
                color: AppTheme.purple,
                sub: `VM ${this.stats.vmTotal} · CT ${this.stats.ctTotal}`
              }).layoutWeight(1)
              MetricCard({
                title: '运行中 VM',
                value: `${this.stats.vmRunning}/${this.stats.vmTotal}`,
                color: AppTheme.info,
                sub: `已停止 ${this.stats.vmStopped}`
              }).layoutWeight(1)
              MetricCard({
                title: '未处理告警',
                value: String(this.stats.alerts),
                color: AppTheme.danger,
                sub: `运行中任务 ${this.stats.runningTasks}`
              }).layoutWeight(1)
            }
            .width('100%')

            // PVE 集群状态
            this.sectionTitle('PVE 集群状态', '管理集群 →', 'Pve')
            ForEach(this.clusters, (c: PveCluster) => {
              this.clusterCard(c)
            }, (c: PveCluster) => c.id)

            // SSH 服务器
            this.sectionTitle('SSH 服务器', '管理 →', 'Servers')
            ForEach(this.servers, (s: Server) => {
              this.serverCard(s)
            }, (s: Server) => s.id)

            // 最近告警
            this.sectionTitle('最近告警', '查看全部 →', 'Alerts')
            ForEach(this.alerts.slice(0, 4), (a: Alert) => {
              this.alertRow(a)
            }, (a: Alert) => a.id)
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

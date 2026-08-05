// 智子 - PVE 集群列表页
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime } from '../service/DataRepository';
import { PveCluster, PveNode, Stats } from '../model/Models';

@Component
export struct PvePage {
  @State clusters: PveCluster[] = DataRepository.getPveClusters();
  @State stats: Stats = DataRepository.getStats();

  // 顶栏操作：添加 PVE 节点主色按钮
  @Builder topActions() {
    Button('添加 PVE 节点')
      .fontSize(12)
      .fontColor(AppTheme.bgBase)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        promptAction.showToast({ message: '添加 PVE 节点功能开发中' });
      })
  }

  // 节点卡片
  @Builder nodeCard(cluster: PveCluster, n: PveNode) {
    Column() {
      // 顶部 2px 紫色装饰条
      Column()
        .width('100%')
        .height(2)
        .backgroundColor(AppTheme.purple)

      Column({ space: 10 }) {
        // 节点名 + 状态
        Row({ space: 6 }) {
          Text(n.node)
            .fontSize(15)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Bold)
          StatusBadge({ status: n.status, badgeSize: 'small' })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // host:port
        Text(`${cluster.host}:${cluster.port}`)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)

        // CPU 进度
        Column({ space: 4 }) {
          Row() {
            Text('CPU').fontSize(10).fontColor(AppTheme.textTertiary).layoutWeight(1)
            Text(`${n.maxcpu} 核`).fontSize(10).fontColor(AppTheme.textSecondary)
          }.width('100%')
          ProgressBar({ value: n.cpu * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 内存进度
        Column({ space: 4 }) {
          Row() {
            Text('内存').fontSize(10).fontColor(AppTheme.textTertiary).layoutWeight(1)
            Text(`${n.mem.toFixed(1)} / ${n.maxmem} GB`).fontSize(10).fontColor(AppTheme.textSecondary)
          }.width('100%')
          ProgressBar({ value: (n.mem / n.maxmem) * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 磁盘进度
        Column({ space: 4 }) {
          Row() {
            Text('磁盘').fontSize(10).fontColor(AppTheme.textTertiary).layoutWeight(1)
            Text(`${n.disk} / ${n.maxdisk} GB`).fontSize(10).fontColor(AppTheme.textSecondary)
          }.width('100%')
          ProgressBar({ value: (n.disk / n.maxdisk) * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 运行时长
        Text(`运行 ${formatUptime(n.uptime)}`)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .width('100%')

        // VM/CT 数量标签
        Row({ space: 6 }) {
          Text(`VM ${n.vmCount}`)
            .fontSize(10)
            .fontColor(AppTheme.info)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('rgba(59, 130, 246, 0.12)')
          Text(`CT ${n.ctCount}`)
            .fontSize(10)
            .fontColor(AppTheme.primary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor(AppTheme.primaryDim)
        }

        // 进入节点按钮
        Button('进入节点')
          .fontSize(11)
          .fontColor(AppTheme.primary)
          .backgroundColor(AppTheme.primaryDim)
          .borderRadius(6)
          .height(28)
          .width('100%')
          .onClick(() => {
            router.pushUrl({ url: 'pages/PveNodeDetail', params: { clusterId: cluster.id, node: n.node } })
              .catch(() => {});
          })
      }
      .padding(12)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .layoutWeight(1)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .clip(true)
  }

  build() {
    Column() {
      TopBar({
        title: 'PVE 集群管理',
        subtitle: `${this.stats.pveNodes} 节点 · ${this.stats.vmTotal} VM · ${this.stats.ctTotal} CT`
      }) {
        this.topActions()
      }

      Scroll() {
        Column({ space: 20 }) {
          // 顶部统计卡
          Row({ space: 12 }) {
            MetricCard({ title: '集群数', value: String(this.clusters.length), color: AppTheme.purple })
            MetricCard({
              title: '节点数',
              value: String(this.stats.pveNodes),
              color: AppTheme.purple,
              badgeText: `在线 ${this.stats.pveNodes}`
            })
            MetricCard({
              title: 'VM 总数',
              value: String(this.stats.vmTotal),
              color: AppTheme.info,
              sub: `运行 ${this.stats.vmRunning}`
            })
            MetricCard({ title: 'CT 总数', value: String(this.stats.ctTotal), color: AppTheme.primary })
          }
          .width('100%')

          // 集群分组展示
          if (this.clusters.length === 0) {
            EmptyState({ icon: '🖥️', title: '暂无 PVE 集群', desc: '点击右上角"添加 PVE 节点"开始' })
          } else {
            ForEach(this.clusters, (cluster: PveCluster) => {
            Column({ space: 12 }) {
              // 集群标题行
              Row() {
                Row({ space: 8 }) {
                  Text(cluster.name)
                    .fontSize(16)
                    .fontColor(AppTheme.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  StatusBadge({ status: 'online', badgeSize: 'small' })
                  Text(`${cluster.host}:${cluster.port}`)
                    .fontSize(10)
                    .fontColor(AppTheme.textTertiary)
                    .fontFamily(AppTheme.fontMono)
                  Text(cluster.version)
                    .fontSize(10)
                    .fontColor(AppTheme.textTertiary)
                  Text(`最后同步 ${cluster.lastSync}`)
                    .fontSize(10)
                    .fontColor(AppTheme.textTertiary)
                }
                .layoutWeight(1)
                .alignItems(VerticalAlign.Center)

                // 右侧操作按钮
                Row({ space: 8 }) {
                  Button('刷新')
                    .fontSize(12)
                    .fontColor(AppTheme.textSecondary)
                    .backgroundColor(AppTheme.bgSurface2)
                    .borderRadius(6)
                    .height(28)
                    .padding({ left: 10, right: 10 })
                    .onClick(() => {
                      this.clusters = DataRepository.getPveClusters();
                      this.stats = DataRepository.getStats();
                      promptAction.showToast({ message: '集群数据已刷新' });
                    })
                  Button('任务中心')
                    .fontSize(12)
                    .fontColor(AppTheme.textSecondary)
                    .backgroundColor(AppTheme.bgSurface2)
                    .borderRadius(6)
                    .height(28)
                    .padding({ left: 10, right: 10 })
                    .onClick(() => {
                      router.pushUrl({ url: 'pages/Alerts' }).catch(() => {});
                    })
                  Button('设置')
                    .fontSize(12)
                    .fontColor(AppTheme.textSecondary)
                    .backgroundColor(AppTheme.bgSurface2)
                    .borderRadius(6)
                    .height(28)
                    .padding({ left: 10, right: 10 })
                    .onClick(() => {
                      router.pushUrl({ url: 'pages/Settings' }).catch(() => {});
                    })
                }
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              // 节点卡片（3 列均分）
              Row({ space: 12 }) {
                ForEach(cluster.nodes, (n: PveNode) => {
                  this.nodeCard(cluster, n)
                }, (n: PveNode) => n.id)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(10)
            .backgroundColor(AppTheme.bgSurface)
            .border({ width: 1, color: AppTheme.borderSubtle })
          }, (cluster: PveCluster) => cluster.id)
          }
        }
        .padding(24)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

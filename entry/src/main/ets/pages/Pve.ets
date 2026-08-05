// 智子 - PVE 集群列表页
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime } from '../service/DataRepository';
import { PveService } from '../service/PveService';
import { PveCluster, PveNode, Stats } from '../model/Models';

@Component
export struct PvePage {
  @State clusters: PveCluster[] = [];
  @State stats: Stats = { total: 0, online: 0, warning: 0, offline: 0, alerts: 0, pveNodes: 0, vmTotal: 0, vmRunning: 0, vmStopped: 0, ctTotal: 0, runningTasks: 0 };
  @StorageLink('isSm') isSm: boolean = false;
  @State loading: boolean = true;
  @State showAddDialog: boolean = false;
  // 添加集群表单字段
  @State addClusterName: string = '';
  @State addClusterHost: string = '';
  @State addClusterPort: string = '8006';
  @State addClusterUsername: string = 'root@pam';
  @State addClusterPassword: string = '';

  aboutToAppear() {
    this.loadClusters();
  }

  async loadClusters() {
    this.loading = true;
    try {
      this.clusters = await PveService.getClusters();
      this.stats = await DataRepository.getStats();
    } catch (e) {
      promptAction.showToast({ message: '加载集群数据失败' });
    } finally {
      this.loading = false;
    }
  }

  resetAddForm() {
    this.addClusterName = '';
    this.addClusterHost = '';
    this.addClusterPort = '8006';
    this.addClusterUsername = 'root@pam';
    this.addClusterPassword = '';
  }

  handleAddCluster() {
    if (!this.addClusterName || !this.addClusterHost) {
      promptAction.showToast({ message: '请填写集群名称和主机地址' });
      return;
    }
    promptAction.showToast({ message: `集群 ${this.addClusterName} 添加成功` });
    this.showAddDialog = false;
    this.resetAddForm();
    this.loadClusters();
  }

  // 顶栏操作：添加集群按钮
  @Builder topActions() {
    Button('添加集群')
      .fontSize(12)
      .fontColor(AppTheme.bgBase)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.showAddDialog = true;
      })
  }

  // 添加集群对话框
  @Builder addClusterDialog() {
    Column() {
      Text('添加 PVE 集群')
        .fontSize(18)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 16 })

      Column({ space: 4 }) {
        Text('集群名称').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
        TextInput({ text: this.addClusterName, placeholder: '例如: homelab-cluster' })
          .onChange((value: string) => { this.addClusterName = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('主机地址').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
        TextInput({ text: this.addClusterHost, placeholder: '例如: 192.168.1.10' })
          .onChange((value: string) => { this.addClusterHost = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('端口').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
        TextInput({ text: this.addClusterPort, placeholder: '8006' })
          .onChange((value: string) => { this.addClusterPort = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .type(InputType.Number)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('用户名').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
        TextInput({ text: this.addClusterUsername, placeholder: 'root@pam' })
          .onChange((value: string) => { this.addClusterUsername = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('密码').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
        TextInput({ text: this.addClusterPassword, placeholder: '输入 PVE 密码' })
          .onChange((value: string) => { this.addClusterPassword = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .type(InputType.Password)
      }
      .width('100%')
      .margin({ bottom: 20 })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor(AppTheme.textSecondary)
          .backgroundColor(AppTheme.bgSurface2)
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.showAddDialog = false;
            this.resetAddForm();
          })
        Button('添加')
          .fontSize(14)
          .fontColor(AppTheme.bgBase)
          .backgroundColor(AppTheme.primary)
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.handleAddCluster();
          })
      }
      .width('100%')
    }
    .padding(20)
    .width('100%')
  }

  // 加载指示器
  @Builder loadingIndicator() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(AppTheme.primary)
      Text('正在加载集群数据...')
        .fontSize(14)
        .fontColor(AppTheme.textTertiary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
    Stack() {
      Column() {
        TopBar({
          title: 'PVE 集群管理',
          subtitle: `${this.stats.pveNodes} 节点 · ${this.stats.vmTotal} VM · ${this.stats.ctTotal} CT`
        }) {
          this.topActions()
        }

        if (this.loading && this.clusters.length === 0) {
          // 首次加载中
          this.loadingIndicator()
        } else {
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
                EmptyState({ icon: '🖥️', title: '暂无 PVE 集群', desc: '点击右上角"添加集群"开始' })
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
                          this.loadClusters();
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
            .padding(this.isSm ? 16 : 24)
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        }
      }
      .height('100%')
      .backgroundColor(AppTheme.bgBase)

      // 添加集群对话框遮罩
      if (this.showAddDialog) {
        Column() {
          Column() {
            Text('添加 PVE 集群')
              .fontSize(18)
              .fontColor(AppTheme.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .margin({ bottom: 12 })

            Scroll() {
              Column({ space: 10 }) {
                Column({ space: 4 }) {
                  Text('集群名称').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
                  TextInput({ text: this.addClusterName, placeholder: '例如: homelab-cluster' })
                    .onChange((value: string) => { this.addClusterName = value; })
                    .fontSize(14)
                    .height(36)
                    .borderRadius(8)
                    .backgroundColor(AppTheme.bgSurface2)
                    .fontColor(AppTheme.textPrimary)
                }
                .width('100%')

                Column({ space: 4 }) {
                  Text('主机地址').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
                  TextInput({ text: this.addClusterHost, placeholder: '例如: 192.168.1.10' })
                    .onChange((value: string) => { this.addClusterHost = value; })
                    .fontSize(14)
                    .height(36)
                    .borderRadius(8)
                    .backgroundColor(AppTheme.bgSurface2)
                    .fontColor(AppTheme.textPrimary)
                }
                .width('100%')

                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text('端口').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
                    TextInput({ text: this.addClusterPort, placeholder: '8006' })
                      .onChange((value: string) => { this.addClusterPort = value; })
                      .fontSize(14)
                      .height(36)
                      .borderRadius(8)
                      .backgroundColor(AppTheme.bgSurface2)
                      .fontColor(AppTheme.textPrimary)
                      .type(InputType.Number)
                  }
                  .layoutWeight(1)

                  Column({ space: 4 }) {
                    Text('用户名').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
                    TextInput({ text: this.addClusterUsername, placeholder: 'root@pam' })
                      .onChange((value: string) => { this.addClusterUsername = value; })
                      .fontSize(14)
                      .height(36)
                      .borderRadius(8)
                      .backgroundColor(AppTheme.bgSurface2)
                      .fontColor(AppTheme.textPrimary)
                  }
                  .layoutWeight(1)
                }
                .width('100%')

                Column({ space: 4 }) {
                  Text('密码').fontSize(12).fontColor(AppTheme.textSecondary).width('100%')
                  TextInput({ text: this.addClusterPassword, placeholder: '输入 PVE 密码' })
                    .onChange((value: string) => { this.addClusterPassword = value; })
                    .fontSize(14)
                    .height(36)
                    .borderRadius(8)
                    .backgroundColor(AppTheme.bgSurface2)
                    .fontColor(AppTheme.textPrimary)
                    .type(InputType.Password)
                }
                .width('100%')
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)

            Row({ space: 12 }) {
              Button('取消')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .backgroundColor(AppTheme.bgSurface2)
                .borderRadius(8)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showAddDialog = false;
                  this.resetAddForm();
                })
              Button('添加')
                .fontSize(14)
                .fontColor(AppTheme.bgBase)
                .backgroundColor(AppTheme.primary)
                .borderRadius(8)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.handleAddCluster();
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .padding(20)
          .width(this.isSm ? '88%' : '80%')
          .constraintSize({ maxWidth: 420, maxHeight: '85%' })
          .backgroundColor(AppTheme.bgSurface)
          .borderRadius(12)
          .shadow({ radius: 20, color: '#00000030', offsetY: 4 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showAddDialog = false;
          this.resetAddForm();
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            event.stopPropagation();
          }
        })
      }
    }
    .height('100%')
  }
}
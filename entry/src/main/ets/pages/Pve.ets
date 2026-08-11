// 智子 - PVE 集群列表页
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime } from '../service/DataRepository';
import { PveService } from '../service/PveService';
import { PveCluster, PveNode, Stats } from '../model/Models';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationFacade,
  NavigationSource } from '../common/Navigation';
import { RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from '../service/RemoteResultAdapter';

@Component
export struct PvePage {
  @State clusters: PveCluster[] = [];
  @State stats: Stats = { total: 0, online: 0, warning: 0, offline: 0, alerts: 0, pveNodes: 0, vmTotal: 0, vmRunning: 0, vmStopped: 0, ctTotal: 0, runningTasks: 0 };
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
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

  aboutToDisappear(): void {
    // 集群同步为单次请求，无持久资源需要释放
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

  private async refreshCluster(cluster: PveCluster): Promise<void> {
    const result: RemoteResult<PveCluster> = await PveService.syncCluster(cluster);
    if (!result.success || result.value === null) {
      RemoteResultAdapter.logFailure('pve-cluster-sync', result);
      promptAction.showToast({ message: RemoteResultAdapter.publicMessage(result) });
      return;
    }
    const refreshed: PveCluster = result.value;
    this.clusters = this.clusters.map((item: PveCluster) => item.id === cluster.id ? refreshed : item);
    promptAction.showToast({ message: '集群数据已刷新' });
  }

  private showNavigationFailure(result: NavigationResult, message: string): void {
    if (!result.success) promptAction.showToast({ message: message });
  }

  private openEmbeddedPage(target: PageKey): void {
    const previous: NavigationState = new NavigationState(PageKey.Pve, MainNavKey.Pve);
    NavigationFacade.openPage(previous, target, NavigationSource.ENTRY, false).then((result: NavigationResult) => {
      this.showNavigationFailure(result, '页面打开失败，请重试或返回');
    });
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
      .fontColor(this.palette.bgBase)
      .backgroundColor(this.palette.primary)
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
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 16 })

      Column({ space: 4 }) {
        Text('集群名称').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
        TextInput({ text: this.addClusterName, placeholder: '例如: homelab-cluster' })
          .onChange((value: string) => { this.addClusterName = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('主机地址').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
        TextInput({ text: this.addClusterHost, placeholder: '例如: 192.168.1.10' })
          .onChange((value: string) => { this.addClusterHost = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('端口').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
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
        Text('用户名').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
        TextInput({ text: this.addClusterUsername, placeholder: 'root@pam' })
          .onChange((value: string) => { this.addClusterUsername = value; })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column({ space: 4 }) {
        Text('密码').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
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
          .fontColor(this.palette.textSecondary)
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(8)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.showAddDialog = false;
            this.resetAddForm();
          })
        Button('添加')
          .fontSize(14)
          .fontColor(this.palette.bgBase)
          .backgroundColor(this.palette.primary)
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
        .color(this.palette.primary)
      Text('正在加载集群数据...')
        .fontSize(14)
        .fontColor(this.palette.textTertiary)
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
        .backgroundColor(this.palette.purple)

      Column({ space: 10 }) {
        // 节点名 + 状态
        Row({ space: 6 }) {
          Text(n.node)
            .fontSize(15)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          StatusBadge({ status: n.status, badgeSize: 'small' })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // host:port
        Text(`${cluster.host}:${cluster.port}`)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontMono)

        // CPU 进度
        Column({ space: 4 }) {
          Row() {
            Text('CPU').fontSize(10).fontColor(this.palette.textTertiary).layoutWeight(1)
            Text(`${n.maxcpu} 核`).fontSize(10).fontColor(this.palette.textSecondary)
          }.width('100%')
          ProgressBar({ value: n.cpu * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 内存进度
        Column({ space: 4 }) {
          Row() {
            Text('内存').fontSize(10).fontColor(this.palette.textTertiary).layoutWeight(1)
            Text(`${n.mem.toFixed(1)} / ${n.maxmem} GB`).fontSize(10).fontColor(this.palette.textSecondary)
          }.width('100%')
          ProgressBar({ value: (n.mem / n.maxmem) * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 磁盘进度
        Column({ space: 4 }) {
          Row() {
            Text('磁盘').fontSize(10).fontColor(this.palette.textTertiary).layoutWeight(1)
            Text(`${n.disk} / ${n.maxdisk} GB`).fontSize(10).fontColor(this.palette.textSecondary)
          }.width('100%')
          ProgressBar({ value: (n.disk / n.maxdisk) * 100, showLabel: true, barHeight: 4 })
        }.width('100%')

        // 运行时长
        Text(`运行 ${formatUptime(n.uptime)}`)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .width('100%')

        // VM/CT 数量标签
        Row({ space: 6 }) {
          Text(`VM ${n.vmCount}`)
            .fontSize(10)
            .fontColor(this.palette.info)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('rgba(59, 130, 246, 0.12)')
          Text(`CT ${n.ctCount}`)
            .fontSize(10)
            .fontColor(this.palette.primary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor(this.palette.primaryDim)
        }

        // 进入节点按钮
        Button('进入节点')
          .fontSize(11)
          .fontColor(this.palette.primary)
          .backgroundColor(this.palette.primaryDim)
          .borderRadius(6)
          .height(28)
          .width('100%')
          .onClick(() => {
            const previous: NavigationState = new NavigationState(PageKey.Pve, MainNavKey.Pve);
            NavigationFacade.openPveNodeDetail(previous, cluster.id, n.node).then((result: NavigationResult) => {
              this.showNavigationFailure(result, '节点详情打开失败，请重试或返回');
            });
          })
      }
      .padding(12)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .layoutWeight(1)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
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
                MetricCard({ title: '集群数', value: String(this.clusters.length), color: this.palette.purple })
                MetricCard({
                  title: '节点数',
                  value: String(this.stats.pveNodes),
                  color: this.palette.purple,
                  badgeText: `在线 ${this.stats.pveNodes}`
                })
                MetricCard({
                  title: 'VM 总数',
                  value: String(this.stats.vmTotal),
                  color: this.palette.info,
                  sub: `运行 ${this.stats.vmRunning}`
                })
                MetricCard({ title: 'CT 总数', value: String(this.stats.ctTotal), color: this.palette.primary })
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
                        .fontColor(this.palette.textPrimary)
                        .fontWeight(FontWeight.Bold)
                      StatusBadge({ status: 'online', badgeSize: 'small' })
                      Text(`${cluster.host}:${cluster.port}`)
                        .fontSize(10)
                        .fontColor(this.palette.textTertiary)
                        .fontFamily(this.palette.fontMono)
                      Text(cluster.version)
                        .fontSize(10)
                        .fontColor(this.palette.textTertiary)
                      Text(`最后同步 ${cluster.lastSync}`)
                        .fontSize(10)
                        .fontColor(this.palette.textTertiary)
                    }
                    .layoutWeight(1)
                    .alignItems(VerticalAlign.Center)

                    // 右侧操作按钮
                    Row({ space: 8 }) {
                      Button('刷新')
                        .fontSize(12)
                        .fontColor(this.palette.textSecondary)
                        .backgroundColor(this.palette.bgSurface2)
                        .borderRadius(6)
                        .height(28)
                        .padding({ left: 10, right: 10 })
                        .onClick(() => {
                          this.refreshCluster(cluster);
                        })
                      Button('任务中心')
                        .fontSize(12)
                        .fontColor(this.palette.textSecondary)
                        .backgroundColor(this.palette.bgSurface2)
                        .borderRadius(6)
                        .height(28)
                        .padding({ left: 10, right: 10 })
                        .onClick(() => {
                          this.openEmbeddedPage(PageKey.Alerts);
                        })
                      Button('设置')
                        .fontSize(12)
                        .fontColor(this.palette.textSecondary)
                        .backgroundColor(this.palette.bgSurface2)
                        .borderRadius(6)
                        .height(28)
                        .padding({ left: 10, right: 10 })
                        .onClick(() => {
                          this.openEmbeddedPage(PageKey.Settings);
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
                .backgroundColor(this.palette.bgSurface)
                .border({ width: 1, color: this.palette.borderSubtle })
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
      .backgroundColor(this.palette.bgBase)

      // 添加集群对话框遮罩
      if (this.showAddDialog) {
        Column() {
          Column({ space: 0 }) {
            Text('添加 PVE 集群')
              .fontSize(18)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .margin({ bottom: 12 })

            Column({ space: 10 }) {
              Column({ space: 4 }) {
                Text('集群名称').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
                TextInput({ text: this.addClusterName, placeholder: '例如: homelab-cluster' })
                  .onChange((value: string) => { this.addClusterName = value; })
                  .fontSize(14)
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor(this.palette.bgSurface2)
                  .fontColor(this.palette.textPrimary)
              }
              .width('100%')

              Column({ space: 4 }) {
                Text('主机地址').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
                TextInput({ text: this.addClusterHost, placeholder: '例如: 192.168.1.10' })
                  .onChange((value: string) => { this.addClusterHost = value; })
                  .fontSize(14)
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor(this.palette.bgSurface2)
                  .fontColor(this.palette.textPrimary)
              }
              .width('100%')

              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text('端口').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
                  TextInput({ text: this.addClusterPort, placeholder: '8006' })
                    .onChange((value: string) => { this.addClusterPort = value; })
                    .fontSize(14)
                    .height(40)
                    .borderRadius(8)
                    .backgroundColor(this.palette.bgSurface2)
                    .fontColor(this.palette.textPrimary)
                    .type(InputType.Number)
                }
                .layoutWeight(1)

                Column({ space: 4 }) {
                  Text('用户名').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
                  TextInput({ text: this.addClusterUsername, placeholder: 'root@pam' })
                    .onChange((value: string) => { this.addClusterUsername = value; })
                    .fontSize(14)
                    .height(40)
                    .borderRadius(8)
                    .backgroundColor(this.palette.bgSurface2)
                    .fontColor(this.palette.textPrimary)
                }
                .layoutWeight(1)
              }
              .width('100%')

              Column({ space: 4 }) {
                Text('密码').fontSize(12).fontColor(this.palette.textSecondary).width('100%')
                TextInput({ text: this.addClusterPassword, placeholder: '输入 PVE 密码' })
                  .onChange((value: string) => { this.addClusterPassword = value; })
                  .fontSize(14)
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor(this.palette.bgSurface2)
                  .fontColor(this.palette.textPrimary)
                  .type(InputType.Password)
              }
              .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })

            Row({ space: 12 }) {
              Button('取消')
                .fontSize(14)
                .fontColor(this.palette.textSecondary)
                .backgroundColor(this.palette.bgSurface2)
                .borderRadius(8)
                .height(40)
                .layoutWeight(1)
                .onClick(() => {
                  this.showAddDialog = false;
                  this.resetAddForm();
                })
              Button('添加')
                .fontSize(14)
                .fontColor(this.palette.bgBase)
                .backgroundColor(this.palette.primary)
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
          .width(this.isSm ? '88%' : '80%')
          .constraintSize({ maxWidth: 420 })
          .backgroundColor(this.palette.bgSurface)
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

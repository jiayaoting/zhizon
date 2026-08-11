// 智子 - PVE 节点详情页
import { router, promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette, progressColor } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime, formatSize } from '../service/DataRepository';
import { PveCluster, PveNode, Vm, Storage, PveTask } from '../model/Models';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationFacade, NavigationSource,
  PveNodeDetailParameterResult, PveNodeDetailRouteParams, mainPage } from '../common/Navigation';
import { RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from '../service/RemoteResultAdapter';

@Entry
@Component
struct PveNodeDetailPage {
  @State activeTab: string = 'vm'; // vm | storage | task | system
  @State vmFilter: string = 'all'; // all | running | stopped | qemu | lxc
  @State vmSearch: string = '';
  @State clusterId: string = '';
  @State nodeName: string = '';
  @State cluster: PveCluster | undefined = undefined;
  @State pveNode: PveNode | undefined = undefined;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @State loading: boolean = true;
  @State vms: Vm[] = [];
  @State storages: Storage[] = [];
  @State tasks: PveTask[] = [];

  async aboutToAppear() {
    const params: PveNodeDetailRouteParams | null = router.getParams() as PveNodeDetailRouteParams | null;
    const parsed: PveNodeDetailParameterResult = NavigationFacade.pveNodeDetailParameters(params);
    if (!parsed.valid || parsed.value === null) {
      this.loading = false;
      promptAction.showToast({ message: '节点参数无效，已返回上一页' });
      router.back();
      return;
    }
    const detailParams: PveNodeDetailRouteParams = parsed.value;
    this.clusterId = detailParams.clusterId;
    this.nodeName = detailParams.node;
    const c: PveCluster | undefined = await DataRepository.getPveCluster(this.clusterId);
    this.cluster = c;
    if (c) {
      this.pveNode = c.nodes.find(n => n.node === this.nodeName);
      if (this.pveNode) {
        await this.loadRemoteData(c, this.pveNode.node, false);
      }
    }
    this.loading = false;
  }

  aboutToDisappear(): void {
    // 节点数据为单次拉取，无持久资源需要释放
  }

  private async loadRemoteData(cluster: PveCluster, node: string, notifySuccess: boolean): Promise<void> {
    const vms: RemoteResult<Vm[]> = await DataRepository.getVms(cluster, node);
    const storages: RemoteResult<Storage[]> = await DataRepository.getStorages(cluster, node);
    const tasks: RemoteResult<PveTask[]> = await DataRepository.getTasks(cluster, node);
    if (vms.success && vms.value !== null && storages.success && storages.value !== null &&
      tasks.success && tasks.value !== null) {
      this.vms = vms.value;
      this.storages = storages.value;
      this.tasks = tasks.value;
      if (notifySuccess) promptAction.showToast({ message: '已刷新节点数据' });
      return;
    }
    if (!vms.success) {
      RemoteResultAdapter.logFailure('pve-node-load', vms);
      promptAction.showToast({ message: RemoteResultAdapter.publicMessage(vms) });
    } else if (!storages.success) {
      RemoteResultAdapter.logFailure('pve-node-load', storages);
      promptAction.showToast({ message: RemoteResultAdapter.publicMessage(storages) });
    } else {
      RemoteResultAdapter.logFailure('pve-node-load', tasks);
      promptAction.showToast({ message: RemoteResultAdapter.publicMessage(tasks) });
    }
  }

  // 过滤后的 VM 列表
  getFilteredVms(): Vm[] {
    let vms = this.vms;
    if (this.vmFilter === 'running') vms = vms.filter(v => v.status === 'running');
    else if (this.vmFilter === 'stopped') vms = vms.filter(v => v.status === 'stopped');
    else if (this.vmFilter === 'qemu') vms = vms.filter(v => v.type === 'qemu');
    else if (this.vmFilter === 'lxc') vms = vms.filter(v => v.type === 'lxc');
    if (this.vmSearch) {
      vms = vms.filter(v => v.name.includes(this.vmSearch) || String(v.vmid).includes(this.vmSearch));
    }
    return vms;
  }

  private selectMain(key: MainNavKey): void {
    const previous: NavigationState = new NavigationState(PageKey.PveNodeDetail, MainNavKey.Pve);
    NavigationFacade.openPage(previous, mainPage(key), NavigationSource.MAIN_NAV, true).then((result: NavigationResult) => {
      if (!result.success) promptAction.showToast({ message: '页面打开失败，请重试或返回' });
    });
  }

  // 顶栏操作：刷新 + SSH 连接
  @Builder topActions() {
    Row({ space: 8 }) {
      Button('刷新')
        .fontSize(12)
        .fontColor(this.palette.textSecondary)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(async () => {
          const c: PveCluster | undefined = await DataRepository.getPveCluster(this.clusterId);
          this.cluster = c;
          this.pveNode = c?.nodes.find(n => n.node === this.nodeName) || undefined;
          if (c && this.pveNode) {
            await this.loadRemoteData(c, this.pveNode.node, true);
          }
        })
      Button('SSH 连接')
        .fontSize(12)
        .fontColor(this.palette.primary)
        .backgroundColor(this.palette.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          const previous: NavigationState = new NavigationState(PageKey.PveNodeDetail, MainNavKey.Pve);
          NavigationFacade.openTerminal(previous, '', this.nodeName).then((result: NavigationResult) => {
            if (!result.success) promptAction.showToast({ message: '终端打开失败，请重试或返回' });
          });
        })
    }
  }

  // Tab 项
  @Builder tabItem(key: string, label: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.activeTab === key ? this.palette.primary : this.palette.textSecondary)
        .fontWeight(this.activeTab === key ? FontWeight.Medium : FontWeight.Regular)
      Column()
        .width('100%')
        .height(2)
        .backgroundColor(this.activeTab === key ? this.palette.primary : Color.Transparent)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 0 })
    .onClick(() => { this.activeTab = key; })
  }

  // 过滤标签
  @Builder filterTag(key: string, label: string) {
    Text(label)
      .fontSize(11)
      .fontColor(this.vmFilter === key ? this.palette.bgBase : this.palette.textSecondary)
      .backgroundColor(this.vmFilter === key ? this.palette.primary : this.palette.bgSurface2)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(6)
      .onClick(() => { this.vmFilter = key; })
  }

  // VM 操作按钮
  @Builder vmActionBtn(text: string, color: string, v: Vm) {
    Button(text)
      .fontSize(11)
      .fontColor(color)
      .backgroundColor(this.palette.bgSurface2)
      .borderRadius(5)
      .height(24)
      .padding({ left: 8, right: 8 })
      .onClick(() => {
        promptAction.showToast({ message: `${text} ${v.name} (vmid: ${v.vmid})` });
      })
  }

  // VM 行
  @Builder vmRow(v: Vm) {
    Column({ space: 8 }) {
      // 第一行：VMID + 图标+名称 + 状态 + 操作按钮
      Row() {
        Text(`#${v.vmid}`)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontMono)

        Row({ space: 6 }) {
          Stack() {
            Text(v.type === 'qemu' ? 'Q' : 'L')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width(22)
          .height(22)
          .borderRadius(5)
          .backgroundColor(v.type === 'qemu' ? this.palette.purple : this.palette.primary)
          Text(v.name)
            .fontSize(13)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        StatusBadge({ status: v.status, badgeSize: 'small' })

        // 操作按钮
        Row({ space: 6 }) {
          if (v.status === 'stopped') {
            this.vmActionBtn('启动', this.palette.success, v)
          } else if (v.status === 'running') {
            this.vmActionBtn('停止', this.palette.danger, v)
            this.vmActionBtn('重启', this.palette.warning, v)
            Button('控制台')
              .fontSize(11)
              .fontColor(this.palette.primary)
              .backgroundColor(this.palette.primaryDim)
              .borderRadius(5)
              .height(24)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                promptAction.showToast({ message: `${v.name} 控制台功能开发中` });
              })
          } else if (v.status === 'paused') {
            this.vmActionBtn('恢复', this.palette.success, v)
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        const previous: NavigationState = new NavigationState(PageKey.PveNodeDetail, MainNavKey.Pve);
        NavigationFacade.openVmDetail(previous, this.clusterId, this.nodeName, v.vmid).then((result: NavigationResult) => {
          if (!result.success) promptAction.showToast({ message: '虚拟机详情打开失败，请重试或返回' });
        });
      })

      // 第二行：资源信息
      Row({ space: 16 }) {
        Text(`CPU ${(v.cpu * 100).toFixed(0)}%`).fontSize(10).fontColor(this.palette.textTertiary)
        Text(`内存 ${v.mem.toFixed(1)}/${v.maxmem} GB`).fontSize(10).fontColor(this.palette.textTertiary)
        Text(`磁盘 ${formatSize(v.maxdisk)}`).fontSize(10).fontColor(this.palette.textTertiary)
        Text(`网络 ${v.netin}/${v.netout} Mbps`).fontSize(10).fontColor(this.palette.textTertiary)
        Text(`运行 ${formatUptime(v.uptime)}`).fontSize(10).fontColor(this.palette.textTertiary)
      }
      .width('100%')
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  // 存储类型徽章背景
  storageBadgeColor(type: string): string {
    if (type === 'dir') return 'rgba(100, 116, 139, 0.15)';
    if (type === 'lvmthin') return 'rgba(59, 130, 246, 0.15)';
    if (type === 'zfs') return 'rgba(139, 92, 246, 0.15)';
    return 'rgba(245, 158, 11, 0.15)';
  }
  storageBadgeText(type: string): string {
    if (type === 'dir') return this.palette.textSecondary;
    if (type === 'lvmthin') return this.palette.info;
    if (type === 'zfs') return this.palette.purple;
    return this.palette.warning;
  }

  // 存储池行
  @Builder storageRow(s: Storage) {
    Column({ space: 8 }) {
      Row() {
        Text(s.name)
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(s.type)
          .fontSize(10)
          .fontColor(this.storageBadgeText(s.type))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(5)
          .backgroundColor(this.storageBadgeColor(s.type))
        Text(s.content)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .layoutWeight(1)
        StatusBadge({ status: s.status, badgeSize: 'small' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(`${s.used} / ${s.total} GB`).fontSize(10).fontColor(this.palette.textSecondary)
        Text(`${Math.round((s.used / s.total) * 100)}%`).fontSize(10).fontColor(this.palette.textTertiary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      ProgressBar({ value: (s.used / s.total) * 100, showLabel: false, barHeight: 4 })
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  // 任务行
  @Builder taskRow(t: PveTask) {
    Column({ space: 8 }) {
      Row() {
        Text(t.type)
          .fontSize(12)
          .fontColor(this.palette.textPrimary)
          .fontFamily(this.palette.fontMono)
        Text(t.target)
          .fontSize(11)
          .fontColor(this.palette.textSecondary)
          .layoutWeight(1)
        // 状态徽章
        Row({ space: 4 }) {
          if (t.status === 'running') {
            Circle({ width: 6, height: 6 }).fill(this.palette.info)
            Text('执行中').fontSize(10).fontColor(this.palette.info)
          } else if (t.status === 'success') {
            Circle({ width: 6, height: 6 }).fill(this.palette.success)
            Text('成功').fontSize(10).fontColor(this.palette.success)
          } else {
            Circle({ width: 6, height: 6 }).fill(this.palette.danger)
            Text('失败').fontSize(10).fontColor(this.palette.danger)
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 进度条（仅 running）
      if (t.status === 'running') {
        ProgressBar({ value: t.progress, showLabel: true, barHeight: 4 })
      }

      Row({ space: 16 }) {
        Text(t.startTime).fontSize(10).fontColor(this.palette.textTertiary)
        Text(t.user).fontSize(10).fontColor(this.palette.textTertiary)
      }
      .width('100%')

      Text(t.upid)
        .fontSize(9)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontMono)

      // 错误信息
      if (t.status === 'failed' && t.error) {
        Text(t.error)
          .fontSize(10)
          .fontColor(this.palette.danger)
      }
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }

  // 信息行（左右布局）
  @Builder infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(this.palette.textTertiary)
      Blank()
      Text(value).fontSize(12).fontColor(this.palette.textPrimary).fontFamily(this.palette.fontMono)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      Stack() {
        GlobalBackgroundLayer()
        Row() {
        Column() {
        TopBar({
          title: this.pveNode ? this.pveNode.node : '-',
          subtitle: this.cluster ? `${this.cluster.name} · ${this.cluster.host}:${this.cluster.port}` : '',
          showBack: true
        }) {
          this.topActions()
        }

        if (this.loading) {
          Column() {
            LoadingProgress()
              .color(this.palette.primary)
              .width(40)
              .height(40)
            Text('加载中...')
              .fontSize(14)
              .fontColor(this.palette.textSecondary)
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.pveNode && this.cluster) {
          Scroll() {
            Column({ space: 16 }) {
              // 节点头部卡片
              Row({ space: 16 }) {
                Text(this.pveNode.node)
                  .fontSize(20)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                StatusBadge({ status: this.pveNode.status })
                Text(`VM ${this.pveNode.vmCount}`)
                  .fontSize(10)
                  .fontColor(this.palette.info)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .backgroundColor('rgba(59, 130, 246, 0.12)')
                Text(`CT ${this.pveNode.ctCount}`)
                  .fontSize(10)
                  .fontColor(this.palette.primary)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .backgroundColor(this.palette.primaryDim)
                Blank()
                Text(`运行 ${formatUptime(this.pveNode.uptime)}`)
                  .fontSize(11)
                  .fontColor(this.palette.textTertiary)
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
                  value: (this.pveNode.cpu * 100).toFixed(0),
                  unit: '%',
                  color: progressColor(this.pveNode.cpu * 100, this.palette),
                  sub: `${this.pveNode.maxcpu} 核`
                })
                MetricCard({
                  title: '内存',
                  value: this.pveNode.mem.toFixed(1),
                  unit: 'GB',
                  color: this.palette.info,
                  sub: `/ ${this.pveNode.maxmem} GB`
                })
                MetricCard({
                  title: '磁盘',
                  value: this.pveNode.disk.toFixed(0),
                  unit: 'GB',
                  color: this.palette.warning,
                  sub: `/ ${this.pveNode.maxdisk} GB`
                })
                MetricCard({
                  title: '网络',
                  value: 'N/A',
                  color: this.palette.success,
                  sub: '聚合流量'
                })
              }
              .width('100%')

              // Tab 栏
              Row() {
                this.tabItem('vm', '虚拟机')
                this.tabItem('storage', '存储池')
                this.tabItem('task', '任务中心')
                this.tabItem('system', '系统信息')
              }
              .width('100%')
              .border({ width: { bottom: 1 }, color: this.palette.borderSubtle })

              // ===== Tab1 虚拟机 =====
              if (this.activeTab === 'vm') {
                Column({ space: 12 }) {
                  // 工具栏
                  Row({ space: 8 }) {
                    TextInput({ text: this.vmSearch, placeholder: '搜索 VM...' })
                      .fontSize(12)
                      .fontColor(this.palette.textPrimary)
                      .backgroundColor(this.palette.bgSurface2)
                      .borderRadius(6)
                      .height(30)
                      .layoutWeight(1)
                      .onChange((val: string) => { this.vmSearch = val; })
                    Button('创建 VM')
                      .fontSize(12)
                      .fontColor(this.palette.bgBase)
                      .backgroundColor(this.palette.primary)
                      .borderRadius(6)
                      .height(30)
                      .padding({ left: 12, right: 12 })
                  }
                  .width('100%')

                  // 过滤标签
                  Row({ space: 8 }) {
                    this.filterTag('all', '全部')
                    this.filterTag('running', '运行中')
                    this.filterTag('stopped', '已停止')
                    this.filterTag('qemu', 'QEMU')
                    this.filterTag('lxc', 'LXC')
                  }
                  .width('100%')

                  // VM 列表
                  if (this.getFilteredVms().length === 0) {
                    EmptyState({ icon: '🖥️', title: '暂无虚拟机', desc: '该节点下没有匹配的 VM/CT' })
                  } else {
                    ForEach(this.getFilteredVms(), (v: Vm) => {
                      this.vmRow(v)
                    }, (v: Vm) => String(v.vmid))
                  }
                }
                .width('100%')
              }

              // ===== Tab2 存储池 =====
              if (this.activeTab === 'storage') {
                ForEach(this.storages, (s: Storage) => {
                  this.storageRow(s)
                }, (s: Storage) => `${s.name}-${s.node}`)
              }

              // ===== Tab3 任务中心 =====
              if (this.activeTab === 'task') {
                ForEach(
                  this.tasks.filter(t => t.node === this.pveNode!.node),
                  (t: PveTask) => { this.taskRow(t) },
                  (t: PveTask) => t.id
                )
              }

              // ===== Tab4 系统信息 =====
              if (this.activeTab === 'system') {
                Column({ space: 0 }) {
                  this.infoRow('内核版本', 'Linux 6.8.0-12-pve')
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('PVE 版本', this.cluster.version)
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('CPU 型号', 'AMD Ryzen 9 7950X')
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('总内存', `${this.pveNode.maxmem} GB`)
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('总磁盘', `${this.pveNode.maxdisk} GB`)
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('网络接口', 'enp3s0, vmbr0, vmbr1')
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('运行时长', formatUptime(this.pveNode.uptime))
                  Divider().color(this.palette.borderSubtle)
                  this.infoRow('最后同步', this.cluster.lastSync)
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .borderRadius(10)
                .backgroundColor(this.palette.bgSurface)
                .border({ width: 1, color: this.palette.borderSubtle })
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
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(Color.Transparent)
      }
      FixedBottomNav({
        selectedKey: MainNavKey.Pve,
        onSelect: (key: MainNavKey): void => { this.selectMain(key); }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

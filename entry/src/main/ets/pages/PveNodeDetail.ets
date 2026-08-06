// 智子 - PVE 节点详情页
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme, progressColor } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime, formatSize } from '../service/DataRepository';
import { PveCluster, PveNode, Vm, Storage, PveTask } from '../model/Models';

interface NodeDetailParams {
  clusterId: string;
  node: string;
}

@Entry
@Component
struct PveNodeDetailPage {
  @State activeNav: string = 'Pve';
  @State activeTab: string = 'vm'; // vm | storage | task | system
  @State vmFilter: string = 'all'; // all | running | stopped | qemu | lxc
  @State vmSearch: string = '';
  @State clusterId: string = '';
  @State nodeName: string = '';
  @State cluster: PveCluster | undefined = undefined;
  @State pveNode: PveNode | undefined = undefined;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @State loading: boolean = true;
  @State vms: Vm[] = [];
  @State storages: Storage[] = [];
  @State tasks: PveTask[] = [];

  async aboutToAppear() {
    const params = router.getParams() as NodeDetailParams;
    this.clusterId = params.clusterId;
    this.nodeName = params.node;
    const c: PveCluster | undefined = await DataRepository.getPveCluster(this.clusterId);
    this.cluster = c;
    if (c) {
      this.pveNode = c.nodes.find(n => n.node === this.nodeName);
      if (this.pveNode) {
        this.vms = await DataRepository.getVms(c, this.pveNode.node);
        this.storages = await DataRepository.getStorages(c, this.pveNode.node);
        this.tasks = await DataRepository.getTasks(c, this.pveNode.node);
      }
    }
    this.loading = false;
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

  // 顶栏操作：刷新 + SSH 连接
  @Builder topActions() {
    Row({ space: 8 }) {
      Button('刷新')
        .fontSize(12)
        .fontColor(AppTheme.textSecondary)
        .backgroundColor(AppTheme.bgSurface2)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(async () => {
          const c: PveCluster | undefined = await DataRepository.getPveCluster(this.clusterId);
          this.cluster = c;
          this.pveNode = c?.nodes.find(n => n.node === this.nodeName) || undefined;
          if (c && this.pveNode) {
            this.vms = await DataRepository.getVms(c, this.pveNode.node);
            this.storages = await DataRepository.getStorages(c, this.pveNode.node);
            this.tasks = await DataRepository.getTasks(c, this.pveNode.node);
          }
          promptAction.showToast({ message: '已刷新节点数据' });
        })
      Button('SSH 连接')
        .fontSize(12)
        .fontColor(AppTheme.primary)
        .backgroundColor(AppTheme.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/Terminal', params: { serverName: this.nodeName } }).catch(() => {});
        })
    }
  }

  // Tab 项
  @Builder tabItem(key: string, label: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.activeTab === key ? AppTheme.primary : AppTheme.textSecondary)
        .fontWeight(this.activeTab === key ? FontWeight.Medium : FontWeight.Regular)
      Column()
        .width('100%')
        .height(2)
        .backgroundColor(this.activeTab === key ? AppTheme.primary : Color.Transparent)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 0 })
    .onClick(() => { this.activeTab = key; })
  }

  // 过滤标签
  @Builder filterTag(key: string, label: string) {
    Text(label)
      .fontSize(11)
      .fontColor(this.vmFilter === key ? AppTheme.bgBase : AppTheme.textSecondary)
      .backgroundColor(this.vmFilter === key ? AppTheme.primary : AppTheme.bgSurface2)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(6)
      .onClick(() => { this.vmFilter = key; })
  }

  // VM 操作按钮
  @Builder vmActionBtn(text: string, color: string, v: Vm) {
    Button(text)
      .fontSize(11)
      .fontColor(color)
      .backgroundColor(AppTheme.bgSurface2)
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
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)

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
          .backgroundColor(v.type === 'qemu' ? AppTheme.purple : AppTheme.primary)
          Text(v.name)
            .fontSize(13)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        StatusBadge({ status: v.status, badgeSize: 'small' })

        // 操作按钮
        Row({ space: 6 }) {
          if (v.status === 'stopped') {
            this.vmActionBtn('启动', AppTheme.success, v)
          } else if (v.status === 'running') {
            this.vmActionBtn('停止', AppTheme.danger, v)
            this.vmActionBtn('重启', AppTheme.warning, v)
            Button('控制台')
              .fontSize(11)
              .fontColor(AppTheme.primary)
              .backgroundColor(AppTheme.primaryDim)
              .borderRadius(5)
              .height(24)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                promptAction.showToast({ message: `${v.name} 控制台功能开发中` });
              })
          } else if (v.status === 'paused') {
            this.vmActionBtn('恢复', AppTheme.success, v)
          }
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        router.pushUrl({
          url: 'pages/VmDetail',
          params: { clusterId: this.clusterId, node: this.nodeName, vmid: v.vmid }
        }).catch(() => {});
      })

      // 第二行：资源信息
      Row({ space: 16 }) {
        Text(`CPU ${(v.cpu * 100).toFixed(0)}%`).fontSize(10).fontColor(AppTheme.textTertiary)
        Text(`内存 ${v.mem.toFixed(1)}/${v.maxmem} GB`).fontSize(10).fontColor(AppTheme.textTertiary)
        Text(`磁盘 ${formatSize(v.maxdisk)}`).fontSize(10).fontColor(AppTheme.textTertiary)
        Text(`网络 ${v.netin}/${v.netout} Mbps`).fontSize(10).fontColor(AppTheme.textTertiary)
        Text(`运行 ${formatUptime(v.uptime)}`).fontSize(10).fontColor(AppTheme.textTertiary)
      }
      .width('100%')
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
  }

  // 存储类型徽章背景
  storageBadgeColor(type: string): string {
    if (type === 'dir') return 'rgba(100, 116, 139, 0.15)';
    if (type === 'lvmthin') return 'rgba(59, 130, 246, 0.15)';
    if (type === 'zfs') return 'rgba(139, 92, 246, 0.15)';
    return 'rgba(245, 158, 11, 0.15)';
  }
  storageBadgeText(type: string): string {
    if (type === 'dir') return AppTheme.textSecondary;
    if (type === 'lvmthin') return AppTheme.info;
    if (type === 'zfs') return AppTheme.purple;
    return AppTheme.warning;
  }

  // 存储池行
  @Builder storageRow(s: Storage) {
    Column({ space: 8 }) {
      Row() {
        Text(s.name)
          .fontSize(13)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(s.type)
          .fontSize(10)
          .fontColor(this.storageBadgeText(s.type))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(5)
          .backgroundColor(this.storageBadgeColor(s.type))
        Text(s.content)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .layoutWeight(1)
        StatusBadge({ status: s.status, badgeSize: 'small' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(`${s.used} / ${s.total} GB`).fontSize(10).fontColor(AppTheme.textSecondary)
        Text(`${Math.round((s.used / s.total) * 100)}%`).fontSize(10).fontColor(AppTheme.textTertiary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      ProgressBar({ value: (s.used / s.total) * 100, showLabel: false, barHeight: 4 })
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
  }

  // 任务行
  @Builder taskRow(t: PveTask) {
    Column({ space: 8 }) {
      Row() {
        Text(t.type)
          .fontSize(12)
          .fontColor(AppTheme.textPrimary)
          .fontFamily(AppTheme.fontMono)
        Text(t.target)
          .fontSize(11)
          .fontColor(AppTheme.textSecondary)
          .layoutWeight(1)
        // 状态徽章
        Row({ space: 4 }) {
          if (t.status === 'running') {
            Circle({ width: 6, height: 6 }).fill(AppTheme.info)
            Text('执行中').fontSize(10).fontColor(AppTheme.info)
          } else if (t.status === 'success') {
            Circle({ width: 6, height: 6 }).fill(AppTheme.success)
            Text('成功').fontSize(10).fontColor(AppTheme.success)
          } else {
            Circle({ width: 6, height: 6 }).fill(AppTheme.danger)
            Text('失败').fontSize(10).fontColor(AppTheme.danger)
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
        Text(t.startTime).fontSize(10).fontColor(AppTheme.textTertiary)
        Text(t.user).fontSize(10).fontColor(AppTheme.textTertiary)
      }
      .width('100%')

      Text(t.upid)
        .fontSize(9)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)

      // 错误信息
      if (t.status === 'failed' && t.error) {
        Text(t.error)
          .fontSize(10)
          .fontColor(AppTheme.danger)
      }
    }
    .padding(12)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }

  // 信息行（左右布局）
  @Builder infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(AppTheme.textTertiary)
      Blank()
      Text(value).fontSize(12).fontColor(AppTheme.textPrimary).fontFamily(AppTheme.fontMono)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Row() {
      if (!this.isSm) {
        NavSidebar({
          activeKey: this.activeNav,
          onSelect: (key: string) => {
            router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
          }
        })
      }

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
              .color(AppTheme.primary)
              .width(40)
              .height(40)
            Text('加载中...')
              .fontSize(14)
              .fontColor(AppTheme.textSecondary)
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
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                StatusBadge({ status: this.pveNode.status })
                Text(`VM ${this.pveNode.vmCount}`)
                  .fontSize(10)
                  .fontColor(AppTheme.info)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .backgroundColor('rgba(59, 130, 246, 0.12)')
                Text(`CT ${this.pveNode.ctCount}`)
                  .fontSize(10)
                  .fontColor(AppTheme.primary)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .backgroundColor(AppTheme.primaryDim)
                Blank()
                Text(`运行 ${formatUptime(this.pveNode.uptime)}`)
                  .fontSize(11)
                  .fontColor(AppTheme.textTertiary)
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
                  value: (this.pveNode.cpu * 100).toFixed(0),
                  unit: '%',
                  color: progressColor(this.pveNode.cpu * 100),
                  sub: `${this.pveNode.maxcpu} 核`
                })
                MetricCard({
                  title: '内存',
                  value: this.pveNode.mem.toFixed(1),
                  unit: 'GB',
                  color: AppTheme.info,
                  sub: `/ ${this.pveNode.maxmem} GB`
                })
                MetricCard({
                  title: '磁盘',
                  value: this.pveNode.disk.toFixed(0),
                  unit: 'GB',
                  color: AppTheme.warning,
                  sub: `/ ${this.pveNode.maxdisk} GB`
                })
                MetricCard({
                  title: '网络',
                  value: 'N/A',
                  color: AppTheme.success,
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
              .border({ width: { bottom: 1 }, color: AppTheme.borderSubtle })

              // ===== Tab1 虚拟机 =====
              if (this.activeTab === 'vm') {
                Column({ space: 12 }) {
                  // 工具栏
                  Row({ space: 8 }) {
                    TextInput({ text: this.vmSearch, placeholder: '搜索 VM...' })
                      .fontSize(12)
                      .fontColor(AppTheme.textPrimary)
                      .backgroundColor(AppTheme.bgSurface2)
                      .borderRadius(6)
                      .height(30)
                      .layoutWeight(1)
                      .onChange((val: string) => { this.vmSearch = val; })
                    Button('创建 VM')
                      .fontSize(12)
                      .fontColor(AppTheme.bgBase)
                      .backgroundColor(AppTheme.primary)
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
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('PVE 版本', this.cluster.version)
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('CPU 型号', 'AMD Ryzen 9 7950X')
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('总内存', `${this.pveNode.maxmem} GB`)
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('总磁盘', `${this.pveNode.maxdisk} GB`)
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('网络接口', 'enp3s0, vmbr0, vmbr1')
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('运行时长', formatUptime(this.pveNode.uptime))
                  Divider().color(AppTheme.borderSubtle)
                  this.infoRow('最后同步', this.cluster.lastSync)
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .borderRadius(10)
                .backgroundColor(AppTheme.bgSurface)
                .border({ width: 1, color: AppTheme.borderSubtle })
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
      .backgroundColor(AppTheme.bgBase)
    }
    .height('100%')
    .padding({ bottom: this.navBarHeight })
    .backgroundColor(AppTheme.bgBase)
  }
}
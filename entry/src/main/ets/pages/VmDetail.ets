// 智子 - 虚拟机详情页
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme, progressColor } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { DataRepository, formatUptime, formatSize } from '../service/DataRepository';
import { Vm, PveTask, Snapshot, PveCluster } from '../model/Models';

interface VmDetailParams {
  clusterId: string;
  node: string;
  vmid: number;
}

// 硬件信息项
interface HwItem {
  label: string;
  value: string;
}
interface HwGroup {
  title: string;
  items: HwItem[];
}

@Entry
@Component
struct VmDetailPage {
  @State activeNav: string = 'Pve';
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @State activeTab: string = 'overview'; // overview | snapshot | hardware | history
  @State clusterId: string = '';
  @State nodeName: string = '';
  @State vmid: number = 0;
  @State vm: Vm | undefined = undefined;
  @State loading: boolean = true;
  @State tasks: PveTask[] = [];
  @State snapshots: Snapshot[] = [];
  @StorageLink('isSm') isSm: boolean = false;

  async aboutToAppear() {
    const params = router.getParams() as VmDetailParams;
    this.clusterId = params.clusterId;
    this.nodeName = params.node;
    this.vmid = Number(params.vmid);
    const cluster: PveCluster | undefined = await DataRepository.getPveCluster(this.clusterId);
    if (cluster) {
      this.vm = await DataRepository.getVm(cluster, this.nodeName, this.vmid);
      this.tasks = await DataRepository.getTasks(cluster, this.nodeName);
      this.snapshots = await DataRepository.getSnapshots(cluster, this.nodeName, this.vmid);
    }
    this.loading = false;
  }

  // 硬件配置分组（硬编码示例）
  getHardwareGroups(): HwGroup[] {
    const vm = this.vm;
    if (!vm) return [];
    return [
      {
        title: '处理器', items: [
          { label: 'CPU 类型', value: 'x86-64 (host)' },
          { label: 'CPU 型号', value: 'kvm64' },
          { label: '插槽', value: '1' },
          { label: '核心数', value: '4' },
        ]
      },
      {
        title: '内存', items: [
          { label: '内存', value: `${vm.maxmem} GB` },
          { label: 'Ballooning', value: '启用' },
          { label: '最小内存', value: `${(vm.maxmem * 0.5).toFixed(1)} GB` },
        ]
      },
      {
        title: '存储', items: [
          { label: '磁盘 0', value: `scsi0 (${formatSize(vm.maxdisk)})` },
          { label: '磁盘格式', value: 'raw' },
          { label: '存储池', value: 'local-lvm' },
          { label: '缓存模式', value: 'writeback' },
        ]
      },
      {
        title: '网络', items: [
          { label: '网卡 0', value: 'net0 (virtio)' },
          { label: '网桥', value: 'vmbr0' },
          { label: 'MAC 地址', value: 'BC:24:11:5F:8A:01' },
          { label: '带宽限制', value: '无限制' },
        ]
      },
      {
        title: '显示', items: [
          { label: '显示适配器', value: 'virtio-gpu' },
          { label: '显存', value: '16 MB' },
        ]
      },
      {
        title: '其他', items: [
          { label: 'BIOS', value: 'SeaBIOS' },
          { label: '机器类型', value: 'pc-q35-8.2' },
          { label: 'SCSI 控制器', value: 'virtio-scsi-single' },
        ]
      },
    ];
  }

  // 顶栏操作：控制台主色按钮
  @Builder topActions() {
    Button('控制台')
      .fontSize(12)
      .fontColor(AppTheme.bgBase)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        if (this.vm) {
          promptAction.showToast({ message: `${this.vm.name} 控制台功能开发中` });
        }
      })
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

  // 标签芯片
  @Builder tagChip(tag: string) {
    Text(tag)
      .fontSize(10)
      .fontColor(AppTheme.primary)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(6)
      .backgroundColor(AppTheme.primaryDim)
  }

  // 操作按钮
  @Builder actionBtn(text: string, bg: string, fg: string) {
    Button(text)
      .fontSize(11)
      .fontColor(fg)
      .backgroundColor(bg)
      .borderRadius(5)
      .height(26)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        promptAction.showToast({ message: `${text} ${this.vm!.name} (vmid: ${this.vm!.vmid})` });
      })
  }

  // 快照操作按钮（带具体快照名）
  @Builder snapshotActionBtn(text: string, bg: string, fg: string, s: Snapshot) {
    Button(text)
      .fontSize(11)
      .fontColor(fg)
      .backgroundColor(bg)
      .borderRadius(5)
      .height(26)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        promptAction.showToast({ message: `${text}快照 ${s.name}` });
      })
  }

  // 快照行（带具体快照引用）
  @Builder snapshotRowWithAction(s: Snapshot) {
    Row() {
      Column({ space: 4 }) {
        Text(s.name)
          .fontSize(12)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
          .fontFamily(AppTheme.fontMono)
        Text(s.desc)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
        Row({ space: 16 }) {
          Text(s.date).fontSize(10).fontColor(AppTheme.textTertiary)
          Text(s.size).fontSize(10).fontColor(AppTheme.textSecondary)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.snapshotActionBtn('回滚', AppTheme.bgSurface2, AppTheme.textSecondary, s)
      this.snapshotActionBtn('删除', AppTheme.bgSurface2, AppTheme.danger, s)
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(VerticalAlign.Center)
  }

  // 简化任务行（历史/最近操作）
  @Builder miniTaskRow(t: PveTask) {
    Row() {
      Text(t.type)
        .fontSize(11)
        .fontColor(AppTheme.textPrimary)
        .fontFamily(AppTheme.fontMono)
        .layoutWeight(1)
      // 状态
      Row({ space: 4 }) {
        Circle({ width: 6, height: 6 })
          .fill(t.status === 'running' ? AppTheme.info : t.status === 'success' ? AppTheme.success : AppTheme.danger)
        Text(t.status === 'running' ? '执行中' : t.status === 'success' ? '成功' : '失败')
          .fontSize(10)
          .fontColor(t.status === 'running' ? AppTheme.info : t.status === 'success' ? AppTheme.success : AppTheme.danger)
      }
      Text(t.startTime).fontSize(10).fontColor(AppTheme.textTertiary)
      Text(t.user).fontSize(10).fontColor(AppTheme.textTertiary)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
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
          title: this.vm ? this.vm.name : '-',
          subtitle: this.vm ? `VMID ${this.vm.vmid} · ${this.vm.node} · ${this.vm.type.toUpperCase()}` : '',
          showBack: true
        }) {
          this.topActions()
        }

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(AppTheme.primary)
            Text('加载中...')
              .fontSize(13)
              .fontColor(AppTheme.textSecondary)
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height('100%')
        } else if (this.vm) {
          Scroll() {
            Column({ space: 16 }) {
              // VM 头部卡片
              Row({ space: 16 }) {
                // 左侧大图标
                Stack() {
                  Text(this.vm.type === 'qemu' ? 'Q' : 'L')
                    .fontSize(28)
                    .fontColor('#FFFFFF')
                    .fontWeight(FontWeight.Bold)
                }
                .width(64)
                .height(64)
                .borderRadius(14)
                .linearGradient({
                  angle: 135,
                  colors: this.vm.type === 'qemu'
                    ? [[AppTheme.purple, 0], ['#7C3AED', 1]]
                    : [[AppTheme.primary, 0], ['#00B88A', 1]]
                })

                // 中间信息
                Column({ space: 6 }) {
                  Text(this.vm.name)
                    .fontSize(26)
                    .fontColor(AppTheme.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Row({ space: 8 }) {
                    StatusBadge({ status: this.vm.status })
                    Text(`VMID ${this.vm.vmid}`).fontSize(10).fontColor(AppTheme.textTertiary).fontFamily(AppTheme.fontMono)
                    Text(`节点 ${this.vm.node}`).fontSize(10).fontColor(AppTheme.textTertiary)
                    Text(`OS ${this.vm.os}`).fontSize(10).fontColor(AppTheme.textTertiary)
                    Text(`运行 ${formatUptime(this.vm.uptime)}`).fontSize(10).fontColor(AppTheme.textTertiary)
                  }
                  .alignItems(VerticalAlign.Center)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 右侧操作按钮组
                Column({ space: 6 }) {
                  if (this.vm.status === 'running') {
                    Row({ space: 6 }) {
                      this.actionBtn('停止', AppTheme.bgSurface2, AppTheme.danger)
                      this.actionBtn('重启', AppTheme.bgSurface2, AppTheme.warning)
                    }
                    Row({ space: 6 }) {
                      this.actionBtn('暂停', AppTheme.bgSurface2, AppTheme.textSecondary)
                      this.actionBtn('控制台', AppTheme.primary, AppTheme.bgBase)
                    }
                  } else if (this.vm.status === 'stopped') {
                    Row({ space: 6 }) {
                      this.actionBtn('启动', AppTheme.success, AppTheme.bgBase)
                      this.actionBtn('克隆', AppTheme.bgSurface2, AppTheme.textSecondary)
                    }
                    Row({ space: 6 }) {
                      this.actionBtn('删除', AppTheme.bgSurface2, AppTheme.danger)
                    }
                  } else if (this.vm.status === 'paused') {
                    Row({ space: 6 }) {
                      this.actionBtn('恢复', AppTheme.success, AppTheme.bgBase)
                      this.actionBtn('停止', AppTheme.bgSurface2, AppTheme.danger)
                    }
                  }
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
                  value: (this.vm.cpu * 100).toFixed(1),
                  unit: '%',
                  color: progressColor(this.vm.cpu * 100)
                })
                MetricCard({
                  title: '内存',
                  value: this.vm.mem.toFixed(1),
                  unit: 'GB',
                  color: AppTheme.info,
                  badgeText: `${this.vm.maxmem} GB`
                })
                MetricCard({
                  title: '磁盘 IO',
                  value: this.vm.diskread.toFixed(1),
                  sub: `写 ${this.vm.diskwrite} MB/s`,
                  color: AppTheme.warning
                })
                MetricCard({
                  title: '网络',
                  value: this.vm.netin.toFixed(1),
                  sub: `出 ${this.vm.netout} Mbps`,
                  color: AppTheme.success
                })
              }
              .width('100%')

              // Tab 栏
              Row() {
                this.tabItem('overview', '概览')
                this.tabItem('snapshot', '快照')
                this.tabItem('hardware', '硬件')
                this.tabItem('history', '历史')
              }
              .width('100%')
              .border({ width: { bottom: 1 }, color: AppTheme.borderSubtle })

              // ===== Tab 概览 =====
              if (this.activeTab === 'overview') {
                Column({ space: 16 }) {
                  // 系统信息卡
                  Column({ space: 0 }) {
                    Text('系统信息')
                      .fontSize(12)
                      .fontColor(AppTheme.textSecondary)
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                      .padding({ top: 12, bottom: 4 })
                    this.infoRow('操作系统', this.vm.os)
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('VMID', String(this.vm.vmid))
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('类型', this.vm.type.toUpperCase())
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('节点', this.vm.node)
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('运行时长', formatUptime(this.vm.uptime))
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('CPU', `${(this.vm.cpu * 100).toFixed(1)}%`)
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('内存', `${this.vm.mem.toFixed(1)} / ${this.vm.maxmem} GB`)
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('磁盘', formatSize(this.vm.maxdisk))
                    Divider().color(AppTheme.borderSubtle)
                    this.infoRow('网络', `${this.vm.netin} / ${this.vm.netout} Mbps`)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
                  .borderRadius(10)
                  .backgroundColor(AppTheme.bgSurface)
                  .border({ width: 1, color: AppTheme.borderSubtle })
                  .alignItems(HorizontalAlign.Start)

                  // 标签卡
                  Column({ space: 8 }) {
                    Text('标签')
                      .fontSize(12)
                      .fontColor(AppTheme.textSecondary)
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                    if (this.vm.tags.length > 0) {
                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(this.vm.tags, (tag: string) => {
                          this.tagChip(tag)
                        }, (tag: string) => tag)
                      }
                      .width('100%')
                    } else {
                      Text('暂无标签').fontSize(10).fontColor(AppTheme.textTertiary)
                    }
                  }
                  .width('100%')
                  .padding(16)
                  .borderRadius(10)
                  .backgroundColor(AppTheme.bgSurface)
                  .border({ width: 1, color: AppTheme.borderSubtle })
                  .alignItems(HorizontalAlign.Start)

                  // 最近操作
                  Column({ space: 0 }) {
                    Text('最近操作')
                      .fontSize(12)
                      .fontColor(AppTheme.textSecondary)
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                      .padding({ top: 12, bottom: 4 })
                    ForEach(
                      this.tasks.filter(t =>
                        t.target.includes(String(this.vm!.vmid)) || t.target.includes(this.vm!.name)
                      ),
                      (t: PveTask) => { this.miniTaskRow(t) },
                      (t: PveTask) => t.id
                    )
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
                  .borderRadius(10)
                  .backgroundColor(AppTheme.bgSurface)
                  .border({ width: 1, color: AppTheme.borderSubtle })
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
              }

              // ===== Tab 快照 =====
              if (this.activeTab === 'snapshot') {
                Column({ space: 12 }) {
                  // 创建快照按钮
                  Row() {
                    Blank()
                    Button('创建快照')
                      .fontSize(12)
                      .fontColor(AppTheme.bgBase)
                      .backgroundColor(AppTheme.primary)
                      .borderRadius(6)
                      .height(30)
                      .padding({ left: 12, right: 12 })
                      .onClick(() => {
                        promptAction.showToast({ message: `创建快照 ${this.vm!.name} (开发中)` });
                      })
                  }
                  .width('100%')

                  // 快照列表
                  if (this.snapshots.length === 0) {
                    EmptyState({ icon: '📸', title: '暂无快照', desc: '点击"创建快照"开始' })
                  } else {
                    ForEach(this.snapshots, (s: Snapshot) => {
                      this.snapshotRowWithAction(s)
                    }, (s: Snapshot) => `${s.name}-${s.vmid}`)
                  }
                }
                .width('100%')
              }

              // ===== Tab 硬件 =====
              if (this.activeTab === 'hardware') {
                Column({ space: 12 }) {
                  ForEach(this.getHardwareGroups(), (g: HwGroup) => {
                    Column({ space: 0 }) {
                      Text(g.title)
                        .fontSize(12)
                        .fontColor(AppTheme.textSecondary)
                        .fontWeight(FontWeight.Medium)
                        .width('100%')
                        .padding({ top: 12, bottom: 4 })
                      ForEach(g.items, (item: HwItem) => {
                        this.infoRow(item.label, item.value)
                      }, (item: HwItem) => item.label)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, bottom: 12 })
                    .borderRadius(10)
                    .backgroundColor(AppTheme.bgSurface)
                    .border({ width: 1, color: AppTheme.borderSubtle })
                    .alignItems(HorizontalAlign.Start)
                  }, (g: HwGroup) => g.title)
                }
                .width('100%')
              }

              // ===== Tab 历史 =====
              if (this.activeTab === 'history') {
                Column({ space: 0 }) {
                  if (this.tasks.filter(t =>
                    t.node === this.vm!.node &&
                    (t.target.includes(String(this.vm!.vmid)) || t.target.includes(this.vm!.name))
                  ).length === 0) {
                    EmptyState({ icon: '📋', title: '暂无任务记录', desc: '该虚拟机暂无历史任务' })
                  } else {
                    ForEach(
                      this.tasks.filter(t =>
                        t.node === this.vm!.node &&
                        (t.target.includes(String(this.vm!.vmid)) || t.target.includes(this.vm!.name))
                      ),
                      (t: PveTask) => { this.miniTaskRow(t) },
                      (t: PveTask) => t.id
                    )
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .borderRadius(10)
                .backgroundColor(AppTheme.bgSurface)
                .border({ width: 1, color: AppTheme.borderSubtle })
                .alignItems(HorizontalAlign.Start)
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
// 智子 - SSH 服务器列表页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { EmptyState } from '../components/EmptyState';
import { DataRepository } from '../service/DataRepository';
import { Server, Stats } from '../model/Models';

@Component
export struct ServersPage {
  @State currentGroup: string = '全部';
  @StorageLink('isSm') isSm: boolean = false;
  @State loading: boolean = true;
  @State stats: Stats = { total: 0, online: 0, warning: 0, offline: 0, alerts: 0, pveNodes: 0, vmTotal: 0, vmRunning: 0, vmStopped: 0, ctTotal: 0, runningTasks: 0 };
  @State servers: Server[] = [];
  private groups: string[] = ['全部', '生产', '测试', '监控', '备份', 'CI/CD'];

  aboutToAppear(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    this.loading = true;
    try {
      const servers = await DataRepository.getServers();
      const stats = await DataRepository.getStats();
      this.servers = servers;
      this.stats = stats;
    } catch (e) {
      promptAction.showToast({ message: '加载数据失败' });
    } finally {
      this.loading = false;
    }
  }

  refresh(): void {
    this.loadData();
  }

  // 状态点颜色
  private statusDotColor(status: string): string {
    if (status === 'online') return AppTheme.success;
    if (status === 'warning') return AppTheme.warning;
    return AppTheme.textTertiary;
  }

  // 筛选后的服务器
  private filteredServers(): Server[] {
    if (this.currentGroup === '全部') return this.servers;
    return this.servers.filter(s => s.group === this.currentGroup);
  }

  // 格式化最后连接时间
  private lastConnectText(s: Server): string {
    if (!s.lastConnected) return '从未连接';
    const diff = Date.now() - s.lastConnected;
    const min = Math.floor(diff / 60000);
    if (min < 1) return '刚刚';
    if (min < 60) return `${min} 分钟前`;
    const h = Math.floor(min / 60);
    if (h < 24) return `${h} 小时前`;
    return `${Math.floor(h / 24)} 天前`;
  }

  @Builder actionsBuilder() {
    Button('添加服务器')
      .fontSize(12)
      .fontColor(AppTheme.bgBase)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        promptAction.showToast({ message: '添加服务器功能开发中' });
      })
  }

  // 分组筛选标签
  @Builder groupTag(g: string) {
    Text(g)
      .fontSize(12)
      .fontColor(g === this.currentGroup ? AppTheme.primary : AppTheme.textSecondary)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(g === this.currentGroup ? AppTheme.primaryDim : AppTheme.bgSurface2)
      .onClick(() => { this.currentGroup = g; })
  }

  // 资源列：标题 + 百分比 + 进度条
  @Builder metricCol(label: string, value: number) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
      Text(`${Math.round(value)}%`)
        .fontSize(12)
        .fontColor(AppTheme.textPrimary)
        .fontFamily(AppTheme.fontMono)
      ProgressBar({ value: value, barHeight: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  // 次按钮（支持独立 onClick）
  @Builder secondaryBtn(text: string, onClick: () => void) {
    Button(text)
      .fontSize(11)
      .fontColor(AppTheme.textSecondary)
      .backgroundColor(AppTheme.bgSurface2)
      .borderRadius(5)
      .height(24)
      .padding({ left: 8, right: 8 })
      .onClick(onClick)
  }

  // 服务器卡片
  @Builder serverCard(s: Server) {
    Column({ space: 10 }) {
      // 顶部行：状态点 + 名称 + 状态徽章 + 更多
      Row() {
        Circle({ width: 8, height: 8 }).fill(this.statusDotColor(s.status))
        Text(s.name)
          .fontSize(AppTheme.fsLg)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 6 })
        StatusBadge({ status: s.status, badgeSize: 'small' })
        Text('更多')
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 地址行
      Text(`${s.host}:${s.port}`)
        .fontSize(11)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width('100%')

      // OS + 分组 + tags
      Row({ space: 6 }) {
        Text(s.os || '-')
          .fontSize(10)
          .fontColor(AppTheme.info)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(5)
          .backgroundColor('rgba(59, 130, 246, 0.12)')
        if (s.group) {
          Text(s.group)
            .fontSize(10)
            .fontColor(AppTheme.purple)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(5)
            .backgroundColor('rgba(139, 92, 246, 0.12)')
        }
        ForEach(s.tags, (t: string) => {
          Text(t)
            .fontSize(10)
            .fontColor(AppTheme.textSecondary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(5)
            .backgroundColor(AppTheme.bgSurface2)
        }, (t: string) => t)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 资源区：CPU / 内存 / 磁盘 三等分
      Row({ space: 12 }) {
        this.metricCol('CPU', s.metrics.cpu)
        this.metricCol('内存', s.metrics.mem)
        this.metricCol('磁盘', s.metrics.disk)
      }
      .width('100%')

      // 底部行：最后连接时间 + 连接 + 终端 + 详情
      Row() {
        Text(`最后连接 ${this.lastConnectText(s)}`)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .layoutWeight(1)
        Button('连接')
          .fontSize(11)
          .fontColor(AppTheme.bgBase)
          .backgroundColor(AppTheme.primary)
          .borderRadius(5)
          .height(24)
          .padding({ left: 10, right: 10 })
          .margin({ right: 6 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/Terminal', params: { serverName: s.name } }).catch(() => {});
          })
        this.secondaryBtn('终端', () => {
          router.pushUrl({ url: 'pages/Terminal', params: { serverName: s.name } }).catch(() => {});
        })
        this.secondaryBtn('详情', () => {
          router.pushUrl({ url: 'pages/ServerDetail', params: { serverId: s.id } }).catch(() => {});
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
  }

  build() {
    Column() {
      TopBar({
        title: 'SSH 服务器',
        subtitle: `${this.stats.total} 台 · 在线 ${this.stats.online} · 离线 ${this.stats.offline}`
      }) {
        this.actionsBuilder()
      }
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(AppTheme.primary)
          Text('加载中…')
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 分组筛选标签
            Row({ space: 8 }) {
              ForEach(this.groups, (g: string) => {
                this.groupTag(g)
              }, (g: string) => g)
            }
            .width('100%')

            // 服务器列表
            if (this.filteredServers().length === 0) {
              EmptyState({ icon: '🖥️', title: '暂无服务器', desc: '点击右上角"添加服务器"开始' })
            } else {
              ForEach(this.filteredServers(), (s: Server) => {
                this.serverCard(s)
              }, (s: Server) => s.id)
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
  }
}
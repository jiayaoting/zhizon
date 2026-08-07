// 智子 - SSH 服务器列表页面
import { router, promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { ProgressBar } from '../components/ProgressBar';
import { EmptyState } from '../components/EmptyState';
import { DataRepository } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { Server, Stats } from '../model/Models';

@Component
export struct ServersPage {
  @State currentGroup: string = '全部';
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageProp('serversDirty') @Watch('onServersDirty') serversDirty: number = 0;
  @State loading: boolean = true;
  @State stats: Stats = { total: 0, online: 0, warning: 0, offline: 0, alerts: 0, pveNodes: 0, vmTotal: 0, vmRunning: 0, vmStopped: 0, ctTotal: 0, runningTasks: 0 };
  @State servers: Server[] = [];
  private groups: string[] = ['全部', '生产', '测试', '监控', '备份', 'CI/CD'];

  aboutToAppear(): void {
    this.loadData().then(() => {
      // 自动检测所有服务器连接状态
      if (this.servers.length > 0) {
        this.checkAllServers();
      }
    });
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

  // 服务器数据变更（添加/编辑/删除后）自动刷新
  private onServersDirty(): void {
    this.loadData();
  }

  // 测试单台服务器连接
  private async testServerConnection(s: Server): Promise<void> {
    promptAction.showToast({ message: `正在连接 ${s.name}...` });
    const ok = await SshService.testConnection(s);
    const status: 'online' | 'warning' | 'offline' = ok ? 'online' : 'offline';

    // 更新内存中的服务器状态（status 不持久化到 DB）
    const updated: Server[] = this.servers.map((item: Server) => {
      if (item.id === s.id) {
        const newServer: Server = {
          id: item.id,
          name: item.name,
          host: item.host,
          port: item.port,
          username: item.username,
          authType: item.authType,
          connectionMode: item.connectionMode,
          agentToken: item.agentToken,
          privateKeyPath: item.privateKeyPath,
          group: item.group,
          tags: item.tags,
          os: item.os,
          status: status,
          metrics: item.metrics,
          lastConnected: ok ? Date.now() : item.lastConnected,
          createdAt: item.createdAt
        };
        return newServer;
      }
      return item;
    });
    this.servers = updated;

    // 持久化最后连接时间
    if (ok) {
      await DataRepository.updateServer(s.id, { lastConnected: Date.now() });
    }

    // 更新统计
    const onlineCount = updated.filter(i => i.status === 'online').length;
    const offlineCount = updated.filter(i => i.status === 'offline').length;
    this.stats = {
      total: this.stats.total,
      online: onlineCount,
      warning: this.stats.warning,
      offline: offlineCount,
      alerts: this.stats.alerts,
      pveNodes: this.stats.pveNodes,
      vmTotal: this.stats.vmTotal,
      vmRunning: this.stats.vmRunning,
      vmStopped: this.stats.vmStopped,
      ctTotal: this.stats.ctTotal,
      runningTasks: this.stats.runningTasks
    };

    promptAction.showToast({ message: ok ? `${s.name} 连接成功` : `${s.name} 无法连接` });
  }

  // 一键重连：从加密存储加载凭据，直接连接并跳转终端
  private async quickReconnect(s: Server): Promise<void> {
    promptAction.showToast({ message: `正在连接 ${s.name}...` });
    try {
      // hydrate 凭据后连接
      const hydrated = await SshService.hydrateCredentials(s);
      const ok = await SshService.testConnection(hydrated);
      if (ok) {
        // 更新状态和最后连接时间
        const status: 'online' | 'warning' | 'offline' = ok ? 'online' : 'offline';
        const updated: Server[] = this.servers.map((item: Server) => {
          if (item.id === s.id) {
            const newServer: Server = {
              id: item.id,
              name: item.name,
              host: item.host,
              port: item.port,
              username: item.username,
              authType: item.authType,
              connectionMode: item.connectionMode,
              agentToken: item.agentToken,
              privateKeyPath: item.privateKeyPath,
              group: item.group,
              tags: item.tags,
              os: item.os,
              status: status,
              metrics: item.metrics,
              lastConnected: Date.now(),
              createdAt: item.createdAt
            };
            return newServer;
          }
          return item;
        });
        this.servers = updated;
        await DataRepository.updateServer(s.id, { lastConnected: Date.now() });
        promptAction.showToast({ message: `${s.name} 连接成功，跳转到终端` });
        router.pushUrl({ url: 'pages/Terminal', params: { serverId: s.id } });
      } else {
        promptAction.showToast({ message: `${s.name} 无法连接` });
      }
    } catch (e) {
      promptAction.showToast({ message: `连接失败: ${JSON.stringify(e)}` });
    }
  }

  // 删除服务器（含二次确认）
  private confirmDeleteServer(s: Server): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除服务器 "${s.name}" (${s.host}) 吗？此操作不可撤销。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: this.palette.danger,
        action: () => {
          this.deleteServer(s);
        }
      }
    });
  }

  private async deleteServer(s: Server): Promise<void> {
    try {
      await DataRepository.deleteServer(s.id);
      promptAction.showToast({ message: `${s.name} 已删除` });
      this.servers = this.servers.filter((item: Server) => item.id !== s.id);
      // 整体赋值 stats 以触发 @State UI 更新
      const onlineCount = this.servers.filter(i => i.status === 'online').length;
      const offlineCount = this.servers.filter(i => i.status === 'offline').length;
      this.stats = {
        total: this.servers.length,
        online: onlineCount,
        warning: this.stats.warning,
        offline: offlineCount,
        alerts: this.stats.alerts,
        pveNodes: this.stats.pveNodes,
        vmTotal: this.stats.vmTotal,
        vmRunning: this.stats.vmRunning,
        vmStopped: this.stats.vmStopped,
        ctTotal: this.stats.ctTotal,
        runningTasks: this.stats.runningTasks
      };
      AppStorage.setOrCreate('serversDirty', Date.now());
    } catch (e) {
      promptAction.showToast({ message: '删除失败，请重试' });
    }
  }

  // 批量检测所有服务器状态（并发）
  private async checkAllServers(): Promise<void> {
    promptAction.showToast({ message: '正在检测所有服务器...' });
    const promises: Promise<void>[] = [];
    for (const s of this.servers) {
      promises.push(this.testSingleServer(s));
    }
    await Promise.all(promises);
    promptAction.showToast({ message: '检测完成' });
  }

  // 检测单台服务器（不弹 toast）
  private async testSingleServer(s: Server): Promise<void> {
    try {
      const ok: boolean = await SshService.testConnection(s);
      const status: 'online' | 'warning' | 'offline' = ok ? 'online' : 'offline';
      const idx: number = this.servers.findIndex((item: Server) => item.id === s.id);
      if (idx >= 0) {
        const updated: Server = {
          id: s.id,
          name: s.name,
          host: s.host,
          port: s.port,
          username: s.username,
          authType: s.authType,
          connectionMode: s.connectionMode,
          agentToken: s.agentToken,
          privateKeyPath: s.privateKeyPath,
          group: s.group,
          tags: s.tags,
          os: s.os,
          status: status,
          metrics: s.metrics,
          lastConnected: ok ? Date.now() : s.lastConnected,
          createdAt: s.createdAt
        };
        this.servers[idx] = updated;
        if (ok) {
          await DataRepository.updateServer(s.id, { lastConnected: Date.now() });
        }
      }
    } catch (e) {
      // 单台失败不影响其他
    }
  }

  // 状态点颜色
  private statusDotColor(status: string): string {
    if (status === 'online') return this.palette.success;
    if (status === 'warning') return this.palette.warning;
    return this.palette.textTertiary;
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
    Row({ space: 8 }) {
      Button('检测全部')
        .fontSize(12)
        .fontColor(this.palette.textPrimary)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(6)
        .height(30)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          this.checkAllServers();
        })
      Button('添加服务器')
        .fontSize(12)
        .fontColor(this.palette.bgBase)
        .backgroundColor(this.palette.primary)
        .borderRadius(6)
        .height(30)
        .padding({ left: 12, right: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/ServerForm' });
        })
    }
  }

  // 分组筛选标签
  @Builder groupTag(g: string) {
    Text(g)
      .fontSize(12)
      .fontColor(g === this.currentGroup ? this.palette.primary : this.palette.textSecondary)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(g === this.currentGroup ? this.palette.primaryDim : this.palette.bgSurface2)
      .onClick(() => { this.currentGroup = g; })
  }

  // 资源列：标题 + 百分比 + 进度条
  @Builder metricCol(label: string, value: number) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(this.palette.textTertiary)
      Text(`${Math.round(value)}%`)
        .fontSize(12)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontMono)
      ProgressBar({ value: value, barHeight: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  // 次按钮（支持独立 onClick）
  @Builder secondaryBtn(text: string, onClick: () => void) {
    Button(text)
      .fontSize(11)
      .fontColor(this.palette.textSecondary)
      .backgroundColor(this.palette.bgSurface2)
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
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: 6 })
        StatusBadge({ status: s.status, badgeSize: 'small' })
        Text('更多')
          .fontSize(11)
          .fontColor(this.palette.textTertiary)
          .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 地址行
      Text(`${s.host}:${s.port}`)
        .fontSize(11)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontMono)
        .width('100%')

      // OS + 分组 + tags + 连接模式
      Row({ space: 6 }) {
        Text(s.os || '-')
          .fontSize(10)
          .fontColor(this.palette.info)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(5)
          .backgroundColor('rgba(59, 130, 246, 0.12)')
        if (s.group) {
          Text(s.group)
            .fontSize(10)
            .fontColor(this.palette.purple)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(5)
            .backgroundColor('rgba(139, 92, 246, 0.12)')
        }
        ForEach(s.tags, (t: string) => {
          Text(t)
            .fontSize(10)
            .fontColor(this.palette.textSecondary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(5)
            .backgroundColor(this.palette.bgSurface2)
        }, (t: string) => t)
        // 连接模式标签
        Text(s.connectionMode === 'direct' ? '直连' : 'Agent')
          .fontSize(10)
          .fontColor(s.connectionMode === 'direct' ? this.palette.warning : this.palette.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(5)
          .backgroundColor(s.connectionMode === 'direct' ? 'rgba(245, 158, 11, 0.12)' : this.palette.primaryDim)
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

      // 底部行：最后连接时间 + 一键重连 + 终端 + 编辑 + 删除
      Row() {
        Text(`最后连接 ${this.lastConnectText(s)}`)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .layoutWeight(1)
        Button('一键重连')
          .fontSize(11)
          .fontColor(this.palette.bgBase)
          .backgroundColor(this.palette.primary)
          .borderRadius(5)
          .height(24)
          .padding({ left: 10, right: 10 })
          .margin({ right: 6 })
          .onClick(() => {
            this.quickReconnect(s);
          })
        this.secondaryBtn('终端', () => {
          router.pushUrl({ url: 'pages/Terminal', params: { serverId: s.id } }).catch(() => {});
        })
        this.secondaryBtn('编辑', () => {
          router.pushUrl({ url: 'pages/ServerForm', params: { serverId: s.id } }).catch(() => {});
        })
        this.secondaryBtn('删除', () => {
          this.confirmDeleteServer(s);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
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
            .color(this.palette.primary)
          Text('加载中…')
            .fontSize(12)
            .fontColor(this.palette.textTertiary)
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

            // 最近连接（按 lastConnected 排序，取前 5 台）
            if (this.servers.filter((s: Server) => s.lastConnected && s.lastConnected > 0).length > 0) {
              Column({ space: 8 }) {
                Text('最近连接')
                  .fontSize(12)
                  .fontColor(this.palette.textSecondary)
                  .fontWeight(FontWeight.Bold)
                Row({ space: 8 }) {
                  ForEach(
                    [...this.servers]
                      .filter((s: Server) => s.lastConnected && s.lastConnected > 0)
                      .sort((a: Server, b: Server) => (b.lastConnected || 0) - (a.lastConnected || 0))
                      .slice(0, 5),
                    (s: Server) => {
                      Text(s.name)
                        .fontSize(11)
                        .fontColor(this.palette.primary)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .borderRadius(6)
                        .backgroundColor(this.palette.primaryDim)
                        .fontFamily(this.palette.fontMono)
                        .onClick(() => {
                          this.quickReconnect(s);
                        })
                    },
                    (s: Server) => `recent-${s.id}`
                  )
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

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
    .backgroundColor(this.palette.bgBase)
  }
}
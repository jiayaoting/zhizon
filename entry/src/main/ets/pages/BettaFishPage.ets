// 智子 - 微舆（BettaFish）Hub 页：连接状态 + 分析/论坛/报告 三 Tab（M2-M4 完整闭环）
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { BettaConnectionBar } from '../components/BettaConnectionBar';
import { BettaEngineStatusCard } from '../components/BettaEngineStatusCard';
import { BettaForumMessageItem } from '../components/BettaForumMessageItem';
import { BettaFishStore } from '../service/BettaFishStore';
import { BettaFishApiClient } from '../service/BettaFishApiClient';
import { BettaServerConfig, BettaEngineStatus, BettaForumMessage, BettaHistoryItem } from '../common/BettaFishModels';
import { BettaFishProgressRouteParams, BettaFishReportRouteParams } from '../common/Navigation';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

const EXAMPLE_QUERIES: string[] = ['武汉大学舆情', '鸿蒙系统用户口碑', '国产大模型热度分析'];

@Component
export struct BettaFishPage {
  @State server: BettaServerConfig | null = null;
  @State connState: string = 'unconfigured';   // unconfigured | checking | connected | error
  @State connDetail: string = '';
  @State currentTab: number = 0;
  @State engines: BettaEngineStatus[] = [];
  @State query: string = '';
  @State submitting: boolean = false;
  @State forumMessages: BettaForumMessage[] = [];
  @State forumFilter: string = '全部';
  @State history: BettaHistoryItem[] = [];
  @StorageLink('bettaRefreshToken') @Watch('onRefreshToken') bettaRefreshToken: number = 0;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  private forumTimer: number = -1;

  aboutToAppear(): void {
    this.reload();
    this.startForumPolling();
  }

  aboutToDisappear(): void {
    if (this.forumTimer >= 0) {
      clearInterval(this.forumTimer);
      this.forumTimer = -1;
    }
  }

  onRefreshToken(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    try {
      this.server = await BettaFishStore.getCurrent();
    } catch (e) {
      this.server = null;
    }
    if (this.server === null) {
      this.connState = 'unconfigured';
      this.connDetail = '配置你的 BettaFish 服务器后即可发起舆情分析';
      this.engines = [];
      this.forumMessages = [];
      return;
    }
    await this.probe(this.server);
    this.loadEngines();
    this.loadForum();
    this.loadHistory();
  }

  private async probe(server: BettaServerConfig): Promise<void> {
    this.connState = 'checking';
    this.connDetail = '正在探测 ' + BettaFishApiClient.buildBaseUrl(server);
    const result = await BettaFishApiClient.systemStatus(server);
    if (result.ok && result.data !== null) {
      this.connState = 'connected';
      if (result.data.started) {
        this.connDetail = '系统已启动 · ' + server.name;
      } else if (result.data.starting) {
        this.connDetail = '系统启动中 · ' + server.name;
      } else {
        this.connDetail = '系统未启动（提交分析时会自动启动）';
      }
    } else {
      this.connState = 'error';
      this.connDetail = result.message;
    }
  }

  private async loadEngines(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    const result = await BettaFishApiClient.engineStatus(server);
    if (result.ok && result.data !== null) {
      this.engines = result.data;
    }
  }

  private async loadForum(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    const result = await BettaFishApiClient.forumLogAll(server);
    if (result.ok && result.data !== null) {
      this.forumMessages = result.data;
    }
  }

  private async loadHistory(): Promise<void> {
    try {
      this.history = await BettaFishStore.listHistory(50);
    } catch (e) {
      this.history = [];
    }
  }

  private startForumPolling(): void {
    if (this.forumTimer >= 0) return;
    this.forumTimer = setInterval(() => {
      this.loadForum();
      this.loadEngines();
    }, 3000);
  }

  private openServerConfig(): void {
    AppNavigator.push('pages/BettaFishServerConfig');
  }

  private openSystem(): void {
    AppNavigator.push('pages/BettaFishSystem');
  }

  // ========== 分析 ==========

  private async onSubmit(): Promise<void> {
    const query = this.query.trim();
    if (query.length === 0) {
      promptAction.showToast({ message: '请输入要分析的舆情话题' });
      return;
    }
    const server = this.server;
    if (server === null) {
      promptAction.showToast({ message: '请先配置服务器' });
      this.openServerConfig();
      return;
    }
    if (this.submitting) return;
    this.submitting = true;
    try {
      // 系统未启动则自动一键启动
      const status = await BettaFishApiClient.systemStatus(server);
      if (status.ok && status.data !== null && !status.data.started && !status.data.starting) {
        const start = await BettaFishApiClient.systemStart(server);
        if (!start.ok) {
          promptAction.showToast({ message: '自动启动系统失败：' + start.message });
          this.submitting = false;
          return;
        }
        promptAction.showToast({ message: '系统已自动启动，正在发起分析…' });
      }
      const search = await BettaFishApiClient.submitSearch(server, query);
      if (!search.ok) {
        promptAction.showToast({ message: '发起分析失败：' + search.message });
        this.submitting = false;
        return;
      }
      this.query = '';
      AppNavigator.push('pages/BettaFishProgress',
        new BettaFishProgressRouteParams('', query, server.id, server.name));
    } catch (e) {
      promptAction.showToast({ message: '发起分析异常，请重试' });
    } finally {
      this.submitting = false;
    }
  }

  // ========== 论坛 ==========

  private filteredForum(): BettaForumMessage[] {
    if (this.forumFilter === '全部') return this.forumMessages;
    const out: BettaForumMessage[] = [];
    for (let i: number = 0; i < this.forumMessages.length; i++) {
      if (this.forumMessages[i].source === this.forumFilter) {
        out.push(this.forumMessages[i]);
      }
    }
    return out;
  }

  // ========== 报告历史 ==========

  private openReport(item: BettaHistoryItem): void {
    AppNavigator.push('pages/BettaFishReportView',
      new BettaFishReportRouteParams(item.taskId,
        item.serverId.length > 0 ? item.serverId : (this.server !== null ? this.server.id : ''),
        item.serverId.length > 0 ? '' : (this.server !== null ? this.server.name : ''),
        item.query));
  }

  private async removeHistory(item: BettaHistoryItem): Promise<void> {
    promptAction.showDialog({
      title: '删除历史记录',
      message: '删除「' + (item.query.length > 0 ? item.query : item.taskId) + '」？',
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '删除', color: '#E84026' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        await BettaFishStore.deleteHistory(item.taskId);
        await this.loadHistory();
        promptAction.showToast({ message: '已删除' });
      }
    }).catch(() => {
    });
  }

  private statusBadge(status: string): string {
    if (status === 'completed') return '✅ 已完成';
    if (status === 'running') return '🔄 生成中';
    if (status === 'error') return '❌ 失败';
    if (status === 'cancelled') return '⏹ 已取消';
    return '⏳ ' + status;
  }

  // ========== 构建器 ==========

  @Builder
  engineRows() {
    if (this.engines.length === 0) {
      Text('暂无引擎状态（需系统启动后显示）')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .width('100%')
    }
    if (this.engines.length > 0) {
      Row({ space: 8 }) {
        BettaEngineStatusCard({ engine: this.engines[0] })
          .layoutWeight(1)
        if (this.engines.length > 1) {
          BettaEngineStatusCard({ engine: this.engines[1] })
            .layoutWeight(1)
        } else {
          Column().layoutWeight(1)
        }
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
    if (this.engines.length > 2) {
      Row({ space: 8 }) {
        BettaEngineStatusCard({ engine: this.engines[2] })
          .layoutWeight(1)
        if (this.engines.length > 3) {
          BettaEngineStatusCard({ engine: this.engines[3] })
            .layoutWeight(1)
        } else {
          Column().layoutWeight(1)
        }
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
  }

  @Builder
  analysisTab() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        Row() {
          Text('引擎状态')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('3 秒自动刷新')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .width('100%')
        this.engineRows()
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })

      Column({ space: 10 }) {
        Text('发起舆情分析')
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        TextInput({ placeholder: '输入要分析的舆情话题…', text: this.query })
          .width('100%')
          .height(44)
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(12)
          .onChange((v: string) => { this.query = v; })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(EXAMPLE_QUERIES, (item: string) => {
            Text(item)
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.palette.primaryDim)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.query = item; })
          }, (item: string) => item)
        }
        .width('100%')
        Button(this.submitting ? '正在发起…' : '🚀 发起分析')
          .width('100%')
          .height(42)
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .backgroundColor(this.palette.primary)
          .enabled(!this.submitting)
          .onClick(() => { this.onSubmit(); })
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 14 })
  }

  @Builder
  forumTab() {
    Column({ space: 10 }) {
      Column({ space: 8 }) {
        Row() {
          Text('Agent 论坛实况')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(this.forumMessages.length.toString() + ' 条')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['全部', 'HOST', 'QUERY', 'MEDIA', 'INSIGHT'], (item: string) => {
            Text(item)
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.forumFilter === item ? Color.White : this.palette.textSecondary)
              .fontWeight(this.forumFilter === item ? FontWeight.Medium : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.forumFilter === item ? this.palette.primary : this.palette.bgSurface2)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.forumFilter = item; })
          }, (item: string) => item)
        }
        .width('100%')
      }
      .width('100%')

      if (this.filteredForum().length === 0) {
        Column({ space: 8 }) {
          Text('💬')
            .fontSize(30)
            .fontFamily(this.palette.fontSans)
          Text('暂无论坛消息，发起分析后这里会实时滚动')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .width('100%')
        .padding(30)
        .justifyContent(FlexAlign.Center)
        .borderRadius(14)
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredForum(), (msg: BettaForumMessage) => {
              BettaForumMessageItem({ message: msg })
                .width('100%')
                .padding({ left: 4, right: 4 })
            }, (msg: BettaForumMessage) => msg.timestamp + '-' + msg.content.length.toString() + '-' + msg.sender)
          }
          .width('100%')
          .padding(12)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 14 })
  }

  @Builder
  historyTab() {
    Column({ space: 10 }) {
      Row() {
        Text('报告历史')
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('本地保存 ' + this.history.length.toString() + ' 条')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')

      if (this.history.length === 0) {
        Column({ space: 8 }) {
          Text('📊')
            .fontSize(30)
            .fontFamily(this.palette.fontSans)
          Text('暂无报告历史，生成报告后自动记录')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .width('100%')
        .padding(30)
        .justifyContent(FlexAlign.Center)
        .borderRadius(14)
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.history, (item: BettaHistoryItem) => {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(item.query.length > 0 ? item.query : item.taskId)
                    .fontSize(this.palette.fsBase)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(this.statusBadge(item.status))
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.primary)
                }
                .width('100%')
                Row({ space: 12 }) {
                  Text(new Date(item.createdAt).toLocaleString())
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textTertiary)
                  Blank()
                  Text('打开')
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.primary)
                    .onClick(() => { this.openReport(item); })
                  Text('删除')
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.danger)
                    .onClick(() => { this.removeHistory(item); })
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
              .onClick(() => { this.openReport(item); })
            }, (item: BettaHistoryItem) => item.taskId)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 14 })
  }

  build() {
    Column() {
      // 头部
      Row({ space: 10 }) {
        Text('🐟')
          .fontSize(22)
          .fontFamily(this.palette.fontSans)
        Column({ space: 2 }) {
          Text('微舆')
            .fontSize(this.palette.fsXl)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Text('BettaFish 舆情分析控制台')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('⚙')
          .fontSize(18)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .width(38)
          .height(38)
          .textAlign(TextAlign.Center)
          .borderRadius(19)
          .backgroundColor(this.palette.primaryDim)
          .accessibilityText('微舆设置')
          .onClick(() => { this.openServerConfig(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24,
        top: Math.max(this.statusBarHeight, 44) + 8 })

      BettaConnectionBar({
        state: this.connState,
        serverName: this.server !== null ? this.server.name : '',
        detail: this.connDetail,
        onConfigTap: () => { this.openServerConfig(); },
        onRetryTap: () => {
          if (this.server !== null) {
            this.probe(this.server);
          } else {
            this.reload();
          }
        }
      })
      .margin({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12 })

      Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
        TabContent() {
          Scroll() {
            this.analysisTab()
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
          .edgeEffect(EdgeEffect.Spring)
        }
        .tabBar('🔍 分析')
        TabContent() {
          this.forumTab()
        }
        .tabBar('💬 论坛')
        TabContent() {
          this.historyTab()
        }
        .tabBar('📊 报告')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(true)
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

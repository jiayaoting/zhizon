// 智子 - 微舆（BettaFish）Hub 页：连接状态 + 分析/论坛/报告 三 Tab（M2-M4 完整闭环）
// v10：内容卡改纯色面（bgSurface + 发丝边框，无阴影/无玻璃），状态语义色，列表发丝分割线，空态含原因 + CTA。
// P4（V2 状态迁移）：V1 状态装饰器全部改 V2（ComponentV2 / Local），主题色、断点、状态栏高度改由
// ThemeState（AppStorageV2）提供；AppStorage 里的刷新令牌改在已有的 3 秒轮询中比较（V2 组件禁用存储装饰器）。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { BettaConnectionBar } from '../components/BettaConnectionBar';
import { BettaEngineStatusCard } from '../components/BettaEngineStatusCard';
import { BettaForumMessageItem } from '../components/BettaForumMessageItem';
import { BettaFishStore } from '../service/betta/BettaFishStore';
import { BettaFishApiClient } from '../service/betta/BettaFishApiClient';
import { BettaServerConfig, BettaEngineStatus, BettaForumMessage, BettaHistoryItem } from '../common/BettaFishModels';
import { BettaFishProgressRouteParams, BettaFishReportRouteParams } from '../common/Navigation';
import { ThemeState } from '../common/ThemeState';
import { PageRefreshBus } from '../common/PageRefreshBus';

const EXAMPLE_QUERIES: string[] = ['武汉大学舆情', '鸿蒙系统用户口碑', '国产大模型热度分析'];
const FORUM_FILTERS: string[] = ['全部', 'HOST', 'QUERY', 'MEDIA', 'INSIGHT'];

@ComponentV2
export struct BettaFishPage {
  @Local server: BettaServerConfig | null = null;
  @Local connState: string = 'unconfigured';   // unconfigured | checking | connected | error
  @Local connDetail: string = '';
  @Local currentTab: number = 0;
  @Local engines: BettaEngineStatus[] = [];
  @Local query: string = '';
  @Local submitting: boolean = false;
  @Local forumMessages: BettaForumMessage[] = [];
  @Local forumFilter: string = '全部';
  @Local history: BettaHistoryItem[] = [];
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // v10：宿主可见性刷新统一走 PageRefreshBus（V2 组件无法使用 @StorageLink + @Watch 观察 AppShell 的令牌）
  private forumTimer: number = -1;
  private onHostShow = (): void => {
    this.reload();
  };

  aboutToAppear(): void {
    PageRefreshBus.onBettaShow(this.onHostShow);
    this.reload();
    this.startForumPolling();
  }

  aboutToDisappear(): void {
    PageRefreshBus.offBettaShow(this.onHostShow);
    if (this.forumTimer >= 0) {
      clearInterval(this.forumTimer);
      this.forumTimer = -1;
    }
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
        { text: '取消', color: this.themeState.palette.textSecondary },
        { text: '删除', color: this.themeState.palette.danger }
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
    if (status === 'completed') return '已完成';
    if (status === 'running') return '生成中';
    if (status === 'error') return '失败';
    if (status === 'cancelled') return '已取消';
    return status;
  }

  private statusColor(status: string): string {
    if (status === 'completed') return this.themeState.palette.success;
    if (status === 'running') return this.themeState.palette.primary;
    if (status === 'error') return this.themeState.palette.danger;
    return this.themeState.palette.textTertiary;
  }

  private statusBg(status: string): string {
    if (status === 'completed') return this.themeState.palette.successBg;
    if (status === 'running') return this.themeState.palette.primaryBg;
    if (status === 'error') return this.themeState.palette.dangerBg;
    return this.themeState.palette.bgSurface2;
  }

  // ========== 构建器 ==========

  // 顶栏图标钮（44vp 触控目标，矢量优先 / emoji 回退）
  @Builder
  iconButton(icon: Resource, emoji: string, label: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(44)
    .height(44)
    .borderRadius(this.themeState.palette.radiusSm)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label)
    .onClick(onTap)
  }

  // Tab 标签（华为式下划线选中态）
  @Builder
  tabLabel(label: string, index: number) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.currentTab === index ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
      Row()
        .width(20)
        .height(2.5)
        .borderRadius(2)
        .backgroundColor(this.currentTab === index ? this.themeState.palette.primary : Color.Transparent)
    }
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  engineRows() {
    if (this.engines.length === 0) {
      Text('暂无引擎状态（需系统启动后显示）')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .width('100%')
    }
    if (this.engines.length > 0) {
      Row({ space: this.themeState.palette.sp2 }) {
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
      .margin({ bottom: this.themeState.palette.sp2 })
    }
    if (this.engines.length > 2) {
      Row({ space: this.themeState.palette.sp2 }) {
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
      .margin({ bottom: this.themeState.palette.sp2 })
    }
  }

  @Builder
  analysisTab() {
    Column({ space: this.themeState.palette.cardGap }) {
      Column({ space: this.themeState.palette.sp2 }) {
        Row() {
          Text('引擎状态')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('3 秒自动刷新')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        this.engineRows()
      }
      .width('100%')
      .padding(this.themeState.palette.sp4)
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })

      Column({ space: this.themeState.palette.sp3 }) {
        Text('发起舆情分析')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        TextInput({ placeholder: '输入要分析的舆情话题…', text: this.query })
          .width('100%')
          .height(44)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .placeholderColor(this.themeState.palette.textTertiary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .onChange((v: string) => { this.query = v; })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(EXAMPLE_QUERIES, (item: string) => {
            Text(item)
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primary)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(this.themeState.palette.radiusCapsule)
              .backgroundColor(this.themeState.palette.primaryBg)
              .margin({ right: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
              .onClick(() => { this.query = item; })
          }, (item: string) => item)
        }
        .width('100%')
        Button(this.submitting ? '正在发起…' : '发起分析')
          .width('100%')
          .height(44)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Medium)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .backgroundColor(this.themeState.palette.primary)
          .enabled(!this.submitting)
          .onClick(() => { this.onSubmit(); })
      }
      .width('100%')
      .padding(this.themeState.palette.sp4)
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp3 })
  }

  @Builder
  forumTab() {
    Column({ space: this.themeState.palette.sp3 }) {
      Column({ space: this.themeState.palette.sp2 }) {
        Row() {
          Text('Agent 论坛实况')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(this.forumMessages.length.toString() + ' 条')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(FORUM_FILTERS, (item: string) => {
            Text(item)
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.forumFilter === item ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
              .fontWeight(this.forumFilter === item ? FontWeight.Medium : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(this.themeState.palette.radiusCapsule)
              .backgroundColor(this.forumFilter === item ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface2)
              .margin({ right: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
              .onClick(() => { this.forumFilter = item; })
          }, (item: string) => item)
        }
        .width('100%')
      }
      .width('100%')

      if (this.filteredForum().length === 0) {
        Column({ space: this.themeState.palette.sp3 }) {
          Text('💬')
            .fontSize(48)
            .fontFamily(this.themeState.palette.fontSans)
          Text('暂无论坛消息')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('发起分析后，Agent 论坛会在这里实时滚动')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .textAlign(TextAlign.Center)
          Text('去发起分析')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .fontWeight(FontWeight.Medium)
            .height(44)
            .padding({ left: 24, right: 24 })
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.themeState.palette.primary)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.currentTab = 0; })
        }
        .width('100%')
        .padding(this.themeState.palette.sp8)
        .justifyContent(FlexAlign.Center)
        .borderRadius(this.themeState.palette.radiusLg)
        .backgroundColor(this.themeState.palette.bgSurface)
        .border({ width: 0.5, color: this.themeState.palette.divider })
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredForum(), (msg: BettaForumMessage) => {
              BettaForumMessageItem({ message: msg })
                .width('100%')
            }, (msg: BettaForumMessage) => msg.timestamp + '-' + msg.content.length.toString() + '-' + msg.sender)
          }
          .width('100%')
          .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3, top: this.themeState.palette.sp1 })
          .borderRadius(this.themeState.palette.radiusLg)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })
          .clip(true)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp3 })
  }

  // 报告历史行：56vp 行高 + 发丝分割线，元信息 fsXs textTertiary
  @Builder
  historyRow(item: BettaHistoryItem) {
    Row({ space: this.themeState.palette.sp2 }) {
      Column({ space: 3 }) {
        Text(item.query.length > 0 ? item.query : item.taskId)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row({ space: this.themeState.palette.sp2 }) {
          Text(this.statusBadge(item.status))
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.statusColor(item.status))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(this.themeState.palette.radiusSm)
            .backgroundColor(this.statusBg(item.status))
          Text(new Date(item.createdAt).toLocaleString())
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('打开')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
        .height(44)
        .padding({ left: 8, right: 8 })
        .textAlign(TextAlign.Center)
        .onClick(() => { this.openReport(item); })
      Text('删除')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.danger)
        .height(44)
        .padding({ left: 8, right: 8 })
        .textAlign(TextAlign.Center)
        .onClick(() => { this.removeHistory(item); })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp2 })
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: this.themeState.palette.divider })
    .onClick(() => { this.openReport(item); })
  }

  @Builder
  historyTab() {
    Column({ space: this.themeState.palette.sp3 }) {
      Row() {
        Text('报告历史')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('本地保存 ' + this.history.length.toString() + ' 条')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')

      if (this.history.length === 0) {
        Column({ space: this.themeState.palette.sp3 }) {
          Text('📊')
            .fontSize(48)
            .fontFamily(this.themeState.palette.fontSans)
          Text('暂无报告历史')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('生成报告后会自动记录在这里')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .textAlign(TextAlign.Center)
          Text('去发起分析')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .fontWeight(FontWeight.Medium)
            .height(44)
            .padding({ left: 24, right: 24 })
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.themeState.palette.primary)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.currentTab = 0; })
        }
        .width('100%')
        .padding(this.themeState.palette.sp8)
        .justifyContent(FlexAlign.Center)
        .borderRadius(this.themeState.palette.radiusLg)
        .backgroundColor(this.themeState.palette.bgSurface)
        .border({ width: 0.5, color: this.themeState.palette.divider })
      } else {
        Scroll() {
          Column() {
            ForEach(this.history, (item: BettaHistoryItem) => {
              this.historyRow(item)
            }, (item: BettaHistoryItem) => item.taskId)
          }
          .width('100%')
          .borderRadius(this.themeState.palette.radiusLg)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })
          .clip(true)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp3 })
  }

  build() {
    Column() {
      // 头部：Tab 首页无返回键；右侧仅 1 个设置动作（≤3 个，符合 §3.4.2）
      Row({ space: this.themeState.palette.sp3 }) {
        Row() {
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(AppIcons.navBetta)
              .fontSize(24)
              .fontColor([this.themeState.palette.primary])
              .accessibilityLevel('no')
          } else {
            Text(AppIcons.navBettaEmoji)
              .fontSize(this.themeState.palette.fsXl)
              .fontFamily(this.themeState.palette.fontSans)
          }
        }
        .width(40)
        .height(40)
        .borderRadius(this.themeState.palette.radiusSm)
        .backgroundColor(this.themeState.palette.primaryBg)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: 2 }) {
          Text('微舆')
            .fontSize(this.themeState.palette.fsXl)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Text('BettaFish 舆情分析控制台')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.iconButton(AppIcons.settings, AppIcons.settingsEmoji, '微舆设置', (): void => {
          this.openServerConfig();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        top: Math.max(this.themeState.statusBarHeight, 44) + 8 })

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
      .margin({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp3 })

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
        .tabBar(this.tabLabel('分析', 0))
        TabContent() {
          this.forumTab()
        }
        .tabBar(this.tabLabel('论坛', 1))
        TabContent() {
          this.historyTab()
        }
        .tabBar(this.tabLabel('报告', 2))
      }
      .layoutWeight(1)
      .width('100%')
      .barHeight(44)
      .scrollable(true)
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

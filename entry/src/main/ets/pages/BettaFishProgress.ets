// 智子 - 微舆 分析进度页：引擎状态轮询 → 生成报告 → SSE 实时进度 → 终态
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { BettaEngineStatusCard } from '../components/BettaEngineStatusCard';
import { AppNavigator } from '../common/AppNavigator';
import { BettaFishStore } from '../service/BettaFishStore';
import { BettaFishApiClient } from '../service/BettaFishApiClient';
import { BettaFishSseClient } from '../service/BettaFishSseClient';
import { BettaServerConfig, BettaEngineStatus, BettaReportStatus, BettaReportEvent,
  BettaReportTask, BettaHistoryItem } from '../common/BettaFishModels';
import { BettaFishProgressRouteParams, BettaFishReportRouteParams } from '../common/Navigation';

@ComponentV2
@Entry
export struct BettaFishProgressPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local server: BettaServerConfig | null = null;
  @Local engines: BettaEngineStatus[] = [];
  @Local reportStatus: BettaReportStatus | null = null;
  @Local query: string = '';
  @Local taskId: string = '';
  @Local generating: boolean = false;
  @Local progress: number = 0;
  @Local phaseText: string = '';
  @Local logs: string[] = [];
  @Local errorText: string = '';
  @Local taskState: string = '';     // '' | running | completed | error | cancelled
  private pollTimer: number = -1;
  private fallbackTimer: number = -1;
  private sse: BettaFishSseClient = new BettaFishSseClient();

  aboutToAppear(): void {
    const params = AppNavigator.getParam('pages/BettaFishProgress') as BettaFishProgressRouteParams | null;
    if (params !== null) {
      this.query = params.query;
      this.taskId = params.taskId;
    }
    this.loadServer();
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.stopPolling();
    this.sse.stop();
  }

  private async loadServer(): Promise<void> {
    try {
      this.server = await BettaFishStore.getCurrent();
    } catch (e) {
      this.server = null;
    }
  }

  private startPolling(): void {
    this.loadEngines();
    this.loadReportStatus();
    if (this.pollTimer < 0) {
      this.pollTimer = setInterval(() => {
        this.loadEngines();
        this.loadReportStatus();
      }, 3000);
    }
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    if (this.fallbackTimer >= 0) {
      clearInterval(this.fallbackTimer);
      this.fallbackTimer = -1;
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

  private async loadReportStatus(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    const result = await BettaFishApiClient.reportStatus(server);
    if (result.ok && result.data !== null) {
      this.reportStatus = result.data;
    }
  }

  // ========== 生成报告 + SSE ==========

  private async onGenerate(): Promise<void> {
    const server = this.server;
    if (server === null) {
      promptAction.showToast({ message: '服务器未配置' });
      return;
    }
    if (this.generating) return;
    this.generating = true;
    this.errorText = '';
    this.logs = [];
    this.progress = 0;
    this.phaseText = '正在生成报告…';
    const result = await BettaFishApiClient.reportGenerate(server, this.query.length > 0 ? this.query : '舆情分析');
    this.generating = false;
    if (!result.ok || result.data === null || result.data.taskId.length === 0) {
      this.errorText = result.message;
      this.phaseText = '';
      return;
    }
    this.taskId = result.data.taskId;
    this.taskState = 'running';
    this.recordHistory('running', 0);
    this.sse.connect(server, this.taskId,
      (event: BettaReportEvent): void => { this.onSseEvent(event); },
      (event: BettaReportEvent): void => { this.onSseTerminal(event); },
      (message: string): void => { this.onSseFallback(message); });
  }

  private onSseEvent(event: BettaReportEvent): void {
    if (event.type === 'progress') {
      const p = event.payload.progress;
      if (typeof p === 'number') {
        this.progress = p;
      }
    } else if (event.type === 'stage') {
      const message = event.payload.message;
      this.phaseText = typeof message === 'string' && (message as string).length > 0 ?
        message as string : BettaFishApiClient.strField(event.payload, 'stage');
    } else if (event.type === 'log') {
      const line = event.payload.line;
      if (typeof line === 'string' && (line as string).length > 0) {
        this.appendLog(line as string);
      }
    } else if (event.type === 'status') {
      const status = event.payload.status;
      if (typeof status === 'string') {
        this.taskState = status as string;
      }
      const p = event.payload.progress;
      if (typeof p === 'number') {
        this.progress = p;
      }
    }
  }

  private onSseTerminal(event: BettaReportEvent): void {
    this.taskState = event.type;
    if (event.type === 'completed') {
      this.progress = 100;
      this.phaseText = '报告生成完成';
      this.recordHistory('completed', 100);
      this.showReportDialog();
    } else {
      const message = event.payload.message;
      this.errorText = typeof message === 'string' ? message as string : '任务已结束（' + event.type + '）';
      this.phaseText = '';
      this.recordHistory(event.type, this.progress);
    }
  }

  private onSseFallback(message: string): void {
    this.errorText = message;
    this.startFallbackPolling();
  }

  private startFallbackPolling(): void {
    if (this.fallbackTimer >= 0) return;
    this.fallbackTimer = setInterval(() => {
      this.pollTask();
    }, 2000);
  }

  private async pollTask(): Promise<void> {
    const server = this.server;
    if (server === null || this.taskId.length === 0) return;
    const result = await BettaFishApiClient.reportProgress(server, this.taskId);
    if (!result.ok || result.data === null) return;
    const task: BettaReportTask = result.data;
    this.progress = task.progress;
    if (task.status === 'completed' || task.status === 'error' || task.status === 'cancelled') {
      if (this.fallbackTimer >= 0) {
        clearInterval(this.fallbackTimer);
        this.fallbackTimer = -1;
      }
      if (task.status === 'completed') {
        this.taskState = 'completed';
        this.progress = 100;
        this.phaseText = '报告生成完成';
        this.recordHistory('completed', 100);
        this.showReportDialog();
      } else {
        this.taskState = task.status;
        this.errorText = task.errorMessage.length > 0 ? task.errorMessage : '任务已结束（' + task.status + '）';
        this.recordHistory(task.status, task.progress);
      }
    }
  }

  private appendLog(line: string): void {
    if (this.logs.length >= 200) {
      this.logs = this.logs.slice(this.logs.length - 180);
    }
    const next: string[] = this.logs.slice();
    next.push(line);
    this.logs = next;
  }

  private recordHistory(status: string, progress: number): void {
    const server = this.server;
    if (server === null || this.taskId.length === 0) return;
    const item = new BettaHistoryItem();
    item.taskId = this.taskId;
    item.query = this.query;
    item.status = status;
    item.progress = progress;
    item.baseUrl = BettaFishApiClient.buildBaseUrl(server);
    item.serverId = server.id;
    item.createdAt = Date.now();
    BettaFishStore.upsertHistory(item).catch(() => {
    });
  }

  private showReportDialog(): void {
    promptAction.showDialog({
      title: '报告生成完成',
      message: '点击查看生成的舆情分析报告',
      buttons: [
        { text: '稍后看', color: '#888888' },
        { text: '查看报告', color: '#22C55E' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.openReport();
      }
    }).catch(() => {
    });
  }

  private openReport(): void {
    const server = this.server;
    AppNavigator.push('pages/BettaFishReportView',
      new BettaFishReportRouteParams(this.taskId,
        server !== null ? server.id : '',
        server !== null ? server.name : '',
        this.query));
  }

  private async onCancel(): Promise<void> {
    const server = this.server;
    if (server === null || this.taskId.length === 0) {
      promptAction.showToast({ message: '暂无进行中的任务' });
      return;
    }
    this.sse.stop();
    const result = await BettaFishApiClient.reportCancel(server, this.taskId);
    promptAction.showToast({ message: result.ok ? '已请求取消' : '取消失败：' + result.message });
    this.taskState = 'cancelled';
    this.recordHistory('cancelled', this.progress);
  }

  // ========== UI ==========

  @Builder
  engineRows() {
    if (this.engines.length === 0) {
      Text('暂无引擎状态')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
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

  build() {
    Column() {
      TopBar({ title: '舆情分析进度', subtitle: this.query.length > 0 ? this.query : '等待生成报告', showBack: true }) {
        Column()
      }
      Scroll() {
        Column({ space: 12 }) {
          // 查询信息
          Column({ space: 6 }) {
            Text('分析主题')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')
            Text(this.query.length > 0 ? this.query : '（未提供主题）')
              .fontSize(this.themeState.palette.fsBase)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 引擎状态
          Column({ space: 8 }) {
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
          .padding(14)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 报告就绪状态
          if (this.reportStatus !== null) {
            Column({ space: 6 }) {
              Row() {
                Text(this.reportStatus.enginesReady ? '✅ 引擎已就绪，可生成报告' : '⏳ 引擎研究中，等待就绪')
                  .fontSize(this.themeState.palette.fsBase)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.reportStatus.enginesReady ? this.themeState.palette.primary :
                    this.themeState.palette.textSecondary)
                  .fontWeight(FontWeight.Medium)
                Blank()
                if (this.reportStatus.currentTask.length > 0) {
                  Text('当前任务存在')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.danger)
                }
              }
              .width('100%')
              if (this.reportStatus.missingFiles.length > 0) {
                Text('缺少输入文件：' + this.reportStatus.missingFiles.join('、'))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.danger)
                  .width('100%')
              }
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          }

          // 生成/进度区
          if (this.taskId.length === 0) {
            Button(this.generating ? '正在生成…' : '📄 生成报告')
              .width('100%')
              .height(42)
              .fontSize(this.themeState.palette.fsBase)
              .fontFamily(this.themeState.palette.fontSans)
              .backgroundColor(this.themeState.palette.primary)
              .enabled(!this.generating && this.reportStatus !== null && this.reportStatus.enginesReady)
              .onClick(() => { this.onGenerate(); })
          } else {
            Column({ space: 10 }) {
              Row() {
                Text(this.phaseText.length > 0 ? this.phaseText : '任务进行中…')
                  .fontSize(this.themeState.palette.fsBase)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(this.progress.toString() + '%')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
              }
              .width('100%')
              Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
                .width('100%')
                .color(this.themeState.palette.primary)
              if (this.logs.length > 0) {
                Column() {
                  Text('实时日志')
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .width('100%')
                  ForEach(this.logs, (line: string) => {
                    Text(line)
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textSecondary)
                      .width('100%')
                      .margin({ top: 2 })
                  }, (line: string) => line)
                }
                .width('100%')
              }
              Row({ space: 10 }) {
                Button('取消任务')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .backgroundColor(Color.Transparent)
                  .fontColor(this.themeState.palette.danger)
                  .border({ width: 1, color: this.themeState.palette.danger })
                  .layoutWeight(1)
                  .height(38)
                  .enabled(this.taskState === 'running' || this.taskState === '')
                  .onClick(() => { this.onCancel(); })
                Button('查看报告')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .backgroundColor(this.themeState.palette.primary)
                  .layoutWeight(1)
                  .height(38)
                  .enabled(this.taskState === 'completed')
                  .onClick(() => { this.openReport(); })
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          }

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.danger)
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(this.themeState.palette.primaryDim)
          }
          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 14 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

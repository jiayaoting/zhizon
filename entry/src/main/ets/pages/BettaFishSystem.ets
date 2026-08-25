// 智子 - 微舆 系统管理页：系统启停 + 四引擎状态 + 报告引擎状态 + 日志查看
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { BettaEngineStatusCard } from '../components/BettaEngineStatusCard';
import { BettaFishStore } from '../service/BettaFishStore';
import { BettaFishApiClient } from '../service/BettaFishApiClient';
import { BettaServerConfig, BettaSystemStatus, BettaEngineStatus, BettaReportStatus } from '../common/BettaFishModels';

@ComponentV2
@Entry
export struct BettaFishSystemPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local server: BettaServerConfig | null = null;
  @Local sysStatus: BettaSystemStatus | null = null;
  @Local engines: BettaEngineStatus[] = [];
  @Local reportStatus: BettaReportStatus | null = null;
  @Local logTitle: string = '';
  @Local logText: string = '';
  @Local busy: boolean = false;
  private pollTimer: number = -1;

  aboutToAppear(): void {
    this.loadServer();
    this.startPolling();
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async loadServer(): Promise<void> {
    try {
      this.server = await BettaFishStore.getCurrent();
    } catch (e) {
      this.server = null;
    }
  }

  private startPolling(): void {
    this.refreshAll();
    if (this.pollTimer < 0) {
      this.pollTimer = setInterval(() => {
        this.refreshAll();
      }, 5000);
    }
  }

  private async refreshAll(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    const statusResult = await BettaFishApiClient.systemStatus(server);
    if (statusResult.ok && statusResult.data !== null) {
      this.sysStatus = statusResult.data;
    }
    const engineResult = await BettaFishApiClient.engineStatus(server);
    if (engineResult.ok && engineResult.data !== null) {
      this.engines = engineResult.data;
    }
    const reportResult = await BettaFishApiClient.reportStatus(server);
    if (reportResult.ok && reportResult.data !== null) {
      this.reportStatus = reportResult.data;
    }
  }

  private async onStart(): Promise<void> {
    const server = this.server;
    if (server === null) {
      promptAction.showToast({ message: '服务器未配置' });
      return;
    }
    if (this.busy) return;
    this.busy = true;
    const result = await BettaFishApiClient.systemStart(server);
    this.busy = false;
    if (result.ok && result.data !== null) {
      promptAction.showToast({ message: result.data.message.length > 0 ? result.data.message : '已发送启动指令' });
      if (result.data.logs.length > 0) {
        this.logTitle = '启动日志';
        this.logText = result.data.logs;
      }
    } else {
      promptAction.showToast({ message: '启动失败：' + result.message });
    }
    this.refreshAll();
  }

  private async onShutdown(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    promptAction.showDialog({
      title: '关停系统',
      message: '确认优雅关停 BettaFish 系统？运行中的分析任务会终止。',
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '关停', color: '#E84026' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.busy = true;
        const r = await BettaFishApiClient.systemShutdown(server);
        this.busy = false;
        if (r.ok && r.data !== null) {
          promptAction.showToast({ message: r.data.message.length > 0 ? r.data.message : '已发送关停指令' });
        } else {
          promptAction.showToast({ message: '关停失败：' + r.message });
        }
        this.refreshAll();
      }
    }).catch(() => {
    });
  }

  private async onLoadEngineLog(appName: string): Promise<void> {
    const server = this.server;
    if (server === null) return;
    this.logTitle = appName.toUpperCase() + ' 引擎输出';
    this.logText = '加载中…';
    const result = await BettaFishApiClient.engineOutput(server, appName);
    if (result.ok && result.data !== null) {
      this.logText = result.data;
    } else {
      this.logText = '加载失败：' + result.message;
    }
  }

  private async onLoadReportLog(): Promise<void> {
    const server = this.server;
    if (server === null) return;
    this.logTitle = '报告引擎日志';
    this.logText = '加载中…';
    const result = await BettaFishApiClient.reportLog(server);
    if (result.ok && result.data !== null) {
      this.logText = result.data;
    } else {
      this.logText = '加载失败：' + result.message;
    }
  }

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
      TopBar({ title: '微舆 · 系统管理', subtitle: 'BettaFish 系统与引擎控制', showBack: true }) {
        Column()
      }
      Scroll() {
        Column({ space: 12 }) {
          // 系统状态
          Column({ space: 10 }) {
            Row() {
              Text(this.sysStatus !== null && this.sysStatus.started ? '🟢 系统已启动' :
                (this.sysStatus !== null && this.sysStatus.starting ? '🟡 系统启动中' : '⚪ 系统未启动'))
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('5 秒自动刷新')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
            Row({ space: 10 }) {
              Button(this.busy ? '处理中…' : '🚀 启动系统')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .backgroundColor(this.themeState.palette.primary)
                .layoutWeight(1)
                .height(40)
                .enabled(!this.busy)
                .onClick(() => { this.onStart(); })
              Button('⏹ 关停系统')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .backgroundColor(Color.Transparent)
                .fontColor(this.themeState.palette.danger)
                .border({ width: 1, color: this.themeState.palette.danger })
                .layoutWeight(1)
                .height(40)
                .enabled(!this.busy)
                .onClick(() => { this.onShutdown(); })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 引擎状态
          Column({ space: 8 }) {
            Text('四引擎状态')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            if (this.engines.length === 0) {
              Text('暂无引擎状态（系统未启动或无数据）')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
            } else {
              this.engineRows()
            }
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 报告引擎状态
          if (this.reportStatus !== null) {
            Column({ space: 6 }) {
              Text('报告引擎')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Text('初始化：' + (this.reportStatus.initialized ? '✅' : '❌') +
                ' · 引擎就绪：' + (this.reportStatus.enginesReady ? '✅' : '❌'))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textSecondary)
                .width('100%')
              if (this.reportStatus.missingFiles.length > 0) {
                Text('缺少输入文件：' + this.reportStatus.missingFiles.join('、'))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.danger)
                  .width('100%')
              }
              Button('查看报告引擎日志')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .backgroundColor(Color.Transparent)
                .fontColor(this.themeState.palette.primary)
                .border({ width: 1, color: this.themeState.palette.primary })
                .width('100%')
                .height(36)
                .onClick(() => { this.onLoadReportLog(); })
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          }

          // 引擎输出日志入口
          Column({ space: 8 }) {
            Text('引擎输出日志')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Row({ space: 8 }) {
              ForEach(['query', 'media', 'insight'], (app: string) => {
                Text(app.toUpperCase())
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor(this.themeState.palette.primaryDim)
                  .margin({ right: 4 })
                  .onClick(() => { this.onLoadEngineLog(app); })
              }, (app: string) => app)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 日志展示
          if (this.logText.length > 0) {
            Column({ space: 6 }) {
              Row() {
                Text(this.logTitle.length > 0 ? this.logTitle : '日志')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Blank()
                Text('清空')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .onClick(() => { this.logText = ''; })
              }
              .width('100%')
              Text(this.logText)
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily('monospace')
                .fontColor(this.themeState.palette.textSecondary)
                .width('100%')
            }
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
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

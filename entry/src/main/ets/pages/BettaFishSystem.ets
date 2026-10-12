// 智子 - 微舆 系统管理页：系统启停 + 四引擎状态 + 报告引擎状态 + 日志查看
// v10：内容卡改 bgSurface + 发丝边框；系统状态用语义点 + 淡底；关停为 danger 语义；日志用 fontMono token。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { BettaEngineStatusCard } from '../components/BettaEngineStatusCard';
import { BettaFishStore } from '../service/betta/BettaFishStore';
import { BettaFishApiClient } from '../service/betta/BettaFishApiClient';
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
        { text: '取消', color: this.themeState.palette.textSecondary },
        { text: '关停', color: this.themeState.palette.danger }
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

  // 系统状态语义色
  private sysColor(): string {
    if (this.sysStatus !== null && this.sysStatus.started) return this.themeState.palette.success;
    if (this.sysStatus !== null && this.sysStatus.starting) return this.themeState.palette.warning;
    return this.themeState.palette.textTertiary;
  }

  private sysLabel(): string {
    if (this.sysStatus !== null && this.sysStatus.started) return '系统已启动';
    if (this.sysStatus !== null && this.sysStatus.starting) return '系统启动中';
    return '系统未启动';
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

  build() {
    Column() {
      TopBar({ title: '微舆 · 系统管理', subtitle: 'BettaFish 系统与引擎控制', showBack: true }) {
        Column()
      }
      Scroll() {
        Column({ space: this.themeState.palette.cardGap }) {
          // 系统状态（语义点 + 淡底状态区）
          Column({ space: this.themeState.palette.sp3 }) {
            Row() {
              Row({ space: this.themeState.palette.sp2 }) {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(this.sysColor())
                Text(this.sysLabel())
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
              }
              .layoutWeight(1)
              .alignItems(VerticalAlign.Center)
              Text('5 秒自动刷新')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Row({ space: this.themeState.palette.sp3 }) {
              Button(this.busy ? '处理中…' : '启动系统')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primaryOnColor)
                .backgroundColor(this.themeState.palette.primary)
                .borderRadius(this.themeState.palette.radiusCapsule)
                .layoutWeight(1)
                .height(44)
                .enabled(!this.busy)
                .onClick(() => { this.onStart(); })
              Button('关停系统')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.danger)
                .backgroundColor(this.themeState.palette.dangerBg)
                .borderRadius(this.themeState.palette.radiusCapsule)
                .layoutWeight(1)
                .height(44)
                .enabled(!this.busy)
                .onClick(() => { this.onShutdown(); })
            }
            .width('100%')
          }
          .width('100%')
          .padding(this.themeState.palette.sp4)
          .borderRadius(this.themeState.palette.radiusLg)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })

          // 引擎状态
          Column({ space: this.themeState.palette.sp2 }) {
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
          .padding(this.themeState.palette.sp4)
          .borderRadius(this.themeState.palette.radiusLg)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })

          // 报告引擎状态
          if (this.reportStatus !== null) {
            Column({ space: 6 }) {
              Text('报告引擎')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Row({ space: this.themeState.palette.sp1 }) {
                Text('初始化：' + (this.reportStatus.initialized ? '是' : '否'))
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.reportStatus.initialized ? this.themeState.palette.success :
                    this.themeState.palette.danger)
                  .fontWeight(FontWeight.Medium)
                Text('·')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                Text('引擎就绪：' + (this.reportStatus.enginesReady ? '是' : '否'))
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.reportStatus.enginesReady ? this.themeState.palette.success :
                    this.themeState.palette.danger)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              if (this.reportStatus.missingFiles.length > 0) {
                Text('缺少输入文件：' + this.reportStatus.missingFiles.join('、'))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.danger)
                  .width('100%')
                  .padding(this.themeState.palette.sp2)
                  .borderRadius(this.themeState.palette.radiusSm)
                  .backgroundColor(this.themeState.palette.dangerBg)
              }
              Button('查看报告引擎日志')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .backgroundColor(this.themeState.palette.bgSurface2)
                .borderRadius(this.themeState.palette.radiusCapsule)
                .width('100%')
                .height(44)
                .onClick(() => { this.onLoadReportLog(); })
            }
            .width('100%')
            .padding(this.themeState.palette.sp4)
            .borderRadius(this.themeState.palette.radiusLg)
            .backgroundColor(this.themeState.palette.bgSurface)
            .border({ width: 0.5, color: this.themeState.palette.divider })
          }

          // 引擎输出日志入口
          Column({ space: this.themeState.palette.sp2 }) {
            Text('引擎输出日志')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Row({ space: this.themeState.palette.sp2 }) {
              ForEach(['query', 'media', 'insight'], (app: string) => {
                Row({ space: 6 }) {
                  if (USE_SYMBOL_ICONS) {
                    SymbolGlyph(AppIcons.doc)
                      .fontSize(16)
                      .fontColor([this.themeState.palette.primary])
                  } else {
                    Text(AppIcons.docEmoji)
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                  }
                  Text(app.toUpperCase())
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                }
                .height(44)
                .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3 })
                .borderRadius(this.themeState.palette.radiusCapsule)
                .backgroundColor(this.themeState.palette.primaryBg)
                .alignItems(VerticalAlign.Center)
                .onClick(() => { this.onLoadEngineLog(app); })
              }, (app: string) => app)
            }
            .width('100%')
          }
          .width('100%')
          .padding(this.themeState.palette.sp4)
          .borderRadius(this.themeState.palette.radiusLg)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })

          // 日志展示
          if (this.logText.length > 0) {
            Column({ space: this.themeState.palette.sp2 }) {
              Row() {
                Text(this.logTitle.length > 0 ? this.logTitle : '日志')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Blank()
                Text('清空')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .height(44)
                  .padding({ left: this.themeState.palette.sp2, right: this.themeState.palette.sp2 })
                  .textAlign(TextAlign.Center)
                  .onClick(() => { this.logText = ''; })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              Text(this.logText)
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontMono)
                .fontColor(this.themeState.palette.textSecondary)
                .width('100%')
                .padding(this.themeState.palette.sp3)
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(this.themeState.palette.bgSurface2)
            }
            .width('100%')
            .padding(this.themeState.palette.sp4)
            .borderRadius(this.themeState.palette.radiusLg)
            .backgroundColor(this.themeState.palette.bgSurface)
            .border({ width: 0.5, color: this.themeState.palette.divider })
          }
          Column().height(this.themeState.palette.sp5)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp3 })
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

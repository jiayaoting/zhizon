// 智子 - 微舆 报告查看页：WebView 渲染 HTML 报告 + 导出（HTML/MD/PDF）+ 复制链接
// v10：ArkWeb 容器收进 bgSurface 圆角卡（radiusMd，发丝边框）；顶栏动作改矢量图标 + 44vp 触控目标。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { AppNavigator } from '../common/AppNavigator';
import { BettaFishStore } from '../service/betta/BettaFishStore';
import { BettaFishApiClient } from '../service/betta/BettaFishApiClient';
import { BettaServerConfig, BettaHistoryItem } from '../common/BettaFishModels';
import { BettaFishReportRouteParams } from '../common/Navigation';

@ComponentV2
@Entry
export struct BettaFishReportViewPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local server: BettaServerConfig | null = null;
  @Local taskId: string = '';
  @Local query: string = '';
  @Local exporting: boolean = false;
  @Local loadFailed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private params: BettaFishReportRouteParams | null = null;

  aboutToAppear(): void {
    this.params = AppNavigator.getParam('pages/BettaFishReportView') as BettaFishReportRouteParams | null;
    if (this.params !== null) {
      this.taskId = this.params.taskId;
      this.query = this.params.query;
    }
    this.loadReport();
  }

  private async loadReport(): Promise<void> {
    try {
      this.server = await BettaFishStore.getCurrent();
    } catch (e) {
      this.server = null;
    }
    if (this.server === null || this.taskId.length === 0) {
      promptAction.showToast({ message: '无法加载报告：服务器未配置' });
      return;
    }
    const url: string = BettaFishApiClient.buildBaseUrl(this.server) + '/api/report/result/' + this.taskId;
    this.controller.loadUrl(url);
  }

  private reportUrl(): string {
    if (this.server === null || this.taskId.length === 0) return '';
    return BettaFishApiClient.buildBaseUrl(this.server) + '/api/report/result/' + this.taskId;
  }

  private async onCopyLink(): Promise<void> {
    const url = this.reportUrl();
    if (url.length === 0) {
      promptAction.showToast({ message: '报告地址不可用' });
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '报告链接已复制' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // ========== 导出 ==========

  private async onExport(kind: string): Promise<void> {
    const server = this.server;
    if (server === null || this.taskId.length === 0) {
      promptAction.showToast({ message: '服务器未配置' });
      return;
    }
    if (this.exporting) return;
    this.exporting = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const dir: string = ctx.filesDir + '/bettafish';
      try {
        fs.mkdirSync(dir);
      } catch (e) {
      }
      let remotePath: string;
      let fileName: string;
      let suffix: string;
      if (kind === 'md') {
        remotePath = '/api/report/export/md/' + this.taskId;
        fileName = this.taskId + '.md';
        suffix = '.md';
      } else if (kind === 'pdf') {
        remotePath = '/api/report/export/pdf/' + this.taskId;
        fileName = this.taskId + '.pdf';
        suffix = '.pdf';
      } else {
        remotePath = '/api/report/download/' + this.taskId;
        fileName = this.taskId + '.html';
        suffix = '.html';
      }
      const localPath: string = dir + '/' + fileName;
      const result = await BettaFishApiClient.downloadLocal(server, remotePath, localPath);
      if (!result.ok || result.data === null) {
        if (kind === 'pdf') {
          promptAction.showToast({ message: 'PDF 导出失败（服务端可能缺少 Pango），可改用 MD/HTML' });
        } else {
          promptAction.showToast({ message: '导出失败：' + result.message });
        }
        return;
      }
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      options.fileSuffixChoices = [suffix];
      const uris: string[] = await documentPicker.save(options);
      if (uris.length > 0) {
        await this.markSaved(kind, localPath);
        promptAction.showToast({ message: '已导出 ' + fileName });
      }
    } catch (e) {
      promptAction.showToast({ message: '导出失败，请重试' });
    } finally {
      this.exporting = false;
    }
  }

  private async markSaved(kind: string, localPath: string): Promise<void> {
    try {
      const history = await BettaFishStore.listHistory(200);
      let found: BettaHistoryItem | null = null;
      for (let i: number = 0; i < history.length; i++) {
        if (history[i].taskId === this.taskId) {
          found = history[i];
          break;
        }
      }
      if (found === null) {
        found = new BettaHistoryItem();
        found.taskId = this.taskId;
        found.query = this.query;
        found.status = 'completed';
        found.createdAt = Date.now();
        if (this.server !== null) {
          found.baseUrl = BettaFishApiClient.buildBaseUrl(this.server);
          found.serverId = this.server.id;
        }
      }
      found.savedAt = Date.now();
      if (kind === 'md') found.localMdPath = localPath;
      else if (kind === 'pdf') found.localPdfPath = localPath;
      else found.localHtmlPath = localPath;
      await BettaFishStore.upsertHistory(found);
    } catch (e) {
    }
  }

  // 顶栏动作：复制链接（矢量图标 + 44vp 触控目标）
  @Builder
  copyLinkAction() {
    Row({ space: this.themeState.palette.sp1 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.link)
          .fontSize(18)
          .fontColor([this.themeState.palette.primary])
      } else {
        Text(AppIcons.linkEmoji)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
      }
      Text('复制链接')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
    }
    .height(44)
    .padding({ left: this.themeState.palette.sp2, right: this.themeState.palette.sp2 })
    .alignItems(VerticalAlign.Center)
    .accessibilityText('复制链接')
    .onClick(() => { this.onCopyLink(); })
  }

  // 加载失败：插画 + 原因 + CTA
  @Builder
  errorState() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('⚠️')
        .fontSize(48)
        .fontFamily(this.themeState.palette.fontSans)
      Text('报告加载失败')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text('请确认服务器可达，或从历史列表重新打开')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      Text('重试')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .fontWeight(FontWeight.Medium)
        .height(44)
        .padding({ left: 24, right: 24 })
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.themeState.palette.primary)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.loadFailed = false;
          this.loadReport();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(this.themeState.palette.sp5)
  }

  private horizontalPadding(): string {
    return this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg;
  }

  build() {
    Column() {
      TopBar({ title: '舆情报告', subtitle: this.query.length > 0 ? this.query : this.taskId, showBack: true }) {
        this.copyLinkAction()
      }
      if (this.loadFailed) {
        Column() {
          this.errorState()
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ left: this.horizontalPadding(), right: this.horizontalPadding(), top: this.themeState.palette.sp3,
          bottom: this.themeState.palette.sp3 })
        .borderRadius(this.themeState.palette.radiusMd)
        .backgroundColor(this.themeState.palette.bgSurface)
        .border({ width: 0.5, color: this.themeState.palette.divider })
      } else {
        Column() {
          Web({ src: '', controller: this.controller })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .width('100%')
            .layoutWeight(1)
            .onErrorReceive(() => {
              this.loadFailed = true;
            })
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ left: this.horizontalPadding(), right: this.horizontalPadding(), top: this.themeState.palette.sp3,
          bottom: this.themeState.palette.sp3 })
        .borderRadius(this.themeState.palette.radiusMd)
        .backgroundColor(this.themeState.palette.bgSurface)
        .border({ width: 0.5, color: this.themeState.palette.divider })
        .clip(true)
      }

      // 底部导出栏
      Row({ space: this.themeState.palette.sp3 }) {
        Button(this.exporting ? '导出中…' : '下载 HTML')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .fontColor(this.themeState.palette.textPrimary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .layoutWeight(1)
          .height(44)
          .enabled(!this.exporting)
          .onClick(() => { this.onExport('html'); })
        Button('导出 MD')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .fontColor(this.themeState.palette.textPrimary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .layoutWeight(1)
          .height(44)
          .enabled(!this.exporting)
          .onClick(() => { this.onExport('md'); })
        Button('导出 PDF')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .layoutWeight(1)
          .height(44)
          .enabled(!this.exporting)
          .onClick(() => { this.onExport('pdf'); })
      }
      .width('100%')
      .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
        top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp3 })
      .border({ width: { top: 0.5 }, color: this.themeState.palette.divider })
      .backgroundColor(this.themeState.palette.bgSurface)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

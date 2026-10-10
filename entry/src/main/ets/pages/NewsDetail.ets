// 智子 - 热榜条目详情页（ArkWeb 原文 + 收藏/已读 + AI 摘要/翻译/问AI + 朗读）
// 设计文档：doc/newsnow-redesign.md §9.3
import { webview } from '@kit.ArkWeb';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { HotEntry, HotItem, HotDetailRouteParams } from '../common/HotModels';
import { NewsRepository } from '../service/NewsRepository';
import { HotArticleCacheEntry } from '../service/DatabaseHelper';
import { NewsAiService } from '../service/NewsAiService';
import { SpeechService } from '../service/SpeechService';
import { LlmConfig, LlmModelEntry, ChatMessage, LlmResult } from '../common/LlmModels';

enum AiPanelKind {
  NONE = 0,
  SUMMARY = 1,
  TRANSLATE = 2,
  ASK = 3
}

// 正文缓存 HTML → 纯文本（离线/抽取失败时作为 AI 上下文兜底）
function htmlToText(html: string): string {
  const stripped: string = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ');
  return stripped.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
}

@ComponentV2
@Entry
export struct NewsDetailPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 路由参数（HotDetailRouteParams 序列化纯数据）
  @Local itemKey: string = '';
  @Local sourceId: string = '';
  @Local sourceName: string = '';
  @Local title: string = '';
  @Local url: string = '';
  @Local info: string = '';
  @Local favorited: boolean = false;
  @Local webFailed: boolean = false;
  @Local offlineMode: boolean = false;
  // AI 面板状态
  @Local aiPanel: AiPanelKind = AiPanelKind.NONE;
  @Local aiText: string = '';
  @Local aiBusy: boolean = false;
  @Local aiError: string = '';
  @Local askInput: string = '';
  // 问AI 历史（只保留最近 4 轮）
  @Local askHistory: ChatMessage[] = [];
  // 正文纯文本（ArkWeb JS 抽取，供 AI 摘要/翻译/问答）
  @Local bodyText: string = '';
  // 朗读状态
  @Local speaking: boolean = false;
  // 阅读缩放
  @Local zoomFactor: number = 1.0;
  // 最近一次 AI 调用 token 消耗
  @Local lastTokens: number = 0;
  // 模型选择（热榜专属模型，跟随全局时为空）
  @Local modelName: string = '跟随全局';
  @Local models: LlmModelEntry[] = [];
  @Local modelSheet: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: HotDetailRouteParams | null =
      AppNavigator.getParam('pages/NewsDetail') as HotDetailRouteParams | null;
    // 注意：router 参数为序列化纯数据对象，类方法不可用，需直接读字段
    if (params !== null) {
      this.itemKey = params.key;
      this.sourceId = params.sourceId;
      this.sourceName = params.sourceName;
      this.title = params.title;
      this.url = params.url;
      this.info = params.info;
    }
    this.loadState();
    this.loadModelName();
  }

  aboutToDisappear(): void {
    SpeechService.stopSpeaking();
  }

  private async loadState(): Promise<void> {
    if (this.itemKey.length === 0) return;
    try {
      this.favorited = await NewsRepository.isFavorite(this.itemKey);
      await NewsRepository.markRead(this.itemKey);
    } catch (e) {
    }
  }

  private async loadModelName(): Promise<void> {
    try {
      this.modelName = await NewsAiService.getActiveModelName();
    } catch (e) {
      this.modelName = '未配置模型';
    }
  }

  // 路由参数 → 收藏用条目（key = `sourceId:itemId`）
  private entryOf(): HotEntry {
    const idx: number = this.itemKey.indexOf(':');
    const itemId: string = idx < 0 ? this.itemKey : this.itemKey.substring(idx + 1);
    const item: HotItem = new HotItem(itemId, this.title, this.url, this.url, 0, this.info);
    return new HotEntry(this.itemKey, item, this.sourceId, this.sourceName);
  }

  private async toggleFavorite(): Promise<void> {
    if (this.itemKey.length === 0) {
      promptAction.showToast({ message: '该条目暂不支持收藏' });
      return;
    }
    try {
      const fav: boolean = await NewsRepository.toggleFavorite(this.entryOf());
      this.favorited = fav;
      promptAction.showToast({ message: fav ? '已收藏' : '已取消收藏' });
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试' });
    }
  }

  // ==================== Web 正文 ====================

  // 阅读字号缩放（ArkWeb zoom）
  private adjustZoom(delta: number): void {
    let next: number = this.zoomFactor + delta;
    if (next < 0.6) next = 0.6;
    if (next > 1.8) next = 1.8;
    this.zoomFactor = next;
    try {
      this.controller.zoom(this.zoomFactor);
    } catch (e) {
    }
  }

  // 深色模式：向原文注入反色 CSS
  private injectDarkCss(): void {
    if (!this.themeState.isDark) return;
    const css: string = 'html{filter:invert(0.9) hue-rotate(180deg)!important;background:#0a0e1a}img,video{filter:invert(1) hue-rotate(180deg)!important}';
    const script: string = '(function(){var s=document.createElement("style");s.id="zhizon-dark";s.textContent="' + css + '";document.head.appendChild(s);})()';
    try {
      this.controller.runJavaScript(script, (err: BusinessError, result: string): void => {
      });
    } catch (e) {
    }
  }

  // 抽取正文纯文本（供 AI 摘要/翻译/问答；热榜无摘要字段）
  private extractBodyText(): void {
    try {
      this.controller.runJavaScript('document.body ? document.body.innerText : ""',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) return;
          const text: string = result === undefined ? '' : result;
          const trimmed: string = text.trim();
          if (trimmed.length > 0) {
            this.bodyText = NewsAiService.truncate(trimmed);
          }
        });
    } catch (e) {
    }
  }

  // AI 上下文正文：优先网页抽取，其次离线缓存抽取，最后用热度描述兜底
  private aiBody(): string {
    const text: string = this.bodyText.trim();
    if (text.length > 0) return NewsAiService.truncate(text);
    return this.info;
  }

  // ==================== AI 能力 ====================

  private panelTitle(): string {
    if (this.aiPanel === AiPanelKind.SUMMARY) return '🤖 AI 摘要';
    if (this.aiPanel === AiPanelKind.TRANSLATE) return '🌐 AI 翻译';
    if (this.aiPanel === AiPanelKind.ASK) return '💬 问 AI';
    return '';
  }

  private closePanel(): void {
    this.aiPanel = AiPanelKind.NONE;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = false;
  }

  // 开始一次 AI 调用（摘要/翻译）
  private async runAi(panel: AiPanelKind,
    builder: (config: LlmConfig, onDelta: (d: string) => void) => Promise<LlmResult>): Promise<void> {
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = panel;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = true;
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    const result: LlmResult = await builder(config, (d: string): void => {
      this.aiText = this.aiText + d;
    });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    }
    if (!result.success) {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    }
  }

  private onSummary(): void {
    this.runAi(AiPanelKind.SUMMARY, (config: LlmConfig, onDelta: (d: string) => void): Promise<LlmResult> => {
      return NewsAiService.summarize(config, this.title, this.aiBody(), onDelta);
    });
  }

  // 外文/中文正文统一翻译成简体中文（翻译模型可单独记忆）
  private async onTranslate(): Promise<void> {
    const config: LlmConfig | null = await NewsAiService.getTranslateConfig();
    if (config === null) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = AiPanelKind.TRANSLATE;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = true;
    const result: LlmResult = await NewsAiService.translate(config, this.title, this.aiBody(), true,
      (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    } else {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : '翻译失败，请重试';
    }
  }

  private async onAskSend(): Promise<void> {
    const q: string = this.askInput.trim();
    if (q.length === 0 || this.aiBusy) return;
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = AiPanelKind.ASK;
    this.aiError = '';
    this.aiText = '';
    this.aiBusy = true;
    this.askHistory = this.askHistory.concat([ChatMessage.create('user', q)]);
    this.askInput = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    const result: LlmResult = await NewsAiService.ask(config, this.title, this.aiBody(),
      this.askHistory, q, (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    }
    if (!result.success) {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    } else {
      // 保留最近 4 轮问答
      this.askHistory = this.askHistory.concat([ChatMessage.create('assistant', result.content)]);
      if (this.askHistory.length > 8) {
        this.askHistory = this.askHistory.slice(this.askHistory.length - 8);
      }
    }
  }

  // ==================== 模型选择 ====================

  private modelLabel(m: LlmModelEntry): string {
    return m.displayName.length > 0 ? m.displayName : m.model;
  }

  private async openModelSheet(): Promise<void> {
    try {
      this.models = await NewsAiService.listModels();
    } catch (e) {
      this.models = [];
    }
    this.modelSheet = true;
  }

  // id 为空字符串 = 恢复「跟随全局」
  private async pickModel(id: string): Promise<void> {
    try {
      await NewsAiService.selectModel(id);
    } catch (e) {
    }
    this.modelSheet = false;
    await this.loadModelName();
    promptAction.showToast({ message: '当前模型：' + this.modelName });
  }

  // ==================== 离线正文缓存 ====================

  // 页面加载完成：抓取当前页面 HTML 存入缓存（供离线/弱网时回退阅读）
  private cacheArticleHtml(): void {
    if (this.url.length === 0) return;
    try {
      this.controller.runJavaScript('document.documentElement.outerHTML',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) return;
          const html: string = result === undefined ? '' : result;
          // 空页/过小页面不缓存；过大页面截断，避免数据库膨胀
          if (html.length < 500 || html.length > 800 * 1024) return;
          NewsRepository.saveArticleCache(this.url, this.title, html).catch(() => {
          });
        });
    } catch (e) {
    }
  }

  // 加载失败：尝试用缓存 HTML 回退（离线阅读）
  private useCachedArticle(): void {
    if (this.url.length === 0) {
      this.webFailed = true;
      return;
    }
    NewsRepository.getArticleCache(this.url).then((cached: HotArticleCacheEntry | null) => {
      if (cached !== null && cached.html.length > 0) {
        try {
          this.offlineMode = true;
          if (this.bodyText.trim().length === 0) {
            const text: string = htmlToText(cached.html);
            if (text.length > 0) this.bodyText = NewsAiService.truncate(text);
          }
          this.controller.loadData(cached.html, 'text/html', 'UTF-8', this.url);
        } catch (e) {
          this.webFailed = true;
        }
      } else {
        this.webFailed = true;
      }
    }).catch(() => {
      this.webFailed = true;
    });
  }

  // ==================== 分享 / 朗读 / 复制 ====================

  private shareNews(): void {
    const text: string = '【' + this.sourceName + '】' + this.title + '\n' +
      (this.info.length > 0 ? this.info + '\n' : '') +
      '原文：' + this.url + '\n—— 来自 智子 热榜';
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: text
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const options: systemShare.ShareControllerOptions = {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      };
      controller.show(context, options).catch((e: Object) => {
      });
    } catch (e) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  // 朗读标题 + 正文（复用 SpeechService TTS）
  private async toggleSpeak(): Promise<void> {
    if (this.speaking) {
      SpeechService.stopSpeaking();
      this.speaking = false;
      return;
    }
    let text: string = this.title;
    const body: string = this.aiBody().trim();
    if (body.length > 0) {
      text = text + '。' + body;
    }
    this.speaking = true;
    await SpeechService.speak(text, {
      onComplete: (): void => {
        this.speaking = false;
      },
      onError: (code: number, message: string): void => {
        this.speaking = false;
      }
    });
  }

  private async copyAiText(): Promise<void> {
    if (this.aiText.length === 0) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.aiText);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // ==================== UI ====================

  @Builder
  actionButton(icon: string, label: string, onClick: () => void) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
      Text(label)
        .fontSize(this.themeState.palette.fsXs - 1)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
    }
    .layoutWeight(1)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .onClick(onClick)
  }

  // 当前模型 chip（点击切换热榜专属模型）
  @Builder
  modelChip(chipWidth: number) {
    Row({ space: 4 }) {
      Text('🤖')
        .fontSize(11)
        .fontFamily(this.themeState.palette.fontSans)
      Text(this.modelName)
        .fontSize(11)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('▾')
        .fontSize(10)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width(chipWidth)
    .height(30)
    .padding({ left: 8, right: 8 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.openModelSheet(); })
  }

  @Builder
  aiPanelContent() {
    Column() {
      Row({ space: 8 }) {
        Text(this.panelTitle())
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        this.modelChip(160)
        Text('✕')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .padding(8)
          .onClick(() => { this.closePanel(); })
      }
      .width('100%')

      if (this.aiPanel === AiPanelKind.ASK) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '输入你的问题，回车发送', text: this.askInput })
            .layoutWeight(1)
            .height(40)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .onChange((value: string) => { this.askInput = value; })
            .onSubmit(() => { this.onAskSend(); })
          Button('发送')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.primary)
            .borderRadius(8)
            .height(40)
            .onClick(() => { this.onAskSend(); })
        }
        .width('100%')
        .margin({ top: 4, bottom: 8 })
      }

      if (this.aiBusy && this.aiText.length === 0) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(18)
            .height(18)
          Text('AI 思考中…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .height(80)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Text(this.aiText.length > 0 ? this.aiText :
            (this.aiError.length > 0 ? this.aiError : '点击上方按钮生成摘要'))
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.aiError.length > 0 ? this.themeState.palette.danger : this.themeState.palette.textPrimary)
            .lineHeight(24)
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .constraintSize({ maxHeight: 320 })
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }

      Row({ space: 10 }) {
        Button('复制')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(8)
          .height(36)
          .layoutWeight(1)
          .onClick(() => { this.copyAiText(); })
        Button('关闭')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(8)
          .height(36)
          .layoutWeight(1)
          .onClick(() => { this.closePanel(); })
      }
      .width('100%')
      .margin({ top: 8 })

      if (this.lastTokens > 0) {
        Text('本次调用消耗 ' + this.lastTokens.toString() + ' tokens')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.themeState.palette.bgBase)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  aiPanelOverlay() {
    if (this.aiPanel !== AiPanelKind.NONE) {
      Stack() {
        Column() {
          Blank()
          this.aiPanelContent()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.35)')
      .onClick(() => { this.closePanel(); })
    }
  }

  @Builder
  modelOverlay() {
    if (this.modelSheet) {
      Stack() {
        Column() {
          Blank()
          Column({ space: 4 }) {
            Row() {
              Text('选择模型')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(8)
                .onClick(() => { this.modelSheet = false; })
            }
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 6 })

            Scroll() {
              Column({ space: 4 }) {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Text('跟随全局')
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textPrimary)
                    Text('使用「我的 → AI 模型」中的默认模型')
                      .fontSize(10)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor(this.themeState.palette.bgSurface)
                .onClick(() => { this.pickModel(''); })

                ForEach(this.models, (m: LlmModelEntry) => {
                  Row({ space: 10 }) {
                    Column({ space: 2 }) {
                      Text(this.modelLabel(m))
                        .fontSize(this.themeState.palette.fsSm)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(m.model)
                        .fontSize(10)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textTertiary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding(12)
                  .borderRadius(8)
                  .backgroundColor(this.themeState.palette.bgSurface)
                  .onClick(() => { this.pickModel(m.id); })
                }, (m: LlmModelEntry) => m.id)

                if (this.models.length === 0) {
                  Text('没有已启用的模型，请到「我的 → AI 模型」中启用')
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .padding({ top: 12, bottom: 12 })
                }
              }
              .width('100%')
            }
            .width('100%')
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: 360 })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.themeState.palette.bgBase)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {})
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.35)')
      .onClick(() => { this.modelSheet = false; })
    }
  }

  @Builder
  fallbackContent() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      if (this.info.length > 0) {
        Text(this.info)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .lineHeight(24)
      }
      Text('原文加载失败，且暂无离线缓存')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '热榜详情', showBack: true }) {
          Row({ space: 10 }) {
            Text('A-')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primary)
              .fontWeight(FontWeight.Medium)
              .onClick(() => { this.adjustZoom(-0.15); })
            Text('A+')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primary)
              .fontWeight(FontWeight.Medium)
              .onClick(() => { this.adjustZoom(0.15); })
            Text('📤')
              .fontSize(this.themeState.palette.fsLg)
              .fontFamily(this.themeState.palette.fontSans)
              .padding(6)
              .onClick(() => { this.shareNews(); })
          }
        }

        if (this.url.length === 0) {
          Column({ space: 12 }) {
            Text('未找到文章内容')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            // 文章头部：宽屏（平板/折叠展开/横屏）字号更大，手机紧凑
            if (this.themeState.isLg || this.themeState.isMd) {
              Column({ space: 6 }) {
                Text(this.title)
                  .fontSize(this.themeState.palette.fsXl)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Row({ space: 8 }) {
                  Text(this.sourceName)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                  if (this.info.length > 0) {
                    Text('· ' + this.info)
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  if (this.offlineMode) {
                    Text('· 离线缓存')
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.warning)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12, bottom: 12 })
              .alignItems(HorizontalAlign.Start)
            } else {
              Column({ space: 6 }) {
                Text(this.title)
                  .fontSize(this.themeState.palette.fsLg)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Row({ space: 8 }) {
                  Text(this.sourceName)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                  if (this.info.length > 0) {
                    Text('· ' + this.info)
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  if (this.offlineMode) {
                    Text('· 离线缓存')
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.warning)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8, bottom: 8 })
              .alignItems(HorizontalAlign.Start)
            }

            // 操作条：收藏 / 摘要 / 翻译 / 问AI / 朗读
            Row() {
              this.actionButton(this.favorited ? '⭐' : '☆', this.favorited ? '已收藏' : '收藏', () => { this.toggleFavorite(); })
              this.actionButton('🤖', '摘要', () => { this.onSummary(); })
              this.actionButton('🌐', '翻译', () => { this.onTranslate(); })
              this.actionButton('💬', '问AI', () => {
                this.aiPanel = AiPanelKind.ASK;
                this.aiText = '';
                this.aiError = '';
              })
              this.actionButton(this.speaking ? '⏹' : '🔊', this.speaking ? '停止' : '朗读', () => { this.toggleSpeak(); })
            }
            .width('100%')
            .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .borderRadius(12)

            // 正文（ArkWeb 加载原文；成功时缓存正文并抽取正文文本，失败时回退缓存）
            Column() {
              if (!this.webFailed) {
                Web({ src: this.url, controller: this.controller })
                  .width('100%')
                  .layoutWeight(1)
                  .onPageEnd(() => {
                    this.cacheArticleHtml();
                    this.extractBodyText();
                    this.injectDarkCss();
                  })
                  .onErrorReceive(() => {
                    this.useCachedArticle();
                  })
              } else {
                this.fallbackContent()
              }
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: 820 })
        }
      }
      .width('100%')
      .height('100%')

      this.aiPanelOverlay()

      this.modelOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

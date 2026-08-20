// 智子 - 新闻详情阅读面板（平板双栏右侧使用）
// ArkWeb 原文 + 收藏/已读 + 离线缓存回退 + AI 摘要/翻译/问AI/朗读
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { NewsItem } from '../common/NewsModels';
import { NewsDislikePanel } from './NewsDislikePanel';
import { NewsRepository } from '../service/NewsRepository';
import { NewsService } from '../service/NewsService';
import { NewsAiService } from '../service/NewsAiService';
import { SpeechService } from '../service/SpeechService';
import { NewsArticleCacheEntry } from '../service/DatabaseHelper';
import { LlmConfig, LlmResult } from '../common/LlmModels';

function formatPaneTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number) => n < 10 ? '0' + n.toString() : n.toString();
  return (d.getMonth() + 1).toString() + '-' + d.getDate().toString() + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

@ComponentV2
export struct NewsDetailPane {
  @Param item: NewsItem = new NewsItem('', '', '', '', '', '', '', '', 0);
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local favorited: boolean = false;
  @Local liked: boolean = false;
  @Local disliked: boolean = false;
  @Local dislikeTarget: NewsItem | null = null;
  @Local webFailed: boolean = false;
  @Local offlineMode: boolean = false;
  // AI 面板
  @Local aiPanel: string = ''; // '' / summary / translate / ask
  @Local aiText: string = '';
  @Local aiBusy: boolean = false;
  @Local askInput: string = '';
  @Local speaking: boolean = false;
  @Local lastTokens: number = 0;
  // 知乎日报正文（API 渲染）
  @Local zhihuHtml: string = '';
  @Local zhihuInjected: boolean = false;
  @Local zoomFactor: number = 1.0;

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.loadState();
    this.prefetchZhihu();
  }

  aboutToDisappear(): void {
    SpeechService.stopSpeaking();
  }

  private async prefetchZhihu(): Promise<void> {
    const sid: string = NewsService.zhihuStoryId(this.item.id);
    if (sid.length === 0) return;
    const html: string = await NewsService.fetchZhihuStory(sid);
    if (html.length > 0) {
      this.zhihuHtml = html;
      this.maybeInjectZhihu();
    }
  }

  private maybeInjectZhihu(): void {
    if (this.zhihuHtml.length === 0 || this.zhihuInjected) return;
    try {
      this.controller.loadData(this.zhihuHtml, 'text/html', 'UTF-8', this.item.url);
      this.zhihuInjected = true;
    } catch (e) {
    }
  }

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

  private async loadState(): Promise<void> {
    if (this.item.url.length === 0) return;
    try {
      this.favorited = await NewsRepository.isFavorite(this.item.url);
      const rating = await NewsRepository.getRating(this.item.url);
      this.liked = rating !== null && rating.rating === 1;
      this.disliked = rating !== null && rating.rating === -1;
      await NewsRepository.markRead(this.item.url);
      // 隐式信号：深度阅读 +2
      await NewsRepository.recordEvent('read', this.item, 2, '');
    } catch (e) {
    }
  }

  // ==================== 点赞 / 点踩（v0.7） ====================

  private async toggleLike(): Promise<void> {
    try {
      if (this.liked) {
        await NewsRepository.removeRating(this.item.url);
        await NewsRepository.recordEvent('undo', this.item, 0, '');
        this.liked = false;
        promptAction.showToast({ message: '已取消点赞' });
      } else {
        await NewsRepository.setRating(this.item, 1, this.item.tags === undefined ? [] : this.item.tags);
        this.liked = true;
        this.disliked = false;
        promptAction.showToast({ message: '已点赞，之后会多推同类内容' });
      }
    } catch (e) {
    }
  }

  private openDislike(): void {
    this.dislikeTarget = this.item;
  }

  private async confirmDislike(item: NewsItem, tags: string[]): Promise<void> {
    this.dislikeTarget = null;
    try {
      await NewsRepository.setRating(item, -1, tags);
      if (tags.length === 0) {
        await NewsRepository.excludeUrl(item.url, 'dislike-no-tag');
      }
      this.liked = false;
      this.disliked = true;
      NewsService.clearExclusionCache();
      promptAction.showToast({ message: tags.length > 0 ?
        '已减少「' + tags.join('、') + '」类推送' : '已减少本篇推荐' });
    } catch (e) {
    }
  }

  private async toggleFavorite(): Promise<void> {
    try {
      const fav: boolean = await NewsRepository.toggleFavorite(this.item);
      this.favorited = fav;
      promptAction.showToast({ message: fav ? '已收藏' : '已取消收藏' });
    } catch (e) {
    }
  }

  // ==================== 离线正文缓存 ====================

  private cacheArticleHtml(): void {
    if (this.item.url.length === 0) return;
    try {
      this.controller.runJavaScript('document.documentElement.outerHTML',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) return;
          const html: string = result === undefined ? '' : result;
          if (html.length < 500 || html.length > 800 * 1024) return;
          NewsRepository.saveArticleCache(this.item.url, this.item.title, html).catch(() => {
          });
        });
    } catch (e) {
    }
  }

  private useCachedArticle(): void {
    if (this.item.url.length === 0) {
      this.webFailed = true;
      return;
    }
    NewsRepository.getArticleCache(this.item.url).then((cached: NewsArticleCacheEntry | null) => {
      if (cached !== null && cached.html.length > 0) {
        try {
          this.offlineMode = true;
          this.controller.loadData(cached.html, 'text/html', 'UTF-8', this.item.url);
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

  // ==================== AI 能力 ====================

  private aiPanelTitle(): string {
    if (this.aiPanel === 'summary') return '🤖 AI 摘要';
    if (this.aiPanel === 'translate') return '🌐 AI 翻译';
    if (this.aiPanel === 'ask') return '💬 问 AI';
    return '';
  }

  private closeAi(): void {
    this.aiPanel = '';
    this.aiText = '';
    this.aiBusy = false;
    this.askInput = '';
  }

  private async runAi(kind: string, builder: (config: LlmConfig, onDelta: (d: string) => void) => Promise<LlmResult>): Promise<void> {
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = kind;
    this.aiText = '';
    this.aiBusy = true;
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
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
      this.aiText = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    }
  }

  private onSummary(): void {
    this.runAi('summary', (config: LlmConfig, onDelta: (d: string) => void): Promise<LlmResult> => {
      return NewsAiService.summarize(config, this.item, this.item.summary, onDelta);
    });
  }

  // 外文翻译：缓存优先 + 方向自动 + 翻译模型（可单独记忆）
  private async onTranslate(): Promise<void> {
    const cached: string = await NewsRepository.getBodyTranslation(this.item.url);
    if (cached.length > 0) {
      this.aiPanel = 'translate';
      this.aiText = cached;
      this.aiBusy = false;
      return;
    }
    const config: LlmConfig | null = await NewsAiService.getTranslateConfig();
    if (config === null) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = 'translate';
    this.aiText = '';
    this.aiBusy = true;
    const targetZh: boolean = this.item.language === 'zh';
    const result: LlmResult = await NewsAiService.translate(config, this.item, this.item.summary,
      !targetZh, (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
      if (this.aiText.length > 0) {
        NewsRepository.saveBodyTranslation(this.item, this.aiText, config.displayName).catch(() => {
        });
      }
    } else {
      this.aiText = result.errorMessage.length > 0 ? result.errorMessage : '翻译失败，请重试';
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
    this.aiPanel = 'ask';
    this.aiText = '';
    this.aiBusy = true;
    this.askInput = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
      return;
    }
    const result: LlmResult = await NewsAiService.ask(config, this.item, this.item.summary, [], q,
      (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    }
    if (!result.success) {
      this.aiText = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    }
  }

  private async toggleSpeak(): Promise<void> {
    if (this.speaking) {
      SpeechService.stopSpeaking();
      this.speaking = false;
      return;
    }
    let text: string = this.item.title;
    if (this.item.summary.trim().length > 0) {
      text = text + '。' + this.item.summary.trim();
    }
    this.speaking = true;
    await SpeechService.speak(text, {
      onComplete: (): void => { this.speaking = false; },
      onError: (code: number, message: string): void => { this.speaking = false; }
    });
  }

  private async copyAiText(): Promise<void> {
    if (this.aiText.length === 0) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.aiText);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制' });
    } catch (e) {
    }
  }

  // ==================== AI 面板 UI ====================

  @Builder
  aiOverlay() {
    if (this.aiPanel.length > 0) {
      Stack() {
        Column() {
          Blank()
          Column({ space: 10 }) {
            Row() {
              Text(this.aiPanelTitle())
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(8)
                .onClick(() => { this.closeAi(); })
            }
            .width('100%')

            if (this.aiPanel === 'ask') {
              Row({ space: 8 }) {
                TextInput({ placeholder: '输入你的问题…', text: this.askInput })
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .onChange((v: string) => { this.askInput = v; })
                  .onSubmit(() => { this.onAskSend(); })
                Button('发送')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(Color.White)
                  .backgroundColor(this.themeState.palette.primary)
                  .borderRadius(8)
                  .height(38)
                  .onClick(() => { this.onAskSend(); })
              }
              .width('100%')
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
              .height(60)
              .justifyContent(FlexAlign.Center)
            } else {
              Scroll() {
                Text(this.aiText.length > 0 ? this.aiText : '点击上方按钮生成')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .lineHeight(24)
                  .width('100%')
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .constraintSize({ maxHeight: 280 })
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
                .onClick(() => { this.closeAi(); })
            }
            .width('100%')

            if (this.lastTokens > 0) {
              Text('本次调用消耗 ' + this.lastTokens.toString() + ' tokens')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
            }
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
      .onClick(() => { this.closeAi(); })
    }
  }

  @Builder
  actionButton(icon: string, label: string, active: boolean, onClick: () => void) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(active ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      Text(label)
        .fontSize(this.themeState.palette.fsXs - 1)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(active ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
    }
    .layoutWeight(1)
    .height(46)
    .justifyContent(FlexAlign.Center)
    .onClick(onClick)
  }

  build() {
    Stack() {
      Column() {
        // 头部
        Column({ space: 6 }) {
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(this.item.title)
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Row({ space: 8 }) {
                Text(this.item.sourceName)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                Text(formatPaneTime(this.item.publishedAt))
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                if (this.offlineMode) {
                  Text('· 离线缓存')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.warning)
                }
                Blank()
                Text('A-')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                  .padding({ left: 6, right: 6 })
                  .onClick(() => { this.adjustZoom(-0.15); })
                Text('A+')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                  .padding({ left: 6, right: 6 })
                  .onClick(() => { this.adjustZoom(0.15); })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')

          if (this.item.summary.length > 0) {
            Text(this.item.summary)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textSecondary)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }

          // 操作条：赞/踩 / 收藏 / 摘要 / 翻译 / 问AI / 朗读
          Row() {
            this.actionButton(this.liked ? '👍' : '👍🏻', this.liked ? '已赞' : '点赞', this.liked, () => { this.toggleLike(); })
            this.actionButton(this.disliked ? '👎' : '👎🏻', this.disliked ? '已踩' : '点踩', this.disliked, () => { this.openDislike(); })
            this.actionButton(this.favorited ? '⭐' : '☆', this.favorited ? '已收藏' : '收藏', this.favorited, () => { this.toggleFavorite(); })
            this.actionButton('🤖', '摘要', false, () => { this.onSummary(); })
            this.actionButton('🌐', '翻译', false, () => { this.onTranslate(); })
            this.actionButton('💬', '问AI', this.aiPanel === 'ask', () => {
              this.aiPanel = 'ask';
              this.aiText = '';
            })
            this.actionButton(this.speaking ? '⏹' : '🔊', this.speaking ? '停止' : '朗读', this.speaking, () => { this.toggleSpeak(); })
          }
          .width('100%')
          .padding({ left: 8, right: 8 })
        }
        .width('100%')
        .padding(14)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
        .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

        // 正文
        Column() {
          if (!this.webFailed && this.item.url.length > 0) {
            Web({ src: this.item.url, controller: this.controller })
              .width('100%')
              .layoutWeight(1)
              .onPageEnd(() => {
                this.cacheArticleHtml();
                this.maybeInjectZhihu();
                this.injectDarkCss();
              })
              .onErrorReceive(() => { this.useCachedArticle(); })
          } else {
            Column({ space: 10 }) {
              Text('📄')
                .fontSize(40)
                .fontFamily(this.themeState.palette.fontSans)
              Text('原文加载失败，且暂无离线缓存')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      this.aiOverlay()

      if (this.dislikeTarget !== null) {
        ForEach([this.dislikeTarget], (target: NewsItem) => {
          NewsDislikePanel({
            item: target,
            onConfirm: (item: NewsItem, tags: string[]): void => { this.confirmDislike(item, tags); },
            onCancel: (): void => { this.dislikeTarget = null; }
          })
        }, (target: NewsItem) => target.url)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

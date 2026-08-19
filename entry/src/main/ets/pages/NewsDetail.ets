// 智子 - 新闻详情页（ArkWeb 原文 + 收藏/已读 + AI 摘要/翻译/问AI）
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { NewsModelSelector } from '../components/NewsModelSelector';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsItem, NewsDetailRouteParams } from '../common/NewsModels';
import { NewsRepository } from '../service/NewsRepository';
import { NewsAiService } from '../service/NewsAiService';
import { SpeechService } from '../service/SpeechService';
import { LlmConfig, ChatMessage, LlmResult } from '../common/LlmModels';

enum AiPanelKind {
  NONE = 0,
  SUMMARY = 1,
  TRANSLATE = 2,
  ASK = 3
}

function formatDetailTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number) => n < 10 ? '0' + n.toString() : n.toString();
  return d.getFullYear().toString() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
    ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

@ComponentV2
@Entry
export struct NewsDetailPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local item: NewsItem = new NewsItem('', '', '', '', '', '', '', '', 0);
  @Local favorited: boolean = false;
  @Local webFailed: boolean = false;
  // AI 面板状态
  @Local aiPanel: AiPanelKind = AiPanelKind.NONE;
  @Local aiText: string = '';
  @Local aiBusy: boolean = false;
  @Local aiError: string = '';
  @Local askInput: string = '';
  // 问AI 历史（只保留最近 4 轮）
  @Local askHistory: ChatMessage[] = [];
  // 朗读状态
  @Local speaking: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: NewsDetailRouteParams | null = AppNavigator.getParam('pages/NewsDetail') as NewsDetailRouteParams | null;
    // 注意：router 参数为序列化纯数据对象，类方法（如 toItem）不可用，需直接读字段
    if (params !== null && params !== undefined && params.url.length > 0) {
      this.item = new NewsItem(params.itemId, params.title, params.summary, params.url,
        params.imageUrl, params.sourceId, params.sourceName, params.category, params.publishedAt);
    }
    this.loadState();
  }

  aboutToDisappear(): void {
    // Web 组件随页面销毁，AI 请求由 LlmClient 内部管理
  }

  private async loadState(): Promise<void> {
    if (this.item.url.length === 0) return;
    try {
      this.favorited = await NewsRepository.isFavorite(this.item.url);
      await NewsRepository.markRead(this.item.url);
    } catch (e) {
    }
  }

  private async toggleFavorite(): Promise<void> {
    try {
      const fav: boolean = await NewsRepository.toggleFavorite(this.item);
      this.favorited = fav;
      promptAction.showToast({ message: fav ? '已收藏' : '已取消收藏' });
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试' });
    }
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
  private async runAi(panel: AiPanelKind, builder: (config: LlmConfig, onDelta: (d: string) => void) => Promise<LlmResult>): Promise<void> {
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
    if (!result.success) {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    }
  }

  private onSummary(): void {
    this.runAi(AiPanelKind.SUMMARY, (config: LlmConfig, onDelta: (d: string) => void): Promise<LlmResult> => {
      return NewsAiService.summarize(config, this.item, this.item.summary, onDelta);
    });
  }

  private onTranslate(): void {
    this.runAi(AiPanelKind.TRANSLATE, (config: LlmConfig, onDelta: (d: string) => void): Promise<LlmResult> => {
      return NewsAiService.translate(config, this.item, this.item.summary, true, onDelta);
    });
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
    const result: LlmResult = await NewsAiService.ask(config, this.item, this.item.summary,
      this.askHistory, q, (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
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

  // 朗读标题 + 摘要（复用 SpeechService TTS）
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

  @Builder
  aiPanelContent() {
    Column() {
      Row() {
        Text(this.panelTitle())
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        NewsModelSelector()
          .width(170)
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
  fallbackContent() {
    Column({ space: 12 }) {
      Text(this.item.title)
        .fontSize(this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      if (this.item.summary.length > 0) {
        Text(this.item.summary)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .lineHeight(24)
      }
      Button('用系统浏览器打开原文')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(Color.White)
        .backgroundColor(this.themeState.palette.primary)
        .borderRadius(8)
        .height(38)
        .margin({ top: 8 })
        .onClick(() => {
          promptAction.showToast({ message: '请在浏览器中打开' });
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '新闻详情', showBack: true })

        if (this.item.url.length === 0) {
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
            // 文章头部：宽屏（平板/折叠展开/横屏）图左字右，手机保持竖排紧凑
            if (this.themeState.isLg || this.themeState.isMd) {
              Row({ space: 14 }) {
                if (this.item.imageUrl.length > 0) {
                  Image(this.item.imageUrl)
                    .width(150)
                    .height(100)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(10)
                }
                Column({ space: 6 }) {
                  Text(this.item.title)
                    .fontSize(this.themeState.palette.fsXl)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Bold)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 8 }) {
                    Text(this.item.sourceName)
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.primary)
                    Text(formatDetailTime(this.item.publishedAt))
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                  }
                  .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)
            } else {
              Column({ space: 6 }) {
                if (this.item.imageUrl.length > 0) {
                  Image(this.item.imageUrl)
                    .width('100%')
                    .height(110)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(10)
                }
                Text(this.item.title)
                  .fontSize(this.themeState.palette.fsLg)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 8 }) {
                  Text(this.item.sourceName)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                  Text(formatDetailTime(this.item.publishedAt))
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .width('100%')
              }
              .width('100%')
              .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8, bottom: 8 })
              .alignItems(HorizontalAlign.Start)
            }

            // 操作条
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

            // 正文（ArkWeb 加载原文）
            Column() {
              if (!this.webFailed) {
                Web({ src: this.item.url, controller: this.controller })
                  .width('100%')
                  .layoutWeight(1)
                  .onErrorReceive(() => {
                    this.webFailed = true;
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

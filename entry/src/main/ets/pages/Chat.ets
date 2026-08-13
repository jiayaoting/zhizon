// 智子 - AI 对话页
import { promptAction, router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { ChatRepository } from '../service/ChatRepository';
import { LlmClient } from '../service/LlmClient';
import { ChatMessage, entryToConfig, LlmConfig, LlmModelEntry, LlmResult, modelDisplayName,
  modelDisplayNameFromConfig } from '../common/LlmModels';
import { MarkdownConverter, MdBlock, InlineSpan } from '../common/MarkdownConverter';

// ============================================================
// MarkdownText：纯 ArkUI 原生组件渲染 Markdown（Column + Text + Span）
// 社区成熟方案（FluidMarkdown/RichTextVista）：解析为结构化对象后用原生组件渲染，
// 规避 RichText 无法自适应高度/List 卡顿、Web 在 List 内高度不可靠的问题。
// ============================================================
@Component
struct MarkdownText {
  @Prop content: string = '';
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isDarkMode') isDark: boolean = false;

  // 行内富文本：Text 内嵌 Span 序列（支持粗体/斜体/行内代码/链接颜色）
  @Builder
  inlineSpans(text: string) {
    ForEach(MarkdownConverter.parseInline(text), (sp: InlineSpan) => {
      if (sp.code) {
        Span(' ' + sp.text + ' ')
          .fontSize(this.palette.fsSm - 1)
          .fontFamily(this.palette.fontMono)
          .fontColor(this.isDark ? '#FCA5A5' : '#C0392B')
          .textBackgroundStyle({ color: this.isDark ? '#1E293B' : '#F1F5F9', radius: '3vp' })
      } else if (sp.link.length > 0) {
        Span(sp.text)
          .fontSize(this.palette.fsSm)
          .fontColor(this.isDark ? '#60A5FA' : '#2563EB')
          .textDecoration({ type: TextDecorationType.Underline })
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      } else {
        Span(sp.text)
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textPrimary)
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      }
    }, (sp: InlineSpan, index: number) => sp.text + index.toString())
  }

  // 段落/列表项（带行内格式）
  @Builder
  para(text: string) {
    Text() {
      this.inlineSpans(text)
    }
    .fontSize(this.palette.fsSm)
    .fontFamily(this.palette.fontSans)
    .lineHeight(20)
    .width('100%')
  }

  build() {
    Column({ space: 6 }) {
      ForEach(MarkdownConverter.parseBlocks(this.content), (block: MdBlock, bi: number) => {
        if (block.kind === 'h1') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette.textPrimary)
          .lineHeight(24)
          .width('100%')
        } else if (block.kind === 'h2') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.palette.fsMd + 1)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette.textPrimary)
          .lineHeight(22)
          .width('100%')
        } else if (block.kind === 'h3') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette.textPrimary)
          .lineHeight(20)
          .width('100%')
        } else if (block.kind === 'code') {
          Column({ space: 0 }) {
            ForEach(block.lines, (ln: string) => {
              Text(ln.length > 0 ? ln : ' ')
                .fontSize(this.palette.fsSm - 1)
                .fontFamily(this.palette.fontMono)
                .fontColor(this.isDark ? '#FCA5A5' : '#C0392B')
                .lineHeight(18)
                .width('100%')
            }, (ln: string, li: number) => ln + li.toString())
          }
          .width('100%')
          .padding(10)
          .borderRadius(8)
          .backgroundColor(this.isDark ? '#1E293B' : '#F1F5F9')
        } else if (block.kind === 'quote') {
          Column({ space: 2 }) {
            ForEach(block.items, (q: string) => {
              Text() {
                this.inlineSpans(q)
              }
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
              .fontStyle(FontStyle.Italic)
              .lineHeight(20)
              .width('100%')
            }, (q: string, qi: number) => q + qi.toString())
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(6)
          .border({ width: 0 })
          .backgroundColor(this.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)')
        } else if (block.kind === 'hr') {
          Divider()
            .strokeWidth(0.5)
            .color(this.palette.borderSubtle)
            .margin({ top: 4, bottom: 4 })
        } else if (block.kind === 'ul') {
          Column({ space: 3 }) {
            ForEach(block.items, (it: string) => {
              Row({ space: 6 }) {
                Text('•')
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                Text() {
                  this.inlineSpans(it)
                }
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .lineHeight(20)
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (it: string, ii: number) => it + ii.toString())
          }
          .width('100%')
        } else if (block.kind === 'ol') {
          Column({ space: 3 }) {
            ForEach(block.items, (it: string) => {
              Row({ space: 6 }) {
                Text() {
                  this.inlineSpans(it)
                }
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .lineHeight(20)
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (it: string, ii: number) => it + ii.toString())
          }
          .width('100%')
        } else if (block.kind === 'table') {
          Column({ space: 2 }) {
            if (block.lines.length > 0) {
              Text() {
                this.inlineSpans(block.lines[0])
              }
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette.textPrimary)
              .lineHeight(20)
              .width('100%')
            }
            ForEach(block.items, (rw: string) => {
              Text() {
                this.inlineSpans(rw)
              }
              .fontSize(this.palette.fsSm - 1)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
              .lineHeight(18)
              .width('100%')
            }, (rw: string, ri: number) => rw + ri.toString())
          }
          .width('100%')
          .padding(8)
          .borderRadius(6)
          .backgroundColor(this.isDark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)')
        } else {
          this.para(block.items.length > 0 ? block.items.join('\n') : block.text)
        }
      }, (block: MdBlock, index: number) => block.kind + index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

// 单条消息气泡子组件：用 @ObjectLink 监听 @Observed ChatMessage 的 content 变化
// 流式 delta 仅修改 message.content 即可触发本组件刷新，无需重建整个消息列表
@Component
struct MessageBubble {
  @ObjectLink message: ChatMessage;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDark: boolean = false;
  @Prop index: number = 0;
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  @Prop isStreaming: boolean = false;
  onRetry: (index: number) => void = () => {};
  onLongPressMessage: (index: number) => void = () => {};
  onToggleSelect: (index: number) => void = () => {};
  onExpandReasoning: (index: number) => void = () => {};
  onFullscreen: (index: number) => void = () => {};
  @State reasoningExpanded: boolean = false;
  // 思考内容滚动控制器：展开后自动滚到底部
  private reasoningScroller: Scroller = new Scroller();

  private formatTime(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    return hh + ':' + mm;
  }

  private isFailure(): boolean {
    return this.message.content.indexOf('⚠️ 请求失败') === 0;
  }

  // 是否应使用 markdown 渲染（助手消息、非失败、有内容、非流式中）
  private useMarkdown(): boolean {
    return this.message.role === 'assistant' && !this.isStreaming && !this.isFailure() &&
      this.message.content.trim().length > 0;
  }

  // 展开/收起思考：展开时通知父组件滚动定位到本条，并自动滚到思考内容底部
  private toggleReasoning(): void {
    this.reasoningExpanded = !this.reasoningExpanded;
    if (this.reasoningExpanded) {
      this.onExpandReasoning(this.index);
      setTimeout(() => {
        this.reasoningScroller.scrollEdge(Edge.Bottom);
      }, 50);
    }
  }

  // 长按：进入多选或弹出操作菜单
  private handleLongPress(): void {
    if (this.selectionMode) {
      this.onToggleSelect(this.index);
    } else {
      this.onLongPressMessage(this.index);
    }
  }

  build() {
    Row() {
      // 多选模式：左侧选择框
      if (this.selectionMode) {
        Column() {
          Row()
            .width(20)
            .height(20)
            .borderRadius(10)
            .border({ width: 2, color: this.selected ? this.palette.primary : this.palette.borderSubtle })
            .backgroundColor(this.selected ? this.palette.primary : Color.Transparent)
            .justifyContent(FlexAlign.Center)
            .margin({ right: 8, top: 20 })
          if (this.selected) {
            Text('✓')
              .fontSize(11)
              .fontFamily(this.palette.fontSans)
              .fontColor('#FFFFFF')
              .margin({ right: 8 })
          }
        }
        .onClick(() => { this.onToggleSelect(this.index); })
      }

      if (this.message.role === 'user') {
        Blank()
        Column({ space: 4 }) {
          Text(this.message.content.trim())
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor('#FFFFFF')
            .lineHeight(20)
            .padding(12)
            .borderRadius(12)
            .backgroundColor(this.palette.primary)
            .constraintSize({ maxWidth: this.isSm ? 260 : 420 })
        }
        .alignItems(HorizontalAlign.End)
        .gesture(LongPressGesture().onAction(() => { this.handleLongPress(); }))
      } else {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('🤖')
              .fontSize(14)
              .fontFamily(this.palette.fontSans)
            Text('智子 AI')
              .fontSize(11)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Text(this.formatTime(this.message.time))
              .fontSize(9)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          // 思考过程折叠区块：默认收起，点击展开查看思考内容
          if (this.message.reasoning.trim().length > 0) {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text('💭')
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                Text('已深度思考')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                Text(this.reasoningExpanded ? '▲' : '▼')
                  .fontSize(9)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
              }
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .borderRadius(6)
              .backgroundColor(this.palette.bgSurface2)
              .onClick(() => { this.toggleReasoning(); })
              if (this.reasoningExpanded) {
                // 思考内容限高可滚动：长思考不会撑爆列表，且用户无需滑回顶部即可收起
                Scroll(this.reasoningScroller) {
                  Text(this.message.reasoning.trim())
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textTertiary)
                    .lineHeight(16)
                    .width('100%')
                    .padding(8)
                }
                .scrollBar(BarState.Off)
                .constraintSize({ maxHeight: 200 })
                .borderRadius(6)
                .backgroundColor(this.palette.bgSurface2)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          // 正文：流式中用 Text 打字机效果；结束后用原生 MarkdownText 渲染
          if (this.useMarkdown()) {
            Column() {
              MarkdownText({ content: this.message.content })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1,
              color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .constraintSize({ maxWidth: this.isSm ? 280 : 440 })
            .gesture(TapGesture({ count: 2 }).onAction(() => { this.onFullscreen(this.index); }))
          } else {
            Text(this.message.content.trim().length > 0 ? this.message.content.trim() : '…')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .lineHeight(20)
              .padding(12)
              .borderRadius(12)
              .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
              .border({ width: 1,
                color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
              .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
              .constraintSize({ maxWidth: this.isSm ? 280 : 440 })
          }
          // 失败时显示重试按钮
          if (this.isFailure()) {
            Row() {
              Text('↻ 重试')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.onRetry(this.index); })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .gesture(LongPressGesture().onAction(() => { this.handleLongPress(); }))
        .gesture(TapGesture({ count: 2 }).onAction(() => {
          if (this.message.role === 'assistant' && !this.isFailure() &&
            this.message.content.trim().length > 0) {
            this.onFullscreen(this.index);
          }
        }))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}

@Entry
@Component
struct Chat {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDark: boolean = false;

  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State sending: boolean = false;
  @State configReady: boolean = false;
  @State configHint: string = '未配置';
  @State streamingContent: string = '';
  @State streamingReasoning: string = '';
  @State streaming: boolean = false;

  // 模型切换
  @State models: LlmModelEntry[] = [];
  @State activeModelId: string = '';
  @State showModelPicker: boolean = false;
  @State activeConfig: LlmConfig | null = null;
  // 当前流式请求的 httpRequest 引用，停止按钮调用 destroy() 中断
  private streamRequest: http.HttpRequest | null = null;
  // 上次失败时缓存的 user 消息，用于重试
  private lastUserText: string = '';

  // 搜索
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State searchRole: string = 'all';

  // 多选删除
  @State selectionMode: boolean = false;
  @State selectedIds: string[] = [];

  // 长按操作面板：显示单条消息的复制/分享/多选/删除
  @State actionSheetIndex: number = -1;

  // 全屏 markdown 查看
  @State fullscreenIndex: number = -1;
  private fullscreenController: webview.WebviewController = new webview.WebviewController();

  private readonly scrollController: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
  }

  // onPageShow 仅在页面被路由栈顶显示时触发，router.pushUrl 子页返回也会触发
  onPageShow(): void {
    this.refreshModels();
    // 回到页面时滚动到最新消息
    setTimeout(() => { this.scrollToBottom(); }, 100);
  }

  private async load(): Promise<void> {
    this.messages = await ChatRepository.loadHistory();
    if (this.messages.length === 0) {
      const welcome: ChatMessage = ChatMessage.create('assistant',
        '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
      this.messages = [welcome];
    }
    await this.refreshModels();
    // 等列表渲染完成后滚动到底部
    setTimeout(() => { this.scrollToBottom(); }, 150);
  }

  private async refreshModels(): Promise<void> {
    this.models = await ChatRepository.loadModels();
    this.activeModelId = await ChatRepository.loadActiveModelId();
    this.activeConfig = await ChatRepository.loadActiveConfig();
    // 激活 id 与现有模型不匹配时（如已删除），同步为当前生效模型，保证列表高亮与状态一致
    if (this.activeConfig !== null && this.activeModelId !== this.activeConfig.id) {
      this.activeModelId = this.activeConfig.id;
    }
    this.configReady = this.activeConfig !== null && this.activeConfig.configured;
    if (this.configReady && this.activeConfig !== null) {
      this.configHint = modelDisplayNameFromConfig(this.activeConfig);
    } else {
      this.configHint = '请先完成配置';
    }
  }

  private currentModelName(): string {
    if (this.activeConfig !== null && this.activeConfig.displayName.trim().length > 0) {
      return this.activeConfig.displayName.trim();
    }
    if (this.activeConfig !== null && this.activeConfig.model.trim().length > 0) {
      return this.activeConfig.model.trim();
    }
    return '未选择模型';
  }

  private async selectModel(index: number): Promise<void> {
    const m: LlmModelEntry = this.models[index];
    try {
      await ChatRepository.setActiveModelId(m.id);
    } catch (e) {
      promptAction.showToast({ message: '切换失败，请重试' });
      return;
    }
    this.activeModelId = m.id;
    this.activeConfig = entryToConfig(m);
    this.configReady = this.activeConfig.configured;
    this.configHint = modelDisplayName(m);
    this.showModelPicker = false;
  }

  private openConfig(): void {
    router.pushUrl({ url: 'pages/ChatConfig' });
  }

  private async clearChat(): Promise<void> {
    AlertDialog.show({
      title: '清空对话',
      message: '确定要清空当前全部对话记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: async () => {
          this.messages = [];
          this.streamingContent = '';
          this.showSearch = false;
          this.searchQuery = '';
          await ChatRepository.clearHistory();
          // 清空后恢复欢迎语，保持一致体验
          const welcome: ChatMessage = ChatMessage.create('assistant',
            '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
          this.messages = [welcome];
        }
      }
    });
  }

  private onInputChange(value: string): void {
    this.inputText = value;
  }

  private async send(): Promise<void> {
    const text: string = this.inputText.trim();
    if (text.length === 0 || this.sending || this.streaming) return;
    const config: LlmConfig | null = this.activeConfig;
    if (config === null || !config.configured) {
      promptAction.showToast({ message: '请先配置大模型 API' });
      return;
    }
    if (config.needsKey && !config.apiKey) {
      promptAction.showToast({ message: '请先配置 API Key' });
      return;
    }
    this.inputText = '';
    this.lastUserText = text;
    const userMessage: ChatMessage = ChatMessage.create('user', text);
    const assistantMessage: ChatMessage = ChatMessage.create('assistant', '');
    const newMessages: ChatMessage[] = this.messages.concat([userMessage, assistantMessage]);
    this.messages = newMessages;
    this.sending = true;
    this.streaming = true;
    this.streamingContent = '';
    this.streamingReasoning = '';
    this.scrollToBottom();

    const history: ChatMessage[] = ChatRepository.requestMessages(
      newMessages.slice(0, newMessages.length - 1), config.contextTokensIn);
    const result: LlmResult = await LlmClient.postCompletionStream(config, history,
      (delta: string) => {
        // 流式增量更新：仅修改 @Observed ChatMessage 的 content 属性
        // MessageBubble 子组件通过 @ObjectLink 自动感知变化，无需重建整个 messages 数组
        this.streamingContent = this.streamingContent + delta;
        assistantMessage.content = this.streamingContent;
        this.scrollToBottom();
      },
      (reasoningDelta: string) => {
        // 思考过程单独累积，气泡中以折叠区块展示，不与正文混排
        this.streamingReasoning = this.streamingReasoning + reasoningDelta;
        assistantMessage.reasoning = this.streamingReasoning;
      });
    this.sending = false;
    this.streaming = false;
    this.streamRequest = null;
    if (result.success) {
      assistantMessage.content = result.content;
      assistantMessage.reasoning = result.reasoning;
      this.streamingContent = '';
      this.streamingReasoning = '';
    } else {
      assistantMessage.content = '⚠️ 请求失败：' + result.errorMessage;
      this.streamingContent = '';
      this.streamingReasoning = '';
    }
    await ChatRepository.saveHistory(this.messages);
    this.scrollToBottom();
  }

  // 停止当前流式请求
  private stopStreaming(): void {
    if (this.streamRequest !== null) {
      try {
        this.streamRequest.destroy();
      } catch (e) {
      }
      this.streamRequest = null;
    }
    this.streaming = false;
    this.sending = false;
    if (this.streamingContent.length === 0 && this.streamingReasoning.length === 0) {
      // 若停止时无内容，移除最后一条空的 assistant 消息
      if (this.messages.length > 0) {
        const last: ChatMessage = this.messages[this.messages.length - 1];
        if (last.role === 'assistant' && last.content.length === 0 && last.reasoning.length === 0) {
          this.messages = this.messages.slice(0, this.messages.length - 1);
        }
      }
    } else {
      // 有内容则保留已收到的部分
      if (this.messages.length > 0) {
        const last: ChatMessage = this.messages[this.messages.length - 1];
        if (last.role === 'assistant') {
          last.content = this.streamingContent;
          last.reasoning = this.streamingReasoning;
        }
      }
    }
    this.streamingContent = '';
    this.streamingReasoning = '';
    ChatRepository.saveHistory(this.messages);
  }

  // 重试上次失败的请求
  private async retryLast(): Promise<void> {
    if (this.sending || this.streaming) return;
    if (this.lastUserText.length === 0) {
      promptAction.showToast({ message: '无可重试的消息' });
      return;
    }
    const text: string = this.lastUserText;
    // 移除最后一条失败的 assistant 消息
    if (this.messages.length > 0) {
      const last: ChatMessage = this.messages[this.messages.length - 1];
      if (last.role === 'assistant' && last.content.indexOf('⚠️ 请求失败') === 0) {
        this.messages = this.messages.slice(0, this.messages.length - 1);
      }
    }
    this.inputText = text;
    await this.send();
  }

  // 直接滚动到底部，去除 setTimeout 队列堆积
  private scrollToBottom(): void {
    this.scrollController.scrollEdge(Edge.Bottom);
  }

  private formatTime(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    return hh + ':' + mm;
  }

  // ---- 消息操作（复制/分享/删除） ----

  // 长按消息：弹出单条操作面板（复制/分享/多选/删除）
  private showActionSheet(index: number): void {
    this.actionSheetIndex = index;
  }

  private closeActionSheet(): void {
    this.actionSheetIndex = -1;
  }

  // 操作面板消息预览文本（截取前 80 字）
  private actionSheetPreviewText(): string {
    const m: ChatMessage | null = this.actionSheetMessage();
    if (m === null) return '';
    const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
    const raw: string = roleName + '：' + m.content;
    return raw.length > 80 ? raw.substring(0, 80) + '…' : raw;
  }

  private actionSheetMessage(): ChatMessage | null {
    const displayed: ChatMessage[] = this.displayMessages();
    if (this.actionSheetIndex < 0 || this.actionSheetIndex >= displayed.length) return null;
    return displayed[this.actionSheetIndex];
  }

  // 单条复制
  private copyMessage(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    this.copyText(displayed[index].content);
    this.closeActionSheet();
  }

  // 复制文本到剪贴板
  private copyText(text: string): void {
    if (text.length === 0) return;
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pb.setData(data);
      promptAction.showToast({ message: '已复制到剪贴板' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // 单条分享：拉起系统分享面板
  private shareMessage(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const m: ChatMessage = displayed[index];
    this.shareText(this.formatMessageForShare(m));
    this.closeActionSheet();
  }

  // 批量分享
  private shareSelected(): void {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '请先选择消息' });
      return;
    }
    this.shareText(this.formatSelectedForShare());
  }

  // 拼接单条消息为分享文本
  private formatMessageForShare(m: ChatMessage): string {
    const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
    let text: string = roleName + '：' + m.content;
    if (m.reasoning.trim().length > 0) {
      text = roleName + '（思考过程）\n' + m.reasoning.trim() + '\n\n' + text;
    }
    return text + '\n\n—— 来自 智子 AI 助手';
  }

  // 拼接选中的多条消息（按时间顺序）
  private formatSelectedForShare(): string {
    const selected: ChatMessage[] = this.messages.filter((m: ChatMessage): boolean =>
      this.selectedIds.indexOf(m.id) >= 0);
    selected.sort((a: ChatMessage, b: ChatMessage): number => a.time - b.time);
    let text: string = '';
    for (let i: number = 0; i < selected.length; i++) {
      const m: ChatMessage = selected[i];
      const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
      if (i > 0) text = text + '\n\n';
      text = text + roleName + '：' + m.content;
    }
    return text + '\n\n—— 来自 智子 AI 助手';
  }

  // 批量复制
  private copySelected(): void {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '请先选择消息' });
      return;
    }
    this.copyText(this.formatSelectedForShare());
    this.exitSelectionMode();
  }

  // 拉起系统分享面板分享文本
  private shareText(text: string): void {
    if (text.length === 0) return;
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
        // 用户取消分享面板时忽略错误
      });
    } catch (e) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  // 多选模式中单条删除：从选中列表移除
  private deleteSingle(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const target: ChatMessage = displayed[index];
    this.selectedIds = [target.id];
    this.deleteSelected();
    this.closeActionSheet();
  }

  // 进入多选模式（从操作面板触发）
  private enterMultiSelectFromSheet(): void {
    const m: ChatMessage | null = this.actionSheetMessage();
    this.selectionMode = true;
    this.selectedIds = m !== null ? [m.id] : [];
    this.closeActionSheet();
  }

  // ---- 多选删除 ----

  private isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelect(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const id: string = displayed[index].id;
    if (this.isSelected(id)) {
      this.selectedIds = this.selectedIds.filter((i: string): boolean => i !== id);
    } else {
      this.selectedIds = this.selectedIds.concat([id]);
    }
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  // 删除选中的消息
  private async deleteSelected(): Promise<void> {
    if (this.selectedIds.length === 0) {
      this.exitSelectionMode();
      return;
    }
    const count: number = this.selectedIds.length;
    AlertDialog.show({
      title: '删除消息',
      message: '确定删除选中的 ' + count.toString() + ' 条消息吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          const remaining: ChatMessage[] = await ChatRepository.deleteMessages(this.selectedIds);
          this.messages = remaining.length > 0 ? remaining : [];
          this.exitSelectionMode();
          if (this.messages.length === 0) {
            const welcome: ChatMessage = ChatMessage.create('assistant',
              '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
            this.messages = [welcome];
          }
          promptAction.showToast({ message: '已删除 ' + count.toString() + ' 条消息' });
        }
      }
    });
  }

  // ---- 全屏 markdown 查看 ----

  private openFullscreen(index: number): void {
    this.fullscreenIndex = index;
  }

  private closeFullscreen(): void {
    this.fullscreenIndex = -1;
  }

  // 展开思考后滚动定位到对应消息
  private expandReasoning(index: number): void {
    if (index >= 0) {
      this.scrollController.scrollToIndex(index, true);
    }
  }

  // ---- 搜索 ----

  private exitSearch(): void {
    this.showSearch = false;
    this.searchQuery = '';
    this.searchRole = 'all';
  }

  private displayMessages(): ChatMessage[] {
    if (!this.showSearch) return this.messages;
    let result: ChatMessage[] = this.messages;
    if (this.searchRole !== 'all') {
      result = result.filter((m: ChatMessage): boolean => m.role === this.searchRole);
    }
    const q: string = this.searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter((m: ChatMessage): boolean => m.content.toLowerCase().indexOf(q) >= 0);
    }
    return result;
  }

  private searchResultCount(): number {
    if (!this.showSearch) return this.messages.length;
    return this.displayMessages().length;
  }

  @Builder
  filterChip(label: string, role: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.searchRole === role ? '#FFFFFF' : this.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
    }
    .height(28)
    .padding({ left: 12, right: 12 })
    .borderRadius(14)
    .backgroundColor(this.searchRole === role ? this.palette.primary : this.palette.bgSurface2)
    .border({ width: 1, color: this.searchRole === role ? this.palette.primary : this.palette.borderSubtle })
    .onClick(() => { this.searchRole = role; })
  }

  @Builder
  searchBar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('🔍')
          .fontSize(14)
          .fontFamily(this.palette.fontSans)
        TextInput({ text: this.searchQuery, placeholder: '搜索对话记录…' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(Color.Transparent)
          .height(40)
          .layoutWeight(1)
          .onChange((value: string) => { this.searchQuery = value; })
        Text('✕')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .padding(8)
          .onClick(() => { this.exitSearch(); })
      }
      .width('100%')
      .padding({ left: 12, right: 4 })
      .height(44)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
      .borderRadius(10)
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
      .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)

      Row({ space: 6 }) {
        this.filterChip('全部', 'all')
        this.filterChip('用户', 'user')
        this.filterChip('助手', 'assistant')
        Blank()
        Text('共 ' + this.searchResultCount().toString() + ' 条')
          .fontSize(10)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8 })
  }

  @Builder
  emptyWelcome() {
    Column({ space: 12 }) {
      Text('🗨️')
        .fontSize(44)
        .fontFamily(this.palette.fontSans)
      Text('智子 AI 助手')
        .fontSize(this.palette.fsXl)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text('配置你自己的大模型 API Key，开始对话')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 80, bottom: 40 })
  }

  // 搜索无结果
  @Builder
  searchEmpty() {
    Column({ space: 8 }) {
      Text('🔍')
        .fontSize(36)
        .fontFamily(this.palette.fontSans)
      Text('未找到匹配的对话')
        .fontSize(this.palette.fsBase)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
      Text('试试其他关键词或筛选条件')
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 60, bottom: 40 })
  }

  @Builder
  inputBar() {
    Row({ space: 8 }) {
      TextInput({ text: this.inputText, placeholder: '输入消息…' })
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .placeholderColor(this.palette.textTertiary)
        .backgroundColor(this.palette.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: this.palette.borderSubtle })
        .height(44)
        .layoutWeight(1)
        .onChange((value: string) => { this.onInputChange(value); })
        .onSubmit(() => { this.send(); })
      // 流式过程中显示停止按钮，否则显示发送按钮
      if (this.streaming) {
        Row() {
          Text('■')
            .fontSize(14)
            .fontFamily(this.palette.fontSans)
            .fontColor('#FFFFFF')
        }
        .height(44)
        .padding({ left: 16, right: 16 })
        .borderRadius(10)
        .backgroundColor(this.palette.danger)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.stopStreaming(); })
      } else {
        Row() {
          if (this.sending) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#FFFFFF')
          } else {
            Text('发送')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .height(44)
        .padding({ left: 16, right: 16 })
        .borderRadius(10)
        .backgroundColor(this.palette.primary)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.send(); })
      }
    }
    .width('100%')
  }

  @Builder
  modelPicker() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.palette.borderSubtle)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Row() {
            Text('选择模型')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showModelPicker = false; })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 8 })

          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.models, (m: LlmModelEntry, index: number) => {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Text(modelDisplayName(m))
                      .fontSize(this.palette.fsSm)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textPrimary)
                      .fontWeight(m.id === this.activeModelId ? FontWeight.Bold : FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(m.model)
                      .fontSize(10)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (m.id === this.activeModelId) {
                    Text('✓')
                      .fontSize(16)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.primary)
                      .fontWeight(FontWeight.Bold)
                  }
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor(m.id === this.activeModelId ? this.palette.primaryDim : this.palette.bgSurface)
                .border({ width: m.id === this.activeModelId ? 1 : 0,
                  color: m.id === this.activeModelId ? this.palette.primary : Color.Transparent })
                .onClick(() => { this.selectModel(index); })
              }, (m: LlmModelEntry) => m.id)
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 360 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showModelPicker = false; })
  }

  build() {
    Stack() {
      // 全局背景层：与首页/其他子页保持一致的视觉氛围
      GlobalBackgroundLayer()
      Column() {
        TopBar({
          title: this.selectionMode ? '已选 ' + this.selectedIds.length.toString() + ' 条' : 'AI 对话',
          subtitle: this.selectionMode ? '长按消息进入多选' : (this.showSearch ? '搜索模式' : this.configHint),
          showBack: true
        }) {
          if (this.selectionMode) {
            Row({ space: 16 }) {
              Text('删除')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.danger)
                .fontWeight(FontWeight.Medium)
                .onClick(() => { this.deleteSelected(); })
              Text('取消')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .onClick(() => { this.exitSelectionMode(); })
            }
          } else {
            Row({ space: 12 }) {
              Text('🔍')
                .fontSize(16)
                .fontFamily(this.palette.fontSans)
                .opacity(this.showSearch ? 0.5 : 1)
                .onClick(() => {
                  if (this.messages.length > 0) {
                    this.showSearch = !this.showSearch;
                    if (!this.showSearch) {
                      this.searchQuery = '';
                      this.searchRole = 'all';
                    }
                  } else {
                    promptAction.showToast({ message: '暂无对话记录可搜索' });
                  }
                })
              Text('🧹')
                .fontSize(18)
                .fontFamily(this.palette.fontSans)
                .onClick(() => { this.clearChat(); })
              Text('⚙️')
                .fontSize(18)
                .fontFamily(this.palette.fontSans)
                .onClick(() => { this.openConfig(); })
            }
          }
        }

        // 搜索栏
        if (this.showSearch && !this.selectionMode) {
          this.searchBar()
        }

        // 消息列表
        if (this.messages.length === 0) {
          this.emptyWelcome()
        } else if (this.showSearch && !this.selectionMode && this.searchResultCount() === 0) {
          this.searchEmpty()
        } else {
          List({ space: 12, scroller: this.scrollController }) {
            ForEach(this.selectionMode ? this.messages : (this.showSearch ? this.displayMessages() : this.messages),
              (message: ChatMessage, index: number) => {
              ListItem() {
                // 使用子组件，通过 @ObjectLink 监听 @Observed ChatMessage 的变化
                MessageBubble({ message: message, index: index,
                  selectionMode: this.selectionMode,
                  selected: this.isSelected(message.id),
                  isStreaming: this.streaming,
                  onRetry: (i: number): void => { this.retryLast(); },
                  onLongPressMessage: (i: number): void => { this.showActionSheet(i); },
                  onToggleSelect: (i: number): void => { this.toggleSelect(i); },
                  onExpandReasoning: (i: number): void => { this.expandReasoning(i); },
                  onFullscreen: (i: number): void => { this.openFullscreen(i); } })
              }
            }, (message: ChatMessage) => message.id)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12 })
        }

        // 底部区域
        if (this.selectionMode) {
          Row({ space: 8 }) {
            Button(this.selectedIds.length === 0 ? '全选' : '取消全选')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => {
                if (this.selectedIds.length === this.messages.length) {
                  this.selectedIds = [];
                } else {
                  this.selectedIds = this.messages.map((m: ChatMessage): string => m.id);
                }
              })
            Button('复制')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => { this.copySelected(); })
            Button('分享')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => { this.shareSelected(); })
            Button('删除 (' + this.selectedIds.length.toString() + ')')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.danger)
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => { this.deleteSelected(); })
          }
          .width('100%')
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8,
            bottom: Math.max(8, this.navBarHeight) })
        } else if (this.showSearch) {
          // 搜索模式下显示退出按钮
          Row() {
            Text('退出搜索，返回对话')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(44)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
          .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
          .borderRadius(10)
          .onClick(() => { this.exitSearch(); })
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24,
            bottom: Math.max(8, this.navBarHeight) })
        } else {
          Column({ space: 8 }) {
            if (!this.configReady) {
              Row() {
                Text('⚠️ 尚未配置大模型 API，点击去配置')
                  .fontSize(11)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.warning)
                  .layoutWeight(1)
                Text('去配置 ›')
                  .fontSize(11)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(10)
              .borderRadius(8)
              .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
              .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
              .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
              .onClick(() => { this.openConfig(); })
            }
            // 当前模型切换
            Row({ space: 6 }) {
              Text('🤖')
                .fontSize(12)
                .fontFamily(this.palette.fontSans)
              Text(this.currentModelName())
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('▾')
                .fontSize(10)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .onClick(() => {
              if (this.models.length > 0) {
                this.showModelPicker = true;
              } else {
                promptAction.showToast({ message: '请先配置模型' });
              }
            })
            this.inputBar()
          }
          .width('100%')
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: Math.max(8, this.navBarHeight) })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.bgBase)

      if (this.showModelPicker) { this.modelPicker() }

      // 长按消息操作面板（复制/分享/多选/删除）
      if (this.actionSheetIndex >= 0) {
        Stack() {
          Column() {
            Column({ space: 0 }) {
              // 消息预览（截取前 80 字）
              Text(this.actionSheetPreviewText())
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .lineHeight(18)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding(12)
              // 操作按钮
              Row({ space: 0 }) {
                Column({ space: 4 }) {
                  Text('📋')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('复制')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.copyMessage(this.actionSheetIndex); })

                Column({ space: 4 }) {
                  Text('📤')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('分享')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.shareMessage(this.actionSheetIndex); })

                Column({ space: 4 }) {
                  Text('☑️')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('多选')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.enterMultiSelectFromSheet(); })

                Column({ space: 4 }) {
                  Text('🗑️')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('删除')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.deleteSingle(this.actionSheetIndex); })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })

              // 取消
              Text('取消')
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .height(44)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(10)
                .onClick(() => { this.closeActionSheet(); })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette.bgBase)
            .borderRadius({ topLeft: 16, topRight: 16 })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick(() => { this.closeActionSheet(); })
      }

      // 全屏 markdown 查看（双击助手消息打开）
      if (this.fullscreenIndex >= 0) {
        Stack() {
          Column() {
            Row() {
              Text('Markdown 预览')
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(16)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .padding(8)
                .onClick(() => { this.closeFullscreen(); })
            }
            .width('100%')
            .padding({ left: 16, right: 8, top: 12, bottom: 8 })

            // 全屏 markdown 渲染（Web 组件，带滚动）
            Scroll() {
              Column() {
                if (this.fullscreenIndex >= 0 && this.fullscreenIndex < this.messages.length) {
                  Web({ src: 'about:blank',
                    controller: this.fullscreenController })
                    .width('100%')
                    .height(2000)
                    .backgroundColor(Color.Transparent)
                    .onControllerAttached(() => {
                      const m: ChatMessage = this.messages[this.fullscreenIndex];
                      const content: string = m.reasoning.trim().length > 0 ?
                        '💭 思考过程\n\n' + m.reasoning.trim() + '\n\n---\n\n' + m.content : m.content;
                      this.fullscreenController.loadData(
                        MarkdownConverter.toHtml(content, this.isDark), 'text/html', 'UTF-8', 'data');
                    })
                }
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .layoutWeight(1)
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.palette.bgBase)
          .padding({ bottom: Math.max(0, this.navBarHeight) })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}

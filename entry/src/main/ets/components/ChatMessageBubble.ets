// 智子 - 聊天气泡组件（用户/助手消息、思考折叠、流式 Markdown、Token 用量、失败重试）
import { ChatMessage } from '../common/LlmModels';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel, FxBudget } from './GlassEffect';
import { ChatMarkdownText } from './ChatMarkdownText';

@Component
export struct ChatMessageBubble {
  @ObjectLink message: ChatMessage;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDark: boolean = false;
  @Prop index: number = 0;
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;
  @Prop isStreaming: boolean = false;
  @Prop speaking: boolean = false;
  onRetry: (index: number) => void = () => {};
  onLongPressMessage: (index: number) => void = () => {};
  onToggleSelect: (index: number) => void = () => {};
  onExpandReasoning: (index: number) => void = () => {};
  onFullscreen: (index: number) => void = () => {};
  onCopyCode: (lang: string, code: string) => void = () => {};
  onSpeak: (index: number) => void = () => {};
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

  // 是否应使用 markdown 渲染（助手消息、非失败、有内容；流式中也渲染以保持排版连续）
  private useMarkdown(): boolean {
    return this.message.role === 'assistant' && !this.isFailure() &&
      this.message.content.trim().length > 0;
  }

  // Token 数量格式化：>=1000 显示为 x.xk
  private fmtTokens(n: number): string {
    if (n >= 1000) {
      const k: number = Math.round((n / 1000) * 10) / 10;
      return k.toString() + 'k';
    }
    return n.toString();
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
            // 朗读按钮：助手消息且非流式中显示
            if (!this.isStreaming && this.message.content.trim().length > 0 && !this.isFailure()) {
              Text(this.speaking ? '🛑' : '🔊')
                .fontSize(12)
                .fontFamily(this.palette.fontSans)
                .padding(3)
                .borderRadius(5)
                .backgroundColor(this.speaking ? this.palette.primaryDim : Color.Transparent)
                .onClick(() => { this.onSpeak(this.index); })
            }
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
              ChatMarkdownText({ content: this.message.content, onCopyCode: this.onCopyCode })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1,
              color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .backgroundBlurStyle(this.glassEnabled && !FxBudget.isLowBattery() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
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
              .backgroundBlurStyle(this.glassEnabled && !FxBudget.isLowBattery() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
              .constraintSize({ maxWidth: this.isSm ? 280 : 440 })
          }
          // 流式状态指示 / 完成后 Token 用量 / 失败错误码
          if (this.isStreaming && this.message.content.trim().length > 0) {
            Row({ space: 5 }) {
              LoadingProgress()
                .width(12)
                .height(12)
                .color(this.palette.textTertiary)
              Text('生成中…')
                .fontSize(10)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
            }
            .padding({ left: 12, top: 4 })
          } else if (!this.isStreaming && this.message.totalTokens > 0) {
            Text('⚡ 输入 ' + this.fmtTokens(this.message.inputTokens) +
              ' · 输出 ' + this.fmtTokens(this.message.outputTokens) +
              ' · 共 ' + this.fmtTokens(this.message.totalTokens))
              .fontSize(10)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding({ left: 12, top: 4 })
          } else if (this.isFailure() && this.message.errorCode.length > 0) {
            Text('错误码：' + this.message.errorCode)
              .fontSize(10)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding({ left: 12, top: 4 })
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


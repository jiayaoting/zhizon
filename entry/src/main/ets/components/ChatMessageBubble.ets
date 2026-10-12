// 智子 - 聊天气泡组件（用户/助手消息、思考折叠、流式 Markdown、Token 用量、失败重试）
// v10 华为拟物白：用户气泡 = primary 底 + primaryOnColor 字（右对齐，右下小圆角尾巴）；
//               AI 气泡 = bgSurface2 底 + textPrimary 字（左对齐，左下小圆角尾巴）+ 发丝描边；
//               元信息 fsXs textTertiary；内容块不再使用毛玻璃（内容卡去玻璃化）。
import { AppStorageV2 } from '@kit.ArkUI';
import { ChatMessage } from '../common/LlmModels';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { ChatMarkdownText } from './ChatMarkdownText';

@ComponentV2
export struct ChatMessageBubble {
  // V2：ChatMessage 为 V2 可观察类（Trace 属性），@Param 传引用即可观察流式原地修改
  @Param message: ChatMessage = new ChatMessage('', '', '');
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Param index: number = 0;
  @Param selectionMode: boolean = false;
  @Param selected: boolean = false;
  @Param isStreaming: boolean = false;
  @Param speaking: boolean = false;
  @Event onRetry: (index: number) => void = () => {};
  @Event onLongPressMessage: (index: number) => void = () => {};
  @Event onToggleSelect: (index: number) => void = () => {};
  @Event onExpandReasoning: (index: number) => void = () => {};
  @Event onFullscreen: (index: number) => void = () => {};
  @Event onCopyCode: (lang: string, code: string) => void = () => {};
  @Event onSpeak: (index: number) => void = () => {};
  @Local reasoningExpanded: boolean = false;
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

  // 气泡最大宽度：手机 ≈78% 屏宽（280vp），大屏限宽保证行长舒适
  private bubbleMaxWidth(): number {
    return this.themeState.isSm ? 280 : 560;
  }

  // 助手元信息单行：时间 + 模型名（时间或模型缺失时自动省略分隔符）
  private assistantMeta(): string {
    const parts: string[] = ['智子 AI'];
    const time: string = this.formatTime(this.message.time);
    if (time.length > 0) parts.push(time);
    if (this.message.modelName.trim().length > 0) parts.push(this.message.modelName.trim());
    return parts.join(' · ');
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
        Row() {
          Row() {
            if (this.selected) {
              if (USE_SYMBOL_ICONS) {
                SymbolGlyph(AppIcons.check)
                  .fontSize(14)
                  .fontColor([this.themeState.palette.primaryOnColor])
              } else {
                Text(AppIcons.checkEmoji)
                  .fontSize(11)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primaryOnColor)
              }
            }
          }
          .width(22)
          .height(22)
          .borderRadius(11)
          .border({ width: 2, color: this.selected ? this.themeState.palette.primary : this.themeState.palette.borderStrong })
          .backgroundColor(this.selected ? this.themeState.palette.primary : Color.Transparent)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .padding({ right: 8 })
        .onClick(() => { this.onToggleSelect(this.index); })
      }

      if (this.message.role === 'user') {
        Blank()
        Column({ space: 4 }) {
          // 用户气泡：primary 底 + primaryOnColor 字，右下角小圆角作"尾巴"
          Text(this.message.content.trim())
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .lineHeight(24)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius({ topLeft: this.themeState.palette.radiusLg, topRight: this.themeState.palette.radiusLg,
              bottomLeft: this.themeState.palette.radiusLg, bottomRight: this.themeState.palette.sp1 })
            .backgroundColor(this.themeState.palette.primary)
            .constraintSize({ maxWidth: this.bubbleMaxWidth() })
        }
        .alignItems(HorizontalAlign.End)
        .gesture(LongPressGesture().onAction(() => { this.handleLongPress(); }))
      } else {
        Column({ space: 4 }) {
          // 元信息行：身份 + 时间 + 模型（fsXs textTertiary，单行省略避免溢出）
          Row({ space: 6 }) {
            Text('🤖')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
            Text(this.assistantMeta())
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: this.themeState.isSm ? 190 : 360 })
            // 朗读按钮：助手消息且非流式中显示（矢量图标，选中态主色）
            if (!this.isStreaming && this.message.content.trim().length > 0 && !this.isFailure()) {
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(AppIcons.speaker)
                    .fontSize(18)
                    .fontColor([this.speaking ? this.themeState.palette.primary : this.themeState.palette.textSecondary])
                } else {
                  Text(AppIcons.speakerEmoji)
                    .fontSize(14)
                    .fontFamily(this.themeState.palette.fontSans)
                }
              }
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.speaking ? this.themeState.palette.primaryBgStrong : Color.Transparent)
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .accessibilityText(this.speaking ? '停止朗读' : '朗读回复')
              .onClick(() => { this.onSpeak(this.index); })
            }
          }
          // 思考过程折叠区块：默认收起，点击展开查看思考内容
          if (this.message.reasoning.trim().length > 0) {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text('💭')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                Text('已深度思考')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                Text(this.reasoningExpanded ? '▲' : '▼')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.themeState.palette.bgBase)
              .onClick(() => { this.toggleReasoning(); })
              if (this.reasoningExpanded) {
                // 思考内容限高可滚动：长思考不会撑爆列表，且用户无需滑回顶部即可收起
                Scroll(this.reasoningScroller) {
                  Text(this.message.reasoning.trim())
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .lineHeight(18)
                    .width('100%')
                    .padding(8)
                }
                .scrollBar(BarState.Off)
                .constraintSize({ maxHeight: 200 })
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(this.themeState.palette.bgBase)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          // 正文：流式中也用 markdown 渲染（排版连续），结束后为最终结果
          if (this.useMarkdown()) {
            Column() {
              ChatMarkdownText({ content: this.message.content, onCopyCode: this.onCopyCode })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius({ topLeft: this.themeState.palette.radiusLg, topRight: this.themeState.palette.radiusLg,
              bottomLeft: this.themeState.palette.sp1, bottomRight: this.themeState.palette.radiusLg })
            .backgroundColor(this.themeState.palette.bgSurface2)
            .border({ width: 1, color: this.themeState.palette.borderSubtle })
            .constraintSize({ maxWidth: this.bubbleMaxWidth() })
            .gesture(TapGesture({ count: 2 }).onAction(() => { this.onFullscreen(this.index); }))
          } else {
            Text(this.message.content.trim().length > 0 ? this.message.content.trim() : '…')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .lineHeight(24)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius({ topLeft: this.themeState.palette.radiusLg, topRight: this.themeState.palette.radiusLg,
                bottomLeft: this.themeState.palette.sp1, bottomRight: this.themeState.palette.radiusLg })
              .backgroundColor(this.themeState.palette.bgSurface2)
              .border({ width: 1, color: this.themeState.palette.borderSubtle })
              .constraintSize({ maxWidth: this.bubbleMaxWidth() })
          }
          // 流式状态指示 / 完成后 Token 用量 / 失败错误码
          if (this.isStreaming && this.message.content.trim().length > 0) {
            Row({ space: 5 }) {
              LoadingProgress()
                .width(12)
                .height(12)
                .color(this.themeState.palette.textTertiary)
              Text('生成中…')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .padding({ left: 4, top: 4 })
          } else if (!this.isStreaming && this.message.totalTokens > 0) {
            Text('输入 ' + this.fmtTokens(this.message.inputTokens) +
              ' · 输出 ' + this.fmtTokens(this.message.outputTokens) +
              ' · 共 ' + this.fmtTokens(this.message.totalTokens))
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .padding({ left: 4, top: 4 })
          } else if (this.isFailure() && this.message.errorCode.length > 0) {
            Text('错误码：' + this.message.errorCode)
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .padding({ left: 4, top: 4 })
          }
          // 失败时显示重试按钮（胶囊 + 主色淡底）
          if (this.isFailure()) {
            Row({ space: 4 }) {
              if (USE_SYMBOL_ICONS) {
                SymbolGlyph(AppIcons.refresh)
                  .fontSize(14)
                  .fontColor([this.themeState.palette.primary])
              } else {
                Text(AppIcons.refreshEmoji)
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
              }
              Text('重试')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 12, right: 14, top: 6, bottom: 6 })
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.themeState.palette.primaryBg)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
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

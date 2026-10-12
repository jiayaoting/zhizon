// 智子 - 聊天气泡 Markdown 渲染组件（纯 ArkUI 原生组件，流式安全）
// v10：仅做 token/字号接入（颜色全部取自 palette，代码块/引用块用 bgBase 底 + radiusSm，链接用 primary）；
//      解析与节流逻辑保持不变。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { MarkdownConverter, MdBlock, InlineSpan } from '../common/MarkdownConverter';
import { SyntaxHighlighter, CodeToken } from '../common/SyntaxHighlighter';

@ComponentV2
export struct ChatMarkdownText {
  @Param content: string = '';
  // 回调（ArkUI V2 组件统一使用 @Event）
  @Event onCopyCode: (lang: string, code: string) => void = () => {};
  // 链接点击回调：段落内含链接时整段可点击（ArkUI Span 不支持独立点击事件，采用段落级简化方案）
  @Event onLinkTap: (url: string) => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // ---- 解析缓存：仅在 content 实际变化时重新解析，避免每次重渲染全量重建 ----
  // 流式对话中 build() 会高频触发，若在 build 内直接调 parseBlocks/parseInline，
  // 每次重渲染都会产生成百上千个数组/对象，且 ForEach 的 diff 会滞留旧数据，
  // 最终导致 JS 堆内存暴涨 OOM（曾出现 431 万 Array 滞留崩溃）。
  // content 变化时解析一次并存入 @Local，build 只消费缓存结果。
  @Local blocks: MdBlock[] = [];
  private parsedContent: string = '';
  // 流式解析节流：内容每 60ms 变化一次，但全量解析最多每 250ms 一次，
  // 避免 O(n²) 反复解析正在增长的整条消息；流式结束后定时器兜底补齐最终结果
  private lastParseTime: number = 0;
  private parseTimer: number = -1;
  private parsePending: boolean = false;
  private static readonly PARSE_THROTTLE_MS: number = 250;
  // 行内 span 缓存：同一段文本只解析一次（按文本内容做 key）
  private spanCache: Map<string, InlineSpan[]> = new Map();
  // 段落合并文本缓存：避免每次 build 都对 block.items 重新 join 生成新字符串
  private paraJoinCache: Map<MdBlock, string> = new Map();

  aboutToAppear(): void {
    this.parsePending = false;
    this.parseTimer = -1;
    this.parseContent();
  }

  aboutToDisappear(): void {
    this.cancelPendingTimer();
  }

  // content 变化（含流式每 60ms 的赋值）→ 节流解析（V1 Watch 迁移为 V2 Monitor）
  @Monitor('content')
  private onContentChange(monitor: IMonitor): void {
    this.parseContent();
  }

  private cancelPendingTimer(): void {
    if (this.parseTimer >= 0) {
      clearTimeout(this.parseTimer);
      this.parseTimer = -1;
    }
    this.parsePending = false;
  }

  private parseContent(): void {
    if (this.parsedContent === this.content) return;
    const now: number = Date.now();
    // 首帧或超过节流间隔 → 立即解析（取消可能残留的兜底定时器，避免重复解析）
    if (this.parsedContent.length === 0 ||
      now - this.lastParseTime >= ChatMarkdownText.PARSE_THROTTLE_MS) {
      this.cancelPendingTimer();
      this.doParse();
      return;
    }
    // 节流窗口内：仅安排一次兜底重解析（避免流式结束的最后一段内容永远显示旧值）
    if (!this.parsePending) {
      this.parsePending = true;
      this.parseTimer = setTimeout(() => {
        this.parsePending = false;
        this.parseTimer = -1;
        // 兜底触发时若内容已与缓存一致（比如即时路径已抢先解析）则跳过
        if (this.parsedContent !== this.content) {
          this.doParse();
        }
      }, ChatMarkdownText.PARSE_THROTTLE_MS);
    }
  }

  private doParse(): void {
    this.parsedContent = this.content;
    this.lastParseTime = Date.now();
    this.spanCache.clear();
    this.paraJoinCache.clear();
    this.blocks = MarkdownConverter.parseBlocks(this.content);
  }

  // 段落文本：优先用缓存的合并结果，避免每次 build 重新 join 生成新字符串
  private paraText(block: MdBlock): string {
    if (block.items.length === 0) return block.text;
    let joined: string | undefined = this.paraJoinCache.get(block);
    if (joined === undefined) {
      joined = block.items.join('\n');
      this.paraJoinCache.set(block, joined);
    }
    return joined;
  }

  // 缓存行内解析结果：同一文本片段只 parseInline 一次
  private spansOf(text: string): InlineSpan[] {
    let spans: InlineSpan[] | undefined = this.spanCache.get(text);
    if (spans === undefined) {
      spans = MarkdownConverter.parseInline(text);
      this.spanCache.set(text, spans);
    }
    return spans;
  }

  // 行内富文本：Text 内嵌 Span 序列（支持粗体/斜体/行内代码/链接颜色）
  // ForEach 使用 index 稳定键：流式内容只在尾部增长，旧节点原地更新而非销毁重建
  @Builder
  inlineSpans(text: string) {
    ForEach(this.spansOf(text), (sp: InlineSpan, index: number) => {
      if (sp.code) {
        // 行内代码：圆角淡底 + 等宽字体（底色用 bgBase，与代码块同族）
        Span(' ' + sp.text + ' ')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontMono)
          .fontColor(this.themeState.palette.danger)
          .textBackgroundStyle({ color: this.themeState.palette.bgBase, radius: 4 })
      } else if (sp.link.length > 0) {
        // 链接：全站统一 primary（一个颜色一个含义）
        Span(sp.text)
          .fontSize(this.themeState.palette.fsMd)
          .fontColor(this.themeState.palette.primary)
          .decoration({ type: TextDecorationType.Underline, color: this.themeState.palette.primary })
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      } else {
        Span(sp.text)
          .fontSize(this.themeState.palette.fsMd)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      }
    }, (sp: InlineSpan, index: number) => index.toString())
  }

  // 段落/列表项（带行内格式；段落含链接时整段可点击打开第一个链接）
  @Builder
  para(text: string) {
    Text() {
      this.inlineSpans(text)
    }
    .fontSize(this.themeState.palette.fsMd)
    .fontFamily(this.themeState.palette.fontSans)
    .lineHeight(24)
    .width('100%')
    .onClick(() => {
      const link: string = this.paraFirstLink(text);
      if (link.length > 0) {
        this.onLinkTap(link);
      }
    })
  }

  // 段落中第一个链接 URL（无则空串）
  private paraFirstLink(text: string): string {
    const spans: InlineSpan[] = this.spansOf(text);
    for (let i: number = 0; i < spans.length; i++) {
      if (spans[i].link.length > 0) {
        return spans[i].link;
      }
    }
    return '';
  }

  build() {
    Column({ space: this.themeState.palette.sp2 }) {
      ForEach(this.blocks, (block: MdBlock, bi: number) => {
        if (block.kind === 'h1') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeState.palette.textPrimary)
          .lineHeight(26)
          .width('100%')
        } else if (block.kind === 'h2') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeState.palette.textPrimary)
          .lineHeight(24)
          .width('100%')
        } else if (block.kind === 'h3') {
          Text() {
            this.inlineSpans(block.text)
          }
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeState.palette.textPrimary)
          .lineHeight(22)
          .width('100%')
        } else if (block.kind === 'code') {
          Column({ space: 0 }) {
            // 代码块头部：语言标注 + 复制按钮（流式中也可复制当前已生成内容）
            Row({ space: this.themeState.palette.sp2 }) {
              Text(block.text.length > 0 ? block.text : 'code')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontMono)
                .fontColor(this.themeState.palette.textTertiary)
              Blank()
              Text('复制')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(this.themeState.palette.bgHover)
                .onClick(() => { this.onCopyCode(block.text, block.lines.join('\n')); })
            }
            .width('100%')
            .padding({ left: 10, right: 8, top: 6, bottom: 4 })
            ForEach(block.lines, (ln: string) => {
              if (ln.length === 0) {
                Text(' ')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontMono)
                  .lineHeight(20)
                  .width('100%')
              } else if (block.text.length > 0 && SyntaxHighlighter.isSupported(block.text)) {
                // 语法高亮：Text + Span 逐 token 着色（可自动换行）
                Text() {
                  ForEach(SyntaxHighlighter.highlightLine(ln, block.text, this.themeState.isDark), (tok: CodeToken) => {
                    Span(tok.text)
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontMono)
                      .fontColor(tok.color)
                  }, (tok: CodeToken, ti: number) => ti.toString())
                }
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontMono)
                .lineHeight(20)
                .width('100%')
              } else {
                Text(ln)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontMono)
                  .fontColor(this.themeState.palette.textPrimary)
                  .lineHeight(20)
                  .width('100%')
              }
            }, (ln: string, li: number) => li.toString())
          }
          .width('100%')
          .padding({ left: 10, right: 10, bottom: 10 })
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.bgBase)
        } else if (block.kind === 'quote') {
          // 引用块：与代码块同族（bgBase 淡底 + radiusSm，竖线改用边框实现，避免空容器塌陷）
          Column({ space: 2 }) {
            ForEach(block.items, (q: string, qi: number) => {
              Text() {
                this.inlineSpans(q)
              }
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textSecondary)
              .fontStyle(FontStyle.Italic)
              .lineHeight(24)
              .width('100%')
            }, (q: string, qi: number) => qi.toString())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.bgBase)
          .border({ width: { left: 3 }, color: this.themeState.palette.primary })
        } else if (block.kind === 'hr') {
          Divider()
            .strokeWidth(0.5)
            .color(this.themeState.palette.divider)
            .margin({ top: 4, bottom: 4 })
        } else if (block.kind === 'ul') {
          Column({ space: 3 }) {
            ForEach(block.items, (it: string) => {
              Row({ space: 6 }) {
                Text('•')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textSecondary)
                Text() {
                  this.inlineSpans(it)
                }
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .lineHeight(24)
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (it: string, ii: number) => ii.toString())
          }
          .width('100%')
        } else if (block.kind === 'ol') {
          Column({ space: 3 }) {
            ForEach(block.items, (it: string) => {
              Row({ space: 6 }) {
                Text() {
                  this.inlineSpans(it)
                }
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .lineHeight(24)
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (it: string, ii: number) => ii.toString())
          }
          .width('100%')
        } else if (block.kind === 'table') {
          Column({ space: 2 }) {
            if (block.lines.length > 0) {
              Text() {
                this.inlineSpans(block.lines[0])
              }
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeState.palette.textPrimary)
              .lineHeight(24)
              .width('100%')
            }
            ForEach(block.items, (rw: string) => {
              Text() {
                this.inlineSpans(rw)
              }
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textSecondary)
              .lineHeight(20)
              .width('100%')
            }, (rw: string, ri: number) => ri.toString())
          }
          .width('100%')
          .padding(8)
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.bgBase)
        } else {
          this.para(this.paraText(block))
        }
      }, (block: MdBlock, index: number) => index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

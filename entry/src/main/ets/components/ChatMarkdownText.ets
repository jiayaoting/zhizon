// 智子 - 聊天气泡 Markdown 渲染组件（纯 ArkUI 原生组件，流式安全）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { MarkdownConverter, MdBlock, InlineSpan } from '../common/MarkdownConverter';
import { SyntaxHighlighter, CodeToken } from '../common/SyntaxHighlighter';

@Component
export struct ChatMarkdownText {
  @Prop @Watch('onContentChange') content: string = '';
  // 普通字段回调（ArkUI V1 @Prop 不支持函数类型，沿用消息气泡的回调传参方式）
  onCopyCode: (lang: string, code: string) => void = () => {};
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isDarkMode') isDark: boolean = false;

  // ---- 解析缓存：仅在 content 实际变化时重新解析，避免每次重渲染全量重建 ----
  // 流式对话中 build() 会高频触发，若在 build 内直接调 parseBlocks/parseInline，
  // 每次重渲染都会产生成百上千个数组/对象，且 ForEach 的 diff 会滞留旧数据，
  // 最终导致 JS 堆内存暴涨 OOM（曾出现 431 万 Array 滞留崩溃）。
  // @Watch 在 content 变化时解析一次并存入 @State，build 只消费缓存结果。
  @State blocks: MdBlock[] = [];
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

  // content 变化（含流式每 60ms 的赋值）→ 节流解析
  private onContentChange(): void {
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
        Span(' ' + sp.text + ' ')
          .fontSize(this.palette.fsSm - 1)
          .fontFamily(this.palette.fontMono)
          .fontColor(this.isDark ? '#FCA5A5' : '#C0392B')
          .textBackgroundStyle({ color: this.isDark ? '#1E293B' : '#F1F5F9', radius: 3 })
      } else if (sp.link.length > 0) {
        Span(sp.text)
          .fontSize(this.palette.fsSm)
          .fontColor(this.isDark ? '#60A5FA' : '#2563EB')
          .decoration({ type: TextDecorationType.Underline, color: this.isDark ? '#60A5FA' : '#2563EB' })
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      } else {
        Span(sp.text)
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textPrimary)
          .fontWeight(sp.bold ? FontWeight.Bold : FontWeight.Medium)
          .fontStyle(sp.italic ? FontStyle.Italic : FontStyle.Normal)
      }
    }, (sp: InlineSpan, index: number) => index.toString())
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
      ForEach(this.blocks, (block: MdBlock, bi: number) => {
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
            // 代码块头部：语言标注 + 复制按钮（流式中也可复制当前已生成内容）
            Row({ space: 8 }) {
              Text(block.text.length > 0 ? block.text : 'code')
                .fontSize(10)
                .fontFamily(this.palette.fontMono)
                .fontColor(this.isDark ? '#94A3B8' : '#64748B')
              Blank()
              Text('复制')
                .fontSize(10)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.isDark ? '#60A5FA' : '#2563EB')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(6)
                .backgroundColor(this.isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)')
                .onClick(() => { this.onCopyCode(block.text, block.lines.join('\n')); })
            }
            .width('100%')
            .padding({ left: 10, right: 8, top: 6, bottom: 4 })
            ForEach(block.lines, (ln: string) => {
              if (ln.length === 0) {
                Text(' ')
                  .fontSize(this.palette.fsSm - 1)
                  .fontFamily(this.palette.fontMono)
                  .lineHeight(18)
                  .width('100%')
              } else if (block.text.length > 0 && SyntaxHighlighter.isSupported(block.text)) {
                // 语法高亮：Text + Span 逐 token 着色（可自动换行）
                Text() {
                  ForEach(SyntaxHighlighter.highlightLine(ln, block.text, this.isDark), (tok: CodeToken) => {
                    Span(tok.text)
                      .fontSize(this.palette.fsSm - 1)
                      .fontFamily(this.palette.fontMono)
                      .fontColor(tok.color)
                  }, (tok: CodeToken, ti: number) => ti.toString())
                }
                .fontSize(this.palette.fsSm - 1)
                .fontFamily(this.palette.fontMono)
                .lineHeight(18)
                .width('100%')
              } else {
                Text(ln)
                  .fontSize(this.palette.fsSm - 1)
                  .fontFamily(this.palette.fontMono)
                  .fontColor(this.isDark ? '#FCA5A5' : '#C0392B')
                  .lineHeight(18)
                  .width('100%')
              }
            }, (ln: string, li: number) => li.toString())
          }
          .width('100%')
          .padding({ left: 10, right: 10, bottom: 10 })
          .borderRadius(8)
          .backgroundColor(this.isDark ? '#1E293B' : '#F1F5F9')
        } else if (block.kind === 'quote') {
          Column({ space: 2 }) {
            ForEach(block.items, (q: string, qi: number) => {
              Text() {
                this.inlineSpans(q)
              }
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
              .fontStyle(FontStyle.Italic)
              .lineHeight(20)
              .width('100%')
            }, (q: string, qi: number) => qi.toString())
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
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .lineHeight(20)
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
            }, (rw: string, ri: number) => ri.toString())
          }
          .width('100%')
          .padding(8)
          .borderRadius(6)
          .backgroundColor(this.isDark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)')
        } else {
          this.para(this.paraText(block))
        }
      }, (block: MdBlock, index: number) => index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

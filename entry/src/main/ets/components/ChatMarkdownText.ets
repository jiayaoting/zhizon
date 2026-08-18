// 智子 - 聊天气泡 Markdown 渲染组件（纯 ArkUI 原生组件，流式安全）
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { MarkdownConverter, MdBlock, InlineSpan } from '../common/MarkdownConverter';
import { SyntaxHighlighter, CodeToken } from '../common/SyntaxHighlighter';

@Component
export struct ChatMarkdownText {
  @Prop content: string = '';
  // 普通字段回调（ArkUI V1 @Prop 不支持函数类型，沿用消息气泡的回调传参方式）
  onCopyCode: (lang: string, code: string) => void = () => {};
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
                  }, (tok: CodeToken, ti: number) => tok.text + ti.toString())
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
            }, (ln: string, li: number) => ln + li.toString())
          }
          .width('100%')
          .padding({ left: 10, right: 10, bottom: 10 })
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

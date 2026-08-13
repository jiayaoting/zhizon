// 智子 - 轻量 Markdown → HTML 转换器（ArkTS 兼容，无外部依赖）
// 支持：标题、粗体、斜体、行内代码、代码块、无序/有序列表、引用、链接、表格、水平线、段落
export class MarkdownConverter {

  // 生成完整 HTML 文档（含内联 CSS），供 Web 组件 loadData 渲染
  static toHtml(md: string, isDark: boolean): string {
    const body: string = MarkdownConverter.toBodyHtml(md);
    const css: string = isDark ? MarkdownConverter.darkCss() : MarkdownConverter.lightCss();
    return '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">' +
      '<style>' + css + '</style></head><body>' + body + '</body></html>';
  }

  // 转 HTML 正文片段（不含 <html> 包裹）
  private static toBodyHtml(md: string): string {
    const lines: string[] = md.split('\n');
    const out: string[] = [];
    let i: number = 0;
    const n: number = lines.length;
    while (i < n) {
      const raw: string = lines[i];
      const line: string = raw.trim();
      // 空行跳过
      if (line.length === 0) {
        i++;
        continue;
      }
      // 代码块
      if (line.startsWith('```')) {
        const codeLines: string[] = [];
        i++;
        while (i < n && !lines[i].trim().startsWith('```')) {
          codeLines.push(lines[i]);
          i++;
        }
        i++; // 跳过结尾 ```
        out.push('<pre><code>' + MarkdownConverter.escapeHtml(codeLines.join('\n')) + '</code></pre>');
        continue;
      }
      // 标题
      if (line.startsWith('### ')) {
        out.push('<h3>' + MarkdownConverter.inline(line.substring(4)) + '</h3>');
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        out.push('<h2>' + MarkdownConverter.inline(line.substring(3)) + '</h2>');
        i++;
        continue;
      }
      if (line.startsWith('# ')) {
        out.push('<h1>' + MarkdownConverter.inline(line.substring(2)) + '</h1>');
        i++;
        continue;
      }
      // 引用（连续引用行合并为一个 blockquote）
      if (line.startsWith('>')) {
        const quoteLines: string[] = [];
        while (i < n && lines[i].trim().startsWith('>')) {
          let q: string = lines[i].trim();
          if (q.startsWith('> ')) q = q.substring(2);
          else q = q.substring(1);
          quoteLines.push(MarkdownConverter.inline(q));
          i++;
        }
        out.push('<blockquote>' + quoteLines.join('<br>') + '</blockquote>');
        continue;
      }
      // 水平线
      if (/^(-{3,}|\*{3,}|_{3,})$/.test(line)) {
        out.push('<hr>');
        i++;
        continue;
      }
      // 无序列表
      if (/^[-*+]\s+/.test(line)) {
        const items: string[] = [];
        while (i < n) {
          const t: string = lines[i].trim();
          if (/^[-*+]\s+/.test(t)) {
            items.push('<li>' + MarkdownConverter.inline(t.replace(/^[-*+]\s+/, '')) + '</li>');
            i++;
          } else if (t.length === 0) {
            break;
          } else {
            break;
          }
        }
        out.push('<ul>' + items.join('') + '</ul>');
        continue;
      }
      // 有序列表
      if (/^\d+[.)]\s+/.test(line)) {
        const items: string[] = [];
        while (i < n) {
          const t: string = lines[i].trim();
          if (/^\d+[.)]\s+/.test(t)) {
            items.push('<li>' + MarkdownConverter.inline(t.replace(/^\d+[.)]\s+/, '')) + '</li>');
            i++;
          } else if (t.length === 0) {
            break;
          } else {
            break;
          }
        }
        out.push('<ol>' + items.join('') + '</ol>');
        continue;
      }
      // 表格（需连续两行：表头 + 分隔行）
      if (line.indexOf('|') >= 0 && i + 1 < n && /^[\s:|-]+$/.test(lines[i + 1].trim())) {
        const header: string[] = MarkdownConverter.splitTableRow(line);
        const rows: string[][] = [];
        i += 2;
        while (i < n && lines[i].trim().indexOf('|') >= 0) {
          rows.push(MarkdownConverter.splitTableRow(lines[i]));
          i++;
        }
        let tableHtml: string = '<table><thead><tr>';
        for (let h: number = 0; h < header.length; h++) {
          tableHtml = tableHtml + '<th>' + MarkdownConverter.inline(header[h]) + '</th>';
        }
        tableHtml = tableHtml + '</tr></thead><tbody>';
        for (let r: number = 0; r < rows.length; r++) {
          tableHtml = tableHtml + '<tr>';
          const row: string[] = rows[r];
          for (let c: number = 0; c < header.length; c++) {
            tableHtml = tableHtml + '<td>' + MarkdownConverter.inline(c < row.length ? row[c] : '') + '</td>';
          }
          tableHtml = tableHtml + '</tr>';
        }
        tableHtml = tableHtml + '</tbody></table>';
        out.push(tableHtml);
        continue;
      }
      // 普通段落：连续非空行合并
      const paraLines: string[] = [];
      while (i < n) {
        const t: string = lines[i].trim();
        if (t.length === 0) break;
        if (t.startsWith('```') || t.startsWith('#') || /^(-{3,}|\*{3,}|_{3,})$/.test(t)) break;
        paraLines.push(MarkdownConverter.inline(t));
        i++;
      }
      out.push('<p>' + paraLines.join('<br>') + '</p>');
    }
    return out.join('');
  }

  private static splitTableRow(line: string): string[] {
    let t: string = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|');
  }

  // 行内格式化：转义 + 行内代码 + 粗体 + 斜体 + 链接
  private static inline(text: string): string {
    let r: string = MarkdownConverter.escapeHtml(text);
    // 行内代码：`code`
    r = MarkdownConverter.wrapOdd(r, '`', '<code>', '</code>');
    // 粗体 **text**
    r = MarkdownConverter.wrapOdd(r, '**', '<strong>', '</strong>');
    // 斜体 *text*（避免与粗体残留的 * 冲突：仅在成对时替换）
    r = MarkdownConverter.wrapOdd(r, '*', '<em>', '</em>');
    // 链接 [text](url)
    r = r.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
    return r;
  }

  // 将分隔符分隔的奇数段包裹标签（用于行内代码/粗体/斜体成对匹配）
  private static wrapOdd(input: string, delim: string, open: string, close: string): string {
    const parts: string[] = input.split(delim);
    if (parts.length < 3) return input;
    let result: string = parts[0];
    for (let i: number = 1; i < parts.length; i++) {
      if (i % 2 === 1) {
        result = result + open + parts[i] + close;
      } else {
        result = result + parts[i];
      }
    }
    return result;
  }

  private static escapeHtml(text: string): string {
    let r: string = text;
    r = r.replace(/&/g, '&amp;');
    r = r.replace(/</g, '&lt;');
    r = r.replace(/>/g, '&gt;');
    r = r.replace(/"/g, '&quot;');
    return r;
  }

  private static lightCss(): string {
    return MarkdownConverter.baseCss() +
      'body{background:transparent;color:#1A202C;}' +
      'pre{background:#F1F3F8;}' +
      'code{background:rgba(0,0,0,0.06);color:#C0392B;}' +
      'pre code{background:transparent;color:#1A202C;}' +
      'blockquote{background:rgba(0,0,0,0.04);border-left:3px solid #CBD5E0;color:#4A5568;}' +
      'a{color:#2563EB;}' +
      'th,td{border:1px solid #CBD5E0;}';
  }

  private static darkCss(): string {
    return MarkdownConverter.baseCss() +
      'body{background:transparent;color:#E2E8F0;}' +
      'pre{background:#0D1526;}' +
      'code{background:rgba(255,255,255,0.12);color:#FCA5A5;}' +
      'pre code{background:transparent;color:#E2E8F0;}' +
      'blockquote{background:rgba(255,255,255,0.06);border-left:3px solid #4A5568;color:#A0AEC0;}' +
      'a{color:#60A5FA;}' +
      'th,td{border:1px solid #334155;}';
  }

  private static baseCss(): string {
    return 'html,body{margin:0;padding:0;}' +
      'body{font-family:-apple-system,"HarmonyOS Sans",sans-serif;font-size:14px;line-height:1.65;' +
      'word-break:break-word;overflow-wrap:anywhere;-webkit-user-select:none;user-select:none;}' +
      'p{margin:4px 0;}' +
      'h1,h2,h3,h4{margin:10px 0 6px;line-height:1.4;}' +
      'h1{font-size:19px;}h2{font-size:17px;}h3{font-size:15px;}' +
      'ul,ol{margin:4px 0;padding-left:22px;}' +
      'li{margin:3px 0;}' +
      'pre{margin:8px 0;padding:10px 12px;border-radius:8px;overflow-x:auto;' +
      'font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;line-height:1.5;' +
      'white-space:pre-wrap;}' +
      'code{font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;' +
      'padding:1px 5px;border-radius:4px;}' +
      'blockquote{margin:6px 0;padding:6px 12px;border-radius:6px;}' +
      'a{text-decoration:none;}' +
      'hr{border:none;border-top:1px solid rgba(128,128,128,0.3);margin:10px 0;}' +
      'table{border-collapse:collapse;margin:6px 0;font-size:13px;}' +
      'th,td{padding:5px 10px;text-align:left;}' +
      'img{max-width:100%;border-radius:6px;}';
  }
}

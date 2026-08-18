// 智子 - 轻量代码语法高亮（纯 ArkTS 实现，无第三方依赖）
// 支持常见语言关键字着色 + 字符串/注释/数字；未知语言回退为单色

export class CodeToken {
  text: string;
  color: string;

  constructor(text: string, color: string) {
    this.text = text;
    this.color = color;
  }
}

export class SyntaxHighlighter {
  private static readonly COMMENT_COLOR = '#6A737D';
  private static readonly STRING_COLOR = '#98C379';
  private static readonly KEYWORD_COLOR = '#C678DD';
  private static readonly NUMBER_COLOR = '#D19A66';
  private static readonly DEFAULT_LIGHT = '#1A202C';
  private static readonly DEFAULT_DARK = '#E2E8F0';

  private static readonly KEYWORDS: Record<string, string[]> = {
    'ts': ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'do',
      'switch', 'case', 'break', 'continue', 'new', 'class', 'interface', 'extends', 'implements',
      'public', 'private', 'protected', 'static', 'readonly', 'async', 'await', 'import', 'export',
      'from', 'default', 'type', 'enum', 'namespace', 'throw', 'try', 'catch', 'finally', 'void',
      'null', 'undefined', 'true', 'false', 'this', 'typeof', 'instanceof', 'in', 'of', 'yield',
      'get', 'set', 'super', 'delete', 'as'],
    'js': ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'do',
      'switch', 'case', 'break', 'continue', 'new', 'class', 'extends', 'async', 'await',
      'import', 'export', 'from', 'default', 'throw', 'try', 'catch', 'finally', 'void',
      'null', 'undefined', 'true', 'false', 'this', 'typeof', 'instanceof', 'in', 'of',
      'yield', 'super', 'delete'],
    'typescript': ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while',
      'new', 'class', 'interface', 'extends', 'public', 'private', 'static', 'async', 'await',
      'import', 'export', 'from', 'default', 'type', 'enum', 'null', 'undefined', 'true',
      'false', 'this', 'typeof', 'instanceof', 'void'],
    'javascript': ['const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while',
      'new', 'class', 'extends', 'async', 'await', 'import', 'export', 'from', 'default',
      'null', 'undefined', 'true', 'false', 'this', 'typeof', 'instanceof', 'void'],
    'python': ['def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while', 'import', 'from',
      'as', 'with', 'try', 'except', 'finally', 'raise', 'pass', 'break', 'continue', 'lambda',
      'yield', 'global', 'nonlocal', 'True', 'False', 'None', 'and', 'or', 'not', 'in', 'is',
      'assert', 'async', 'await'],
    'py': ['def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while', 'import', 'from',
      'as', 'with', 'try', 'except', 'finally', 'raise', 'pass', 'break', 'continue', 'lambda',
      'yield', 'global', 'nonlocal', 'True', 'False', 'None', 'and', 'or', 'not', 'in', 'is',
      'assert', 'async', 'await'],
    'java': ['public', 'private', 'protected', 'static', 'final', 'class', 'interface', 'enum',
      'extends', 'implements', 'new', 'return', 'if', 'else', 'for', 'while', 'do', 'switch',
      'case', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'throws', 'import',
      'package', 'void', 'int', 'long', 'double', 'float', 'boolean', 'char', 'byte', 'short',
      'String', 'this', 'super', 'null', 'true', 'false', 'instanceof', 'synchronized', 'volatile',
      'abstract', 'default', 'record'],
    'go': ['func', 'package', 'import', 'return', 'if', 'else', 'for', 'range', 'switch', 'case',
      'break', 'continue', 'defer', 'go', 'chan', 'struct', 'interface', 'type', 'map', 'var',
      'const', 'nil', 'true', 'false', 'len', 'cap', 'make', 'new', 'append', 'error', 'string',
      'int', 'float64', 'bool', 'byte', 'rune', 'select', 'fallthrough', 'default'],
    'rust': ['fn', 'let', 'mut', 'pub', 'use', 'mod', 'struct', 'enum', 'impl', 'trait', 'return',
      'if', 'else', 'for', 'while', 'loop', 'match', 'break', 'continue', 'move', 'ref', 'async',
      'await', 'dyn', 'type', 'const', 'static', 'true', 'false', 'None', 'Some', 'Result', 'Ok',
      'Err', 'String', 'i32', 'u32', 'f64', 'bool', 'char', 'usize'],
    'sql': ['select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set', 'delete',
      'create', 'table', 'drop', 'alter', 'add', 'column', 'primary', 'key', 'foreign', 'join',
      'inner', 'left', 'right', 'full', 'on', 'group', 'by', 'order', 'having', 'limit', 'offset',
      'and', 'or', 'not', 'null', 'is', 'in', 'like', 'between', 'as', 'distinct', 'count', 'sum',
      'avg', 'min', 'max', 'index', 'unique', 'default', 'if', 'exists', 'with', 'union', 'all',
      'case', 'when', 'then', 'else', 'end'],
    'bash': ['if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done', 'case', 'esac',
      'function', 'return', 'exit', 'echo', 'export', 'local', 'read', 'cd', 'mkdir', 'rm',
      'cp', 'mv', 'grep', 'sed', 'awk', 'find', 'ls', 'cat', 'source', 'alias', 'set', 'unset',
      'true', 'false', 'shift', 'break', 'continue'],
    'shell': ['if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done', 'case', 'esac',
      'function', 'return', 'exit', 'echo', 'export', 'local', 'read', 'cd', 'mkdir', 'rm',
      'cp', 'mv', 'grep', 'sed', 'awk', 'find', 'ls', 'cat', 'source', 'alias', 'set', 'unset',
      'true', 'false', 'shift', 'break', 'continue'],
    'c': ['int', 'char', 'float', 'double', 'void', 'long', 'short', 'unsigned', 'signed',
      'struct', 'union', 'enum', 'typedef', 'static', 'extern', 'const', 'volatile', 'register',
      'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default', 'break',
      'continue', 'goto', 'sizeof', 'NULL', 'true', 'false', 'include', 'define'],
    'cpp': ['int', 'char', 'float', 'double', 'void', 'long', 'short', 'unsigned', 'signed',
      'struct', 'union', 'enum', 'class', 'namespace', 'template', 'typename', 'typedef',
      'static', 'extern', 'const', 'constexpr', 'volatile', 'auto', 'return', 'if', 'else',
      'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue', 'new', 'delete',
      'this', 'nullptr', 'true', 'false', 'include', 'define', 'public', 'private', 'protected',
      'virtual', 'override', 'friend', 'operator'],
    'json': [],
    'html': ['html', 'head', 'body', 'div', 'span', 'p', 'a', 'img', 'ul', 'ol', 'li', 'table',
      'tr', 'td', 'th', 'form', 'input', 'button', 'script', 'style', 'link', 'meta', 'title',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br', 'hr', 'class', 'id', 'href', 'src', 'style'],
    'css': ['color', 'background', 'background-color', 'font-size', 'font-family', 'font-weight',
      'margin', 'padding', 'border', 'border-radius', 'display', 'position', 'width', 'height',
      'top', 'left', 'right', 'bottom', 'flex', 'flex-direction', 'justify-content',
      'align-items', 'overflow', 'opacity', 'z-index', 'transition', 'transform', 'cursor',
      'text-align', 'line-height', 'box-shadow', 'text-decoration', 'list-style']
  };

  static isSupported(lang: string): boolean {
    return SyntaxHighlighter.KEYWORDS[lang.trim().toLowerCase()] !== undefined;
  }

  // 高亮单行代码，返回 token 序列（含默认色）
  static highlightLine(line: string, lang: string, isDark: boolean): CodeToken[] {
    const keywords: string[] = SyntaxHighlighter.KEYWORDS[lang.trim().toLowerCase()];
    const defaultColor: string = isDark ? SyntaxHighlighter.DEFAULT_DARK : SyntaxHighlighter.DEFAULT_LIGHT;
    const tokens: CodeToken[] = [];
    let i: number = 0;
    const n: number = line.length;
    while (i < n) {
      const ch: string = line.charAt(i);
      const next: string = i + 1 < n ? line.charAt(i + 1) : '';
      // 行注释 //
      if (ch === '/' && next === '/') {
        tokens.push(new CodeToken(line.substring(i), SyntaxHighlighter.COMMENT_COLOR));
        return tokens;
      }
      // 块注释 /* */
      if (ch === '/' && next === '*') {
        let end: number = line.indexOf('*/', i + 2);
        if (end < 0) end = n;
        tokens.push(new CodeToken(line.substring(i, end + 2), SyntaxHighlighter.COMMENT_COLOR));
        i = end + 2;
        continue;
      }
      // 字符串
      if (ch === '"' || ch === "'" || ch === '`') {
        const quote: string = ch;
        let j: number = i + 1;
        while (j < n) {
          const c: string = line.charAt(j);
          if (c === '\\') {
            j = j + 2;
            continue;
          }
          if (c === quote) {
            j = j + 1;
            break;
          }
          j = j + 1;
        }
        tokens.push(new CodeToken(line.substring(i, j), SyntaxHighlighter.STRING_COLOR));
        i = j;
        continue;
      }
      // 数字
      if (SyntaxHighlighter.isDigit(ch)) {
        let j: number = i + 1;
        while (j < n && (SyntaxHighlighter.isDigit(line.charAt(j)) || line.charAt(j) === '.' ||
          line.charAt(j) === 'x' || line.charAt(j) === 'e' || line.charAt(j) === 'E' ||
          line.charAt(j) === '_' || (line.charAt(j) >= 'a' && line.charAt(j) <= 'f') ||
          (line.charAt(j) >= 'A' && line.charAt(j) <= 'F'))) {
          j = j + 1;
        }
        tokens.push(new CodeToken(line.substring(i, j), SyntaxHighlighter.NUMBER_COLOR));
        i = j;
        continue;
      }
      // 标识符
      if (SyntaxHighlighter.isIdentStart(ch)) {
        let j: number = i + 1;
        while (j < n && SyntaxHighlighter.isIdentPart(line.charAt(j))) {
          j = j + 1;
        }
        const word: string = line.substring(i, j);
        if (keywords.indexOf(word) >= 0) {
          tokens.push(new CodeToken(word, SyntaxHighlighter.KEYWORD_COLOR));
        } else {
          // 函数调用：标识符后紧跟 (
          let k: number = j;
          while (k < n && (line.charAt(k) === ' ' || line.charAt(k) === '\t')) {
            k = k + 1;
          }
          if (k < n && line.charAt(k) === '(') {
            tokens.push(new CodeToken(word, '#61AFEF'));
          } else {
            tokens.push(new CodeToken(word, defaultColor));
          }
        }
        i = j;
        continue;
      }
      // 其他字符
      tokens.push(new CodeToken(ch, defaultColor));
      i = i + 1;
    }
    return tokens;
  }

  private static isDigit(ch: string): boolean {
    return ch >= '0' && ch <= '9';
  }

  private static isIdentStart(ch: string): boolean {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch === '_' || ch === '$';
  }

  private static isIdentPart(ch: string): boolean {
    return SyntaxHighlighter.isIdentStart(ch) || SyntaxHighlighter.isDigit(ch);
  }
}

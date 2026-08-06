// 智子 - ANSI 解析器（SGR 颜色/样式 + CSI 降级）
// 流式缓冲处理 UTF-8 多字节分片；输出 AnsiSegment[] 供 Text+Span 渲染

import { AnsiSegment } from '../model/Models';

const CSI = '\x1b['; // Control Sequence Introducer
const OSC = '\x1b]'; // Operating System Command
const SGR_TERM = 'm';

// 16 色标准映射（0-7 暗色，8-15 亮色）
const FG_16: Record<number, string> = {
  30: '#1A1B26', 31: '#F7768E', 32: '#9ECE6A', 33: '#E0AF68',
  34: '#7AA2F7', 35: '#BB9AF7', 36: '#7DCFFF', 37: '#C0CAF5',
  90: '#565F89', 91: '#F7768E', 92: '#9ECE6A', 93: '#E0AF68',
  94: '#7AA2F7', 95: '#BB9AF7', 96: '#7DCFFF', 97: '#C0CAF5',
};

const BG_16: Record<number, string> = {
  40: '#1A1B26', 41: '#F7768E', 42: '#9ECE6A', 43: '#E0AF68',
  44: '#7AA2F7', 45: '#BB9AF7', 46: '#7DCFFF', 47: '#C0CAF5',
  100: '#565F89', 101: '#F7768E', 102: '#9ECE6A', 103: '#E0AF68',
  104: '#7AA2F7', 105: '#BB9AF7', 106: '#7DCFFF', 107: '#C0CAF5',
};

// 256 色调色板生成
function rgb256(code: number): string {
  if (code < 16) return FG_16[code + 30] || '#C0CAF5';
  if (code < 232) {
    const c = code - 16;
    const r = Math.floor(c / 36) * 40 + 55;
    const g = Math.floor((c % 36) / 6) * 40 + 55;
    const b = (c % 6) * 40 + 55;
    return `rgb(${r},${g},${b})`;
  }
  const gray = (code - 232) * 10 + 8;
  return `rgb(${gray},${gray},${gray})`;
}

// 当前渲染状态
interface RenderState {
  fg?: string;
  bg?: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  dim: boolean;
  reverse: boolean;
  reset(): void;
}

class RenderStateImpl implements RenderState {
  fg?: string;
  bg?: string;
  bold: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  dim: boolean = false;
  reverse: boolean = false;

  reset(): void {
    this.fg = undefined;
    this.bg = undefined;
    this.bold = false;
    this.italic = false;
    this.underline = false;
    this.dim = false;
    this.reverse = false;
  }

  clone(): RenderStateImpl {
    const s = new RenderStateImpl();
    s.fg = this.fg;
    s.bg = this.bg;
    s.bold = this.bold;
    s.italic = this.italic;
    s.underline = this.underline;
    s.dim = this.dim;
    s.reverse = this.reverse;
    return s;
  }
}

export class AnsiParser {
  private buffer: string = '';
  private state: RenderStateImpl = new RenderStateImpl();
  private segments: AnsiSegment[] = [];
  private textBuf: string = '';

  // 输入原始数据（可含任意分片），返回新产生的 AnsiSegment 数组
  feed(raw: string): AnsiSegment[] {
    this.buffer += raw;
    const result: AnsiSegment[] = [];
    let i = 0;

    while (i < this.buffer.length) {
      // 查找 ESC 序列
      const escIdx = this.buffer.indexOf('\x1b', i);
      if (escIdx === -1) {
        // 无更多转义序列，剩余全部是普通文本
        this.flushText(this.buffer.substring(i));
        i = this.buffer.length;
        break;
      }

      // 输出 ESC 之前的普通文本
      if (escIdx > i) {
        this.flushText(this.buffer.substring(i, escIdx));
      }
      i = escIdx;

      // 解析转义序列
      if (this.buffer[i] === '\x1b') {
        if (i + 1 < this.buffer.length && this.buffer[i + 1] === '[') {
          // CSI 序列：ESC [ ... m
          const endIdx = this.buffer.indexOf(SGR_TERM, i + 2);
          if (endIdx === -1) {
            // 序列不完整（分片截断），等待更多数据
            // 保留从 ESC 开始的未完成序列
            this.flushText(this.buffer.substring(i, i + 1)); // 只输出 ESC
            i++;
            continue;
          }
          const params = this.buffer.substring(i + 2, endIdx);
          this.processSGR(params);
          i = endIdx + 1;
        } else if (i + 1 < this.buffer.length && this.buffer[i + 1] === ']') {
          // OSC 序列：ESC ] ... BEL 或 ESC ] ... ESC \
          let endIdx2 = this.buffer.indexOf('\x07', i + 2);
          if (endIdx2 === -1) {
            endIdx2 = this.buffer.indexOf('\x1b\\', i + 2);
          }
          if (endIdx2 === -1) {
            // 不完整 OSC，跳过
            i = this.buffer.length;
          } else {
            i = endIdx2 + (this.buffer[endIdx2] === '\x07' ? 1 : 2);
          }
        } else {
          // 未知转义序列，输出 ESC 字符
          this.flushText(this.buffer[i]);
          i++;
        }
      }
    }

    // 清空已处理的缓冲区
    if (i >= this.buffer.length) {
      this.buffer = '';
    } else {
      this.buffer = this.buffer.substring(i);
    }

    // 返回新产生的段并清空内部累积
    const out = [...this.segments];
    this.segments = [];
    return out;
  }

  // 重置解析器状态（新连接时调用）
  reset(): void {
    this.buffer = '';
    this.state.reset();
    this.segments = [];
    this.textBuf = '';
  }

  // 输出文本缓冲区为一个段
  private flushText(text: string): void {
    if (text.length === 0) return;
    const segment: AnsiSegment = {
      text: text,
      fg: this.state.fg,
      bg: this.state.bg,
      bold: this.state.bold,
      italic: this.state.italic,
      underline: this.state.underline
    };
    this.segments.push(segment);
    this.textBuf = '';
  }

  // 处理 SGR 参数（分号分隔）
  private processSGR(params: string): void {
    if (params.length === 0 || params === '0') {
      this.flushText('');
      this.state.reset();
      return;
    }

    const codes = params.split(';').map((s: string) => parseInt(s) || 0);
    let i = 0;

    while (i < codes.length) {
      const code = codes[i];
      if (code === 0) {
        this.flushText('');
        this.state.reset();
      } else if (code === 1) {
        this.flushText('');
        this.state.bold = true;
      } else if (code === 2) {
        this.flushText('');
        this.state.dim = true;
      } else if (code === 3) {
        this.flushText('');
        this.state.italic = true;
      } else if (code === 4) {
        this.flushText('');
        this.state.underline = true;
      } else if (code === 7) {
        this.flushText('');
        this.state.reverse = true;
      } else if (code === 22) {
        this.flushText('');
        this.state.bold = false;
        this.state.dim = false;
      } else if (code === 23) {
        this.flushText('');
        this.state.italic = false;
      } else if (code === 24) {
        this.flushText('');
        this.state.underline = false;
      } else if (code === 27) {
        this.flushText('');
        this.state.reverse = false;
      } else if (code >= 30 && code <= 37) {
        this.flushText('');
        this.state.fg = FG_16[code];
      } else if (code === 38) {
        // 38;5;N 或 38;2;R;G;B
        this.flushText('');
        if (i + 2 < codes.length && codes[i + 1] === 5) {
          this.state.fg = rgb256(codes[i + 2]);
          i += 2;
        } else if (i + 4 < codes.length && codes[i + 1] === 2) {
          this.state.fg = `rgb(${codes[i + 2]},${codes[i + 3]},${codes[i + 4]})`;
          i += 4;
        }
      } else if (code === 39) {
        this.flushText('');
        this.state.fg = undefined;
      } else if (code >= 40 && code <= 47) {
        this.flushText('');
        this.state.bg = BG_16[code];
      } else if (code === 48) {
        // 48;5;N 或 48;2;R;G;B
        this.flushText('');
        if (i + 2 < codes.length && codes[i + 1] === 5) {
          this.state.bg = rgb256(codes[i + 2]);
          i += 2;
        } else if (i + 4 < codes.length && codes[i + 1] === 2) {
          this.state.bg = `rgb(${codes[i + 2]},${codes[i + 3]},${codes[i + 4]})`;
          i += 4;
        }
      } else if (code === 49) {
        this.flushText('');
        this.state.bg = undefined;
      } else if (code >= 90 && code <= 97) {
        this.flushText('');
        this.state.fg = FG_16[code];
      } else if (code >= 100 && code <= 107) {
        this.flushText('');
        this.state.bg = BG_16[code];
      }
      // 其他 SGR 代码忽略
      i++;
    }
  }
}

// 智子 - 终端行缓冲区
// 管理终端输出行：按行分割、ANSI 渲染、滚动上限、光标行管理

import { AnsiSegment } from '../model/Models';
import { AnsiParser } from './AnsiParser';

export interface TerminalLine {
  segments: AnsiSegment[];
  rawText: string;
}

export class TerminalBuffer {
  private parser: AnsiParser = new AnsiParser();
  private lines: TerminalLine[] = [];
  private currentLine: AnsiSegment[] = [];
  private maxLines: number = 5000; // 默认滚动上限
  private rawLine: string = '';
  private dirty: boolean = true;

  // 设置滚动行数上限
  setMaxLines(max: number): void {
    this.maxLines = max;
    this.trimLines();
  }

  // 输入原始数据（可含任意分片和 ANSI 转义）
  feed(raw: string): void {
    this.dirty = true;
    this.rawLine += raw;

    // 按 \n 分割
    let idx: number;
    while ((idx = this.rawLine.indexOf('\n')) !== -1) {
      const lineData = this.rawLine.substring(0, idx);
      this.rawLine = this.rawLine.substring(idx + 1);

      // 解析 ANSI
      const segments = this.parser.feed(lineData + '\n');
      this.appendLine(segments);
    }

    // 解析残留数据（可能含未完成的 ANSI 序列）
    if (this.rawLine.length > 0) {
      const segments = this.parser.feed('');
      if (segments.length > 0) {
        this.currentLine.push(...segments);
      }
    }
  }

  // 获取所有行（用于渲染）
  getLines(): TerminalLine[] {
    this.dirty = false;
    const result = [...this.lines];
    // 当前行（未完成的）
    if (this.currentLine.length > 0) {
      result.push({ segments: [...this.currentLine], rawText: '' });
    }
    return result;
  }

  // 获取纯文本（用于复制/搜索）
  getPlainText(): string {
    let text = '';
    for (const line of this.lines) {
      text += line.rawText + '\n';
    }
    return text;
  }

  // 是否变更（用于增量渲染优化）
  isDirty(): boolean {
    return this.dirty;
  }

  // 清空缓冲区
  clear(): void {
    this.lines = [];
    this.currentLine = [];
    this.rawLine = '';
    this.parser.reset();
    this.dirty = true;
  }

  // 重置（新连接时调用）
  reset(): void {
    this.clear();
  }

  // 行数
  getLineCount(): number {
    return this.lines.length + (this.currentLine.length > 0 ? 1 : 0);
  }

  private appendLine(segments: AnsiSegment[]): void {
    if (segments.length === 0) {
      // 空行
      this.lines.push({ segments: [], rawText: '' });
    } else {
      // 最后一个段可能以 \n 结尾，去掉
      const last = segments[segments.length - 1];
      let displaySegments: AnsiSegment[];
      if (last && last.text.endsWith('\n')) {
        last.text = last.text.substring(0, last.text.length - 1);
        displaySegments = segments;
      } else {
        displaySegments = segments;
      }

      const raw = displaySegments.map((s: AnsiSegment) => s.text).join('');
      this.lines.push({ segments: displaySegments, rawText: raw });
    }
    this.trimLines();
  }

  private trimLines(): void {
    while (this.lines.length > this.maxLines) {
      this.lines.shift();
    }
  }
}

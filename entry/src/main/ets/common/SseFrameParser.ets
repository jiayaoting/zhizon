// 智子 - 共享 SSE 帧解析（LlmClient 与 BettaFishSseClient 复用）
// 兼容 \r\n 与 \n 分隔；帧内按行累积 id / event / data 字段

export class SseParseResult {
  events: string[];
  consumed: number;

  constructor(events: string[], consumed: number) {
    this.events = events;
    this.consumed = consumed;
  }
}

export class SseFrame {
  id: string = '';
  event: string = '';
  data: string = '';

  constructor(id: string, event: string, data: string) {
    this.id = id;
    this.event = event;
    this.data = data;
  }
}

export class SseFrameParser {
  // 从缓冲中切出完整帧，返回剩余缓冲位置
  static parse(buffer: string): SseParseResult {
    const events: string[] = [];
    let pos: number = 0;
    while (pos < buffer.length) {
      const rnIdx: number = buffer.indexOf('\r\n\r\n', pos);
      const nIdx: number = buffer.indexOf('\n\n', pos);
      let sepIdx: number = -1;
      let sepLen: number = 0;
      if (rnIdx >= 0 && (nIdx < 0 || rnIdx <= nIdx)) {
        sepIdx = rnIdx;
        sepLen = 4;
      } else if (nIdx >= 0) {
        sepIdx = nIdx;
        sepLen = 2;
      } else {
        break;
      }
      events.push(buffer.substring(pos, sepIdx));
      pos = sepIdx + sepLen;
    }
    return new SseParseResult(events, pos);
  }

  // 单帧文本 → 结构化字段
  static frameToSse(frameText: string): SseFrame {
    const lines: string[] = frameText.split(/\r?\n/);
    let id: string = '';
    let event: string = '';
    let data: string = '';
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (line.startsWith(':')) {
        continue;   // 注释行（心跳等）
      }
      if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        const value: string = line.substring(5).trim();
        data = data.length > 0 ? data + value : value;
      }
    }
    return new SseFrame(id, event, data);
  }
}

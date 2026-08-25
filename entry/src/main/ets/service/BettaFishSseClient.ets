// 智子 - BettaFish 报告进度 SSE 客户端
// 基于 http.requestInStream + dataReceive 增量解析；断线指数退避重连（Last-Event-ID 续传）
// 连续失败超过阈值后回调 onFallback，由页面切换为轮询降级
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BettaServerConfig, BettaReportEvent } from '../common/BettaFishModels';
import { SseFrameParser, SseFrame, SseParseResult } from '../common/SseFrameParser';
import { BettaFishApiClient } from './BettaFishApiClient';

const READ_TIMEOUT = 30000;
const MAX_RETRIES = 3;

export class BettaFishSseClient {
  private httpRequest: http.HttpRequest | null = null;
  private buffer: string = '';
  private lastEventId: string = '';
  private stopped: boolean = false;
  private retryCount: number = 0;
  private server: BettaServerConfig | null = null;
  private taskId: string = '';
  private onEvent: (event: BettaReportEvent) => void = () => {};
  private onTerminal: (event: BettaReportEvent) => void = () => {};
  private onFallback: (message: string) => void = () => {};

  connect(server: BettaServerConfig, taskId: string,
    onEvent: (event: BettaReportEvent) => void,
    onTerminal: (event: BettaReportEvent) => void,
    onFallback: (message: string) => void): void {
    this.server = server;
    this.taskId = taskId;
    this.onEvent = onEvent;
    this.onTerminal = onTerminal;
    this.onFallback = onFallback;
    this.stopped = false;
    this.buffer = '';
    this.retryCount = 0;
    this.open();
  }

  stop(): void {
    this.stopped = true;
    if (this.httpRequest !== null) {
      this.httpRequest.off('dataReceive');
      this.httpRequest.destroy();
      this.httpRequest = null;
    }
  }

  private async open(): Promise<void> {
    if (this.stopped) return;
    const server = this.server;
    if (server === null) return;
    const baseUrl = BettaFishApiClient.buildBaseUrl(server);
    if (baseUrl.length === 0) {
      this.handleFailure('服务器地址无效');
      return;
    }
    const url = baseUrl + '/api/report/stream/' + this.taskId;
    const httpRequest: http.HttpRequest = http.createHttp();
    this.httpRequest = httpRequest;
    const header: Record<string, string> = {
      'Accept': 'text/event-stream',
      'Connection': 'close'
    };
    if (this.lastEventId.length > 0) {
      header['Last-Event-ID'] = this.lastEventId;
    }

    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      this.processChunk(data);
    });

    const streamDone = new Promise<boolean>((resolve: (value: boolean) => void) => {
      httpRequest.on('dataEnd', () => {
        resolve(true);
      });
      setTimeout(() => {
        resolve(true);
      }, READ_TIMEOUT + 1000);
    });

    try {
      const code: number = await httpRequest.requestInStream(url, {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: (server.timeoutSec > 0 ? server.timeoutSec : 10) * 1000,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      });
      if (this.stopped) return;
      if (code !== 200) {
        this.handleFailure('服务端返回 ' + code.toString());
        return;
      }
      await streamDone;
      if (this.stopped) return;
      // 流正常结束但未收到终态：视为断流，尝试续传重连
      this.handleDisconnect();
    } catch (e) {
      if (!this.stopped) {
        this.handleFailure('连接异常');
      }
    }
  }

  private processChunk(data: ArrayBuffer): void {
    if (this.stopped) return;
    const decoder = new util.TextDecoder('utf-8');
    const chunk: string = decoder.decodeToString(new Uint8Array(data));
    this.buffer = this.buffer + chunk;
    const parseResult: SseParseResult = SseFrameParser.parse(this.buffer);
    this.buffer = this.buffer.substring(parseResult.consumed);
    for (let i: number = 0; i < parseResult.events.length; i++) {
      this.dispatchFrame(parseResult.events[i]);
      if (this.stopped) return;
    }
  }

  private dispatchFrame(frameText: string): void {
    const frame: SseFrame = SseFrameParser.frameToSse(frameText);
    if (frame.data.length === 0) return;
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(frame.data) as Record<string, Object>;
    } catch (e) {
      return;
    }
    const event = new BettaReportEvent();
    // 服务端 data 内 id 才是真正的递增事件号（hb-... 心跳除外）
    const dataId = parsed.id;
    if (typeof dataId === 'number') {
      event.id = dataId.toString();
      this.lastEventId = event.id;
    } else if (frame.id.length > 0 && !frame.id.startsWith('hb-')) {
      event.id = frame.id;
      this.lastEventId = event.id;
    } else {
      event.id = frame.id;
    }
    event.type = frame.event.length > 0 ? frame.event : BettaFishApiClient.strField(parsed, 'type');
    event.taskId = BettaFishApiClient.strField(parsed, 'task_id');
    event.timestamp = BettaFishApiClient.strField(parsed, 'timestamp');
    const payload = parsed.payload;
    if (payload !== undefined && payload !== null) {
      event.payload = payload as Record<string, Object>;
    }
    this.onEvent(event);
    if (this.isTerminal(event)) {
      this.stopped = true;
      if (this.httpRequest !== null) {
        this.httpRequest.off('dataReceive');
        this.httpRequest.destroy();
        this.httpRequest = null;
      }
      this.onTerminal(event);
    }
  }

  private isTerminal(event: BettaReportEvent): boolean {
    if (event.type === 'completed' || event.type === 'error' || event.type === 'cancelled') {
      return true;
    }
    const payloadStatus = event.payload.status;
    if (typeof payloadStatus === 'string') {
      const s: string = payloadStatus as string;
      return s === 'completed' || s === 'error' || s === 'cancelled';
    }
    return false;
  }

  private handleDisconnect(): void {
    if (this.stopped) return;
    this.retryCount++;
    if (this.retryCount > MAX_RETRIES) {
      this.onFallback('SSE 连接多次中断，已切换为轮询');
      return;
    }
    const backoff: number = Math.min(1000 * Math.pow(2, this.retryCount - 1), 8000);
    setTimeout(() => {
      this.open();
    }, backoff);
  }

  private handleFailure(message: string): void {
    if (this.stopped) return;
    this.retryCount++;
    if (this.retryCount > MAX_RETRIES) {
      this.onFallback(message);
      return;
    }
    const backoff: number = Math.min(1000 * Math.pow(2, this.retryCount - 1), 8000);
    setTimeout(() => {
      this.open();
    }, backoff);
  }
}

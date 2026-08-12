// 智子 - 大模型客户端（OpenAI 兼容 /chat/completions + SSE 流式）
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { ChatMessage, LlmConfig, LlmResult } from '../common/LlmModels';
const REQUEST_TIMEOUT = 60000;
const TEXT_DECODER: util.TextDecoder = new util.TextDecoder();

export class LlmClient {
  // 非流式单次对话（用于测试连接）
  static async testConnection(config: LlmConfig): Promise<LlmResult> {
    if (!config.baseUrl.trim()) return new LlmResult(false, '', 'EMPTY_BASE_URL', '接口地址不能为空');
    if (!config.model.trim()) return new LlmResult(false, '', 'EMPTY_MODEL', '模型名称不能为空');
    if (!config.needsKey && !config.apiKey.trim()) {
      return new LlmResult(false, '', 'EMPTY_API_KEY', 'API Key 不能为空');
    }
    const messages: ChatMessage[] = [new ChatMessage('user', '你好，请回复"连接成功"四个字。')];
    try {
      const result = await LlmClient.postCompletion(config, messages);
      return result;
    } catch (e) {
      return LlmClient.toResult(e);
    }
  }

  // 非流式请求完整返回
  static async postCompletion(config: LlmConfig, messages: ChatMessage[]): Promise<LlmResult> {
    const httpRequest = http.createHttp();
    try {
      const url: string = LlmClient.normalizeUrl(config.baseUrl);
      const header: Record<string, string> = {
        'Content-Type': 'application/json'
      };
      if (!config.needsKey) {
        header['Authorization'] = 'Bearer ' + config.apiKey.trim();
      }
      const body = {
        model: config.model.trim(),
        messages: messages.map((m: ChatMessage): Record<string, string> => ({ role: m.role, content: m.content })),
        temperature: config.temperature,
        stream: false
      };
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const code: number = response.responseCode;
      if (code !== 200) {
        return new LlmResult(false, '', 'HTTP_' + code.toString(), LlmClient.errorMessageFromBody(response.result, code));
      }
      const text: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const content: string = LlmClient.extractContent(text);
      if (!content) return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
      return new LlmResult(true, content, '', '');
    } catch (e) {
      return LlmClient.toResult(e);
    } finally {
      httpRequest.destroy();
    }
  }

  // 流式请求：onDelta 逐片回调，返回完整内容
  static async postCompletionStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const httpRequest = http.createHttp();
    let fullContent: string = '';
    let buffer: string = '';
    try {
      const url: string = LlmClient.normalizeUrl(config.baseUrl);
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream'
      };
      if (!config.needsKey) {
        header['Authorization'] = 'Bearer ' + config.apiKey.trim();
      }
      const body = {
        model: config.model.trim(),
        messages: messages.map((m: ChatMessage): Record<string, string> => ({ role: m.role, content: m.content })),
        temperature: config.temperature,
        stream: true
      };
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        buffer = buffer + LlmClient.arrayBufferToString(data);
        const events: string[] = LlmClient.extractSseEvents(buffer);
        buffer = LlmClient.remainingBuffer(buffer, events);
        for (let i: number = 0; i < events.length; i++) {
          const delta: string = LlmClient.contentFromSseEvent(events[i]);
          if (delta.length > 0) {
            fullContent = fullContent + delta;
            onDelta(delta);
          }
        }
      });
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: REQUEST_TIMEOUT,
        readTimeout: REQUEST_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const code: number = response.responseCode;
      if (code !== 200) {
        return new LlmResult(false, '', 'HTTP_' + code.toString(), LlmClient.errorMessageFromBody(response.result, code));
      }
      // 兜底：请求完成后仍可能有残留 buffer 未解析
      if (buffer.trim().length > 0) {
        const events: string[] = LlmClient.extractSseEvents(buffer);
        for (let i: number = 0; i < events.length; i++) {
          const delta: string = LlmClient.contentFromSseEvent(events[i]);
          if (delta.length > 0) {
            fullContent = fullContent + delta;
            onDelta(delta);
          }
        }
      }
      if (!fullContent.trim()) return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
      return new LlmResult(true, fullContent, '', '');
    } catch (e) {
      return LlmClient.toResult(e);
    } finally {
      httpRequest.off('dataReceive');
      httpRequest.destroy();
    }
  }

  private static normalizeUrl(baseUrl: string): string {
    let url: string = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/chat/completions')) return url;
    if (url.endsWith('/v1')) return url + '/chat/completions';
    return url + '/chat/completions';
  }

  private static extractContent(jsonText: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const choices: Object = parsed.choices;
      if (choices !== undefined && Array.isArray(choices) && (choices as Object[]).length > 0) {
        const first: Record<string, Object> = (choices as Object[])[0] as Record<string, Object>;
        const message: Object = first.message;
        if (message !== undefined) {
          const messageObj: Record<string, Object> = message as Record<string, Object>;
          const content: Object = messageObj.content;
          if (content !== undefined) return String(content);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // 从 SSE 文本流中提取完整事件（按空行分隔），返回已消费的事件
  private static extractSseEvents(buffer: string): string[] {
    const events: string[] = [];
    let index: number = 0;
    while (true) {
      const idx: number = buffer.indexOf('\n\n', index);
      if (idx < 0) break;
      const event: string = buffer.substring(index, idx);
      events.push(event);
      index = idx + 2;
    }
    return events;
  }

  // 提取未消费的 buffer（最后一段不完整的 SSE 块）
  private static remainingBuffer(buffer: string, consumed: string[]): string {
    let consumedLen: number = 0;
    for (let i: number = 0; i < consumed.length; i++) {
      consumedLen = consumedLen + consumed[i].length + 2;
    }
    return buffer.substring(consumedLen);
  }

  // 从单个 SSE 事件提取增量内容
  private static contentFromSseEvent(event: string): string {
    const lines: string[] = event.split('\n');
    let data: string = '';
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (line.startsWith('data:')) {
        const value: string = line.substring(5).trim();
        if (data.length > 0) data = data + value;
        else data = value;
      }
    }
    if (data.length === 0 || data === '[DONE]') return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
      const choices: Object = parsed.choices;
      if (choices !== undefined && Array.isArray(choices) && (choices as Object[]).length > 0) {
        const first: Record<string, Object> = (choices as Object[])[0] as Record<string, Object>;
        const delta: Object = first.delta;
        if (delta !== undefined) {
          const deltaObj: Record<string, Object> = delta as Record<string, Object>;
          const content: Object = deltaObj.content;
          if (content !== undefined) return String(content);
        }
        const message: Object = first.message;
        if (message !== undefined) {
          const messageObj: Record<string, Object> = message as Record<string, Object>;
          const content: Object = messageObj.content;
          if (content !== undefined) return String(content);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  private static arrayBufferToString(buffer: ArrayBuffer): string {
    try {
      return TEXT_DECODER.decodeToString(new Uint8Array(buffer));
    } catch (e) {
      return '';
    }
  }

  private static errorMessageFromBody(body: Object, code: number): string {
    try {
      if (typeof body === 'string' && (body as string).length > 0) {
        const parsed: Record<string, Object> = JSON.parse(body as string) as Record<string, Object>;
        const error: Object = parsed.error;
        if (error !== undefined) {
          const errorObj: Record<string, Object> = error as Record<string, Object>;
          const message: Object = errorObj.message;
          if (message !== undefined) return String(message);
        }
      }
    } catch (e) {
    }
    if (code === 401) return 'API Key 无效或未授权，请检查配置';
    if (code === 403) return '访问被拒绝，请检查 API Key 权限';
    if (code === 404) return '接口地址或模型名称错误';
    if (code === 429) return '请求过于频繁或额度不足';
    return '服务返回错误（HTTP ' + code.toString() + '）';
  }

  private static toResult(e: Error): LlmResult {
    const message: string = e.message || '网络请求失败';
    if (message.indexOf('timeout') >= 0) return new LlmResult(false, '', 'TIMEOUT', '请求超时，请检查网络或接口地址');
    if (message.indexOf('connect') >= 0 || message.indexOf('resolve') >= 0) {
      return new LlmResult(false, '', 'NETWORK', '网络连接失败，请检查网络与接口地址');
    }
    return new LlmResult(false, '', 'REQUEST_FAILED', message);
  }
}

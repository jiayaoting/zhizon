// 智子 - 大模型客户端（OpenAI Chat Completions + Anthropic Messages + SSE 流式）
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { AnthropicRequestBody, ChatMessage, ChatRequestBody, ChatRequestMessage, LlmConfig, LlmResult } from '../common/LlmModels';
// 连接超时（网络握手）与读取超时（响应传输）分开设置：
// 流式响应/思考型模型可能长时间持续传输数据，读取超时需放宽
const CONNECT_TIMEOUT = 30000;
const READ_TIMEOUT = 300000;

export class LlmClient {
  // 非流式单次对话（用于测试连接）
  static async testConnection(config: LlmConfig): Promise<LlmResult> {
    if (!config.baseUrl.trim()) return new LlmResult(false, '', 'EMPTY_BASE_URL', '接口地址不能为空');
    if (!config.model.trim()) return new LlmResult(false, '', 'EMPTY_MODEL', '模型名称不能为空');
    if (config.needsKey && !config.apiKey.trim()) {
      return new LlmResult(false, '', 'EMPTY_API_KEY', 'API Key 不能为空');
    }
    const messages: ChatMessage[] = [ChatMessage.create('user', '你好，请回复"连接成功"四个字。')];
    try {
      const result = await LlmClient.postCompletion(config, messages);
      return result;
    } catch (e) {
      return LlmClient.toResult(e);
    }
  }

  // 非流式请求完整返回
  static async postCompletion(config: LlmConfig, messages: ChatMessage[]): Promise<LlmResult> {
    if (config.apiFormat === 'anthropic') {
      return LlmClient.postAnthropic(config, messages, false);
    }
    return LlmClient.postOpenAI(config, messages, false);
  }

  // 流式请求：onDelta 逐片回调正文，onReasoning 逐片回调思考过程，返回完整内容
  static async postCompletionStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void): Promise<LlmResult> {
    if (config.apiFormat === 'anthropic') {
      return LlmClient.postAnthropicStream(config, messages, onDelta, onReasoning);
    }
    return LlmClient.postOpenAIStream(config, messages, onDelta, onReasoning);
  }

  // ---- OpenAI Chat Completions ----

  private static async postOpenAI(config: LlmConfig, messages: ChatMessage[], stream: boolean,
    onDelta?: (delta: string) => void, onReasoning?: (reasoning: string) => void): Promise<LlmResult> {
    const httpRequest = http.createHttp();
    let fullContent: string = '';
    let fullReasoning: string = '';
    let buffer: string = '';
    let rawData: string = '';
    try {
      const url: string = LlmClient.openAIUrl(config);
      const header: Record<string, string> = {
        'Content-Type': 'application/json'
      };
      if (stream) {
        header['Accept'] = 'text/event-stream';
      }
      if (config.needsKey) {
        header['Authorization'] = 'Bearer ' + config.apiKey.trim();
      }
      const requestMessages: ChatRequestMessage[] = messages.map((m: ChatMessage): ChatRequestMessage =>
        new ChatRequestMessage(m.role, m.content));
      const body: ChatRequestBody = new ChatRequestBody(config.model.trim(), requestMessages, config.temperature, stream);

      const processData = (data: ArrayBuffer): void => {
        const chunk: string = LlmClient.arrayBufferToString(data);
        rawData = rawData + chunk;
        buffer = buffer + chunk;
        const parseResult: SseParseResult = LlmClient.extractSseEvents(buffer);
        const events: string[] = parseResult.events;
        buffer = LlmClient.remainingBuffer(buffer, parseResult);
        for (let i: number = 0; i < events.length; i++) {
          const contentDelta: string = LlmClient.openAIContentFromSse(events[i]);
          if (contentDelta.length > 0) {
            fullContent = fullContent + contentDelta;
            if (onDelta !== undefined) onDelta(contentDelta);
          }
          const reasoningDelta: string = LlmClient.openAIReasoningFromSse(events[i]);
          if (reasoningDelta.length > 0) {
            fullReasoning = fullReasoning + reasoningDelta;
            if (onReasoning !== undefined) onReasoning(reasoningDelta);
          }
        }
      };

      if (stream && onDelta !== undefined) {
        // 流式必须用 requestInStream：dataReceive 事件才会逐块触发（request 时不回调）
        httpRequest.on('dataReceive', (data: ArrayBuffer) => {
          processData(data);
        });
        const code: number = await httpRequest.requestInStream(url, {
          method: http.RequestMethod.POST,
          header: header,
          extraData: JSON.stringify(body),
          connectTimeout: CONNECT_TIMEOUT,
          readTimeout: READ_TIMEOUT,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingCache: false
        });
        if (code !== 200) {
          return new LlmResult(false, '', 'HTTP_' + code.toString(), LlmClient.errorMessageFromBody(rawData, code));
        }
        // 流结束：处理尾部未完整解析的数据
        if (buffer.trim().length > 0) {
          const tailResult: SseParseResult = LlmClient.extractSseEvents(buffer);
          const tailEvents: string[] = tailResult.events;
          for (let i: number = 0; i < tailEvents.length; i++) {
            const contentDelta: string = LlmClient.openAIContentFromSse(tailEvents[i]);
            if (contentDelta.length > 0) {
              fullContent = fullContent + contentDelta;
              if (onDelta !== undefined) onDelta(contentDelta);
            }
            const reasoningDelta: string = LlmClient.openAIReasoningFromSse(tailEvents[i]);
            if (reasoningDelta.length > 0) {
              fullReasoning = fullReasoning + reasoningDelta;
              if (onReasoning !== undefined) onReasoning(reasoningDelta);
            }
          }
        }
        if (!fullContent.trim() && !fullReasoning.trim()) {
          return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
        }
        return new LlmResult(true, fullContent, '', '', fullReasoning);
      }

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const code: number = response.responseCode;
      if (code !== 200) {
        return new LlmResult(false, '', 'HTTP_' + code.toString(), LlmClient.errorMessageFromBody(response.result, code));
      }
      const text: string = LlmClient.resultToString(response.result);
      const content: string = LlmClient.openAIContent(text);
      if (!content) return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
      const reasoning: string = LlmClient.openAIReasoning(text);
      return new LlmResult(true, content, '', '', reasoning);
    } catch (e) {
      return LlmClient.toResult(e);
    } finally {
      httpRequest.off('dataReceive');
      httpRequest.destroy();
    }
  }

  private static async postOpenAIStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void): Promise<LlmResult> {
    return LlmClient.postOpenAI(config, messages, true, onDelta, onReasoning);
  }

  // ---- Anthropic Messages ----

  private static async postAnthropic(config: LlmConfig, messages: ChatMessage[], stream: boolean,
    onDelta?: (delta: string) => void, onReasoning?: (reasoning: string) => void): Promise<LlmResult> {
    const httpRequest = http.createHttp();
    let fullContent: string = '';
    let fullReasoning: string = '';
    let buffer: string = '';
    let rawData: string = '';
    try {
      const url: string = LlmClient.anthropicUrl(config);
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01'
      };
      if (stream) {
        header['Accept'] = 'text/event-stream';
      }
      if (config.needsKey) {
        header['x-api-key'] = config.apiKey.trim();
      }
      const requestMessages: ChatRequestMessage[] = messages.map((m: ChatMessage): ChatRequestMessage =>
        new ChatRequestMessage(m.role, m.content));
      const body: AnthropicRequestBody = new AnthropicRequestBody(config.model.trim(), config.maxTokens,
        requestMessages, stream);

      const processData = (data: ArrayBuffer): void => {
        const chunk: string = LlmClient.arrayBufferToString(data);
        rawData = rawData + chunk;
        buffer = buffer + chunk;
        const parseResult: SseParseResult = LlmClient.extractSseEvents(buffer);
        const events: string[] = parseResult.events;
        buffer = LlmClient.remainingBuffer(buffer, parseResult);
        for (let i: number = 0; i < events.length; i++) {
          const contentDelta: string = LlmClient.anthropicContentFromSse(events[i]);
          if (contentDelta.length > 0) {
            fullContent = fullContent + contentDelta;
            if (onDelta !== undefined) onDelta(contentDelta);
          }
          const reasoningDelta: string = LlmClient.anthropicReasoningFromSse(events[i]);
          if (reasoningDelta.length > 0) {
            fullReasoning = fullReasoning + reasoningDelta;
            if (onReasoning !== undefined) onReasoning(reasoningDelta);
          }
        }
      };

      if (stream && onDelta !== undefined) {
        // 流式必须用 requestInStream：dataReceive 事件才会逐块触发（request 时不回调）
        httpRequest.on('dataReceive', (data: ArrayBuffer) => {
          processData(data);
        });
        const code: number = await httpRequest.requestInStream(url, {
          method: http.RequestMethod.POST,
          header: header,
          extraData: JSON.stringify(body),
          connectTimeout: CONNECT_TIMEOUT,
          readTimeout: READ_TIMEOUT,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingCache: false
        });
        if (code !== 200) {
          return new LlmResult(false, '', 'HTTP_' + code.toString(),
            LlmClient.anthropicErrorMessage(rawData, code));
        }
        // 流结束：处理尾部未完整解析的数据
        if (buffer.trim().length > 0) {
          const tailResult: SseParseResult = LlmClient.extractSseEvents(buffer);
          const tailEvents: string[] = tailResult.events;
          for (let i: number = 0; i < tailEvents.length; i++) {
            const contentDelta: string = LlmClient.anthropicContentFromSse(tailEvents[i]);
            if (contentDelta.length > 0) {
              fullContent = fullContent + contentDelta;
              if (onDelta !== undefined) onDelta(contentDelta);
            }
            const reasoningDelta: string = LlmClient.anthropicReasoningFromSse(tailEvents[i]);
            if (reasoningDelta.length > 0) {
              fullReasoning = fullReasoning + reasoningDelta;
              if (onReasoning !== undefined) onReasoning(reasoningDelta);
            }
          }
        }
        if (!fullContent.trim() && !fullReasoning.trim()) {
          return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
        }
        return new LlmResult(true, fullContent, '', '', fullReasoning);
      }

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const code: number = response.responseCode;
      if (code !== 200) {
        return new LlmResult(false, '', 'HTTP_' + code.toString(),
          LlmClient.anthropicErrorMessage(response.result, code));
      }
      const text: string = LlmClient.resultToString(response.result);
      const content: string = LlmClient.anthropicContent(text);
      if (!content) return new LlmResult(false, '', 'EMPTY_RESPONSE', '模型返回内容为空');
      const reasoning: string = LlmClient.anthropicReasoning(text);
      return new LlmResult(true, content, '', '', reasoning);
    } catch (e) {
      return LlmClient.toResult(e);
    } finally {
      httpRequest.off('dataReceive');
      httpRequest.destroy();
    }
  }

  private static async postAnthropicStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void): Promise<LlmResult> {
    return LlmClient.postAnthropic(config, messages, true, onDelta, onReasoning);
  }

  // ---- URL 规范化 ----

  private static openAIUrl(config: LlmConfig): string {
    let url: string = config.baseUrl.trim();
    if (config.useFullUrl) {
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      return url;
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/chat/completions')) return url;
    if (url.endsWith('/v1')) return url + '/chat/completions';
    return url + '/chat/completions';
  }

  private static anthropicUrl(config: LlmConfig): string {
    let url: string = config.baseUrl.trim();
    if (config.useFullUrl) {
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      return url;
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/v1/messages')) return url;
    if (url.endsWith('/messages')) return url;
    return url + '/v1/messages';
  }

  // ---- OpenAI 响应解析 ----

  // 非流式正文提取
  private static openAIContent(jsonText: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const choices: Object = parsed.choices;
      if (choices !== undefined && Array.isArray(choices) && (choices as Object[]).length > 0) {
        const first: Record<string, Object> = (choices as Object[])[0] as Record<string, Object>;
        const message: Object = first.message;
        if (message !== undefined) {
          const messageObj: Record<string, Object> = message as Record<string, Object>;
          const content: Object = messageObj.content;
          if (content !== undefined && content !== null && String(content).length > 0) return String(content);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // 非流式思考提取（reasoning_content / reasoning）
  private static openAIReasoning(jsonText: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const choices: Object = parsed.choices;
      if (choices !== undefined && Array.isArray(choices) && (choices as Object[]).length > 0) {
        const first: Record<string, Object> = (choices as Object[])[0] as Record<string, Object>;
        const message: Object = first.message;
        if (message !== undefined) {
          const messageObj: Record<string, Object> = message as Record<string, Object>;
          const reasoningContent: Object = messageObj.reasoning_content;
          if (reasoningContent !== undefined && reasoningContent !== null && String(reasoningContent).length > 0) {
            return String(reasoningContent);
          }
          const reasoning: Object = messageObj.reasoning;
          if (reasoning !== undefined && reasoning !== null && String(reasoning).length > 0) return String(reasoning);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ---- Anthropic 响应解析 ----

  // 非流式正文提取（text block）
  private static anthropicContent(jsonText: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const content: Object = parsed.content;
      if (content !== undefined && Array.isArray(content)) {
        const blocks: Object[] = content as Object[];
        let text: string = '';
        for (let i: number = 0; i < blocks.length; i++) {
          const block: Record<string, Object> = blocks[i] as Record<string, Object>;
          if (block.type === 'text' && block.text !== undefined) {
            text = text + String(block.text);
          }
        }
        return text;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // 非流式思考提取（thinking block）
  private static anthropicReasoning(jsonText: string): string {
    try {
      const parsed: Record<string, Object> = JSON.parse(jsonText) as Record<string, Object>;
      const content: Object = parsed.content;
      if (content !== undefined && Array.isArray(content)) {
        const blocks: Object[] = content as Object[];
        let text: string = '';
        for (let i: number = 0; i < blocks.length; i++) {
          const block: Record<string, Object> = blocks[i] as Record<string, Object>;
          if (block.type === 'thinking' && block.thinking !== undefined) {
            text = text + String(block.thinking);
          }
        }
        return text;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ---- SSE 通用解析 ----

  private static extractSseEvents(buffer: string): SseParseResult {
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

  private static remainingBuffer(buffer: string, parseResult: SseParseResult): string {
    return buffer.substring(parseResult.consumed);
  }

  // 提取 SSE 事件的 data 字段内容
  private static sseDataFromEvent(event: string): string {
    const lines: string[] = event.split(/\r?\n/);
    let data: string = '';
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (line.startsWith('data:')) {
        const value: string = line.substring(5).trim();
        if (data.length > 0) data = data + value;
        else data = value;
      }
    }
    return data;
  }

  // ---- OpenAI SSE 增量提取 ----

  // 流式正文增量：仅取 delta.content / message.content
  private static openAIContentFromSse(event: string): string {
    const data: string = LlmClient.sseDataFromEvent(event);
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
          if (content !== undefined && content !== null && String(content).length > 0) return String(content);
        }
        const message: Object = first.message;
        if (message !== undefined) {
          const messageObj: Record<string, Object> = message as Record<string, Object>;
          const content: Object = messageObj.content;
          if (content !== undefined && content !== null && String(content).length > 0) return String(content);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // 流式思考增量：仅取 delta.reasoning_content / delta.reasoning / delta.thinking
  private static openAIReasoningFromSse(event: string): string {
    const data: string = LlmClient.sseDataFromEvent(event);
    if (data.length === 0 || data === '[DONE]') return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
      const choices: Object = parsed.choices;
      if (choices !== undefined && Array.isArray(choices) && (choices as Object[]).length > 0) {
        const first: Record<string, Object> = (choices as Object[])[0] as Record<string, Object>;
        const delta: Object = first.delta;
        if (delta !== undefined) {
          const deltaObj: Record<string, Object> = delta as Record<string, Object>;
          const reasoningContent: Object = deltaObj.reasoning_content;
          if (reasoningContent !== undefined && reasoningContent !== null && String(reasoningContent).length > 0) {
            return String(reasoningContent);
          }
          const reasoning: Object = deltaObj.reasoning;
          if (reasoning !== undefined && reasoning !== null && String(reasoning).length > 0) return String(reasoning);
          const thinking: Object = deltaObj.thinking;
          if (thinking !== undefined && thinking !== null && String(thinking).length > 0) return String(thinking);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ---- Anthropic SSE 增量提取 ----

  // 流式正文增量：text_delta
  private static anthropicContentFromSse(event: string): string {
    const data: string = LlmClient.sseDataFromEvent(event);
    if (data.length === 0) return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
      const eventType: string = typeof parsed.type === 'string' ? parsed.type : '';
      if (eventType === 'content_block_delta') {
        const delta: Object = parsed.delta;
        if (delta !== undefined) {
          const deltaObj: Record<string, Object> = delta as Record<string, Object>;
          if (deltaObj.type === 'text_delta') {
            const text: Object = deltaObj.text;
            if (text !== undefined) return String(text);
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // 流式思考增量：thinking_delta
  private static anthropicReasoningFromSse(event: string): string {
    const data: string = LlmClient.sseDataFromEvent(event);
    if (data.length === 0) return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
      const eventType: string = typeof parsed.type === 'string' ? parsed.type : '';
      if (eventType === 'content_block_delta') {
        const delta: Object = parsed.delta;
        if (delta !== undefined) {
          const deltaObj: Record<string, Object> = delta as Record<string, Object>;
          if (deltaObj.type === 'thinking_delta') {
            // extended thinking：思考内容增量
            const thinking: Object = deltaObj.thinking;
            if (thinking !== undefined) return String(thinking);
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ---- 工具方法 ----

  private static arrayBufferToString(buffer: ArrayBuffer): string {
    try {
      const decoder: util.TextDecoder = new util.TextDecoder();
      return decoder.decodeToString(new Uint8Array(buffer));
    } catch (e) {
      return '';
    }
  }

  // response.result 可能是 string、ArrayBuffer 或对象，统一转字符串
  private static resultToString(result: Object): string {
    if (typeof result === 'string') return result as string;
    if (result instanceof ArrayBuffer) {
      return LlmClient.arrayBufferToString(result as ArrayBuffer);
    }
    try {
      return JSON.stringify(result);
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

  private static anthropicErrorMessage(body: Object, code: number): string {
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
    if (code === 401) return 'API Key 无效或未授权，请检查 x-api-key';
    if (code === 403) return '访问被拒绝，请检查 API Key 权限';
    if (code === 404) return '接口地址或模型名称错误';
    if (code === 429) return '请求过于频繁或额度不足';
    return '服务返回错误（HTTP ' + code.toString() + '）';
  }

  private static toResult(e: Object): LlmResult {
    const err: BusinessError = e as BusinessError;
    const message: string = (err && typeof err.message === 'string' && err.message.length > 0)
      ? err.message : '网络请求失败';
    if (message.indexOf('timeout') >= 0) return new LlmResult(false, '', 'TIMEOUT', '请求超时，请检查网络或接口地址');
    if (message.indexOf('connect') >= 0 || message.indexOf('resolve') >= 0) {
      return new LlmResult(false, '', 'NETWORK', '网络连接失败，请检查网络与接口地址');
    }
    return new LlmResult(false, '', 'REQUEST_FAILED', message);
  }
}

// SSE 解析结果：包含已切分的事件和已消费的字符数
class SseParseResult {
  events: string[];
  consumed: number;

  constructor(events: string[], consumed: number) {
    this.events = events;
    this.consumed = consumed;
  }
}
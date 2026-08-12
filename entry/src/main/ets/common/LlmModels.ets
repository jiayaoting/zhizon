// 智子 - 大模型服务商模板（OpenAI 兼容协议）
export class LlmProviderTemplate {
  id: string;
  name: string;
  baseUrl: string;
  defaultModel: string;
  models: string[];
  isLocal: boolean;

  constructor(id: string, name: string, baseUrl: string, defaultModel: string, models: string[], isLocal: boolean = false) {
    this.id = id;
    this.name = name;
    this.baseUrl = baseUrl;
    this.defaultModel = defaultModel;
    this.models = models;
    this.isLocal = isLocal;
  }
}

export const LLM_PROVIDER_TEMPLATES: LlmProviderTemplate[] = [
  new LlmProviderTemplate('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini',
    ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1']),
  new LlmProviderTemplate('deepseek', 'DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat',
    ['deepseek-chat', 'deepseek-reasoner']),
  new LlmProviderTemplate('qwen', '通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus',
    ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen-long']),
  new LlmProviderTemplate('kimi', 'Kimi（月之暗面）', 'https://api.moonshot.cn/v1', 'moonshot-v1-8k',
    ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k']),
  new LlmProviderTemplate('zhipu', '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash',
    ['glm-4-flash', 'glm-4-plus', 'glm-4-air']),
  new LlmProviderTemplate('ollama', 'Ollama（本地）', 'http://127.0.0.1:11434/v1', 'llama3.2',
    [], true)
];

export function providerTemplateById(id: string): LlmProviderTemplate | null {
  for (let i: number = 0; i < LLM_PROVIDER_TEMPLATES.length; i++) {
    if (LLM_PROVIDER_TEMPLATES[i].id === id) return LLM_PROVIDER_TEMPLATES[i];
  }
  return null;
}

// 配置模型
export class LlmConfig {
  providerId: string = '';
  baseUrl: string = '';
  apiKey: string = '';
  model: string = '';
  temperature: number = 0.7;

  get configured(): boolean {
    return this.baseUrl.trim().length > 0 && this.model.trim().length > 0;
  }

  get needsKey(): boolean {
    return this.baseUrl.indexOf('127.0.0.1') >= 0 || this.baseUrl.indexOf('localhost') >= 0;
  }
}

// 对话消息
export class ChatMessage {
  role: string;
  content: string;
  time: number;

  constructor(role: string, content: string, time: number = Date.now()) {
    this.role = role;
    this.content = content;
    this.time = time;
  }
}

// 请求结果
export class LlmResult {
  success: boolean;
  content: string;
  errorCode: string;
  errorMessage: string;

  constructor(success: boolean, content: string, errorCode: string = '', errorMessage: string = '') {
    this.success = success;
    this.content = content;
    this.errorCode = errorCode;
    this.errorMessage = errorMessage;
  }
}

// OpenAI 兼容请求消息（/chat/completions messages 项）
export class ChatRequestMessage {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

// OpenAI 兼容请求体（/chat/completions）
export class ChatRequestBody {
  model: string;
  messages: ChatRequestMessage[];
  temperature: number;
  stream: boolean;

  constructor(model: string, messages: ChatRequestMessage[], temperature: number, stream: boolean) {
    this.model = model;
    this.messages = messages;
    this.temperature = temperature;
    this.stream = stream;
  }
}

// 配置持久化结构（不含 API Key，Key 单独加密存储）
export class StoredLlmConfig {
  providerId: string;
  baseUrl: string;
  model: string;
  temperature: number;

  constructor(providerId: string, baseUrl: string, model: string, temperature: number) {
    this.providerId = providerId;
    this.baseUrl = baseUrl;
    this.model = model;
    this.temperature = temperature;
  }
}

// 聊天历史持久化结构
export class StoredChatMessage {
  role: string;
  content: string;
  time: number;

  constructor(role: string, content: string, time: number) {
    this.role = role;
    this.content = content;
    this.time = time;
  }
}

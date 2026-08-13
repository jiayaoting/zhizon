// API 格式类型
export type ApiFormat = 'openai' | 'anthropic';

// 智子 - 大模型服务商模板
export class LlmProviderTemplate {
  id: string;
  name: string;
  baseUrl: string;
  defaultModel: string;
  models: string[];
  isLocal: boolean;
  apiFormat: ApiFormat;

  constructor(id: string, name: string, baseUrl: string, defaultModel: string, models: string[],
    apiFormat: ApiFormat = 'openai', isLocal: boolean = false) {
    this.id = id;
    this.name = name;
    this.baseUrl = baseUrl;
    this.defaultModel = defaultModel;
    this.models = models;
    this.apiFormat = apiFormat;
    this.isLocal = isLocal;
  }
}

export const API_FORMAT_LABELS: Record<string, string> = {
  'openai': 'OpenAI Chat Completions',
  'anthropic': 'Anthropic Messages'
};

export const LLM_PROVIDER_TEMPLATES: LlmProviderTemplate[] = [
  new LlmProviderTemplate('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-5.6-terra',
    ['gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.5', 'gpt-5.4-mini', 'gpt-4.1', 'gpt-4.1-mini']),
  new LlmProviderTemplate('anthropic', 'Anthropic', 'https://api.anthropic.com', 'claude-sonnet-4-6',
    ['claude-opus-5', 'claude-opus-4-7', 'claude-sonnet-4-6', 'claude-sonnet-4-5', 'claude-haiku-4-5'],
    'anthropic'),
  new LlmProviderTemplate('deepseek', 'DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-v4-flash',
    ['deepseek-v4-pro', 'deepseek-v4-flash']),
  new LlmProviderTemplate('qwen', '通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus',
    ['qwen3.8-max', 'qwen3.7-max', 'qwen3.7-plus', 'qwen3-max', 'qwen-plus', 'qwen-turbo', 'qwen-flash',
      'qwen-long']),
  new LlmProviderTemplate('kimi', 'Kimi（月之暗面）', 'https://api.moonshot.cn/v1', 'kimi-k3',
    ['kimi-k3', 'kimi-k2.6', 'kimi-k2.7-code', 'kimi-k2.7-code-highspeed']),
  new LlmProviderTemplate('zhipu', '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4.7-flash',
    ['glm-5.2', 'glm-5.1', 'glm-5', 'glm-4.7', 'glm-4.7-flash', 'glm-4.6', 'glm-4.5']),
  new LlmProviderTemplate('ollama', 'Ollama（本地）', 'http://127.0.0.1:11434/v1', 'qwen3',
    [], 'openai', true),
  new LlmProviderTemplate('custom', '自定义', '', '', [], 'openai')
];

export function providerTemplateById(id: string): LlmProviderTemplate | null {
  for (let i: number = 0; i < LLM_PROVIDER_TEMPLATES.length; i++) {
    if (LLM_PROVIDER_TEMPLATES[i].id === id) return LLM_PROVIDER_TEMPLATES[i];
  }
  return null;
}

// 配置模型
export class LlmConfig {
  id: string = '';
  displayName: string = '';
  providerId: string = '';
  baseUrl: string = '';
  apiKey: string = '';
  model: string = '';
  temperature: number = 0.7;
  apiFormat: ApiFormat = 'openai';
  maxTokens: number = 4096;
  // 自定义模型高级配置
  useFullUrl: boolean = false;
  modelFamily: string = '';
  contextTokensIn: number = 128000;
  contextTokensOut: number = 4096;
  workers: number = 1;
  visionEnabled: boolean = false;
  thinkingEnabled: boolean = false;
  followDefaultConfig: boolean = true;

  get configured(): boolean {
    return this.baseUrl.trim().length > 0 && this.model.trim().length > 0;
  }

  get needsKey(): boolean {
    if (this.baseUrl.indexOf('127.0.0.1') >= 0 || this.baseUrl.indexOf('localhost') >= 0) return false;
    return true;
  }
}

// 单个模型条目（配置页管理多个模型时使用，含 API Key）
export class LlmModelEntry {
  id: string = '';
  displayName: string = '';
  providerId: string = '';
  baseUrl: string = '';
  apiKey: string = '';
  model: string = '';
  temperature: number = 0.7;
  apiFormat: ApiFormat = 'openai';
  maxTokens: number = 4096;
  // 自定义模型高级配置
  useFullUrl: boolean = false;
  modelFamily: string = '';
  contextTokensIn: number = 128000;
  contextTokensOut: number = 4096;
  workers: number = 1;
  visionEnabled: boolean = false;
  thinkingEnabled: boolean = false;
  followDefaultConfig: boolean = true;

  get configured(): boolean {
    return this.baseUrl.trim().length > 0 && this.model.trim().length > 0;
  }

  get needsKey(): boolean {
    if (this.baseUrl.indexOf('127.0.0.1') >= 0 || this.baseUrl.indexOf('localhost') >= 0) return false;
    return true;
  }
}

// 模型条目转请求配置
export function entryToConfig(entry: LlmModelEntry): LlmConfig {
  const config = new LlmConfig();
  config.id = entry.id;
  config.displayName = entry.displayName;
  config.providerId = entry.providerId;
  config.baseUrl = entry.baseUrl;
  config.apiKey = entry.apiKey;
  config.model = entry.model;
  config.temperature = entry.temperature;
  config.apiFormat = entry.apiFormat;
  config.maxTokens = entry.maxTokens;
  config.useFullUrl = entry.useFullUrl;
  config.modelFamily = entry.modelFamily;
  config.contextTokensIn = entry.contextTokensIn;
  config.contextTokensOut = entry.contextTokensOut;
  config.workers = entry.workers;
  config.visionEnabled = entry.visionEnabled;
  config.thinkingEnabled = entry.thinkingEnabled;
  config.followDefaultConfig = entry.followDefaultConfig;
  return config;
}

// 模型显示名称：优先使用用户自定义名称，否则用服务商 + 模型名
export function modelDisplayName(entry: LlmModelEntry): string {
  if (entry.displayName.trim().length > 0) return entry.displayName.trim();
  const template = providerTemplateById(entry.providerId);
  const providerName: string = template !== null ? template.name : '自定义';
  if (entry.model.trim().length > 0) return providerName + ' · ' + entry.model.trim();
  return providerName;
}

// 模型显示名称（LlmConfig 版本，ArkTS 不支持结构类型转换）
export function modelDisplayNameFromConfig(config: LlmConfig): string {
  if (config.displayName.trim().length > 0) return config.displayName.trim();
  const template = providerTemplateById(config.providerId);
  const providerName: string = template !== null ? template.name : '自定义';
  if (config.model.trim().length > 0) return providerName + ' · ' + config.model.trim();
  return providerName;
}

// 对话消息（@Observed 用于流式增量更新，仅修改 content 即可触发 UI 刷新，无需重建整个数组）
@Observed
export class ChatMessage {
  id: string;
  role: string; // user / assistant / system
  content: string;
  reasoning: string; // 思考过程（thinking/reasoning），与正文分离展示
  time: number;

  constructor(id: string, role: string, content: string, time: number = Date.now(),
    reasoning: string = '') {
    this.id = id;
    this.role = role;
    this.content = content;
    this.time = time;
    this.reasoning = reasoning;
  }

  // 便捷工厂方法：自动生成 id
  static create(role: string, content: string, time: number = Date.now(),
    reasoning: string = ''): ChatMessage {
    return new ChatMessage(ChatMessage.newId(), role, content, time, reasoning);
  }

  // 生成唯一消息 id：时间戳 + 随机串
  static newId(): string {
    const ts: string = Date.now().toString(36);
    const rand: string = Math.random().toString(36).substring(2, 8);
    return 'msg-' + ts + '-' + rand;
  }
}

// 请求结果
export class LlmResult {
  success: boolean;
  content: string;
  errorCode: string;
  errorMessage: string;
  reasoning: string; // 思考过程，成功时可能非空

  constructor(success: boolean, content: string, errorCode: string = '', errorMessage: string = '',
    reasoning: string = '') {
    this.success = success;
    this.content = content;
    this.errorCode = errorCode;
    this.errorMessage = errorMessage;
    this.reasoning = reasoning;
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

// Anthropic Messages 请求体
export class AnthropicRequestBody {
  model: string;
  max_tokens: number;
  messages: ChatRequestMessage[];
  stream: boolean;

  constructor(model: string, maxTokens: number, messages: ChatRequestMessage[], stream: boolean) {
    this.model = model;
    this.max_tokens = maxTokens;
    this.messages = messages;
    this.stream = stream;
  }
}

// 配置持久化结构（不含 API Key，Key 单独加密存储）
export class StoredLlmConfig {
  id: string;
  displayName: string;
  providerId: string;
  baseUrl: string;
  model: string;
  temperature: number;
  apiFormat: string;
  maxTokens: number;
  useFullUrl: boolean;
  modelFamily: string;
  contextTokensIn: number;
  contextTokensOut: number;
  workers: number;
  visionEnabled: boolean;
  thinkingEnabled: boolean;
  followDefaultConfig: boolean;

  constructor(id: string, displayName: string, providerId: string, baseUrl: string, model: string,
    temperature: number, apiFormat: string = 'openai', maxTokens: number = 4096,
    useFullUrl: boolean = false, modelFamily: string = '', contextTokensIn: number = 128000,
    contextTokensOut: number = 4096, workers: number = 1, visionEnabled: boolean = false,
    thinkingEnabled: boolean = false, followDefaultConfig: boolean = true) {
    this.id = id;
    this.displayName = displayName;
    this.providerId = providerId;
    this.baseUrl = baseUrl;
    this.model = model;
    this.temperature = temperature;
    this.apiFormat = apiFormat;
    this.maxTokens = maxTokens;
    this.useFullUrl = useFullUrl;
    this.modelFamily = modelFamily;
    this.contextTokensIn = contextTokensIn;
    this.contextTokensOut = contextTokensOut;
    this.workers = workers;
    this.visionEnabled = visionEnabled;
    this.thinkingEnabled = thinkingEnabled;
    this.followDefaultConfig = followDefaultConfig;
  }
}

// 聊天历史持久化结构
export class StoredChatMessage {
  id: string;
  role: string;
  content: string;
  time: number;
  reasoning: string;

  constructor(id: string, role: string, content: string, time: number, reasoning: string = '') {
    this.id = id;
    this.role = role;
    this.content = content;
    this.time = time;
    this.reasoning = reasoning;
  }
}

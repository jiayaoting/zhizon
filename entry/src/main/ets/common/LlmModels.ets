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
  new LlmProviderTemplate('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini',
    ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1']),
  new LlmProviderTemplate('anthropic', 'Anthropic', 'https://api.anthropic.com', 'claude-sonnet-4-20250514',
    ['claude-sonnet-4-20250514', 'claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229'], 'anthropic'),
  new LlmProviderTemplate('deepseek', 'DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat',
    ['deepseek-chat', 'deepseek-reasoner']),
  new LlmProviderTemplate('qwen', '通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus',
    ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen-long']),
  new LlmProviderTemplate('kimi', 'Kimi（月之暗面）', 'https://api.moonshot.cn/v1', 'moonshot-v1-8k',
    ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k']),
  new LlmProviderTemplate('zhipu', '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash',
    ['glm-4-flash', 'glm-4-plus', 'glm-4-air']),
  new LlmProviderTemplate('ollama', 'Ollama（本地）', 'http://127.0.0.1:11434/v1', 'llama3.2',
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

  constructor(id: string, displayName: string, providerId: string, baseUrl: string, model: string,
    temperature: number, apiFormat: string = 'openai', maxTokens: number = 4096) {
    this.id = id;
    this.displayName = displayName;
    this.providerId = providerId;
    this.baseUrl = baseUrl;
    this.model = model;
    this.temperature = temperature;
    this.apiFormat = apiFormat;
    this.maxTokens = maxTokens;
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

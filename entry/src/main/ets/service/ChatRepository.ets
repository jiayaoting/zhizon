// 智子 - AI 对话仓库（多模型配置 + API Key 加密存取 + 会话历史持久化）
import { DataRepository } from './DataRepository';
import { CryptoHelper } from '../common/CryptoHelper';
import { ApiFormat, ChatMessage, LlmConfig, LlmModelEntry, StoredChatMessage, StoredLlmConfig,
  entryToConfig } from '../common/LlmModels';

const KEY_MODELS = 'llmModels';
const KEY_MODEL_KEYS = 'llmModelKeys';
const KEY_ACTIVE_MODEL = 'llmActiveModelId';
const KEY_HISTORY = 'llmChatHistory';
// 旧版单配置键（迁移用）
const KEY_LEGACY_CONFIG = 'llmConfig';
const KEY_LEGACY_API_KEY = 'llmApiKey';

export class ChatRepository {
  // ---- 模型列表 ----

  // 加载全部模型（自动解密各自 API Key）
  static async loadModels(): Promise<LlmModelEntry[]> {
    try {
      const raw: string = await DataRepository.getSetting(KEY_MODELS, '');
      if (raw.length === 0) {
        // 首次升级：尝试迁移旧版单配置
        await ChatRepository.migrateLegacyConfig();
        const migrated: string = await DataRepository.getSetting(KEY_MODELS, '');
        if (migrated.length === 0) return [];
        return await ChatRepository.parseModels(migrated);
      }
      return await ChatRepository.parseModels(raw);
    } catch (e) {
      return [];
    }
  }

  // 保存全部模型（API Key 各自加密存储）
  static async saveModels(models: LlmModelEntry[]): Promise<void> {
    const stored: StoredLlmConfig[] = [];
    const keys: Record<string, string> = {};
    for (let i: number = 0; i < models.length; i++) {
      const m: LlmModelEntry = models[i];
      stored.push(new StoredLlmConfig(m.id, m.displayName, m.providerId, m.baseUrl, m.model,
        m.temperature, m.apiFormat, m.maxTokens, m.useFullUrl, m.modelFamily, m.contextTokensIn,
        m.contextTokensOut, m.workers, m.visionEnabled, m.thinkingEnabled, m.followDefaultConfig,
        m.enabled));
      if (m.apiKey.trim().length > 0) {
        keys[m.id] = await CryptoHelper.encrypt(m.apiKey.trim());
      } else {
        keys[m.id] = '';
      }
    }
    await DataRepository.setSetting(KEY_MODELS, JSON.stringify(stored));
    await DataRepository.setSetting(KEY_MODEL_KEYS, JSON.stringify(keys));
    // 迁移完成后清理旧键，避免重复迁移
    await DataRepository.setSetting(KEY_LEGACY_CONFIG, '');
    await DataRepository.setSetting(KEY_LEGACY_API_KEY, '');
  }

  // 生成新模型 id
  static newModelId(): string {
    return 'm' + Date.now().toString();
  }

  // ---- 当前激活模型 ----

  static async loadActiveModelId(): Promise<string> {
    try {
      return await DataRepository.getSetting(KEY_ACTIVE_MODEL, '');
    } catch (e) {
      return '';
    }
  }

  static async setActiveModelId(id: string): Promise<void> {
    await DataRepository.setSetting(KEY_ACTIVE_MODEL, id);
  }

  // 加载当前激活模型的完整配置；无启用配置返回 null
  static async loadActiveConfig(): Promise<LlmConfig | null> {
    const models: LlmModelEntry[] = await ChatRepository.loadModels();
    if (models.length === 0) return null;
    const activeId: string = await ChatRepository.loadActiveModelId();
    for (let i: number = 0; i < models.length; i++) {
      if (models[i].id === activeId && models[i].enabled) return entryToConfig(models[i]);
    }
    // 激活模型被禁用或缺失时，回退到第一个启用的模型
    for (let i: number = 0; i < models.length; i++) {
      if (models[i].enabled) return entryToConfig(models[i]);
    }
    return null;
  }

  // ---- 内部 ----

  private static async parseModels(raw: string): Promise<LlmModelEntry[]> {
    const parsed: Array<Record<string, Object>> = JSON.parse(raw) as Array<Record<string, Object>>;
    const keysRaw: string = await DataRepository.getSetting(KEY_MODEL_KEYS, '');
    const keys: Record<string, string> = keysRaw.length > 0 ? JSON.parse(keysRaw) as Record<string, string> : {};
    const models: LlmModelEntry[] = [];
    for (let i: number = 0; i < parsed.length; i++) {
      const item: Record<string, Object> = parsed[i];
      const entry = new LlmModelEntry();
      entry.id = typeof item.id === 'string' ? item.id : '';
      entry.displayName = typeof item.displayName === 'string' ? item.displayName : '';
      entry.providerId = typeof item.providerId === 'string' ? item.providerId : '';
      entry.baseUrl = typeof item.baseUrl === 'string' ? item.baseUrl : '';
      entry.model = typeof item.model === 'string' ? item.model : '';
      if (typeof item.temperature === 'number') entry.temperature = item.temperature as number;
      if (typeof item.apiFormat === 'string') entry.apiFormat = item.apiFormat as ApiFormat;
      if (typeof item.maxTokens === 'number') entry.maxTokens = item.maxTokens as number;
      if (typeof item.useFullUrl === 'boolean') entry.useFullUrl = item.useFullUrl as boolean;
      if (typeof item.modelFamily === 'string') entry.modelFamily = item.modelFamily as string;
      if (typeof item.contextTokensIn === 'number') entry.contextTokensIn = item.contextTokensIn as number;
      if (typeof item.contextTokensOut === 'number') entry.contextTokensOut = item.contextTokensOut as number;
      if (typeof item.workers === 'number') entry.workers = item.workers as number;
      if (typeof item.visionEnabled === 'boolean') entry.visionEnabled = item.visionEnabled as boolean;
      if (typeof item.thinkingEnabled === 'boolean') entry.thinkingEnabled = item.thinkingEnabled as boolean;
      if (typeof item.followDefaultConfig === 'boolean') entry.followDefaultConfig = item.followDefaultConfig as boolean;
      if (typeof item.enabled === 'boolean') entry.enabled = item.enabled as boolean;
      const enc: string = keys[entry.id];
      if (enc !== undefined && enc.length > 0) {
        try {
          entry.apiKey = await CryptoHelper.decrypt(enc);
        } catch (e) {
          entry.apiKey = '';
        }
      }
      if (entry.id.length > 0) models.push(entry);
    }
    return models;
  }

  // 旧版单配置 → 多模型格式迁移
  private static async migrateLegacyConfig(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting(KEY_LEGACY_CONFIG, '');
      if (raw.length === 0) return;
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const entry = new LlmModelEntry();
      entry.id = ChatRepository.newModelId();
      entry.providerId = typeof parsed.providerId === 'string' ? parsed.providerId : '';
      entry.baseUrl = typeof parsed.baseUrl === 'string' ? parsed.baseUrl : '';
      entry.model = typeof parsed.model === 'string' ? parsed.model : '';
      if (typeof parsed.temperature === 'number') entry.temperature = parsed.temperature as number;
      if (typeof parsed.apiFormat === 'string') entry.apiFormat = parsed.apiFormat as ApiFormat;
      if (typeof parsed.maxTokens === 'number') entry.maxTokens = parsed.maxTokens as number;
      const token: string = await DataRepository.getSetting(KEY_LEGACY_API_KEY, '');
      if (token.length > 0) {
        try {
          entry.apiKey = await CryptoHelper.decrypt(token);
        } catch (e) {
          entry.apiKey = '';
        }
      }
      await ChatRepository.saveModels([entry]);
      await ChatRepository.setActiveModelId(entry.id);
    } catch (e) {
    }
  }

  // ---- 会话历史 ----

  static async loadHistory(): Promise<ChatMessage[]> {
    try {
      const raw: string = await DataRepository.getSetting(KEY_HISTORY, '');
      if (raw.length === 0) return [];
      const parsed: Array<Record<string, Object>> = JSON.parse(raw) as Array<Record<string, Object>>;
      const messages: ChatMessage[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        const item: Record<string, Object> = parsed[i];
        const role: string = typeof item.role === 'string' ? item.role : '';
        const content: string = typeof item.content === 'string' ? item.content : '';
        const time: number = typeof item.time === 'number' ? item.time as number : 0;
        const reasoning: string = typeof item.reasoning === 'string' ? item.reasoning as string : '';
        if (role.length > 0 && content.length > 0) {
          // 兼容旧数据：无 id 时自动补全
          const id: string = typeof item.id === 'string' && (item.id as string).length > 0
            ? item.id as string : ChatMessage.newId();
          messages.push(new ChatMessage(id, role, content, time, reasoning));
        }
      }
      return messages;
    } catch (e) {
      return [];
    }
  }

  static async saveHistory(messages: ChatMessage[]): Promise<void> {
    try {
      // 限制最多保留最近 200 条，超出时截断最旧的消息
      const MAX_HISTORY = 200;
      const trimmed: ChatMessage[] = messages.length > MAX_HISTORY
        ? messages.slice(messages.length - MAX_HISTORY) : messages;
      const storedMessages: StoredChatMessage[] = trimmed.map((m: ChatMessage) =>
        new StoredChatMessage(m.id, m.role, m.content, m.time, m.reasoning));
      const payload: string = JSON.stringify(storedMessages);
      await DataRepository.setSetting(KEY_HISTORY, payload);
    } catch (e) {
    }
  }

  static async clearHistory(): Promise<void> {
    await DataRepository.setSetting(KEY_HISTORY, '');
  }

  // 按 id 删除指定消息，并持久化剩余记录
  static async deleteMessages(ids: string[]): Promise<ChatMessage[]> {
    const history: ChatMessage[] = await ChatRepository.loadHistory();
    const remaining: ChatMessage[] = history.filter((m: ChatMessage): boolean =>
      ids.indexOf(m.id) < 0);
    await ChatRepository.saveHistory(remaining);
    return remaining;
  }

  // 转换为请求上下文：
  // - 跳过 system role（应通过专门的 systemPrompt 参数注入，此处仅保留 user/assistant）
  // - 按字符数估算 token（总字符数 / 4），从最新向前累加直到接近 maxTokens 的 80%
  // - 默认使用模型配置的 contextTokensIn 作为上下文窗口，可由调用方覆盖
  static requestMessages(history: ChatMessage[], maxContextTokens: number = 128000): ChatMessage[] {
    const conversation: ChatMessage[] = history.filter((m: ChatMessage): boolean =>
      m.role === 'user' || m.role === 'assistant');
    const tokenBudget: number = Math.floor(maxContextTokens * 0.8);
    let tokenAcc: number = 0;
    const selected: ChatMessage[] = [];
    for (let i: number = conversation.length - 1; i >= 0; i--) {
      const m: ChatMessage = conversation[i];
      const approxTokens: number = Math.ceil(m.content.length / 4);
      if (tokenAcc + approxTokens > tokenBudget && selected.length > 0) break;
      selected.unshift(m);
      tokenAcc = tokenAcc + approxTokens;
    }
    return selected;
  }
}

// 智子 - AI 对话仓库（API Key 加密存取 + 会话历史持久化）
import { DataRepository } from './DataRepository';
import { CryptoHelper } from '../common/CryptoHelper';
import { ChatMessage, LlmConfig, StoredChatMessage, StoredLlmConfig } from '../common/LlmModels';

const KEY_CONFIG = 'llmConfig';
const KEY_API_KEY = 'llmApiKey';
const KEY_HISTORY = 'llmChatHistory';

export class ChatRepository {
  // ---- 配置 ----

  static async loadConfig(): Promise<LlmConfig> {
    const config = new LlmConfig();
    try {
      const raw: string = await DataRepository.getSetting(KEY_CONFIG, '');
      if (raw.length > 0) {
        const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
        config.providerId = typeof parsed.providerId === 'string' ? parsed.providerId : '';
        config.baseUrl = typeof parsed.baseUrl === 'string' ? parsed.baseUrl : '';
        config.model = typeof parsed.model === 'string' ? parsed.model : '';
        if (typeof parsed.temperature === 'number') config.temperature = parsed.temperature as number;
      }
      config.apiKey = await ChatRepository.loadApiKey();
    } catch (e) {
    }
    return config;
  }

  static async saveConfig(config: LlmConfig): Promise<void> {
    const stored: StoredLlmConfig = new StoredLlmConfig(config.providerId, config.baseUrl, config.model,
      config.temperature);
    await DataRepository.setSetting(KEY_CONFIG, JSON.stringify(stored));
    await ChatRepository.saveApiKey(config.apiKey);
  }

  static async clearConfig(): Promise<void> {
    await DataRepository.setSetting(KEY_CONFIG, '');
    await DataRepository.setSetting(KEY_API_KEY, '');
  }

  private static async loadApiKey(): Promise<string> {
    try {
      const token: string = await DataRepository.getSetting(KEY_API_KEY, '');
      if (token.length === 0) return '';
      return await CryptoHelper.decrypt(token);
    } catch (e) {
      return '';
    }
  }

  private static async saveApiKey(apiKey: string): Promise<void> {
    if (!apiKey.trim()) {
      await DataRepository.setSetting(KEY_API_KEY, '');
      return;
    }
    const encrypted: string = await CryptoHelper.encrypt(apiKey.trim());
    await DataRepository.setSetting(KEY_API_KEY, encrypted);
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
        if (role.length > 0 && content.length > 0) {
          messages.push(new ChatMessage(role, content, time));
        }
      }
      return messages;
    } catch (e) {
      return [];
    }
  }

  static async saveHistory(messages: ChatMessage[]): Promise<void> {
    try {
      const storedMessages: StoredChatMessage[] = messages.map((m: ChatMessage) =>
        new StoredChatMessage(m.role, m.content, m.time));
      const payload: string = JSON.stringify(storedMessages);
      await DataRepository.setSetting(KEY_HISTORY, payload);
    } catch (e) {
    }
  }

  static async clearHistory(): Promise<void> {
    await DataRepository.setSetting(KEY_HISTORY, '');
  }

  // 转换为请求上下文（最多保留最近 20 条）
  static requestMessages(history: ChatMessage[]): ChatMessage[] {
    return history.slice(-20);
  }
}

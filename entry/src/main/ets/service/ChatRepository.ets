// 智子 - AI 对话仓库（多会话 + 消息持久化 RDB v9 + 多模型配置 + API Key 加密存取）
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';
import { DataRepository } from './DataRepository';
import { CryptoHelper } from '../common/CryptoHelper';
import { ApiFormat, ChatMessage, ChatSession, LlmConfig, LlmModelEntry, StoredLlmConfig,
  entryToConfig } from '../common/LlmModels';

const KEY_MODELS = 'llmModels';
const KEY_MODEL_KEYS = 'llmModelKeys';
const KEY_ACTIVE_MODEL = 'llmActiveModelId';
const KEY_ACTIVE_SESSION = 'llmActiveSessionId';
// 旧版单会话历史（迁移用）
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
        m.enabled, m.systemPrompt));
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
      entry.id = typeof item.id === 'string' ? item.id as string : '';
      entry.displayName = typeof item.displayName === 'string' ? item.displayName as string : '';
      entry.providerId = typeof item.providerId === 'string' ? item.providerId as string : '';
      entry.baseUrl = typeof item.baseUrl === 'string' ? item.baseUrl as string : '';
      entry.model = typeof item.model === 'string' ? item.model as string : '';
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
      if (typeof item.systemPrompt === 'string') entry.systemPrompt = item.systemPrompt as string;
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
      entry.providerId = typeof parsed.providerId === 'string' ? parsed.providerId as string : '';
      entry.baseUrl = typeof parsed.baseUrl === 'string' ? parsed.baseUrl as string : '';
      entry.model = typeof parsed.model === 'string' ? parsed.model as string : '';
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

  // ================= 多会话管理（RDB v9） =================

  // 确保存在会话：首次运行时从旧版单会话历史迁移，否则创建默认会话
  // 健壮性：若已有会话但旧历史键仍残留（上次迁移中途失败），下次启动补迁移为新会话
  static async ensureSessions(): Promise<ChatSession[]> {
    const sessions: ChatSession[] = await ChatRepository.loadSessions();
    if (sessions.length === 0) {
      await ChatRepository.migrateLegacyHistory();
      const after: ChatSession[] = await ChatRepository.loadSessions();
      if (after.length > 0) return after;
      const created: ChatSession = await ChatRepository.createSession('新的对话');
      return [created];
    }
    const legacyRaw: string = await DataRepository.getSetting(KEY_HISTORY, '');
    if (legacyRaw.trim().length > 0) {
      // 上次迁移未清空旧键：补迁移（成功后会清空旧键，避免重复执行）
      await ChatRepository.migrateLegacyHistory();
    }
    return await ChatRepository.loadSessions();
  }

  // 加载全部会话（固定置顶优先，其次按更新时间倒序）
  static async loadSessions(): Promise<ChatSession[]> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatSession[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_sessions');
      predicates.orderByDesc('pinned');
      predicates.orderByDesc('updated_at');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readSession(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  // 新建会话
  static async createSession(title: string, activeModelId: string = ''): Promise<ChatSession> {
    const session: ChatSession = ChatSession.create(title.length > 0 ? title : '新的对话', activeModelId);
    const bucket: relationalStore.ValuesBucket = {
      id: session.id,
      title: session.title,
      created_at: session.createdAt,
      updated_at: session.updatedAt,
      pinned: session.pinned ? 1 : 0,
      active_model_id: session.activeModelId
    };
    await DatabaseHelper.getStore().insert('chat_sessions', bucket);
    return session;
  }

  // 重命名会话（空标题时自动退回占位名）
  static async renameSession(id: string, title: string): Promise<void> {
    const name: string = title.trim().length > 0 ? title.trim() : '未命名对话';
    const predicates = new relationalStore.RdbPredicates('chat_sessions');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { title: name, updated_at: Date.now() };
    await DatabaseHelper.getStore().update(bucket, predicates);
  }

  // 固定/取消固定会话
  static async setSessionPinned(id: string, pinned: boolean): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_sessions');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { pinned: pinned ? 1 : 0, updated_at: Date.now() };
    await DatabaseHelper.getStore().update(bucket, predicates);
  }

  // 触碰会话（更新时间戳，用于会话列表排序）
  static async touchSession(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_sessions');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { updated_at: Date.now() };
    await DatabaseHelper.getStore().update(bucket, predicates);
  }

  // 删除会话（连同其全部消息）
  static async deleteSession(id: string): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    await store.beginTransaction();
    try {
      const msgPredicates = new relationalStore.RdbPredicates('chat_messages');
      msgPredicates.equalTo('session_id', id);
      await store.delete(msgPredicates);
      const sessPredicates = new relationalStore.RdbPredicates('chat_sessions');
      sessPredicates.equalTo('id', id);
      await store.delete(sessPredicates);
      await store.commit();
    } catch (e) {
      await store.rollBack();
      throw new Error('PERSISTENCE_FAILED');
    }
  }

  // 当前激活会话 id（持久化；失效时回退到第一个会话）
  static async loadActiveSessionId(): Promise<string> {
    try {
      const saved: string = await DataRepository.getSetting(KEY_ACTIVE_SESSION, '');
      if (saved.length > 0) {
        const sessions: ChatSession[] = await ChatRepository.loadSessions();
        for (let i: number = 0; i < sessions.length; i++) {
          if (sessions[i].id === saved) return saved;
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static async setActiveSessionId(id: string): Promise<void> {
    await DataRepository.setSetting(KEY_ACTIVE_SESSION, id);
  }

  // ---- 会话消息 ----

  // 加载会话消息（按时间升序）
  static async loadMessages(sessionId: string): Promise<ChatMessage[]> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatMessage[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_messages');
      predicates.equalTo('session_id', sessionId);
      predicates.orderByAsc('time');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readMessage(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  // 追加一条或多条消息到会话
  static async appendMessages(sessionId: string, messages: ChatMessage[]): Promise<void> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    await store.beginTransaction();
    try {
      for (let i: number = 0; i < messages.length; i++) {
        const m: ChatMessage = messages[i];
        m.sessionId = sessionId;
        await store.insert('chat_messages', ChatRepository.messageBucket(sessionId, m));
      }
      await store.commit();
    } catch (e) {
      await store.rollBack();
      throw new Error('PERSISTENCE_FAILED');
    }
  }

  // 更新单条消息（内容/思考/状态/错误/用量）
  static async updateMessage(message: ChatMessage): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_messages');
    predicates.equalTo('id', message.id);
    const bucket: relationalStore.ValuesBucket = {
      content: message.content,
      reasoning: message.reasoning,
      status: message.status,
      error_code: message.errorCode,
      error_msg: message.errorMessage,
      model_id: message.modelId,
      model_name: message.modelName,
      input_tokens: message.inputTokens,
      cached_tokens: message.cachedTokens,
      output_tokens: message.outputTokens,
      total_tokens: message.totalTokens
    };
    await DatabaseHelper.getStore().update(bucket, predicates);
  }

  // 删除会话内指定消息，返回剩余消息（逐个删除，避免 ArkTS 类型转换问题）
  static async deleteMessages(sessionId: string, ids: string[]): Promise<ChatMessage[]> {
    if (ids.length === 0) return await ChatRepository.loadMessages(sessionId);
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    for (let i: number = 0; i < ids.length; i++) {
      const predicates = new relationalStore.RdbPredicates('chat_messages');
      predicates.equalTo('session_id', sessionId);
      predicates.equalTo('id', ids[i]);
      await store.delete(predicates);
    }
    return await ChatRepository.loadMessages(sessionId);
  }

  // 清空会话消息
  static async clearSessionMessages(sessionId: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_messages');
    predicates.equalTo('session_id', sessionId);
    await DatabaseHelper.getStore().delete(predicates);
  }

  // 跨会话搜索：标题命中（SQL LIKE）
  static async searchSessions(query: string): Promise<ChatSession[]> {
    const q: string = query.trim();
    if (q.length === 0) return await ChatRepository.loadSessions();
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatSession[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_sessions');
      predicates.like('title', '%' + q + '%');
      predicates.orderByDesc('updated_at');
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readSession(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  // 跨会话搜索：按消息正文命中（标题或内容包含关键字都会命中该会话）
  static async searchSessionsByMessage(query: string): Promise<ChatSession[]> {
    const q: string = query.trim().toLowerCase();
    if (q.length === 0) return await ChatRepository.loadSessions();
    const all: ChatSession[] = await ChatRepository.loadSessions();
    const hits: ChatSession[] = [];
    for (let i: number = 0; i < all.length; i++) {
      const msgs: ChatMessage[] = await ChatRepository.loadMessages(all[i].id);
      let found: boolean = false;
      for (let m: number = 0; m < msgs.length; m++) {
        if (msgs[m].content.toLowerCase().indexOf(q) >= 0) {
          found = true;
          break;
        }
      }
      if (found) hits.push(all[i]);
    }
    return hits;
  }

  // 旧版单会话历史 → 默认会话迁移（仅执行一次）
  private static async migrateLegacyHistory(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting(KEY_HISTORY, '');
      if (raw.length === 0) return;
      const parsed: Array<Record<string, Object>> = JSON.parse(raw) as Array<Record<string, Object>>;
      if (parsed.length === 0) return;
      // 用第一条用户消息生成标题
      let title: string = '历史对话';
      for (let i: number = 0; i < parsed.length; i++) {
        const item: Record<string, Object> = parsed[i];
        if (typeof item.role === 'string' && item.role === 'user') {
          const content: string = typeof item.content === 'string' ? item.content as string : '';
          const firstLine: string = content.split('\n')[0].trim();
          if (firstLine.length > 0) {
            title = firstLine.length > 20 ? firstLine.substring(0, 20) + '…' : firstLine;
          }
          break;
        }
      }
      const session: ChatSession = await ChatRepository.createSession(title);
      const messages: ChatMessage[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        const item: Record<string, Object> = parsed[i];
        const role: string = typeof item.role === 'string' ? item.role as string : '';
        const content: string = typeof item.content === 'string' ? item.content as string : '';
        const time: number = typeof item.time === 'number' ? item.time as number : 0;
        const reasoning: string = typeof item.reasoning === 'string' ? item.reasoning as string : '';
        if (role.length > 0 && content.length > 0) {
          const id: string = typeof item.id === 'string' && (item.id as string).length > 0
            ? item.id as string : ChatMessage.newId();
          messages.push(new ChatMessage(id, role, content, time, reasoning));
        }
      }
      if (messages.length > 0) {
        await ChatRepository.appendMessages(session.id, messages);
      }
      await ChatRepository.setActiveSessionId(session.id);
      // 迁移成功后清空旧键，避免重复迁移
      await DataRepository.setSetting(KEY_HISTORY, '');
    } catch (e) {
    }
  }

  private static readSession(resultSet: relationalStore.ResultSet): ChatSession {
    return new ChatSession(
      resultSet.getString(resultSet.getColumnIndex('id')),
      resultSet.getString(resultSet.getColumnIndex('title')),
      resultSet.getLong(resultSet.getColumnIndex('created_at')),
      resultSet.getLong(resultSet.getColumnIndex('updated_at')),
      resultSet.getLong(resultSet.getColumnIndex('pinned')) === 1,
      resultSet.getString(resultSet.getColumnIndex('active_model_id')));
  }

  private static messageBucket(sessionId: string, m: ChatMessage): relationalStore.ValuesBucket {
    return {
      id: m.id,
      session_id: sessionId,
      role: m.role,
      content: m.content,
      reasoning: m.reasoning,
      time: m.time,
      status: m.status,
      error_code: m.errorCode,
      error_msg: m.errorMessage,
      model_id: m.modelId,
      model_name: m.modelName,
      input_tokens: m.inputTokens,
      cached_tokens: m.cachedTokens,
      output_tokens: m.outputTokens,
      total_tokens: m.totalTokens,
      image_data: m.imageDataUrl
    };
  }

  private static readMessage(resultSet: relationalStore.ResultSet): ChatMessage {
    const msg = new ChatMessage(
      resultSet.getString(resultSet.getColumnIndex('id')),
      resultSet.getString(resultSet.getColumnIndex('role')),
      resultSet.getString(resultSet.getColumnIndex('content')),
      resultSet.getLong(resultSet.getColumnIndex('time')),
      resultSet.getString(resultSet.getColumnIndex('reasoning')));
    msg.sessionId = resultSet.getString(resultSet.getColumnIndex('session_id'));
    msg.status = resultSet.getString(resultSet.getColumnIndex('status'));
    msg.errorCode = resultSet.getString(resultSet.getColumnIndex('error_code'));
    msg.errorMessage = resultSet.getString(resultSet.getColumnIndex('error_msg'));
    msg.modelId = resultSet.getString(resultSet.getColumnIndex('model_id'));
    msg.modelName = resultSet.getString(resultSet.getColumnIndex('model_name'));
    msg.inputTokens = resultSet.getLong(resultSet.getColumnIndex('input_tokens'));
    msg.cachedTokens = resultSet.getLong(resultSet.getColumnIndex('cached_tokens'));
    msg.outputTokens = resultSet.getLong(resultSet.getColumnIndex('output_tokens'));
    msg.totalTokens = resultSet.getLong(resultSet.getColumnIndex('total_tokens'));
    msg.imageDataUrl = resultSet.getString(resultSet.getColumnIndex('image_data'));
    return msg;
  }

  // ---- 旧版单会话 API（兼容保留：作用于当前激活会话） ----

  static async loadHistory(): Promise<ChatMessage[]> {
    const sessions: ChatSession[] = await ChatRepository.ensureSessions();
    const activeId: string = await ChatRepository.loadActiveSessionId();
    const sessionId: string = activeId.length > 0 ? activeId : sessions[0].id;
    return await ChatRepository.loadMessages(sessionId);
  }

  static async saveHistory(messages: ChatMessage[]): Promise<void> {
    const sessions: ChatSession[] = await ChatRepository.ensureSessions();
    const activeId: string = await ChatRepository.loadActiveSessionId();
    const sessionId: string = activeId.length > 0 ? activeId : sessions[0].id;
    await ChatRepository.clearSessionMessages(sessionId);
    if (messages.length > 0) {
      await ChatRepository.appendMessages(sessionId, messages);
    }
  }

  static async clearHistory(): Promise<void> {
    const sessions: ChatSession[] = await ChatRepository.ensureSessions();
    const activeId: string = await ChatRepository.loadActiveSessionId();
    const sessionId: string = activeId.length > 0 ? activeId : sessions[0].id;
    await ChatRepository.clearSessionMessages(sessionId);
  }

  // ---- 上下文与估算 ----

  // 估算文本 token 数（字符/4，与旧实现一致）
  static estimateTokens(text: string): number {
    return Math.ceil(text.length / 4);
  }

  // 转换为请求上下文：
  // - 跳过 system role（应通过系统提示词注入，此处仅保留 user/assistant）
  // - 按字符数估算 token，从最新向前累加直到接近 maxTokens 的 80%
  static requestMessages(history: ChatMessage[], maxContextTokens: number = 128000): ChatMessage[] {
    const conversation: ChatMessage[] = history.filter((m: ChatMessage): boolean =>
      m.role === 'user' || m.role === 'assistant');
    const tokenBudget: number = Math.floor(maxContextTokens * 0.8);
    let tokenAcc: number = 0;
    const selected: ChatMessage[] = [];
    for (let i: number = conversation.length - 1; i >= 0; i--) {
      const m: ChatMessage = conversation[i];
      const approxTokens: number = ChatRepository.estimateTokens(m.content);
      if (tokenAcc + approxTokens > tokenBudget && selected.length > 0) break;
      selected.unshift(m);
      tokenAcc = tokenAcc + approxTokens;
    }
    return selected;
  }

  // 估算整个会话的上下文占用（输入 token 数），用于 UI 展示
  static estimateSessionTokens(messages: ChatMessage[]): number {
    let acc: number = 0;
    for (let i: number = 0; i < messages.length; i++) {
      acc = acc + ChatRepository.estimateTokens(messages[i].content) +
        ChatRepository.estimateTokens(messages[i].reasoning);
    }
    return acc;
  }
}

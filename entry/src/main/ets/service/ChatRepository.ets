// 智子 - AI 对话仓库（多会话 + 消息持久化 RDB v9 + 多模型配置 + API Key 加密存取）
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from './DatabaseHelper';
import { DataRepository } from './DataRepository';
import { AchievementService } from './AchievementService';
import { CryptoHelper } from '../common/CryptoHelper';
import { ChatExporter, ImportedChat } from './ChatExporter';
import { ApiFormat, ChatMessage, ChatSession, LlmConfig, LlmModelEntry, StoredLlmConfig,
  entryToConfig } from '../common/LlmModels';

// FTS5 全文索引维护 SQL（表在 DatabaseHelper.initFtsTables 中创建；不可用时全部 no-op）
const SQL_FTS_INSERT_CHAT = 'INSERT OR REPLACE INTO chat_messages_fts (id, session_id, role, content, reasoning) VALUES (?, ?, ?, ?, ?)';
const SQL_FTS_DELETE_CHAT = 'DELETE FROM chat_messages_fts WHERE id = ?';
const SQL_FTS_DELETE_CHAT_BY_SESSION = 'DELETE FROM chat_messages_fts WHERE session_id = ?';
const SQL_FTS_COUNT_CHAT = 'SELECT COUNT(*) AS c FROM chat_messages_fts';

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

  // AI 角色模板应用：把角色 system prompt 写入指定模型的配置并持久化
  static async updateModelSystemPrompt(modelId: string, prompt: string): Promise<boolean> {
    if (modelId.length === 0) return false;
    try {
      const models: LlmModelEntry[] = await ChatRepository.loadModels();
      let found: boolean = false;
      for (let i: number = 0; i < models.length; i++) {
        if (models[i].id === modelId) {
          models[i].systemPrompt = prompt;
          found = true;
          break;
        }
      }
      if (!found) return false;
      await ChatRepository.saveModels(models);
      return true;
    } catch (e) {
      return false;
    }
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
      active_model_id: session.activeModelId,
      incognito: session.incognito ? 1 : 0,
      system_prompt: session.systemPrompt
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

  // 设置会话无痕标记（无痕会话的消息不写入数据库）
  static async setSessionIncognito(id: string, incognito: boolean): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_sessions');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { incognito: incognito ? 1 : 0, updated_at: Date.now() };
    await DatabaseHelper.getStore().update(bucket, predicates);
  }

  // 设置会话级系统提示词（AI 角色模板应用到会话）
  static async setSessionSystemPrompt(id: string, prompt: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('chat_sessions');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { system_prompt: prompt, updated_at: Date.now() };
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
      // 同步清理 FTS 索引
      if (DatabaseHelper.isChatFtsReady()) {
        await store.executeSql(SQL_FTS_DELETE_CHAT_BY_SESSION, [id]);
      }
      // 级联清理 Agent 执行步骤，避免孤儿数据随会话删除残留
      const stepPredicates = new relationalStore.RdbPredicates('chat_agent_steps');
      stepPredicates.equalTo('session_id', id);
      await store.delete(stepPredicates);
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

  // 加载会话消息（按时间升序，全量：备份/导入等场景使用）
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

  // 加载会话消息窗口（倒序分页取最近 limit 条，再翻转为时间升序；聊天列表渲染用）
  static async loadMessagesWindow(sessionId: string, limit: number, offset: number): Promise<ChatMessage[]> {
    if (limit <= 0) return [];
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatMessage[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_messages');
      predicates.equalTo('session_id', sessionId);
      predicates.orderByDesc('time');
      predicates.limitAs(limit);
      predicates.offsetAs(offset);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readMessage(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    results.reverse();
    return results;
  }

  // 加载指定时间之前的历史消息（上滑补载），返回时间升序
  static async loadMessagesBefore(sessionId: string, beforeTime: number, limit: number): Promise<ChatMessage[]> {
    if (limit <= 0) return [];
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatMessage[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('chat_messages');
      predicates.equalTo('session_id', sessionId);
      predicates.lessThan('time', beforeTime);
      predicates.orderByDesc('time');
      predicates.limitAs(limit);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readMessage(resultSet));
      }
      resultSet.close();
    } catch (e) {
    }
    results.reverse();
    return results;
  }

  // 会话消息总数（COUNT(*) 聚合，避免全表拉取循环计数）
  static async countMessages(sessionId: string): Promise<number> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    try {
      const resultSet = await store.querySql('SELECT COUNT(*) AS c FROM chat_messages WHERE session_id = ?',
        [sessionId]);
      let count: number = 0;
      if (resultSet.goToNextRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('c'));
      }
      resultSet.close();
      return count;
    } catch (e) {
      return 0;
    }
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
        // 同步 FTS 索引（索引不可用时为空操作）
        if (DatabaseHelper.isChatFtsReady()) {
          await store.executeSql(SQL_FTS_INSERT_CHAT, [m.id, sessionId, m.role, m.content, m.reasoning]);
        }
      }
      await store.commit();
      // 成就触发：按累计用户消息条数更新对话类成就
      const userCount: number = await DatabaseHelper.getChatMessageCount();
      await AchievementService.onChatMessages(userCount);
    } catch (e) {
      await store.rollBack();
      throw new Error('PERSISTENCE_FAILED');
    }
  }

  // 从备份 JSON 恢复全部会话（云同步用），返回导入会话数
  static async importBackupAll(json: string): Promise<number> {
    const importedList: ImportedChat[] = ChatExporter.parseImportAll(json);
    if (importedList.length === 0) return 0;
    for (let i: number = 0; i < importedList.length; i++) {
      const imported: ImportedChat = importedList[i];
      const session: ChatSession = await ChatRepository.createSession(imported.title);
      await ChatRepository.appendMessages(session.id, imported.messages);
    }
    return importedList.length;
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
    // 同步 FTS 索引（消息正文/状态变化后重新索引）
    if (DatabaseHelper.isChatFtsReady()) {
      try {
        const ftsStore: relationalStore.RdbStore = DatabaseHelper.getStore();
        await ftsStore.executeSql(SQL_FTS_INSERT_CHAT, [message.id, message.sessionId, message.role,
          message.content, message.reasoning]);
      } catch (e) {
      }
    }
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
      if (DatabaseHelper.isChatFtsReady()) {
        await store.executeSql(SQL_FTS_DELETE_CHAT, [ids[i]]);
      }
    }
    return await ChatRepository.loadMessages(sessionId);
  }

  // 清空会话消息
  static async clearSessionMessages(sessionId: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('chat_messages');
    predicates.equalTo('session_id', sessionId);
    await store.delete(predicates);
    if (DatabaseHelper.isChatFtsReady()) {
      try {
        await store.executeSql(SQL_FTS_DELETE_CHAT_BY_SESSION, [sessionId]);
      } catch (e) {
      }
    }
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

  // 跨会话全文搜索：优先 FTS5（按相关度排序），不可用/短词回退 LIKE（EXISTS 子查询，无 N+1 全量加载）
  static async searchSessionsByMessage(query: string): Promise<ChatSession[]> {
    const q: string = query.trim();
    if (q.length === 0) return await ChatRepository.loadSessions();
    await ChatRepository.ensureChatFtsIndex();
    if (DatabaseHelper.isChatFtsReady() && q.length >= 3) {
      try {
        const store: relationalStore.RdbStore = DatabaseHelper.getStore();
        const sessionIds: string[] = [];
        const resultSet = await store.querySql(
          'SELECT session_id FROM chat_messages_fts WHERE chat_messages_fts MATCH ? ' +
          'GROUP BY session_id ORDER BY MIN(bm25(chat_messages_fts)) LIMIT ?',
          [ChatRepository.ftsPhrase(q), 50]);
        try {
          while (resultSet.goToNextRow()) {
            sessionIds.push(resultSet.getString(resultSet.getColumnIndex('session_id')));
          }
        } finally {
          resultSet.close();
        }
        return await ChatRepository.sessionsByIds(sessionIds);
      } catch (e) {
        // FTS 查询异常（如分词器限制）回退 LIKE
      }
    }
    return await ChatRepository.likeSearchSessionsByMessage(q);
  }

  // LIKE 兜底：单条 EXISTS SQL 跨会话匹配正文（替代原来的逐会话全量加载）
  private static async likeSearchSessionsByMessage(q: string): Promise<ChatSession[]> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatSession[] = [];
    const like: string = '%' + q + '%';
    try {
      const resultSet = await store.querySql(
        'SELECT DISTINCT s.id, s.title, s.created_at, s.updated_at, s.pinned, s.active_model_id, ' +
        's.incognito, s.system_prompt FROM chat_sessions s WHERE EXISTS (SELECT 1 FROM chat_messages m ' +
        'WHERE m.session_id = s.id AND (m.content LIKE ? OR m.reasoning LIKE ?)) ' +
        'ORDER BY s.updated_at DESC LIMIT 50', [like, like]);
      while (resultSet.goToNextRow()) {
        results.push(new ChatSession(
          resultSet.getString(resultSet.getColumnIndex('id')),
          resultSet.getString(resultSet.getColumnIndex('title')),
          resultSet.getLong(resultSet.getColumnIndex('created_at')),
          resultSet.getLong(resultSet.getColumnIndex('updated_at')),
          resultSet.getLong(resultSet.getColumnIndex('pinned')) === 1,
          resultSet.getString(resultSet.getColumnIndex('active_model_id')),
          resultSet.getLong(resultSet.getColumnIndex('incognito')) === 1,
          resultSet.getString(resultSet.getColumnIndex('system_prompt'))));
      }
      resultSet.close();
    } catch (e) {
    }
    return results;
  }

  // 会话内全文搜索（搜索整个会话历史，而非仅已加载窗口）
  static async searchSessionMessages(sessionId: string, query: string, limit: number = 50): Promise<ChatMessage[]> {
    const q: string = query.trim();
    if (q.length === 0 || sessionId.length === 0) return [];
    await ChatRepository.ensureChatFtsIndex();
    if (DatabaseHelper.isChatFtsReady() && q.length >= 3) {
      try {
        const store: relationalStore.RdbStore = DatabaseHelper.getStore();
        const ids: string[] = [];
        const resultSet = await store.querySql(
          'SELECT id FROM chat_messages_fts WHERE session_id = ? AND chat_messages_fts MATCH ? ' +
          'ORDER BY bm25(chat_messages_fts) LIMIT ?', [sessionId, ChatRepository.ftsPhrase(q), limit]);
        try {
          while (resultSet.goToNextRow()) {
            ids.push(resultSet.getString(resultSet.getColumnIndex('id')));
          }
        } finally {
          resultSet.close();
        }
        const out: ChatMessage[] = [];
        for (let i: number = 0; i < ids.length; i++) {
          const m: ChatMessage | null = await ChatRepository.getMessageById(ids[i]);
          if (m !== null) out.push(m);
        }
        return out;
      } catch (e) {
      }
    }
    return await ChatRepository.likeSearchSessionMessages(sessionId, q, limit);
  }

  // LIKE 兜底：会话内消息正文匹配（时间倒序取最近 limit 条）
  private static async likeSearchSessionMessages(sessionId: string, q: string, limit: number): Promise<ChatMessage[]> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    const results: ChatMessage[] = [];
    const like: string = '%' + q + '%';
    try {
      const resultSet = await store.querySql(
        'SELECT * FROM chat_messages WHERE session_id = ? AND (content LIKE ? OR reasoning LIKE ?) ' +
        'ORDER BY time DESC LIMIT ?', [sessionId, like, like, limit]);
      while (resultSet.goToNextRow()) {
        results.push(ChatRepository.readMessage(resultSet));
      }
      resultSet.close();
      results.reverse();
    } catch (e) {
    }
    return results;
  }

  // 按 id 加载单条消息
  static async getMessageById(id: string): Promise<ChatMessage | null> {
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('chat_messages');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      try {
        if (resultSet.goToNextRow()) return ChatRepository.readMessage(resultSet);
        return null;
      } finally {
        resultSet.close();
      }
    } catch (e) {
      return null;
    }
  }

  // 按 id 列表还原会话（保持 FTS 相关度顺序）
  private static async sessionsByIds(ids: string[]): Promise<ChatSession[]> {
    const all: ChatSession[] = await ChatRepository.loadSessions();
    const byId: Map<string, ChatSession> = new Map<string, ChatSession>();
    for (let i: number = 0; i < all.length; i++) {
      byId.set(all[i].id, all[i]);
    }
    const out: ChatSession[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      const s: ChatSession | undefined = byId.get(ids[i]);
      if (s !== undefined) out.push(s);
    }
    return out;
  }

  // FTS 短语转义（trigram 分词下按短语匹配子串）
  private static ftsPhrase(query: string): string {
    const q: string = query.trim();
    return '"' + q.replace(/"/g, '""') + '"';
  }

  // 首次搜索前确保 FTS 索引存在（启动后第一次搜索时全量重建一次）
  private static ftsIndexChecked: boolean = false;

  private static async ensureChatFtsIndex(): Promise<void> {
    if (!DatabaseHelper.isChatFtsReady() || ChatRepository.ftsIndexChecked) return;
    ChatRepository.ftsIndexChecked = true;
    const store: relationalStore.RdbStore = DatabaseHelper.getStore();
    try {
      const countRs = await store.querySql(SQL_FTS_COUNT_CHAT);
      let n: number = 0;
      try {
        if (countRs.goToNextRow()) n = countRs.getLong(countRs.getColumnIndex('c'));
      } finally {
        countRs.close();
      }
      if (n > 0) return;
      const sessions: ChatSession[] = await ChatRepository.loadSessions();
      for (let i: number = 0; i < sessions.length; i++) {
        const msgs: ChatMessage[] = await ChatRepository.loadMessages(sessions[i].id);
        for (let j: number = 0; j < msgs.length; j++) {
          const m: ChatMessage = msgs[j];
          await store.executeSql(SQL_FTS_INSERT_CHAT, [m.id, sessions[i].id, m.role, m.content, m.reasoning]);
        }
      }
    } catch (e) {
    }
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
      resultSet.getString(resultSet.getColumnIndex('active_model_id')),
      resultSet.getLong(resultSet.getColumnIndex('incognito')) === 1,
      resultSet.getString(resultSet.getColumnIndex('system_prompt')));
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

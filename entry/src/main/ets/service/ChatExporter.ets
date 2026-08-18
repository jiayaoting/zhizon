// 智子 - AI 会话导出 / 导入（Markdown / JSON / 文件备份）
import { ChatMessage, ChatSession } from '../common/LlmModels';

// 导入解析结果
export class ImportedChat {
  title: string;
  messages: ChatMessage[];

  constructor(title: string, messages: ChatMessage[]) {
    this.title = title;
    this.messages = messages;
  }
}

// 文件备份中单个会话条目
class BackupSessionItem {
  title: string;
  createdAt: number;
  messages: Record<string, Object>[];

  constructor(title: string, createdAt: number, messages: Record<string, Object>[]) {
    this.title = title;
    this.createdAt = createdAt;
    this.messages = messages;
  }
}

export class ChatExporter {
  // 导出为 Markdown：标题 + 按角色分节的消息（含思考过程引用块）
  static toMarkdown(session: ChatSession, messages: ChatMessage[]): string {
    const lines: string[] = [];
    lines.push('# ' + (session.title.trim().length > 0 ? session.title.trim() : 'AI 对话'));
    lines.push('');
    for (let i: number = 0; i < messages.length; i++) {
      const m: ChatMessage = messages[i];
      const roleName: string = m.role === 'user' ? '用户' : (m.role === 'assistant' ? '智子 AI' : '系统');
      lines.push('## ' + roleName + ' · ' + ChatExporter.fmtTime(m.time));
      lines.push('');
      if (m.reasoning.trim().length > 0) {
        lines.push('> 💭 思考过程');
        const reasonLines: string[] = m.reasoning.trim().split('\n');
        for (let r: number = 0; r < reasonLines.length; r++) {
          lines.push('> ' + reasonLines[r]);
        }
        lines.push('');
      }
      lines.push(m.content);
      lines.push('');
    }
    return lines.join('\n');
  }

  // 导出为 JSON（app/version/title/messages）
  static toJson(session: ChatSession, messages: ChatMessage[]): string {
    const msgList: Record<string, Object>[] = [];
    for (let i: number = 0; i < messages.length; i++) {
      const m: ChatMessage = messages[i];
      const item: Record<string, Object> = {};
      item['role'] = m.role;
      item['content'] = m.content;
      item['reasoning'] = m.reasoning;
      item['time'] = m.time;
      msgList.push(item);
    }
    const payload: Record<string, Object> = {};
    payload['app'] = 'zhizon';
    payload['version'] = 1;
    payload['title'] = session.title.trim().length > 0 ? session.title.trim() : 'AI 对话';
    payload['messages'] = msgList;
    return JSON.stringify(payload);
  }

  // 导出全部会话为备份 JSON（app/version:2/sessions[{title,createdAt,messages}]）
  // messagesBySession：会话 id → 消息数组（调用方负责加载）
  static toJsonAll(sessions: ChatSession[],
    messagesBySession: (sessionId: string) => ChatMessage[]): string {
    const sessionList: BackupSessionItem[] = [];
    for (let i: number = 0; i < sessions.length; i++) {
      const s: ChatSession = sessions[i];
      const msgs: ChatMessage[] = messagesBySession(s.id);
      const msgList: Record<string, Object>[] = [];
      for (let j: number = 0; j < msgs.length; j++) {
        const m: ChatMessage = msgs[j];
        const item: Record<string, Object> = {};
        item['role'] = m.role;
        item['content'] = m.content;
        item['reasoning'] = m.reasoning;
        item['time'] = m.time;
        msgList.push(item);
      }
      sessionList.push(new BackupSessionItem(s.title, s.createdAt, msgList));
    }
    const payload: Record<string, Object> = {};
    payload['app'] = 'zhizon';
    payload['version'] = 2;
    payload['exportedAt'] = Date.now();
    payload['sessions'] = sessionList;
    return JSON.stringify(payload);
  }

  // 解析文件备份 JSON（version 2 多会话 / version 1 单会话均支持）；格式非法返回空数组
  static parseImportAll(json: string): ImportedChat[] {
    const result: ImportedChat[] = [];
    try {
      const parsed: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (typeof parsed.app !== 'string' || parsed.app !== 'zhizon') return result;
      const sessions: Object = parsed['sessions'];
      if (sessions !== undefined && Array.isArray(sessions)) {
        const arr: Object[] = sessions as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          const item: Record<string, Object> = arr[i] as Record<string, Object>;
          const msgs: Object = item['messages'];
          if (msgs === undefined || !Array.isArray(msgs)) continue;
          const messages: ChatMessage[] = ChatExporter.parseMessages(msgs as Object[]);
          if (messages.length === 0) continue;
          const title: string = typeof item['title'] === 'string' ? item['title'] as string : '导入的对话';
          result.push(new ImportedChat(title, messages));
        }
        return result;
      }
      // version 1 单会话格式兜底
      const single: ImportedChat | null = ChatExporter.parseImport(json);
      if (single !== null) result.push(single);
      return result;
    } catch (e) {
      return result;
    }
  }

  private static parseMessages(arr: Object[]): ChatMessage[] {
    const messages: ChatMessage[] = [];
    for (let i: number = 0; i < arr.length; i++) {
      const item: Record<string, Object> = arr[i] as Record<string, Object>;
      const role: string = typeof item.role === 'string' ? item.role as string : '';
      const content: string = typeof item.content === 'string' ? item.content as string : '';
      if ((role === 'user' || role === 'assistant') && content.length > 0) {
        const time: number = typeof item.time === 'number' ? item.time as number : 0;
        const reasoning: string = typeof item.reasoning === 'string' ? item.reasoning as string : '';
        messages.push(new ChatMessage(ChatMessage.newId(), role, content, time, reasoning));
      }
    }
    return messages;
  }

  // 解析导入 JSON：格式非法返回 null
  static parseImport(json: string): ImportedChat | null {
    try {
      const parsed: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      if (typeof parsed.app !== 'string' || parsed.app !== 'zhizon') return null;
      const msgs: Object = parsed.messages;
      if (msgs === undefined || !Array.isArray(msgs)) return null;
      const arr: Object[] = msgs as Object[];
      const messages: ChatMessage[] = [];
      for (let i: number = 0; i < arr.length; i++) {
        const item: Record<string, Object> = arr[i] as Record<string, Object>;
        const role: string = typeof item.role === 'string' ? item.role as string : '';
        const content: string = typeof item.content === 'string' ? item.content as string : '';
        if ((role === 'user' || role === 'assistant') && content.length > 0) {
          const time: number = typeof item.time === 'number' ? item.time as number : 0;
          const reasoning: string = typeof item.reasoning === 'string' ? item.reasoning as string : '';
          messages.push(new ChatMessage(ChatMessage.newId(), role, content, time, reasoning));
        }
      }
      if (messages.length === 0) return null;
      const title: string = typeof parsed.title === 'string' ? parsed.title as string : '导入的对话';
      return new ImportedChat(title, messages);
    } catch (e) {
      return null;
    }
  }

  private static fmtTime(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    const month: string = (d.getMonth() + 1).toString();
    const day: string = d.getDate().toString();
    return month + '月' + day + '日 ' + hh + ':' + mm;
  }
}

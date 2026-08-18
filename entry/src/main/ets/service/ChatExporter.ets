// 智子 - AI 会话导出 / 导入（Markdown / JSON）
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

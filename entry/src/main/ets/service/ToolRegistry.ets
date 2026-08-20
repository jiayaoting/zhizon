// 智子 - 工具注册表（P0：计算器 / 当前时间 / 联网搜索，均为 SAFE 只读）
import { ToolDefinition, ToolResult, ToolLevel } from '../common/AgentModels';
import { WebSearchService, WebSearchResult } from './WebSearchService';
import { DataRepository } from './DataRepository';
import { NewsService } from './NewsService';
import { NewsItem } from '../common/NewsModels';

const CALC_SCHEMA = '{"type":"object","properties":{"expression":{"type":"string","description":"数学表达式，如 123*45+7"}},"required":["expression"]}';
const NOW_SCHEMA = '{"type":"object","properties":{}}';
const SEARCH_SCHEMA = '{"type":"object","properties":{"query":{"type":"string","description":"搜索关键词"}},"required":["query"]}';
const NEWS_SCHEMA = '{"type":"object","properties":{}}';
const NEWS_SEARCH_SCHEMA = '{"type":"object","properties":{"query":{"type":"string","description":"新闻搜索关键词"}},"required":["query"]}';

export class ToolRegistry {
  // 当前支持的 SAFe 工具列表
  static listTools(): ToolDefinition[] {
    return [
      new ToolDefinition('calculator', '计算数学表达式，支持 + - * / 与括号', CALC_SCHEMA, 'SAFE'),
      new ToolDefinition('now', '获取当前日期与时间', NOW_SCHEMA, 'SAFE'),
      new ToolDefinition('web_search', '联网搜索，返回相关结果摘要', SEARCH_SCHEMA, 'SAFE'),
      new ToolDefinition('news_top', '获取今日热点新闻标题列表（含来源），供回答近期热点问题', NEWS_SCHEMA, 'SAFE'),
      new ToolDefinition('news_search', '按关键词搜索新闻，返回标题与摘要', NEWS_SEARCH_SCHEMA, 'SAFE')
    ];
  }

  static async execute(name: string, argsJson: string): Promise<ToolResult> {
    if (name === 'calculator') return ToolRegistry.runCalculator(argsJson);
    if (name === 'now') return new ToolResult('', true, ToolRegistry.nowText(), '');
    if (name === 'web_search') return await ToolRegistry.runSearch(argsJson);
    if (name === 'news_top') return await ToolRegistry.runNewsTop();
    if (name === 'news_search') return await ToolRegistry.runNewsSearch(argsJson);
    return new ToolResult('', false, '', '未知工具：' + name);
  }

  // ---- 新闻搜索 ----
  private static async runNewsSearch(argsJson: string): Promise<ToolResult> {
    try {
      const args: Record<string, Object> = JSON.parse(argsJson) as Record<string, Object>;
      const query: string = typeof args['query'] === 'string' ? args['query'] as string : '';
      if (query.trim().length === 0) return new ToolResult('', false, '', '搜索关键词为空');
      const items: NewsItem[] = await NewsService.search(query.trim(), 10);
      if (items.length === 0) return new ToolResult('', false, '', '未找到相关新闻');
      let text: string = '搜索「' + query.trim() + '」结果（' + items.length.toString() + ' 条）：\n';
      for (let i: number = 0; i < items.length; i++) {
        text = text + (i + 1).toString() + '. [' + items[i].sourceName + '] ' + items[i].title +
          (items[i].summary.length > 0 ? ' —— ' + items[i].summary.trim().substring(0, 60) : '') + '\n';
      }
      return new ToolResult('', true, text, '');
    } catch (e) {
      return new ToolResult('', false, '', '搜索新闻失败');
    }
  }

  // ---- 今日热点新闻（资讯功能数据） ----
  private static async runNewsTop(): Promise<ToolResult> {
    try {
      const items: NewsItem[] = await NewsService.fetchChannel('recommend', 10, false);
      if (items.length === 0) {
        return new ToolResult('', false, '', '暂无新闻数据，请检查网络');
      }
      let text: string = '今日热点新闻（共 ' + items.length.toString() + ' 条）：\n';
      for (let i: number = 0; i < items.length; i++) {
        text = text + (i + 1).toString() + '. [' + items[i].sourceName + '] ' + items[i].title + '\n';
      }
      return new ToolResult('', true, text, '');
    } catch (e) {
      return new ToolResult('', false, '', '获取新闻失败');
    }
  }

  // ---- 计算器（递归下降，仅支持 + - * / 括号与小数，无 eval） ----
  private static calcSrc: string = '';
  private static calcPos: number = 0;

  private static runCalculator(argsJson: string): ToolResult {
    try {
      const args: Record<string, Object> = JSON.parse(argsJson) as Record<string, Object>;
      const expr: string = typeof args['expression'] === 'string' ? args['expression'] as string : '';
      if (expr.trim().length === 0) return new ToolResult('', false, '', '表达式为空');
      ToolRegistry.calcSrc = expr;
      ToolRegistry.calcPos = 0;
      const value: number = ToolRegistry.parseExpr();
      ToolRegistry.skipSpace();
      if (ToolRegistry.calcPos < ToolRegistry.calcSrc.length) {
        return new ToolResult('', false, '', '表达式格式无效');
      }
      return new ToolResult('', true, value.toString(), '');
    } catch (e) {
      return new ToolResult('', false, '', '计算失败：表达式无效');
    }
  }

  private static parseExpr(): number {
    let v: number = ToolRegistry.parseTerm();
    while (true) {
      ToolRegistry.skipSpace();
      if (ToolRegistry.peek() === '+') {
        ToolRegistry.calcPos += 1;
        v = v + ToolRegistry.parseTerm();
      } else if (ToolRegistry.peek() === '-') {
        ToolRegistry.calcPos += 1;
        v = v - ToolRegistry.parseTerm();
      } else {
        break;
      }
    }
    return v;
  }

  private static parseTerm(): number {
    let v: number = ToolRegistry.parseFactor();
    while (true) {
      ToolRegistry.skipSpace();
      if (ToolRegistry.peek() === '*') {
        ToolRegistry.calcPos += 1;
        v = v * ToolRegistry.parseFactor();
      } else if (ToolRegistry.peek() === '/') {
        ToolRegistry.calcPos += 1;
        const d: number = ToolRegistry.parseFactor();
        if (d === 0) throw new Error('DIV_BY_ZERO');
        v = v / d;
      } else {
        break;
      }
    }
    return v;
  }

  private static parseFactor(): number {
    ToolRegistry.skipSpace();
    if (ToolRegistry.peek() === '-') {
      ToolRegistry.calcPos += 1;
      return -ToolRegistry.parseFactor();
    }
    if (ToolRegistry.peek() === '(') {
      ToolRegistry.calcPos += 1;
      const v: number = ToolRegistry.parseExpr();
      ToolRegistry.skipSpace();
      if (ToolRegistry.peek() === ')') {
        ToolRegistry.calcPos += 1;
      }
      return v;
    }
    return ToolRegistry.parseNumber();
  }

  private static parseNumber(): number {
    ToolRegistry.skipSpace();
    const start: number = ToolRegistry.calcPos;
    while (ToolRegistry.calcPos < ToolRegistry.calcSrc.length) {
      const ch: string = ToolRegistry.calcSrc.charAt(ToolRegistry.calcPos);
      if ((ch >= '0' && ch <= '9') || ch === '.') {
        ToolRegistry.calcPos += 1;
      } else {
        break;
      }
    }
    if (start === ToolRegistry.calcPos) throw new Error('NO_NUMBER');
    return Number(ToolRegistry.calcSrc.substring(start, ToolRegistry.calcPos));
  }

  private static peek(): string {
    if (ToolRegistry.calcPos >= ToolRegistry.calcSrc.length) return '';
    return ToolRegistry.calcSrc.charAt(ToolRegistry.calcPos);
  }

  private static skipSpace(): void {
    while (ToolRegistry.calcPos < ToolRegistry.calcSrc.length &&
      ToolRegistry.calcSrc.charAt(ToolRegistry.calcPos) === ' ') {
      ToolRegistry.calcPos += 1;
    }
  }

  private static nowText(): string {
    const d: Date = new Date();
    const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' +
      pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }

  private static async runSearch(argsJson: string): Promise<ToolResult> {
    try {
      const args: Record<string, Object> = JSON.parse(argsJson) as Record<string, Object>;
      const query: string = typeof args['query'] === 'string' ? args['query'] as string : '';
      if (query.trim().length === 0) return new ToolResult('', false, '', '搜索关键词为空');
      const baseUrl: string = await DataRepository.getSetting('webSearchBaseUrl',
        'https://api.duckduckgo.com/?q={q}&format=json&no_html=1');
      const apiKey: string = await DataRepository.getSetting('webSearchApiKey', '');
      const results: WebSearchResult[] = await WebSearchService.search(query, baseUrl, apiKey);
      if (results.length === 0) return new ToolResult('', false, '', '未获取到搜索结果');
      const lines: string[] = [];
      const n: number = Math.min(5, results.length);
      for (let i: number = 0; i < n; i++) {
        const r: WebSearchResult = results[i];
        lines.push((i + 1).toString() + '. ' + r.title + '\n' + r.url + '\n' + r.snippet);
      }
      return new ToolResult('', true, lines.join('\n\n'), '');
    } catch (e) {
      return new ToolResult('', false, '', '联网搜索失败');
    }
  }
}

// 智子 - 热榜 AI 能力服务（摘要 / 翻译 / 问AI / 今日要闻 / 热点速递 / 搜索汇总）
// 全部手动触发；复用 LlmClient 流式/非流式能力与 AiCallLogger 调用记录
// 设计文档：doc/newsnow-redesign.md §7
import { ChatRepository } from '../chat/ChatRepository';
import { LlmClient } from '../chat/LlmClient';
import { LlmConfig, LlmModelEntry, ChatMessage, LlmResult, entryToConfig } from '../../common/LlmModels';
import { AiCallContext } from '../platform/AiCallLogger';
import { DataRepository } from '../platform/DataRepository';
import { WebSearchService, WebSearchResult } from '../chat/WebSearchService';
import { HotEntry } from '../../common/HotModels';

// 文章正文入上下文的字符上限（约 2000~3000 token）
const ARTICLE_CONTEXT_MAX: number = 8000;

export class NewsAiService {
  // ==================== 热榜功能专属模型（可切换并记忆） ====================

  // 当前功能使用的模型：优先 settings.hotModelId 记忆的模型（需 enabled 且已配置），否则回退全局活跃模型
  static async getActiveConfig(): Promise<LlmConfig | null> {
    const rememberedId: string = await DataRepository.getSetting('hotModelId', '');
    if (rememberedId.trim().length > 0) {
      const models: LlmModelEntry[] = await ChatRepository.loadModels();
      for (let i: number = 0; i < models.length; i++) {
        const m: LlmModelEntry = models[i];
        if (m.id === rememberedId && m.enabled && m.configured) {
          return entryToConfig(m);
        }
      }
    }
    return await ChatRepository.loadActiveConfig();
  }

  // 可选模型列表（启用且已配置）
  static async listModels(): Promise<LlmModelEntry[]> {
    const models: LlmModelEntry[] = await ChatRepository.loadModels();
    const usable: LlmModelEntry[] = [];
    for (let i: number = 0; i < models.length; i++) {
      if (models[i].enabled && models[i].configured) {
        usable.push(models[i]);
      }
    }
    return usable;
  }

  static async selectModel(id: string): Promise<void> {
    await DataRepository.setSetting('hotModelId', id);
  }

  // 当前模型显示名（供选择器展示）
  static async getActiveModelName(): Promise<string> {
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) return '未配置模型';
    return config.displayName.trim().length > 0 ? config.displayName : config.model;
  }

  // 是否已配置可用模型
  static async hasModel(): Promise<boolean> {
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) return false;
    return config.baseUrl.trim().length > 0 && config.model.trim().length > 0;
  }

  // ==================== 翻译模型（单独记忆） ====================

  static async getTranslateConfig(): Promise<LlmConfig | null> {
    const rememberedId: string = await DataRepository.getSetting('hotTranslateModelId', '');
    if (rememberedId.trim().length > 0) {
      const models: LlmModelEntry[] = await ChatRepository.loadModels();
      for (let i: number = 0; i < models.length; i++) {
        const m: LlmModelEntry = models[i];
        if (m.id === rememberedId && m.enabled && m.configured) {
          return entryToConfig(m);
        }
      }
    }
    return await NewsAiService.getActiveConfig();
  }

  // 选择并记忆翻译模型（空 = 跟随主模型）
  static async selectTranslateModel(id: string): Promise<void> {
    await DataRepository.setSetting('hotTranslateModelId', id);
  }

  // ==================== 上下文构造 ====================

  // 调用日志场景（写入 ai_call_logs.game 字段：news:summary / news:translate / news:qa / news:digest …）
  private static newsContext(scene: string): AiCallContext {
    return new AiCallContext('chat', 'news:' + scene);
  }

  static truncate(text: string, maxChars: number = ARTICLE_CONTEXT_MAX): string {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars) + '\n…（内容过长已截断）';
  }

  // 文章上下文：标题 + 正文（热榜无语义摘要，正文来自详情页抽取）
  static articleContext(title: string, bodyText: string = ''): string {
    let ctx: string = '文章标题：' + title;
    if (bodyText.trim().length > 0) {
      ctx = ctx + '\n文章正文：' + bodyText.trim();
    }
    return NewsAiService.truncate(ctx);
  }

  // 榜单条目 → prompt 列表行（标题 + 来源 + 热度描述）
  private static entriesToLines(items: HotEntry[], max: number): string {
    let list: string = '';
    const count: number = items.length > max ? max : items.length;
    for (let i: number = 0; i < count; i++) {
      const info: string = items[i].item.info.trim();
      list = list + (i + 1).toString() + '. [' + items[i].sourceName + '] ' + items[i].item.title +
        (info.length > 0 ? '（' + info + '）' : '') + '\n';
    }
    return list;
  }

  // ==================== AI 摘要（流式，手动触发） ====================
  static async summarize(config: LlmConfig, title: string, bodyText: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const system: string = '你是一位资深新闻编辑。请用简洁的中文为以下文章生成摘要：先一句话概括核心，再列出 3~5 个要点（每条一行，用 - 开头）。只输出摘要本身。';
    const user: string = NewsAiService.articleContext(title, bodyText) + '\n\n请生成摘要。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('summary'));
  }

  // ==================== AI 翻译（流式，手动触发） ====================
  static async translate(config: LlmConfig, title: string, bodyText: string, targetZh: boolean,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const direction: string = targetZh ? '把以下新闻翻译成简体中文' : '把以下新闻翻译成英文';
    const system: string = '你是一位专业新闻翻译。' + direction + '。保持术语准确、表达自然，只输出译文。';
    const user: string = NewsAiService.articleContext(title, bodyText) + '\n\n请翻译。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('translate'));
  }

  // 标题速译（非流式，手动触发）
  static async translateTitle(config: LlmConfig, title: string): Promise<LlmResult> {
    const system: string = '你是一位专业新闻翻译。把以下新闻标题翻译成简体中文，保持术语准确、表达自然，只输出译文。';
    const user: string = '标题：' + title + '\n\n请翻译成简体中文。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletion(config, messages, NewsAiService.newsContext('translate'));
  }

  // ==================== 文章追问（流式，可多轮） ====================
  static async ask(config: LlmConfig, title: string, bodyText: string, history: ChatMessage[],
    question: string, onDelta: (delta: string) => void): Promise<LlmResult> {
    const system: string = '你是一位博学的新闻解读助手。以下文章是背景资料，请基于文章内容回答用户问题；文章未提及的内容请明确说明，并补充必要的常识背景。回答用中文，简洁有条理。\n\n' +
      NewsAiService.articleContext(title, bodyText);
    const messages: ChatMessage[] = [ChatMessage.create('system', system)];
    for (let i: number = 0; i < history.length; i++) {
      messages.push(history[i]);
    }
    messages.push(ChatMessage.create('user', question));
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('qa'));
  }

  // ==================== AI 搜索结果汇总（流式） ====================
  static async generateSearchSummary(config: LlmConfig, items: HotEntry[], keyword: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const list: string = NewsAiService.entriesToLines(items, 20);
    const system: string = '你是一位新闻分析助手。请基于搜索结果，围绕关键词输出结构化摘要，只使用给定信息，不编造。';
    const user: string = '搜索关键词：' + keyword + '\n搜索结果：\n' + list + '\n\n请输出：\n' +
      '1. 一句话概述该主题当前动态；\n' +
      '2. 按 3~5 条要点梳理（每条 - 开头，含来源）；\n' +
      '3. 若结果与关键词相关性弱，请说明。\n使用 Markdown。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('search'));
  }

  // ==================== AI 热点速递（按早/午/晚时段） ====================
  static async generateHotspot(config: LlmConfig, items: HotEntry[], dateLabel: string,
    period: string, onDelta: (delta: string) => void): Promise<LlmResult> {
    const list: string = NewsAiService.entriesToLines(items, 60);
    // 可选：联网搜索补充热点信息（「设置 → AI对话 → 联网搜索」配置了接口时生效）
    let webExtra: string = '';
    try {
      const searchBase: string = await DataRepository.getSetting('webSearchBaseUrl', '');
      if (searchBase.trim().length > 0) {
        const searchKey: string = await DataRepository.getSetting('webSearchApiKey', '');
        const results: WebSearchResult[] =
          await WebSearchService.search('今日热点新闻 国际 国内 科技 财经', searchBase, searchKey);
        if (results.length > 0) {
          let block: string = '';
          const wCount: number = results.length > 12 ? 12 : results.length;
          for (let i: number = 0; i < wCount; i++) {
            block = block + '- ' + results[i].title +
              (results[i].snippet.trim().length > 0 ? '：' + results[i].snippet.trim() : '') + '\n';
          }
          webExtra = '\n\n【联网搜索补充信息（可参考，注意甄别时效性）】\n' + block;
        }
      }
    } catch (e) {
    }
    const system: string = '你是一位资深新闻主编。请基于用户提供的当天热榜标题，梳理一份详实的「热点速递」。' +
      '要求：只基于给定信息组织内容，不要编造具体细节、数字或人名；信息不足时写明「据现有信息」。';
    const periodTitle: string = period === 'morning' ? '早报速递' : (period === 'evening' ? '晚报速递' : '午间速递');
    const periodDesc: string = period === 'morning' ? '梳理今晨重要资讯' :
      (period === 'evening' ? '复盘全天重要动态' : '汇总当天最新进展');
    const user: string = '今天是' + dateLabel + '。以下是各平台热榜条目（含来源）：\n' + list + '\n\n' +
      '请输出「' + periodTitle + '」（' + periodDesc + '），格式如下（严格按此结构）：\n' +
      '顶部一行：🌤️ ' + periodTitle + ' · ' + dateLabel + '\n' +
      '---\n' +
      '## 🌍 国际要闻\n每条：**① 标题** + 3~4 句详细描述（事件本身、背景、各方反应与影响，编号 ①②…）\n' +
      '## 🇨🇳 国内热点\n同上\n' +
      '## 💡 财经科技\n同上\n' +
      '## 📌 今日看点\n结尾一段话总结当日核心焦点（3~4 句）\n' +
      '分类中没有合适内容的可省略该分类。使用 Markdown 输出，每条新闻尽量给足信息量。' + webExtra;
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('hotspot'));
  }

  // ==================== AI 今日要闻（跨源汇总，流式） ====================
  static async generateDigest(config: LlmConfig, items: HotEntry[], dateLabel: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const list: string = NewsAiService.entriesToLines(items, 50);
    const system: string = '你是一位资深新闻主编。请基于给定热榜条目，生成一份详实的「今日要闻」简报。' +
      '只基于给定信息展开，不要编造具体数字、人名或细节；信息不足时写明「据现有信息」。';
    const user: string = '今天是' + dateLabel + '。以下是各平台热榜条目（含来源与热度）：\n' + list + '\n\n请输出：\n' +
      '1. 开头用 2~3 句话总结当天热点趋势；\n' +
      '2. 选出 8~10 条最重要的新闻，每条格式：【分类】标题（来源）—— 2~3 句详细描述（事件本身、背景、影响）；\n' +
      '3. 结尾给出 1~2 句阅读建议。\n使用 Markdown，适当详细但不要冗长。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('digest'));
  }
}

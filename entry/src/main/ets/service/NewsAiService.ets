// 智子 - 新闻 AI 能力服务（摘要 / 翻译 / 问AI / 今日要闻 / 推荐）
// 全部手动触发；复用 LlmClient 流式/非流式能力与 AiCallLogger 调用记录
import { ChatRepository } from './ChatRepository';
import { LlmClient } from './LlmClient';
import { LlmConfig, LlmModelEntry, ChatMessage, LlmResult, entryToConfig } from '../common/LlmModels';
import { AiCallContext } from './AiCallLogger';
import { DataRepository } from './DataRepository';
import { NewsItem } from '../common/NewsModels';

// 文章正文入上下文的字符上限（约 2000~3000 token）
const ARTICLE_CONTEXT_MAX: number = 8000;

export class NewsAiService {
  // ==================== 资讯功能专属模型（可切换并记忆） ====================

  // 当前资讯功能使用的模型配置：
  // 优先 settings.newsModelId 记忆的模型（需 enabled 且已配置），否则回退全局活跃模型
  static async getActiveConfig(): Promise<LlmConfig | null> {
    const rememberedId: string = await DataRepository.getSetting('newsModelId', '');
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

  // 资讯功能可选模型列表（启用且已配置）
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

  // 记忆资讯功能使用的模型
  static async selectModel(id: string): Promise<void> {
    await DataRepository.setSetting('newsModelId', id);
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

  // 调用日志场景（写入 ai_call_logs.game 字段：news:summary / news:translate / news:qa / news:digest / news:recommend）
  private static newsContext(scene: string): AiCallContext {
    return new AiCallContext('chat', 'news:' + scene);
  }

  // 截断长文本
  static truncate(text: string, maxChars: number = ARTICLE_CONTEXT_MAX): string {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars) + '\n…（内容过长已截断）';
  }

  // 文章上下文：标题 + 摘要 + 正文
  static articleContext(article: NewsItem, bodyText: string = ''): string {
    let ctx: string = '文章标题：' + article.title;
    if (article.summary.trim().length > 0) {
      ctx = ctx + '\n文章摘要：' + article.summary.trim();
    }
    if (bodyText.trim().length > 0) {
      ctx = ctx + '\n文章正文：' + bodyText.trim();
    }
    return NewsAiService.truncate(ctx);
  }

  // ==================== AI 摘要（流式，手动触发） ====================
  static async summarize(config: LlmConfig, article: NewsItem, bodyText: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const system: string = '你是一位资深新闻编辑。请用简洁的中文为以下文章生成摘要：先一句话概括核心，再列出 3~5 个要点（每条一行，用 - 开头）。只输出摘要本身。';
    const user: string = NewsAiService.articleContext(article, bodyText) + '\n\n请生成摘要。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('summary'));
  }

  // ==================== AI 翻译（流式，手动触发） ====================
  static async translate(config: LlmConfig, article: NewsItem, bodyText: string, targetZh: boolean,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    const direction: string = targetZh ? '把以下新闻翻译成简体中文' : '把以下新闻翻译成英文';
    const system: string = '你是一位专业新闻翻译。' + direction + '。保持术语准确、表达自然，只输出译文。';
    const user: string = NewsAiService.articleContext(article, bodyText) + '\n\n请翻译。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('translate'));
  }

  // ==================== 文章追问（流式，可多轮） ====================
  static async ask(config: LlmConfig, article: NewsItem, bodyText: string, history: ChatMessage[],
    question: string, onDelta: (delta: string) => void): Promise<LlmResult> {
    const system: string = '你是一位博学的新闻解读助手。以下文章是背景资料，请基于文章内容回答用户问题；文章未提及的内容请明确说明，并补充必要的常识背景。回答用中文，简洁有条理。\n\n' +
      NewsAiService.articleContext(article, bodyText);
    const messages: ChatMessage[] = [ChatMessage.create('system', system)];
    for (let i: number = 0; i < history.length; i++) {
      messages.push(history[i]);
    }
    messages.push(ChatMessage.create('user', question));
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('qa'));
  }

  // ==================== AI 热点速递（流式生成分类热点梳理） ====================
  // 输出风格：🌍国际要闻 / 🇨🇳国内热点 / 💡财经科技 / 📌今日看点，每条含标题 + 2~3 句描述
  static async generateHotspot(config: LlmConfig, items: NewsItem[], dateLabel: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    let list: string = '';
    const count: number = items.length > 60 ? 60 : items.length;
    for (let i: number = 0; i < count; i++) {
      const s: string = items[i].summary.length > 0 ?
        (items[i].title + '（' + items[i].sourceName + '）' + items[i].summary.trim().substring(0, 150)) :
        (items[i].title + '（' + items[i].sourceName + '）');
      list = list + (i + 1).toString() + '. ' + s + '\n';
    }
    const system: string = '你是一位资深新闻主编。请基于用户提供的当天新闻标题与摘要，梳理一份详实的「热点速递」。' +
      '要求：只基于给定信息组织内容，不要编造具体细节、数字或人名；信息不足时写明「据现有信息」。';
    const user: string = '今天是' + dateLabel + '。以下是聚合的当天新闻（含来源）：\n' + list + '\n\n' +
      '请输出「热点速递」，格式如下（严格按此结构）：\n' +
      '顶部一行：🌤️ 时段速递 · ' + dateLabel + '\n' +
      '---\n' +
      '## 🌍 国际要闻\n每条：**① 标题** + 3~4 句详细描述（事件本身、背景、各方反应与影响，编号 ①②…）\n' +
      '## 🇨🇳 国内热点\n同上\n' +
      '## 💡 财经科技\n同上\n' +
      '## 📌 今日看点\n结尾一段话总结当日核心焦点（3~4 句）\n' +
      '分类中没有合适内容的可省略该分类。使用 Markdown 输出，每条新闻尽量给足信息量。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('hotspot'));
  }

  // ==================== AI 今日要闻（流式生成简报） ====================
  static async generateDigest(config: LlmConfig, items: NewsItem[], dateLabel: string,
    onDelta: (delta: string) => void): Promise<LlmResult> {
    let list: string = '';
    const count: number = items.length > 50 ? 50 : items.length;
    for (let i: number = 0; i < count; i++) {
      const s: string = items[i].summary.length > 0 ?
        items[i].summary.trim().substring(0, 120) : '';
      list = list + (i + 1).toString() + '. [' + items[i].sourceName + '] ' + items[i].title +
        (s.length > 0 ? ' —— ' + s : '') + '\n';
    }
    const system: string = '你是一位资深新闻主编。请基于给定新闻标题与摘要，生成一份详实的「今日要闻」简报。' +
      '只基于给定信息展开，不要编造具体数字、人名或细节；信息不足时写明「据现有信息」。';
    const user: string = '今天是' + dateLabel + '。以下是聚合的新闻（含来源与摘要）：\n' + list + '\n\n请输出：\n' +
      '1. 开头用 2~3 句话总结当天热点趋势；\n' +
      '2. 选出 8~10 条最重要的新闻，每条格式：【分类】标题（来源）—— 2~3 句详细描述（事件本身、背景、影响）；\n' +
      '3. 结尾给出 1~2 句阅读建议。\n使用 Markdown，适当详细但不要冗长。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('digest'));
  }

  // ==================== 为你推荐（基于阅读/收藏历史） ====================
  static async recommend(config: LlmConfig, candidates: NewsItem[], historyTitles: string[],
    onDelta: (delta: string) => void): Promise<LlmResult> {
    let hist: string = historyTitles.length === 0 ? '（暂无阅读历史，请先阅读或收藏几篇文章）' : '';
    const hCount: number = historyTitles.length > 20 ? 20 : historyTitles.length;
    for (let i: number = 0; i < hCount; i++) {
      hist = hist + '- ' + historyTitles[i] + '\n';
    }
    let list: string = '';
    const count: number = candidates.length > 30 ? 30 : candidates.length;
    for (let i: number = 0; i < count; i++) {
      list = list + (i + 1).toString() + '. [' + candidates[i].sourceName + '] ' + candidates[i].title + '\n';
    }
    const system: string = '你是一位个性化新闻推荐引擎。请根据用户阅读历史，从候选新闻中挑选最相关的 8 条并说明理由。';
    const user: string = '我的阅读/收藏历史：\n' + hist + '\n候选新闻：\n' + list +
      '\n\n请输出推荐列表，格式：1. 标题（来源）—— 推荐理由（一句话）。只推荐候选列表中的新闻。';
    const messages: ChatMessage[] = [ChatMessage.create('system', system), ChatMessage.create('user', user)];
    return await LlmClient.postCompletionStream(config, messages, onDelta, undefined,
      NewsAiService.newsContext('recommend'));
  }
}

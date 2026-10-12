// 智子 - 热榜条目详情页（v10 华为原生拟物白）
// 顶栏：‹ 返回 + 标题（2 行截断）+ ⭐ 收藏 + 分享 + ⋯（离线缓存 / 字号 / 浏览器打开 / 复制链接）
// 正文：白卡 ArkWeb；底部 AI 工具条（摘要/翻译/问AI/朗读）；AI 面板用底部半模态卡承载
// 设计文档：doc/v10-redesign.md §4.3；数据流沿用 doc/newsnow-redesign.md §9.3
import { webview } from '@kit.ArkWeb';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { AiModelPicker } from '../components/AiModelPicker';
import { HotEntry, HotItem, HotDetailRouteParams } from '../common/HotModels';
import { NewsRepository } from '../service/hot/NewsRepository';
import { HotArticleCacheEntry } from '../service/platform/DatabaseHelper';
import { NewsAiService } from '../service/hot/NewsAiService';
import { SpeechService } from '../service/chat/SpeechService';
import { LlmConfig, LlmModelEntry, ChatMessage, LlmResult } from '../common/LlmModels';

enum AiPanelKind {
  NONE = 0,
  SUMMARY = 1,
  TRANSLATE = 2,
  ASK = 3
}

// 正文缓存 HTML → 纯文本（离线/抽取失败时作为 AI 上下文兜底）
function htmlToText(html: string): string {
  const stripped: string = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ');
  return stripped.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
}

@ComponentV2
@Entry
export struct NewsDetailPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 路由参数（HotDetailRouteParams 序列化纯数据）
  @Local itemKey: string = '';
  @Local sourceId: string = '';
  @Local sourceName: string = '';
  @Local title: string = '';
  @Local url: string = '';
  @Local info: string = '';
  @Local favorited: boolean = false;
  @Local webFailed: boolean = false;
  @Local offlineMode: boolean = false;
  // AI 面板状态
  @Local aiPanel: AiPanelKind = AiPanelKind.NONE;
  @Local aiText: string = '';
  @Local aiBusy: boolean = false;
  @Local aiError: string = '';
  @Local askInput: string = '';
  // 问AI 历史（只保留最近 4 轮）
  @Local askHistory: ChatMessage[] = [];
  // 正文纯文本（ArkWeb JS 抽取，供 AI 摘要/翻译/问答）
  @Local bodyText: string = '';
  // 朗读状态
  @Local speaking: boolean = false;
  // 阅读缩放
  @Local zoomFactor: number = 1.0;
  // 最近一次 AI 调用 token 消耗
  @Local lastTokens: number = 0;
  // 模型选择（热榜专属模型，跟随全局时为空）
  @Local modelName: string = '跟随全局';
  @Local models: LlmModelEntry[] = [];
  @Local modelSheet: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: HotDetailRouteParams | null =
      AppNavigator.getParam('pages/NewsDetail') as HotDetailRouteParams | null;
    // 注意：router 参数为序列化纯数据对象，类方法不可用，需直接读字段
    if (params !== null) {
      this.itemKey = params.key;
      this.sourceId = params.sourceId;
      this.sourceName = params.sourceName;
      this.title = params.title;
      this.url = params.url;
      this.info = params.info;
    }
    this.loadState();
    this.loadModelName();
  }

  aboutToDisappear(): void {
    SpeechService.stopSpeaking();
  }

  private async loadState(): Promise<void> {
    if (this.itemKey.length === 0) return;
    try {
      this.favorited = await NewsRepository.isFavorite(this.itemKey);
      await NewsRepository.markRead(this.itemKey);
    } catch (e) {
    }
  }

  private async loadModelName(): Promise<void> {
    try {
      this.modelName = await NewsAiService.getActiveModelName();
    } catch (e) {
      this.modelName = '未配置模型';
    }
  }

  // 路由参数 → 收藏用条目（key = `sourceId:itemId`）
  private entryOf(): HotEntry {
    const idx: number = this.itemKey.indexOf(':');
    const itemId: string = idx < 0 ? this.itemKey : this.itemKey.substring(idx + 1);
    const item: HotItem = new HotItem(itemId, this.title, this.url, this.url, 0, this.info);
    return new HotEntry(this.itemKey, item, this.sourceId, this.sourceName);
  }

  private async toggleFavorite(): Promise<void> {
    if (this.itemKey.length === 0) {
      promptAction.showToast({ message: '该条目暂不支持收藏' });
      return;
    }
    try {
      const fav: boolean = await NewsRepository.toggleFavorite(this.entryOf());
      this.favorited = fav;
      promptAction.showToast({ message: fav ? '已收藏' : '已取消收藏' });
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试' });
    }
  }

  // ==================== Web 正文 ====================

  // 阅读字号缩放（ArkWeb zoom）
  private adjustZoom(delta: number): void {
    let next: number = this.zoomFactor + delta;
    if (next < 0.6) next = 0.6;
    if (next > 1.8) next = 1.8;
    this.zoomFactor = next;
    try {
      this.controller.zoom(this.zoomFactor);
    } catch (e) {
    }
  }

  // 深色模式：向原文注入反色 CSS（底色取 token，避免与全局色板错位）
  private injectDarkCss(): void {
    if (!this.themeState.isDark) return;
    const css: string = 'html{filter:invert(0.9) hue-rotate(180deg)!important;background:' +
      this.themeState.palette.bgBase + '}img,video{filter:invert(1) hue-rotate(180deg)!important}';
    const script: string = '(function(){var s=document.createElement("style");s.id="zhizon-dark";s.textContent="' + css + '";document.head.appendChild(s);})()';
    try {
      this.controller.runJavaScript(script, (err: BusinessError, result: string): void => {
      });
    } catch (e) {
    }
  }

  // 抽取正文纯文本（供 AI 摘要/翻译/问答；热榜无摘要字段）
  private extractBodyText(): void {
    try {
      this.controller.runJavaScript('document.body ? document.body.innerText : ""',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) return;
          const text: string = result === undefined ? '' : result;
          const trimmed: string = text.trim();
          if (trimmed.length > 0) {
            this.bodyText = NewsAiService.truncate(trimmed);
          }
        });
    } catch (e) {
    }
  }

  // AI 上下文正文：优先网页抽取，其次离线缓存抽取，最后用热度描述兜底
  private aiBody(): string {
    const text: string = this.bodyText.trim();
    if (text.length > 0) return NewsAiService.truncate(text);
    return this.info;
  }

  // ==================== AI 能力 ====================

  private panelTitle(): string {
    if (this.aiPanel === AiPanelKind.SUMMARY) return 'AI 摘要';
    if (this.aiPanel === AiPanelKind.TRANSLATE) return 'AI 翻译';
    if (this.aiPanel === AiPanelKind.ASK) return '问 AI';
    return '';
  }

  private closePanel(): void {
    this.aiPanel = AiPanelKind.NONE;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = false;
  }

  // 开始一次 AI 调用（摘要/翻译）
  private async runAi(panel: AiPanelKind,
    builder: (config: LlmConfig, onDelta: (d: string) => void) => Promise<LlmResult>): Promise<void> {
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = panel;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = true;
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    const result: LlmResult = await builder(config, (d: string): void => {
      this.aiText = this.aiText + d;
    });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    }
    if (!result.success) {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    }
  }

  private onSummary(): void {
    this.runAi(AiPanelKind.SUMMARY, (config: LlmConfig, onDelta: (d: string) => void): Promise<LlmResult> => {
      return NewsAiService.summarize(config, this.title, this.aiBody(), onDelta);
    });
  }

  // 外文/中文正文统一翻译成简体中文（翻译模型可单独记忆）
  private async onTranslate(): Promise<void> {
    const config: LlmConfig | null = await NewsAiService.getTranslateConfig();
    if (config === null) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = AiPanelKind.TRANSLATE;
    this.aiText = '';
    this.aiError = '';
    this.aiBusy = true;
    const result: LlmResult = await NewsAiService.translate(config, this.title, this.aiBody(), true,
      (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    } else {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : '翻译失败，请重试';
    }
  }

  private async onAskSend(): Promise<void> {
    const q: string = this.askInput.trim();
    if (q.length === 0 || this.aiBusy) return;
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.aiPanel = AiPanelKind.ASK;
    this.aiError = '';
    this.aiText = '';
    this.aiBusy = true;
    this.askHistory = this.askHistory.concat([ChatMessage.create('user', q)]);
    this.askInput = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.aiBusy = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    const result: LlmResult = await NewsAiService.ask(config, this.title, this.aiBody(),
      this.askHistory, q, (d: string): void => {
        this.aiText = this.aiText + d;
      });
    this.aiBusy = false;
    if (result.success) {
      this.lastTokens = result.tokenUsage.totalTokens;
    }
    if (!result.success) {
      this.aiError = result.errorMessage.length > 0 ? result.errorMessage : 'AI 调用失败，请重试';
    } else {
      // 保留最近 4 轮问答
      this.askHistory = this.askHistory.concat([ChatMessage.create('assistant', result.content)]);
      if (this.askHistory.length > 8) {
        this.askHistory = this.askHistory.slice(this.askHistory.length - 8);
      }
    }
  }

  // ==================== 模型选择 ====================

  private modelLabel(m: LlmModelEntry): string {
    return m.displayName.length > 0 ? m.displayName : m.model;
  }

  // 是否使用热榜专属模型（跟随全局时为 false）
  private modelActive(): boolean {
    return this.modelName.length > 0 && this.modelName !== '跟随全局' && this.modelName !== '未配置模型';
  }

  private isCurrentModel(m: LlmModelEntry): boolean {
    return this.modelLabel(m) === this.modelName;
  }

  // 当前生效模型的 id（供共享模型选择器高亮；跟随全局时为空串）
  private currentModelId(): string {
    for (let i: number = 0; i < this.models.length; i++) {
      if (this.isCurrentModel(this.models[i])) return this.models[i].id;
    }
    return '';
  }

  private async openModelSheet(): Promise<void> {
    try {
      this.models = await NewsAiService.listModels();
    } catch (e) {
      this.models = [];
    }
    this.modelSheet = true;
  }

  // id 为空字符串 = 恢复「跟随全局」
  private async pickModel(id: string): Promise<void> {
    try {
      await NewsAiService.selectModel(id);
    } catch (e) {
    }
    this.modelSheet = false;
    await this.loadModelName();
    promptAction.showToast({ message: '当前模型：' + this.modelName });
  }

  // ==================== 离线正文缓存 ====================

  // 页面加载完成：抓取当前页面 HTML 存入缓存（供离线/弱网时回退阅读）
  private cacheArticleHtml(): void {
    this.requestArticleHtml(false);
  }

  private requestArticleHtml(notify: boolean): void {
    if (this.url.length === 0) return;
    try {
      this.controller.runJavaScript('document.documentElement.outerHTML',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) {
            if (notify) promptAction.showToast({ message: '缓存失败，请重试' });
            return;
          }
          const html: string = result === undefined ? '' : result;
          // 空页/过小页面不缓存；过大页面截断，避免数据库膨胀
          if (html.length < 500 || html.length > 800 * 1024) {
            if (notify) promptAction.showToast({ message: '本页暂不支持离线缓存' });
            return;
          }
          NewsRepository.saveArticleCache(this.url, this.title, html).then(() => {
            if (notify) promptAction.showToast({ message: '已缓存离线正文' });
          }).catch(() => {
            if (notify) promptAction.showToast({ message: '缓存失败，请重试' });
          });
        });
    } catch (e) {
      if (notify) promptAction.showToast({ message: '缓存失败，请重试' });
    }
  }

  // 加载失败：尝试用缓存 HTML 回退（离线阅读）；notify=true 时（用户主动选「离线缓存」）给出反馈
  private useCachedArticle(notify: boolean = false): void {
    if (this.url.length === 0) {
      this.webFailed = true;
      return;
    }
    NewsRepository.getArticleCache(this.url).then((cached: HotArticleCacheEntry | null) => {
      if (cached !== null && cached.html.length > 0) {
        try {
          this.offlineMode = true;
          if (this.bodyText.trim().length === 0) {
            const text: string = htmlToText(cached.html);
            if (text.length > 0) this.bodyText = NewsAiService.truncate(text);
          }
          this.controller.loadData(cached.html, 'text/html', 'UTF-8', this.url);
          if (notify) promptAction.showToast({ message: '已切换离线正文' });
        } catch (e) {
          this.webFailed = true;
          if (notify) promptAction.showToast({ message: '离线正文打开失败' });
        }
      } else {
        this.webFailed = true;
        if (notify) promptAction.showToast({ message: '暂无离线正文' });
      }
    }).catch(() => {
      this.webFailed = true;
      if (notify) promptAction.showToast({ message: '暂无离线正文' });
    });
  }

  // ⋯ 菜单：离线缓存（有缓存则切离线，无缓存则抓取当前页）
  private async onOfflineCache(): Promise<void> {
    if (this.url.length === 0) {
      promptAction.showToast({ message: '该条目没有原文链接' });
      return;
    }
    if (this.offlineMode) {
      promptAction.showToast({ message: '当前已是离线正文' });
      return;
    }
    const cached: HotArticleCacheEntry | null = await NewsRepository.getArticleCache(this.url);
    if (cached !== null && cached.html.length > 0 && !this.webFailed) {
      this.useCachedArticle(true);
      return;
    }
    if (this.webFailed) {
      // Web 未挂载：重新挂载（在线成功则读原文，失败会自动回退缓存）
      this.webFailed = false;
      promptAction.showToast({ message: cached !== null ? '正在打开离线正文…' : '暂无离线正文' });
      return;
    }
    this.requestArticleHtml(true);
  }

  // 原文加载失败后的重试（重新挂载 ArkWeb）
  private retryLoad(): void {
    this.webFailed = false;
    this.offlineMode = false;
  }

  // ==================== 分享 / 朗读 / 复制 ====================

  private shareNews(): void {
    const text: string = '【' + this.sourceName + '】' + this.title + '\n' +
      (this.info.length > 0 ? this.info + '\n' : '') +
      '原文：' + this.url + '\n—— 来自 智子 热榜';
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: text
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const options: systemShare.ShareControllerOptions = {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      };
      controller.show(context, options).catch((e: Object) => {
      });
    } catch (e) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  // 用系统浏览器打开原文
  private openInBrowser(): void {
    if (this.url.length === 0) {
      promptAction.showToast({ message: '该条目没有原文链接' });
      return;
    }
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      context.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: this.url
      }).catch((e: Object) => {
        promptAction.showToast({ message: '无法打开链接' });
      });
    } catch (e) {
      promptAction.showToast({ message: '无法打开链接' });
    }
  }

  private copyLink(): void {
    if (this.url.length === 0) {
      promptAction.showToast({ message: '该条目没有原文链接' });
      return;
    }
    this.copyText(this.url, '已复制链接');
  }

  // 朗读标题 + 正文（复用 SpeechService TTS）
  private async toggleSpeak(): Promise<void> {
    if (this.speaking) {
      SpeechService.stopSpeaking();
      this.speaking = false;
      return;
    }
    let text: string = this.title;
    const body: string = this.aiBody().trim();
    if (body.length > 0) {
      text = text + '。' + body;
    }
    this.speaking = true;
    await SpeechService.speak(text, {
      onComplete: (): void => {
        this.speaking = false;
      },
      onError: (code: number, message: string): void => {
        this.speaking = false;
      }
    });
  }

  private async copyText(text: string, okMessage: string): Promise<void> {
    if (text.length === 0) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: okMessage });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  private async copyAiText(): Promise<void> {
    await this.copyText(this.aiText, '已复制');
  }

  // ==================== 顶栏 ====================

  // 页边距：手机 pagePadding(16vp) / 大屏 pagePaddingLg(24vp)
  private pagePad(): string {
    return this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg;
  }

  // 顶栏图标动作：≥44vp 触控区（icon/emoji 为固定入参；状态在各自 builder 内读取，避免按值传参不刷新）
  @Builder
  barIcon(icon: Resource, emoji: string, label: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(18)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(label)
    .onClick(onTap)
  }

  // 收藏：已收藏用主色实心星（在 builder 内直接读状态，保证选中态刷新）
  @Builder
  starButton() {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(this.favorited ? AppIcons.starFill : AppIcons.star)
          .fontSize(22)
          .fontColor([this.favorited ? this.themeState.palette.primary : this.themeState.palette.textSecondary])
      } else {
        Text(this.favorited ? AppIcons.starFillEmoji : AppIcons.starEmoji)
          .fontSize(18)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.favorited ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(this.favorited ? '取消收藏' : '收藏')
    .onClick(() => {
      this.toggleFavorite();
    })
  }

  // overflow 菜单：离线缓存 / 字号 / 浏览器打开 / 复制链接（文字菜单，危险项无）
  private overflowMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: '离线缓存', action: (): void => { this.onOfflineCache(); } },
      { value: '字号 A-', action: (): void => { this.adjustZoom(-0.15); } },
      { value: '字号 A+', action: (): void => { this.adjustZoom(0.15); } },
      { value: '在浏览器打开', action: (): void => { this.openInBrowser(); } },
      { value: '复制链接', action: (): void => { this.copyLink(); } }
    ];
    return items;
  }

  @Builder
  moreButton() {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.more)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(AppIcons.moreEmoji)
          .fontSize(20)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusSm)
    .accessibilityText('更多操作')
    .bindMenu(this.overflowMenu())
  }

  // 华为式顶栏：返回 + 标题（2 行截断）+ 收藏 + 分享 + ⋯（操作区 3 个图标）
  @Builder
  topBar() {
    Row({ space: this.themeState.palette.sp1 }) {
      this.barIcon(AppIcons.back, AppIcons.backEmoji, '返回', (): void => {
        AppNavigator.pop();
      })

      Text(this.title.length > 0 ? this.title : '文章详情')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      this.starButton()

      this.barIcon(AppIcons.share, AppIcons.shareEmoji, '分享', (): void => {
        this.shareNews();
      })

      this.moreButton()
    }
    .width('100%')
    .padding({
      left: this.pagePad(), right: this.pagePad(),
      top: Math.max(this.themeState.statusBarHeight, 44) + 6, bottom: 6
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR,
      this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
    .border({
      width: { bottom: 0.5 },
      color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette)
    })
  }

  // ==================== 正文区 ====================

  // 正文元信息条：来源 · 热度描述 · 离线标记
  @Builder
  metaStrip() {
    Row({ space: this.themeState.palette.sp2 }) {
      Text(this.sourceName.length > 0 ? this.sourceName : '热榜')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
      if (this.info.length > 0) {
        Text('· ' + this.info)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      } else {
        Blank()
      }
      if (this.offlineMode) {
        Text('离线缓存')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.warning)
          .padding({ left: this.themeState.palette.sp2, right: this.themeState.palette.sp2, top: 2, bottom: 2 })
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.themeState.palette.warningBg)
      }
    }
    .width('100%')
    .padding({
      left: this.themeState.palette.sp4, right: this.themeState.palette.sp4,
      top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp3
    })
    .alignItems(VerticalAlign.Center)
  }

  // 无原文链接：仅标题可用（空态给原因 + 下一步）
  @Builder
  noUrlState() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('🔗')
        .fontSize(52)
      Text('该条目没有原文链接，仅标题可用')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
      Text(this.sourceName.length > 0 ? '来源 · ' + this.sourceName : '来自热榜')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
      if (this.title.length > 0) {
        Button('复制标题')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .height(this.themeState.palette.touchTarget)
          .padding({ left: 28, right: 28 })
          .margin({ top: this.themeState.palette.sp1 })
          .onClick(() => {
            this.copyText(this.title, '已复制标题');
          })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: this.themeState.palette.sp8, right: this.themeState.palette.sp8 })
    .justifyContent(FlexAlign.Center)
  }

  // 原文加载失败且无缓存：插画式空态 + 重试 / 浏览器打开
  @Builder
  fallbackContent() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('📄')
        .fontSize(52)
      Text('原文加载失败，且暂无离线缓存')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
      Text('可以重新加载，或到浏览器中打开原文')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      Row({ space: this.themeState.palette.sp3 }) {
        Button('重新加载')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .height(this.themeState.palette.touchTarget)
          .padding({ left: this.themeState.palette.sp5, right: this.themeState.palette.sp5 })
          .onClick(() => {
            this.retryLoad();
          })
        Button('浏览器打开')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .height(this.themeState.palette.touchTarget)
          .padding({ left: this.themeState.palette.sp5, right: this.themeState.palette.sp5 })
          .onClick(() => {
            this.openInBrowser();
          })
      }
      .margin({ top: this.themeState.palette.sp1 })
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: this.themeState.palette.sp6, right: this.themeState.palette.sp6 })
    .justifyContent(FlexAlign.Center)
  }

  // ==================== AI 工具条 / 面板 ====================

  private chipActive(kind: string): boolean {
    if (kind === 'translate') return this.aiPanel === AiPanelKind.TRANSLATE;
    if (kind === 'ask') return this.aiPanel === AiPanelKind.ASK;
    if (kind === 'speak') return this.speaking;
    return false;
  }

  private chipLabel(kind: string): string {
    if (kind === 'translate') return '翻译';
    if (kind === 'ask') return '问 AI';
    if (kind === 'speak') return this.speaking ? '停止' : '朗读';
    return '';
  }

  // 主操作：主色填充胶囊（primaryOnColor 文字）
  @Builder
  primaryAction(icon: Resource, emoji: string, label: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp1 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.themeState.palette.primaryOnColor])
      } else {
        Text(emoji)
          .fontSize(15)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
      }
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .fontWeight(FontWeight.Medium)
    }
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp5 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.primary)
    .alignItems(VerticalAlign.Center)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(onTap)
  }

  // 次级动作：胶囊 chip（选中态 primaryBgStrong + 主色文字）
  // kind: 'translate' | 'ask' | 'speak' —— 选中态/文案在 builder 内直接读状态，避免按值传参不刷新
  @Builder
  aiChip(kind: string, icon: Resource, emoji: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp1 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.chipActive(kind) ? this.themeState.palette.primary : this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(15)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.chipActive(kind) ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      }
      Text(this.chipLabel(kind))
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.chipActive(kind) ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .fontWeight(this.chipActive(kind) ? FontWeight.Medium : FontWeight.Normal)
    }
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.chipActive(kind) ? this.themeState.palette.primaryBgStrong :
      this.themeState.palette.bgSurface2)
    .border({
      width: 0.5,
      color: this.chipActive(kind) ? this.themeState.palette.primary : this.themeState.palette.divider
    })
    .alignItems(VerticalAlign.Center)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(onTap)
  }

  // 底部 AI 工具条（悬浮条：保留 P0 级玻璃）
  @Builder
  aiToolbar() {
    Row({ space: this.themeState.palette.sp2 }) {
      this.primaryAction(AppIcons.doc, AppIcons.docEmoji, 'AI 摘要', (): void => {
        this.onSummary();
      })

      Scroll() {
        Row({ space: this.themeState.palette.sp2 }) {
          this.aiChip('translate', AppIcons.globe, AppIcons.globeEmoji, (): void => {
            this.onTranslate();
          })
          this.aiChip('ask', AppIcons.navChat, AppIcons.navChatEmoji, (): void => {
            this.aiPanel = AiPanelKind.ASK;
            this.aiText = '';
            this.aiError = '';
          })
          this.aiChip('speak', AppIcons.speaker, AppIcons.speakerEmoji, (): void => {
            this.toggleSpeak();
          })
        }
      }
      .layoutWeight(1)
      .height(this.themeState.palette.touchTarget)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({
      left: this.pagePad(), right: this.pagePad(), top: this.themeState.palette.sp2,
      bottom: Math.max(8, this.themeState.navBarHeight)
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR,
      this.themeState.palette))
    .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
    .border({
      width: { top: 0.5 },
      color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette)
    })
  }

  // 当前模型 chip（点击切换热榜专属模型；使用专属模型时点亮主色）
  @Builder
  modelChip() {
    Row({ space: this.themeState.palette.sp1 }) {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.navChat)
          .fontSize(14)
          .fontColor([this.modelActive() ? this.themeState.palette.primary : this.themeState.palette.textSecondary])
      } else {
        Text('🤖')
          .fontSize(12)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.modelActive() ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
      }
      Text(this.modelName)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.modelActive() ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .constraintSize({ maxWidth: 150 })
    .height(32)
    .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.modelActive() ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface2)
    .border({
      width: 0.5,
      color: this.modelActive() ? this.themeState.palette.primary : this.themeState.palette.divider
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openModelSheet();
    })
  }

  @Builder
  aiPanelContent() {
    Column() {
      Row({ space: this.themeState.palette.sp2 }) {
        Text(this.panelTitle())
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        this.modelChip()
        this.barIcon(AppIcons.close, AppIcons.closeEmoji, '关闭', (): void => {
          this.closePanel();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.aiPanel === AiPanelKind.ASK) {
        Row({ space: this.themeState.palette.sp2 }) {
          TextInput({ placeholder: '输入你的问题，回车发送', text: this.askInput })
            .layoutWeight(1)
            .height(this.themeState.palette.touchTarget)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .placeholderColor(this.themeState.palette.textTertiary)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .borderRadius(this.themeState.palette.radiusCapsule)
            .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
            .onChange((value: string) => {
              this.askInput = value;
            })
            .onSubmit(() => {
              this.onAskSend();
            })
          Button('发送')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .backgroundColor(this.themeState.palette.primary)
            .borderRadius(this.themeState.palette.radiusCapsule)
            .height(this.themeState.palette.touchTarget)
            .width(76)
            .onClick(() => {
              this.onAskSend();
            })
        }
        .width('100%')
        .margin({ top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp3 })
        .alignItems(VerticalAlign.Center)
      }

      if (this.aiBusy && this.aiText.length === 0) {
        Row({ space: this.themeState.palette.sp2 }) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.themeState.palette.primary)
          Text('AI 思考中…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .height(80)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Text(this.aiText.length > 0 ? this.aiText :
            (this.aiError.length > 0 ? this.aiError : '点击上方按钮生成摘要'))
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.aiError.length > 0 ? this.themeState.palette.danger : this.themeState.palette.textPrimary)
            .lineHeight(24)
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .constraintSize({ maxHeight: 320 })
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }

      Row({ space: this.themeState.palette.sp3 }) {
        Button('复制')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .height(this.themeState.palette.touchTarget)
          .layoutWeight(1)
          .onClick(() => {
            this.copyAiText();
          })
        Button('关闭')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .height(this.themeState.palette.touchTarget)
          .layoutWeight(1)
          .onClick(() => {
            this.closePanel();
          })
      }
      .width('100%')
      .margin({ top: this.themeState.palette.sp4 })

      if (this.lastTokens > 0) {
        Text('本次调用消耗 ' + this.lastTokens.toString() + ' tokens')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .margin({ top: this.themeState.palette.sp2 })
      }
    }
    .width('100%')
    .padding({
      left: this.themeState.palette.sp5, right: this.themeState.palette.sp5, top: this.themeState.palette.sp4,
      bottom: Math.max(20, this.themeState.navBarHeight)
    })
    .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
    .backgroundColor(this.themeState.palette.bgElevated)
    .constraintSize({ maxWidth: 820 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  aiPanelOverlay() {
    if (this.aiPanel !== AiPanelKind.NONE) {
      Stack() {
        Column() {
          Blank()
          this.aiPanelContent()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.maskOverlay)
      .onClick(() => {
        this.closePanel();
      })
    }
  }

  build() {
    Stack() {
      Column() {
        this.topBar()

        if (this.url.length === 0) {
          this.noUrlState()
        } else {
          // 正文区：外层页边距（手机 16vp / 大屏 24vp），内层白卡（无阴影 + 发丝边 + 圆角）
          Column() {
            Column() {
              this.metaStrip()
              Divider()
                .color(this.themeState.palette.divider)
                .strokeWidth(0.5)
              if (!this.webFailed) {
                Web({ src: this.url, controller: this.controller })
                  .width('100%')
                  .layoutWeight(1)
                  .onPageEnd(() => {
                    this.cacheArticleHtml();
                    this.extractBodyText();
                    this.injectDarkCss();
                  })
                  .onErrorReceive(() => {
                    this.useCachedArticle();
                  })
              } else {
                this.fallbackContent()
              }
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.themeState.palette.bgSurface)
            .borderRadius(this.themeState.palette.radiusMd)
            .border({ width: 0.5, color: this.themeState.palette.divider })
            .clip(true)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({
            left: this.pagePad(), right: this.pagePad(), top: this.themeState.palette.sp2
          })

          this.aiToolbar()
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: 820 })

      this.aiPanelOverlay()

      AiModelPicker({
        visible: this.modelSheet,
        models: this.models,
        followGlobal: !this.modelActive(),
        activeModelId: this.currentModelId(),
        currentName: this.modelName,
        onSelect: (id: string): void => { this.pickModel(id); },
        onClose: (): void => { this.modelSheet = false; }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

// 智子 - AI 今日要闻 / 热点速递（独立全屏页）
// 数据来源：内存热榜（HotFeedStore）；手动触发生成；结果按日期 + 模式缓存
// Swiper 分页：左右滑动切换模式（原生动画）；空白页也占满高度可滑动
// 设计文档：doc/newsnow-redesign.md §9.4
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { ChatMarkdownText } from '../components/ChatMarkdownText';
import { HotEntry, HotDigestEntry, HotViewKey, HotDetailRouteParams } from '../common/HotModels';
import { HotFeedStore } from '../service/hot/HotFeedStore';
import { NewsRepository } from '../service/hot/NewsRepository';
import { NewsAiService } from '../service/hot/NewsAiService';
import { LlmConfig, LlmModelEntry, LlmResult } from '../common/LlmModels';

// 每个源参与 prompt 的候选条数（跨源均衡，避免单源刷屏）
const TOP_PER_SOURCE: number = 3;
// 送入 prompt 的最大条目数
const DIGEST_MAX_ITEMS: number = 50;
const HOTSPOT_MAX_ITEMS: number = 60;

@ComponentV2
@Entry
export struct NewsDigestPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local digest: HotDigestEntry | null = null;
  // 各模式当日缓存（Swiper 分页：非当前页直接读缓存展示，避免空白页无法滑动）
  @Local digestMap: Record<string, HotDigestEntry | null> = {};
  // 生成模式：digest = 今日要闻；morning/noon/evening = 时段速递
  @Local mode: string = 'digest';
  // Swiper 当前页（与 mode 同步）
  @Local swiperIndex: number = 0;
  @Local generating: boolean = false;
  @Local streamText: string = '';
  @Local errorText: string = '';
  // 热榜暂无数据时的引导文案
  @Local noDataHint: string = '';
  // 本次生成使用的候选条目（用于渲染原文链接区）
  @Local sourceItems: HotEntry[] = [];
  // 最近一次生成 token 消耗
  @Local lastTokens: number = 0;
  // 模型选择（热榜专属模型）
  @Local modelName: string = '跟随全局';
  @Local models: LlmModelEntry[] = [];
  @Local modelSheet: boolean = false;
  // 加载序号：防止快速切换模式时旧查询结果覆盖新结果
  private loadSeq: number = 0;

  aboutToAppear(): void {
    this.loadToday();
    this.loadModelName();
  }

  // 一次性加载全部模式的当日缓存（Swiper 各页即时可用）
  private async loadToday(): Promise<void> {
    const seq: number = this.loadSeq + 1;
    this.loadSeq = seq;
    try {
      const modes: string[] = this.modeOrder();
      const map: Record<string, HotDigestEntry | null> = {};
      const tasks: Promise<void>[] = [];
      for (let i: number = 0; i < modes.length; i++) {
        tasks.push(NewsRepository.todayDigest(modes[i]).then((d: HotDigestEntry | null) => {
          map[modes[i]] = d;
        }));
      }
      await Promise.all(tasks);
      if (seq === this.loadSeq) {
        this.digestMap = map;
        this.digest = map[this.mode] === undefined ? null : map[this.mode];
      }
    } catch (e) {
      if (seq === this.loadSeq) {
        this.digestMap = {};
        this.digest = null;
      }
    }
  }

  private modeTitle(): string {
    if (this.mode === 'morning') return '🌅 早报速递';
    if (this.mode === 'noon') return '🌤️ 午间速递';
    if (this.mode === 'evening') return '🌙 晚报速递';
    return '📰 今日要闻';
  }

  private modeDesc(): string {
    if (this.mode === 'morning') return 'AI 梳理今晨热榜重要资讯';
    if (this.mode === 'noon') return 'AI 汇总当天热榜最新进展';
    if (this.mode === 'evening') return 'AI 复盘全天热榜重要动态';
    return '聚合各源热榜条目，一键生成 8~10 条要闻';
  }

  // ==================== 模式顺序与展示（分段标签 + Swiper 滑动） ====================

  private modeOrder(): string[] {
    return ['digest', 'morning', 'noon', 'evening'];
  }

  private modeIndex(mode: string): number {
    const order: string[] = this.modeOrder();
    for (let i: number = 0; i < order.length; i++) {
      if (order[i] === mode) return i;
    }
    return 0;
  }

  private modeIcon(mode: string): string {
    if (mode === 'morning') return '🌅';
    if (mode === 'noon') return '🌤️';
    if (mode === 'evening') return '🌙';
    return '📰';
  }

  private modeName(mode: string): string {
    if (mode === 'morning') return '早报';
    if (mode === 'noon') return '午间';
    if (mode === 'evening') return '晚报';
    return '今日要闻';
  }

  // 切换模式（标签点击 / Swiper onChange 共用）
  private switchMode(mode: string): void {
    if (this.mode === mode || this.generating) return;
    this.mode = mode;
    this.swiperIndex = this.modeIndex(mode);
    this.digest = this.digestMap[mode] === undefined ? null : this.digestMap[mode];
    this.streamText = '';
    this.errorText = '';
    this.noDataHint = '';
    this.sourceItems = [];
  }

  // Swiper 翻页回调（生成中禁止切换，并把页强制拉回当前模式）
  private onSwiperChange(index: number): void {
    const modes: string[] = this.modeOrder();
    if (index < 0 || index >= modes.length) return;
    if (modes[index] === this.mode) return;
    if (this.generating) {
      this.swiperIndex = this.modeIndex(this.mode);
      return;
    }
    this.switchMode(modes[index]);
  }

  // ==================== 候选数据（内存热榜） ====================

  // 候选条目：各源 Top3 横向混合（确定性顺序），为空时回退全部已加载条目
  private async pickItems(): Promise<HotEntry[]> {
    const ids: string[] = await HotFeedStore.sourceIds(HotViewKey.Hottest);
    const out: HotEntry[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      const top: HotEntry[] = HotFeedStore.topEntries(ids[i], TOP_PER_SOURCE);
      for (let j: number = 0; j < top.length; j++) {
        out.push(top[j]);
      }
    }
    if (out.length > 0) return out;
    return HotFeedStore.allLoadedEntries();
  }

  // 确保内存中至少有数据；仍为空则返回 false（此时不调用 AI）
  private async ensureItems(): Promise<boolean> {
    if (HotFeedStore.allLoadedEntries().length > 0) return true;
    try {
      await HotFeedStore.ensureView(HotViewKey.Hottest, false);
    } catch (e) {
    }
    return HotFeedStore.allLoadedEntries().length > 0;
  }

  private async generate(): Promise<void> {
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.generating = true;
    this.streamText = '';
    this.errorText = '';
    this.noDataHint = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.generating = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    try {
      const ready: boolean = await this.ensureItems();
      if (!ready) {
        this.noDataHint = '暂无热榜数据，请先回到首页加载热榜后再试';
        this.generating = false;
        return;
      }
      const picked: HotEntry[] = await this.pickItems();
      this.sourceItems = picked;
      const limit: number = this.mode === 'digest' ? DIGEST_MAX_ITEMS : HOTSPOT_MAX_ITEMS;
      const candidates: HotEntry[] = picked.length > limit ? picked.slice(0, limit) : picked;
      let result: LlmResult;
      if (this.mode === 'digest') {
        result = await NewsAiService.generateDigest(config, candidates,
          NewsRepository.todayLabel(), (d: string): void => {
            this.streamText = this.streamText + d;
          });
      } else {
        result = await NewsAiService.generateHotspot(config, candidates,
          NewsRepository.todayLabel(), this.mode, (d: string): void => {
            this.streamText = this.streamText + d;
          });
      }
      this.generating = false;
      if (!result.success) {
        this.errorText = result.errorMessage.length > 0 ? result.errorMessage : 'AI 生成失败，请重试';
        return;
      }
      const saved: HotDigestEntry = await NewsRepository.saveDigest(result.content,
        config.displayName.length > 0 ? config.displayName : config.model, this.mode);
      this.digest = saved;
      this.digestMap[this.mode] = saved;
      this.streamText = '';
      this.lastTokens = result.tokenUsage.totalTokens;
      promptAction.showToast({ message: this.modeTitle() + '已生成' });
    } catch (e) {
      this.generating = false;
      this.errorText = '生成失败，请重试';
    }
  }

  private digestText(): string {
    if (this.digest === null) return '';
    return this.digest.content;
  }

  // 指定模式的当日缓存（供 @Builder 内调用，@Builder 中不允许声明局部变量）
  private digestOf(mode: string): HotDigestEntry | null {
    return this.digestMap[mode] === undefined ? null : this.digestMap[mode];
  }

  private digestContentOf(mode: string): string {
    const entry: HotDigestEntry | null = this.digestOf(mode);
    return entry === null ? '' : entry.content;
  }

  // 用系统浏览器打开链接（Markdown 段落链接点击）
  private openUrl(url: string): void {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      context.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      }).catch((e: Object) => {
        promptAction.showToast({ message: '无法打开链接' });
      });
    } catch (e) {
      promptAction.showToast({ message: '无法打开链接' });
    }
  }

  private openEntry(entry: HotEntry): void {
    AppNavigator.push('pages/NewsDetail', new HotDetailRouteParams(entry.key, entry.sourceId,
      entry.sourceName, entry.item.title, entry.item.url, entry.item.info));
  }

  private digestModel(): string {
    if (this.digest === null) return '';
    return this.digest.modelName;
  }

  private async copy(): Promise<void> {
    const text: string = this.digest !== null ? this.digest.content : this.streamText;
    if (text.length === 0) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // ==================== 模型选择（热榜专属模型） ====================

  private modelLabel(m: LlmModelEntry): string {
    return m.displayName.length > 0 ? m.displayName : m.model;
  }

  private async loadModelName(): Promise<void> {
    try {
      this.modelName = await NewsAiService.getActiveModelName();
    } catch (e) {
      this.modelName = '未配置模型';
    }
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

  // ==================== Swiper 分页 ====================

  // 每页：自己的纵向滚动区，始终占满 Swiper 高度（空白页也可左右滑动）
  @Builder
  modePage(m: string) {
    Scroll() {
      Column({ space: 12 }) {
        if (m === this.mode) {
          this.currentModeBody()
        } else {
          this.otherModeBody(m)
        }
        Column().height(20)
      }
      .width('100%')
      .constraintSize({ maxWidth: 720 })
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  // 当前模式：完整内容（生成中/流式/错误/结果/原文链接/空态）
  @Builder
  currentModeBody() {
    if (this.generating) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(20)
          .height(20)
        Text('AI 正在整理热榜要闻…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
    }

    if (this.streamText.length > 0) {
      // 流式预览：纯文本（流式中反复全量 Markdown 解析会 OOM）；
      // 生成完成后下方用 ChatMarkdownText 渲染最终结果（只解析一次）
      Text(this.streamText.length > 3000 ?
        '…' + this.streamText.substring(this.streamText.length - 3000) : this.streamText)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .lineHeight(24)
        .width('100%')
    }

    if (this.errorText.length > 0) {
      Text(this.errorText)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.danger)
        .width('100%')
    }

    if (!this.generating && this.streamText.length === 0 && this.errorText.length === 0) {
      if (this.digest !== null) {
        // 用 ForEach 单元素 + 唯一 key 强制重建渲染组件：
        // V1 ChatMarkdownText 在 V2 页面中 @Prop 更新可能不触发重解析，key 变化会卸载重建
        ForEach([this.digestText()], (content: string) => {
          ChatMarkdownText({ content: content, onLinkTap: (url: string): void => { this.openUrl(url); } })
            .width('100%')
        }, (content: string) => 'md-' + this.mode + '-' +
          (this.digest !== null ? this.digest.id : 'empty'))

        Row({ space: 10 }) {
          Button('📋 复制简报')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .borderRadius(this.themeState.palette.radiusSm)
            .height(38)
            .layoutWeight(1)
            .onClick(() => { this.copy(); })
          Button('🔁 重新生成')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.primary)
            .borderRadius(this.themeState.palette.radiusSm)
            .height(38)
            .layoutWeight(1)
            .onClick(() => { this.generate(); })
        }
        .width('100%')
        .margin({ top: 8 })

        if (this.lastTokens > 0) {
          Text('本次生成消耗 ' + this.lastTokens.toString() + ' tokens')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .margin({ top: 10 })
        }

        // 原文链接区：来自本次真实热榜数据，点击打开详情（原文 ArkWeb）
        if (this.sourceItems.length > 0) {
          Text('📎 原文链接')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .margin({ top: 16, bottom: 6 })
          Column({ space: 6 }) {
            ForEach(this.sourceItems.slice(0, 12), (entry: HotEntry) => {
              Row({ space: 8 }) {
                Text('🔗')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                Text(entry.item.title)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text(entry.sourceName)
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .maxLines(1)
              }
              .width('100%')
              .padding(10)
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.themeState.palette.bgSurface2)
              .onClick(() => { this.openEntry(entry); })
            }, (entry: HotEntry) => entry.key)
          }
          .width('100%')
        }
      } else if (this.noDataHint.length > 0) {
        Column({ space: 10 }) {
          Text('📡')
            .fontSize(46)
            .fontFamily(this.themeState.palette.fontSans)
          Text(this.noDataHint)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
          Text('热榜数据保存在内存中，回到首页浏览任意榜单后即可生成')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
          Button('重试')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.primary)
            .borderRadius(16)
            .height(34)
            .margin({ top: 6 })
            .onClick(() => { this.generate(); })
        }
        .width('100%')
        .padding({ top: 40 })
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          Text(this.mode === 'digest' ? '🤖' : '🌤️')
            .fontSize(46)
            .fontFamily(this.themeState.palette.fontSans)
          Text('今天还没有生成' + (this.mode === 'digest' ? '简报' : '速递'))
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
          Text('点击上方「生成」按钮，' + this.modeDesc())
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .padding({ top: 40 })
        .justifyContent(FlexAlign.Center)
      }
    }
  }

  // 其他模式页：展示已生成缓存；未生成给引导（整页占满，左右滑动始终可用）
  @Builder
  otherModeBody(m: string) {
    if (this.digestOf(m) !== null) {
      Column({ space: 12 }) {
        ForEach([this.digestContentOf(m)], (content: string) => {
          ChatMarkdownText({ content: content, onLinkTap: (url: string): void => { this.openUrl(url); } })
            .width('100%')
        }, (content: string) => 'md-other-' + m + '-' + this.digestContentOf(m).length.toString())
        Text('左右滑动或点击上方标签可切换到「' + this.modeName(m) + '」')
          .fontSize(this.themeState.palette.fsXs - 1)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
      }
      .width('100%')
    } else {
      Column({ space: 10 }) {
        Text(this.modeIcon(m))
          .fontSize(46)
          .fontFamily(this.themeState.palette.fontSans)
        Text('「' + this.modeName(m) + '」尚未生成')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
        Text('左右滑动切换模式，或点击上方标签后按「生成」')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .padding({ top: 60 })
      .justifyContent(FlexAlign.Center)
    }
  }

  // 当前模型 chip（点击切换热榜专属模型）
  @Builder
  modelChip(chipWidth: number) {
    Row({ space: 4 }) {
      Text('🤖')
        .fontSize(11)
        .fontFamily(this.themeState.palette.fontSans)
      Text(this.modelName)
        .fontSize(10)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('▾')
        .fontSize(9)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width(chipWidth)
    .height(30)
    .padding({ left: 8, right: 8 })
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.openModelSheet(); })
  }

  @Builder
  modelOverlay() {
    if (this.modelSheet) {
      Stack() {
        Column() {
          Blank()
          Column({ space: 4 }) {
            Row() {
              Text('选择模型')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(8)
                .accessibilityText('关闭')
                .onClick(() => { this.modelSheet = false; })
            }
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 6 })

            Scroll() {
              Column({ space: 4 }) {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Text('跟随全局')
                      .fontSize(this.themeState.palette.fsSm)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textPrimary)
                    Text('使用「我的 → AI 模型」中的默认模型')
                      .fontSize(10)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(12)
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(this.themeState.palette.bgSurface)
                .onClick(() => { this.pickModel(''); })

                ForEach(this.models, (m: LlmModelEntry) => {
                  Row({ space: 10 }) {
                    Column({ space: 2 }) {
                      Text(this.modelLabel(m))
                        .fontSize(this.themeState.palette.fsSm)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(m.model)
                        .fontSize(10)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textTertiary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding(12)
                  .borderRadius(this.themeState.palette.radiusSm)
                  .backgroundColor(this.themeState.palette.bgSurface)
                  .onClick(() => { this.pickModel(m.id); })
                }, (m: LlmModelEntry) => m.id)

                if (this.models.length === 0) {
                  Text('没有已启用的模型，请到「我的 → AI 模型」中启用')
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .padding({ top: 12, bottom: 12 })
                }
              }
              .width('100%')
            }
            .width('100%')
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: 360 })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.themeState.palette.bgBase)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {})
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.35)')
      .onClick(() => { this.modelSheet = false; })
    }
  }

  build() {
    Stack() {
      Column() {
        TopBar({
          title: 'AI 今日要闻',
          subtitle: NewsRepository.todayLabel()
        })

        // 顶部固定区：状态卡 + 分段标签 + 指示点
        Column({ space: 12 }) {
          // 状态卡
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(this.digest !== null ? this.modeTitle() + '已生成' : this.modeTitle())
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text(this.digest !== null ?
                (this.digestModel().length > 0 ? '由 ' + this.digestModel() + ' 生成' : '') :
                this.modeDesc())
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            this.modelChip(104)
            Button(this.digest !== null ? '重新生成' : '生成')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(this.themeState.palette.primary)
              .borderRadius(16)
              .height(34)
              .enabled(!this.generating)
              .onClick(() => { this.generate(); })
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(this.themeState.palette.bgSurface)
          .border({ width: 0.5, color: this.themeState.palette.divider })

          // 模式切换：主体分段标签（4 个模式均分，选中高亮）
          Row({ space: 4 }) {
            ForEach(this.modeOrder(), (m: string) => {
              Column({ space: 2 }) {
                Text(this.modeIcon(m))
                  .fontSize(this.themeState.palette.fsMd + 2)
                  .fontFamily(this.themeState.palette.fontSans)
                Text(this.modeName(m))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.mode === m ? Color.White : this.themeState.palette.textSecondary)
                  .fontWeight(this.mode === m ? FontWeight.Bold : FontWeight.Normal)
              }
              .layoutWeight(1)
              .height(54)
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.mode === m ? this.themeState.palette.primary :
                this.themeState.palette.bgSurface)
              .border({ width: this.mode === m ? 0 : 1,
                color: this.mode === m ? Color.Transparent :
                  this.themeState.palette.divider })
              .onClick(() => { this.switchMode(m); })
            }, (m: string) => m)
          }
          .width('100%')

          // 位置指示点 + 滑动提示
          Row({ space: 6 }) {
            ForEach(this.modeOrder(), (m: string) => {
              Circle({ width: this.mode === m ? 8 : 6, height: this.mode === m ? 8 : 6 })
                .fill(this.mode === m ? this.themeState.palette.primary : this.themeState.palette.borderSubtle)
            }, (m: string) => m + '-dot')
            Text('左右滑动切换')
              .fontSize(this.themeState.palette.fsXs - 1)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .margin({ left: 4 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 2, bottom: 4 })
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })

        // Swiper 分页：原生滑动动画；每页占满剩余高度，空白页也可滑动
        Swiper() {
          ForEach(this.modeOrder(), (m: string) => {
            this.modePage(m)
          }, (m: string) => m)
        }
        .layoutWeight(1)
        .width('100%')
        .index(this.swiperIndex)
        .loop(false)
        .indicator(false)
        .cachedCount(1)
        .onChange((index: number) => { this.onSwiperChange(index); })
      }
      .width('100%')
      .height('100%')

      this.modelOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

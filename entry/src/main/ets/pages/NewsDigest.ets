// 智子 - AI 今日要闻（独立全屏页）
// 手动触发生成；结果缓存到 news_digests（按日期），可重新生成
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { ChatMarkdownText } from '../components/ChatMarkdownText';
import { NewsModelSelector } from '../components/NewsModelSelector';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsItem, NewsDigestEntry, NewsDetailRouteParams } from '../common/NewsModels';
import { NewsService } from '../service/NewsService';
import { NewsRepository } from '../service/NewsRepository';
import { NewsAiService } from '../service/NewsAiService';
import { NewsRanker } from '../service/NewsRanker';
import { LlmConfig, LlmResult } from '../common/LlmModels';

@ComponentV2
@Entry
export struct NewsDigestPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local digest: NewsDigestEntry | null = null;
  // 生成模式：digest = 今日要闻；hotspot = 热点速递
  @Local mode: string = 'digest';
  @Local generating: boolean = false;
  @Local streamText: string = '';
  @Local errorText: string = '';
  // 本次生成使用的候选新闻（用于渲染原文链接区）
  @Local sourceItems: NewsItem[] = [];
  // 最近一次生成 token 消耗
  @Local lastTokens: number = 0;
  // 加载序号：防止快速切换模式时旧查询结果覆盖新结果
  private loadSeq: number = 0;

  aboutToAppear(): void {
    this.loadToday();
  }

  private async loadToday(): Promise<void> {
    const seq: number = this.loadSeq + 1;
    this.loadSeq = seq;
    try {
      const d: NewsDigestEntry | null = await NewsRepository.todayDigest(this.mode);
      if (seq === this.loadSeq) {
        this.digest = d;
      }
    } catch (e) {
      if (seq === this.loadSeq) {
        this.digest = null;
      }
    }
  }

  private modeTitle(): string {
    if (this.mode === 'morning') return '🌅 早报速递';
    if (this.mode === 'noon') return '🌤️ 午间速递';
    if (this.mode === 'evening') return '🌙 晚报速递';
    if (this.mode === 'personal') return '🎯 为你精选';
    return '📰 今日要闻';
  }

  private modeDesc(): string {
    if (this.mode === 'morning') return 'AI 梳理今晨重要资讯';
    if (this.mode === 'noon') return 'AI 汇总当天最新进展';
    if (this.mode === 'evening') return 'AI 复盘全天重要动态';
    if (this.mode === 'personal') return '基于你的点赞/点踩画像，AI 精选最相关内容';
    return '聚合当天各源热点，一键生成 8~10 条要闻';
  }

  // ==================== 模式顺序与展示（分段标签 + 左右滑动） ====================

  private modeOrder(): string[] {
    return ['digest', 'morning', 'noon', 'evening', 'personal'];
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
    if (mode === 'personal') return '🎯';
    return '📰';
  }

  private modeName(mode: string): string {
    if (mode === 'morning') return '早报';
    if (mode === 'noon') return '午间';
    if (mode === 'evening') return '晚报';
    if (mode === 'personal') return '为你';
    return '今日要闻';
  }

  // 左右滑动切换模式（左滑下一个，右滑上一个）
  private onSwipeMode(offsetX: number): void {
    const modes: string[] = this.modeOrder();
    const idx: number = this.modeIndex(this.mode);
    if (offsetX < 0 && idx < modes.length - 1) {
      this.switchMode(modes[idx + 1]);
    } else if (offsetX > 0 && idx > 0) {
      this.switchMode(modes[idx - 1]);
    }
  }

  private switchMode(mode: string): void {
    if (this.mode === mode || this.generating) return;
    this.mode = mode;
    // 立即清空内容区（避免旧模式内容残留，让切换反馈明确），再异步加载新模式缓存
    this.digest = null;
    this.streamText = '';
    this.errorText = '';
    this.sourceItems = [];
    this.loadToday();
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
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.generating = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    try {
      const items: NewsItem[] = await NewsService.fetchChannel('recommend',
        this.mode === 'hotspot' ? 60 : 50, true);
      if (items.length === 0) {
        this.errorText = '没有获取到新闻数据，请检查网络后重试';
        this.generating = false;
        return;
      }
      this.sourceItems = items;
      let result: LlmResult;
      if (this.mode === 'personal') {
        // 个性化：先按画像权重精选候选（NewsRanker），再生成
        const ranked: NewsItem[] = await NewsRanker.rank(items, 20);
        this.sourceItems = ranked;
        result = await NewsAiService.generatePersonalizedDigest(config, ranked,
          NewsRepository.todayLabel(), (d: string): void => {
            this.streamText = this.streamText + d;
          });
      } else if (this.mode === 'digest') {
        result = await NewsAiService.generateDigest(config, items,
          NewsRepository.todayLabel(), (d: string): void => {
            this.streamText = this.streamText + d;
          });
      } else {
        result = await NewsAiService.generateHotspot(config, items,
          NewsRepository.todayLabel(), this.mode, (d: string): void => {
            this.streamText = this.streamText + d;
          });
      }
      this.generating = false;
      if (!result.success) {
        this.errorText = result.errorMessage.length > 0 ? result.errorMessage : 'AI 生成失败，请重试';
        return;
      }
      const saved: NewsDigestEntry = await NewsRepository.saveDigest(result.content,
        config.displayName.length > 0 ? config.displayName : config.model, this.mode);
      this.digest = saved;
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

  build() {
    Column() {
      TopBar({
        title: 'AI 今日要闻',
        subtitle: NewsRepository.todayLabel()
      })

      Scroll() {
        Row() {
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
            NewsModelSelector({ compact: true })
              .width(104)
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
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

          // 模式切换：主体分段标签（5 个模式均分，选中高亮）+ 左右滑动切换
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
                GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
              .border({ width: this.mode === m ? 0 : 1,
                color: this.mode === m ? Color.Transparent :
                  GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
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
          .padding({ top: 2, bottom: 8 })

          if (this.generating) {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(20)
                .height(20)
              Text('AI 正在整理今日要闻…')
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
                  .borderRadius(8)
                  .height(38)
                  .layoutWeight(1)
                  .onClick(() => { this.copy(); })
                Button('🔁 重新生成')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(Color.White)
                  .backgroundColor(this.themeState.palette.primary)
                  .borderRadius(8)
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

              // 原文链接区：来自本次真实源数据，点击打开详情（原文 ArkWeb）
              if (this.sourceItems.length > 0) {
                Text('📎 原文链接')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .width('100%')
                  .margin({ top: 16, bottom: 6 })
                Column({ space: 6 }) {
                  ForEach(this.sourceItems.slice(0, 12), (item: NewsItem) => {
                    Row({ space: 8 }) {
                      Text('🔗')
                        .fontSize(this.themeState.palette.fsSm)
                        .fontFamily(this.themeState.palette.fontSans)
                      Text(item.title)
                        .fontSize(this.themeState.palette.fsSm)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.primary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(item.sourceName)
                        .fontSize(this.themeState.palette.fsXs)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textTertiary)
                        .maxLines(1)
                    }
                    .width('100%')
                    .padding(10)
                    .borderRadius(8)
                    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
                    .onClick(() => {
                      AppNavigator.push('pages/NewsDetail', new NewsDetailRouteParams(item));
                    })
                  }, (item: NewsItem) => item.id)
                }
                .width('100%')
              }
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

          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 40 })
            .onActionEnd((event: GestureEvent) => {
              // PanGesture 在结束时提供可靠的 offsetX：左滑 <0 → 下一个，右滑 >0 → 上一个
              const dx: number = event.offsetX;
              if (Math.abs(dx) < 30) return;
              this.onSwipeMode(dx);
            })
        )
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

// 智子 - AI 今日要闻（独立全屏页）
// 手动触发生成；结果缓存到 news_digests（按日期），可重新生成
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
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
      if (this.mode === 'hotspot') {
        result = await NewsAiService.generateHotspot(config, items,
          NewsRepository.todayLabel(), (d: string): void => {
            this.streamText = this.streamText + d;
          });
      } else {
        result = await NewsAiService.generateDigest(config, items,
          NewsRepository.todayLabel(), (d: string): void => {
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
      promptAction.showToast({ message: this.mode === 'hotspot' ? '热点速递已生成' : '今日要闻已生成' });
    } catch (e) {
      this.generating = false;
      this.errorText = '生成失败，请重试';
    }
  }

  private digestText(): string {
    if (this.digest === null) return '';
    return this.digest.content;
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
              Text(this.mode === 'hotspot' ?
                (this.digest !== null ? '🔥 热点速递已生成' : '🔥 AI 热点速递') :
                (this.digest !== null ? '📰 今日简报已生成' : '📰 每天一份 AI 热点简报'))
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text(this.digest !== null ?
                (this.digestModel().length > 0 ? '由 ' + this.digestModel() + ' 生成' : '') :
                (this.mode === 'hotspot' ? 'AI 梳理国际 / 国内 / 财经科技热点' :
                  '聚合当天各源热点，一键生成 8~10 条要闻'))
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
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

          // 模式切换 + 资讯专属模型选择（记忆到 settings.newsModelId）
          Row({ space: 8 }) {
            Row({ space: 6 }) {
              Text('📰 今日要闻')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.mode === 'digest' ? this.themeState.palette.primary :
                  this.themeState.palette.textSecondary)
                .fontWeight(this.mode === 'digest' ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(this.mode === 'digest' ? this.themeState.palette.primary + '2A' :
                  this.themeState.palette.bgSurface2)
                .onClick(() => { this.switchMode('digest'); })
              Text('🔥 热点速递')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.mode === 'hotspot' ? this.themeState.palette.primary :
                  this.themeState.palette.textSecondary)
                .fontWeight(this.mode === 'hotspot' ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(this.mode === 'hotspot' ? this.themeState.palette.primary + '2A' :
                  this.themeState.palette.bgSurface2)
                .onClick(() => { this.switchMode('hotspot'); })
            }
            Blank()
            NewsModelSelector()
              .width(180)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 0, bottom: 12 })

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
                ChatMarkdownText({ content: content })
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
                Text(this.mode === 'hotspot' ? '🔥' : '🤖')
                  .fontSize(46)
                  .fontFamily(this.themeState.palette.fontSans)
                Text(this.mode === 'hotspot' ? '今天还没有生成热点速递' : '今天还没有生成简报')
                  .fontSize(this.themeState.palette.fsLg)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textPrimary)
                Text(this.mode === 'hotspot' ?
                  '点击上方「生成」按钮，AI 将梳理国际 / 国内 / 财经科技热点' :
                  '点击上方「生成」按钮，AI 将聚合当天新闻热点并生成简报')
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

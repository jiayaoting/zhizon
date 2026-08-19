// 智子 - 为你推荐（基于收藏/阅读历史，AI 排序候选新闻）
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { ChatMarkdownText } from '../components/ChatMarkdownText';
import { NewsModelSelector } from '../components/NewsModelSelector';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsItem } from '../common/NewsModels';
import { NewsService } from '../service/NewsService';
import { NewsRepository } from '../service/NewsRepository';
import { NewsAiService } from '../service/NewsAiService';
import { LlmConfig, LlmResult } from '../common/LlmModels';

@ComponentV2
@Entry
export struct NewsRecommendPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local historyTitles: string[] = [];
  @Local output: string = '';
  @Local generating: boolean = false;
  @Local errorText: string = '';

  aboutToAppear(): void {
    this.loadHistory();
  }

  aboutToDisappear(): void {
    // 单次生成，无持久资源需要释放
  }

  private async loadHistory(): Promise<void> {
    try {
      const favs: NewsItem[] = await NewsRepository.listFavorites();
      const titles: string[] = [];
      for (let i: number = 0; i < favs.length; i++) {
        titles.push(favs[i].title);
      }
      this.historyTitles = titles;
    } catch (e) {
      this.historyTitles = [];
    }
  }

  private async generate(): Promise<void> {
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.generating = true;
    this.output = '';
    this.errorText = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.generating = false;
      promptAction.showToast({ message: '模型配置不可用' });
      return;
    }
    try {
      const candidates: NewsItem[] = await NewsService.fetchChannel('recommend', 30, true);
      if (candidates.length === 0) {
        this.errorText = '没有获取到候选新闻，请检查网络后重试';
        this.generating = false;
        return;
      }
      const result: LlmResult = await NewsAiService.recommend(config, candidates,
        this.historyTitles, (d: string): void => {
          this.output = this.output + d;
        });
      this.generating = false;
      if (!result.success) {
        this.errorText = result.errorMessage.length > 0 ? result.errorMessage : 'AI 生成失败，请重试';
      }
    } catch (e) {
      this.generating = false;
      this.errorText = '生成失败，请重试';
    }
  }

  private async copy(): Promise<void> {
    if (this.output.length === 0) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.output);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  build() {
    Column() {
      TopBar({ title: '为你推荐', subtitle: 'AI 个性化新闻推荐', showBack: true })

      Scroll() {
        Row() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('🎯 基于你的兴趣推荐')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text(this.historyTitles.length > 0 ?
                '已收集 ' + this.historyTitles.length.toString() + ' 篇收藏文章作为兴趣依据' :
                '暂无收藏记录，推荐将基于通用热点')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
              NewsModelSelector()
                .width(180)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('生成推荐')
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

          if (this.generating) {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(20)
                .height(20)
              Text('AI 正在分析你的兴趣并排序候选新闻…')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 8, bottom: 8 })
          }

          if (this.output.length > 0) {
            if (this.generating) {
              // 流式预览：纯文本（避免流式中反复全量解析 OOM）
              Text(this.output.length > 3000 ?
                '…' + this.output.substring(this.output.length - 3000) : this.output)
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .lineHeight(24)
                .width('100%')
            } else {
              ChatMarkdownText({ content: this.output })
                .width('100%')
            }
          }

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.danger)
              .width('100%')
          }

          if (!this.generating && this.output.length === 0 && this.errorText.length === 0) {
            Column({ space: 10 }) {
              Text('🗂️')
                .fontSize(46)
                .fontFamily(this.themeState.palette.fontSans)
              Text('点击「生成推荐」获取个性化新闻')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
              Text('多多收藏你感兴趣的文章，推荐会越来越准')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
            .padding({ top: 40 })
            .justifyContent(FlexAlign.Center)
          }

          if (this.output.length > 0 && !this.generating) {
            Button('📋 复制推荐')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(this.themeState.palette.primary)
              .borderRadius(8)
              .height(38)
              .width('100%')
              .onClick(() => { this.copy(); })
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

// 智子 - 新闻搜索（跨源关键词搜索 + AI 汇总）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsItem, NewsDetailRouteParams } from '../common/NewsModels';
import { NewsService } from '../service/NewsService';
import { NewsRepository } from '../service/NewsRepository';
import { NewsAiService } from '../service/NewsAiService';
import { ChatMarkdownText } from '../components/ChatMarkdownText';
import { NewsCard } from '../components/NewsCard';
import { LlmConfig, LlmResult } from '../common/LlmModels';

@ComponentV2
@Entry
export struct NewsSearchPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local keyword: string = '';
  // 搜索模式：web=全网跨源 / local=本地收藏与离线缓存全文搜索（FTS5 优先）
  @Local mode: string = 'web';
  @Local items: NewsItem[] = [];
  @Local searching: boolean = false;
  @Local searched: boolean = false;
  @Local errorText: string = '';
  // AI 汇总
  @Local summaryText: string = '';
  @Local summarizing: boolean = false;

  aboutToAppear(): void {
    // 无持久资源需要加载
  }

  private async doSearch(): Promise<void> {
    const q: string = this.keyword.trim();
    if (q.length === 0) {
      promptAction.showToast({ message: '请输入搜索关键词' });
      return;
    }
    this.searching = true;
    this.errorText = '';
    this.summaryText = '';
    if (this.mode === 'local') {
      // 本地全文搜索：收藏（标题/摘要）+ 离线正文缓存（标题/正文）
      this.items = await NewsRepository.searchLocal(q, 30);
    } else {
      this.items = await NewsService.search(q, 30);
    }
    this.searching = false;
    this.searched = true;
    if (this.items.length === 0) {
      this.errorText = this.mode === 'local' ? '本地收藏与缓存中没有找到相关内容' : '没有找到相关新闻，换个关键词试试';
    }
  }

  private openDetail(item: NewsItem): void {
    AppNavigator.push('pages/NewsDetail', new NewsDetailRouteParams(item));
  }

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

  private async summarize(): Promise<void> {
    if (this.items.length === 0 || this.summarizing) return;
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    this.summarizing = true;
    this.summaryText = '';
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      this.summarizing = false;
      return;
    }
    const result: LlmResult = await NewsAiService.generateSearchSummary(config, this.items,
      this.keyword.trim(), (d: string): void => {
        this.summaryText = this.summaryText + d;
      });
    this.summarizing = false;
    if (!result.success) {
      promptAction.showToast({ message: 'AI 汇总失败，请重试' });
    }
  }

  build() {
    Column() {
      TopBar({ title: '新闻搜索', subtitle: '跨源关键词搜索', showBack: true })

      // 搜索模式切换：全网跨源 / 本地收藏·缓存全文
      Row({ space: 8 }) {
        Row() {
          Text('🌐 全网搜索')
            .fontSize(12)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.mode === 'web' ? '#FFFFFF' : this.themeState.palette.textSecondary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor(this.mode === 'web' ? this.themeState.palette.primary : this.themeState.palette.bgSurface2)
        .onClick(() => { this.mode = 'web'; this.items = []; this.searched = false; this.errorText = ''; })
        Row() {
          Text('🗂 本地收藏·缓存')
            .fontSize(12)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.mode === 'local' ? '#FFFFFF' : this.themeState.palette.textSecondary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor(this.mode === 'local' ? this.themeState.palette.primary : this.themeState.palette.bgSurface2)
        .onClick(() => { this.mode = 'local'; this.items = []; this.searched = false; this.errorText = ''; })
        Blank()
        Text(this.mode === 'local' ? '🔒 本地搜索（不出网）' : '多源 RSS 聚合')
          .fontSize(10)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10 })

      // 搜索输入
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入关键词，如：AI、机器人、芯片…', text: this.keyword })
          .layoutWeight(1)
          .height(40)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .onChange((value: string) => { this.keyword = value; })
          .onSubmit(() => { this.doSearch(); })
        Button('搜索')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(8)
          .height(40)
          .onClick(() => { this.doSearch(); })
      }
      .width('100%')
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12, bottom: 8 })

      if (this.searching) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
          Text('搜索中…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 20, bottom: 8 })
      } else if (this.errorText.length > 0 && this.items.length === 0) {
        Text(this.errorText)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.danger)
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 16 })
      } else if (this.items.length > 0) {
        Column() {
          // AI 汇总按钮
          Row({ space: 8 }) {
            Text('🤖 AI 汇总搜索结果')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor(this.themeState.palette.primary)
              .enabled(!this.summarizing)
              .onClick(() => { this.summarize(); })
            if (this.summarizing) {
              LoadingProgress()
                .width(16)
                .height(16)
            }
            Blank()
            Text('共 ' + this.items.length.toString() + ' 条')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 4, bottom: 6 })

          // AI 汇总结果（流式纯文本预览 + 完成后 Markdown）
          if (this.summaryText.length > 0) {
            if (this.summarizing) {
              Text(this.summaryText.length > 3000 ?
                '…' + this.summaryText.substring(this.summaryText.length - 3000) : this.summaryText)
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .lineHeight(24)
                .width('100%')
                .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, bottom: 8 })
            } else {
              ChatMarkdownText({ content: this.summaryText, onLinkTap: (url: string): void => { this.openUrl(url); } })
                .width('100%')
                .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, bottom: 8 })
            }
          }

          // 结果列表
          List({ space: 10 }) {
            ForEach(this.items, (item: NewsItem) => {
              ListItem() {
                NewsCard({
                  item: item,
                  read: false,
                  onOpen: (opened: NewsItem): void => { this.openDetail(opened); }
                })
              }
            }, (item: NewsItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 4, bottom: 12 })
        }
        .width('100%')
        .height('100%')
      } else if (this.searched) {
        Text('请输入关键词开始搜索')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 40 })
      } else {
        Column({ space: 10 }) {
          Text('🔍')
            .fontSize(44)
            .fontFamily(this.themeState.palette.fontSans)
          Text('搜索多源新闻（HN + 内置源）')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .width('100%')
        .padding({ top: 60 })
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

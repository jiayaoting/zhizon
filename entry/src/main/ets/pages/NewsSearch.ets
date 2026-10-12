// 智子 - 热榜搜索（已加载榜单 + 收藏 + 离线正文缓存 + AI 汇总）
// 设计文档：doc/newsnow-redesign.md §9.5
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { HotEntry, HotItem, HotDetailRouteParams } from '../common/HotModels';
import { HotFeedStore } from '../service/hot/HotFeedStore';
import { NewsRepository, HotSearchHit } from '../service/hot/NewsRepository';
import { NewsAiService } from '../service/hot/NewsAiService';
import { ChatMarkdownText } from '../components/ChatMarkdownText';
import { LlmConfig, LlmResult } from '../common/LlmModels';

// 搜索结果行（含来源标记）
class SearchRow {
  entry: HotEntry;
  origin: string;   // 榜单 / 收藏 / 缓存

  constructor(entry: HotEntry, origin: string) {
    this.entry = entry;
    this.origin = origin;
  }
}

@ComponentV2
@Entry
export struct NewsSearchPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local keyword: string = '';
  // 搜索范围：all=全部 / board=已加载榜单 / local=收藏与离线缓存
  @Local scope: string = 'all';
  @Local rows: SearchRow[] = [];
  @Local searching: boolean = false;
  @Local searched: boolean = false;
  @Local errorText: string = '';
  @Local summaryText: string = '';
  @Local summarizing: boolean = false;

  private async doSearch(): Promise<void> {
    const q: string = this.keyword.trim();
    if (q.length === 0) {
      promptAction.showToast({ message: '请输入搜索关键词' });
      return;
    }
    this.searching = true;
    this.errorText = '';
    this.summaryText = '';
    const out: SearchRow[] = [];
    const lower: string = q.toLowerCase();

    // 1) 已加载榜单（内存过滤，零网络）
    if (this.scope === 'all' || this.scope === 'board') {
      const loaded: HotEntry[] = HotFeedStore.allLoadedEntries();
      for (let i: number = 0; i < loaded.length && out.length < 60; i++) {
        const e: HotEntry = loaded[i];
        if (e.item.title.toLowerCase().indexOf(lower) >= 0 ||
          e.item.info.toLowerCase().indexOf(lower) >= 0) {
          out.push(new SearchRow(e, '榜单'));
        }
      }
    }

    // 2) 收藏（FTS 优先，回退 LIKE）
    if (this.scope === 'all' || this.scope === 'local') {
      const favs: HotSearchHit[] = await NewsRepository.searchFavorites(q, 30);
      for (let i: number = 0; i < favs.length; i++) {
        out.push(new SearchRow(NewsSearchPage.toEntry(favs[i]), '收藏'));
      }
      // 3) 离线正文缓存
      const arts: HotSearchHit[] = await NewsRepository.searchArticles(q, 30);
      for (let i: number = 0; i < arts.length; i++) {
        out.push(new SearchRow(NewsSearchPage.toEntry(arts[i]), '缓存'));
      }
    }

    this.rows = out;
    this.searching = false;
    this.searched = true;
    if (out.length === 0) {
      this.errorText = this.scope === 'board' ?
        '已加载榜单中没有匹配条目（可切到「全部」搜索收藏与缓存）' : '没有找到相关内容，换个关键词试试';
    }
  }

  private static toEntry(hit: HotSearchHit): HotEntry {
    const item: HotItem = new HotItem(hit.key, hit.title, hit.url, hit.url, 0, hit.info);
    return new HotEntry(hit.key, item, hit.sourceId, hit.sourceName);
  }

  private openDetail(entry: HotEntry): void {
    AppNavigator.push('pages/NewsDetail', new HotDetailRouteParams(entry.key, entry.sourceId,
      entry.sourceName, entry.item.title, entry.item.url, entry.item.info));
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

  // AI 汇总当前搜索结果
  private async summarize(): Promise<void> {
    if (this.rows.length === 0 || this.summarizing) return;
    const has: boolean = await NewsAiService.hasModel();
    if (!has) {
      promptAction.showToast({ message: '请先在「我的 → AI 模型」配置模型' });
      return;
    }
    const config: LlmConfig | null = await NewsAiService.getActiveConfig();
    if (config === null) {
      promptAction.showToast({ message: '请先配置可用模型' });
      return;
    }
    const entries: HotEntry[] = [];
    for (let i: number = 0; i < this.rows.length; i++) entries.push(this.rows[i].entry);
    this.summarizing = true;
    this.summaryText = '';
    try {
      const result: LlmResult = await NewsAiService.generateSearchSummary(config, entries, this.keyword,
        (delta: string) => {
          this.summaryText = this.summaryText + delta;
        });
      if (!result.success && this.summaryText.length === 0) {
        promptAction.showToast({ message: result.errorMessage.length > 0 ? result.errorMessage : 'AI 汇总失败' });
      }
    } catch (e) {
      promptAction.showToast({ message: 'AI 汇总失败，请重试' });
    }
    this.summarizing = false;
  }

  @Builder
  scopeBar() {
    Row({ space: 8 }) {
      this.scopeChip('all', '全部')
      this.scopeChip('board', '榜单')
      this.scopeChip('local', '收藏·缓存')
      Blank()
      if (this.rows.length > 0) {
        Row({ space: 4 }) {
          Text(this.summarizing ? '汇总中…' : 'AI 汇总')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(14)
        .backgroundColor(this.themeState.palette.primaryBg)
        .onClick(() => {
          this.summarize();
        })
      }
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  scopeChip(key: string, label: string) {
    Text(label)
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.scope === key ? this.themeState.palette.textPrimary : this.themeState.palette.textSecondary)
      .fontWeight(this.scope === key ? FontWeight.Bold : FontWeight.Normal)
      .height(32)
      .padding({ left: 14, right: 14 })
      .borderRadius(16)
      .backgroundColor(this.scope === key ? this.themeState.palette.primaryBgStrong : this.themeState.palette.bgSurface2)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.scope = key;
      })
  }

  @Builder
  resultRow(row: SearchRow) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(row.entry.item.title)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Row({ space: 6 }) {
          Text(row.origin)
            .fontSize(this.themeState.palette.fsXs - 1)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .borderRadius(6)
            .backgroundColor(this.themeState.palette.primaryBg)
          Text(row.entry.sourceName +
            (row.entry.item.info.length > 0 ? ' · ' + row.entry.item.info : ''))
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('↗')
        .fontSize(this.themeState.palette.fsMd)
        .fontColor(this.themeState.palette.textTertiary)
        .padding(8)
        .accessibilityText('打开链接')
        .onClick(() => {
          this.openUrl(row.entry.item.url);
        })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      TopBar({ title: '搜索热榜', showBack: true })

      // 搜索输入
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '输入关键词，搜索榜单 / 收藏 / 缓存' })
          .layoutWeight(1)
          .height(40)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(20)
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            this.doSearch();
          })
        Text('搜索')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor(this.themeState.palette.primary)
          .onClick(() => {
            this.doSearch();
          })
      }
      .width('100%')
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 6 })
      .alignItems(VerticalAlign.Center)

      this.scopeBar()

      // AI 汇总结果
      if (this.summaryText.length > 0) {
        Column() {
          ChatMarkdownText({ content: this.summaryText })
        }
        .width('100%')
        .constraintSize({ maxHeight: 260 })
        .padding(12)
        .margin({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8 })
        .borderRadius(12)
        .backgroundColor(this.themeState.palette.bgSurface2)
      }

      if (this.searching) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(32)
            .height(32)
          Text('搜索中…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorText.length > 0) {
        Column({ space: 10 }) {
          Text('🔍')
            .fontSize(40)
          Text(this.errorText)
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.rows, (row: SearchRow) => {
            ListItem() {
              this.resultRow(row)
            }
            .onClick(() => {
              this.openDetail(row.entry);
            })
          }, (row: SearchRow) => row.entry.key + ':' + row.origin)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 10, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

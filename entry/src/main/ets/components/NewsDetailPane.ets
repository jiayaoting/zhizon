// 智子 - 新闻详情阅读面板（平板双栏右侧使用；ArkWeb 原文 + 收藏/已读 + 离线缓存回退）
import { webview } from '@kit.ArkWeb';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { NewsItem } from '../common/NewsModels';
import { NewsRepository } from '../service/NewsRepository';
import { NewsArticleCacheEntry } from '../service/DatabaseHelper';

function formatPaneTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number) => n < 10 ? '0' + n.toString() : n.toString();
  return (d.getMonth() + 1).toString() + '-' + d.getDate().toString() + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

@ComponentV2
export struct NewsDetailPane {
  @Param item: NewsItem = new NewsItem('', '', '', '', '', '', '', '', 0);
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local favorited: boolean = false;
  @Local webFailed: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.loadState();
  }

  aboutToDisappear(): void {
    // Web 组件随面板销毁
  }

  private async loadState(): Promise<void> {
    if (this.item.url.length === 0) return;
    try {
      this.favorited = await NewsRepository.isFavorite(this.item.url);
      await NewsRepository.markRead(this.item.url);
    } catch (e) {
    }
  }

  private async toggleFavorite(): Promise<void> {
    try {
      const fav: boolean = await NewsRepository.toggleFavorite(this.item);
      this.favorited = fav;
      promptAction.showToast({ message: fav ? '已收藏' : '已取消收藏' });
    } catch (e) {
    }
  }

  // 页面加载完成：缓存正文（离线回退用）
  private cacheArticleHtml(): void {
    if (this.item.url.length === 0) return;
    try {
      this.controller.runJavaScript('document.documentElement.outerHTML',
        (error: BusinessError, result: string): void => {
          if (error !== null && error !== undefined) return;
          const html: string = result === undefined ? '' : result;
          if (html.length < 500 || html.length > 800 * 1024) return;
          NewsRepository.saveArticleCache(this.item.url, this.item.title, html).catch(() => {
          });
        });
    } catch (e) {
    }
  }

  private useCachedArticle(): void {
    if (this.item.url.length === 0) {
      this.webFailed = true;
      return;
    }
    NewsRepository.getArticleCache(this.item.url).then((cached: NewsArticleCacheEntry | null) => {
      if (cached !== null && cached.html.length > 0) {
        try {
          this.controller.loadData(cached.html, 'text/html', 'UTF-8', this.item.url);
        } catch (e) {
          this.webFailed = true;
        }
      } else {
        this.webFailed = true;
      }
    }).catch(() => {
      this.webFailed = true;
    });
  }

  build() {
    Column() {
      // 头部
      Column({ space: 6 }) {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(this.item.title)
              .fontSize(this.themeState.palette.fsLg)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 8 }) {
              Text(this.item.sourceName)
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
              Text(formatPaneTime(this.item.publishedAt))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.favorited ? '⭐' : '☆')
            .fontSize(this.themeState.palette.fsXl)
            .fontFamily(this.themeState.palette.fontSans)
            .padding(8)
            .onClick(() => { this.toggleFavorite(); })
        }
        .width('100%')

        if (this.item.summary.length > 0) {
          Text(this.item.summary)
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })

      // 正文
      Column() {
        if (!this.webFailed && this.item.url.length > 0) {
          Web({ src: this.item.url, controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .onPageEnd(() => { this.cacheArticleHtml(); })
            .onErrorReceive(() => { this.useCachedArticle(); })
        } else {
          Column({ space: 10 }) {
            Text('📄')
              .fontSize(40)
              .fontFamily(this.themeState.palette.fontSans)
            Text('原文加载失败，且暂无离线缓存')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

// 智子 - 点踩标签选择面板（底部弹层，默认不选中任何标签）
// 规则：勾选标签 → 所选标签负向加权；不勾选直接确认 → 仅本篇降权
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { NewsItem } from '../common/NewsModels';

@ComponentV2
export struct NewsDislikePanel {
  @Param item: NewsItem = new NewsItem('', '', '', '', '', '', '', '', 0);
  @Event onConfirm: (item: NewsItem, tags: string[]) => void = () => {};
  @Event onCancel: () => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local selected: string[] = [];

  aboutToAppear(): void {
    // 每次打开默认不选中任何标签
    this.selected = [];
  }

  private isSelected(tag: string): boolean {
    return this.selected.indexOf(tag) >= 0;
  }

  private toggle(tag: string): void {
    const idx: number = this.selected.indexOf(tag);
    if (idx >= 0) {
      const next: string[] = this.selected.slice();
      next.splice(idx, 1);
      this.selected = next;
    } else {
      this.selected = this.selected.concat([tag]);
    }
  }

  private confirm(): void {
    this.onConfirm(this.item, this.selected.slice());
  }

  build() {
    Stack() {
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.onCancel(); })

      Column({ space: 12 }) {
        Row() {
          Text('👎 减少哪些内容？')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('✕')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .padding(6)
            .onClick(() => { this.onCancel(); })
        }
        .width('100%')

        Text('勾选的标签类新闻以后会减少推送；不勾选直接确认，则仅减少本篇。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')

        if (this.item.tags !== undefined && this.item.tags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.item.tags, (tag: string) => {
              Row({ space: 4 }) {
                Text(this.isSelected(tag) ? '☑' : '☐')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.isSelected(tag) ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
                Text('#' + tag)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.isSelected(tag) ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
              }
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.isSelected(tag) ? this.themeState.palette.primary + '2A' :
                GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
              .border({ width: this.isSelected(tag) ? 1 : 0,
                color: this.isSelected(tag) ? this.themeState.palette.primary : Color.Transparent })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.toggle(tag); })
            }, (tag: string) => tag)
          }
          .width('100%')
        } else {
          Text('该文章暂无标签，将仅减少本篇推荐。')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
        }

        Row({ space: 10 }) {
          Button('取消')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.onCancel(); })
          Button('确认减少')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.danger)
            .borderRadius(10)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.confirm(); })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius({ topLeft: 18, topRight: 18 })
      .backgroundColor(this.themeState.palette.bgBase)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
  }
}

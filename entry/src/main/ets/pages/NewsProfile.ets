// 智子 - 个性化画像（兴趣/厌恶标签权重管理 + 屏蔽恢复 + 重置）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NewsProfileService, NewsProfileSnapshot } from '../service/NewsProfileService';
import { NewsRepository } from '../service/NewsRepository';

interface TagWeight {
  tag: string;
  weight: number;
}

@ComponentV2
@Entry
export struct NewsProfilePage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local posTags: TagWeight[] = [];
  @Local negTags: TagWeight[] = [];
  @Local excludedCount: number = 0;

  aboutToAppear(): void {
    this.loadProfile();
  }

  aboutToDisappear(): void {
    // 单次加载，无持久资源需要释放
  }

  private async loadProfile(): Promise<void> {
    try {
      const p: NewsProfileSnapshot = await NewsProfileService.getProfile();
      const pos: TagWeight[] = [];
      const posKeys: string[] = Object.keys(p.posTags);
      for (let i: number = 0; i < posKeys.length; i++) {
        const w: number = p.posTags[posKeys[i]];
        if (w > 0) pos.push({ tag: posKeys[i], weight: w } as TagWeight);
      }
      pos.sort((a: TagWeight, b: TagWeight) => b.weight - a.weight);
      const neg: TagWeight[] = [];
      const negKeys: string[] = Object.keys(p.negTags);
      for (let i: number = 0; i < negKeys.length; i++) {
        const w: number = p.negTags[negKeys[i]];
        if (w > 0) neg.push({ tag: negKeys[i], weight: w } as TagWeight);
      }
      neg.sort((a: TagWeight, b: TagWeight) => b.weight - a.weight);
      this.posTags = pos;
      this.negTags = neg;
      const excluded: string[] = await NewsRepository.listExcludedUrls();
      this.excludedCount = excluded.length;
    } catch (e) {
      this.posTags = [];
      this.negTags = [];
      this.excludedCount = 0;
    }
  }

  private async removeNeg(tag: string): Promise<void> {
    await NewsProfileService.removeNegTag(tag);
    promptAction.showToast({ message: '已恢复「' + tag + '」类推送' });
    this.loadProfile();
  }

  private async restoreExcluded(): Promise<void> {
    if (this.excludedCount === 0) return;
    await NewsRepository.clearExclusions();
    promptAction.showToast({ message: '已恢复被屏蔽的文章' });
    this.loadProfile();
  }

  private async resetAll(): Promise<void> {
    promptAction.showDialog({
      title: '重置推荐画像',
      message: '将清空全部兴趣/厌恶标签权重与被屏蔽文章，推荐回到初始状态。此操作不可撤销。',
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '重置', color: '#E84026' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        NewsRepository.resetProfile().then(() => {
          NewsRepository.clearExclusions().then(() => {
            promptAction.showToast({ message: '已重置推荐画像' });
            this.loadProfile();
          });
        });
      }
    }).catch(() => {
    });
  }

  @Builder
  tagChip(entry: TagWeight, removable: boolean) {
    Row({ space: 4 }) {
      Text('#' + entry.tag + ' ×' + entry.weight.toString())
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(removable ? this.themeState.palette.danger : this.themeState.palette.primary)
      if (removable) {
        Text('✕')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .onClick(() => { this.removeNeg(entry.tag); })
      }
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .borderRadius(14)
    .backgroundColor(removable ? this.themeState.palette.danger + '1A' :
      GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
    .margin({ right: 8, bottom: 8 })
  }

  build() {
    Column() {
      TopBar({ title: '个性化画像', subtitle: '点赞/点踩正在影响推荐', showBack: true })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('👍 兴趣标签（点赞累积，按权重排序）')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            if (this.posTags.length === 0) {
              Text('暂无点赞记录，去资讯页点赞感兴趣的内容吧')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.posTags, (entry: TagWeight) => {
                  this.tagChip(entry, false)
                }, (entry: TagWeight) => entry.tag)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Text('👎 厌恶标签（点踩累积，点击 ✕ 恢复该类推送）')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            if (this.negTags.length === 0) {
              Text('暂无点踩记录')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.negTags, (entry: TagWeight) => {
                  this.tagChip(entry, true)
                }, (entry: TagWeight) => entry.tag)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          .alignItems(HorizontalAlign.Start)

          Row() {
            Column({ space: 4 }) {
              Text('被屏蔽的文章')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text(this.excludedCount > 0 ? '共 ' + this.excludedCount.toString() + ' 篇（点踩未选标签时屏蔽）' : '暂无被屏蔽文章')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('恢复')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(this.themeState.palette.primary)
              .borderRadius(14)
              .height(32)
              .enabled(this.excludedCount > 0)
              .onClick(() => { this.restoreExcluded(); })
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          .alignItems(VerticalAlign.Center)

          Button('重置推荐画像')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.danger)
            .borderRadius(10)
            .height(40)
            .width('100%')
            .onClick(() => { this.resetAll(); })

          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
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

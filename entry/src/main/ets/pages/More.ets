import { AppConstants, MoreItem, ToolboxItem } from '../common/Constants';
import { PageKey } from '../common/Navigation';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct MorePage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  onSelectEntry: (key: PageKey) => void = () => {};

  build() {
    Column() {
      Text('更多')
        .fontSize(20)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24,
          top: this.statusBarHeight + 16, bottom: 16 })
      if (AppConstants.moreItems.length === 0) {
        Column() {
          Text('暂无更多功能')
            .fontSize(14)
            .fontColor(this.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(AppConstants.moreItems, (item: MoreItem) => {
              Row({ space: 12 }) {
                Text(item.icon).fontSize(24)
                Column({ space: 3 }) {
                  Text(item.label)
                    .fontSize(14)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(item.desc)
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›').fontSize(18).fontColor(this.palette.textTertiary)
              }
              .width('100%')
              .padding(14)
              .borderRadius(8)
              .backgroundColor(this.palette.bgSurface)
              .border({ width: 1, color: this.palette.borderSubtle })
              .onClick(() => {
                this.onSelectEntry(item.key);
              })
            }, (item: MoreItem) => item.key)

            Text('工具功能')
              .fontSize(13)
              .fontColor(this.palette.textSecondary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: 8 })

            ForEach(AppConstants.toolboxItems, (item: ToolboxItem) => {
              Row({ space: 12 }) {
                Text(item.icon).fontSize(24)
                Column({ space: 3 }) {
                  Text(item.label)
                    .fontSize(14)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(item.desc)
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›').fontSize(18).fontColor(this.palette.textTertiary)
              }
              .width('100%')
              .padding(14)
              .borderRadius(8)
              .backgroundColor(this.palette.bgSurface)
              .border({ width: 1, color: this.palette.borderSubtle })
              .onClick(() => {
                this.onSelectEntry(item.key);
              })
            }, (item: ToolboxItem) => item.key)
          }
          .padding(this.isSm ? 16 : 24)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

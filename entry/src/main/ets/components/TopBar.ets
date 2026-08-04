// 智子 - 通用组件：顶栏
import { AppTheme } from '../common/Theme';
import { router } from '@kit.ArkUI';

@Component
export struct TopBar {
  @Prop title: string;
  @Prop subtitle: string = '';
  @Prop showBack: boolean = false;
  @BuilderParam actions: () => void = this.emptyActions;

  @Builder emptyActions() {}

  build() {
    Row({ space: 12 }) {
      // 返回箭头（可选，用 emoji 避免 sys.symbol 兼容性问题）
      if (this.showBack) {
        Row() {
          Text('‹')
            .fontSize(22)
            .fontColor(AppTheme.textSecondary)
            .fontWeight(FontWeight.Bold)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor(AppTheme.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => router.back())
      }

      Column() {
        Text(this.title)
          .fontSize(20)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(AppTheme.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.actions()
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }
}

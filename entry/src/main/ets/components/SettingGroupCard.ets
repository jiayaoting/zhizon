// 智子 - 通用分组卡片（v10：华为拟物白白卡；设置 / 我的等页面共用）
// 契约保持不变：@Param title + 尾随 @BuilderParam content
// V2（P4）：入参统一 @Param，全局 UI 状态走 themeState（AppStorageV2）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';

@ComponentV2
export struct SettingGroupCard {
  @Param title: string = '';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: this.themeState.palette.sp3 }) {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(this.themeState.palette.fsMd)
          .fontColor(this.themeState.palette.textPrimary)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      this.content()
    }
    .width('100%')
    .padding(this.themeState.palette.sp4)
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(HorizontalAlign.Start)
  }
}

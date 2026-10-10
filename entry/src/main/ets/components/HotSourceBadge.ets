// 智子 - 源徽标（首字 + 源配色圆角块）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { HotSources } from '../common/HotSources';

@ComponentV2
export struct HotSourceBadge {
  @Param sourceId: string = '';
  @Param badgeSize: number = 28;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // 徽标文字：站点名首字（NewsNow 用图标，此处用文字徽标替代）
  private label(): string {
    const name: string = HotSources.nameOf(this.sourceId);
    if (name.length === 0) return '?';
    // 英文名取首字母大写，中文取首字
    const first: string = name.substring(0, 1);
    return /[a-zA-Z]/.test(first) ? first.toUpperCase() : first;
  }

  build() {
    Stack() {
      Column()
        .width(this.badgeSize)
        .height(this.badgeSize)
        .borderRadius(this.badgeSize * 0.28)
        .backgroundColor(HotSources.colorOf(this.sourceId))
      Text(this.label())
        .fontSize(this.badgeSize * 0.5)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
    }
    .width(this.badgeSize)
    .height(this.badgeSize)
  }
}

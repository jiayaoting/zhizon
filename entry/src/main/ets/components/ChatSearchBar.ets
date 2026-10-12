// 智子 - 会话内搜索栏 + 搜索无结果空态（v10 超大页拆分：自 pages/Chat.ets 原样抽出）
// 契约：@Param query / role / resultCount
//       @Event onQueryChange(value) / onRoleChange(role) / onExit()
// 说明：只承载 UI（搜索输入行 / 角色筛选胶囊 / 无结果空态），
//       搜索检索（loadSearchResults）与消息源同步（syncMessageSource）仍由宿主页执行。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct ChatSearchBar {
  @Param query: string = '';          // 搜索关键词（宿主持有，回传后由宿主更新）
  @Param role: string = 'all';        // 当前角色筛选：all / user / assistant
  @Param resultCount: number = 0;     // 当前筛选命中条数（宿主计算）
  @Event onQueryChange: (value: string) => void = () => {};
  @Event onRoleChange: (role: string) => void = () => {};
  @Event onExit: () => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  @Builder
  filterChip(label: string, roleValue: string) {
    Row() {
      Text(label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.role === roleValue ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
        .fontWeight(this.role === roleValue ? FontWeight.Medium : FontWeight.Normal)
    }
    .height(32)
    .padding({ left: 14, right: 14 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.role === roleValue ? this.themeState.palette.primaryBgStrong : this.themeState.palette.bgSurface2)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => { this.onRoleChange(roleValue); })
  }

  build() {
    Column({ space: this.themeState.palette.sp2 }) {
      Row({ space: this.themeState.palette.sp2 }) {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(AppIcons.search)
            .fontSize(18)
            .fontColor([this.themeState.palette.textTertiary])
        } else {
          Text(AppIcons.searchEmoji)
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
        }
        TextInput({ text: this.query, placeholder: '搜索对话记录…' })
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .placeholderColor(this.themeState.palette.textTertiary)
          .backgroundColor(Color.Transparent)
          .height(40)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.onQueryChange(value);
          })
        Row() {
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(AppIcons.close)
              .fontSize(18)
              .fontColor([this.themeState.palette.textTertiary])
          } else {
            Text(AppIcons.closeEmoji)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('退出搜索')
        .onClick(() => { this.onExit(); })
      }
      .width('100%')
      .padding({ left: 12, right: 4 })
      .height(44)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .borderRadius(this.themeState.palette.radiusCapsule)

      Row({ space: 6 }) {
        this.filterChip('全部', 'all')
        this.filterChip('用户', 'user')
        this.filterChip('助手', 'assistant')
        Blank()
        Text('共 ' + this.resultCount.toString() + ' 条')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp2 })
  }
}

// 搜索无结果空态（会话内搜索命中 0 条时占位）
@ComponentV2
export struct ChatSearchEmpty {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  build() {
    Column({ space: this.themeState.palette.sp2 }) {
      Text('🔍')
        .fontSize(36)
        .fontFamily(this.themeState.palette.fontSans)
      Text('未找到匹配的对话')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
      Text('试试其他关键词或筛选条件')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 60, bottom: 40 })
  }
}

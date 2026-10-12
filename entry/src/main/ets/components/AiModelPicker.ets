// 智子 - 模型切换半模态（可复用：AI 对话页 / 详情页）
// 契约：@Param visible / models / followGlobal / activeModelId / currentName
//       @Event onSelect(id) / onClose()
// 说明：只做「切换」，不进入模型配置（配置入口固定为 我的 → AI 模型）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { LlmModelEntry, modelDisplayName } from '../common/LlmModels';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct AiModelPicker {
  @Param visible: boolean = false;
  @Param models: LlmModelEntry[] = [];
  @Param followGlobal: boolean = true;   // 当前是否「跟随全局模型」（未单独指定）
  @Param activeModelId: string = '';     // 已单独指定的模型 id
  @Param currentName: string = '';       // 当前生效模型显示名（用于副标题）
  @Event onSelect: (id: string) => void = () => {};
  @Event onClose: () => void = () => {};
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // 模型列表行（华为式 56vp 行 + 选中 primaryBg 高亮 + 主色对勾）
  @Builder
  row(label: string, sub: string, selected: boolean, onTap: () => void) {
    Row({ space: this.themeState.palette.sp3 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (sub.length > 0) {
          Text(sub)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (selected) {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(AppIcons.check)
            .fontSize(20)
            .fontColor([this.themeState.palette.primary])
        } else {
          Text(AppIcons.checkEmoji)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
        }
      }
    }
    .width('100%')
    .height(this.themeState.palette.rowHeight)
    .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3 })
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(selected ? this.themeState.palette.primaryBg : Color.Transparent)
    .onClick(onTap)
  }

  build() {
    if (this.visible) {
      Stack() {
        Column() {
          Blank()
          Column({ space: this.themeState.palette.sp1 }) {
            Row() {
              Row()
                .width(36)
                .height(4)
                .borderRadius(2)
                .backgroundColor(this.themeState.palette.borderStrong)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 10, bottom: 4 })

            Row() {
              Text('切换模型')
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(AppIcons.close)
                    .fontSize(20)
                    .fontColor([this.themeState.palette.textSecondary])
                } else {
                  Text(AppIcons.closeEmoji)
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textSecondary)
                }
              }
              .width(this.themeState.palette.touchTarget)
              .height(this.themeState.palette.touchTarget)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .accessibilityText('关闭')
              .onClick(() => { this.onClose(); })
            }
            .width('100%')
            .padding({ bottom: this.themeState.palette.sp1 })

            Scroll() {
              Column({ space: 0 }) {
                // 跟随全局模型：清除单独指定，与全局激活模型保持一致
                this.row('跟随全局模型',
                  this.followGlobal ? '当前生效：' + this.currentName : '不单独指定，与全局模型保持一致',
                  this.followGlobal,
                  (): void => { this.onSelect(''); })
                ForEach(this.models, (m: LlmModelEntry) => {
                  this.row(modelDisplayName(m), m.model,
                    !this.followGlobal && m.id === this.activeModelId,
                    (): void => { this.onSelect(m.id); })
                }, (m: LlmModelEntry) => m.id)
                if (this.models.length === 0) {
                  Column({ space: this.themeState.palette.sp1 }) {
                    Text('没有可用模型')
                      .fontSize(this.themeState.palette.fsMd)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textPrimary)
                    Text('请到「我的 → AI 模型」完成配置后再切换')
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                  .padding({ left: this.themeState.palette.sp3, top: this.themeState.palette.sp4,
                    bottom: this.themeState.palette.sp4 })
                }
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: 360 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.themeState.navBarHeight) })
          .backgroundColor(this.themeState.palette.bgElevated)
          .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.maskOverlay)
      .onClick(() => { this.onClose(); })
    }
  }
}

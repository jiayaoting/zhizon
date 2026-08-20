// 智子 - 新闻 AI 模型选择器（资讯功能专属模型，切换后记忆到 settings.newsModelId）
// 样式与 AI 对话页模型选择统一：玻璃卡片触发按钮 + 底部圆角选择面板
import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { LlmModelEntry } from '../common/LlmModels';
import { NewsAiService } from '../service/NewsAiService';
import { DataRepository } from '../service/DataRepository';

@ComponentV2
export struct NewsModelSelector {
  // 记忆的 settings key：newsModelId（资讯）/ newsTranslateModelId（翻译）/ newsTagModelId（智能标签）
  @Param settingKey: string = 'newsModelId';
  // 空选择时的文案：资讯用「跟随全局模型」；翻译/标签用「跟随资讯模型」
  @Param followLabel: string = '跟随全局模型';
  @Param followDesc: string = '使用「我的 → AI 模型」中的默认模型';
  // 紧凑模式：隐藏 🤖 图标、缩小字号与高度（用于空间紧张的页面如 AI 今日要闻）
  @Param compact: boolean = false;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local modelName: string = '跟随全局';
  @Local selectedId: string = '';
  @Local showSheet: boolean = false;
  @Local models: LlmModelEntry[] = [];

  aboutToAppear(): void {
    this.refresh();
  }

  aboutToDisappear(): void {
    this.showSheet = false;
  }

  private async refresh(): Promise<void> {
    try {
      this.models = await NewsAiService.listModels();
      this.selectedId = await DataRepository.getSetting(this.settingKey, '');
      if (this.selectedId.length === 0) {
        this.modelName = this.followLabel;
      } else {
        let found: string = '';
        for (let i: number = 0; i < this.models.length; i++) {
          if (this.models[i].id === this.selectedId) {
            found = this.models[i].displayName.length > 0 ? this.models[i].displayName : this.models[i].model;
            break;
          }
        }
        this.modelName = found.length > 0 ? found : this.followLabel;
      }
    } catch (e) {
      this.modelName = '未配置模型';
    }
  }

  private async pick(id: string): Promise<void> {
    // id 为空 = 恢复「跟随」（清空该功能专属记忆）
    if (this.settingKey === 'newsModelId') {
      await NewsAiService.selectModel(id);
    } else if (this.settingKey === 'newsTranslateModelId') {
      await NewsAiService.selectTranslateModel(id);
    } else {
      await DataRepository.setSetting(this.settingKey, id);
    }
    this.showSheet = false;
    await this.refresh();
  }

  // ==================== 底部选择面板（与 AI 对话页 modelPicker 风格一致） ====================
  @Builder
  modelSheet() {
    Column() {
      // 拖拽条
      Row()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor(this.themeState.palette.borderSubtle)
        .margin({ top: 10, bottom: 6 })

      // 标题行
      Row() {
        Text('选择模型')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('✕')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .padding(8)
          .onClick(() => { this.showSheet = false; })
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 8 })

      // 模型列表
      if (this.models.length > 0) {
        Scroll() {
          Column({ space: 4 }) {
            // 「跟随全局」选项：清空资讯专属记忆
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(this.followLabel)
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.selectedId.length === 0 ? this.themeState.palette.primary :
                    this.themeState.palette.textPrimary)
                  .fontWeight(this.selectedId.length === 0 ? FontWeight.Bold : FontWeight.Medium)
                Text(this.followDesc)
                  .fontSize(10)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.selectedId.length === 0) {
                Text('✓')
                  .fontSize(16)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.primary)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(this.selectedId.length === 0 ? this.themeState.palette.primaryDim :
              this.themeState.palette.bgSurface)
            .border({ width: this.selectedId.length === 0 ? 1 : 0,
              color: this.selectedId.length === 0 ? this.themeState.palette.primary : Color.Transparent })
            .onClick(() => { this.pick(''); })

            ForEach(this.models, (m: LlmModelEntry) => {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(m.displayName.length > 0 ? m.displayName : m.model)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textPrimary)
                    .fontWeight(m.id === this.selectedId ? FontWeight.Bold : FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(m.model)
                    .fontSize(10)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (m.id === this.selectedId) {
                  Text('✓')
                    .fontSize(16)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                    .fontWeight(FontWeight.Bold)
                }
              }
              .width('100%')
              .padding(12)
              .borderRadius(8)
              .backgroundColor(m.id === this.selectedId ? this.themeState.palette.primaryDim :
                this.themeState.palette.bgSurface)
              .border({ width: m.id === this.selectedId ? 1 : 0,
                color: m.id === this.selectedId ? this.themeState.palette.primary : Color.Transparent })
              .onClick(() => { this.pick(m.id); })
            }, (m: LlmModelEntry) => m.id)
          }
          .width('100%')
        }
        .width('100%')
        .scrollBar(BarState.Off)
        .constraintSize({ maxHeight: 360 })
      } else {
        Text('没有已启用的模型，请到「我的 → AI 模型」中启用')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .padding({ top: 16, bottom: 16 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: Math.max(16, this.themeState.navBarHeight) })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    // 触发按钮：与 AI 对话页「当前模型切换」一致的玻璃卡片样式
    Row({ space: 4 }) {
      if (!this.compact) {
        Text('🤖')
          .fontSize(12)
          .fontFamily(this.themeState.palette.fontSans)
      }
      Text(this.modelName)
        .fontSize(this.compact ? 10 : 11)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('▾')
        .fontSize(this.compact ? 9 : 10)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .height(this.compact ? 30 : 34)
    .padding({ left: this.compact ? 8 : 10, right: this.compact ? 8 : 10, top: this.compact ? 4 : 6, bottom: this.compact ? 4 : 6 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .backgroundBlurStyle(this.themeState.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.models.length === 0) {
        this.refresh();
      }
      this.showSheet = true;
    })
    .bindSheet($$this.showSheet, this.modelSheet(), {
      height: 440,
      dragBar: false,
      showClose: false,
      backgroundColor: this.themeState.palette.bgBase,
      // 圆角需用 radius + LengthMetrics（与本项目 GameAIPanel 一致）
      radius: { topStart: LengthMetrics.vp(16), topEnd: LengthMetrics.vp(16) }
    })
  }
}

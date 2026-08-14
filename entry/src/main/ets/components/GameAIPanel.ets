// 智子 - 游戏 AI 托管面板（模型选择 / 速度控制 / 启停）
import { LengthMetrics } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { AI_SPEED_OPTIONS } from '../service/GameAIService';

@Component
export struct GameAIPanel {
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @Prop modelNames: string[] = [];
  @Prop selectedModelIndex: number = 0;
  @Prop running: boolean = false;
  @Prop status: string = '';
  @Prop speedIndex: number = 2;
  @Prop modelsConfigured: boolean = true;
  // 思考统计（仅 2048 / 扫雷 传入；其余游戏保持 0 不显示）
  @Prop thinkingCount: number = 0;
  @Prop thinkingFailCount: number = 0;
  // 本轮思考已用时间（毫秒，由托管方实时刷新）
  @Prop thinkingTimeMs: number = 0;
  onSelectModel: (index: number) => void = () => {};
  onToggleRun: () => void = () => {};
  onSpeedChange: (index: number) => void = () => {};
  @State showModelSheet: boolean = false;

  build() {
    Column({ space: 6 }) {
      // 第一行：模型选择 + 启停
      Row({ space: 8 }) {
        Text('🤖')
          .fontSize(15)
          .fontFamily(this.palette.fontSans)
        // 模型名称（点击弹出完整模型列表）
        Text(this.currentModelLabel())
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.modelsConfigured ? this.palette.textPrimary : this.palette.textTertiary)
          .maxLines(this.modelsConfigured ? 2 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(6)
          .onClick(() => {
            if (!this.modelsConfigured || this.modelNames.length === 0) return;
            this.showModelSheet = true;
          })
          .bindSheet($$this.showModelSheet, this.modelSheetBuilder(), {
            height: '70%',
            dragBar: true,
            showClose: true,
            backgroundColor: this.palette.bgBase,
            // 显式指定弹窗顶部圆角（LengthMetrics 类型），避免系统内部解析 radius 报类型错误
            radius: { topStart: LengthMetrics.vp(20), topEnd: LengthMetrics.vp(20) }
          })
        Row() {
          Text(this.running ? '⏹ 停止' : '▶ AI 托管')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(14)
        .backgroundColor(this.running ? this.palette.danger : this.palette.primary)
        .onClick(() => {
          if (!this.modelsConfigured) return;
          this.onToggleRun();
        })
      }
      .width('100%')

      // 第二行：状态（推理/思考中实时显示本轮思考时间）+ 速度档位 —— 右对齐
      Row({ space: 6 }) {
        Text(this.running ? this.status : '点击「AI 托管」让模型替你游玩')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.running ? this.palette.primary : this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.End)
          .layoutWeight(1)
        if (this.running && this.isThinking()) {
          Text(this.formatThinkTime(this.thinkingTimeMs))
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.primary)
            .fontWeight(FontWeight.Medium)
        }
        ForEach(AI_SPEED_OPTIONS, (label: string, index: number) => {
          Text(label)
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(index === this.speedIndex ? Color.White : this.palette.textSecondary)
            .fontWeight(index === this.speedIndex ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(8)
            .backgroundColor(index === this.speedIndex ? this.palette.primary : this.palette.bgSurface2)
            .onClick(() => {
              if (this.running) return;
              this.onSpeedChange(index);
            })
        }, (label: string) => label)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 第三行：思考统计（总次数 / 失败次数）—— 右对齐，有数据时才显示
      if (this.thinkingCount > 0 || this.thinkingFailCount > 0) {
        Row({ space: 8 }) {
          if (this.thinkingCount > 0) {
            Text('思考 ' + this.thinkingCount.toString() + ' 次')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
          }
          if (this.thinkingFailCount > 0) {
            Text('失败 ' + this.thinkingFailCount.toString() + ' 次')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.danger)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  // 模型选择底部弹窗：完整展示所有模型名称，当前模型高亮标记
  @Builder
  modelSheetBuilder() {
    Column({ space: 8 }) {
      Text('选择 AI 模型')
        .fontSize(this.palette.fsBase)
        .fontWeight(FontWeight.Bold)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .alignSelf(ItemAlign.Start)
        .padding({ left: 4, top: 4 })
      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.modelNames, (name: string, index: number) => {
            Row({ space: 8 }) {
              Text(name)
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .layoutWeight(1)
              if (index === this.selectedModelIndex) {
                Text('使用中')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor(this.palette.primaryDim)
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor(index === this.selectedModelIndex ? this.palette.primaryDim : this.palette.bgSurface2)
            .onClick(() => {
              this.onSelectModel(index);
              this.showModelSheet = false;
            })
          }, (name: string, index: number) => index.toString())
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }

  private currentModelLabel(): string {
    if (!this.modelsConfigured) return '未配置模型';
    if (this.modelNames.length === 0) return '未配置模型';
    const idx: number = this.selectedModelIndex >= 0 && this.selectedModelIndex < this.modelNames.length
      ? this.selectedModelIndex : 0;
    return '模型：' + this.modelNames[idx] + ' ›';
  }

  // 是否处于思考/推理状态（此时在状态后展示本轮实时耗时）
  private isThinking(): boolean {
    return this.status.indexOf('思考') >= 0 || this.status.indexOf('推理') >= 0;
  }

  // 毫秒 → 秒（一位小数）
  private formatThinkTime(ms: number): string {
    return (ms / 1000).toFixed(1) + 's';
  }
}

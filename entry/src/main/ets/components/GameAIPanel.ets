// 智子 - 游戏 AI 托管面板（模型选择 / 速度控制 / 启停）
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
  onSelectModel: (index: number) => void = () => {};
  onToggleRun: () => void = () => {};
  onSpeedChange: (index: number) => void = () => {};

  build() {
    Column({ space: 6 }) {
      // 第一行：模型选择 + 启停
      Row({ space: 8 }) {
        Text('🤖')
          .fontSize(15)
          .fontFamily(this.palette.fontSans)
        // 模型名称（点击循环切换）
        Text(this.currentModelLabel())
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.modelsConfigured ? this.palette.textPrimary : this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(6)
          .onClick(() => {
            if (this.running || !this.modelsConfigured || this.modelNames.length === 0) return;
            this.onSelectModel((this.selectedModelIndex + 1) % this.modelNames.length);
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

      // 第二行：状态 + 速度档位
      Row({ space: 8 }) {
        Text(this.running ? this.status : '点击「AI 托管」让模型替你游玩')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.running ? this.palette.primary : this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
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
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  private currentModelLabel(): string {
    if (!this.modelsConfigured) return '未配置模型';
    if (this.modelNames.length === 0) return '未配置模型';
    const idx: number = this.selectedModelIndex >= 0 && this.selectedModelIndex < this.modelNames.length
      ? this.selectedModelIndex : 0;
    return '模型：' + this.modelNames[idx] + ' ›';
  }
}

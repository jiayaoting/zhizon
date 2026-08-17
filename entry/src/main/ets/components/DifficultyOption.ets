import { DifficultyDefinition, DifficultyLevel } from '../common/Difficulty';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';

@ComponentV2
export struct DifficultyOption {
  @Param definition: DifficultyDefinition = new DifficultyDefinition(DifficultyLevel.MEDIUM, '中等', '🤔', '经典体验');
  @Param selected: boolean = false;
  @Param disabled: boolean = false;
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onSelect: (level: DifficultyLevel) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.definition.icon)
        .fontSize(24)
        .fontFamily(this.themeState.palette.fontSans)
        .width(32)
      Column({ space: 3 }) {
        Text(this.definition.label)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.disabled ? this.themeState.palette.textTertiary : this.themeState.palette.textPrimary)
          .fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
        Text(this.definition.description)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.selected) {
        Text('✓')
          .fontSize(16)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeState.palette.primary)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(8)
    .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themeState.palette.primary : this.themeState.palette.borderDefault })
    .backgroundColor(this.selected ? this.themeState.palette.primaryDim : this.themeState.palette.bgSurface)
    .opacity(this.disabled ? 0.5 : 1)
    .accessibilityText(this.definition.label + (this.selected ? '，已选中' : ''))
    .onClick(() => {
      if (!this.disabled) this.onSelect(this.definition.level);
    })
  }
}

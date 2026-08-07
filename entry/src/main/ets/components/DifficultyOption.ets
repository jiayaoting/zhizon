import { DifficultyDefinition, DifficultyLevel } from '../common/Difficulty';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct DifficultyOption {
  @Prop definition: DifficultyDefinition;
  @Prop selected: boolean = false;
  @Prop disabled: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  onSelect: (level: DifficultyLevel) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.definition.icon)
        .fontSize(24)
        .width(32)
      Column({ space: 3 }) {
        Text(this.definition.label)
          .fontSize(this.palette.fsMd)
          .fontColor(this.disabled ? this.palette.textTertiary : this.palette.textPrimary)
          .fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
        Text(this.definition.description)
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.selected) {
        Text('✓')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette.primary)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(8)
    .border({ width: this.selected ? 2 : 1, color: this.selected ? this.palette.primary : this.palette.borderDefault })
    .backgroundColor(this.selected ? this.palette.primaryDim : this.palette.bgSurface)
    .opacity(this.disabled ? 0.5 : 1)
    .accessibilityText(this.definition.label + (this.selected ? '，已选中' : ''))
    .onClick(() => {
      if (!this.disabled) this.onSelect(this.definition.level);
    })
  }
}

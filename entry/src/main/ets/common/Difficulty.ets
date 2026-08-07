export enum DifficultyLevel {
  VERY_EASY = 'VERY_EASY',
  EASY = 'EASY',
  MEDIUM = 'MEDIUM',
  HARD = 'HARD',
  HELL = 'HELL'
}

export class DifficultyDefinition {
  level: DifficultyLevel;
  label: string;
  icon: string;
  description: string;

  constructor(level: DifficultyLevel, label: string, icon: string, description: string) {
    this.level = level;
    this.label = label;
    this.icon = icon;
    this.description = description;
  }
}

export const DIFFICULTY_DEFINITIONS: DifficultyDefinition[] = [
  new DifficultyDefinition(DifficultyLevel.VERY_EASY, '超简单', '😊', '轻松上手'),
  new DifficultyDefinition(DifficultyLevel.EASY, '简单', '🙂', '节奏舒缓'),
  new DifficultyDefinition(DifficultyLevel.MEDIUM, '中等', '🤔', '经典体验'),
  new DifficultyDefinition(DifficultyLevel.HARD, '困难', '😈', '快速挑战'),
  new DifficultyDefinition(DifficultyLevel.HELL, '地狱', '💀', '极限速度')
];

export function difficultyLabel(level: DifficultyLevel): string {
  for (const definition of DIFFICULTY_DEFINITIONS) {
    if (definition.level === level) return definition.label;
  }
  return '中等';
}

// 智子 - 成就系统数据模型与成就定义

export class AchievementDefinition {
  id: string;
  name: string;
  desc: string;
  icon: string;
  category: string;
  target: number;
  unit: string;

  constructor(id: string, name: string, desc: string, icon: string, category: string,
    target: number, unit: string) {
    this.id = id;
    this.name = name;
    this.desc = desc;
    this.icon = icon;
    this.category = category;
    this.target = target;
    this.unit = unit;
  }
}

export class AchievementState {
  id: string;
  unlocked: boolean;
  progress: number;
  unlockedAt: number;

  constructor(id: string, unlocked: boolean, progress: number, unlockedAt: number) {
    this.id = id;
    this.unlocked = unlocked;
    this.progress = progress;
    this.unlockedAt = unlockedAt;
  }
}

// 成就定义表：progress 为累计值，达到 target 即解锁
export const ACHIEVEMENT_DEFINITIONS: AchievementDefinition[] = [
  new AchievementDefinition('first_game', '初次体验', '完成任意一局游戏', '🎮', '游戏', 1, '局'),
  new AchievementDefinition('game_10', '渐入佳境', '累计完成 10 局游戏', '🎯', '游戏', 10, '局'),
  new AchievementDefinition('game_50', '游戏达人', '累计完成 50 局游戏', '🏆', '游戏', 50, '局'),
  new AchievementDefinition('game_100', '百局老手', '累计完成 100 局游戏', '👑', '游戏', 100, '局'),
  new AchievementDefinition('score_2048_2048', '2048 达成', '2048 单局达到 2048 分', '🔢', '游戏', 2048, '分'),
  new AchievementDefinition('snake_100', '贪吃蛇进阶', '贪吃蛇单局达到 100 分', '🐍', '游戏', 100, '分'),
  new AchievementDefinition('tetris_1000', '方块大师', '俄罗斯方块单局达到 1000 分', '🧱', '游戏', 1000, '分'),
  new AchievementDefinition('gomoku_win', '五子棋首胜', '五子棋取得一场胜利', '⚫', '游戏', 1, '胜'),
  new AchievementDefinition('chess_win', '象棋首胜', '中国象棋取得一场胜利', '♟️', '游戏', 1, '胜'),
  new AchievementDefinition('ai_host_1', 'AI 托管体验', '使用 1 次游戏 AI 托管', '🤖', '游戏', 1, '次'),
  new AchievementDefinition('ai_host_10', 'AI 托管常客', '累计使用 10 次游戏 AI 托管', '🦾', '游戏', 10, '次'),
  new AchievementDefinition('chat_1', '初次对话', '发送第一条 AI 对话', '💬', '对话', 1, '条'),
  new AchievementDefinition('chat_50', '聊天爱好者', '累计发送 50 条对话', '💡', '对话', 50, '条'),
  new AchievementDefinition('chat_200', '深度交流', '累计发送 200 条对话', '🌐', '对话', 200, '条')
];

// 根据 id 查找定义，未找到返回 null
export function achievementDefinition(id: string): AchievementDefinition | null {
  for (let i: number = 0; i < ACHIEVEMENT_DEFINITIONS.length; i++) {
    if (ACHIEVEMENT_DEFINITIONS[i].id === id) return ACHIEVEMENT_DEFINITIONS[i];
  }
  return null;
}

export function achievementCategoryLabel(category: string): string {
  if (category === '游戏') return '🎮 游戏';
  return '💬 对话';
}

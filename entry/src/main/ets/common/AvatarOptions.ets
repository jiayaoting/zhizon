// 智子 - 头像选项配置
// 首页右上角头像支持多款预设样式与自定义图片

export interface AvatarOption {
  id: string;         // 持久化标识
  label: string;      // 显示名称
  style: string;      // 风格描述
  colors: string[];   // 渐变颜色（纯色时两个相同）
}

export const CUSTOM_AVATAR_ID: string = 'custom';

export const AVATAR_OPTIONS: AvatarOption[] = [
  { id: 'liquid', label: '液态渐变', style: '青绿到紫，流动渐变', colors: ['#00D9A3', '#8B5CF6'] },
  { id: 'bright', label: '明亮渐变', style: '青绿到蓝，清爽渐变', colors: ['#00D9A3', '#3B82F6'] },
  { id: 'aurora', label: '极光紫', style: '紫到粉，梦幻渐变', colors: ['#8B5CF6', '#EC4899'] },
  { id: 'sunset', label: '日落橙', style: '橙到红，温暖渐变', colors: ['#F59E0B', '#EF4444'] },
  { id: 'ocean', label: '海洋蓝', style: '蓝到天蓝，静谧渐变', colors: ['#3B82F6', '#0EA5E9'] },
  { id: 'forest', label: '自然绿', style: '绿到黄绿，清新渐变', colors: ['#10B981', '#84CC16'] },
  { id: 'classic', label: '经典蓝', style: '纯色蓝底 + 白字', colors: ['#3B82F6', '#3B82F6'] }
];

export function avatarLabel(id: string): string {
  for (let i: number = 0; i < AVATAR_OPTIONS.length; i++) {
    if (AVATAR_OPTIONS[i].id === id) return AVATAR_OPTIONS[i].label;
  }
  if (id === CUSTOM_AVATAR_ID) return '自定义图片';
  return '液态渐变';
}

export function isSupportedAvatar(id: string): boolean {
  if (id === CUSTOM_AVATAR_ID) return true;
  for (let i: number = 0; i < AVATAR_OPTIONS.length; i++) {
    if (AVATAR_OPTIONS[i].id === id) return true;
  }
  return false;
}

export function avatarColors(id: string): string[] {
  for (let i: number = 0; i < AVATAR_OPTIONS.length; i++) {
    if (AVATAR_OPTIONS[i].id === id) return AVATAR_OPTIONS[i].colors;
  }
  return ['#00D9A3', '#8B5CF6'];
}

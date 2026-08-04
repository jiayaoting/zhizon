// 智子 - 主题颜色与样式常量

export class AppTheme {
  // 背景色
  static readonly bgBase = '#0A0E1A';
  static readonly bgSurface = '#131826';
  static readonly bgSurface2 = '#1A2030';
  static readonly bgElevated = '#232A3D';
  static readonly bgHover = '#2A3349';

  // 边框
  static readonly borderSubtle = '#1E293B';
  static readonly borderDefault = '#2D3748';
  static readonly borderStrong = '#3D4A63';

  // 文字
  static readonly textPrimary = '#E2E8F0';
  static readonly textSecondary = '#94A3B8';
  static readonly textTertiary = '#64748B';

  // 主色 - 终端青绿
  static readonly primary = '#00D9A3';
  static readonly primaryHover = '#00F0B5';
  static readonly primaryDim = 'rgba(0, 217, 163, 0.15)';

  // 状态色
  static readonly success = '#10B981';
  static readonly warning = '#F59E0B';
  static readonly danger = '#EF4444';
  static readonly info = '#3B82F6';
  static readonly purple = '#8B5CF6';

  // 圆角
  static readonly radiusSm = '4vp';
  static readonly radiusMd = '6vp';
  static readonly radiusLg = '10vp';
  static readonly radiusXl = '14vp';

  // 间距
  static readonly sp1 = '4vp';
  static readonly sp2 = '8vp';
  static readonly sp3 = '12vp';
  static readonly sp4 = '16vp';
  static readonly sp5 = '20vp';
  static readonly sp6 = '24vp';
  static readonly sp8 = '32vp';

  // 字号
  static readonly fsXs = 10;
  static readonly fsSm = 12;
  static readonly fsBase = 13;
  static readonly fsMd = 14;
  static readonly fsLg = 16;
  static readonly fsXl = 20;
  static readonly fs2xl = 26;
  static readonly fs3xl = 32;

  // 字体
  static readonly fontSans = ' sans-serif';
  static readonly fontMono = 'JetBrains Mono, Fira Code, Consolas, Courier New, monospace';
}

// 进度条颜色阈值
export function progressColor(value: number): string {
  if (value >= 85) return AppTheme.danger;
  if (value >= 65) return AppTheme.warning;
  return AppTheme.success;
}

// 状态文本映射
export interface StatusInfo {
  text: string;
  color: string;
  dotColor: string;
}

export function statusInfo(status: string): StatusInfo {
  const map: Record<string, StatusInfo> = {
    online: { text: '在线', color: AppTheme.success, dotColor: AppTheme.success },
    warning: { text: '告警', color: AppTheme.warning, dotColor: AppTheme.warning },
    offline: { text: '离线', color: AppTheme.textTertiary, dotColor: AppTheme.textTertiary },
    running: { text: '运行中', color: AppTheme.success, dotColor: AppTheme.success },
    stopped: { text: '已停止', color: AppTheme.danger, dotColor: AppTheme.danger },
    paused: { text: '已暂停', color: AppTheme.warning, dotColor: AppTheme.warning },
    success: { text: '成功', color: AppTheme.success, dotColor: AppTheme.success },
    failed: { text: '失败', color: AppTheme.danger, dotColor: AppTheme.danger },
    active: { text: '可用', color: AppTheme.success, dotColor: AppTheme.success }
  };
  return map[status] || map.offline;
}

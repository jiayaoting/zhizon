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
  static readonly fontSans = 'sans-serif';
  static readonly fontMono = 'JetBrains Mono, Fira Code, Consolas, Courier New, monospace';
}

// 进度条颜色阈值
export function progressColor(value: number): string {
  if (value >= 85) return AppTheme.danger;
  if (value >= 65) return AppTheme.warning;
  return AppTheme.success;
}

// 状态文本映射
export class StatusInfo {
  text: string;
  color: string;
  dotColor: string;

  constructor(text: string, color: string, dotColor: string) {
    this.text = text;
    this.color = color;
    this.dotColor = dotColor;
  }
}

export function statusInfo(status: string): StatusInfo {
  const map = new Map<string, StatusInfo>();
  map.set('online', new StatusInfo('在线', AppTheme.success, AppTheme.success));
  map.set('warning', new StatusInfo('告警', AppTheme.warning, AppTheme.warning));
  map.set('offline', new StatusInfo('离线', AppTheme.textTertiary, AppTheme.textTertiary));
  map.set('running', new StatusInfo('运行中', AppTheme.success, AppTheme.success));
  map.set('stopped', new StatusInfo('已停止', AppTheme.danger, AppTheme.danger));
  map.set('paused', new StatusInfo('已暂停', AppTheme.warning, AppTheme.warning));
  map.set('success', new StatusInfo('成功', AppTheme.success, AppTheme.success));
  map.set('failed', new StatusInfo('失败', AppTheme.danger, AppTheme.danger));
  map.set('active', new StatusInfo('可用', AppTheme.success, AppTheme.success));
  return map.get(status) || map.get('offline')!;
}

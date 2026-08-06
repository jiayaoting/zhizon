// 智子 - 全局常量

export class AppConstants {
  // 应用信息
  static readonly appName = '智子';
  static readonly appVersion = '1.0.0';
  static readonly bundleName = 'com.zhizon.manager';

  // 存储
  static readonly prefsName = 'zhizon_prefs';
  static readonly dbName = 'zhizon_db';

  // 网络
  static readonly defaultSshPort = 22;
  static readonly defaultPvePort = 8006;
  static readonly connectTimeout = 30000;
  static readonly keepAliveInterval = 30;

  // 导航页面列表（用 emoji 字符串避免 sys.symbol 兼容性问题）
  static readonly navItems: NavItem[] = [
    { key: 'Index', label: '总览', icon: '📊' },
    { key: 'Servers', label: 'SSH 服务器', icon: '🖥️' },
    { key: 'Pve', label: 'PVE 集群', icon: '🗂️' },
    { key: 'Terminal', label: 'SSH 终端', icon: '⌨️' },
    { key: 'Files', label: '文件管理', icon: '📁' },
    { key: 'Commands', label: '快捷命令', icon: '⚡' },
    { key: 'Batch', label: '批量操作', icon: '🔄' },
    { key: 'Alerts', label: '告警中心', icon: '🔔' },
    { key: 'Settings', label: '设置', icon: '⚙️' },
    { key: 'Games', label: '游戏中心', icon: '🎮' }
  ];
}

export interface NavItem {
  key: string;
  label: string;
  icon: string;
}

// 通用尺寸
export const PAGE_PADDING = 24;
export const CARD_RADIUS = 10;
export const SIDEBAR_WIDTH = 220;

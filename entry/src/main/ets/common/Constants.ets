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

  // 导航页面列表
  static readonly navItems: NavItem[] = [
    { key: 'Index', label: '总览', icon: $r('sys.symbol.grid') },
    { key: 'Servers', label: 'SSH 服务器', icon: $r('sys.symbol.server') },
    { key: 'Pve', label: 'PVE 集群', icon: $r('sys.symbol.rectangle_stack') },
    { key: 'Terminal', label: 'SSH 终端', icon: $r('sys.symbol.terminal') },
    { key: 'Files', label: '文件管理', icon: $r('sys.symbol.folder') },
    { key: 'Commands', label: '快捷命令', icon: $r('sys.symbol.command') },
    { key: 'Batch', label: '批量操作', icon: $r('sys.symbol.layers') },
    { key: 'Alerts', label: '告警中心', icon: $r('sys.symbol.bell') },
    { key: 'Settings', label: '设置', icon: $r('sys.symbol.gearshape') }
  ];
}

export interface NavItem {
  key: string;
  label: string;
  icon: Resource;
}

// 通用尺寸
export const PAGE_PADDING = 24;
export const CARD_RADIUS = 10;
export const SIDEBAR_WIDTH = 220;

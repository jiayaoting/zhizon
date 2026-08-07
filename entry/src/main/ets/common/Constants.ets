// 智子 - 全局常量（沉浸光感重构版）
import { ColorThemeId } from './Theme';

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

  // 新版导航：精简为 5 主 + 1 更多结构
  static readonly navItems: NavItem[] = [
    { key: 'Index', label: '首页', icon: '🏠' },
    { key: 'Servers', label: '服务器', icon: '🖥️' },
    { key: 'Pve', label: 'PVE 集群', icon: '🗂️' },
    { key: 'Toolbox', label: '工具箱', icon: '🧰' },
    { key: 'Alerts', label: '告警', icon: '🔔' },
    { key: 'Settings', label: '设置', icon: '⚙️' }
  ];

  // 工具箱子页面
  static readonly toolboxItems: ToolboxItem[] = [
    { key: 'Terminal', label: 'SSH 终端', icon: '⌨️', desc: '远程终端连接' },
    { key: 'Files', label: '文件管理', icon: '📁', desc: 'SFTP 文件传输' },
    { key: 'Commands', label: '快捷命令', icon: '⚡', desc: '命令库管理' },
    { key: 'Batch', label: '批量操作', icon: '🔄', desc: '多服务器执行' },
    { key: 'Games', label: '游戏中心', icon: '🎮', desc: '休闲小游戏' }
  ];

  // 更多菜单项（手机端）
  static readonly moreItems: NavItem[] = [
    { key: 'Alerts', label: '告警', icon: '🔔' },
    { key: 'Settings', label: '设置', icon: '⚙️' }
  ];
}

export interface NavItem {
  key: string;
  label: string;
  icon: string;
}

export interface ToolboxItem {
  key: string;
  label: string;
  icon: string;
  desc: string;
}

// 通用尺寸
export const PAGE_PADDING = 24;
export const CARD_RADIUS = 10;
export const SIDEBAR_WIDTH = 220;

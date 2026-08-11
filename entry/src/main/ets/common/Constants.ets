// 智子 - 全局常量
import { ColorThemeId } from './Theme';
import { MainNavKey, PageKey } from './Navigation';

export class NavItem {
  key: MainNavKey;
  label: string;
  icon: string;

  constructor(key: MainNavKey, label: string, icon: string) {
    this.key = key;
    this.label = label;
    this.icon = icon;
  }
}

export class ToolboxItem {
  key: PageKey;
  label: string;
  icon: string;
  desc: string;

  constructor(key: PageKey, label: string, icon: string, desc: string) {
    this.key = key;
    this.label = label;
    this.icon = icon;
    this.desc = desc;
  }
}

export class MoreItem {
  key: PageKey;
  label: string;
  icon: string;
  desc: string;

  constructor(key: PageKey, label: string, icon: string, desc: string) {
    this.key = key;
    this.label = label;
    this.icon = icon;
    this.desc = desc;
  }
}

export class AppConstants {
  // 应用信息
  static readonly appName = '智子';
  static readonly appVersion = '1.0.0';
  static readonly bundleName = 'com.zhizon.manager';

  // 存储
  static readonly prefsName = 'zhizon_prefs';
  static readonly dbName = 'zhizon_db';

  static readonly navItems: NavItem[] = [
    new NavItem(MainNavKey.Index, '首页', '🏠'),
    new NavItem(MainNavKey.Toolbox, '工具箱', '🧰'),
    new NavItem(MainNavKey.More, '更多', '⋯')
  ];

  // 工具箱子页面
  static readonly toolboxItems: ToolboxItem[] = [
    new ToolboxItem(PageKey.Commands, '快捷命令', '⚡', '命令库管理'),
    new ToolboxItem(PageKey.Games, '游戏中心', '🎮', '休闲小游戏')
  ];

  static readonly moreItems: MoreItem[] = [
    new MoreItem(PageKey.Alerts, '告警', '🔔', '查看和处理系统告警'),
    new MoreItem(PageKey.Settings, '设置', '⚙️', '主题、背景与应用设置')
  ];
}

// 通用尺寸
export const PAGE_PADDING = 24;
export const CARD_RADIUS = 10;
export const SIDEBAR_WIDTH = 220;

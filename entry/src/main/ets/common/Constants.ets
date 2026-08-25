// 智子 - 全局常量
import { ColorThemeId } from './Theme';
import { MainNavKey } from './Navigation';

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

export class AppConstants {
  // 应用信息
  static readonly appName = '智子';
  static readonly appVersion = '1.0.0';
  static readonly bundleName = 'com.zhizon.manager';

  // 存储
  static readonly prefsName = 'zhizon_prefs';
  static readonly dbName = 'zhizon_db';

  static readonly navItems: NavItem[] = [
    new NavItem(MainNavKey.Index, '资讯', '📰'),
    new NavItem(MainNavKey.Chat, 'AI对话', '🗨️'),
    new NavItem(MainNavKey.Games, '游戏', '🎮'),
    new NavItem(MainNavKey.BettaFish, '微舆', '🐟'),
    new NavItem(MainNavKey.Profile, '我的', '👤')
  ];
}

// 通用尺寸
export const PAGE_PADDING = 24;
export const CARD_RADIUS = 10;
export const SIDEBAR_WIDTH = 220;

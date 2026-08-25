// 智子 - 设置项数据模型（数据驱动渲染 + 搜索过滤）
export enum SettingRowKind {
  NAV = 'NAV',
  SWITCH = 'SWITCH'
}

export enum SettingActionId {
  NONE = 0,
  ACCOUNT = 1,
  AUTO_BACKUP = 2,
  APPEARANCE = 3,
  NEWS = 4,
  GAME = 5,
  AGENT = 6,
  MASTER_PASSWORD = 7,
  BIOMETRIC = 8,
  AUTO_LOCK = 9,
  CLEAR_READ = 10,
  CLEAR_CACHE = 11,
  ABOUT_UPDATE = 12,
  ABOUT_AGREEMENT = 13,
  ABOUT_PRIVACY = 14,
  ABOUT_LICENSE = 15,
  ABOUT_FEEDBACK = 16,
  READING_REPORT = 17,
  AI_ROLES = 18,
  BETTA_SERVER = 19,
  BETTA_SYSTEM = 20
}

export class SettingItem {
  key: string;
  title: string;
  icon: string;
  value: string;
  desc: string;
  kind: SettingRowKind;
  danger: boolean;
  action: SettingActionId;
  showArrow: boolean;

  constructor(key: string, title: string, icon: string, value: string, desc: string,
    kind: SettingRowKind, danger: boolean, action: SettingActionId, showArrow: boolean = true) {
    this.key = key;
    this.title = title;
    this.icon = icon;
    this.value = value;
    this.desc = desc;
    this.kind = kind;
    this.danger = danger;
    this.action = action;
    this.showArrow = showArrow;
  }
}

export class SettingGroup {
  key: string;
  title: string;
  items: SettingItem[];

  constructor(key: string, title: string, items: SettingItem[]) {
    this.key = key;
    this.title = title;
    this.items = items;
  }
}

// 搜索匹配：标题 / 描述 / 当前值（忽略大小写）
export function settingMatches(item: SettingItem, keyword: string): boolean {
  const k: string = keyword.trim().toLowerCase();
  if (k.length === 0) return true;
  if (item.title.toLowerCase().indexOf(k) >= 0) return true;
  if (item.desc.toLowerCase().indexOf(k) >= 0) return true;
  if (item.value.toLowerCase().indexOf(k) >= 0) return true;
  return false;
}

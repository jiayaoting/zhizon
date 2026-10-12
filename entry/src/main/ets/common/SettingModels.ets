// 智子 - 设置项数据模型（数据驱动渲染 + 搜索过滤）
// v10：行图标改为「矢量优先 + emoji 回退」（与 AppIcons 一致）；
// 枚举按 §3.4.4 边界收敛：数据操作（清空阅读记录 / 清空热榜缓存）已收敛到
// 热榜设置 → 数据，阅读周报主入口收敛到 我的 → 阅读周报，均已从本枚举移除。
export enum SettingRowKind {
  NAV = 'NAV',
  SWITCH = 'SWITCH'
}

export enum SettingActionId {
  NONE = 0,
  ACCOUNT = 1,
  AUTO_BACKUP = 2,
  BACKUP_NOW = 3,
  RESTORE_NOW = 4,
  APPEARANCE = 5,
  NEWS = 6,
  GAME = 7,
  AGENT = 8,
  MASTER_PASSWORD = 9,
  BIOMETRIC = 10,
  AUTO_LOCK = 11,
  BETTA_SERVER = 12,
  BETTA_SYSTEM = 13,
  ABOUT_UPDATE = 14,
  ABOUT_AGREEMENT = 15,
  ABOUT_PRIVACY = 16,
  ABOUT_LICENSE = 17,
  ABOUT_FEEDBACK = 18
}

export class SettingItem {
  key: string;
  title: string;
  symbol: Resource;   // 左矢量图标（SymbolGlyph）
  icon: string;       // 矢量不可用时的 emoji 回退
  value: string;
  desc: string;
  kind: SettingRowKind;
  danger: boolean;
  action: SettingActionId;
  showArrow: boolean;

  constructor(key: string, title: string, symbol: Resource, icon: string, value: string, desc: string,
    kind: SettingRowKind, danger: boolean, action: SettingActionId, showArrow: boolean = true) {
    this.key = key;
    this.title = title;
    this.symbol = symbol;
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

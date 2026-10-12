// 智子 - 图标中心（v10）
// 设计规范：导航/操作用系统矢量符号（SymbolGlyph，单色可染色），内容区保留 emoji 点缀。
//
// 回退开关：若真机上出现图标空白（系统符号名不匹配），把 USE_SYMBOL_ICONS 改为 false，
// 全站导航/操作图标会立即回退为 emoji（每个图标都配了 *Emoji 字段），无需改各页面。
export const USE_SYMBOL_ICONS: boolean = true;

// 图标资源（必须使用字面量 $r，故仅此处集中声明）
const S_HOME: Resource = $r('sys.symbol.house');
const S_CHAT: Resource = $r('sys.symbol.message');
const S_GAME: Resource = $r('sys.symbol.gamecontroller');
const S_BETTA: Resource = $r('sys.symbol.water_waves');
const S_PERSON: Resource = $r('sys.symbol.person');
const S_SEARCH: Resource = $r('sys.symbol.magnifyingglass');
const S_SETTINGS: Resource = $r('sys.symbol.gearshape');
const S_BACK: Resource = $r('sys.symbol.chevron_left');
const S_FORWARD: Resource = $r('sys.symbol.chevron_right');
const S_MORE: Resource = $r('sys.symbol.more');
const S_SHARE: Resource = $r('sys.symbol.share');
const S_STAR: Resource = $r('sys.symbol.star');
const S_STAR_FILL: Resource = $r('sys.symbol.star_fill');
const S_REFRESH: Resource = $r('sys.symbol.arrow_clockwise');
const S_ADD: Resource = $r('sys.symbol.plus');
const S_TRASH: Resource = $r('sys.symbol.trash');
const S_CHECK: Resource = $r('sys.symbol.checkmark');
const S_CLOSE: Resource = $r('sys.symbol.xmark');
const S_CLOCK: Resource = $r('sys.symbol.clock');
const S_CALENDAR: Resource = $r('sys.symbol.calendar');
const S_CHART: Resource = $r('sys.symbol.ranking');
const S_TROPHY: Resource = $r('sys.symbol.medal');
const S_MIC: Resource = $r('sys.symbol.mic');
const S_GLOBE: Resource = $r('sys.symbol.website');
const S_PHOTO: Resource = $r('sys.symbol.camera');
const S_DOC: Resource = $r('sys.symbol.doc_text');
const S_BOOKMARK: Resource = $r('sys.symbol.bookmark');
const S_HEART: Resource = $r('sys.symbol.heart');
const S_LINK: Resource = $r('sys.symbol.link');
const S_WARNING: Resource = $r('sys.symbol.exclamationmark_triangle');
const S_LIST: Resource = $r('sys.symbol.list_bullet');
const S_SLIDER: Resource = $r('sys.symbol.slider_horizontal_2');
const S_LOCK: Resource = $r('sys.symbol.lock');
const S_PLAY: Resource = $r('sys.symbol.play_fill');
const S_SPEAKER: Resource = $r('sys.symbol.speaker_wave_2');
const S_SERVER: Resource = $r('sys.symbol.externaldrive');
const S_DOWNLOAD: Resource = $r('sys.symbol.arrow_down_circle');
const S_UPLOAD: Resource = $r('sys.symbol.arrow_up_circle');

// 语义化图标集合（页面/组件统一从这里取，保证"一个图标一个含义"）
export class AppIcons {
  // 主导航
  static readonly navHot: Resource = S_HOME;
  static readonly navChat: Resource = S_CHAT;
  static readonly navGame: Resource = S_GAME;
  static readonly navBetta: Resource = S_BETTA;
  static readonly navProfile: Resource = S_PERSON;
  // 通用操作
  static readonly back: Resource = S_BACK;
  static readonly forward: Resource = S_FORWARD;
  static readonly more: Resource = S_MORE;
  static readonly search: Resource = S_SEARCH;
  static readonly settings: Resource = S_SETTINGS;
  static readonly share: Resource = S_SHARE;
  static readonly star: Resource = S_STAR;
  static readonly starFill: Resource = S_STAR_FILL;
  static readonly refresh: Resource = S_REFRESH;
  static readonly add: Resource = S_ADD;
  static readonly trash: Resource = S_TRASH;
  static readonly check: Resource = S_CHECK;
  static readonly close: Resource = S_CLOSE;
  static readonly clock: Resource = S_CLOCK;
  static readonly calendar: Resource = S_CALENDAR;
  static readonly chart: Resource = S_CHART;
  static readonly trophy: Resource = S_TROPHY;
  static readonly mic: Resource = S_MIC;
  static readonly globe: Resource = S_GLOBE;
  static readonly photo: Resource = S_PHOTO;
  static readonly doc: Resource = S_DOC;
  static readonly bookmark: Resource = S_BOOKMARK;
  static readonly heart: Resource = S_HEART;
  static readonly link: Resource = S_LINK;
  static readonly warning: Resource = S_WARNING;
  static readonly list: Resource = S_LIST;
  static readonly slider: Resource = S_SLIDER;
  static readonly lock: Resource = S_LOCK;
  static readonly play: Resource = S_PLAY;
  static readonly speaker: Resource = S_SPEAKER;
  static readonly server: Resource = S_SERVER;
  static readonly download: Resource = S_DOWNLOAD;
  static readonly upload: Resource = S_UPLOAD;

  // ============ emoji 回退（USE_SYMBOL_ICONS=false 时使用）============
  static readonly navHotEmoji: string = '🔥';
  static readonly navChatEmoji: string = '🗨️';
  static readonly navGameEmoji: string = '🎮';
  static readonly navBettaEmoji: string = '🐟';
  static readonly navProfileEmoji: string = '👤';
  static readonly backEmoji: string = '‹';
  static readonly forwardEmoji: string = '›';
  static readonly moreEmoji: string = '⋯';
  static readonly searchEmoji: string = '🔍';
  static readonly settingsEmoji: string = '⚙️';
  static readonly shareEmoji: string = '⤴';
  static readonly starEmoji: string = '☆';
  static readonly starFillEmoji: string = '⭐';
  static readonly refreshEmoji: string = '↻';
  static readonly addEmoji: string = '＋';
  static readonly trashEmoji: string = '🗑';
  static readonly checkEmoji: string = '✓';
  static readonly closeEmoji: string = '✕';
  static readonly clockEmoji: string = '🕐';
  static readonly calendarEmoji: string = '📅';
  static readonly chartEmoji: string = '📈';
  static readonly trophyEmoji: string = '🏆';
  static readonly micEmoji: string = '🎙';
  static readonly globeEmoji: string = '🌐';
  static readonly photoEmoji: string = '📷';
  static readonly docEmoji: string = '📄';
  static readonly bookmarkEmoji: string = '🔖';
  static readonly heartEmoji: string = '❤️';
  static readonly linkEmoji: string = '🔗';
  static readonly warningEmoji: string = '⚠️';
  static readonly listEmoji: string = '☰';
  static readonly sliderEmoji: string = '⚙';
  static readonly lockEmoji: string = '🔒';
  static readonly playEmoji: string = '▶';
  static readonly speakerEmoji: string = '🔊';
  static readonly serverEmoji: string = '🖥';
  static readonly downloadEmoji: string = '⬇';
  static readonly uploadEmoji: string = '⬆';

  // ============ 主导航图标映射（FixedBottomNav / SideNav 共用，避免重复）============
  // key 传入 MainNavKey 的字符串值；未知 key 回退到热榜图标
  static navIcon(key: string): Resource {
    if (key === 'Chat') return S_CHAT;
    if (key === 'Games') return S_GAME;
    if (key === 'BettaFish') return S_BETTA;
    if (key === 'Profile') return S_PERSON;
    return S_HOME;
  }

  static navEmoji(key: string): string {
    if (key === 'Chat') return AppIcons.navChatEmoji;
    if (key === 'Games') return AppIcons.navGameEmoji;
    if (key === 'BettaFish') return AppIcons.navBettaEmoji;
    if (key === 'Profile') return AppIcons.navProfileEmoji;
    return AppIcons.navHotEmoji;
  }
}

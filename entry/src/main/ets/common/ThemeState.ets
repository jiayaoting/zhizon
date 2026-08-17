// 智子 - V2 全局 UI 状态（AppStorageV2 迁移用）
// ThemeManager / WindowEnvironmentProvider / SecurityService / EntryAbility 会同步写入这里。
import { ThemePalette, defaultLightPalette } from './Theme';

@ObservedV2
export class ThemeState {
  @Trace palette: ThemePalette = defaultLightPalette;
  @Trace isDark: boolean = false;
  @Trace isSm: boolean = false;
  @Trace isMd: boolean = false;
  @Trace isLg: boolean = false;
  @Trace navBarHeight: number = 12;
  @Trace statusBarHeight: number = 20;
  @Trace isWideNav: boolean = false;
  @Trace glassEnabled: boolean = false;
  @Trace liquidGlassEnabled: boolean = false;
  @Trace isLandscape: boolean = false;
  @Trace globalBackgroundUri: string = '';
  @Trace backgroundCandidateUri: string = '';
  @Trace backgroundVisibleStrength: number = 50;
  @Trace backgroundDisplayState: string = 'INVALID';
  @Trace appLocked: boolean = false;
  @Trace startupState: string = 'INITIALIZING';
  @Trace followSystemDark: boolean = true;
  @Trace colorThemeId: string = 'cyan';
}

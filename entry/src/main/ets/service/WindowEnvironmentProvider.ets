import { display, window, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x9201;
const SAFE_TOP_MIN: number = 44;
const SAFE_BOTTOM_MIN: number = 24;
const BP_SM: number = 600;
const BP_LG: number = 840;

export enum WindowEnvironmentConfidence {
  EXACT = 'EXACT',
  FALLBACK = 'FALLBACK'
}

export enum WindowOrientation {
  PORTRAIT = 'PORTRAIT',
  LANDSCAPE = 'LANDSCAPE'
}

export enum WindowDeviceType {
  PHONE = 'PHONE',
  TABLET = 'TABLET',
  TWO_IN_ONE = '2IN1'
}

export enum WindowFoldState {
  UNKNOWN = 'UNKNOWN',
  EXPANDED = 'EXPANDED',
  FOLDED = 'FOLDED',
  HALF_FOLDED = 'HALF_FOLDED'
}

export class WindowEnvironmentSnapshot {
  deviceType: WindowDeviceType;
  width: number;
  height: number;
  orientation: WindowOrientation;
  foldState: WindowFoldState;
  density: number;
  safeTop: number;
  safeBottom: number;
  confidence: WindowEnvironmentConfidence;

  constructor(deviceType: WindowDeviceType, width: number, height: number, orientation: WindowOrientation,
    density: number, safeTop: number, safeBottom: number, confidence: WindowEnvironmentConfidence) {
    this.deviceType = deviceType;
    this.width = width;
    this.height = height;
    this.orientation = orientation;
    this.foldState = WindowFoldState.UNKNOWN;
    this.density = density;
    this.safeTop = safeTop;
    this.safeBottom = safeBottom;
    this.confidence = confidence;
  }
}

export class WindowEnvironmentProvider {
  private static activeProvider: WindowEnvironmentProvider | null = null;
  private attachedWindow: window.Window | null = null;
  private publishing: boolean = false;
  private currentSnapshot: WindowEnvironmentSnapshot = new WindowEnvironmentSnapshot(WindowDeviceType.PHONE,
    0, 0, WindowOrientation.PORTRAIT, 1, SAFE_TOP_MIN, SAFE_BOTTOM_MIN, WindowEnvironmentConfidence.FALLBACK);
  private currentFoldState: WindowFoldState = WindowFoldState.UNKNOWN;

  snapshot(): WindowEnvironmentSnapshot {
    return this.currentSnapshot;
  }

  isAttached(): boolean {
    return this.attachedWindow !== null && this.publishing;
  }

  attach(mainWindow: window.Window): void {
    if (this.attachedWindow === mainWindow && this.publishing) {
      this.refresh();
      return;
    }
    this.detach();
    this.attachedWindow = mainWindow;
    this.publishing = true;
    WindowEnvironmentProvider.activeProvider = this;
    try {
      mainWindow.on('avoidAreaChange', WindowEnvironmentProvider.handleAvoidAreaChange);
    } catch (error) {
      hilog.error(DOMAIN, 'WindowEnvironment',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'attach', 'SAFE_AREA', 'SAFE_AREA_LISTENER_FAILED', 'snapshot-fallback');
    }
    // 窗口尺寸变化（2in1 自由缩放 / 分屏 / 旋转）实时刷新断点，保证跨设备自适应
    try {
      mainWindow.on('windowSizeChange', WindowEnvironmentProvider.handleWindowSizeChange);
    } catch (error) {
      hilog.error(DOMAIN, 'WindowEnvironment',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'attach', 'SIZE_AREA', 'WINDOW_SIZE_LISTENER_FAILED', 'breakpoint-static');
    }
    // 折叠屏状态：读取当前状态并监听开合变化（display 模块提供，非折叠设备抛错走兜底）
    try {
      const status: display.FoldStatus = display.getFoldStatus();
      if (WindowEnvironmentProvider.activeProvider !== null) {
        WindowEnvironmentProvider.activeProvider.updateFoldState(status);
      }
      display.on('foldStatusChange', WindowEnvironmentProvider.handleFoldStatusChange);
    } catch (error) {
      hilog.error(DOMAIN, 'WindowEnvironment',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'attach', 'FOLD', 'FOLD_LISTENER_FAILED', 'fold-unknown');
    }
    this.refresh();
  }

  detach(): void {
    const currentWindow: window.Window | null = this.attachedWindow;
    this.publishing = false;
    this.attachedWindow = null;
    if (WindowEnvironmentProvider.activeProvider === this) {
      WindowEnvironmentProvider.activeProvider = null;
    }
    if (currentWindow === null) {
      return;
    }
    try {
      currentWindow.off('avoidAreaChange', WindowEnvironmentProvider.handleAvoidAreaChange);
    } catch (error) {
      hilog.error(DOMAIN, 'WindowEnvironment',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'detach', 'SAFE_AREA', 'SAFE_AREA_LISTENER_REMOVE_FAILED', 'publishing-disabled');
    }
    try {
      currentWindow.off('windowSizeChange', WindowEnvironmentProvider.handleWindowSizeChange);
    } catch (error) {
      // 尺寸监听移除失败不影响主流程
    }
    try {
      display.off('foldStatusChange', WindowEnvironmentProvider.handleFoldStatusChange);
    } catch (error) {
      // 折叠监听移除失败不影响主流程
    }
  }

  refresh(): void {
    const currentWindow: window.Window | null = this.attachedWindow;
    if (!this.publishing || currentWindow === null) {
      return;
    }
    const snapshot: WindowEnvironmentSnapshot = this.readSnapshot(currentWindow);
    if (!this.publishing || this.attachedWindow !== currentWindow) {
      return;
    }
    snapshot.foldState = this.currentFoldState;
    this.currentSnapshot = snapshot;
    AppStorage.setOrCreate('windowEnvironmentSnapshot', snapshot);
    AppStorage.setOrCreate('statusBarHeight', snapshot.safeTop);
    AppStorage.setOrCreate('navBarHeight', snapshot.safeBottom);
    AppStorage.setOrCreate('isSm', snapshot.width < BP_SM);
    AppStorage.setOrCreate('isMd', snapshot.width >= BP_SM && snapshot.width < BP_LG);
    AppStorage.setOrCreate('isLg', snapshot.width >= BP_LG);
    AppStorage.setOrCreate('isLandscape', snapshot.orientation === WindowOrientation.LANDSCAPE);
    // 侧边导航开关：按物理设备类型判定（避免手机横屏被误判为大屏）
    AppStorage.setOrCreate('isWideNav', this.resolveSideNavNeeded(snapshot.orientation));
    const themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
    themeState.statusBarHeight = snapshot.safeTop;
    themeState.navBarHeight = snapshot.safeBottom;
    themeState.isSm = snapshot.width < BP_SM;
    themeState.isMd = snapshot.width >= BP_SM && snapshot.width < BP_LG;
    themeState.isLg = snapshot.width >= BP_LG;
    themeState.isLandscape = snapshot.orientation === WindowOrientation.LANDSCAPE;
    themeState.isWideNav = this.resolveSideNavNeeded(snapshot.orientation);
  }

  // 是否使用侧边导航（大屏布局）：2in1 恒用；平板横屏用；手机无论横竖屏都不用
  private resolveSideNavNeeded(orientation: WindowOrientation): boolean {
    const dt: string = deviceInfo.deviceType;
    if (dt === '2in1' || dt === 'desktop' || dt === 'pc') return true;
    if (dt === 'tablet' || dt === 'pad') return orientation === WindowOrientation.LANDSCAPE;
    return false;
  }

  // 单独更新折叠状态（开合变化时），其余环境量不变
  private updateFoldState(status: display.FoldStatus): void {
    let state: WindowFoldState = WindowFoldState.UNKNOWN;
    if (status === display.FoldStatus.FOLD_STATUS_EXPANDED) state = WindowFoldState.EXPANDED;
    else if (status === display.FoldStatus.FOLD_STATUS_FOLDED) state = WindowFoldState.FOLDED;
    else if (status === display.FoldStatus.FOLD_STATUS_HALF_FOLDED) state = WindowFoldState.HALF_FOLDED;
    this.currentFoldState = state;
    this.currentSnapshot.foldState = state;
    AppStorage.setOrCreate('windowEnvironmentSnapshot', this.currentSnapshot);
  }

  // 窗口尺寸变化（2in1 缩放 / 分屏 / 旋转）
  private static handleWindowSizeChange(size: window.Size): void {
    if (WindowEnvironmentProvider.activeProvider !== null) {
      WindowEnvironmentProvider.activeProvider.refresh();
    }
  }

  // 折叠屏开合状态变化
  private static handleFoldStatusChange(status: display.FoldStatus): void {
    if (WindowEnvironmentProvider.activeProvider !== null) {
      WindowEnvironmentProvider.activeProvider.updateFoldState(status);
    }
  }

  private static handleAvoidAreaChange(options: window.AvoidAreaOptions): void {
    if (WindowEnvironmentProvider.activeProvider !== null) {
      WindowEnvironmentProvider.activeProvider.refresh();
    }
  }

  private readSnapshot(currentWindow: window.Window): WindowEnvironmentSnapshot {
    try {
      const currentDisplay: display.Display = display.getDefaultDisplaySync();
      const density: number = currentDisplay.densityPixels;
      if (density <= 0) {
        return this.createFallbackSnapshot();
      }
      const rect: window.Rect = currentWindow.getWindowProperties().windowRect;
      const width: number = rect.width / density;
      const height: number = rect.height / density;
      const systemArea: window.AvoidArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea: window.AvoidArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const navigationArea: window.AvoidArea =
        currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const safeTop: number = Math.max(systemArea.topRect.height / density,
        cutoutArea.topRect.height / density, SAFE_TOP_MIN);
      const safeBottom: number = Math.max(systemArea.bottomRect.height / density,
        navigationArea.bottomRect.height / density, SAFE_BOTTOM_MIN);
      return new WindowEnvironmentSnapshot(this.resolveDeviceType(width), width, height,
        this.resolveOrientation(width, height), density, safeTop, safeBottom, WindowEnvironmentConfidence.EXACT);
    } catch (error) {
      hilog.error(DOMAIN, 'WindowEnvironment',
        'operation=%{public}s category=%{public}s code=%{public}s rollback=%{public}s',
        'snapshot-read', 'SAFE_AREA', 'WINDOW_ENVIRONMENT_READ_FAILED', 'fallback');
      return this.createFallbackSnapshot();
    }
  }

  private createFallbackSnapshot(): WindowEnvironmentSnapshot {
    return new WindowEnvironmentSnapshot(WindowDeviceType.PHONE, 0, 0, WindowOrientation.PORTRAIT, 1,
      SAFE_TOP_MIN, SAFE_BOTTOM_MIN, WindowEnvironmentConfidence.FALLBACK);
  }

  private resolveDeviceType(width: number): WindowDeviceType {
    if (width >= BP_LG) {
      return WindowDeviceType.TWO_IN_ONE;
    }
    if (width >= BP_SM) {
      return WindowDeviceType.TABLET;
    }
    return WindowDeviceType.PHONE;
  }

  private resolveOrientation(width: number, height: number): WindowOrientation {
    return width > height ? WindowOrientation.LANDSCAPE : WindowOrientation.PORTRAIT;
  }
}

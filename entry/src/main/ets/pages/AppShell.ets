import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { AppConstants, ToolboxItem } from '../common/Constants';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationSuccess,
  NavigationFailure, NavigationSource, NavigationFacade, mainPage, AppShellRouteParams } from '../common/Navigation';
import { IndexPage } from './Index';
import { SettingsPage } from './Settings';
import { GamesPage } from './Games';
import { MorePage } from './More';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { FontRegistry } from '../components/FontRegistry';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { StartupState } from '../entryability/EntryAbility';
import { WindowEnvironmentConfidence, WindowEnvironmentSnapshot, WindowDeviceType,
  WindowOrientation } from '../service/WindowEnvironmentProvider';

const DOMAIN = 0x9201;

@Entry
@Component
struct AppShell {
  @State navigation: NavigationState = new NavigationState(PageKey.Index, MainNavKey.Index);
  @StorageLink('startupState') startupState: StartupState = StartupState.INITIALIZING;
  @StorageLink('windowEnvironmentSnapshot') environment: WindowEnvironmentSnapshot =
    new WindowEnvironmentSnapshot(WindowDeviceType.PHONE, 0, 0, WindowOrientation.PORTRAIT, 1, 44, 24,
      WindowEnvironmentConfidence.FALLBACK);
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @State privacyConsented: boolean = false;

  aboutToAppear(): void {
    const params: AppShellRouteParams | null = router.getParams() as AppShellRouteParams | null;
    if (params !== undefined && params !== null && params.page !== undefined) {
      const initialResult: NavigationResult = NavigationFacade.navigateLegacy(this.navigation, params.page,
        NavigationSource.INITIAL);
      this.handleNavigationResult(params.page, initialResult, false);
    }
  }

  aboutToDisappear(): void {
    // 导航容器为路由托管，无独立资源需要释放
  }

  // 返回键拦截：子页面返回首页，首页才退出到桌面
  onBackPress(): boolean {
    if (this.navigation.currentPage === PageKey.Index) {
      return false;
    }
    this.selectMain(MainNavKey.Index);
    return true;
  }

  private handleNavigationResult(key: string, result: NavigationResult, animated: boolean = true): void {
    if (!result.success) {
      const failure = result as NavigationFailure;
      hilog.error(DOMAIN, 'Navigation', '导航失败 key=%{public}s reason=%{public}s rollback=%{public}s',
        key, failure.reason, 'true');
      promptAction.showToast({ message: '页面打开失败，请重试' });
      return;
    }
    const success = result as NavigationSuccess;
    if (success.currentPage === this.navigation.currentPage) {
      this.navigation = success.nextSnapshot;
      return;
    }
    if (animated) {
      animateTo({ duration: 300, curve: Curve.Friction, delay: 0 }, () => {
        this.navigation = success.nextSnapshot;
      });
    } else {
      this.navigation = success.nextSnapshot;
    }
  }

  private selectMain(key: MainNavKey): void {
    const target = mainPage(key);
    const result = NavigationFacade.navigate(this.navigation, target, NavigationSource.MAIN_NAV);
    this.handleNavigationResult(key, result);
  }

  private selectMoreEntry(key: PageKey): void {
    if (key === PageKey.Chat) {
      router.pushUrl({ url: 'pages/Chat' });
      return;
    }
    const result = NavigationFacade.navigate(this.navigation, key, NavigationSource.ENTRY);
    this.handleNavigationResult(key, result);
  }

  private selectPage(key: string): void {
    const result = NavigationFacade.navigateLegacy(this.navigation, key, NavigationSource.LEGACY);
    this.handleNavigationResult(key, result);
  }

  private openToolboxEntry(item: ToolboxItem): void {
    if (item.key === PageKey.Chat) {
      router.pushUrl({ url: 'pages/Chat' });
      return;
    }
    this.selectPage(item.key);
  }

  @Builder
  renderPage() {
    Stack() {
      if (this.navigation.currentPage === PageKey.Index) {
        Column() {
          IndexPage({ onNavigate: (key: string): void => { this.selectPage(key); } })
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Toolbox) {
        Column() {
          this.toolboxPage()
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.More) {
        Column() {
          MorePage({ onSelectEntry: (key: PageKey): void => { this.selectMoreEntry(key); } })
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Settings) {
        Column() {
          SettingsPage()
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Games) {
        Column() {
          GamesPage()
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  toolboxPage() {
    Column() {
      Text('工具箱')
        .fontSize(20)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: this.environment.width < 600 ? 16 : 24,
          right: this.environment.width < 600 ? 16 : 24,
          top: this.environment.safeTop + 16, bottom: 16 })
      Scroll() {
        Column({ space: 12 }) {
          ForEach(AppConstants.toolboxItems, (item: ToolboxItem) => {
            Row({ space: 12 }) {
              Text(item.icon).fontSize(24)
              Column({ space: 3 }) {
                Text(item.label).fontSize(14)
                .fontFamily(this.palette.fontSans).fontColor(this.palette.textPrimary).fontWeight(FontWeight.Medium)
                Text(item.desc).fontSize(11)
                .fontFamily(this.palette.fontSans).fontColor(this.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›').fontSize(18)
              .fontFamily(this.palette.fontSans).fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding(14)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.openToolboxEntry(item); })
          }, (item: ToolboxItem) => item.key)
        }
        .padding(this.environment.width < 600 ? 16 : 24)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  startupPage() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .visibility(this.startupState === StartupState.INITIALIZING ? Visibility.Visible : Visibility.None)
      Text(this.startupState === StartupState.FAILED ? '应用初始化失败' : '正在初始化应用')
        .fontSize(18)
        .fontFamily(this.palette.fontSans)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.textPrimary)
      if (this.startupState === StartupState.FAILED) {
        Text('核心数据未加载，请重新打开应用后重试')
          .fontSize(13)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.palette.bgBase)
  }

  build() {
    if (this.startupState !== StartupState.READY) {
      this.startupPage()
    } else {
      Stack() {
        // 主内容层
        Column() {
          Stack() {
            GlobalBackgroundLayer()
            // 注册打包的开源字体（无可见 UI）
            FontRegistry()
            Column() {
              this.renderPage()
            }
            .width('100%')
            .height('100%')
          }
          .layoutWeight(1)
          .width('100%')

          FixedBottomNav({
            selectedKey: this.navigation.selectedMain,
            onSelect: (key: MainNavKey): void => { this.selectMain(key); }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette.bgBase)

        // 隐私政策同意弹窗（未同意时覆盖）
        if (!this.privacyConsented) {
          PrivacyDialog({
            onConsent: (): void => {
              this.privacyConsented = true;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}

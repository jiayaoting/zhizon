import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { AppConstants, ToolboxItem } from '../common/Constants';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationSuccess,
  NavigationFailure, NavigationSource, NavigationFacade, mainPage, AppShellRouteParams } from '../common/Navigation';
import { IndexPage } from './Index';
import { ServersPage } from './Servers';
import { PvePage } from './Pve';
import { TerminalPage } from './Terminal';
import { FilesPage } from './Files';
import { CommandsPage } from './Commands';
import { BatchPage } from './Batch';
import { AlertsPage } from './Alerts';
import { SettingsPage } from './Settings';
import { GamesPage } from './Games';
import { MorePage } from './More';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
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

  aboutToAppear(): void {
    const params: AppShellRouteParams | null = router.getParams() as AppShellRouteParams | null;
    if (params !== undefined && params !== null && params.page !== undefined) {
      const initialResult: NavigationResult = NavigationFacade.navigateLegacy(this.navigation, params.page,
        NavigationSource.INITIAL);
      this.handleNavigationResult(params.page, initialResult);
    }
  }

  aboutToDisappear(): void {
    // 导航容器为路由托管，无独立资源需要释放
  }

  private handleNavigationResult(key: string, result: NavigationResult): void {
    if (!result.success) {
      const failure = result as NavigationFailure;
      hilog.error(DOMAIN, 'Navigation', '导航失败 key=%{public}s reason=%{public}s rollback=%{public}s',
        key, failure.reason, 'true');
      promptAction.showToast({ message: '页面打开失败，请重试' });
      return;
    }
    const success = result as NavigationSuccess;
    this.navigation = success.nextSnapshot;
  }

  private selectMain(key: MainNavKey): void {
    const target = mainPage(key);
    const result = NavigationFacade.navigate(this.navigation, target, NavigationSource.MAIN_NAV);
    this.handleNavigationResult(key, result);
  }

  private selectMoreEntry(key: PageKey): void {
    const result = NavigationFacade.navigate(this.navigation, key, NavigationSource.ENTRY);
    this.handleNavigationResult(key, result);
  }

  private selectPage(key: string): void {
    const result = NavigationFacade.navigateLegacy(this.navigation, key, NavigationSource.LEGACY);
    this.handleNavigationResult(key, result);
  }

  @Builder
  renderPage() {
    if (this.navigation.currentPage === PageKey.Index) {
      IndexPage({ onNavigate: (key: string): void => { this.selectPage(key); } })
    } else if (this.navigation.currentPage === PageKey.Servers) {
      ServersPage()
    } else if (this.navigation.currentPage === PageKey.Pve) {
      PvePage()
    } else if (this.navigation.currentPage === PageKey.Toolbox) {
      this.toolboxPage()
    } else if (this.navigation.currentPage === PageKey.More) {
      MorePage({ onSelectEntry: (key: PageKey): void => { this.selectMoreEntry(key); } })
    } else if (this.navigation.currentPage === PageKey.Terminal) {
      TerminalPage()
    } else if (this.navigation.currentPage === PageKey.Files) {
      FilesPage()
    } else if (this.navigation.currentPage === PageKey.Commands) {
      CommandsPage()
    } else if (this.navigation.currentPage === PageKey.Batch) {
      BatchPage()
    } else if (this.navigation.currentPage === PageKey.Alerts) {
      AlertsPage()
    } else if (this.navigation.currentPage === PageKey.Settings) {
      SettingsPage()
    } else if (this.navigation.currentPage === PageKey.Games) {
      GamesPage()
    }
  }

  @Builder
  toolboxPage() {
    Column() {
      Text('工具箱')
        .fontSize(20)
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
                Text(item.label).fontSize(14).fontColor(this.palette.textPrimary).fontWeight(FontWeight.Medium)
                Text(item.desc).fontSize(11).fontColor(this.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›').fontSize(18).fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding(14)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.selectPage(item.key); })
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
    .backgroundColor(this.palette.bgBase)
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
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.textPrimary)
      if (this.startupState === StartupState.FAILED) {
        Text('核心数据未加载，请重新打开应用后重试')
          .fontSize(13)
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
      Column() {
        Stack() {
          GlobalBackgroundLayer()
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
    }
  }
}

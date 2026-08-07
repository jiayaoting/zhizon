import { display, promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { AppConstants, ToolboxItem } from '../common/Constants';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationSuccess,
  NavigationFailure, NavigationFailureReason, pageFromString, pageOwner, mainPage } from '../common/Navigation';
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

const BP_SM = 600;
const DOMAIN = 0x9201;

@Entry
@Component
struct AppShell {
  @State navigation: NavigationState = new NavigationState(PageKey.Index, MainNavKey.Index);
  @State winWidth: number = 0;
  @StorageLink('isSm') isSm: boolean = true;
  @StorageLink('isMd') isMd: boolean = false;
  @StorageLink('isLg') isLg: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null && params.page !== undefined) {
      const initialPage = pageFromString(params.page);
      if (initialPage === null) {
        this.handleNavigationResult(params.page, new NavigationFailure(NavigationFailureReason.PAGE_UNAVAILABLE));
      } else {
        const initialResult = this.navigate(initialPage, false);
        this.handleNavigationResult(params.page, initialResult);
      }
    }
    try {
      const currentDisplay = display.getDefaultDisplaySync();
      const vpWidth = px2vp(currentDisplay.width);
      this.winWidth = vpWidth;
      this.applyWidth(vpWidth);
    } catch (e) {
      this.applyWidth(0);
    }
  }

  private applyWidth(width: number): void {
    this.isSm = width < BP_SM;
    this.isMd = width >= BP_SM && width < 840;
    this.isLg = width >= 840;
  }

  private canRender(page: PageKey): boolean {
    return page === PageKey.Index || page === PageKey.Servers || page === PageKey.Pve ||
      page === PageKey.Toolbox || page === PageKey.More || page === PageKey.Terminal ||
      page === PageKey.Files || page === PageKey.Commands || page === PageKey.Batch ||
      page === PageKey.Alerts || page === PageKey.Settings || page === PageKey.Games;
  }

  private navigate(target: PageKey, entryNavigation: boolean): NavigationResult {
    if (!this.canRender(target)) {
      return new NavigationFailure(entryNavigation ? NavigationFailureReason.ENTRY_UNAVAILABLE :
        NavigationFailureReason.PAGE_UNAVAILABLE);
    }
    const previous = this.navigation.currentPage;
    const mainKey = pageOwner(target);
    this.navigation = new NavigationState(target, mainKey);
    return new NavigationSuccess(previous, target, mainKey);
  }

  private handleNavigationResult(key: string, result: NavigationResult): void {
    if (!result.success) {
      const failure = result as NavigationFailure;
      hilog.error(DOMAIN, 'Navigation', '导航失败 key=%{public}s reason=%{public}s rollback=%{public}s',
        key, failure.reason, 'true');
      promptAction.showToast({ message: '页面打开失败，请重试' });
    }
  }

  private selectMain(key: MainNavKey): void {
    const target = mainPage(key);
    const result = this.navigate(target, false);
    this.handleNavigationResult(key, result);
  }

  private selectMoreEntry(key: PageKey): void {
    const result = this.navigate(key, true);
    this.handleNavigationResult(key, result);
  }

  private selectPage(key: string): void {
    const target = pageFromString(key);
    if (target === null) {
      this.handleNavigationResult(key, new NavigationFailure(NavigationFailureReason.PAGE_UNAVAILABLE));
      return;
    }
    const result = this.navigate(target, false);
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
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24,
          top: this.statusBarHeight + 16, bottom: 16 })
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
        .padding(this.isSm ? 16 : 24)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }

  build() {
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
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const width = newArea.width as number;
      if (width > 0 && Math.abs(width - this.winWidth) > 10) {
        this.winWidth = width;
        this.applyWidth(width);
      }
    })
  }
}

import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeState } from '../common/ThemeState';
import { FixedBottomNav } from '../components/FixedBottomNav';
import { SideNav } from '../components/SideNav';
import { MainNavKey, PageKey, NavigationState, NavigationResult, NavigationSuccess,
  NavigationFailure, NavigationSource, NavigationFacade, mainPage, AppShellRouteParams } from '../common/Navigation';
import { IndexPage } from './Index';
import { SettingsPage } from './Settings';
import { GamesPage } from './Games';
import { ProfilePage } from './Profile';
import { ChatTab } from './Chat';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { FontRegistry } from '../components/FontRegistry';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { LockOverlay } from '../components/LockOverlay';
import { SecurityService } from '../service/SecurityService';
import { StartupState } from '../entryability/EntryAbility';
import { AppNavigator } from '../common/AppNavigator';
import { TetrisPage } from './Tetris';
import { Game2048Page } from './Game2048';
import { SnakePage } from './Snake';
import { MinesweeperPage } from './Minesweeper';
import { SudokuPage } from './Sudoku';
import { ChineseChessPage } from './ChineseChess';
import { GameHistoryPage } from './GameHistory';
import { LegalDocPage } from './LegalDoc';
import { ChatConfig } from './ChatConfig';
import { AiModelPage } from './AiModelPage';
import { AiCallLogPage } from './AiCallLog';
import { NewsDetailPage } from './NewsDetail';
import { NewsDigestPage } from './NewsDigest';
import { NewsFavoritesPage } from './NewsFavorites';
import { NewsRecommendPage } from './NewsRecommend';
import { NewsSearchPage } from './NewsSearch';
import { NewsStatsPage } from './NewsStats';
import { NewsLikesPage } from './NewsLikes';
import { NewsProfilePage } from './NewsProfile';
import { NewsSourceSettingsPage } from './NewsSourceSettings';
import { NewsChannelSettingsPage } from './NewsChannelSettings';
import { GameSettingsPage } from './GameSettings';

const DOMAIN = 0x9201;

@Entry
@ComponentV2
struct AppShell {
  @Local navigation: NavigationState = new NavigationState(PageKey.Index, MainNavKey.Index);
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local privacyConsented: boolean = false;
  
  aboutToAppear(): void {
    // 启动时按自动锁定策略初始化锁定状态
    SecurityService.checkAndLockOnForeground().catch((e: Error) => {
      hilog.warn(0x9201, 'AppShell', '安全锁定检查失败 %{public}s', e.message);
    });
  }

  aboutToDisappear(): void {
    // 导航容器为路由托管，无独立资源需要释放
  }

  // 从 ChatConfig 等路由子页返回时，AppShell 重新可见，通知 Chat 刷新模型配置
  onPageShow(): void {
    if (this.navigation.currentPage === PageKey.Chat) {
      this.bumpChatRefresh();
    }
  }

  // 返回键拦截：子页返回所属 Tab，Tab 首页才退出到桌面
  onBackPress(): boolean {
    if (this.navigation.currentPage === PageKey.Settings) {
      this.selectMain(MainNavKey.Profile);
      return true;
    }
    if (this.navigation.currentPage === PageKey.Index) {
      return false;
    }
    this.selectMain(MainNavKey.Index);
    return true;
  }

  private bumpChatRefresh(): void {
    const current: number = AppStorage.get<number>('chatRefreshToken') ?? 0;
    AppStorage.setOrCreate('chatRefreshToken', current + 1);
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
    if (key === MainNavKey.Chat) {
      this.bumpChatRefresh();
    }
  }

  private selectPage(key: string): void {
    const result = NavigationFacade.navigateLegacy(this.navigation, key, NavigationSource.LEGACY);
    this.handleNavigationResult(key, result);
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
      if (this.navigation.currentPage === PageKey.Games) {
        Column() {
          GamesPage()
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Chat) {
        Column() {
          ChatTab()
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Profile) {
        Column() {
          ProfilePage({ onNavigate: (key: string): void => { this.selectPage(key); } })
        }
        .width('100%')
        .height('100%')
        .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.97, y: 0.97 } })
      }
      if (this.navigation.currentPage === PageKey.Settings) {
        Column() {
          SettingsPage({ onBack: (): void => { this.selectMain(MainNavKey.Profile); } })
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
  startupPage() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .visibility(this.themeState.startupState === StartupState.INITIALIZING ? Visibility.Visible : Visibility.None)
      Text(this.themeState.startupState === StartupState.FAILED ? '应用初始化失败' : '正在初始化应用')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeState.palette.textPrimary)
      if (this.themeState.startupState === StartupState.FAILED) {
        Text('核心数据未加载，请重新打开应用后重试')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.themeState.palette.bgBase)
  }

  @Builder
  routeDestination(name: string, param: Object) {
    if (name === 'pages/Tetris') {
      TetrisPage()
    } else if (name === 'pages/Game2048') {
      Game2048Page()
    } else if (name === 'pages/Snake') {
      SnakePage()
    } else if (name === 'pages/Minesweeper') {
      MinesweeperPage()
    } else if (name === 'pages/Sudoku') {
      SudokuPage()
    } else if (name === 'pages/ChineseChess') {
      ChineseChessPage()
    } else if (name === 'pages/GameHistory') {
      GameHistoryPage()
    } else if (name === 'pages/LegalDoc') {
      LegalDocPage()
    } else if (name === 'pages/ChatConfig') {
      ChatConfig()
    } else if (name === 'pages/AiModelPage') {
      AiModelPage()
    } else if (name === 'pages/AiCallLog') {
      AiCallLogPage()
    } else if (name === 'pages/NewsDetail') {
      NewsDetailPage()
    } else if (name === 'pages/NewsDigest') {
      NewsDigestPage()
    } else if (name === 'pages/NewsFavorites') {
      NewsFavoritesPage()
    } else if (name === 'pages/NewsRecommend') {
      NewsRecommendPage()
    } else if (name === 'pages/NewsSearch') {
      NewsSearchPage()
    } else if (name === 'pages/NewsStats') {
      NewsStatsPage()
    } else if (name === 'pages/NewsLikes') {
      NewsLikesPage()
    } else if (name === 'pages/NewsProfile') {
      NewsProfilePage()
    } else if (name === 'pages/NewsSourceSettings') {
      NewsSourceSettingsPage()
    } else if (name === 'pages/NewsChannelSettings') {
      NewsChannelSettingsPage()
    } else if (name === 'pages/GameSettings') {
      GameSettingsPage()
    }
  }

  build() {
    if (this.themeState.startupState !== StartupState.READY) {
      this.startupPage()
    } else {
      Stack() {
        if (this.themeState.isWideNav) {
          // 大屏（2in1 / 平板横屏）：左侧导航 + 右侧内容
          Row() {
            SideNav({
              selectedKey: this.navigation.selectedMain,
              onSelect: (key: MainNavKey): void => { this.selectMain(key); }
            })
            Stack() {
              GlobalBackgroundLayer()
              FontRegistry()
              Column() {
                this.renderPage()
              }
              .width('100%')
              .height('100%')
            }
            .layoutWeight(1)
            .width('100%')
            .height('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeState.palette.bgBase)
        } else {
          // 手机 / 平板竖屏：底部导航 + 上方内容
          Column() {
            Stack() {
              GlobalBackgroundLayer()
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
          .backgroundColor(this.themeState.palette.bgBase)
        }

        // 隐私政策同意弹窗（未同意时覆盖）
        if (!this.privacyConsented) {
          PrivacyDialog({
            onConsent: (): void => {
              this.privacyConsented = true;
            }
          })
        }

        // 锁屏覆盖层（设置了主密码且触发自动锁定时显示）
        if (this.themeState.appLocked) {
          LockOverlay({
            onUnlocked: (): void => {
              this.themeState.appLocked = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}

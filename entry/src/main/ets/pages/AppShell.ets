// 智子 - 自适应主框架（沉浸光感重构版）
import { display } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette, ThemeManager } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { AppConstants, NavItem, ToolboxItem } from '../common/Constants';
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

const BP_SM = 600;

@Entry
@Component
struct AppShell {
  @State currentPage: string = 'Index';
  @State winWidth: number = 0;
  @State showMoreMenu: boolean = false;
  @StorageLink('isSm') isSm: boolean = true;
  @StorageLink('isMd') isMd: boolean = false;
  @StorageLink('isLg') isLg: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  // 新版导航：5 主 Tab
  private mainNavItems: NavItem[] = AppConstants.navItems;

  // 手机端 4 个主 Tab
  private smPrimaryTabs: NavItem[] = [
    this.mainNavItems[0], // 首页
    this.mainNavItems[1], // 服务器
    this.mainNavItems[2], // PVE 集群
    this.mainNavItems[3], // 工具箱
  ];

  aboutToAppear() {
    try {
      const d = display.getDefaultDisplaySync();
      const vpWidth = px2vp(d.width);
      this.winWidth = vpWidth;
      this.applyWidth(vpWidth);
    } catch (e) {
      this.winWidth = 0;
      this.applyWidth(0);
    }
  }

  private applyWidth(w: number) {
    this.isSm = w < BP_SM;
    this.isMd = w >= BP_SM && w < 840;
    this.isLg = w >= 840;
  }

  selectPage(key: string) {
    this.currentPage = key;
    this.showMoreMenu = false;
  }

  @Builder
  renderPage() {
    if (this.currentPage === 'Index') {
      IndexPage({ onNavigate: (key: string): void => { this.selectPage(key); } })
    } else if (this.currentPage === 'Servers') {
      ServersPage()
    } else if (this.currentPage === 'Pve') {
      PvePage()
    } else if (this.currentPage === 'Toolbox') {
      this.toolboxPage()
    } else if (this.currentPage === 'Terminal') {
      TerminalPage()
    } else if (this.currentPage === 'Files') {
      FilesPage()
    } else if (this.currentPage === 'Commands') {
      CommandsPage()
    } else if (this.currentPage === 'Batch') {
      BatchPage()
    } else if (this.currentPage === 'Alerts') {
      AlertsPage()
    } else if (this.currentPage === 'Settings') {
      SettingsPage()
    } else if (this.currentPage === 'Games') {
      GamesPage()
    }
  }

  // 工具箱页面
  @Builder
  toolboxPage() {
    Column() {
      // 顶部标题
      Row() {
        Text('工具箱')
          .fontSize(20)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: this.statusBarHeight + 16, bottom: 16 })

      Scroll() {
        Column({ space: 12 }) {
          ForEach(AppConstants.toolboxItems, (item: NavItem, idx: number) => {
            Row({ space: 12 }) {
              Text(item.icon)
                .fontSize(24)
              Column() {
                Text(item.label)
                  .fontSize(14)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                if ((item as ToolboxItem).desc) {
                  Text((item as ToolboxItem).desc)
                    .fontSize(11)
                    .fontColor(this.palette.textTertiary)
                    .margin({ top: 2 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›')
                .fontSize(18)
                .fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding(14)
            .borderRadius(10)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => {
              this.selectPage(item.key);
            })
          }, (item: NavItem) => item.key)
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

  @Builder
  tabItem(item: NavItem, isActive: boolean) {
    Column({ space: 2 }) {
      Text(item.icon)
        .fontSize(20)
      Text(item.label)
        .fontSize(10)
        .fontColor(isActive ? this.palette.primary : this.palette.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => {
      this.selectPage(item.key);
    })
  }

  // 更多菜单面板
  @Builder
  moreMenuPanel() {
    Column({ space: 0 }) {
      Text('更多')
        .fontSize(14)
        .fontColor(this.palette.textSecondary)
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 10 })

      ForEach(AppConstants.moreItems, (item: NavItem) => {
        Row({ space: 12 }) {
          Text(item.icon).fontSize(20)
          Text(item.label)
            .fontSize(14)
            .fontColor(this.palette.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .onClick(() => {
          this.selectPage(item.key);
          this.showMoreMenu = false;
        })
      }, (item: NavItem) => item.key)

      // 取消按钮
      Row() {
        Text('取消')
          .fontSize(14)
          .fontColor(this.palette.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 12 })
      }
      .width('100%')
      .border({ width: { top: 1 }, color: this.palette.borderSubtle })
      .onClick(() => { this.showMoreMenu = false; })
    }
    .width('100%')
    .backgroundColor(this.palette.bgSurface)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .padding({ bottom: this.navBarHeight })
  }

  @Builder
  bottomTabBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Tab 栏
      Row() {
        ForEach(this.smPrimaryTabs, (item: NavItem) => {
          this.tabItem(item, item.key === this.currentPage)
        }, (item: NavItem) => item.key)

        // 更多按钮
        Column({ space: 2 }) {
          Text('⋯')
            .fontSize(20)
            .fontColor(this.palette.textTertiary)
          Text('更多')
            .fontSize(10)
            .fontColor(this.palette.textTertiary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => { this.showMoreMenu = !this.showMoreMenu; })
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.palette.bgSurface)
      .border({ width: { top: 1 }, color: this.palette.borderSubtle })
      .padding({ bottom: this.navBarHeight })

      // 更多菜单弹出层（浮在 Tab 上方）
      if (this.showMoreMenu) {
        this.moreMenuPanel()
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.isSm) {
        // 手机：内容 + 底部Tab（带背景图）
        Stack({ alignContent: Alignment.Bottom }) {
          // 背景图层
          Stack() {
            // 背景图
            Image(ThemeManager.getInstance().getPageBackground(this.currentPage))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .visibility(ThemeManager.getInstance().getPageBackground(this.currentPage) ? Visibility.Visible : Visibility.None)
            // 半透明遮罩
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.palette.isDark ? 'rgba(10, 14, 26, 0.85)' : 'rgba(245, 246, 250, 0.85)')
          }
          .width('100%')
          .height('100%')

          // 内容层
          Column() {
            this.renderPage()
          }
          .layoutWeight(1)

          this.bottomTabBar()
        }
        .layoutWeight(1)
      } else {
        // 平板+：侧边栏 + 内容（带背景图）
        Row() {
          NavSidebar({
            activeKey: this.currentPage,
            compact: !this.isLg,
            onSelect: (key: string) => {
              this.currentPage = key;
            }
          })
          .width(this.isLg ? 220 : 160)

          Stack() {
            // 背景图层
            Stack() {
              Image(ThemeManager.getInstance().getPageBackground(this.currentPage))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .visibility(ThemeManager.getInstance().getPageBackground(this.currentPage) ? Visibility.Visible : Visibility.None)
              Column()
                .width('100%')
                .height('100%')
                .backgroundColor(this.palette.isDark ? 'rgba(10, 14, 26, 0.85)' : 'rgba(245, 246, 250, 0.85)')
            }
            .width('100%')
            .height('100%')

            Column() {
              this.renderPage()
            }
            .layoutWeight(1)
            .height('100%')
          }
          .layoutWeight(1)
          .height('100%')
        }
        .height('100%')
        .padding({ bottom: this.navBarHeight })
      }
    }
    .height('100%')
    .backgroundColor(this.palette.bgBase)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const w = newArea.width as number;
      if (w > 0 && Math.abs(w - this.winWidth) > 10) {
        this.winWidth = w;
        this.applyWidth(w);
      }
    })
  }
}

// 智子 - 自适应主框架（手机底部Tab / 平板侧边栏）
import { display } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { AppConstants, NavItem } from '../common/Constants';
import { IndexPage } from './Index';
import { ServersPage } from './Servers';
import { PvePage } from './Pve';
import { TerminalPage } from './Terminal';
import { FilesPage } from './Files';
import { CommandsPage } from './Commands';
import { BatchPage } from './Batch';
import { AlertsPage } from './Alerts';
import { SettingsPage } from './Settings';

const BP_SM = 600;
const SAFE_TOP = 34;
const SAFE_BOTTOM = 12;

@Entry
@Component
struct AppShell {
  @State currentPage: string = 'Index';
  @State winWidth: number = 0;
  @State showMoreMenu: boolean = false;
  @StorageLink('isSm') isSm: boolean = true;
  @StorageLink('isMd') isMd: boolean = false;
  @StorageLink('isLg') isLg: boolean = false;
  private allNavItems: NavItem[] = AppConstants.navItems;

  // 手机端 5 个主 Tab
  private smPrimaryTabs: NavItem[] = [
    this.allNavItems[0], // 总览
    this.allNavItems[1], // SSH 服务器
    this.allNavItems[2], // PVE 集群
    this.allNavItems[3], // SSH 终端
    this.allNavItems[7], // 告警中心
  ];

  // 更多菜单中的项
  private smMoreTabs: NavItem[] = [
    this.allNavItems[4], // 文件管理
    this.allNavItems[5], // 快捷命令
    this.allNavItems[6], // 批量操作
    this.allNavItems[8], // 设置
  ];

  aboutToAppear() {
    try {
      const d = display.getDefaultDisplaySync();
      const vpWidth = px2vp(d.width);
      this.winWidth = vpWidth;
      this.applyWidth(vpWidth);
    } catch (e) {
      // 兜底：默认手机布局，等 onAreaChange 更新
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
      IndexPage()
    } else if (this.currentPage === 'Servers') {
      ServersPage()
    } else if (this.currentPage === 'Pve') {
      PvePage()
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
    }
  }

  @Builder
  tabItem(item: NavItem, isActive: boolean, isMore: boolean) {
    Column({ space: 2 }) {
      Text(isMore ? '⋯' : item.icon)
        .fontSize(isMore ? 20 : 18)
      Text(isMore ? '更多' : item.label)
        .fontSize(10)
        .fontColor(isActive ? AppTheme.primary : AppTheme.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => {
      if (isMore) {
        this.showMoreMenu = !this.showMoreMenu;
      } else {
        this.selectPage(item.key);
      }
    })
  }

  @Builder
  bottomTabBar() {
    Column() {
      // 更多菜单弹出层
      if (this.showMoreMenu) {
        Column({ space: 0 }) {
          ForEach(this.smMoreTabs, (item: NavItem, idx: number) => {
            Row({ space: 10 }) {
              Text(item.icon).fontSize(16)
              Text(item.label)
                .fontSize(14)
                .fontColor(this.currentPage === item.key ? AppTheme.primary : AppTheme.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .backgroundColor(this.currentPage === item.key ? AppTheme.primaryDim : Color.Transparent)
            .onClick(() => this.selectPage(item.key))
          }, (item: NavItem) => item.key)
        }
        .width('100%')
        .backgroundColor(AppTheme.bgElevated)
        .borderRadius({ topLeft: 12, topRight: 12 })
        .padding({ top: 4, bottom: 8 })
      }

      // 主 Tab 栏
      Row() {
        ForEach(this.smPrimaryTabs, (item: NavItem) => {
          this.tabItem(item, item.key === this.currentPage, false)
        }, (item: NavItem) => item.key)

        // 更多按钮
        this.tabItem({ key: 'more', label: '更多', icon: '⋯' },
          this.smMoreTabs.some(t => t.key === this.currentPage), true)
      }
      .width('100%')
      .height(56)
      .backgroundColor(AppTheme.bgSurface)
      .border({ width: { top: 1 }, color: AppTheme.borderSubtle })
    }
    .width('100%')
    .backgroundColor(AppTheme.bgSurface)
  }

  // 半透明遮罩：点击关闭更多菜单
  @Builder
  overlayMask() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.4)')
      .position({ x: 0, y: 0 })
      .onClick(() => { this.showMoreMenu = false; })
  }

  build() {
    Column() {
      if (this.isSm) {
        // 手机：内容 + 底部Tab
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            this.renderPage()
          }
          .layoutWeight(1)
          .padding({ top: SAFE_TOP })

          this.bottomTabBar()
            .padding({ bottom: SAFE_BOTTOM })
        }
        .layoutWeight(1)

        // 更多菜单遮罩
        if (this.showMoreMenu) {
          this.overlayMask()
        }
      } else {
        // 平板+：侧边栏 + 内容
        Row() {
          NavSidebar({
            activeKey: this.currentPage,
            compact: !this.isLg,
            onSelect: (key: string) => {
              this.currentPage = key;
            }
          })
          .width(this.isLg ? 220 : 160)

          Column() {
            this.renderPage()
          }
          .layoutWeight(1)
          .height('100%')
        }
        .height('100%')
      }
    }
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const w = newArea.width as number;
      if (w > 0 && Math.abs(w - this.winWidth) > 10) {
        this.winWidth = w;
        this.applyWidth(w);
      }
    })
  }
}
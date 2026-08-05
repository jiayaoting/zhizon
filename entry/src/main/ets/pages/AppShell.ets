// 智子 - 自适应主框架（手机底部Tab / 平板侧边栏）
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

@Entry
@Component
struct AppShell {
  @State currentPage: string = 'Index';
  @State winWidth: number = 0;
  private navItems: NavItem[] = AppConstants.navItems;

  aboutToAppear() {
    AppStorage.setOrCreate('isSm', false);
  }

  private get isSm(): boolean {
    return this.winWidth > 0 && this.winWidth < BP_SM;
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
  bottomTabBar() {
    Row() {
      ForEach(this.navItems, (item: NavItem) => {
        Column({ space: 2 }) {
          Text(item.icon)
            .fontSize(18)
          Text(item.label)
            .fontSize(10)
            .fontColor(item.key === this.currentPage ? AppTheme.primary : AppTheme.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => {
          this.currentPage = item.key;
        })
      }, (item: NavItem) => item.key)
    }
    .width('100%')
    .height(56)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: { top: 1 }, color: AppTheme.borderSubtle })
  }

  build() {
    Column() {
      if (this.winWidth === 0) {
        // 加载中占位
        Column() {
          Text('智子')
            .fontSize(24)
            .fontColor(AppTheme.primary)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppTheme.bgBase)
      } else if (this.isSm) {
        // 手机：内容 + 底部Tab
        Column() {
          this.renderPage()
        }
        .layoutWeight(1)

        this.bottomTabBar()
      } else {
        // 平板+：侧边栏 + 内容
        Row() {
          NavSidebar({
            activeKey: this.currentPage,
            onSelect: (key: string) => {
              this.currentPage = key;
            }
          })

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
      this.winWidth = w;
      AppStorage.setOrCreate('isSm', w > 0 && w < BP_SM);
    })
  }
}
// 智子 - 快捷命令库页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { EmptyState } from '../components/EmptyState';
import { DataRepository } from '../service/DataRepository';
import { Command } from '../model/Models';

@Entry
@Component
struct CommandsPage {
  @State activeNav: string = 'Commands';
  @State currentCat: string = '全部';
  private commands: Command[] = DataRepository.getCommands();
  private categories: string[] = ['全部', '系统', '进程', '网络', 'Docker', '安全', '服务'];

  // 分类下命令数
  private countOf(cat: string): number {
    if (cat === '全部') return this.commands.length;
    return this.commands.filter(c => c.category === cat).length;
  }

  // 当前筛选命令
  private filteredCommands(): Command[] {
    if (this.currentCat === '全部') return this.commands;
    return this.commands.filter(c => c.category === this.currentCat);
  }

  @Builder actionsBuilder() {
    Button('添加命令')
      .fontSize(12)
      .fontColor(Color.White)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .onClick(() => {
        promptAction.showToast({ message: '添加命令功能开发中' });
      })
  }

  @Builder categoryItem(cat: string) {
    Row({ space: 8 }) {
      // 选中时左侧紫色条
      if (cat === this.currentCat) {
        Column()
          .width(2)
          .height(14)
          .backgroundColor(AppTheme.purple)
      }
      Text(cat)
        .fontSize(13)
        .fontColor(cat === this.currentCat ? AppTheme.primary : AppTheme.textSecondary)
        .fontWeight(cat === this.currentCat ? FontWeight.Medium : FontWeight.Regular)
        .layoutWeight(1)
      // 命令数小徽章
      Text(`${this.countOf(cat)}`)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
        .borderRadius(8)
        .backgroundColor(AppTheme.bgSurface2)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(6)
    .backgroundColor(cat === this.currentCat ? AppTheme.primaryDim : Color.Transparent)
    .onClick(() => {
      this.currentCat = cat;
    })
  }

  @Builder commandCard(cmd: Command) {
    Column({ space: 10 }) {
      // 顶部：命令名 + 使用次数
      Row() {
        Text(cmd.name)
          .fontSize(AppTheme.fsMd)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${cmd.uses} 次`)
          .fontSize(10)
          .fontColor(AppTheme.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(AppTheme.primaryDim)
      }
      .width('100%')

      // 命令内容（mono 字体，可点击复制）
      Text(cmd.cmd)
        .fontSize(AppTheme.fsSm)
        .fontColor(AppTheme.primary)
        .fontFamily(AppTheme.fontMono)
        .width('100%')
        .padding(10)
        .borderRadius(6)
        .backgroundColor(AppTheme.bgSurface2)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          promptAction.showToast({ message: '已复制到剪贴板' });
        })

      // 底部：分类标签 + 复制 + 运行
      Row() {
        Text(cmd.category)
          .fontSize(10)
          .fontColor(AppTheme.textSecondary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(AppTheme.bgSurface2)
        Blank()
        Button('复制')
          .fontSize(11)
          .fontColor(AppTheme.textSecondary)
          .backgroundColor(AppTheme.bgSurface2)
          .borderRadius(6)
          .height(26)
          .onClick(() => {
            promptAction.showToast({ message: '已复制到剪贴板' });
          })
        Button('运行')
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.primary)
          .borderRadius(6)
          .height(26)
          .onClick(() => {
            promptAction.showToast({ message: `运行：${cmd.name}` });
          })
      }
      .width('100%')
    }
    .width(280)
    .padding(14)
    .margin({ right: 12, bottom: 12 })
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
  }

  build() {
    Row() {
      NavSidebar({ activeKey: this.activeNav, onSelect: (key: string) => {
        router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
      }})
      Column() {
        TopBar({ title: '快捷命令库', subtitle: `${this.commands.length} 条命令` }) {
          this.actionsBuilder()
        }
        Row() {
          // 左侧分类侧栏
          Scroll() {
            Column({ space: 2 }) {
              ForEach(this.categories, (cat: string) => {
                this.categoryItem(cat)
              }, (cat: string) => cat)
            }
            .padding({ top: 12, left: 8, right: 8 })
            .width('100%')
          }
          .width(180)
          .height('100%')
          .backgroundColor(AppTheme.bgSurface)
          .border({ width: { right: 1 }, color: AppTheme.borderSubtle })
          .scrollBar(BarState.Off)
          .align(Alignment.Top)

          // 右侧命令卡片网格
          Scroll() {
            if (this.filteredCommands().length === 0) {
              EmptyState({ icon: '⚡', title: '暂无命令', desc: '切换其他分类查看命令' })
            } else {
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
                ForEach(this.filteredCommands(), (cmd: Command) => {
                  this.commandCard(cmd)
                }, (cmd: Command) => cmd.id)
              }
              .padding(20)
              .width('100%')
            }
          }
          .layoutWeight(1)
          .height('100%')
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        }
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(AppTheme.bgBase)
    }
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

// 智子 - 快捷命令库页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { EmptyState } from '../components/EmptyState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { DataRepository } from '../service/DataRepository';
import { Command } from '../model/Models';

@Component
export struct CommandsPage {
  @State currentCat: string = '全部';
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @State commands: Command[] = [];
  @State loading: boolean = true;
  private categories: string[] = ['全部', '系统', '进程', '网络', 'Docker', '安全', '服务'];
  private commandsDataSource: ArrayDataSource<Command> = new ArrayDataSource<Command>();

  aboutToAppear(): void {
    DataRepository.getCommands().then((data: Command[]) => {
      this.commands = data;
      this.refreshCommandsDataSource();
      this.loading = false;
    }).catch(() => {
      this.loading = false;
    });
  }

  aboutToDisappear(): void {
    // 命令库为静态数据，无持久资源需要释放
  }

  // 刷新 LazyForEach 数据源
  private refreshCommandsDataSource(): void {
    this.commandsDataSource.reloadAll(this.filteredCommands());
  }

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
      .backgroundColor(this.palette.primary)
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
          .backgroundColor(this.palette.purple)
      }
      Text(cat)
        .fontSize(13)
        .fontColor(cat === this.currentCat ? this.palette.primary : this.palette.textSecondary)
        .fontWeight(cat === this.currentCat ? FontWeight.Medium : FontWeight.Regular)
        .layoutWeight(1)
      // 命令数小徽章
      Text(`${this.countOf(cat)}`)
        .fontSize(10)
        .fontColor(this.palette.textTertiary)
        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
        .borderRadius(8)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(6)
    .backgroundColor(cat === this.currentCat ? this.palette.primaryDim : Color.Transparent)
    .onClick(() => {
      this.currentCat = cat;
      this.refreshCommandsDataSource();
    })
  }

  @Builder commandCard(cmd: Command) {
    Column({ space: 10 }) {
      // 顶部：命令名 + 使用次数
      Row() {
        Text(cmd.name)
          .fontSize(this.palette.fsMd)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${cmd.uses} 次`)
          .fontSize(10)
          .fontColor(this.palette.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(this.palette.primaryDim)
      }
      .width('100%')

      // 命令内容（mono 字体，可点击复制）
      Text(cmd.cmd)
        .fontSize(this.palette.fsSm)
        .fontColor(this.palette.primary)
        .fontFamily(this.palette.fontMono)
        .width('100%')
        .padding(10)
        .borderRadius(6)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          promptAction.showToast({ message: '已复制到剪贴板' });
        })

      // 底部：分类标签 + 复制 + 运行
      Row() {
        Text(cmd.category)
          .fontSize(10)
          .fontColor(this.palette.textSecondary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
        Blank()
        Button('复制')
          .fontSize(11)
          .fontColor(this.palette.textSecondary)
          .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
          .borderRadius(6)
          .height(26)
          .onClick(() => {
            promptAction.showToast({ message: '已复制到剪贴板' });
          })
        Button('运行')
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(this.palette.primary)
          .borderRadius(6)
          .height(26)
          .onClick(() => {
            promptAction.showToast({ message: `运行：${cmd.name}` });
          })
      }
      .width('100%')
    }
    .width(this.isSm ? '100%' : 280)
    .padding(14)
    .margin({ right: this.isSm ? 0 : 12, bottom: 12 })
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
  }

  @Builder loadingBuilder() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.palette.primary)
      Text('加载中...')
        .fontSize(13)
        .fontColor(this.palette.textTertiary)
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      TopBar({ title: '快捷命令库', subtitle: `${this.commands.length} 条命令` }) {
        this.actionsBuilder()
      }
      if (this.isSm) {
        // ===== 手机端：横向分类栏 + 卡片列表 =====
        Column() {
          // 横向滚动分类栏
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.categories, (cat: string) => {
                Text(cat)
                  .fontSize(12)
                  .fontColor(cat === this.currentCat ? Color.White : this.palette.textSecondary)
                  .fontWeight(cat === this.currentCat ? FontWeight.Medium : FontWeight.Regular)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor(cat === this.currentCat ? this.palette.primary : this.palette.bgSurface2)
                  .onClick(() => { this.currentCat = cat; this.refreshCommandsDataSource(); })
              }, (cat: string) => cat)
            }
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .backgroundColor(this.palette.bgSurface)
          .border({ width: { bottom: 1 }, color: this.palette.borderSubtle })

          // 命令卡片列表
          if (this.loading) {
            this.loadingBuilder()
          } else if (this.commandsDataSource.totalCount() === 0) {
            EmptyState({ icon: '⚡', title: '暂无命令', desc: '切换其他分类查看命令' })
          } else {
            List({ space: 10 }) {
              LazyForEach(this.commandsDataSource, (cmd: Command) => {
                ListItem() {
                  this.commandCard(cmd)
                }
              }, (cmd: Command) => cmd.id)
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .align(Alignment.Top)
            .padding(12)
          }
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        // ===== 平板端：左侧分类侧栏 + 右侧卡片网格 =====
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
          .backgroundColor(this.palette.bgSurface)
          .border({ width: { right: 1 }, color: this.palette.borderSubtle })
          .scrollBar(BarState.Off)
          .align(Alignment.Top)

          // 右侧命令卡片网格
          if (this.loading) {
            this.loadingBuilder()
          } else {
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
        }
        .layoutWeight(1)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}
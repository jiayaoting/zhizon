// 智子 - 会话列表抽屉（新建/切换/重命名/固定/删除/导入导出）
import { ChatSession } from '../common/LlmModels';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from './GlassEffect';
import { LazyListDataSource } from '../common/LazyDataSource';

@Component
export struct ChatSessionDrawer {
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isDarkMode') isDark: boolean = false;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @Prop @Watch('onSessionsChange') sessions: ChatSession[] = [];
  private sessionSource: LazyListDataSource<ChatSession> = new LazyListDataSource<ChatSession>([]);
  @Prop activeSessionId: string = '';
  @Prop drawerRenameId: string = '';
  @Prop drawerRenameText: string = '';
  onClose: () => void = () => {};
  onNewSession: () => void = () => {};
  onSwitchSession: (id: string) => void = () => {};
  onBeginRename: (id: string) => void = () => {};
  onRenameTextChange: (value: string) => void = () => {};
  onConfirmRename: () => void = () => {};
  onCancelRename: () => void = () => {};
  onTogglePin: (id: string) => void = () => {};
  onDeleteSession: (id: string) => void = () => {};
  onExport: () => void = () => {};
  onImport: () => void = () => {};
  onExportFile: () => void = () => {};
  onExportCurrentFile: () => void = () => {};
  onImportFile: () => void = () => {};
  onSearchChange: (value: string) => void = () => {};
  @State searchText: string = '';

  aboutToAppear(): void {
    this.sessionSource.replace(this.sessions);
  }

  private onSessionsChange(): void {
    this.sessionSource.replace(this.sessions);
  }

  // 会话时间标签：当天显示 HH:mm，否则显示 M月D日
  private sessionTimeLabel(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const now: Date = new Date();
    const sameDay: boolean = d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    if (sameDay) return hh + ':' + mm;
    return (d.getMonth() + 1).toString() + '月' + d.getDate().toString() + '日';
  }

  build() {
    Stack() {
      Row() {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('对话列表')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.onClose(); })
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 4 })

          // 搜索会话（标题或消息正文命中）
          TextInput({ text: this.searchText, placeholder: '搜索会话…' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(36)
            .width('100%')
            .onChange((value: string) => {
              this.searchText = value;
              this.onSearchChange(value);
            })

          // 新建会话
          Row() {
            Text('＋ 新建对话')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(40)
          .justifyContent(FlexAlign.Center)
          .borderRadius(10)
          .backgroundColor(this.palette.primary)
          .onClick(() => { this.onNewSession(); })

          // 会话列表
          List({ space: 6 }) {
            LazyForEach(this.sessionSource, (s: ChatSession) => {
              ListItem() {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    if (s.id === this.drawerRenameId) {
                      TextInput({ text: this.drawerRenameText, placeholder: '会话名称' })
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textPrimary)
                        .backgroundColor(this.palette.bgSurface)
                        .borderRadius(8)
                        .border({ width: 1, color: this.palette.borderSubtle })
                        .height(36)
                        .layoutWeight(1)
                        .onChange((value: string) => { this.onRenameTextChange(value); })
                      Text('✓')
                        .fontSize(16)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.primary)
                        .padding(6)
                        .onClick(() => { this.onConfirmRename(); })
                      Text('✕')
                        .fontSize(14)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textTertiary)
                        .padding(6)
                        .onClick(() => { this.onCancelRename(); })
                    } else {
                      Text(s.pinned ? '📌' : '💬')
                        .fontSize(13)
                        .fontFamily(this.palette.fontSans)
                      Column({ space: 2 }) {
                        Text(s.title)
                          .fontSize(this.palette.fsSm)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.textPrimary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(this.sessionTimeLabel(s.updatedAt))
                          .fontSize(10)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.textTertiary)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      if (s.id === this.activeSessionId) {
                        Text('当前')
                          .fontSize(10)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.primary)
                          .fontWeight(FontWeight.Medium)
                      }
                      Text('✏️')
                        .fontSize(13)
                        .fontFamily(this.palette.fontSans)
                        .padding(4)
                        .onClick(() => { this.onBeginRename(s.id); })
                      Text('📌')
                        .fontSize(12)
                        .fontFamily(this.palette.fontSans)
                        .opacity(s.pinned ? 1 : 0.4)
                        .padding(4)
                        .onClick(() => { this.onTogglePin(s.id); })
                      Text('🗑️')
                        .fontSize(13)
                        .fontFamily(this.palette.fontSans)
                        .padding(4)
                        .onClick(() => { this.onDeleteSession(s.id); })
                    }
                  }
                  .width('100%')
                  .padding(10)
                  .borderRadius(10)
                  .backgroundColor(s.id === this.activeSessionId
                    ? GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette)
                    : this.palette.bgSurface)
                  .border({ width: 1,
                    color: s.id === this.activeSessionId ? this.palette.primary : this.palette.borderSubtle })
                  .onClick(() => {
                    if (this.drawerRenameId.length === 0) this.onSwitchSession(s.id);
                  })
                }
                .width('100%')
              }
            }, (s: ChatSession) => s.id)
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .width('100%')
        // 底部操作：导出 Markdown / 导出备份文件 / 导入
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Row() {
              Text('📋 导出 Markdown')
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
            }
            .layoutWeight(1)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.onExport(); })
            Row() {
              Text('📋 导入')
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
            }
            .layoutWeight(1)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.onImport(); })
          }
          .width('100%')
          Row({ space: 8 }) {
            Row() {
              Text('💾 备份全部会话')
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
            }
            .layoutWeight(1)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.onExportFile(); })
            Row() {
              Text('💾 备份当前会话')
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
            }
            .layoutWeight(1)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.onExportCurrentFile(); })
          }
          .width('100%')
          Row() {
            Text('📂 从文件导入备份')
              .fontSize(11)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(36)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.palette.primaryDim)
          .border({ width: 1, color: this.palette.primary })
          .onClick(() => { this.onImportFile(); })
        }
        .width('100%')
        }
        .width(this.isSm ? '78%' : 320)
        .height('100%')
        .padding({ left: 16, right: 16, top: Math.max(16, this.navBarHeight) + 12,
          bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        // 抽屉内容不设 onClick：点击冒泡无父级处理器，不会误触关闭；Blank 区域独立响应关闭
        Blank()
          .layoutWeight(1)
          .height('100%')
          .onClick(() => { this.onClose(); })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
  }

}

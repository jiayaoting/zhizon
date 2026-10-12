// 智子 - 会话列表抽屉（新建/切换/重命名/固定/删除/导入导出）
// v10 华为式列表：56vp 行高 + 发丝分割线（左缩进 dividerIndent）+ 当前会话 primaryBg 高亮；
//               固定会话在标题旁显示主色书签图标；左滑展开「固定 / 重命名 / 删除」操作（删除 danger）。
import { AppStorageV2 } from '@kit.ArkUI';
import { ChatSession } from '../common/LlmModels';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { LazyListDataSource } from '../common/LazyDataSource';

@ComponentV2
export struct ChatSessionDrawer {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Param sessions: ChatSession[] = [];
  private sessionSource: LazyListDataSource<ChatSession> = new LazyListDataSource<ChatSession>([]);
  @Param activeSessionId: string = '';
  @Param drawerRenameId: string = '';
  @Param drawerRenameText: string = '';
  @Event onClose: () => void = () => {};
  @Event onNewSession: () => void = () => {};
  @Event onSwitchSession: (id: string) => void = () => {};
  @Event onBeginRename: (id: string) => void = () => {};
  @Event onRenameTextChange: (value: string) => void = () => {};
  @Event onConfirmRename: () => void = () => {};
  @Event onCancelRename: () => void = () => {};
  @Event onTogglePin: (id: string) => void = () => {};
  @Event onToggleIncognito: (id: string) => void = () => {};
  @Event onOpenRoles: () => void = () => {};
  @Event onDeleteSession: (id: string) => void = () => {};
  @Event onExport: () => void = () => {};
  @Event onImport: () => void = () => {};
  @Event onExportFile: () => void = () => {};
  @Event onExportCurrentFile: () => void = () => {};
  @Event onImportFile: () => void = () => {};
  @Event onSearchChange: (value: string) => void = () => {};
  @Local searchText: string = '';

  aboutToAppear(): void {
    this.sessionSource.replace(this.sessions);
  }

  // 会话列表变化（V1 Watch → V2 Monitor）：同步 LazyForEach 数据源
  @Monitor('sessions')
  private onSessionsChange(monitor: IMonitor): void {
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

  // 会话行元信息：无痕标记 + 时间
  private sessionMeta(s: ChatSession): string {
    return (s.incognito ? '无痕 · ' : '') + this.sessionTimeLabel(s.updatedAt);
  }

  // 底部批量操作钮（胶囊 + bgSurface2）
  @Builder
  footerAction(label: string, emphasized: boolean, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(emphasized ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(emphasized ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface2)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(onTap)
  }

  // 行内无痕开关（保留原会话级无痕能力）
  @Builder
  incognitoToggle(s: ChatSession) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.lock)
          .fontSize(18)
          .fontColor([s.incognito ? this.themeState.palette.warning : this.themeState.palette.textTertiary])
          .opacity(s.incognito ? 1 : 0.5)
      } else {
        Text(AppIcons.lockEmoji)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .opacity(s.incognito ? 1 : 0.5)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusCapsule)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(s.incognito ? '关闭无痕' : '开启无痕')
    .onClick(() => { this.onToggleIncognito(s.id); })
  }

  // 会话行左侧状态图标：固定 > 无痕 > 普通
  @Builder
  sessionStateIcon(s: ChatSession) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(s.pinned ? AppIcons.bookmark : (s.incognito ? AppIcons.lock : AppIcons.navChat))
          .fontSize(20)
          .fontColor([s.pinned ? this.themeState.palette.primary :
            (s.incognito ? this.themeState.palette.warning : this.themeState.palette.textTertiary)])
      } else {
        Text(s.pinned ? AppIcons.bookmarkEmoji : (s.incognito ? AppIcons.lockEmoji : AppIcons.navChatEmoji))
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
      }
    }
    .width(28)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  // 左滑操作（固定 / 重命名 / 删除）：文案 ≤3 字，删除用 danger 实底
  // 说明：ArkTS 的 UI 转译不支持在对象字面量的箭头函数里直接声明组件树，
  //      因此 builder 只做「调用 @Builder 方法」，组件树写在下方 swipeEndActions 中。
  @Builder
  swipeEndActions(s: ChatSession) {
    Row({ space: 0 }) {
      Row() {
        Text(s.pinned ? '取消固定' : '固定')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width(84)
      .height(this.themeState.palette.rowHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.themeState.palette.bgHover)
      .onClick(() => { this.onTogglePin(s.id); })

      Row() {
        Text('重命名')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width(84)
      .height(this.themeState.palette.rowHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .onClick(() => { this.onBeginRename(s.id); })

      Row() {
        Text('删除')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width(84)
      .height(this.themeState.palette.rowHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.themeState.palette.danger)
      .onClick(() => { this.onDeleteSession(s.id); })
    }
    .height(this.themeState.palette.rowHeight)
  }

  build() {
    Stack() {
      Row() {
        Column({ space: this.themeState.palette.sp2 }) {
          // 标题区：对话列表 + 角色模板 + 关闭
          Row({ space: this.themeState.palette.sp2 }) {
            Text('对话列表')
              .fontSize(this.themeState.palette.fsLg)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('🎭')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .padding(6)
              .accessibilityText('AI 角色模板')
              .onClick(() => { this.onOpenRoles(); })
            Row() {
              if (USE_SYMBOL_ICONS) {
                SymbolGlyph(AppIcons.close)
                  .fontSize(20)
                  .fontColor([this.themeState.palette.textSecondary])
              } else {
                Text(AppIcons.closeEmoji)
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textSecondary)
              }
            }
            .width(this.themeState.palette.touchTarget)
            .height(this.themeState.palette.touchTarget)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .accessibilityText('关闭会话列表')
            .onClick(() => { this.onClose(); })
          }
          .width('100%')

          // 搜索会话（标题或消息正文命中）
          Row({ space: this.themeState.palette.sp2 }) {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.search)
                .fontSize(18)
                .fontColor([this.themeState.palette.textTertiary])
            } else {
              Text(AppIcons.searchEmoji)
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
            }
            TextInput({ text: this.searchText, placeholder: '搜索会话…' })
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .placeholderColor(this.themeState.palette.textTertiary)
              .backgroundColor(Color.Transparent)
              .height(40)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.searchText = value;
                this.onSearchChange(value);
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .borderRadius(this.themeState.palette.radiusCapsule)
          .backgroundColor(this.themeState.palette.bgSurface2)

          // 新建会话（主色胶囊）
          Row({ space: 4 }) {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.add)
                .fontSize(18)
                .fontColor([this.themeState.palette.primaryOnColor])
            } else {
              Text(AppIcons.addEmoji)
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primaryOnColor)
            }
            Text('新建对话')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primaryOnColor)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(this.themeState.palette.touchTarget)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(this.themeState.palette.radiusCapsule)
          .backgroundColor(this.themeState.palette.primary)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => { this.onNewSession(); })

          // 会话列表：56vp 行 + 发丝分割线 + 左滑操作
          List({ space: 0 }) {
            LazyForEach(this.sessionSource, (s: ChatSession) => {
              ListItem() {
                Column() {
                  Row({ space: this.themeState.palette.sp3 }) {
                    if (s.id === this.drawerRenameId) {
                      // 重命名内联编辑（保留原交互）
                      TextInput({ text: this.drawerRenameText, placeholder: '会话名称' })
                        .fontSize(this.themeState.palette.fsMd)
                        .fontFamily(this.themeState.palette.fontSans)
                        .fontColor(this.themeState.palette.textPrimary)
                        .placeholderColor(this.themeState.palette.textTertiary)
                        .backgroundColor(this.themeState.palette.bgSurface2)
                        .borderRadius(this.themeState.palette.radiusCapsule)
                        .height(this.themeState.palette.touchTarget)
                        .layoutWeight(1)
                        .onChange((value: string) => { this.onRenameTextChange(value); })
                      Row() {
                        if (USE_SYMBOL_ICONS) {
                          SymbolGlyph(AppIcons.check)
                            .fontSize(20)
                            .fontColor([this.themeState.palette.primary])
                        } else {
                          Text(AppIcons.checkEmoji)
                            .fontSize(this.themeState.palette.fsMd)
                            .fontFamily(this.themeState.palette.fontSans)
                            .fontColor(this.themeState.palette.primary)
                        }
                      }
                      .width(this.themeState.palette.touchTarget)
                      .height(this.themeState.palette.touchTarget)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .accessibilityText('确认重命名')
                      .onClick(() => { this.onConfirmRename(); })
                      Row() {
                        if (USE_SYMBOL_ICONS) {
                          SymbolGlyph(AppIcons.close)
                            .fontSize(18)
                            .fontColor([this.themeState.palette.textTertiary])
                        } else {
                          Text(AppIcons.closeEmoji)
                            .fontSize(this.themeState.palette.fsSm)
                            .fontFamily(this.themeState.palette.fontSans)
                            .fontColor(this.themeState.palette.textTertiary)
                        }
                      }
                      .width(this.themeState.palette.touchTarget)
                      .height(this.themeState.palette.touchTarget)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .accessibilityText('取消重命名')
                      .onClick(() => { this.onCancelRename(); })
                    } else {
                      this.sessionStateIcon(s)
                      Column({ space: 2 }) {
                        Row({ space: 4 }) {
                          Text(s.title)
                            .fontSize(this.themeState.palette.fsMd)
                            .fontFamily(this.themeState.palette.fontSans)
                            .fontColor(this.themeState.palette.textPrimary)
                            .fontWeight(s.id === this.activeSessionId ? FontWeight.Medium : FontWeight.Normal)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                          // 固定会话：主色书签小图标
                          if (s.pinned && USE_SYMBOL_ICONS) {
                            SymbolGlyph(AppIcons.bookmark)
                              .fontSize(14)
                              .fontColor([this.themeState.palette.primary])
                          }
                        }
                        .width('100%')
                        Text(this.sessionMeta(s))
                          .fontSize(this.themeState.palette.fsXs)
                          .fontFamily(this.themeState.palette.fontSans)
                          .fontColor(s.incognito ? this.themeState.palette.warning : this.themeState.palette.textTertiary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      this.incognitoToggle(s)
                    }
                  }
                  .width('100%')
                  .height(this.themeState.palette.rowHeight)
                  .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp1 })
                  .backgroundColor(s.id === this.activeSessionId ? this.themeState.palette.primaryBg : Color.Transparent)
                  .onClick(() => {
                    if (this.drawerRenameId.length === 0) this.onSwitchSession(s.id);
                  })

                  // 发丝分割线（左缩进 dividerIndent）
                  Divider()
                    .strokeWidth(0.5)
                    .color(this.themeState.palette.divider)
                    .margin({ left: this.themeState.palette.dividerIndent })
                }
                .width('100%')
              }
              .swipeAction({
                end: {
                  builder: () => { this.swipeEndActions(s) },
                  actionAreaDistance: 252
                },
                edgeEffect: SwipeEdgeEffect.Spring
              })
            }, (s: ChatSession) => s.id)
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .width('100%')

          // 底部操作：导出 Markdown / 导入 / 备份 / 从文件导入
          Column({ space: this.themeState.palette.sp2 }) {
            Row({ space: this.themeState.palette.sp2 }) {
              this.footerAction('导出 Markdown', false, (): void => { this.onExport(); })
              this.footerAction('导入', false, (): void => { this.onImport(); })
            }
            .width('100%')
            Row({ space: this.themeState.palette.sp2 }) {
              this.footerAction('备份全部会话', false, (): void => { this.onExportFile(); })
              this.footerAction('备份当前会话', false, (): void => { this.onExportCurrentFile(); })
            }
            .width('100%')
            this.footerAction('从文件导入备份', true, (): void => { this.onImportFile(); })
          }
          .width('100%')
        }
        .width(this.themeState.isSm ? '78%' : 320)
        .height('100%')
        .padding({ left: 16, right: 16, top: Math.max(16, this.themeState.navBarHeight) + 12,
          bottom: Math.max(16, this.themeState.navBarHeight) })
        .backgroundColor(this.themeState.palette.bgBase)
        .border({ width: { right: 0.5 }, color: this.themeState.palette.divider })
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
    .backgroundColor(this.themeState.palette.maskOverlay)
  }

}

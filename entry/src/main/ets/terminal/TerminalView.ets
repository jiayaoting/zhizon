// 智子 - 可复用终端渲染组件（沉浸光感版）
// 终端区域保持传统暗色风格，UI控件使用响应式主题
import { ThemePalette, defaultLightPalette, defaultDarkPalette } from '../common/Theme';
import { AnsiSegment, TerminalSession } from '../model/Models';
import { TerminalBuffer, TerminalLine } from './TerminalBuffer';

@Component
export struct TerminalView {
  @Prop lines: string[] = [];
  @Prop prompt: string = '$ ';
  @Prop isConnected: boolean = false;
  @Prop isReconnecting: boolean = false;
  @Prop session: TerminalSession | null = null;
  @Link cmdInput: string;
  @Prop isLoading: boolean = false;
  @Prop quickCmds: string[] = [];
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  onSendCommand?: (cmd: string) => void;
  onResize?: (cols: number, rows: number) => void;
  onReconnect?: () => void;

  private scroller: Scroller = new Scroller();
  private fontWidth: number = 7.8;
  private lineHeight: number = 18;
  private lastCols: number = 0;
  private lastRows: number = 0;

  private isPromptLine(line: string): boolean {
    return line.includes('root@') || (line.includes('#') || line.includes('$ ')) &&
      !line.includes('错误') && !line.includes('失败');
  }

  private isErrorLine(line: string): boolean {
    return line.includes('错误') || line.includes('失败') ||
      line.includes('Error') || line.includes('error');
  }

  private isSuccessLine(line: string): boolean {
    return line.includes('连接成功') || line.includes('已建立') ||
      line.includes('成功');
  }

  // 终端文本颜色：始终使用暗色色板
  private lineColor(line: string): string {
    if (this.isErrorLine(line)) return defaultDarkPalette.danger;
    if (this.isSuccessLine(line)) return defaultDarkPalette.success;
    if (this.isPromptLine(line)) return defaultDarkPalette.primaryHover;
    return defaultDarkPalette.primary;
  }

  build() {
    Column() {
      // 重连状态横幅（UI元素，响应式）
      if (this.isReconnecting) {
        Row() {
          Text('⏳ 正在重新连接...')
            .fontSize(11)
            .fontColor(this.palette.warning)
            .fontFamily(defaultDarkPalette.fontMono)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('rgba(245, 158, 11, 0.1)')
      }

      if (!this.isConnected && !this.isReconnecting && this.session) {
        Row() {
          Text('⚠ 连接已断开')
            .fontSize(11)
            .fontColor(this.palette.danger)
            .fontFamily(defaultDarkPalette.fontMono)
          Blank()
          Button('重连')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .backgroundColor(this.palette.primary)
            .borderRadius(4)
            .height(24)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              if (this.onReconnect) this.onReconnect();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('rgba(239, 68, 68, 0.1)')
      }

      // 终端内容区（始终暗色）
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          if (this.isLoading) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color(defaultDarkPalette.primary)
              .margin({ top: 40 })
            Text('正在连接...')
              .fontSize(13)
              .fontColor(defaultDarkPalette.primary)
              .fontFamily(defaultDarkPalette.fontMono)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
          } else {
            ForEach(this.lines, (line: string) => {
              Text(line)
                .fontSize(12)
                .fontFamily(defaultDarkPalette.fontMono)
                .fontColor(this.lineColor(line))
                .width('100%')
                .lineHeight(this.lineHeight)
            }, (line: string, idx: number) => `${idx}-${line}`)
          }
        }
        .width('100%')
        .padding(this.isSm ? 10 : 12)
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = newValue.width as number;
          const h = newValue.height as number;
          const cols = Math.floor(w / this.fontWidth);
          const rows = Math.floor(h / this.lineHeight);
          if (cols !== this.lastCols || rows !== this.lastRows) {
            this.lastCols = cols;
            this.lastRows = rows;
            if (this.onResize && cols > 0 && rows > 0) {
              this.onResize(cols, rows);
            }
          }
        })
      }
      .layoutWeight(1)
      .backgroundColor('#000000')
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .onDidScroll(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      })

      // 快捷命令栏（UI元素，响应式）
      if (this.quickCmds.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.quickCmds, (cmd: string) => {
              Text(cmd)
                .fontSize(11)
                .fontColor(this.palette.textSecondary)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(6)
                .backgroundColor(this.palette.bgSurface2)
                .fontFamily(defaultDarkPalette.fontMono)
                .onClick(() => {
                  if (this.onSendCommand) this.onSendCommand(cmd);
                })
            }, (cmd: string) => cmd)
          }
          .padding({ left: this.isSm ? 10 : 12, right: this.isSm ? 10 : 12, top: 8, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .backgroundColor(this.palette.bgSurface)
      }

      // 底部输入栏（UI元素，响应式）
      Row({ space: 8 }) {
        TextInput({ placeholder: this.isConnected ? '输入命令...' : '未连接', text: $$this.cmdInput })
          .fontSize(12)
          .fontColor(defaultDarkPalette.textPrimary)
          .fontFamily(defaultDarkPalette.fontMono)
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(6)
          .height(32)
          .layoutWeight(1)
          .enabled(this.isConnected)
          .onSubmit(() => {
            if (this.onSendCommand && this.cmdInput.trim()) {
              this.onSendCommand(this.cmdInput);
            }
          })
        Button('发送')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isConnected ? this.palette.primary : this.palette.textTertiary)
          .borderRadius(6)
          .height(32)
          .padding({ left: 16, right: 16 })
          .enabled(this.isConnected)
          .onClick(() => {
            if (this.onSendCommand && this.cmdInput.trim()) {
              this.onSendCommand(this.cmdInput);
            }
          })
      }
      .width('100%')
      .padding({ left: this.isSm ? 10 : 12, right: this.isSm ? 10 : 12, top: 8, bottom: 8 })
      .backgroundColor(this.palette.bgSurface)
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor('#000000')
  }
}

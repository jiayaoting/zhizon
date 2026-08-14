// 智子 - AI 调用记录查看页（列表 + 详情 + 清空）
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { AiCallLogger } from '../service/AiCallLogger';
import { AiCallLogEntry } from '../service/DatabaseHelper';

// 场景标签与配色
function typeInfo(type: string): [string, string] {
  if (type === 'game') return ['游戏', '#8B5CF6'];
  if (type === 'test') return ['测试', '#10B981'];
  return ['聊天', '#3B82F6'];
}

// 游戏显示名
function gameLabel(game: string): string {
  if (game === '2048') return '2048';
  if (game === 'Tetris') return '俄罗斯方块';
  if (game === 'Snake') return '贪吃蛇';
  if (game === 'Minesweeper') return '扫雷';
  if (game === 'Sudoku') return '数独';
  if (game === 'ChineseChess') return '中国象棋';
  return game;
}

// 耗时显示
function formatDuration(ms: number): string {
  if (ms < 1000) return ms + ' ms';
  return (ms / 1000).toFixed(1) + ' s';
}

// 时间显示
function formatTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
    ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
}

@Entry
@Component
export struct AiCallLogPage {
  @State logs: AiCallLogEntry[] = [];
  @State loading: boolean = true;
  @State expandedId: string = '';
  @State clearing: boolean = false;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    this.logs = await AiCallLogger.loadLogs(500);
    this.loading = false;
  }

  private async clearAll(): Promise<void> {
    if (this.clearing) return;
    this.clearing = true;
    await AiCallLogger.clearLogs();
    this.logs = [];
    this.expandedId = '';
    this.clearing = false;
    promptAction.showToast({ message: '已清空全部调用记录' });
  }

  @Builder
  clearAction() {
    Row() {
      Text('清空')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.danger)
    }
    .width(44)
    .height(30)
    .borderRadius(8)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.logs.length === 0) return;
      AlertDialog.show({
        title: '清空调用记录',
        message: '确定要删除全部 AI 调用记录吗？此操作不可恢复。',
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '清空',
          fontColor: this.palette.danger,
          action: () => {
            this.clearAll();
          }
        }
      });
    })
  }

  @Builder
  logCard(entry: AiCallLogEntry) {
    Column({ space: 8 }) {
      // 首行：类型徽标 + 场景 + 结果 + 耗时
      Row({ space: 8 }) {
        Text(typeInfo(entry.type)[0])
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(Color.White)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .backgroundColor(typeInfo(entry.type)[1])
        Text(entry.type === 'game' ? gameLabel(entry.game) : typeInfo(entry.type)[0])
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(entry.success ? '成功' : '失败')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(entry.success ? '#10B981' : this.palette.danger)
        Text(formatDuration(entry.durationMs))
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 第二行：模型 + 时间
      Row({ space: 8 }) {
        Text(entry.model.length > 0 ? entry.model : '未命名模型')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(formatTime(entry.startTime))
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')

      // 详情（展开）
      if (this.expandedId === entry.id) {
        Column({ space: 6 }) {
          this.detailRow('开始时间', formatTime(entry.startTime))
          this.detailRow('结束时间', formatTime(entry.endTime))
          this.detailRow('请求字符', entry.promptChars.toString())
          this.detailRow('响应字符', entry.responseChars.toString())
          if (!entry.success) {
            this.detailRow('错误码', entry.errorCode.length > 0 ? entry.errorCode : '—')
            this.detailRow('错误信息', entry.errorMsg.length > 0 ? entry.errorMsg : '—')
          }
        }
        .width('100%')
        .padding({ top: 8 })
        .border({ width: { top: 1 }, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
    .onClick(() => {
      this.expandedId = this.expandedId === entry.id ? '' : entry.id;
    })
  }

  @Builder
  detailRow(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .width(60)
      Text(value)
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      TopBar({
        title: 'AI 调用记录',
        subtitle: this.logs.length > 0 ? '共 ' + this.logs.length.toString() + ' 条' : '暂无调用记录',
        showBack: true,
        actions: this.clearAction
      })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.logs.length === 0) {
        Column({ space: 8 }) {
          Text('📋')
            .fontSize(40)
          Text('暂无 AI 调用记录')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
          Text('使用 AI 对话或游戏 AI 托管后，将在此记录每次模型调用摘要')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
        List({ space: 10 }) {
          ForEach(this.logs, (entry: AiCallLogEntry) => {
            ListItem() {
              this.logCard(entry)
            }
          }, (entry: AiCallLogEntry) => entry.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12,
          bottom: Math.max(16, this.navBarHeight) })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}
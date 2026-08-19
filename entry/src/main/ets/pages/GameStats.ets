// 智子 - 战绩统计（趋势图 + 汇总指标）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { DatabaseHelper, GameScoreRecord } from '../service/DatabaseHelper';

function gameIcon(game: string): string {
  if (game === '2048') return '🔢';
  if (game === 'Snake') return '🐍';
  if (game === 'Tetris') return '🧱';
  if (game === 'Minesweeper') return '💣';
  if (game === 'SUDOKU') return '🧩';
  if (game === 'ChineseChess') return '♟️';
  if (game === 'Gomoku') return '⚫';
  return '🎮';
}

function gameName(game: string): string {
  if (game === '2048') return '2048';
  if (game === 'Snake') return '贪吃蛇';
  if (game === 'Tetris') return '俄罗斯方块';
  if (game === 'Minesweeper') return '扫雷';
  if (game === 'SUDOKU') return '数独';
  if (game === 'ChineseChess') return '中国象棋';
  if (game === 'Gomoku') return '五子棋';
  return game;
}

function isBoardGame(game: string): boolean {
  return game === 'Gomoku' || game === 'ChineseChess';
}

@ComponentV2
@Entry
export struct GameStatsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local loading: boolean = true;
  @Local gameKey: string = 'all';
  @Local allScores: GameScoreRecord[] = [];
  private chartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  private gameKeys: string[] = ['all', '2048', 'Snake', 'Tetris', 'Minesweeper', 'SUDOKU', 'ChineseChess', 'Gomoku'];

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.allScores = await DatabaseHelper.getAllGameScores();
    this.loading = false;
  }

  private redrawChart(): void {
    // 切换游戏标签后重绘图表（Canvas.onReady 只在挂载时触发一次）
    setTimeout(() => {
      try {
        this.drawChart();
      } catch (e) {
      }
    }, 60);
  }

  private filtered(): GameScoreRecord[] {
    if (this.gameKey === 'all') return this.allScores;
    const out: GameScoreRecord[] = [];
    for (let i: number = 0; i < this.allScores.length; i++) {
      if (this.allScores[i].game === this.gameKey) out.push(this.allScores[i]);
    }
    return out;
  }

  private recentScores(): GameScoreRecord[] {
    const filtered: GameScoreRecord[] = this.filtered();
    const sorted: GameScoreRecord[] = [];
    // filtered 按时间倒序（新 → 旧），取最前面的 20 局即最近 20 局
    for (let i: number = 0; i < filtered.length && sorted.length < 20; i++) {
      sorted.push(filtered[i]);
    }
    // 反转为时间正序（旧 → 新）
    sorted.reverse();
    return sorted;
  }

  private totalCount(): number {
    return this.filtered().length;
  }

  private maxScore(): number {
    const list: GameScoreRecord[] = this.filtered();
    let max: number = 0;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].score > max) max = list[i].score;
    }
    return max;
  }

  private avgScore(): string {
    const list: GameScoreRecord[] = this.filtered();
    if (list.length === 0) return '-';
    let sum: number = 0;
    for (let i: number = 0; i < list.length; i++) sum += list[i].score;
    return (sum / list.length).toFixed(1);
  }

  private winRate(): string {
    if (!isBoardGame(this.gameKey)) return '-';
    const list: GameScoreRecord[] = this.filtered();
    if (list.length === 0) return '-';
    let wins: number = 0;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].score > 0) wins += 1;
    }
    return Math.round(wins / list.length * 100).toString() + '%';
  }

  @Builder
  statCard(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .layoutWeight(1)
    .padding(10)
    .borderRadius(10)
    .backgroundColor(this.themeState.palette.bgSurface)
  }

  @Builder
  chartArea() {
    Column({ space: 8 }) {
      Text('最近 20 局得分趋势')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Canvas(this.chartCtx)
        .width('100%')
        .height(200)
        .onReady(() => { this.drawChart(); })
        .backgroundColor(this.themeState.palette.bgSurface)
        .borderRadius(10)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(this.themeState.palette.bgSurface)
  }

  private drawChart(): void {
    const ctx: CanvasRenderingContext2D = this.chartCtx;
    const w: number = ctx.width > 0 ? ctx.width : (this.themeState.isSm ? 320 : 480);
    const h: number = ctx.height > 0 ? ctx.height : 200;
    ctx.clearRect(0, 0, w, h);
    const scores: GameScoreRecord[] = this.recentScores();
    if (scores.length === 0) {
      ctx.fillStyle = this.themeState.palette.textSecondary;
      ctx.font = '16px sans-serif';
      ctx.fillText('暂无数据，快去玩一局吧', 20, h / 2);
      return;
    }
    let max: number = 1;
    for (let i: number = 0; i < scores.length; i++) {
      if (scores[i].score > max) max = scores[i].score;
    }
    const leftPad: number = 10;
    const topPad: number = 30;
    const bottomPad: number = 20;
    const slot: number = (w - leftPad * 2) / scores.length;
    const barW: number = Math.max(3, slot * 0.6);
    // 数值标签字体：柱多时略小，保证可读性
    const labelFont: string = scores.length > 12 ? '11px sans-serif' : '12px sans-serif';
    for (let i: number = 0; i < scores.length; i++) {
      const barH: number = Math.max(3, (scores[i].score / max) * (h - topPad - bottomPad));
      const x: number = leftPad + slot * i + (slot - barW) / 2;
      const y: number = h - bottomPad - barH;
      ctx.fillStyle = this.themeState.palette.primary;
      ctx.fillRect(x, y, barW, barH);
      // 柱顶数值标签（主题色，深色/浅色都清晰）
      ctx.fillStyle = this.themeState.palette.textSecondary;
      ctx.font = labelFont;
      const label: string = scores[i].score.toString();
      ctx.fillText(label, x + barW / 2 - label.length * 3, y - 5);
    }
    // 基线
    ctx.strokeStyle = this.themeState.palette.borderSubtle;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(leftPad, h - bottomPad);
    ctx.lineTo(w - leftPad, h - bottomPad);
    ctx.stroke();
    // 最高分提示（14px，明显放大）
    ctx.fillStyle = this.themeState.palette.textSecondary;
    ctx.font = '14px sans-serif';
    ctx.fillText('最高 ' + max.toString(), leftPad, 14);
  }

  build() {
    Column() {
      TopBar({ title: '战绩统计', subtitle: '趋势与汇总', showBack: true })
      // 游戏选择（横向可滑动）
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.gameKeys, (key: string) => {
              Row({ space: 3 }) {
                Text(this.gameKey === 'all' ? '🎮' : gameIcon(key))
                .fontSize(this.themeState.palette.fsSm)
              Text(key === 'all' ? '全部' : gameName(key))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.gameKey === key ? this.themeState.palette.textPrimary : this.themeState.palette.textTertiary)
                .fontWeight(this.gameKey === key ? FontWeight.Bold : FontWeight.Normal)
            }
            .height(32)
            .padding({ left: 10, right: 10 })
            .borderRadius(8)
            .backgroundColor(this.gameKey === key ? this.themeState.palette.primary + '22' : Color.Transparent)
            .onClick(() => {
              this.gameKey = key;
              this.redrawChart();
            })
          })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.None)

      // 纵向内容
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            this.statCard('总局数', this.totalCount().toString())
            this.statCard('最高分', this.maxScore().toString())
            this.statCard('平均分', this.avgScore())
            this.statCard('胜率', this.winRate())
          }
          .width('100%')

          this.chartArea()
          Column().height(20)
        }
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

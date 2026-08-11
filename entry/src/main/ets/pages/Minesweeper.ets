// 智子 - 扫雷
import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DataRepository } from '../service/DataRepository';
import { DifficultyLevel, difficultyLabel, GameId, GameLaunchFacade, GameLaunchResult,
  GameRouteParams } from '../common/Difficulty';
import { GameHistoryRouteParams } from '../common/Navigation';

// 难度配置
class MinesweeperConfig {
  rows: number;
  cols: number;
  mines: number;
  constructor(rows: number, cols: number, mines: number) {
    this.rows = rows;
    this.cols = cols;
    this.mines = mines;
  }
}

function configFor(level: DifficultyLevel): MinesweeperConfig {
  if (level === DifficultyLevel.VERY_EASY) return new MinesweeperConfig(9, 9, 10);
  if (level === DifficultyLevel.EASY) return new MinesweeperConfig(12, 12, 20);
  if (level === DifficultyLevel.MEDIUM) return new MinesweeperConfig(16, 16, 40);
  if (level === DifficultyLevel.HARD) return new MinesweeperConfig(14, 22, 60);
  return new MinesweeperConfig(16, 30, 99);
}

// 格子状态
@Observed
class MineCell {
  isMine: boolean = false;
  adjacent: number = 0;
  revealed: boolean = false;
  flagged: boolean = false;
}

interface MinePos {
  r: number;
  c: number;
}

@Component
export struct MinesweeperPage {
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false;
  @State isGameOver: boolean = false;
  @State isWin: boolean = false;
  @State isPaused: boolean = false;
  @State autoPaused: boolean = false;
  @State flagMode: boolean = false;
  @State board: MineCell[][] = [];
  @State remainingMines: number = 0;
  @State score: number = 0;
  @State bestScore: number = 0;
  @State playSeconds: number = 0;
  @State newRecord: boolean = false;
  @State cursorR: number = 0;
  @State cursorC: number = 0;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  private timerId: number = -1;
  private titleText: string = '扫雷';
  private rows: number = 9;
  private cols: number = 9;
  private mineCount: number = 10;
  private firstClick: boolean = true;
  private gameStartTime: number = 0;
  private scoreSaved: boolean = false;

  // ---- 触觉反馈 ----
  private vibrate(duration: number): void {
    try {
      vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'physicalFeedback' });
    } catch (e) {
      // 设备不支持振动时静默忽略
    }
  }

  private formatDuration(seconds: number): string {
    const m: number = Math.floor(seconds / 60);
    const s: number = Math.floor(seconds % 60);
    return m > 0 ? `${m} 分 ${s} 秒` : `${s} 秒`;
  }

  // ---- 计时 ----
  private startTimer(): void {
    this.stopTimer();
    this.timerId = setInterval(() => {
      if (this.isPaused || this.isGameOver) return;
      this.playSeconds += 1;
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // ---- 游戏初始化 ----
  private initBoard(): void {
    const config: MinesweeperConfig = configFor(this.difficulty);
    this.rows = config.rows;
    this.cols = config.cols;
    this.mineCount = config.mines;
    const grid: MineCell[][] = [];
    for (let r: number = 0; r < this.rows; r++) {
      const row: MineCell[] = [];
      for (let c: number = 0; c < this.cols; c++) {
        row.push(new MineCell());
      }
      grid.push(row);
    }
    this.board = grid;
    this.remainingMines = this.mineCount;
    this.firstClick = true;
  }

  // 首次翻开后布雷（保证首开安全）
  private placeMines(safeR: number, safeC: number): void {
    let placed: number = 0;
    let attempts: number = 0;
    while (placed < this.mineCount && attempts < 100000) {
      attempts += 1;
      const r: number = Math.floor(Math.random() * this.rows);
      const c: number = Math.floor(Math.random() * this.cols);
      if (this.board[r][c].isMine) continue;
      if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1) continue;
      this.board[r][c].isMine = true;
      placed += 1;
    }
    // 计算邻雷数
    for (let r: number = 0; r < this.rows; r++) {
      for (let c: number = 0; c < this.cols; c++) {
        if (this.board[r][c].isMine) continue;
        this.board[r][c].adjacent = this.countAdjacentMines(r, c);
      }
    }
  }

  private countAdjacentMines(r: number, c: number): number {
    let count: number = 0;
    for (let dr: number = -1; dr <= 1; dr++) {
      for (let dc: number = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue;
        const nr: number = r + dr;
        const nc: number = c + dc;
        if (nr >= 0 && nr < this.rows && nc >= 0 && nc < this.cols && this.board[nr][nc].isMine) {
          count += 1;
        }
      }
    }
    return count;
  }

  // ---- 翻开格子 ----
  revealCell(r: number, c: number): void {
    if (!this.gameStarted || this.isGameOver || this.isPaused || this.isWin) return;
    if (r < 0 || r >= this.rows || c < 0 || c >= this.cols) return;
    const cell: MineCell = this.board[r][c];
    if (cell.revealed || cell.flagged) return;

    if (this.firstClick) {
      this.firstClick = false;
      this.placeMines(r, c);
      this.startTimer();
    }

    if (cell.isMine) {
      cell.revealed = true;
      this.isGameOver = true;
      this.stopTimer();
      this.vibrate(80);
      // 展示所有雷
      for (let rr: number = 0; rr < this.rows; rr++) {
        for (let cc: number = 0; cc < this.cols; cc++) {
          if (this.board[rr][cc].isMine && !this.board[rr][cc].flagged) {
            this.board[rr][cc].revealed = true;
          }
        }
      }
      this.score = 0;
      return;
    }

    this.vibrate(5);
    this.floodReveal(r, c);
    this.checkWin();
  }

  private floodReveal(sr: number, sc: number): void {
    const stack: MinePos[] = [];
    stack.push({ r: sr, c: sc });
    while (stack.length > 0) {
      const cur: MinePos = stack[stack.length - 1];
      stack.pop();
      const cell: MineCell = this.board[cur.r][cur.c];
      if (cell.revealed || cell.flagged) continue;
      cell.revealed = true;
      if (cell.adjacent > 0) continue;
      for (let dr: number = -1; dr <= 1; dr++) {
        for (let dc: number = -1; dc <= 1; dc++) {
          if (dr === 0 && dc === 0) continue;
          const nr: number = cur.r + dr;
          const nc: number = cur.c + dc;
          if (nr >= 0 && nr < this.rows && nc >= 0 && nc < this.cols) {
            stack.push({ r: nr, c: nc });
          }
        }
      }
    }
  }

  // ---- 标旗 ----
  toggleFlag(r: number, c: number): void {
    if (!this.gameStarted || this.isGameOver || this.isPaused || this.isWin) return;
    const cell: MineCell = this.board[r][c];
    if (cell.revealed) return;
    if (cell.flagged) {
      cell.flagged = false;
      this.remainingMines += 1;
    } else {
      if (this.remainingMines <= 0) return;
      cell.flagged = true;
      this.remainingMines -= 1;
      this.vibrate(5);
    }
    // 全旗=全雷 判定胜利
    this.checkWin();
  }

  private checkWin(): void {
    let safeHidden: number = 0;
    let correctFlags: number = 0;
    for (let r: number = 0; r < this.rows; r++) {
      for (let c: number = 0; c < this.cols; c++) {
        const cell: MineCell = this.board[r][c];
        if (!cell.isMine && !cell.revealed) safeHidden += 1;
        if (cell.isMine && cell.flagged) correctFlags += 1;
      }
    }
    if (safeHidden === 0 || correctFlags === this.mineCount) {
      this.isWin = true;
      this.stopTimer();
      this.vibrate(30);
      this.finishGame(true);
    }
  }

  // ---- 游戏结束收尾 ----
  private finishGame(win: boolean): void {
    const cells: number = this.rows * this.cols;
    this.score = Math.max(100, this.mineCount * 80 + cells - this.playSeconds * 2);
    if (!win) this.score = 0;
    if (win) {
      this.newRecord = this.score > this.bestScore;
      if (this.newRecord) this.bestScore = this.score;
      this.saveScore();
    }
  }

  private saveScore(): void {
    if (this.scoreSaved) return;
    this.scoreSaved = true;
    DataRepository.addGameScore('Minesweeper', this.score, 1, difficultyLabel(this.difficulty));
  }

  // ---- 游戏控制 ----
  private startWithDifficulty(level: DifficultyLevel): void {
    this.difficulty = level;
    this.gameStarted = true;
    this.isGameOver = false;
    this.isWin = false;
    this.isPaused = false;
    this.autoPaused = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.gameStartTime = Date.now();
    this.initBoard();
  }

  restartGame(): void {
    this.stopTimer();
    this.isGameOver = false;
    this.isWin = false;
    this.isPaused = false;
    this.autoPaused = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.gameStartTime = Date.now();
    this.initBoard();
  }

  togglePause(): void {
    if (this.isGameOver || this.isWin) return;
    this.isPaused = !this.isPaused;
    this.autoPaused = false;
  }

  onPageHide(): void {
    if (!this.isPaused && !this.isGameOver && !this.isWin && this.gameStarted) {
      this.autoPaused = true;
      this.isPaused = true;
    }
  }

  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.isPaused = false;
      promptAction.showToast({ message: '已恢复游戏' });
    }
  }

  cycleDifficulty(): void {
    const order: DifficultyLevel[] = [
      DifficultyLevel.VERY_EASY, DifficultyLevel.EASY, DifficultyLevel.MEDIUM,
      DifficultyLevel.HARD, DifficultyLevel.HELL
    ];
    let idx: number = 0;
    for (let i: number = 0; i < order.length; i++) {
      if (order[i] === this.difficulty) { idx = i; break; }
    }
    this.difficulty = order[(idx + 1) % order.length];
    promptAction.showToast({ message: `难度：${difficultyLabel(this.difficulty)}` });
  }

  private async loadBestScore(): Promise<void> {
    const best: number = await DataRepository.getGameHighScore('Minesweeper');
    this.bestScore = best;
  }

  // ---- 键盘操作 ----
  private handleKey(code: KeyCode): void {
    if (code === KeyCode.KEYCODE_P || code === KeyCode.KEYCODE_ENTER) {
      this.togglePause();
      return;
    }
    if (code === KeyCode.KEYCODE_R) {
      this.restartGame();
      return;
    }
    if (this.isGameOver || this.isPaused || this.isWin || !this.gameStarted) return;
    if (code === KeyCode.KEYCODE_DPAD_LEFT || code === KeyCode.KEYCODE_A) {
      this.cursorC = Math.max(0, this.cursorC - 1);
    } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
      this.cursorC = Math.min(this.cols - 1, this.cursorC + 1);
    } else if (code === KeyCode.KEYCODE_DPAD_UP || code === KeyCode.KEYCODE_W) {
      this.cursorR = Math.max(0, this.cursorR - 1);
    } else if (code === KeyCode.KEYCODE_DPAD_DOWN || code === KeyCode.KEYCODE_S) {
      this.cursorR = Math.min(this.rows - 1, this.cursorR + 1);
    } else if (code === KeyCode.KEYCODE_SPACE) {
      this.revealCell(this.cursorR, this.cursorC);
    } else if (code === KeyCode.KEYCODE_F) {
      this.toggleFlag(this.cursorR, this.cursorC);
    }
  }

  // 棋盘宽高比（cols/rows），用于约束外层容器
  private boardAspectRatio(): number {
    if (this.rows <= 0) return 1;
    return this.cols / this.rows;
  }

  // ---- 棋盘 ----
  @Builder
  gameBoard() {
    Column() {
      ForEach(this.board, (row: MineCell[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: MineCell, colIdx: number) => {
            Row() {
              Text(this.cellText(cell))
                .fontSize(this.cellFontSize())
                .fontFamily(this.palette.fontSans)
                .fontColor(this.cellTextColor(cell))
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .borderRadius(2)
            .border({ width: this.cursorR === rowIdx && this.cursorC === colIdx ? 2 : 0.5,
              color: this.cursorR === rowIdx && this.cursorC === colIdx ? this.palette.primary : this.palette.borderDefault })
            .backgroundColor(this.cellColor(cell))
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.flagMode) {
                this.toggleFlag(rowIdx, colIdx);
              } else {
                this.revealCell(rowIdx, colIdx);
              }
            })
            .onLongPress(() => { this.toggleFlag(rowIdx, colIdx); })
          }, (cell: MineCell, colIdx: number) => colIdx.toString())
        }
        .layoutWeight(1)
      }, (row: MineCell[], rowIdx: number) => rowIdx.toString())
    }
    .border({ width: 2, color: this.palette.borderDefault })
    .borderRadius(6)
    .padding(2)
    .backgroundColor(this.palette.bgSurface)
  }

  private cellColor(cell: MineCell): string {
    if (cell.revealed) {
      return this.palette.bgSurface2;
    }
    if (cell.flagged) {
      return this.palette.primaryDim;
    }
    return this.palette.bgSurface;
  }

  private cellText(cell: MineCell): string {
    if (!cell.revealed) {
      if (cell.flagged) return '🚩';
      return '';
    }
    if (cell.isMine) return '💣';
    if (cell.adjacent === 0) return '';
    return cell.adjacent.toString();
  }

  private cellTextColor(cell: MineCell): string {
    if (!cell.revealed) return this.palette.textPrimary;
    if (cell.isMine) return this.palette.danger;
    if (cell.adjacent === 1) return this.palette.info;
    if (cell.adjacent === 2) return this.palette.success;
    if (cell.adjacent === 3) return this.palette.danger;
    return this.palette.textTertiary;
  }

  private cellFontSize(): number {
    const n: number = Math.min(this.cols, 16);
    if (n <= 9) return 14;
    if (n <= 12) return 12;
    if (n <= 16) return 10;
    return 8;
  }

  // ---- 棋盘 ----
  @Builder
  gameBoard() {
    Column() {
      ForEach(this.board, (row: MineCell[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: MineCell, colIdx: number) => {
            Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .margin(0.5)
              .borderRadius(2)
              .border({ width: 0.5, color: this.palette.borderDefault })
              .backgroundColor(this.cellColor(cell))
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                if (this.flagMode) {
                  this.toggleFlag(rowIdx, colIdx);
                } else {
                  this.revealCell(rowIdx, colIdx);
                }
              })
              .onLongPress(() => { this.toggleFlag(rowIdx, colIdx); })
              .child(
                Text(this.cellText(cell))
                  .fontSize(this.cellFontSize())
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.cellTextColor(cell))
                  .fontWeight(FontWeight.Bold)
              )
          }, (cell: MineCell, colIdx: number) => colIdx.toString())
        }
        .layoutWeight(1)
      }, (row: MineCell[], rowIdx: number) => rowIdx.toString())
    }
    .border({ width: 2, color: this.palette.borderDefault })
    .borderRadius(6)
    .padding(2)
    .backgroundColor(this.palette.bgSurface)
  }

  // ---- 信息面板 ----
  @Builder
  infoPanel() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('剩余雷')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.remainingMines.toString())
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.danger)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })

      Column({ space: 2 }) {
        Text('用时')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.formatDuration(this.playSeconds))
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.info)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })

      Column({ space: 2 }) {
        Text('最佳')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.bestScore.toString())
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.warning)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })
    }
    .width('100%')
  }

  // ---- 模式切换 ----
  @Builder
  modeBar() {
    Row({ space: 8 }) {
      Row() {
        Text(this.flagMode ? '🚩 标旗模式' : '🖱 翻开模式')
          .fontSize(this.palette.fsSm)
          .fontColor(this.flagMode ? this.palette.danger : this.palette.primary)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(this.flagMode ? this.palette.primaryDim : this.palette.bgSurface2)
      .onClick(() => { this.flagMode = !this.flagMode; })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Text('长按格子也可标旗')
        .fontSize(this.palette.fsXs)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontSans)
    }
    .width('100%')
  }

  // ---- 顶栏操作按钮 ----
  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      Row() {
        Text('🏆')
          .fontSize(14)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
         router.pushUrl({ url: 'pages/GameHistory', params: new GameHistoryRouteParams('Minesweeper') });
      })

      Row() {
        Text(this.isPaused ? '▶' : '⏸')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.togglePause(); })

      Row() {
        Text('↺')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.restartGame(); })
    }
  }

  // ---- 游戏结束遮罩 ----
  @Builder
  gameOverOverlay() {
    Stack() {
      Column({ space: 12 }) {
        Text(this.isWin ? '🎉 胜利！' : '💥 踩雷了')
          .fontSize(this.palette.fs2xl)
          .fontColor(this.isWin ? this.palette.primary : this.palette.danger)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
        if (this.isWin && this.newRecord) {
          Text('🎉 新纪录！')
            .fontSize(this.palette.fsMd)
            .fontColor(this.palette.warning)
            .fontFamily(this.palette.fontSans)
            .fontWeight(FontWeight.Bold)
        }
        if (this.isWin) {
          Text('得分：' + this.score.toString())
            .fontSize(this.palette.fsMd)
            .fontColor(this.palette.textPrimary)
            .fontFamily(this.palette.fontSans)
            .fontWeight(FontWeight.Medium)
          Text('用时 ' + this.formatDuration(this.playSeconds) + ' · 历史最高 ' + this.bestScore.toString())
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontSans)
        } else {
          Text('用时 ' + this.formatDuration(this.playSeconds))
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontSans)
        }
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Row() {
              Text('↺')
                .fontSize(22)
                .fontColor('#0A0E1A')
                .fontWeight(FontWeight.Bold)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.palette.primary)
            .justifyContent(FlexAlign.Center)
            Text('重新开始')
              .fontSize(this.palette.fsXs)
              .fontColor(this.palette.textSecondary)
              .fontFamily(this.palette.fontSans)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.restartGame(); })

          Column({ space: 6 }) {
            Row() {
              Text('←')
                .fontSize(22)
                .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('返回')
              .fontSize(this.palette.fsXs)
              .fontColor(this.palette.textSecondary)
              .fontFamily(this.palette.fontSans)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { router.back(); })
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(10, 14, 26, 0.85)')
    .alignContent(Alignment.Center)
  }

  // ---- 暂停遮罩 ----
  @Builder
  pauseOverlay() {
    Stack() {
      Column({ space: 12 }) {
        Text('已暂停')
          .fontSize(this.palette.fs2xl)
          .fontColor(this.palette.textPrimary)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
        Row({ space: 10 }) {
          Text('难度')
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontSans)
          Text(difficultyLabel(this.difficulty))
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.primary)
            .fontFamily(this.palette.fontSans)
            .fontWeight(FontWeight.Medium)
          Text('›')
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(this.palette.bgSurface2)
        .onClick(() => { this.cycleDifficulty(); })
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Row() {
              Text('▶')
                .fontSize(20)
                .fontColor('#0A0E1A')
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.palette.primary)
            .justifyContent(FlexAlign.Center)
            Text('继续')
              .fontSize(this.palette.fsXs)
              .fontColor(this.palette.textSecondary)
              .fontFamily(this.palette.fontSans)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.togglePause(); })

          Column({ space: 6 }) {
            Row() {
              Text('↺')
                .fontSize(20)
                .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('重新开始')
              .fontSize(this.palette.fsXs)
              .fontColor(this.palette.textSecondary)
              .fontFamily(this.palette.fontSans)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.restartGame(); })

          Column({ space: 6 }) {
            Row() {
              Text('←')
                .fontSize(20)
                .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('返回')
              .fontSize(this.palette.fsXs)
              .fontColor(this.palette.textSecondary)
              .fontFamily(this.palette.fontSans)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { router.back(); })
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(10, 14, 26, 0.7)')
    .alignContent(Alignment.Center)
  }

  // ---- 生命周期 ----
  aboutToAppear(): void {
    const params: GameRouteParams | null = router.getParams() as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.MINESWEEPER);
    if (!result.success || result.request === null) {
      promptAction.showToast({ message: result.message });
      router.back();
      return;
    }
    this.loadBestScore();
    this.startWithDifficulty(result.request.difficulty);
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.gameStarted && this.score > 0 && !this.scoreSaved) {
      this.saveScore();
    }
  }

  build() {
    Stack() {
      Column() {
        TopBar({
          title: this.titleText,
          subtitle: difficultyLabel(this.difficulty),
          showBack: true
        }) {
          this.actionsBuilder()
        }

        if (this.isSm) {
          if (this.gameStarted) {
            Column({ space: 8 }) {
              this.infoPanel()
              Stack() {
                Column() {
                  this.gameBoard()
                }
                if (this.isGameOver || this.isWin) { this.gameOverOverlay() }
                if (this.isPaused) { this.pauseOverlay() }
              }
              .width('100%')
              .layoutWeight(1)
              this.modeBar()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .justifyContent(FlexAlign.Center)
          }
        } else {
          if (this.gameStarted) {
            Row({ space: 20 }) {
              Column({ space: 12 }) {
                Stack() {
                  Column() {
                    this.gameBoard()
                  }
                  if (this.isGameOver || this.isWin) { this.gameOverOverlay() }
                  if (this.isPaused) { this.pauseOverlay() }
                }
                .width('100%')
                .aspectRatio(this.boardAspectRatio())
                .alignContent(Alignment.Center)
                this.modeBar()
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)

              Scroll() {
                Column({ space: 12 }) {
                  this.infoPanel()
                  Column({ space: 6 }) {
                    Text('操作提示')
                      .fontSize(this.palette.fsXs)
                      .fontColor(this.palette.textTertiary)
                      .fontFamily(this.palette.fontSans)
                    Column({ space: 4 }) {
                      Text('点击/空格：翻开格子')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
                        .fontFamily(this.palette.fontSans)
                      Text('长按/标旗模式/F：标记地雷')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
                        .fontFamily(this.palette.fontSans)
                      Text('方向键/WASD：移动光标')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
                        .fontFamily(this.palette.fontSans)
                      Text('首次点击必安全，数字=周围雷数')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.primary)
                        .fontFamily(this.palette.fontSans)
                    }
                    .padding(14)
                    .backgroundColor(this.palette.bgSurface)
                    .borderRadius(10)
                    .border({ width: 1, color: this.palette.borderSubtle })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
              }
              .layoutWeight(1)
              .scrollBar(BarState.Off)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 24, right: 24, top: 8, bottom: 8 })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.palette.bgBase)
      .focusable(true)
      .defaultFocus(true)
      .onKeyEvent((event: KeyEvent) => {
        if (event.type !== KeyType.Down) return;
        this.handleKey(event.keyCode);
      })
    }
    .width('100%')
    .height('100%')
  }
}

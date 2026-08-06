// 智子 - 俄罗斯方块
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';

const COLS: number = 10;
const ROWS: number = 20;
const CELL_SIZE_SM: number = 16;
const CELL_SIZE_LG: number = 24;

// 方块形状定义（4个旋转状态，每个状态4个坐标块）
const SHAPES: Array<Array<Array<[number, number]>>> = [
  // I
  [[[0,0],[1,0],[2,0],[3,0]], [[2,-1],[2,0],[2,1],[2,2]], [[0,1],[1,1],[2,1],[3,1]], [[1,-1],[1,0],[1,1],[1,2]]],
  // O
  [[[0,0],[1,0],[0,1],[1,1]], [[0,0],[1,0],[0,1],[1,1]], [[0,0],[1,0],[0,1],[1,1]], [[0,0],[1,0],[0,1],[1,1]]],
  // T
  [[[1,0],[0,1],[1,1],[2,1]], [[1,0],[1,1],[2,1],[1,2]], [[0,1],[1,1],[2,1],[1,1]], [[1,0],[0,1],[1,1],[1,2]]],
  // S
  [[[1,0],[2,0],[0,1],[1,1]], [[1,0],[1,1],[2,1],[2,2]], [[1,0],[2,0],[0,1],[1,1]], [[1,0],[1,1],[2,1],[2,2]]],
  // Z
  [[[0,0],[1,0],[1,1],[2,1]], [[2,0],[1,1],[2,1],[1,2]], [[0,0],[1,0],[1,1],[2,1]], [[2,0],[1,1],[2,1],[1,2]]],
  // J
  [[[0,0],[0,1],[1,1],[2,1]], [[1,0],[2,0],[1,1],[1,2]], [[0,1],[1,1],[2,1],[2,2]], [[1,0],[0,2],[1,1],[1,2]]],
  // L
  [[[2,0],[0,1],[1,1],[2,1]], [[1,0],[1,1],[1,2],[2,2]], [[0,1],[1,1],[2,1],[0,2]], [[0,0],[1,0],[1,1],[1,2]]]
];

const PIECE_COLORS: string[] = [
  AppTheme.primary,   // I - 青绿
  AppTheme.warning,   // O - 黄
  AppTheme.purple,    // T - 紫
  AppTheme.success,   // S - 绿
  AppTheme.danger,    // Z - 红
  AppTheme.info,      // J - 蓝
  '#F97316'           // L - 橙
];

// 分数规则
function scoreForLines(lines: number): number {
  if (lines === 1) return 100;
  if (lines === 2) return 300;
  if (lines === 3) return 500;
  if (lines === 4) return 800;
  return 0;
}

// 下落间隔（毫秒），随等级递减
function dropInterval(level: number): number {
  const base: number = 800;
  const min: number = 80;
  const interval: number = base - (level - 1) * 70;
  return Math.max(interval, min);
}

interface Piece {
  type: number;
  rotation: number;
  x: number;
  y: number;
}

@Entry
@Component
export struct TetrisPage {
  @State board: number[][] = [];
  @State currentPiece: Piece | null = null;
  @State nextType: number = 0;
  @State score: number = 0;
  @State level: number = 1;
  @State lines: number = 0;
  @State isGameOver: boolean = false;
  @State isPaused: boolean = false;
  @State clearedRows: number[] = [];
  @StorageLink('isSm') isSm: boolean = false;

  private timerId: number = -1;
  private titleText: string = '俄罗斯方块';

  // ---- 棋盘初始化 ----
  private initBoard(): void {
    const b: number[][] = [];
    for (let r: number = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < COLS; c++) {
        row.push(0);
      }
      b.push(row);
    }
    this.board = b;
  }

  private randomType(): number {
    return Math.floor(Math.random() * 7);
  }

  private spawnPiece(): void {
    const t: number = this.nextType;
    this.nextType = this.randomType();
    const shape: number[][] = SHAPES[t][0];
    const pieceX: number = Math.floor((COLS - this.pieceWidth(shape)) / 2);
    this.currentPiece = { type: t, rotation: 0, x: pieceX, y: 0 };
  }

  private pieceWidth(shape: number[][]): number {
    let maxX: number = 0;
    for (let i: number = 0; i < shape.length; i++) {
      if (shape[i][0] > maxX) maxX = shape[i][0];
    }
    return maxX + 1;
  }

  // ---- 碰撞检测 ----
  private collides(type: number, rotation: number, px: number, py: number): boolean {
    const shape: number[][] = SHAPES[type][rotation];
    for (let i: number = 0; i < shape.length; i++) {
      const bx: number = px + shape[i][0];
      const by: number = py + shape[i][1];
      if (bx < 0 || bx >= COLS || by >= ROWS) return true;
      if (by >= 0 && this.board[by][bx] !== 0) return true;
    }
    return false;
  }

  // ---- 移动与旋转 ----
  private movePiece(dx: number, dy: number): boolean {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return false;
    const p: Piece = this.currentPiece;
    if (!this.collides(p.type, p.rotation, p.x + dx, p.y + dy)) {
      this.currentPiece = { type: p.type, rotation: p.rotation, x: p.x + dx, y: p.y + dy };
      return true;
    }
    return false;
  }

  moveLeft(): void { this.movePiece(-1, 0); }
  moveRight(): void { this.movePiece(1, 0); }

  rotatePiece(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    const newRot: number = (p.rotation + 1) % 4;
    // 尝试基础旋转
    if (!this.collides(p.type, newRot, p.x, p.y)) {
      this.currentPiece = { type: p.type, rotation: newRot, x: p.x, y: p.y };
      return;
    }
    // Wall kick：尝试左右偏移
    const kicks: number[] = [-1, 1, -2, 2];
    for (let k: number = 0; k < kicks.length; k++) {
      if (!this.collides(p.type, newRot, p.x + kicks[k], p.y)) {
        this.currentPiece = { type: p.type, rotation: newRot, x: p.x + kicks[k], y: p.y };
        return;
      }
    }
  }

  hardDrop(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    let dropY: number = p.y;
    while (!this.collides(p.type, p.rotation, p.x, dropY + 1)) {
      dropY++;
    }
    this.currentPiece = { type: p.type, rotation: p.rotation, x: p.x, y: dropY };
    this.lockPiece();
  }

  // ---- 锁定方块 ----
  private lockPiece(): void {
    if (this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    const shape: number[][] = SHAPES[p.type][p.rotation];
    const newBoard: number[][] = [];
    for (let r: number = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < COLS; c++) {
        row.push(this.board[r][c]);
      }
      newBoard.push(row);
    }
    for (let i: number = 0; i < shape.length; i++) {
      const bx: number = p.x + shape[i][0];
      const by: number = p.y + shape[i][1];
      if (by >= 0 && by < ROWS && bx >= 0 && bx < COLS) {
        newBoard[by][bx] = p.type + 1;
      }
    }
    this.board = newBoard;

    // 检查消除
    const fullRows: number[] = [];
    for (let r: number = 0; r < ROWS; r++) {
      let full: boolean = true;
      for (let c: number = 0; c < COLS; c++) {
        if (this.board[r][c] === 0) { full = false; break; }
      }
      if (full) fullRows.push(r);
    }

    if (fullRows.length > 0) {
      this.clearedRows = fullRows;
      // 消除行
      const afterBoard: number[][] = [];
      for (let r: number = ROWS - 1; r >= 0; r--) {
        if (fullRows.indexOf(r) === -1) {
          const row: number[] = [];
          for (let c: number = 0; c < COLS; c++) {
            row.push(this.board[r][c]);
          }
          afterBoard.unshift(row);
        }
      }
      while (afterBoard.length < ROWS) {
        const emptyRow: number[] = [];
        for (let c: number = 0; c < COLS; c++) emptyRow.push(0);
        afterBoard.unshift(emptyRow);
      }
      this.board = afterBoard;

      const cleared: number = fullRows.length;
      this.lines += cleared;
      this.score += scoreForLines(cleared);
      this.level = Math.floor(this.lines / 10) + 1;

      // 清除动画标记
      setTimeout(() => { this.clearedRows = []; }, 200);
    }

    // 生成新方块
    this.spawnPiece();

    // 检查游戏结束
    if (this.currentPiece !== null && this.collides(this.currentPiece.type, this.currentPiece.rotation, this.currentPiece.x, this.currentPiece.y)) {
      this.isGameOver = true;
      this.currentPiece = null;
      this.stopTimer();
    }
  }

  // ---- 下落 ----
  private drop(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    if (!this.collides(p.type, p.rotation, p.x, p.y + 1)) {
      this.currentPiece = { type: p.type, rotation: p.rotation, x: p.x, y: p.y + 1 };
    } else {
      this.lockPiece();
    }
  }

  // ---- 定时器 ----
  private startTimer(): void {
    this.stopTimer();
    const interval: number = dropInterval(this.level);
    this.timerId = setInterval(() => { this.drop(); }, interval);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private restartTimer(): void {
    this.stopTimer();
    this.startTimer();
  }

  // ---- 游戏控制 ----
  restartGame(): void {
    this.initBoard();
    this.score = 0;
    this.level = 1;
    this.lines = 0;
    this.isGameOver = false;
    this.isPaused = false;
    this.clearedRows = [];
    this.nextType = this.randomType();
    this.spawnPiece();
    this.startTimer();
  }

  togglePause(): void {
    if (this.isGameOver) return;
    this.isPaused = !this.isPaused;
  }

  // ---- 获取合并后的棋盘（含当前活动方块） ----
  private getDisplayBoard(): number[][] {
    const display: number[][] = [];
    for (let r: number = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < COLS; c++) {
        row.push(this.board[r][c]);
      }
      display.push(row);
    }
    if (this.currentPiece !== null && !this.isGameOver) {
      const p: Piece = this.currentPiece;
      const shape: number[][] = SHAPES[p.type][p.rotation];
      for (let i: number = 0; i < shape.length; i++) {
        const bx: number = p.x + shape[i][0];
        const by: number = p.y + shape[i][1];
        if (by >= 0 && by < ROWS && bx >= 0 && bx < COLS) {
          display[by][bx] = p.type + 1;
        }
      }
    }
    return display;
  }

  // ---- 预览方块 ----
  @Builder
  previewPiece(type: number) {
    Column() {
      ForEach(SHAPES[type][0], (block: number[]) => {
        Row() {
          ForEach([0, 1, 2, 3], (col: number) => {
            Row()
              .width(16)
              .height(16)
              .margin(1)
              .backgroundColor(this.isBlockFilled(SHAPES[type][0], col, block[1]) ? PIECE_COLORS[type] : Color.Transparent)
              .borderRadius(2)
          }, (col: number) => col.toString())
        }
      }, (block: number[]) => block[0].toString() + '_' + block[1].toString())
    }
    .alignItems(HorizontalAlign.Center)
  }

  private isBlockFilled(shape: Array<[number, number]>, col: number, row: number): boolean {
    for (let i: number = 0; i < shape.length; i++) {
      if (shape[i][0] === col && shape[i][1] === row) return true;
    }
    return false;
  }

  // ---- 棋盘渲染 ----
  @Builder
  gameBoard() {
    Column() {
      ForEach(this.getDisplayBoard(), (row: number[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: number, colIdx: number) => {
            Row()
              .width(this.isSm ? CELL_SIZE_SM : CELL_SIZE_LG)
              .height(this.isSm ? CELL_SIZE_SM : CELL_SIZE_LG)
              .margin(0.5)
              .borderRadius(2)
              .backgroundColor(cell > 0 ? PIECE_COLORS[cell - 1] : AppTheme.bgSurface2)
              .border({ width: cell > 0 ? 0.5 : 0, color: 'rgba(255,255,255,0.1)' })
          }, (colIdx: number) => colIdx.toString())
        }
      }, (rowIdx: number) => rowIdx.toString())
    }
    .border({ width: 2, color: AppTheme.borderDefault })
    .borderRadius(6)
    .padding(2)
    .backgroundColor(AppTheme.bgSurface)
  }

  // ---- 控制按钮 ----
  @Builder
  controlButtons() {
    Column({ space: 6 }) {
      // 旋转
      Row() {
        Text('↻ 旋转')
          .fontSize(AppTheme.fsSm)
          .fontColor(AppTheme.textSecondary)
      }
      .width('100%')
      .height(this.isSm ? 36 : 48)
      .borderRadius(10)
      .backgroundColor(AppTheme.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .border({ width: 1, color: AppTheme.borderSubtle })
      .onClick(() => { this.rotatePiece(); })

      // 左右 + 下落
      Row({ space: 6 }) {
        // 左
        Row() {
          Text('◀')
            .fontSize(18)
            .fontColor(AppTheme.textPrimary)
        }
        .layoutWeight(1)
        .height(this.isSm ? 36 : 48)
        .borderRadius(10)
        .backgroundColor(AppTheme.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: AppTheme.borderSubtle })
        .onClick(() => { this.moveLeft(); })

        // 下
        Row() {
          Text('▼')
            .fontSize(18)
            .fontColor(AppTheme.primary)
        }
        .layoutWeight(1)
        .height(this.isSm ? 36 : 48)
        .borderRadius(10)
        .backgroundColor(AppTheme.primaryDim)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: AppTheme.primary })
        .onClick(() => { this.hardDrop(); })

        // 右
        Row() {
          Text('▶')
            .fontSize(18)
            .fontColor(AppTheme.textPrimary)
        }
        .layoutWeight(1)
        .height(this.isSm ? 36 : 48)
        .borderRadius(10)
        .backgroundColor(AppTheme.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: AppTheme.borderSubtle })
        .onClick(() => { this.moveRight(); })
      }
      .width('100%')
    }
  }

  // ---- 信息面板 ----
  @Builder
  infoPanel() {
    Column({ space: 12 }) {
      // 下一个方块 — 放最前面确保可见
      Column({ space: 4 }) {
        Text('下一个')
          .fontSize(AppTheme.fsXs)
          .fontColor(AppTheme.textTertiary)
        Column() {
          this.previewPiece(this.nextType)
        }
        .width('100%')
        .padding(8)
        .backgroundColor(AppTheme.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: AppTheme.borderSubtle })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 分数
      Column({ space: 4 }) {
        Text('分数')
          .fontSize(AppTheme.fsXs)
          .fontColor(AppTheme.textTertiary)
        Text(this.score.toString())
          .fontSize(AppTheme.fsXl)
          .fontColor(AppTheme.primary)
          .fontWeight(FontWeight.Bold)
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .padding(10)
      .backgroundColor(AppTheme.bgSurface)
      .borderRadius(10)
      .border({ width: 1, color: AppTheme.borderSubtle })

      // 等级 & 行数
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text('等级')
            .fontSize(AppTheme.fsXs)
            .fontColor(AppTheme.textTertiary)
          Text(this.level.toString())
            .fontSize(AppTheme.fsMd)
            .fontColor(AppTheme.warning)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding(10)
        .backgroundColor(AppTheme.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: AppTheme.borderSubtle })

        Column({ space: 4 }) {
          Text('行数')
            .fontSize(AppTheme.fsXs)
            .fontColor(AppTheme.textTertiary)
          Text(this.lines.toString())
            .fontSize(AppTheme.fsMd)
            .fontColor(AppTheme.info)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding(10)
        .backgroundColor(AppTheme.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: AppTheme.borderSubtle })
      }
      .width('100%')
    }
    .width('100%')
  }

  // ---- 游戏结束遮罩 ----
  @Builder
  gameOverOverlay() {
    Stack() {
      Column({ space: 16 }) {
        Text('游戏结束')
          .fontSize(AppTheme.fs2xl)
          .fontColor(AppTheme.danger)
          .fontWeight(FontWeight.Bold)
        Text('最终得分: ' + this.score.toString())
          .fontSize(AppTheme.fsMd)
          .fontColor(AppTheme.textSecondary)
        Row()
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .backgroundColor(AppTheme.primary)
          .borderRadius(8)
          .onClick(() => { this.restartGame(); })
        Text('重新开始')
          .fontSize(AppTheme.fsMd)
          .fontColor('#0A0E1A')
          .fontWeight(FontWeight.Medium)
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
          .fontSize(AppTheme.fs2xl)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Bold)
        Row()
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .backgroundColor(AppTheme.primary)
          .borderRadius(8)
          .onClick(() => { this.togglePause(); })
        Text('继续')
          .fontSize(AppTheme.fsMd)
          .fontColor('#0A0E1A')
          .fontWeight(FontWeight.Medium)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(10, 14, 26, 0.7)')
    .alignContent(Alignment.Center)
  }

  // ---- 顶栏操作按钮 ----
  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      // 暂停/继续
      Row() {
        Text(this.isPaused ? '▶' : '⏸')
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(AppTheme.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.togglePause(); })

      // 重新开始
      Row() {
        Text('↺')
          .fontSize(16)
          .fontColor(AppTheme.textPrimary)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(AppTheme.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.restartGame(); })
    }
  }

  // ---- 生命周期 ----
  aboutToAppear(): void {
    const params: Record<string, string> | null = router.getParams() as Record<string, string> | null;
    if (params !== null && params['title'] !== undefined) {
      this.titleText = params['title'];
    }
    this.restartGame();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  build() {
    Column() {
      TopBar({
        title: this.titleText,
        subtitle: 'Level ' + this.level.toString(),
        showBack: true
      }) {
        this.actionsBuilder()
      }

      if (this.isSm) {
        // ---- 手机端：棋盘左 + (下一个+按钮+信息)右 ----
        Row({ space: 10 }) {
          // 左侧：棋盘
          Stack() {
            Column() {
              this.gameBoard()
            }
            .gesture(
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionEnd((event: GestureEvent) => {
                  if (this.isGameOver || this.isPaused) return;
                  const offsetX: number = event.offsetX;
                  const offsetY: number = event.offsetY;
                  if (Math.abs(offsetX) > Math.abs(offsetY)) {
                    if (offsetX > 0) this.moveRight();
                    else this.moveLeft();
                  } else {
                    if (offsetY < -20) this.rotatePiece();
                    else if (offsetY > 20) this.hardDrop();
                  }
                })
            )

            if (this.isGameOver) { this.gameOverOverlay() }
            if (this.isPaused) { this.pauseOverlay() }
          }
          .alignContent(Alignment.Center)

          // 右侧：信息+按钮
          Column({ space: 8 }) {
            // 下一个方块
            Column({ space: 2 }) {
              Text('下一个')
                .fontSize(AppTheme.fsXs)
                .fontColor(AppTheme.textTertiary)
              Column() {
                this.previewPiece(this.nextType)
              }
              .width('100%')
              .padding(6)
              .backgroundColor(AppTheme.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: AppTheme.borderSubtle })
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            // 分数
            Column({ space: 2 }) {
              Text('分数')
                .fontSize(AppTheme.fsXs)
                .fontColor(AppTheme.textTertiary)
              Text(this.score.toString())
                .fontSize(AppTheme.fsLg)
                .fontColor(AppTheme.primary)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(AppTheme.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: AppTheme.borderSubtle })

            // 等级
            Column({ space: 2 }) {
              Text('等级')
                .fontSize(AppTheme.fsXs)
                .fontColor(AppTheme.textTertiary)
              Text(this.level.toString())
                .fontSize(AppTheme.fsMd)
                .fontColor(AppTheme.warning)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(AppTheme.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: AppTheme.borderSubtle })

            // 行数
            Column({ space: 2 }) {
              Text('行数')
                .fontSize(AppTheme.fsXs)
                .fontColor(AppTheme.textTertiary)
              Text(this.lines.toString())
                .fontSize(AppTheme.fsMd)
                .fontColor(AppTheme.info)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(AppTheme.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: AppTheme.borderSubtle })

            // 控制按钮
            this.controlButtons()
          }
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      } else {
        // ---- 平板端布局：棋盘左 + 信息右 ----
        Row({ space: 20 }) {
          // 左侧：棋盘 + 按钮
          Column({ space: 12 }) {
            Stack() {
              Column() {
                this.gameBoard()
              }
              .gesture(
                PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                  .onActionEnd((event: GestureEvent) => {
                    if (this.isGameOver || this.isPaused) return;
                    const offsetX: number = event.offsetX;
                    const offsetY: number = event.offsetY;
                    if (Math.abs(offsetX) > Math.abs(offsetY)) {
                      if (offsetX > 0) this.moveRight();
                      else this.moveLeft();
                    } else {
                      if (offsetY < -20) this.rotatePiece();
                      else if (offsetY > 20) this.hardDrop();
                    }
                  })
              )

              if (this.isGameOver) { this.gameOverOverlay() }
              if (this.isPaused) { this.pauseOverlay() }
            }

            this.controlButtons()
          }
          .alignItems(HorizontalAlign.Center)

          // 右侧：信息面板
          Scroll() {
            this.infoPanel()
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
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

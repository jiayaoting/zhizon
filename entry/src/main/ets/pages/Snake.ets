// 智子 - 贪吃蛇
import { router } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DataRepository } from '../service/DataRepository';
import { DifficultyLevel, DIFFICULTY_DEFINITIONS, DifficultyDefinition, difficultyLabel } from '../common/Difficulty';
import { DifficultyOption } from '../components/DifficultyOption';

const COLS: number = 16;
const ROWS: number = 16;
const CELL_SIZE_SM: number = 20;
const CELL_SIZE_LG: number = 26;

interface Point {
  x: number;
  y: number;
}

enum Direction {
  UP,
  DOWN,
  LEFT,
  RIGHT
}

@Entry
@Component
export struct SnakePage {
  @State snake: Point[] = [];
  @State food: Point = { x: 0, y: 0 };
  @State snakeDirection: Direction = Direction.RIGHT;
  @State nextDirection: Direction = Direction.RIGHT;
  @State score: number = 0;
  @State bestScore: number = 0;
  @State level: number = 1;
  @State isGameOver: boolean = false;
  @State isPaused: boolean = false;
  @State isStarted: boolean = false;
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false; // 是否已选择难度开始
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  private timerId: number = -1;
  private titleText: string = '贪吃蛇';

  // ---- 下落速度（基于难度） ----
  private dropInterval(): number {
    let base: number = 200;
    if (this.difficulty === DifficultyLevel.VERY_EASY) base = 400;
    else if (this.difficulty === DifficultyLevel.EASY) base = 300;
    else if (this.difficulty === DifficultyLevel.HARD) base = 120;
    else if (this.difficulty === DifficultyLevel.HELL) base = 80;
    const min: number = 50;
    const interval: number = base - (this.level - 1) * 10;
    return Math.max(interval, min);
  }

  // ---- 初始化 ----
  private initGame(): void {
    const startX: number = Math.floor(COLS / 2);
    const startY: number = Math.floor(ROWS / 2);
    this.snake = [
      { x: startX, y: startY },
      { x: startX - 1, y: startY },
      { x: startX - 2, y: startY }
    ];
    this.snakeDirection = Direction.RIGHT;
    this.nextDirection = Direction.RIGHT;
    this.score = 0;
    this.level = 1;
    this.isGameOver = false;
    this.isPaused = false;
    this.generateFood();
  }

  private generateFood(): void {
    const available: Point[] = [];
    for (let r: number = 0; r < ROWS; r++) {
      for (let c: number = 0; c < COLS; c++) {
        let occupied: boolean = false;
        for (let i: number = 0; i < this.snake.length; i++) {
          if (this.snake[i].x === c && this.snake[i].y === r) {
            occupied = true;
            break;
          }
        }
        if (!occupied) available.push({ x: c, y: r });
      }
    }
    if (available.length === 0) {
      // 无可用位置 = 胜利
      this.isGameOver = true;
      this.saveScore();
      return;
    }
    const idx: number = Math.floor(Math.random() * available.length);
    this.food = available[idx];
  }

  // ---- 移动逻辑 ----
  private moveSnake(): void {
    if (this.isGameOver || this.isPaused || !this.isStarted) return;

    this.snakeDirection = this.nextDirection;
    const head: Point = this.snake[0];
    let newHead: Point = { x: head.x, y: head.y };

    switch (this.snakeDirection) {
      case Direction.UP:    newHead.y -= 1; break;
      case Direction.DOWN:  newHead.y += 1; break;
      case Direction.LEFT:  newHead.x -= 1; break;
      case Direction.RIGHT: newHead.x += 1; break;
    }

    // 碰墙检测
    if (newHead.x < 0 || newHead.x >= COLS || newHead.y < 0 || newHead.y >= ROWS) {
      this.isGameOver = true;
      this.stopTimer();
      this.saveScore();
      return;
    }

    // 碰自身检测（不含尾部，因为尾部会移除）
    for (let i: number = 0; i < this.snake.length - 1; i++) {
      if (this.snake[i].x === newHead.x && this.snake[i].y === newHead.y) {
        this.isGameOver = true;
        this.stopTimer();
        this.saveScore();
        return;
      }
    }

    // 添加新头部
    const newSnake: Point[] = [{ x: newHead.x, y: newHead.y }];
    for (let i: number = 0; i < this.snake.length; i++) {
      newSnake.push({ x: this.snake[i].x, y: this.snake[i].y });
    }

    // 检查是否吃到食物
    if (newHead.x === this.food.x && newHead.y === this.food.y) {
      this.score += 10;
      this.level = Math.floor(this.score / 100) + 1;
      // 保持尾部，蛇变长
      this.snake = newSnake;
      this.generateFood();
      // 调整速度
      this.restartTimer();
    } else {
      // 移除尾部
      newSnake.pop();
      this.snake = newSnake;
    }
  }

  // ---- 方向变更（防止反向） ----
  private changeDirection(dir: Direction): void {
    if (this.isGameOver || this.isPaused) return;
    if (!this.isStarted) {
      this.isStarted = true;
      this.startTimer();
    }

    // 不能反向
    if (this.snakeDirection === Direction.UP && dir === Direction.DOWN) return;
    if (this.snakeDirection === Direction.DOWN && dir === Direction.UP) return;
    if (this.snakeDirection === Direction.LEFT && dir === Direction.RIGHT) return;
    if (this.snakeDirection === Direction.RIGHT && dir === Direction.LEFT) return;

    this.nextDirection = dir;
  }

  // ---- 定时器 ----
  private startTimer(): void {
    this.stopTimer();
    const interval: number = this.dropInterval();
    this.timerId = setInterval(() => { this.moveSnake(); }, interval);
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
  private startWithDifficulty(level: DifficultyLevel): void {
    this.difficulty = level;
    this.gameStarted = true;
    this.initGame();
    this.isStarted = true;
    this.startTimer();
  }

  restartGame(): void {
    this.stopTimer();
    this.initGame();
    this.isStarted = true;
    this.startTimer();
  }

  private saveScore(): void {
    DataRepository.addGameScore('Snake', this.score, this.level, difficultyLabel(this.difficulty));
  }

  togglePause(): void {
    if (this.isGameOver || !this.isStarted) return;
    this.isPaused = !this.isPaused;
  }

  // ---- 棋盘渲染 ----
  @Builder
  gameBoard() {
    Column() {
      ForEach(this.getDisplayGrid(), (row: number[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: number, colIdx: number) => {
            Row()
              .width(this.isSm ? CELL_SIZE_SM : CELL_SIZE_LG)
              .height(this.isSm ? CELL_SIZE_SM : CELL_SIZE_LG)
              .margin(0.5)
              .borderRadius(2)
              .backgroundColor(this.cellColor(cell, colIdx, rowIdx))
          }, (colIdx: number) => colIdx.toString())
        }
      }, (rowIdx: number) => rowIdx.toString())
    }
    .border({ width: 2, color: this.palette.borderDefault })
    .borderRadius(6)
    .padding(2)
    .backgroundColor(this.palette.bgSurface)
  }

  private cellColor(cell: number, x: number, y: number): string {
    if (cell === 1) {
      // 蛇头
      return this.palette.primary;
    }
    if (cell === 2) {
      // 蛇身 - 渐变效果
      return this.palette.primaryDim;
    }
    if (cell === 3) {
      // 食物
      return this.palette.danger;
    }
    return this.palette.bgSurface2;
  }

  private getDisplayGrid(): number[][] {
    const grid: number[][] = [];
    for (let r: number = 0; r < ROWS; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < COLS; c++) {
        row.push(0);
      }
      grid.push(row);
    }

    // 食物
    if (this.food) {
      grid[this.food.y][this.food.x] = 3;
    }

    // 蛇身
    for (let i: number = 0; i < this.snake.length; i++) {
      const s: Point = this.snake[i];
      if (s.y >= 0 && s.y < ROWS && s.x >= 0 && s.x < COLS) {
        grid[s.y][s.x] = i === 0 ? 1 : 2;
      }
    }

    return grid;
  }

  // ---- 方向按钮 ----
  @Builder
  directionPad() {
    Column({ space: 8 }) {
      // 上
      Row() {
        Text('▲')
          .fontSize(20)
          .fontColor(this.palette.textPrimary)
      }
      .width(this.isSm ? 48 : 56)
      .height(this.isSm ? 48 : 56)
      .borderRadius(12)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .border({ width: 1, color: this.palette.borderSubtle })
      .onClick(() => { this.changeDirection(Direction.UP); })

      // 左右下
      Row({ space: 8 }) {
        Row() {
          Text('◀')
            .fontSize(20)
            .fontColor(this.palette.textPrimary)
        }
        .width(this.isSm ? 48 : 56)
        .height(this.isSm ? 48 : 56)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => { this.changeDirection(Direction.LEFT); })

        Row() {
          Text('▼')
            .fontSize(20)
            .fontColor(this.palette.textPrimary)
        }
        .width(this.isSm ? 48 : 56)
        .height(this.isSm ? 48 : 56)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => { this.changeDirection(Direction.DOWN); })

        Row() {
          Text('▶')
            .fontSize(20)
            .fontColor(this.palette.textPrimary)
        }
        .width(this.isSm ? 48 : 56)
        .height(this.isSm ? 48 : 56)
        .borderRadius(12)
        .backgroundColor(this.palette.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => { this.changeDirection(Direction.RIGHT); })
      }
      .justifyContent(FlexAlign.Center)
    }
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 信息面板 ----
  @Builder
  infoPanel() {
    Row({ space: 8 }) {
      // 分数
      Column({ space: 2 }) {
        Text('分数')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
        Text(this.score.toString())
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })

      // 等级
      Column({ space: 2 }) {
        Text('等级')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
        Text(this.level.toString())
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

      // 最佳
      Column({ space: 2 }) {
        Text('最佳')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
        Text(this.bestScore.toString())
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
    }
    .width('100%')
  }

  // ---- 游戏结束弹窗 ----
  @Builder
  gameOverOverlay() {
    Stack() {
      Column({ space: 16 }) {
        Text('游戏结束')
          .fontSize(this.palette.fs2xl)
          .fontColor(this.palette.danger)
          .fontWeight(FontWeight.Bold)
        Text('最终得分: ' + this.score.toString())
          .fontSize(this.palette.fsMd)
          .fontColor(this.palette.textSecondary)
        Text('蛇身长度: ' + this.snake.length.toString())
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textTertiary)
        Row()
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .backgroundColor(this.palette.primary)
          .borderRadius(8)
          .onClick(() => { this.restartGame(); })
        Text('重新开始')
          .fontSize(this.palette.fsMd)
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

  // ---- 暂停弹窗 ----
  @Builder
  pauseOverlay() {
    Stack() {
      Column({ space: 12 }) {
        Text('已暂停')
          .fontSize(this.palette.fs2xl)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Row()
          .padding({ left: 24, right: 24, top: 10, bottom: 10 })
          .backgroundColor(this.palette.primary)
          .borderRadius(8)
          .onClick(() => { this.togglePause(); })
        Text('继续')
          .fontSize(this.palette.fsMd)
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

  // ---- 难度选择 ----
  @Builder
  difficultyPicker() {
    Column({ space: 16 }) {
      Text('选择难度')
        .fontSize(this.palette.fsXl)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      ForEach(DIFFICULTY_DEFINITIONS, (definition: DifficultyDefinition) => {
        DifficultyOption({
          definition: definition,
          selected: this.difficulty === definition.level,
          onSelect: (level: DifficultyLevel): void => { this.startWithDifficulty(level); }
        })
      }, (definition: DifficultyDefinition) => definition.level)
    }
    .width('100%')
    .padding(20)
  }

  // ---- 操作栏 ----
  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      // 战绩
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
        router.pushUrl({ url: 'pages/GameHistory', params: { 'game': 'Snake' } as Record<string, string> });
      })

      // 暂停
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

      // 重新开始
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

  // ---- 生命周期 ----
  aboutToAppear(): void {
    const params: Record<string, string> | null = router.getParams() as Record<string, string> | null;
    if (params !== null && params['title'] !== undefined) {
      this.titleText = params['title'];
    }
    this.initGame();
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
        // 手机端布局：棋盘 + 按钮 + 信息
        if (!this.gameStarted) {
          Column() {
            this.difficultyPicker()
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16 })
        } else {
          Column() {
            Stack() {
              Column() {
                this.gameBoard()
              }
              .gesture(
                PanGesture({ fingers: 1, direction: PanDirection.All, distance: 10 })
                  .onActionEnd((event: GestureEvent) => {
                    if (this.isGameOver || this.isPaused) return;
                    const ox: number = event.offsetX;
                    const oy: number = event.offsetY;
                    const absX: number = Math.abs(ox);
                    const absY: number = Math.abs(oy);
                    if (absX > absY) {
                      if (ox > 0) this.changeDirection(Direction.RIGHT);
                      else this.changeDirection(Direction.LEFT);
                    } else {
                      if (oy > 0) this.changeDirection(Direction.DOWN);
                      else this.changeDirection(Direction.UP);
                    }
                  })
              )

              if (this.isGameOver) { this.gameOverOverlay() }
              if (this.isPaused) { this.pauseOverlay() }
            }
            .width('100%')
            .alignContent(Alignment.Center)

            Column({ space: 8 }) {
              this.directionPad()
              this.infoPanel()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 8, right: 8 })
          .justifyContent(FlexAlign.Center)
        }
      } else {
        // 平板端布局
        if (!this.gameStarted) {
          Column() {
            this.difficultyPicker()
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Row({ space: 20 }) {
            Column({ space: 12 }) {
              Stack() {
                Column() {
                  this.gameBoard()
                }
                .gesture(
                  PanGesture({ fingers: 1, direction: PanDirection.All, distance: 10 })
                    .onActionEnd((event: GestureEvent) => {
                      if (this.isGameOver || this.isPaused) return;
                      const ox: number = event.offsetX;
                      const oy: number = event.offsetY;
                      const absX: number = Math.abs(ox);
                      const absY: number = Math.abs(oy);
                      if (absX > absY) {
                        if (ox > 0) this.changeDirection(Direction.RIGHT);
                        else this.changeDirection(Direction.LEFT);
                      } else {
                        if (oy > 0) this.changeDirection(Direction.DOWN);
                        else this.changeDirection(Direction.UP);
                      }
                    })
                )

                if (this.isGameOver) { this.gameOverOverlay() }
                if (this.isPaused) { this.pauseOverlay() }
              }

              this.directionPad()
            }
            .alignItems(HorizontalAlign.Center)

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
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

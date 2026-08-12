// 智子 - 弹球打砖块
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
class BreakoutConfig {
  rows: number;
  speed: number;
  constructor(rows: number, speed: number) {
    this.rows = rows;
    this.speed = speed;
  }
}

function breakoutConfig(level: DifficultyLevel): BreakoutConfig {
  if (level === DifficultyLevel.VERY_EASY) return new BreakoutConfig(5, 300);
  if (level === DifficultyLevel.EASY) return new BreakoutConfig(7, 380);
  if (level === DifficultyLevel.MEDIUM) return new BreakoutConfig(9, 460);
  if (level === DifficultyLevel.HARD) return new BreakoutConfig(11, 540);
  return new BreakoutConfig(13, 640);
}

// 砖块
@Observed
class Brick {
  alive: boolean = true;
  value: number = 10;
}

const COLS: number = 8;
const PADDLE_W: number = 80;
const PADDLE_H: number = 12;
const BALL_R: number = 6;
const PADDLE_BOTTOM: number = 20;
const BRICK_TOP: number = 56;
const BRICK_H: number = 16;
const BRICK_GAP: number = 3;
const START_LIVES: number = 3;

@Entry
@Component
export struct BreakoutPage {
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false;
  @State isGameOver: boolean = false;
  @State isWin: boolean = false;
  @State isPaused: boolean = false;
  @State autoPaused: boolean = false;
  @State paddleX: number = 200;
  @State ballX: number = 200;
  @State ballY: number = 300;
  @State ballVx: number = 0;
  @State ballVy: number = 0;
  @State playing: boolean = false;
  @State bricks: Brick[][] = [];
  @State score: number = 0;
  @State bestScore: number = 0;
  @State lives: number = START_LIVES;
  @State newRecord: boolean = false;
  @State playSeconds: number = 0;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  private timerId: number = -1;
  private titleText: string = '打砖块';
  private playW: number = 360;
  private playH: number = 480;
  private areaReady: boolean = false;
  private brickRows: number = 9;
  private ballSpeed: number = 460;
  private keyLeft: boolean = false;
  private keyRight: boolean = false;
  private lastPanX: number = 0;
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
      if (!this.isPaused && !this.isGameOver && !this.isWin) {
        this.playSeconds += 1;
      }
      this.tick();
    }, 30);
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // ---- 游戏循环 ----
  private tick(): void {
    if (this.isPaused || this.isGameOver || this.isWin) return;
    // 挡板移动
    if (this.keyLeft) this.movePaddle(-16);
    if (this.keyRight) this.movePaddle(16);
    if (!this.playing) {
      this.ballX = this.paddleX;
      this.ballY = this.playH - PADDLE_BOTTOM - PADDLE_H - BALL_R - 1;
      return;
    }
    // 球移动
    this.ballX += this.ballVx;
    this.ballY += this.ballVy;
    // 左右壁
    if (this.ballX < BALL_R) {
      this.ballX = BALL_R;
      this.ballVx = Math.abs(this.ballVx);
    }
    if (this.ballX > this.playW - BALL_R) {
      this.ballX = this.playW - BALL_R;
      this.ballVx = -Math.abs(this.ballVx);
    }
    // 顶壁
    if (this.ballY < BALL_R) {
      this.ballY = BALL_R;
      this.ballVy = Math.abs(this.ballVy);
    }
    // 挡板碰撞
    const paddleY: number = this.playH - PADDLE_BOTTOM - PADDLE_H;
    if (this.ballVy > 0 && this.ballY + BALL_R >= paddleY && this.ballY + BALL_R <= paddleY + PADDLE_H + 8 &&
      this.ballX >= this.paddleX - PADDLE_W / 2 - BALL_R && this.ballX <= this.paddleX + PADDLE_W / 2 + BALL_R) {
      const hit: number = (this.ballX - this.paddleX) / (PADDLE_W / 2);
      this.ballVx = Math.max(-6, Math.min(6, hit * 5.5));
      this.ballVy = -Math.abs(this.ballVy);
      this.ballY = paddleY - BALL_R;
      this.vibrate(5);
    }
    // 砖块碰撞
    this.hitBricks();
    // 漏球
    if (this.ballY > this.playH + 20) {
      this.lives -= 1;
      this.vibrate(60);
      if (this.lives <= 0) {
        this.isGameOver = true;
        this.stopTimer();
        this.score = 0;
        return;
      }
      this.playing = false;
      this.ballVx = 0;
      this.ballVy = 0;
    }
  }

  private hitBricks(): void {
    const brickW: number = (this.playW - 16) / COLS;
    for (let r: number = 0; r < this.brickRows; r++) {
      for (let c: number = 0; c < COLS; c++) {
        const brick: Brick = this.bricks[r][c];
        if (!brick.alive) continue;
        const bx: number = 8 + c * brickW;
        const by: number = BRICK_TOP + r * (BRICK_H + BRICK_GAP);
        if (this.ballX + BALL_R >= bx && this.ballX - BALL_R <= bx + brickW &&
          this.ballY + BALL_R >= by && this.ballY - BALL_R <= by + BRICK_H) {
          brick.alive = false;
          this.score += brick.value;
          this.ballVy = -this.ballVy;
          this.vibrate(8);
          this.checkWin();
          return;
        }
      }
    }
  }

  private checkWin(): void {
    for (let r: number = 0; r < this.brickRows; r++) {
      for (let c: number = 0; c < COLS; c++) {
        if (this.bricks[r][c].alive) return;
      }
    }
    this.isWin = true;
    this.stopTimer();
    this.vibrate(30);
    this.score += this.lives * 100;
    this.newRecord = this.score > this.bestScore;
    if (this.newRecord) this.bestScore = this.score;
    this.saveScore();
  }

  private saveScore(): void {
    if (this.scoreSaved) return;
    this.scoreSaved = true;
    DataRepository.addGameScore('Breakout', this.score, 1, difficultyLabel(this.difficulty));
  }

  // ---- 挡板 ----
  private movePaddle(dx: number): void {
    this.paddleX = Math.max(PADDLE_W / 2, Math.min(this.playW - PADDLE_W / 2, this.paddleX + dx));
  }

  private launchBall(): void {
    if (!this.playing) {
      this.playing = true;
      this.ballVy = -this.ballSpeed;
      this.ballVx = (Math.random() * 2 - 1) * 1.5;
    }
  }

  // ---- 游戏控制 ----
  private initBricks(): void {
    const grid: Brick[][] = [];
    for (let r: number = 0; r < this.brickRows; r++) {
      const row: Brick[] = [];
      const value: number = 50 - r * 4;
      for (let c: number = 0; c < COLS; c++) {
        const brick: Brick = new Brick();
        brick.value = Math.max(10, value);
        row.push(brick);
      }
      grid.push(row);
    }
    this.bricks = grid;
  }

  private resetPositions(): void {
    this.paddleX = this.playW / 2;
    this.ballX = this.paddleX;
    this.ballY = this.playH - PADDLE_BOTTOM - PADDLE_H - BALL_R - 1;
    this.ballVx = 0;
    this.ballVy = 0;
    this.playing = false;
  }

  private startWithDifficulty(level: DifficultyLevel): void {
    this.difficulty = level;
    const config: BreakoutConfig = breakoutConfig(level);
    this.brickRows = config.rows;
    this.ballSpeed = config.speed;
    this.gameStarted = true;
    this.isGameOver = false;
    this.isWin = false;
    this.isPaused = false;
    this.autoPaused = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.lives = START_LIVES;
    this.score = 0;
    this.gameStartTime = Date.now();
    this.initBricks();
    this.resetPositions();
    if (this.areaReady) {
      this.startTimer();
    }
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
    this.lives = START_LIVES;
    this.score = 0;
    this.gameStartTime = Date.now();
    this.initBricks();
    this.resetPositions();
    this.startTimer();
  }

  togglePause(): void {
    if (this.isGameOver || this.isWin) return;
    this.isPaused = !this.isPaused;
    this.autoPaused = false;
    if (!this.isPaused) {
      this.startTimer();
    }
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
      this.startTimer();
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
    const best: number = await DataRepository.getGameHighScore('Breakout');
    this.bestScore = best;
  }

  // ---- 键盘 ----
  private onKeyDown(code: KeyCode): void {
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
      this.keyLeft = true;
    } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
      this.keyRight = true;
    } else if (code === KeyCode.KEYCODE_SPACE) {
      this.launchBall();
    }
  }

  private onKeyUp(code: KeyCode): void {
    if (code === KeyCode.KEYCODE_DPAD_LEFT || code === KeyCode.KEYCODE_A) {
      this.keyLeft = false;
    } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
      this.keyRight = false;
    }
  }

  // ---- 砖块渲染 ----
  private brickColor(row: number): string {
    const colors: string[] = [this.palette.danger, this.palette.warning, this.palette.info,
      this.palette.success, this.palette.purple];
    return colors[row % colors.length];
  }

  @Builder
  gameArea() {
    Stack() {
      // 砖块
      ForEach(this.bricks, (row: Brick[], rowIdx: number) => {
        ForEach(row, (brick: Brick, colIdx: number) => {
          if (brick.alive) {
            Row()
              .width((this.playW - 16) / COLS - 2)
              .height(BRICK_H)
              .borderRadius(3)
              .backgroundColor(this.brickColor(rowIdx))
              .position({ x: 8 + colIdx * ((this.playW - 16) / COLS) + 1, y: BRICK_TOP + rowIdx * (BRICK_H + BRICK_GAP) })
          }
        }, (brick: Brick, colIdx: number) => colIdx.toString())
      }, (row: Brick[], rowIdx: number) => rowIdx.toString())

      // 球
      Row()
        .width(BALL_R * 2)
        .height(BALL_R * 2)
        .borderRadius(BALL_R)
        .backgroundColor(this.palette.primary)
        .position({ x: this.ballX - BALL_R, y: this.ballY - BALL_R })

      // 挡板
      Row()
        .width(PADDLE_W)
        .height(PADDLE_H)
        .borderRadius(PADDLE_H / 2)
        .backgroundColor(this.palette.textPrimary)
        .position({ x: this.paddleX - PADDLE_W / 2, y: this.playH - PADDLE_BOTTOM - PADDLE_H })

      // 待发球提示
      if (!this.playing && !this.isGameOver && !this.isWin) {
        Text('点击或按空格发球')
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
          .position({ x: '50%', y: '62%' })
          .translate({ x: '-50%' })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 2, color: this.palette.borderDefault })
    .borderRadius(6)
    .clip(true)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal })
        .onActionStart(() => { this.lastPanX = 0; })
        .onActionUpdate((event: GestureEvent) => {
          if (!this.isGameOver && !this.isPaused && !this.isWin) {
            const dx: number = event.offsetX - this.lastPanX;
            this.lastPanX = event.offsetX;
            this.movePaddle(dx);
          }
        })
    )
    .onClick(() => { this.launchBall(); })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w: number = Number(newValue.width);
      const h: number = Number(newValue.height);
      if (w > 0 && h > 0) {
        this.playW = w;
        this.playH = h;
        if (!this.areaReady) {
          this.areaReady = true;
          this.resetPositions();
          if (this.gameStarted) {
            this.startTimer();
          }
        }
      }
    })
  }

  // ---- 信息面板 ----
  @Builder
  infoPanel() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('分数')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
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

      Column({ space: 2 }) {
        Text('生命')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text('❤️'.repeat(Math.max(0, this.lives)) + '💔'.repeat(Math.max(0, START_LIVES - this.lives)))
          .fontSize(10)
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
         router.pushUrl({ url: 'pages/GameHistory', params: new GameHistoryRouteParams('Breakout') });
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
        Text(this.isWin ? '🎉 胜利！' : '游戏结束')
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
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.BREAKOUT);
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
                this.gameArea()
                if (this.isGameOver || this.isWin) { this.gameOverOverlay() }
                if (this.isPaused) { this.pauseOverlay() }
              }
              .width('100%')
              .layoutWeight(1)
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
                  this.gameArea()
                  if (this.isGameOver || this.isWin) { this.gameOverOverlay() }
                  if (this.isPaused) { this.pauseOverlay() }
                }
                .width('100%')
                .aspectRatio(3 / 4)
                .alignContent(Alignment.Center)
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
                      Text('拖拽或左右键：移动挡板')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
                        .fontFamily(this.palette.fontSans)
                      Text('点击/空格：发球')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
                        .fontFamily(this.palette.fontSans)
                      Text('打光所有砖块即可获胜')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.primary)
                        .fontFamily(this.palette.fontSans)
                      Text('漏球扣 1 条命，共 3 条')
                        .fontSize(this.palette.fsSm)
                        .fontColor(this.palette.textSecondary)
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
      .padding({ bottom: Math.max(0, this.navBarHeight) })
      .focusable(true)
      .defaultFocus(true)
      .onKeyEvent((event: KeyEvent) => {
        if (event.type === KeyType.Down) {
          this.onKeyDown(event.keyCode);
        } else if (event.type === KeyType.Up) {
          this.onKeyUp(event.keyCode);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

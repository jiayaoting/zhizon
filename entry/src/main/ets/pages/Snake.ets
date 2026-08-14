// 智子 - 贪吃蛇
import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DataRepository } from '../service/DataRepository';
import { DifficultyLevel, difficultyLabel, GameId, GameLaunchFacade, GameLaunchResult,
  GameRouteParams } from '../common/Difficulty';
import { GameHistoryRouteParams } from '../common/Navigation';
import { DeviceMetrics } from '../common/DeviceMetrics';
import { GameAIPanel } from '../components/GameAIPanel';
import { GameAIService, GameAction, AI_SPEED_DELAYS, SnakePoint } from '../service/GameAIService';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { ScreenKeepAlive } from '../common/ScreenKeepAlive';

const COLS: number = 16;
const ROWS: number = 16;

interface Point extends SnakePoint {
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
  @State autoPaused: boolean = false;
  @State floatScore: string = '';
  @State showFloatScore: boolean = false;
  @State showHelp: boolean = false;
  @State newRecord: boolean = false;
  @State playSeconds: number = 0;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  // ---- AI 托管 ----
  @State aiRunning: boolean = false;
  @State aiStatus: string = '';
  @State aiModelNames: string[] = [];
  @State aiModelIndex: number = 0;
  @State aiSpeedIndex: number = 2;
  @State aiModelsConfigured: boolean = true;
  private aiModels: LlmModelEntry[] = [];
  private aiConfig: LlmConfig | null = null;
  private aiLoopActive: boolean = false;
  @State aiFailCount: number = 0;
  @State aiThinkCount: number = 0;
  @State aiThinkTimeMs: number = 0;
  private aiThinkTimer: number = -1;
  private aiThinkStart: number = 0;
  private aiHosted: boolean = false;
  private aiSelectSeq: number = 0;

  private timerId: number = -1;
  private titleText: string = '贪吃蛇';
  private gameStartTime: number = 0;
  private scoreSaved: boolean = false;
  private lastLevel: number = 1;

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

  // 自适应棋盘格子尺寸
  private boardCellSize(): number {
    if (this.isSm) {
      // 手机端：TopBar + 方向键(3行) + 信息栏 + 间距 + 安全区
      return DeviceMetrics.fitCellSize(COLS, ROWS, 370, 12, 24);
    }
    // 平板端：TopBar + 方向键(更大按钮) + 安全区
    return DeviceMetrics.fitCellSize(COLS, ROWS, 330, 14, 30);
  }

  private boardSide(): number {
    return COLS * this.boardCellSize();
  }

  private showScoreFloat(text: string): void {
    this.floatScore = text;
    this.showFloatScore = false;
    setTimeout(() => {
      this.showFloatScore = true;
    }, 10);
    setTimeout(() => {
      this.showFloatScore = false;
    }, 900);
  }

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
      this.stopTimer();
      this.vibrate(80);
      this.finishGame();
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
      this.vibrate(80);
      this.finishGame();
      return;
    }

    // 碰自身检测（不含尾部，因为尾部会移除）
    for (let i: number = 0; i < this.snake.length - 1; i++) {
      if (this.snake[i].x === newHead.x && this.snake[i].y === newHead.y) {
        this.isGameOver = true;
        this.stopTimer();
        this.vibrate(80);
        this.finishGame();
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
      // 触觉反馈 + 飘字
      this.vibrate(15);
      this.showScoreFloat('+10');
      // 等级提升提示
      if (this.level > this.lastLevel) {
        promptAction.showToast({ message: `等级提升 → Level ${this.level}` });
        this.lastLevel = this.level;
      }
    } else {
      // 移除尾部
      newSnake.pop();
      this.snake = newSnake;
    }
  }

  // ---- 游戏结束收尾（新纪录/用时/保存） ----
  private finishGame(): void {
    this.newRecord = this.score > this.bestScore;
    if (this.newRecord) this.bestScore = this.score;
    this.playSeconds = Math.max(0, Math.floor((Date.now() - this.gameStartTime) / 1000));
    this.saveScore();
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
    this.scoreSaved = false;
    this.lastLevel = 1;
    this.newRecord = false;
    this.playSeconds = 0;
    this.gameStartTime = Date.now();
    this.startTimer();
  }

  restartGame(): void {
    this.stopAi();
    this.aiHosted = false;
    this.stopTimer();
    this.initGame();
    this.isStarted = true;
    this.scoreSaved = false;
    this.lastLevel = 1;
    this.newRecord = false;
    this.playSeconds = 0;
    this.gameStartTime = Date.now();
    this.startTimer();
  }

  private saveScore(): void {
    if (this.scoreSaved) return;
    this.scoreSaved = true;
    DataRepository.addGameScore('Snake', this.score, this.level, difficultyLabel(this.difficulty),
      this.currentAiModelName());
  }

  togglePause(): void {
    if (this.isGameOver || !this.isStarted) return;
    if (this.aiRunning) {
      this.isPaused = true;
      this.stopAi();
      this.autoPaused = false;
      return;
    }
    this.isPaused = !this.isPaused;
    this.autoPaused = false;
    if (this.isPaused) {
      this.stopTimer();
    } else {
      this.startTimer();
    }
  }

  // ---- 页面隐藏时自动暂停 ----
  onPageHide(): void {
    this.stopAi();
    if (!this.isPaused && !this.isGameOver && this.isStarted) {
      this.autoPaused = true;
      this.isPaused = true;
      this.stopTimer();
    }
  }

  // ---- 页面显示时恢复（仅自动暂停） ----
  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.isPaused = false;
      this.startTimer();
      promptAction.showToast({ message: '已恢复游戏' });
    }
  }

  // ---- 切换难度（暂停弹层内） ----
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
    if (!this.isPaused && !this.isGameOver) {
      this.restartTimer();
    }
    promptAction.showToast({ message: `难度：${difficultyLabel(this.difficulty)}` });
  }

  private async loadBestScore(): Promise<void> {
    const best: number = await DataRepository.getGameHighScore('Snake');
    this.bestScore = best;
  }

  // ---- AI 托管（AI 决策期间冻结移动计时器，避免蛇在 AI 思考时撞墙） ----
  private async initAiPanel(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    // 恢复本游戏记忆的模型；无记忆时保持默认（激活模型）
    const savedId: string = await GameAIService.loadSavedModelId('Snake');
    if (savedId.length > 0) {
      for (let i: number = 0; i < this.aiModels.length; i++) {
        if (this.aiModels[i].id === savedId) { this.aiModelIndex = i; break; }
      }
    }
    const names: string[] = [];
    for (let i: number = 0; i < this.aiModels.length; i++) {
      names.push(GameAIService.modelLabel(this.aiModels[i]));
    }
    this.aiModelNames = names;
    this.aiModelsConfigured = this.aiModels.length > 0;
    if (this.aiModelsConfigured) {
      this.aiConfig = await GameAIService.loadConfig(this.aiModels[this.aiModelIndex].id);
    } else {
      this.aiConfig = null;
    }
  }

  private async toggleAi(): Promise<void> {
    if (this.aiRunning) {
      this.stopAi();
      return;
    }
    if (!this.aiModelsConfigured) {
      promptAction.showToast({ message: '请先在 AI 对话中配置可用模型' });
      return;
    }
    if (this.aiConfig === null) {
      promptAction.showToast({ message: '模型配置无效，请检查 AI 设置' });
      return;
    }
    if (!this.gameStarted) return;
    if (this.isGameOver) {
      this.restartGame();
    }
    this.isPaused = false;
    this.isStarted = true;
    this.aiHosted = true;
    this.aiFailCount = 0;
    this.aiRunning = true;
    this.aiStatus = 'AI 准备中…';
    this.stopTimer();
    this.aiLoop().catch((e: Object) => {
      this.stopAi();
    });
  }

  private stopAi(): void {
    this.aiRunning = false;
    this.aiLoopActive = false;
    this.stopThinkTimer();
    this.aiStatus = '';
    if (this.gameStarted && !this.isGameOver && !this.isPaused) {
      this.startTimer();
    }
  }

  // 本轮思考计时：每次思考开始刷新起始点并启动 100ms 定时器实时更新耗时
  private startThinkTimer(): void {
    this.aiThinkStart = Date.now();
    this.aiThinkTimeMs = 0;
    this.stopThinkTimer();
    this.aiThinkTimer = setInterval(() => {
      this.aiThinkTimeMs = Date.now() - this.aiThinkStart;
    }, 100);
  }

  private stopThinkTimer(): void {
    if (this.aiThinkTimer >= 0) {
      clearInterval(this.aiThinkTimer);
      this.aiThinkTimer = -1;
    }
  }

  // AI 托管时使用的模型显示名（取配置中的显示名称）；手动游玩返回空串
  private currentAiModelName(): string {
    if (!this.aiHosted || this.aiModelIndex < 0 || this.aiModelIndex >= this.aiModels.length) return '';
    return GameAIService.modelLabel(this.aiModels[this.aiModelIndex]);
  }

  private selectAiModel(index: number): void {
    this.aiModelIndex = index;
    this.aiSelectSeq += 1;
    const seq: number = this.aiSelectSeq;
    if (this.aiModels.length > index) {
      GameAIService.loadConfig(this.aiModels[index].id).then((config: LlmConfig | null) => {
        if (seq !== this.aiSelectSeq) return;
        this.aiConfig = config;
        this.aiFailCount = 0;
      });
      GameAIService.saveModelId('Snake', this.aiModels[index].id);
    }
  }

  private changeAiSpeed(index: number): void {
    if (this.aiRunning) return;
    this.aiSpeedIndex = index;
  }

  // AI 决策循环：冻结移动，每轮 决策 → 转向 → 展示窗口 → 手动走一步
  private async aiLoop(): Promise<void> {
    if (!this.aiRunning || this.aiLoopActive) return;
    this.aiLoopActive = true;
    while (this.aiRunning) {
      if (this.isGameOver || this.isPaused) break;
      if (this.aiConfig === null) break;
      this.aiThinkCount += 1;
      this.aiStatus = 'AI 思考中…';
      this.startThinkTimer();
      const stateText: string = GameAIService.serializeSnake(this.snake, this.food, COLS, ROWS);
      const messages = GameAIService.buildMessages('Snake', this.difficulty, stateText);
      const result = await GameAIService.decide(this.aiConfig, messages, 'Snake');
      this.stopThinkTimer();
      if (!this.aiRunning) break;
      if (!result.success) {
        this.aiFailCount += 1;
        if (this.aiFailCount >= 3) {
          this.aiStatus = 'AI 模型不稳定，已退出';
          this.stopAi();
          promptAction.showToast({ message: 'AI 连续失败，已停止托管' });
          break;
        }
        continue;
      }
      this.aiFailCount = 0;
      // 贪吃蛇：一次请求返回一串方向，连续走多步，减少 LLM 调用次数
      const actions: GameAction[] = GameAIService.parseActionSequence('Snake', result.content);
      if (actions.length === 0) continue;
      this.aiStatus = 'AI 执行 ' + actions.length.toString() + ' 步';
      for (let i: number = 0; i < actions.length; i++) {
        if (!this.aiRunning || this.isGameOver || this.isPaused) break;
        const foodBefore: Point = this.food;
        const action: GameAction = actions[i];
        if (action.command === 'UP') this.changeDirection(Direction.UP);
        else if (action.command === 'DOWN') this.changeDirection(Direction.DOWN);
        else if (action.command === 'LEFT') this.changeDirection(Direction.LEFT);
        else if (action.command === 'RIGHT') this.changeDirection(Direction.RIGHT);
        this.moveSnake();
        if (this.isGameOver || this.isPaused) break;
        // 吃到食物（食物位置变化）：本序列结束，重新规划
        if (this.food.x !== foodBefore.x || this.food.y !== foodBefore.y) break;
      }
      if (this.isGameOver || this.isPaused) break;
      if (this.aiSpeedIndex < AI_SPEED_DELAYS.length && AI_SPEED_DELAYS[this.aiSpeedIndex] > 0) {
        await new Promise<void>((resolve) => {
          setTimeout(() => { resolve(); }, AI_SPEED_DELAYS[this.aiSpeedIndex]);
        });
      }
      if (this.isGameOver || this.isPaused) break;
      // 展示窗口结束后手动走一步，保持游戏节奏
      this.moveSnake();
      if (this.isGameOver) break;
    }
    this.aiLoopActive = false;
    this.stopThinkTimer();
    if (this.aiRunning) {
      this.aiRunning = false;
      this.aiStatus = this.isGameOver ? 'AI 结束：游戏已终局' : 'AI 已暂停';
    }
  }

  // ---- 棋盘渲染 ----
  @Builder
  gameBoard() {
    Column() {
      ForEach(this.getDisplayGrid(), (row: number[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: number, colIdx: number) => {
            Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .borderRadius(2)
              .backgroundColor(this.cellColor(cell, colIdx, rowIdx))
              // 食物脉冲动画
              .scale(cell === 3 ? { x: 1.12, y: 1.12 } : { x: 1, y: 1 })
              .animation(cell === 3 ?
                { duration: 600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate } :
                { duration: 0 })
          }, (colIdx: number) => colIdx.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }, (rowIdx: number) => rowIdx.toString())
    }
    .width('100%')
    .aspectRatio(1)
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
          .fontFamily(this.palette.fontSans)
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
            .fontFamily(this.palette.fontSans)
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
            .fontFamily(this.palette.fontSans)
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
            .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.score.toString())
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.level.toString())
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.bestScore.toString())
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
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
      Column({ space: 12 }) {
        Text('游戏结束')
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.danger)
          .fontWeight(FontWeight.Bold)
        if (this.newRecord) {
          Text('🎉 新纪录！')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.warning)
            .fontWeight(FontWeight.Bold)
        }
        Text('最终得分：' + this.score.toString())
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text('蛇身长度：' + this.snake.length.toString() + ' · 历史最高：' + this.bestScore.toString())
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text('用时 ' + this.formatDuration(this.playSeconds))
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Row({ space: 12 }) {
          // 重新开始
          Column({ space: 6 }) {
            Row() {
            Text('↺')
              .fontSize(22)
              .fontFamily(this.palette.fontSans)
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
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.restartGame(); })

          // 返回
          Column({ space: 6 }) {
            Row() {
            Text('←')
              .fontSize(22)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
              .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('返回')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
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

  // ---- 暂停弹窗 ----
  @Builder
  pauseOverlay() {
    Stack() {
      Column({ space: 12 }) {
        Text('已暂停')
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Row({ space: 10 }) {
          Text('难度')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
          Text(difficultyLabel(this.difficulty))
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.primary)
            .fontWeight(FontWeight.Medium)
          Text('›')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(this.palette.bgSurface2)
        .onClick(() => { this.cycleDifficulty(); })
        Row({ space: 12 }) {
          // 继续
          Column({ space: 6 }) {
            Row() {
            Text('▶')
              .fontSize(20)
              .fontFamily(this.palette.fontSans)
              .fontColor('#0A0E1A')
            }
            .width(48)
            .height(48)
            .borderRadius(24)
              .backgroundColor(this.palette.primary)
            .justifyContent(FlexAlign.Center)
            Text('继续')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.togglePause(); })

          // 重新开始
          Column({ space: 6 }) {
            Row() {
            Text('↺')
              .fontSize(20)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
              .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('重新开始')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.restartGame(); })

          // 返回
          Column({ space: 6 }) {
            Row() {
            Text('←')
              .fontSize(20)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
            }
            .width(48)
            .height(48)
            .borderRadius(24)
              .backgroundColor(this.palette.bgSurface2)
            .justifyContent(FlexAlign.Center)
            Text('返回')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
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

  // ---- 操作栏 ----
  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      // 使用说明
      Row() {
        Text('📖')
          .fontSize(14)
          .fontFamily(this.palette.fontSans)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.showHelp = true; })

      // 战绩
      Row() {
        Text('🏆')
          .fontSize(14)
          .fontFamily(this.palette.fontSans)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
         router.pushUrl({ url: 'pages/GameHistory', params: new GameHistoryRouteParams('Snake') });
      })

      // 暂停
      Row() {
        Text(this.isPaused ? '▶' : '⏸')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
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
    const params: GameRouteParams | null = router.getParams() as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.SNAKE);
    if (!result.success || result.request === null) {
      promptAction.showToast({ message: result.message });
      router.back();
      return;
    }
    this.loadBestScore();
    this.startWithDifficulty(result.request.difficulty);
    this.initAiPanel();
    ScreenKeepAlive.enable(getContext(this));
  }

  aboutToDisappear(): void {
    this.stopAi();
    this.stopTimer();
    ScreenKeepAlive.disable(getContext(this));
    // 中途退出时保存当前分数
    if (this.gameStarted && this.score > 0 && !this.scoreSaved) {
      this.saveScore();
    }
  }

  // ---- 使用说明 ----
  @Builder
  helpDialog() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showHelp = false; })
          }
          .width('100%')
          .padding({ right: 4, top: 4 })

          Scroll() {
            Text('📖 贪吃蛇\n\n' +
              '【目标】\n控制蛇移动吃掉食物，每吃一个蛇身增长，尽可能得高分。\n\n' +
              '【操作】\n' +
              '• 方向键 / 滑动屏幕：控制蛇的移动方向\n' +
              '• 蛇不能掉头（不能直接反向移动）\n' +
              '• 按空格键或点击暂停按钮可暂停/继续\n\n' +
              '【规则】\n' +
              '• 蛇头撞到墙壁或自己的身体则游戏结束\n' +
              '• 每吃一个食物得 10 分，蛇身长度 +1\n' +
              '• 难度越高，蛇的移动速度越快')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .lineHeight(22)
              .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 400 })
          .padding({ left: 20, right: 20, bottom: 16 })
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(this.palette.bgBase)
        .padding({ bottom: Math.max(16, this.navBarHeight) })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showHelp = false; })
  }

  build() {
    Stack() {
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
        if (this.gameStarted) {
          Column() {
            Stack() {
              Column() {
                this.gameBoard()
              }
              .gesture(
                PanGesture({ fingers: 1, direction: PanDirection.All, distance: 10 })
                  .onActionEnd((event: GestureEvent) => {
                    if (this.aiRunning || this.isGameOver || this.isPaused) return;
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
            .width(this.boardSide())
            .height(this.boardSide())
            .alignContent(Alignment.Center)

            GameAIPanel({
              modelNames: this.aiModelNames,
              selectedModelIndex: this.aiModelIndex,
              running: this.aiRunning,
              status: this.aiStatus,
              speedIndex: this.aiSpeedIndex,
              modelsConfigured: this.aiModelsConfigured,
              thinkingCount: this.aiThinkCount,
              thinkingFailCount: this.aiFailCount,
              thinkingTimeMs: this.aiThinkTimeMs,
              onSelectModel: (index: number): void => { this.selectAiModel(index); },
              onToggleRun: (): void => { this.toggleAi(); },
              onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
            })

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
        if (this.gameStarted) {
          Row({ space: 20 }) {
            Column({ space: 12 }) {
              Stack() {
                Column() {
                  this.gameBoard()
                }
                .gesture(
                  PanGesture({ fingers: 1, direction: PanDirection.All, distance: 10 })
                    .onActionEnd((event: GestureEvent) => {
                      if (this.aiRunning || this.isGameOver || this.isPaused) return;
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
              .width(this.boardSide())
              .height(this.boardSide())
              .alignContent(Alignment.Center)

              this.directionPad()
            }
            .alignItems(HorizontalAlign.Center)

            Scroll() {
              Column({ space: 12 }) {
                GameAIPanel({
                  modelNames: this.aiModelNames,
                  selectedModelIndex: this.aiModelIndex,
                  running: this.aiRunning,
                  status: this.aiStatus,
                  speedIndex: this.aiSpeedIndex,
                  modelsConfigured: this.aiModelsConfigured,
                  thinkingCount: this.aiThinkCount,
                  thinkingFailCount: this.aiFailCount,
                  thinkingTimeMs: this.aiThinkTimeMs,
                  onSelectModel: (index: number): void => { this.selectAiModel(index); },
                  onToggleRun: (): void => { this.toggleAi(); },
                  onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
                })
                this.infoPanel()
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
        if (event.type !== KeyType.Down) return;
        const code: KeyCode = event.keyCode;
        if (code === KeyCode.KEYCODE_P || code === KeyCode.KEYCODE_ENTER) {
          this.togglePause();
          return;
        }
        if (code === KeyCode.KEYCODE_R) {
          this.restartGame();
          return;
        }
        if (this.aiRunning) return;
        if (this.isGameOver || this.isPaused) return;
        if (code === KeyCode.KEYCODE_DPAD_LEFT || code === KeyCode.KEYCODE_A) {
          this.changeDirection(Direction.LEFT);
        } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
          this.changeDirection(Direction.RIGHT);
        } else if (code === KeyCode.KEYCODE_DPAD_UP || code === KeyCode.KEYCODE_W) {
          this.changeDirection(Direction.UP);
        } else if (code === KeyCode.KEYCODE_DPAD_DOWN || code === KeyCode.KEYCODE_S) {
          this.changeDirection(Direction.DOWN);
        }
      })

      // 得分飘字
      if (this.showFloatScore) {
        Text(this.floatScore)
          .fontSize(this.palette.fsXl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.warning)
          .fontWeight(FontWeight.Bold)
          .position({ x: '50%', y: '12%' })
          .translate({ x: '-50%' })
          .transition({ type: TransitionType.Insert, translate: { x: '-50%', y: -50 }, opacity: 0 })
          .animation({ duration: 800, curve: Curve.Friction })
      }

      if (this.showHelp) { this.helpDialog() }
    }
    .width('100%')
    .height('100%')
  }
}

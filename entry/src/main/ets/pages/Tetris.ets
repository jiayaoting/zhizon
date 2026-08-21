// 智子 - 俄罗斯方块
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
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
import { GameAIService, GameAction, AI_SPEED_DELAYS } from '../service/GameAIService';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { ScreenKeepAlive } from '../common/ScreenKeepAlive';
import { SoundService } from '../service/SoundService';

const COLS: number = 10;
const ROWS: number = 20;

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

// SRS 踢墙表（简化标准）
const SRS_KICKS_JLSTZ: Array<Array<[number, number]>> = [
  [[-1, 0], [-1, 1], [0, -2], [-1, -2]],
  [[1, 0], [1, -1], [0, 2], [1, 2]],
  [[1, 0], [1, 1], [0, -2], [1, -2]],
  [[-1, 0], [-1, -1], [0, 2], [-1, 2]]
];
const SRS_KICKS_I: Array<Array<[number, number]>> = [
  [[-2, 0], [1, 0], [-2, -1], [1, 2]],
  [[-1, 0], [2, 0], [-1, 2], [2, -1]],
  [[2, 0], [-1, 0], [2, 1], [-1, -2]],
  [[1, 0], [-2, 0], [1, -2], [-2, 1]]
];

const PIECE_COLORS: string[] = [
  '#00D4AA',   // I - 青绿
  '#FBBF24',   // O - 黄
  '#8B5CF6',   // T - 紫
  '#10B981',   // S - 绿
  '#EF4444',   // Z - 红
  '#3B82F6',   // J - 蓝
  '#F97316'    // L - 橙
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
function dropInterval(level: number, difficulty: DifficultyLevel): number {
  // 难度影响基础速度：超简单=1000, 简单=800, 中等=600, 困难=450, 地狱=300
  let base: number = 600;
  if (difficulty === DifficultyLevel.VERY_EASY) base = 1000;
  else if (difficulty === DifficultyLevel.EASY) base = 800;
  else if (difficulty === DifficultyLevel.HARD) base = 450;
  else if (difficulty === DifficultyLevel.HELL) base = 300;
  const min: number = 60;
  const interval: number = base - (level - 1) * 50;
  return Math.max(interval, min);
}

interface Piece {
  type: number;
  rotation: number;
  x: number;
  y: number;
}

@Component
@Entry
export struct TetrisPage {
  @State board: number[][] = [];
  @State boardDisplay: number[][] = [];
  @State currentPiece: Piece | null = null;
  @State nextType: number = 0;
  private bag: number[] = [];
  @State score: number = 0;
  @State level: number = 1;
  @State lines: number = 0;
  @State isGameOver: boolean = false;
  @State isPaused: boolean = false;
  @State clearedRows: number[] = [];
  @State combo: number = -1;
  @State tSpin: boolean = false;
  @State lastAction: string = 'drop';
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false;
  @State bestScore: number = 0;
  @State heldType: number = -1;
  @State holdUsed: boolean = false;
  @State autoPaused: boolean = false;
  @State floatScore: string = '';
  @State showFloatScore: boolean = false;
  @State newRecord: boolean = false;
  @State showHelp: boolean = false;
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
  @State aiThinkTotalMs: number = 0;
  private aiThinkTimer: number = -1;
  private aiThinkStart: number = 0;
  private aiHosted: boolean = false;
  private aiSelectSeq: number = 0;

  private timerId: number = -1;
  private titleText: string = '俄罗斯方块';
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
      // 手机端：TopBar + 信息栏 + 下一个 + 旋转按钮 + 间距 + 安全区
      return DeviceMetrics.fitCellSize(COLS, ROWS, 350, 14, 24);
    }
    // 平板端：TopBar + 安全区
    return DeviceMetrics.fitCellSize(COLS, ROWS, 140, 16, 30);
  }

  private boardWidth(): number {
    return COLS * this.boardCellSize();
  }

  private boardHeight(): number {
    return ROWS * this.boardCellSize();
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
    this.syncBoardDisplay();
  }

  private nextFromBag(): number {
    if (this.bag.length === 0) {
      this.bag = [0, 1, 2, 3, 4, 5, 6];
      for (let i: number = this.bag.length - 1; i > 0; i--) {
        const j: number = Math.floor(Math.random() * (i + 1));
        const tmp: number = this.bag[i];
        this.bag[i] = this.bag[j];
        this.bag[j] = tmp;
      }
    }
    return this.bag.pop() as number;
  }

  private randomType(): number {
    return this.nextFromBag();
  }

  private spawnPiece(): void {
    const t: number = this.nextType;
    this.nextType = this.randomType();
    const shape: number[][] = SHAPES[t][0];
    const pieceX: number = Math.floor((COLS - this.pieceWidth(shape)) / 2);
    this.currentPiece = { type: t, rotation: 0, x: pieceX, y: 0 };
    this.syncBoardDisplay();
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
      this.lastAction = 'move';
      this.syncBoardDisplay();
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
      this.lastAction = 'rotate';
      this.syncBoardDisplay();
      this.vibrate(10);
      return;
    }
    // SRS Wall kick：根据方块类型和旋转状态尝试标准踢墙表
    const kickTable: Array<Array<[number, number]>> = p.type === 0 ? SRS_KICKS_I : SRS_KICKS_JLSTZ;
    const kicks: Array<[number, number]> = kickTable[p.rotation];
    for (let k: number = 0; k < kicks.length; k++) {
      const dx: number = kicks[k][0];
      const dy: number = kicks[k][1];
      if (!this.collides(p.type, newRot, p.x + dx, p.y + dy)) {
        this.currentPiece = { type: p.type, rotation: newRot, x: p.x + dx, y: p.y + dy };
        this.lastAction = 'rotate';
        this.syncBoardDisplay();
        this.vibrate(10);
        return;
      }
    }
  }

  // ---- 软降：每次下落一格并 +1 分 ----
  softDrop(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    if (!this.collides(p.type, p.rotation, p.x, p.y + 1)) {
      this.currentPiece = { type: p.type, rotation: p.rotation, x: p.x, y: p.y + 1 };
      this.lastAction = 'drop';
      this.score += 1;
      this.syncBoardDisplay();
    } else {
      this.lockPiece();
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
    this.lastAction = 'drop';
    this.vibrate(20);
    this.lockPiece();
  }

  // ---- 暂存方块（Hold） ----
  holdPiece(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null || this.holdUsed) return;
    const current: Piece = this.currentPiece;
    if (this.heldType === -1) {
      this.heldType = current.type;
      this.holdUsed = true;
      this.spawnPiece();
    } else {
      const swapType: number = this.heldType;
      this.heldType = current.type;
      const shape: number[][] = SHAPES[swapType][0];
      const pieceX: number = Math.floor((COLS - this.pieceWidth(shape)) / 2);
      this.currentPiece = { type: swapType, rotation: 0, x: pieceX, y: 0 };
      this.holdUsed = true;
      this.syncBoardDisplay();
    }
    this.vibrate(10);
  }

  // ---- 落点投影（Ghost） ----
  private ghostDropY(): number {
    if (this.currentPiece === null) return 0;
    const p: Piece = this.currentPiece;
    let dropY: number = p.y;
    while (!this.collides(p.type, p.rotation, p.x, dropY + 1)) {
      dropY++;
    }
    return dropY;
  }

  // ---- 锁定方块 ----
  private lockPiece(): void {
    if (this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    // T-spin 简化检测：T 块且最后动作为旋转时，检查三个角是否被占用
    this.tSpin = false;
    if (p.type === 2 && this.lastAction === 'rotate') {
      const corners: Array<[number, number]> = [[-1, -1], [1, -1], [-1, 1], [1, 1]];
      let blocked: number = 0;
      for (const corner of corners) {
        const cx: number = p.x + corner[0];
        const cy: number = p.y + corner[1];
        if (cx < 0 || cx >= COLS || cy < 0 || cy >= ROWS || (cy >= 0 && cy < ROWS && cx >= 0 && cx < COLS && this.board[cy][cx] !== 0)) {
          blocked += 1;
        }
      }
      this.tSpin = blocked >= 3;
    }
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
      this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
        this.clearedRows = fullRows;
        this.board = afterBoard;
        this.syncBoardDisplay();
      });

      const cleared: number = fullRows.length;
      this.lines += cleared;
      this.combo += 1;
      const gained: number = scoreForLines(cleared) + Math.max(0, this.combo) * 50 + (this.tSpin ? 400 : 0);
      this.score += gained;
      this.level = Math.floor(this.lines / 10) + 1;

      // 触觉反馈 + 飘字
      this.vibrate(cleared >= 4 ? 60 : 30);
      this.showScoreFloat('+' + gained.toString());

      // 等级提升提示
      if (this.level > this.lastLevel) {
        promptAction.showToast({ message: `等级提升 → Level ${this.level}` });
        this.lastLevel = this.level;
      }

      // 清除动画标记
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
          this.clearedRows = [];
        });
      }, 220);
    } else {
      this.combo = -1;
    }

    // 允许再次 Hold
    this.holdUsed = false;

    // 生成新方块
    this.spawnPiece();

    // 检查游戏结束
    if (this.currentPiece !== null && this.collides(this.currentPiece.type, this.currentPiece.rotation, this.currentPiece.x, this.currentPiece.y)) {
      this.isGameOver = true;
      this.currentPiece = null;
      this.stopTimer();
      this.vibrate(80);
      SoundService.play('gameover');
      this.newRecord = this.score > this.bestScore;
      if (this.newRecord) this.bestScore = this.score;
      this.playSeconds = Math.floor((Date.now() - this.gameStartTime) / 1000);
      this.saveScore();
    }
    this.syncBoardDisplay();
  }

  // ---- 下落 ----
  private drop(): void {
    if (this.isGameOver || this.isPaused || this.currentPiece === null) return;
    const p: Piece = this.currentPiece;
    if (!this.collides(p.type, p.rotation, p.x, p.y + 1)) {
      this.currentPiece = { type: p.type, rotation: p.rotation, x: p.x, y: p.y + 1 };
      this.syncBoardDisplay();
    } else {
      this.lockPiece();
    }
  }

  // ---- 定时器 ----
  private startTimer(): void {
    this.stopTimer();
    const interval: number = dropInterval(this.level, this.difficulty);
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
  private startWithDifficulty(level: DifficultyLevel): void {
    this.difficulty = level;
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.aiThinkTimeMs = 0;
    this.aiThinkTotalMs = 0;
    this.gameStarted = true;
    this.initBoard();
    this.score = 0;
    this.level = 1;
    this.lines = 0;
    this.isGameOver = false;
    this.isPaused = false;
    this.clearedRows = [];
    this.heldType = -1;
    this.holdUsed = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.lastLevel = 1;
    this.gameStartTime = Date.now();
    this.nextType = this.randomType();
    this.spawnPiece();
    this.startTimer();
  }

  restartGame(): void {
    this.stopAi();
    this.aiHosted = false;
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.aiThinkTimeMs = 0;
    this.aiThinkTotalMs = 0;
    this.initBoard();
    this.score = 0;
    this.level = 1;
    this.lines = 0;
    this.isGameOver = false;
    this.isPaused = false;
    this.clearedRows = [];
    this.heldType = -1;
    this.holdUsed = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.lastLevel = 1;
    this.gameStartTime = Date.now();
    this.nextType = this.randomType();
    this.spawnPiece();
    this.startTimer();
  }

  private saveScore(): void {
    if (this.scoreSaved) return;
    this.scoreSaved = true;
    DataRepository.addGameScore('Tetris', this.score, this.level, difficultyLabel(this.difficulty),
      this.currentAiModelName(), this.playSeconds, Math.floor(this.aiThinkTotalMs / 1000));
  }

  togglePause(): void {
    if (this.isGameOver) return;
    if (this.aiRunning) {
      this.isPaused = true;
      this.stopAi();
      this.autoPaused = false;
      return;
    }
    this.isPaused = !this.isPaused;
    this.autoPaused = false;
    if (!this.isPaused) {
      this.startTimer();
    }
  }

  // ---- 页面隐藏时自动暂停 ----
  onPageHide(): void {
    this.stopAi();
    if (!this.isPaused && !this.isGameOver && this.gameStarted) {
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
    const best: number = await DataRepository.getGameHighScore('Tetris');
    this.bestScore = best;
  }

  // ---- AI 托管（AI 决策期间冻结重力计时器，避免方块在 AI 思考时落地） ----
  private async initAiPanel(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    // 恢复本游戏记忆的模型；无记忆时保持默认（激活模型）
    const savedId: string = await GameAIService.loadSavedModelId('Tetris');
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
    this.aiHosted = true;
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.aiThinkTimeMs = 0;
    this.aiThinkTotalMs = 0;
    // 游戏时间从点击「AI 托管」这一刻开始计时（含 AI 思考耗时）
    this.gameStartTime = Date.now();
    this.playSeconds = 0;
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
    this.stopThinkTimer();
    this.aiThinkStart = Date.now();
    this.aiThinkTimeMs = 0;
    this.aiThinkTimer = setInterval(() => {
      this.aiThinkTimeMs = Date.now() - this.aiThinkStart;
    }, 100);
  }

  private stopThinkTimer(): void {
    if (this.aiThinkTimer >= 0) {
      clearInterval(this.aiThinkTimer);
      this.aiThinkTimer = -1;
      // 累计 AI 思考总时长（毫秒）
      this.aiThinkTotalMs += Math.max(0, Date.now() - this.aiThinkStart);
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
      GameAIService.saveModelId('Tetris', this.aiModels[index].id);
    }
  }

  private changeAiSpeed(index: number): void {
    if (this.aiRunning) return;
    this.aiSpeedIndex = index;
  }

  // AI 决策循环：冻结重力，每轮 决策 → 执行动作 → 展示窗口 → 手动推进一格
  private async aiLoop(): Promise<void> {
    if (!this.aiRunning || this.aiLoopActive) return;
    this.aiLoopActive = true;
    while (this.aiRunning) {
      if (this.isGameOver || this.isPaused) break;
      if (this.aiConfig === null) break;
      const p: Piece | null = this.currentPiece;
      if (p === null) break;
      this.aiThinkCount += 1;
      this.aiStatus = 'AI 思考中…';
      this.startThinkTimer();
      const stateText: string = GameAIService.serializeTetris(this.board, p.type, p.rotation, p.x, p.y,
        this.nextType, this.score, this.level);
      const messages = GameAIService.buildMessages('Tetris', this.difficulty, stateText);
      const result = await GameAIService.decide(this.aiConfig, messages, 'Tetris');
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
      // 俄罗斯方块：一次请求返回完整动作序列，一次放置只调用一次 LLM，大幅提速
      const actions: GameAction[] = GameAIService.parseActionSequence('Tetris', result.content);
      // 兜底：模型没有输出动作，或没有收尾下落时，强制 HARD_DROP，保证每轮一定落子
      if (actions.length === 0) {
        actions.push(new GameAction('HARD_DROP'));
      }
      let hasDrop: boolean = false;
      for (let i: number = 0; i < actions.length; i++) {
        if (actions[i].command === 'HARD_DROP' || actions[i].command === 'SOFT_DROP') {
          hasDrop = true;
          break;
        }
      }
      if (!hasDrop) {
        actions.push(new GameAction('HARD_DROP'));
      }
      this.aiStatus = 'AI 执行 ' + actions.length.toString() + ' 步';
      for (let i: number = 0; i < actions.length; i++) {
        if (!this.aiRunning || this.isGameOver || this.isPaused) break;
        const pieceBefore: Piece | null = this.currentPiece;
        const action: GameAction = actions[i];
        if (action.command === 'LEFT') this.moveLeft();
        else if (action.command === 'RIGHT') this.moveRight();
        else if (action.command === 'ROTATE') this.rotatePiece();
        else if (action.command === 'SOFT_DROP') this.softDrop();
        else if (action.command === 'HARD_DROP') this.hardDrop();
        else if (action.command === 'HOLD') this.holdPiece();
        // 方块被锁定（放置完成，生成了新方块）：新方块回到顶部 y=0，
        // 用 y 坐标判断（移动/软降会让对象引用变化，不能用引用比较）
        if (pieceBefore !== null &&
          (action.command === 'SOFT_DROP' || action.command === 'HARD_DROP') &&
          this.currentPiece !== null && this.currentPiece.y <= pieceBefore.y) {
          break;
        }
      }
      if (this.isGameOver || this.isPaused || this.currentPiece === null) break;
      if (this.aiSpeedIndex < AI_SPEED_DELAYS.length && AI_SPEED_DELAYS[this.aiSpeedIndex] > 0) {
        await new Promise<void>((resolve) => {
          setTimeout(() => { resolve(); }, AI_SPEED_DELAYS[this.aiSpeedIndex]);
        });
      }
      if (this.isGameOver || this.isPaused || this.currentPiece === null) break;
      // 展示窗口结束后手动推进一格，保持游戏节奏
      this.drop();
      if (this.isGameOver) break;
    }
    this.aiLoopActive = false;
    this.stopThinkTimer();
    if (this.aiRunning) {
      this.aiRunning = false;
      this.aiStatus = this.isGameOver ? 'AI 结束：游戏已终局' : 'AI 已暂停';
    }
  }

  // ---- 获取合并后的棋盘（含当前活动方块与落点投影） ----
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
      const ghostY: number = this.ghostDropY();
      for (let i: number = 0; i < shape.length; i++) {
        const bx: number = p.x + shape[i][0];
        const by: number = p.y + shape[i][1];
        if (by >= 0 && by < ROWS && bx >= 0 && bx < COLS) {
          display[by][bx] = p.type + 1;
        }
        // 落点投影（100+ 表示 ghost）
        const gx: number = p.x + shape[i][0];
        const gy: number = ghostY + shape[i][1];
        if (gy >= 0 && gy < ROWS && gx >= 0 && gx < COLS) {
          if (display[gy][gx] === 0) {
            display[gy][gx] = 100 + p.type + 1;
          }
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
  private syncBoardDisplay(): void {
    this.boardDisplay = this.getDisplayBoard();
  }

  @Builder
  gameBoard() {
    Column() {
      ForEach(this.boardDisplay, (row: number[], rowIdx: number) => {
        Row() {
          ForEach(row, (cell: number, colIdx: number) => {
            Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .borderRadius(2)
              .backgroundColor(cell >= 100 ? PIECE_COLORS[cell - 100 - 1] :
                (cell > 0 ? PIECE_COLORS[cell - 1] : this.palette.bgSurface2))
              .opacity(cell >= 100 ? 0.35 : 1)
              .scale(this.clearedRows.indexOf(rowIdx) !== -1 ? { x: 1.15, y: 1.15 } : { x: 1, y: 1 })
              .border({ width: cell > 0 && cell < 100 ? 0.5 : 0, color: 'rgba(255,255,255,0.1)' })
          }, (colIdx: number) => colIdx.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }, (rowIdx: number) => rowIdx.toString())
    }
    .width('100%')
    .height('100%')
    .border({ width: 2, color: this.palette.borderDefault })
    .borderRadius(6)
    .padding(2)
    .backgroundColor(this.palette.bgSurface)
  }

  // ---- 旋转按钮 ----
  @Builder
  rotateButton() {
    Row() {
      Text('↻ 旋转')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
    }
    .width('100%')
    .height(this.isSm ? 36 : 48)
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface2)
    .justifyContent(FlexAlign.Center)
    .border({ width: 1, color: this.palette.borderSubtle })
    .margin({ top: 8, bottom: this.isSm ? 12 : 0 })
    .onClick(() => { this.rotatePiece(); })
  }

  // ---- 信息面板 ----
  @Builder
  infoPanel() {
    Column({ space: 12 }) {
      // 下一个方块 — 放最前面确保可见
      Column({ space: 4 }) {
        Text('下一个')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Column() {
          this.previewPiece(this.nextType)
        }
        .width('100%')
        .padding(8)
        .backgroundColor(this.palette.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: this.palette.borderSubtle })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 分数
      Column({ space: 4 }) {
        Text('分数')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.score.toString())
          .fontSize(this.palette.fsXl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .padding(10)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(10)
      .border({ width: 1, color: this.palette.borderSubtle })

      // 等级 & 行数
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text('等级')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
          Text(this.level.toString())
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.warning)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding(10)
        .backgroundColor(this.palette.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: this.palette.borderSubtle })

        Column({ space: 4 }) {
          Text('行数')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
          Text(this.lines.toString())
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.info)
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding(10)
        .backgroundColor(this.palette.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: this.palette.borderSubtle })
      }
      .width('100%')
    }
    .width('100%')
  }

  // ---- 游戏结束遮罩 ----
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
        Text('历史最高：' + this.bestScore.toString() + ' · 用时 ' + this.formatDuration(this.playSeconds))
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
          .onClick(() => { AppNavigator.pop(); })
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
          .onClick(() => { AppNavigator.pop(); })
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

  // ---- 顶栏操作按钮 ----
  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      // 暂存方块（Hold）
      Row() {
        Text(this.heldType >= 0 ? (this.heldType + 1).toString() : 'H')
          .fontSize(13)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.holdUsed ? this.palette.textTertiary : this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.heldType >= 0 ? PIECE_COLORS[this.heldType] + '33' :
        (this.holdUsed ? this.palette.bgSurface2 : this.palette.primaryDim))
      .justifyContent(FlexAlign.Center)
      .border({ width: 1, color: this.holdUsed ? this.palette.borderSubtle : this.palette.primary })
      .onClick(() => { this.holdPiece(); })

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
         AppNavigator.push('pages/GameHistory', new GameHistoryRouteParams('Tetris'));
      })

      // 暂停/继续
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
    const params: GameRouteParams | null = AppNavigator.getParam('pages/Tetris') as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.TETRIS);
    if (!result.success || result.request === null) {
      promptAction.showToast({ message: result.message });
      AppNavigator.pop();
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
            Text('📖 俄罗斯方块\n\n' +
              '【目标】\n消除满行获取高分，尽可能坚持更久。\n\n' +
              '【操作】\n' +
              '• 方向键 ← →：左右移动方块\n' +
              '• 方向键 ↑：旋转方块\n' +
              '• 方向键 ↓：加速下落\n' +
              '• 空格键：方块直接落底\n' +
              '• 触屏：左右滑动移动，点击旋转\n' +
              '• H 按钮：暂存当前方块\n\n' +
              '【规则】\n' +
              '• 方块填满一行即可消除，消除行数越多单次得分越高\n' +
              '• 消除 1 行 = 100 分，2 行 = 300 分，3 行 = 500 分，4 行 = 800 分\n' +
              '• 方块堆叠到顶部则游戏结束\n' +
              '• 难度越高，下落速度越快')
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
        if (this.gameStarted) {
          // ---- 手机端：顶部信息 → 下一个 → 棋盘 → 旋转按钮 ----
          Column({ space: 8 }) {
          // 顶部信息栏：分数 | 等级 | 行数
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text('分数')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
              Text(this.score.toString())
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })

            Column({ space: 2 }) {
              Text('等级')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
              Text(this.level.toString())
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.warning)
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })

            Column({ space: 2 }) {
              Text('行数')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
              Text(this.lines.toString())
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.info)
                .fontWeight(FontWeight.Bold)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding(6)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
          }
          .width('100%')

          // 下一个方块 — 放在棋盘顶部
          Row({ space: 8 }) {
            Text('下一个')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            this.previewPiece(this.nextType)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(6)
          .backgroundColor(this.palette.bgSurface)
          .borderRadius(8)
          .border({ width: 1, color: this.palette.borderSubtle })

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
                thinkingTotalMs: this.aiThinkTotalMs,
                onSelectModel: (index: number): void => { this.selectAiModel(index); },
                onToggleRun: (): void => { this.toggleAi(); },
                onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
              })

          // 棋盘
          Stack() {
            Column() {
              this.gameBoard()
            }
            .gesture(
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionEnd((event: GestureEvent) => {
                  if (this.aiRunning || this.isGameOver || this.isPaused) return;
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
          .width(this.boardWidth())
          .height(this.boardHeight())
          .alignContent(Alignment.Center)

          // 旋转按钮
          this.rotateButton()
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 8, right: 8, top: 4, bottom: 16 })
        }
      } else {
        if (this.gameStarted) {
          // ---- 平板端：棋盘左 + (下一个+旋转+信息)右 ----
          Row({ space: 20 }) {
          // 左侧：棋盘
          Stack() {
            Column() {
              this.gameBoard()
            }
            .gesture(
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
                .onActionEnd((event: GestureEvent) => {
                  if (this.aiRunning || this.isGameOver || this.isPaused) return;
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
          .width(this.boardWidth())
          .height(this.boardHeight())
          .alignContent(Alignment.Center)

          // 右侧：下一个 + 旋转 + 信息
          Column({ space: 12 }) {
            // 下一个方块 — 放在顶部
            Column({ space: 4 }) {
              Text('下一个')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
              Column() {
                this.previewPiece(this.nextType)
              }
              .width('100%')
              .padding(8)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(10)
              .border({ width: 1, color: this.palette.borderSubtle })
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            // 旋转按钮
            this.rotateButton()

            // AI 托管面板
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
              thinkingTotalMs: this.aiThinkTotalMs,
              onSelectModel: (index: number): void => { this.selectAiModel(index); },
              onToggleRun: (): void => { this.toggleAi(); },
              onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
            })

            // 信息面板
            this.infoPanel()
          }
          .layoutWeight(1)
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
          this.moveLeft();
        } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
          this.moveRight();
        } else if (code === KeyCode.KEYCODE_DPAD_DOWN || code === KeyCode.KEYCODE_S) {
          this.softDrop();
        } else if (code === KeyCode.KEYCODE_DPAD_UP || code === KeyCode.KEYCODE_W ||
          code === KeyCode.KEYCODE_X) {
          this.rotatePiece();
        } else if (code === KeyCode.KEYCODE_SPACE) {
          this.hardDrop();
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

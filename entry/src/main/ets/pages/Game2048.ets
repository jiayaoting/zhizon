// 智子 - 2048
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
import { GameAIService, GameAction, AI_SPEED_DELAYS } from '../service/GameAIService';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';

const BOARD_SIZE: number = 6;
const WIN_SCORE: number = 2048;

interface TileStyle {
  bg: string;
  fg: string;
  fontSize: number;
}

// 瓦片颜色映射
// 2048 瓦片颜色（独立函数，使用硬编码颜色避免 arkts-no-standalone-this）
// 所有前景色均为固定高对比色，不依赖主题变量，确保任何主题下数字都清晰可读
function tileStyle(value: number, palette: ThemePalette): TileStyle {
  switch (value) {
    case 2:    return { bg: '#1E293B', fg: '#E2E8F0', fontSize: 24 };
    case 4:    return { bg: '#334155', fg: '#E2E8F0', fontSize: 24 };
    case 8:    return { bg: '#3B82F6', fg: '#FFFFFF', fontSize: 24 };
    case 16:   return { bg: '#2563EB', fg: '#FFFFFF', fontSize: 24 };
    case 32:   return { bg: '#8B5CF6', fg: '#FFFFFF', fontSize: 24 };
    case 64:   return { bg: '#7C3AED', fg: '#FFFFFF', fontSize: 24 };
    case 128:  return { bg: '#F59E0B', fg: '#FFFFFF', fontSize: 22 };
    case 256:  return { bg: '#EA580C', fg: '#FFFFFF', fontSize: 22 };
    case 512:  return { bg: '#EF4444', fg: '#FFFFFF', fontSize: 22 };
    case 1024: return { bg: '#DC2626', fg: '#FFFFFF', fontSize: 20 };
    case 2048: return { bg: '#FBBF24', fg: '#7C2D12', fontSize: 20 };
    default:   return { bg: '#1A2030', fg: '#E2E8F0', fontSize: 18 };
  }
}

interface DifficultyConfig2048 {
  level: DifficultyLevel;
  prob4: number;
  initTiles: number;
}

@Entry
@Component
export struct Game2048Page {
  @State board: number[][] = [];
  @State score: number = 0;
  @State bestScore: number = 0;
  @State isGameOver: boolean = false;
  @State isWin: boolean = false;
  @State hasWonBefore: boolean = false;
  @State moveAnimating: boolean = false;
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false;
  @State isPaused: boolean = false;
  @State autoPaused: boolean = false;
  @State mergePulse: boolean = false;
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
  private aiFailCount: number = 0;
  private aiSelectSeq: number = 0;

  private titleText: string = '2048';
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

  // 自适应棋盘边长
  private boardSide(): number {
    if (this.isSm) {
      // 手机端：TopBar + 记分牌 + 间距 + 安全区
      return BOARD_SIZE * DeviceMetrics.fitCellSize(BOARD_SIZE, BOARD_SIZE, 240, 12, 72);
    }
    // 平板端：TopBar + 安全区
    return BOARD_SIZE * DeviceMetrics.fitCellSize(BOARD_SIZE, BOARD_SIZE, 160, 16, 96);
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

  // 难度对应的4出现概率和初始瓦片数
  private difficultyConfigs: DifficultyConfig2048[] = [
    { level: DifficultyLevel.VERY_EASY, prob4: 0.0, initTiles: 3 },
    { level: DifficultyLevel.EASY, prob4: 0.05, initTiles: 3 },
    { level: DifficultyLevel.MEDIUM, prob4: 0.10, initTiles: 4 },
    { level: DifficultyLevel.HARD, prob4: 0.20, initTiles: 4 },
    { level: DifficultyLevel.HELL, prob4: 0.30, initTiles: 6 }
  ];

  private difficultyConfig(level: DifficultyLevel): DifficultyConfig2048 {
    for (const config of this.difficultyConfigs) {
      if (config.level === level) return config;
    }
    return this.difficultyConfigs[2];
  }

  // ---- 初始化 ----
  private initBoard(): void {
    const b: number[][] = [];
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        row.push(0);
      }
      b.push(row);
    }
    this.board = b;
  }

  private addRandomTile(): void {
    const empty: Array<[number, number]> = [];
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        if (this.board[r][c] === 0) empty.push([r, c]);
      }
    }
    if (empty.length === 0) return;
    const idx: number = Math.floor(Math.random() * empty.length);
    const pos: [number, number] = empty[idx];
    const config = this.difficultyConfig(this.difficulty);
    const value: number = Math.random() < config.prob4 ? 4 : 2;

    const newBoard: number[][] = [];
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        row.push(this.board[r][c]);
      }
      newBoard.push(row);
    }
    newBoard[pos[0]][pos[1]] = value;
    this.board = newBoard;
  }

  // ---- 核心滑动逻辑 ----
  private slideRow(row: number[]): number[] {
    // 去掉0
    const filtered: number[] = [];
    for (let i: number = 0; i < row.length; i++) {
      if (row[i] !== 0) filtered.push(row[i]);
    }
    // 合并
    const merged: number[] = [];
    let i: number = 0;
    while (i < filtered.length) {
      if (i + 1 < filtered.length && filtered[i] === filtered[i + 1]) {
        const sum: number = filtered[i] * 2;
        merged.push(sum);
        this.score += sum;
        i += 2;
      } else {
        merged.push(filtered[i]);
        i++;
      }
    }
    // 补0
    while (merged.length < BOARD_SIZE) {
      merged.push(0);
    }
    return merged;
  }

  private boardEquals(a: number[][], b: number[][]): boolean {
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        if (a[r][c] !== b[r][c]) return false;
      }
    }
    return true;
  }

  private copyBoard(): number[][] {
    const copy: number[][] = [];
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        row.push(this.board[r][c]);
      }
      copy.push(row);
    }
    return copy;
  }

  private move(direction: string): void {
    if (this.isGameOver || this.moveAnimating || this.isPaused) return;

    const prevScore: number = this.score;
    const oldBoard: number[][] = this.copyBoard();
    let newBoard: number[][] = [];

    if (direction === 'left') {
      for (let r: number = 0; r < BOARD_SIZE; r++) {
        const row: number[] = [];
        for (let c: number = 0; c < BOARD_SIZE; c++) row.push(this.board[r][c]);
        const slid: number[] = this.slideRow(row);
        newBoard.push(slid);
      }
    } else if (direction === 'right') {
      for (let r: number = 0; r < BOARD_SIZE; r++) {
        const row: number[] = [];
        for (let c: number = 0; c < BOARD_SIZE; c++) row.push(this.board[r][c]);
        const reversed: number[] = [];
        for (let c: number = BOARD_SIZE - 1; c >= 0; c--) reversed.push(row[c]);
        const slid: number[] = this.slideRow(reversed);
        const back: number[] = [];
        for (let c: number = BOARD_SIZE - 1; c >= 0; c--) back.push(slid[c]);
        newBoard.push(back);
      }
    } else if (direction === 'up') {
      for (let r: number = 0; r < BOARD_SIZE; r++) {
        const row: number[] = [];
        for (let c: number = 0; c < BOARD_SIZE; c++) row.push(0);
        newBoard.push(row);
      }
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        const col: number[] = [];
        for (let r: number = 0; r < BOARD_SIZE; r++) col.push(this.board[r][c]);
        const slid: number[] = this.slideRow(col);
        for (let r: number = 0; r < BOARD_SIZE; r++) newBoard[r][c] = slid[r];
      }
    } else if (direction === 'down') {
      for (let r: number = 0; r < BOARD_SIZE; r++) {
        const row: number[] = [];
        for (let c: number = 0; c < BOARD_SIZE; c++) row.push(0);
        newBoard.push(row);
      }
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        const col: number[] = [];
        for (let r: number = 0; r < BOARD_SIZE; r++) col.push(this.board[r][c]);
        const reversed: number[] = [];
        for (let i: number = col.length - 1; i >= 0; i--) reversed.push(col[i]);
        const slid: number[] = this.slideRow(reversed);
        const back: number[] = [];
        for (let i: number = slid.length - 1; i >= 0; i--) back.push(slid[i]);
        for (let r: number = 0; r < BOARD_SIZE; r++) newBoard[r][c] = back[r];
      }
    }

    if (!this.boardEquals(oldBoard, newBoard)) {
      this.board = newBoard;
      const gained: number = this.score - prevScore;
      if (gained > 0) {
        // 合并反馈：振动 + 飘字 + 棋盘脉冲动画
        this.vibrate(gained >= 512 ? 40 : 12);
        this.showScoreFloat('+' + gained.toString());
        this.mergePulse = true;
        setTimeout(() => { this.mergePulse = false; }, 180);
      }
      this.addRandomTile();
      this.checkGameOver();
    }
  }

  // ---- 合并动画（棋盘缩放脉冲） ----
  private mergeBoardScale(): ScaleOptions {
    const v: number = this.mergePulse ? 1.03 : 1;
    return { x: v, y: v };
  }

  // ---- 胜负判定 ----
  private checkGameOver(): void {
    // 检查是否有2048
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        if (this.board[r][c] >= WIN_SCORE && !this.hasWonBefore) {
          this.isWin = true;
          this.hasWonBefore = true;
          return;
        }
      }
    }

    // 检查是否还有空位
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      for (let c: number = 0; c < BOARD_SIZE; c++) {
        if (this.board[r][c] === 0) return;
      }
    }

    // 检查是否还能合并
    for (let r: number = 0; r < BOARD_SIZE; r++) {
      for (let c: number = 0; c < BOARD_SIZE - 1; c++) {
        if (this.board[r][c] === this.board[r][c + 1]) return;
      }
    }
    for (let c: number = 0; c < BOARD_SIZE; c++) {
      for (let r: number = 0; r < BOARD_SIZE - 1; r++) {
        if (this.board[r][c] === this.board[r + 1][c]) return;
      }
    }

    this.isGameOver = true;
    this.vibrate(80);
    this.newRecord = this.score > this.bestScore;
    if (this.newRecord) this.bestScore = this.score;
    this.playSeconds = Math.max(0, Math.floor((Date.now() - this.gameStartTime) / 1000));
    this.saveScore();
  }

  private saveScore(): void {
    if (this.scoreSaved) return;
    this.scoreSaved = true;
    DataRepository.addGameScore('2048', this.score, 1, difficultyLabel(this.difficulty));
  }

  // ---- 游戏控制 ----
  private startWithDifficulty(level: DifficultyLevel): void {
    this.difficulty = level;
    this.gameStarted = true;
    this.initBoard();
    this.score = 0;
    this.isGameOver = false;
    this.isWin = false;
    this.hasWonBefore = false;
    this.isPaused = false;
    this.autoPaused = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.gameStartTime = Date.now();
    const config = this.difficultyConfig(this.difficulty);
    for (let i: number = 0; i < config.initTiles; i++) {
      this.addRandomTile();
    }
  }

  restartGame(): void {
    this.stopAi();
    this.initBoard();
    this.score = 0;
    this.isGameOver = false;
    this.isWin = false;
    this.hasWonBefore = false;
    this.isPaused = false;
    this.autoPaused = false;
    this.newRecord = false;
    this.playSeconds = 0;
    this.scoreSaved = false;
    this.gameStartTime = Date.now();
    const config = this.difficultyConfig(this.difficulty);
    for (let i: number = 0; i < config.initTiles; i++) {
      this.addRandomTile();
    }
  }

  continueGame(): void {
    this.isWin = false;
  }

  // ---- 暂停 ----
  togglePause(): void {
    if (this.isGameOver || this.isWin) return;
    this.isPaused = !this.isPaused;
    this.autoPaused = false;
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
    promptAction.showToast({ message: `难度：${difficultyLabel(this.difficulty)}` });
  }

  private async loadBestScore(): Promise<void> {
    const best: number = await DataRepository.getGameHighScore('2048');
    this.bestScore = best;
  }

  // ---- AI 托管 ----
  private async initAiPanel(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
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
    if (this.isGameOver || this.isWin) {
      this.restartGame();
    }
    this.isPaused = false;
    this.aiFailCount = 0;
    this.aiRunning = true;
    this.aiStatus = 'AI 准备中…';
    this.aiLoop().catch((e: Object) => {
      this.stopAi();
    });
  }

  private stopAi(): void {
    this.aiRunning = false;
    this.aiLoopActive = false;
    this.aiStatus = '';
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
    }
  }

  private changeAiSpeed(index: number): void {
    if (this.aiRunning) return;
    this.aiSpeedIndex = index;
  }

  // AI 决策循环：每个动作执行后经展示窗口再进入下一轮
  private async aiLoop(): Promise<void> {
    if (!this.aiRunning || this.aiLoopActive) return;
    this.aiLoopActive = true;
    while (this.aiRunning) {
      if (this.isGameOver || this.isWin || this.isPaused) break;
      if (this.aiConfig === null) break;
      this.aiStatus = 'AI 思考中…';
      const stateText: string = GameAIService.serializeGrid2048(this.board);
      const messages = GameAIService.buildMessages('2048', this.difficulty, stateText);
      const result = await GameAIService.decide(this.aiConfig, messages);
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
      const action: GameAction | null = GameAIService.parseAction('2048', result.content);
      if (action === null) continue;
      this.aiStatus = 'AI 执行 ' + action.command;
      this.move(action.command.toLowerCase());
      if (this.isGameOver || this.isWin) break;
      if (this.aiSpeedIndex < AI_SPEED_DELAYS.length && AI_SPEED_DELAYS[this.aiSpeedIndex] > 0) {
        await new Promise<void>((resolve) => {
          setTimeout(() => { resolve(); }, AI_SPEED_DELAYS[this.aiSpeedIndex]);
        });
      }
      if (this.isGameOver || this.isWin) break;
    }
    this.aiLoopActive = false;
    if (this.aiRunning) {
      this.aiRunning = false;
      if (this.isGameOver || this.isWin) this.aiStatus = 'AI 结束：游戏已终局';
      else this.aiStatus = 'AI 已暂停';
    }
  }

  // ---- 棋盘渲染 ----
  @Builder
  gameBoard() {
    Column({ space: 8 }) {
      ForEach(this.board, (row: number[], rowIdx: number) => {
        Row({ space: 8 }) {
          ForEach(row, (cell: number, colIdx: number) => {
            Stack() {
              if (cell > 0) {
                Text(cell.toString())
                  .fontSize(tileStyle(cell, this.palette).fontSize)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(tileStyle(cell, this.palette).fg)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .borderRadius(8)
            .backgroundColor(tileStyle(cell, this.palette).bg)
            .alignContent(Alignment.Center)
          }, (colIdx: number) => colIdx.toString())
        }
        .layoutWeight(1)
      }, (rowIdx: number) => rowIdx.toString())
    }
    .width('100%')
    .aspectRatio(1)
    .padding(8)
    .backgroundColor(this.palette.bgSurface)
    .borderRadius(12)
    .border({ width: 1, color: this.palette.borderSubtle })
    .scale(this.mergeBoardScale())
    .animation({ duration: 180, curve: Curve.EaseOut })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 20 })
        .onActionEnd((event: GestureEvent) => {
          if (this.isGameOver || this.isWin) return;
          const ox: number = event.offsetX;
          const oy: number = event.offsetY;
          const absX: number = Math.abs(ox);
          const absY: number = Math.abs(oy);
          if (absX > absY) {
            if (ox > 0) this.move('right');
            else this.move('left');
          } else {
            if (oy > 0) this.move('down');
            else this.move('up');
          }
        })
    )
  }

  // ---- 信息面板 ----
  @Builder
  scoreBoard() {
    Row({ space: 12 }) {
      // 当前分数
      Column({ space: 2 }) {
        Text('分数')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.score.toString())
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(12)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(10)
      .border({ width: 1, color: this.palette.borderSubtle })

      // 最佳分数
      Column({ space: 2 }) {
        Text('最佳')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
        Text(this.bestScore.toString())
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.warning)
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(12)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(10)
      .border({ width: 1, color: this.palette.borderSubtle })
    }
    .width('100%')
  }

  // ---- 胜利弹窗 ----
  @Builder
  winOverlay() {
    Stack() {
      Column({ space: 16 }) {
        Text('🎉 恭喜！')
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
        Text('你达到了 2048！')
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
        Row({ space: 12 }) {
          Row()
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .backgroundColor(this.palette.bgSurface2)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.continueGame(); })
          Text('继续游戏')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .fontWeight(FontWeight.Medium)

          Row()
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .backgroundColor(this.palette.primary)
            .borderRadius(8)
            .onClick(() => { this.restartGame(); })
          Text('重新开始')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor('#0A0E1A')
            .fontWeight(FontWeight.Medium)
        }
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(10, 14, 26, 0.85)')
    .alignContent(Alignment.Center)
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
         router.pushUrl({ url: 'pages/GameHistory', params: new GameHistoryRouteParams('2048') });
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
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.GAME_2048);
    if (!result.success || result.request === null) {
      promptAction.showToast({ message: result.message });
      router.back();
      return;
    }
    this.loadBestScore();
    this.startWithDifficulty(result.request.difficulty);
    this.initAiPanel();
  }

  // ---- 页面隐藏时自动暂停 ----
  onPageHide(): void {
    this.stopAi();
    if (!this.isPaused && !this.isGameOver && this.gameStarted) {
      this.autoPaused = true;
      this.isPaused = true;
    }
  }

  // ---- 页面显示时恢复（仅自动暂停） ----
  onPageShow(): void {
    if (this.autoPaused) {
      this.autoPaused = false;
      this.isPaused = false;
      promptAction.showToast({ message: '已恢复游戏' });
    }
  }

  aboutToDisappear(): void {
    // 中途退出时保存当前分数
    this.stopAi();
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
            Text('📖 2048\n\n' +
              '【目标】\n滑动合并相同数字，最终合并出 2048 方块。\n\n' +
              '【操作】\n' +
              '• 方向键 / 滑动屏幕：向对应方向滑动，所有方块一起移动\n' +
              '• 相同数字的方块碰撞后合并为它们的和\n' +
              '• 每次移动后会在空白位置随机生成一个 2 或 4\n\n' +
              '【规则】\n' +
              '• 棋盘满格且无法继续合并时游戏结束\n' +
              '• 合并出 2048 方块即为胜利，可继续挑战更高分\n' +
              '• 不同难度影响初始方块数量和 4 的出现概率')
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
          subtitle: '合并数字，达到2048',
          showBack: true
        }) {
          this.actionsBuilder()
        }

        if (this.isSm) {
          // 手机端布局
          if (this.gameStarted) {
            Column({ space: 16 }) {
              this.scoreBoard()
              GameAIPanel({
                modelNames: this.aiModelNames,
                selectedModelIndex: this.aiModelIndex,
                running: this.aiRunning,
                status: this.aiStatus,
                speedIndex: this.aiSpeedIndex,
                modelsConfigured: this.aiModelsConfigured,
                onSelectModel: (index: number): void => { this.selectAiModel(index); },
                onToggleRun: (): void => { this.toggleAi(); },
                onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
              })
              Stack() {
                Column() {
                  this.gameBoard()
                }
                if (this.isWin) { this.winOverlay() }
                if (this.isGameOver) { this.gameOverOverlay() }
                if (this.isPaused) { this.pauseOverlay() }
              }
              .width(this.boardSide())
              .height(this.boardSide())
              .alignContent(Alignment.Center)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.Center)
          }
        } else {
          // 平板端布局
          if (this.gameStarted) {
            Row({ space: 20 }) {
              Column({ space: 16 }) {
                Stack() {
                  Column() {
                    this.gameBoard()
                  }
                  if (this.isWin) { this.winOverlay() }
                  if (this.isGameOver) { this.gameOverOverlay() }
                  if (this.isPaused) { this.pauseOverlay() }
                }
                .width(this.boardSide())
                .height(this.boardSide())
                .alignContent(Alignment.Center)
              }
              .alignItems(HorizontalAlign.Center)

            Column({ space: 16 }) {
              this.scoreBoard()
              GameAIPanel({
                modelNames: this.aiModelNames,
                selectedModelIndex: this.aiModelIndex,
                running: this.aiRunning,
                status: this.aiStatus,
                speedIndex: this.aiSpeedIndex,
                modelsConfigured: this.aiModelsConfigured,
                onSelectModel: (index: number): void => { this.selectAiModel(index); },
                onToggleRun: (): void => { this.toggleAi(); },
                onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
              })
              Column({ space: 8 }) {
                Text('操作提示')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                Column({ space: 6 }) {
                  Text('滑动屏幕即可操作')
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                  Text('相同数字会合并相加')
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                  Text('目标：达到 2048！')
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.primary)
                }
                .padding(16)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(10)
                .border({ width: 1, color: this.palette.borderSubtle })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
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
          this.move('left');
        } else if (code === KeyCode.KEYCODE_DPAD_RIGHT || code === KeyCode.KEYCODE_D) {
          this.move('right');
        } else if (code === KeyCode.KEYCODE_DPAD_UP || code === KeyCode.KEYCODE_W) {
          this.move('up');
        } else if (code === KeyCode.KEYCODE_DPAD_DOWN || code === KeyCode.KEYCODE_S) {
          this.move('down');
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

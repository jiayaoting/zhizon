// 智子 - 五子棋（人机对弈 + 本地引擎 + 大模型 AI 托管）
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchResult, GameRouteParams,
  difficultyLabel } from '../common/Difficulty';
import { AI_SPEED_DELAYS, GameAIService, GameAction } from '../service/GameAIService';
import { GomokuEngine, GOMOKU_SIZE } from '../service/GomokuEngine';
import { DataRepository } from '../service/DataRepository';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { GameAIPanel } from '../components/GameAIPanel';
import { LiveViewService } from '../service/LiveViewService';

// 落子记录（悔棋用）
class GomokuMove {
  r: number;
  c: number;
  player: number;

  constructor(r: number, c: number, player: number) {
    this.r = r;
    this.c = c;
    this.player = player;
  }
}

const HUMAN_PLAYER: number = 1; // 黑方（玩家 / LLM 托管）
const ENGINE_PLAYER: number = 2; // 白方（本地引擎）

@Component
@Entry
export struct GomokuPage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  // 路由参数
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State paramsValid: boolean = true;

  // 棋盘
  @State board: number[][] = [];
  @State boardVersion: number = 0;
  @State currentPlayer: number = HUMAN_PLAYER;
  @State gameOver: boolean = false;
  @State winnerText: string = '';
  @State lastR: number = -1;
  @State lastC: number = -1;
  @State engineThinking: boolean = false;

  // 悔棋
  private moveStack: GomokuMove[] = [];
  @State undoUsed: number = 0;
  private undoLimit: number = 3;

  // AI 托管（大模型替玩家执黑）
  @State aiRunning: boolean = false;
  @State aiStatus: string = '';
  @State aiModels: LlmModelEntry[] = [];
  @State aiModelIndex: number = 0;
  @State aiConfig: LlmConfig | null = null;
  @State aiModelsConfigured: boolean = false;
  @State aiSpeedIndex: number = 2;
  @State aiFailCount: number = 0;
  @State aiThinkCount: number = 0;
  @State aiThinkTimeMs: number = 0;
  @State aiThinkTotalMs: number = 0;
  private aiLoopActive: boolean = false;
  private aiThinkStart: number = 0;
  private aiThinkTimer: number = -1;

  // 计时
  private gameStartTime: number = 0;
  // 托管期间使用的模型名（结束时用于战绩记录）
  private aiHostedModelName: string = '';
  // 实况窗（AI 托管进度）
  private liveViewEvent: string = '';

  // 棋盘尺寸（随容器自适应）
  @State boardWidth: number = 360;
  private boardCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  aboutToAppear(): void {
    this.parseParams();
    this.newGame();
    this.loadAiModels();
  }

  aboutToDisappear(): void {
    this.aiRunning = false;
    this.aiLoopActive = false;
    this.stopThinkTimer();
    if (this.liveViewEvent.length > 0) {
      const event: string = this.liveViewEvent;
      this.liveViewEvent = '';
      LiveViewService.close(event);
    }
  }

  // ---- 路由参数解析 ----
  private parseParams(): void {
    const params: GameRouteParams | null = AppNavigator.getParam('pages/Gomoku') as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.GOMOKU);
    if (!result.success || result.request === null) {
      this.paramsValid = false;
      this.difficulty = DifficultyLevel.MEDIUM;
      return;
    }
    this.difficulty = result.request.difficulty;
  }

  // ---- 模型加载 ----
  private async loadAiModels(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    this.aiModelsConfigured = this.aiModels.length > 0;
    if (this.aiModelsConfigured) {
      const saved: string = await GameAIService.loadSavedModelId('');
      if (saved.length > 0) {
        for (let i: number = 0; i < this.aiModels.length; i++) {
          if (this.aiModels[i].id === saved) {
            this.aiModelIndex = i;
            break;
          }
        }
      }
      const entry: LlmModelEntry = this.aiModels[this.aiModelIndex];
      this.aiConfig = await GameAIService.loadConfig(entry.id);
    }
  }

  // ---- 对局控制 ----
  private newGame(): void {
    this.board = GomokuEngine.createBoard();
    this.boardVersion += 1;
    this.currentPlayer = HUMAN_PLAYER;
    this.gameOver = false;
    this.winnerText = '';
    this.lastR = -1;
    this.lastC = -1;
    this.moveStack = [];
    this.undoUsed = 0;
    this.engineThinking = false;
    this.gameStartTime = Date.now();
    this.aiStatus = '';
  }

  private restart(): void {
    if (this.aiRunning) {
      this.aiRunning = false;
      this.aiLoopActive = false;
    }
    this.newGame();
  }

  // 认输（仅轮到玩家且未结束时）
  private resign(): void {
    if (this.gameOver || this.aiRunning || this.engineThinking) return;
    if (this.currentPlayer !== HUMAN_PLAYER) return;
    this.finishGame('white');
  }

  // ---- 落子核心 ----
  private applyMove(r: number, c: number, player: number): void {
    if (!GomokuEngine.isValidMove(this.board, r, c)) return;
    GomokuEngine.place(this.board, r, c, player);
    this.moveStack.push(new GomokuMove(r, c, player));
    this.lastR = r;
    this.lastC = c;
    this.boardVersion += 1;
    if (GomokuEngine.checkWin(this.board, r, c, player)) {
      this.finishGame(player === HUMAN_PLAYER ? 'black' : 'white');
      return;
    }
    if (GomokuEngine.isBoardFull(this.board)) {
      this.finishGame('draw');
      return;
    }
    this.currentPlayer = player === HUMAN_PLAYER ? ENGINE_PLAYER : HUMAN_PLAYER;
  }

  // 玩家点击落子
  private onCellTap(r: number, c: number): void {
    if (this.gameOver || this.aiRunning || this.engineThinking) return;
    if (this.currentPlayer !== HUMAN_PLAYER) return;
    this.applyMove(r, c, HUMAN_PLAYER);
    if (!this.gameOver && this.currentPlayer === ENGINE_PLAYER) {
      this.engineMove();
    }
  }

  // 本地引擎执白
  private async engineMove(): Promise<void> {
    this.engineThinking = true;
    this.aiStatus = '';
    await GomokuPage.sleep(220);
    if (this.gameOver) {
      this.engineThinking = false;
      return;
    }
    const levelIndex: number = GomokuPage.levelIndexOf(this.difficulty);
    const move: number[] | null = GomokuEngine.findBestMove(this.board, ENGINE_PLAYER, levelIndex);
    this.engineThinking = false;
    if (move === null) {
      if (!this.gameOver && GomokuEngine.isBoardFull(this.board)) {
        this.finishGame('draw');
      }
      return;
    }
    this.applyMove(move[0], move[1], ENGINE_PLAYER);
  }

  // ---- 悔棋 ----
  private undo(): void {
    if (this.gameOver || this.aiRunning || this.engineThinking) return;
    if (this.currentPlayer !== HUMAN_PLAYER) return;
    if (this.undoUsed >= this.undoLimit) {
      promptAction.showToast({ message: '已达本局悔棋次数上限' });
      return;
    }
    if (this.moveStack.length === 0) return;
    // 最近一步是引擎（白）时回退两步（白+黑），否则回退一步
    let count: number = 1;
    const last: GomokuMove = this.moveStack[this.moveStack.length - 1];
    if (last.player === ENGINE_PLAYER) count = 2;
    if (this.moveStack.length < count) count = this.moveStack.length;
    for (let i: number = 0; i < count; i++) {
      const mv: GomokuMove = this.moveStack.pop() as GomokuMove;
      this.board[mv.r][mv.c] = 0;
    }
    this.undoUsed += 1;
    this.currentPlayer = HUMAN_PLAYER;
    this.boardVersion += 1;
    // 最近落子高亮
    if (this.moveStack.length > 0) {
      const prev: GomokuMove = this.moveStack[this.moveStack.length - 1];
      this.lastR = prev.r;
      this.lastC = prev.c;
    } else {
      this.lastR = -1;
      this.lastC = -1;
    }
  }

  // ---- 结束与战绩 ----
  private finishGame(winner: string): void {
    this.gameOver = true;
    this.aiRunning = false;
    this.aiLoopActive = false;
    this.engineThinking = false;
    this.aiStatus = '';
    if (this.liveViewEvent.length > 0) {
      const event: string = this.liveViewEvent;
      this.liveViewEvent = '';
      LiveViewService.update(event, '五子棋 AI 托管结束', 100);
      setTimeout(() => {
        LiveViewService.close(event);
      }, 1500);
    }
    if (winner === 'black') this.winnerText = '🎉 你赢了！';
    else if (winner === 'white') this.winnerText = '😔 引擎获胜';
    else this.winnerText = '🤝 平局';
    this.recordScore(winner);
  }

  private recordScore(winner: string): void {
    const playerWins: boolean = winner === 'black';
    const levelIndex: number = GomokuPage.levelIndexOf(this.difficulty);
    const diffLabel: string = difficultyLabel(this.difficulty);
    const duration: number = this.gameStartTime > 0 ?
      Math.max(0, Math.floor((Date.now() - this.gameStartTime) / 1000)) : 0;
    DataRepository.addGameScore('Gomoku', playerWins ? 1 : 0, levelIndex, diffLabel,
      this.aiHostedModelName, duration, Math.floor(this.aiThinkTotalMs / 1000));
  }

  private currentAiModelName(): string {
    if (this.aiModelIndex >= 0 && this.aiModelIndex < this.aiModels.length) {
      return GameAIService.modelLabel(this.aiModels[this.aiModelIndex]);
    }
    return '';
  }

  // ---- AI 托管（大模型执黑） ----
  private async toggleAi(): Promise<void> {
    if (this.aiRunning) {
      this.aiRunning = false;
      this.aiLoopActive = false;
      this.aiStatus = '';
      if (this.liveViewEvent.length > 0) {
        const event: string = this.liveViewEvent;
        this.liveViewEvent = '';
        LiveViewService.close(event);
      }
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
    if (this.gameOver) {
      this.newGame();
    }
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.aiThinkTimeMs = 0;
    this.aiThinkTotalMs = 0;
    this.aiRunning = true;
    this.aiStatus = 'AI 准备中…';
    this.aiHostedModelName = this.currentAiModelName();
    this.aiLoopActive = true;
    // 实况窗：后台可见托管进度
    this.liveViewEvent = LiveViewService.nextEvent('gomoku');
    LiveViewService.publish(this.liveViewEvent, '🤖 五子棋 AI 托管中', 0);
    this.aiLoop().catch((e: Object) => {
      this.aiRunning = false;
      this.aiLoopActive = false;
      this.aiStatus = '';
      if (this.liveViewEvent.length > 0) {
        const event: string = this.liveViewEvent;
        this.liveViewEvent = '';
        LiveViewService.close(event);
      }
    });
  }

  private async aiLoop(): Promise<void> {
    while (this.aiRunning && !this.gameOver && this.aiLoopActive) {
      if (this.currentPlayer === HUMAN_PLAYER) {
        if (this.aiConfig === null) break;
        const moves: number[][] = GomokuEngine.candidateMoves(this.board, 30);
        if (moves.length === 0) {
          if (!this.gameOver) this.finishGame('draw');
          break;
        }
        this.aiStatus = 'AI 思考中…';
        this.startThinkTimer();
        const messages = GameAIService.buildMessages('Gomoku', this.difficulty,
          GameAIService.serializeGomoku(this.board, moves));
        const result = await GameAIService.decide(this.aiConfig, messages, 'Gomoku', 30000);
        this.stopThinkTimer();
        this.aiThinkCount += 1;
        if (!result.success) {
          this.aiFailCount += 1;
          this.aiStatus = 'AI 请求失败，稍后重试';
          if (this.aiFailCount >= 3) {
            this.aiRunning = false;
            this.aiLoopActive = false;
            promptAction.showToast({ message: 'AI 连续失败，已停止托管' });
            break;
          }
          await GomokuPage.sleep(1200);
          continue;
        }
        const action: GameAction | null = GameAIService.parseAction('Gomoku', result.content);
        if (action === null) {
          this.aiFailCount += 1;
          this.aiStatus = 'AI 返回无效动作';
          await GomokuPage.sleep(800);
          continue;
        }
        let target: number[] | null = null;
        if (action.command === 'MOVE_IDX' && action.c >= 0 && action.c < moves.length) {
          target = moves[action.c];
        } else if (action.command === 'MOVE') {
          for (let i: number = 0; i < moves.length; i++) {
            if (moves[i][0] === action.r && moves[i][1] === action.c) {
              target = moves[i];
              break;
            }
          }
        }
        if (target === null) {
          this.aiFailCount += 1;
          this.aiStatus = 'AI 落子不合法';
          await GomokuPage.sleep(800);
          continue;
        }
        this.applyMove(target[0], target[1], HUMAN_PLAYER);
        this.aiStatus = '已落子';
        if (this.liveViewEvent.length > 0) {
          LiveViewService.update(this.liveViewEvent, '🤖 五子棋 AI 托管中',
            Math.min(90, this.aiThinkCount * 3));
        }
        if (this.gameOver) break;
      }
      // 引擎响应后短暂停顿再进入下一轮
      await GomokuPage.sleep(AI_SPEED_DELAYS[this.aiSpeedIndex]);
    }
  }

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
      this.aiThinkTotalMs += Math.max(0, Date.now() - this.aiThinkStart);
    }
  }

  private selectAiModel(index: number): void {
    this.aiModelIndex = index;
    if (index >= 0 && index < this.aiModels.length) {
      const entry: LlmModelEntry = this.aiModels[index];
      GameAIService.loadConfig(entry.id).then((config: LlmConfig | null) => {
        this.aiConfig = config;
      });
      GameAIService.saveModelId('', entry.id);
    }
  }

  // ---- 工具 ----
  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  private static levelIndexOf(level: DifficultyLevel): number {
    if (level === DifficultyLevel.VERY_EASY) return 0;
    if (level === DifficultyLevel.EASY) return 1;
    if (level === DifficultyLevel.HARD) return 3;
    if (level === DifficultyLevel.HELL) return 4;
    return 2;
  }

  private cellSize(): number {
    return this.boardWidth / GOMOKU_SIZE;
  }

  // ---- 棋盘绘制 ----
  private drawBoard(): void {
    const ctx: CanvasRenderingContext2D = this.boardCtx;
    const size: number = this.boardWidth;
    const cell: number = this.cellSize();
    ctx.clearRect(0, 0, size, size);
    // 木色底
    ctx.fillStyle = '#E8C889';
    ctx.fillRect(0, 0, size, size);
    // 网格线
    ctx.strokeStyle = '#6B4A1F';
    ctx.lineWidth = 1;
    for (let i: number = 0; i < GOMOKU_SIZE; i++) {
      const pos: number = Math.round(cell / 2 + i * cell);
      ctx.beginPath();
      ctx.moveTo(cell / 2, pos);
      ctx.lineTo(size - cell / 2, pos);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(pos, cell / 2);
      ctx.lineTo(pos, size - cell / 2);
      ctx.stroke();
    }
    // 星位（天元 + 四角星）
    const stars: number[][] = [[3, 3], [3, 11], [11, 3], [11, 11], [7, 7]];
    ctx.fillStyle = '#4A3315';
    for (let i: number = 0; i < stars.length; i++) {
      const px: number = cell / 2 + stars[i][0] * cell;
      const py: number = cell / 2 + stars[i][1] * cell;
      ctx.beginPath();
      ctx.arc(px, py, Math.max(2.5, cell * 0.09), 0, Math.PI * 2);
      ctx.fill();
    }
  }

  @Builder
  statusBar() {
    Row({ space: 10 }) {
      if (this.gameOver) {
        Text(this.winnerText)
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      } else if (this.aiRunning && this.aiStatus.length > 0) {
        Text('🤖 ' + this.aiStatus)
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .layoutWeight(1)
      } else if (this.engineThinking) {
        Text('🤔 引擎思考中…')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .layoutWeight(1)
      } else {
        Text(this.currentPlayer === HUMAN_PLAYER ? '⚫ 轮到你了（黑）' : '⚪ 引擎思考中（白）')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.currentPlayer === HUMAN_PLAYER ? this.palette.textPrimary : this.palette.textSecondary)
          .layoutWeight(1)
      }
      Text('难度：' + difficultyLabel(this.difficulty))
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  @Builder
  boardArea() {
    Stack() {
      // 网格底图
      Canvas(this.boardCtx)
        .width(this.boardWidth)
        .height(this.boardWidth)
        .onReady(() => { this.drawBoard(); })
        .borderRadius(10)
        .clip(true)
      // 棋子层：key 含 boardVersion 强制重建
      Column() {
        ForEach(this.board, (row: number[], r: number) => {
          Row() {
            ForEach(row, (_: number, c: number) => {
              this.stoneCell(r, c)
            }, (_: number, c: number) => r.toString() + '_' + c.toString())
          }
          .width('100%')
          .height(this.cellSize())
        }, (row: number[], r: number) => r.toString() + '_v' + this.boardVersion.toString())
      }
      .width(this.boardWidth)
      .height(this.boardWidth)
    }
    .width(this.boardWidth)
    .height(this.boardWidth)
    .shadow({ radius: 18, color: '#40000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  stoneCell(r: number, c: number) {
    Stack() {
      // 最近落子高亮
      if (this.lastR === r && this.lastC === c) {
        Circle()
          .width('100%')
          .height('100%')
          .fill(Color.Transparent)
          .stroke('#FFD700')
          .strokeWidth(2)
      }
      if (this.board[r][c] === HUMAN_PLAYER) {
        Circle()
          .width('86%')
          .height('86%')
          .fill('#1A1A1A')
          .shadow({ radius: 4, color: '#59000000', offsetX: 1, offsetY: 2 })
      } else if (this.board[r][c] === ENGINE_PLAYER) {
        Circle()
          .width('86%')
          .height('86%')
          .fill('#F5F5F5')
          .stroke('#999999')
          .strokeWidth(1)
          .shadow({ radius: 4, color: '#59000000', offsetX: 1, offsetY: 2 })
      }
    }
    .width(this.cellSize())
    .height(this.cellSize())
    .onClick(() => { this.onCellTap(r, c); })
  }

  @Builder
  controlPanel() {
    Column({ space: 8 }) {
      // 操作按钮行
      Row({ space: 8 }) {
        Button('↩ 悔棋 (' + (this.undoLimit - this.undoUsed).toString() + ')')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.palette.bgSurface)
          .fontColor(this.palette.textPrimary)
          .borderRadius(8)
          .enabled(!this.gameOver && !this.aiRunning && !this.engineThinking)
          .onClick(() => { this.undo(); })
        Button('🔄 重新开始')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.palette.bgSurface)
          .fontColor(this.palette.textPrimary)
          .borderRadius(8)
          .onClick(() => { this.restart(); })
        Button('🏳️ 认输')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.palette.bgSurface)
          .fontColor(this.palette.textPrimary)
          .borderRadius(8)
          .enabled(!this.gameOver && !this.aiRunning && !this.engineThinking)
          .onClick(() => { this.resign(); })
      }
      .width('100%')

      // AI 托管面板
      GameAIPanel({
        modelNames: this.aiModels.map((m: LlmModelEntry): string => GameAIService.modelLabel(m)),
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
        onSpeedChange: (index: number): void => { this.aiSpeedIndex = index; }
      })
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '五子棋', subtitle: '人机对弈 · ' + difficultyLabel(this.difficulty) })
        if (!this.paramsValid) {
          Column({ space: 12 }) {
            Text('⚠️ 启动参数无效')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.warning)
            Button('返回游戏中心')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .backgroundColor(this.palette.primary)
              .onClick(() => { AppNavigator.pop(); })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              this.statusBar()
              this.boardArea()
              this.controlPanel()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({
              left: this.isSm ? 10 : 24,
              right: this.isSm ? 10 : 24,
              top: 10,
              bottom: 16
            })
            .onAreaChange((_: Area, newValue: Area) => {
              const pad: number = this.isSm ? 20 : 48;
              const w: number = Math.floor(Number(newValue.width) - pad);
              const target: number = Math.min(Math.max(w, 270), 430);
              if (target > 0 && Math.abs(target - this.boardWidth) > 1) {
                this.boardWidth = target;
                this.drawBoard();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.palette.bgBase)
    }
    .width('100%')
    .height('100%')
  }
}

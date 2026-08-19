// 智子 - 五子棋（人机 / 人对AI / AI对AI，模型可分别选择）
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchResult, GameRouteParams, difficultyLabel } from '../common/Difficulty';
import {
  AI_SPEED_DELAYS, AI_SPEED_OPTIONS, GOMOKU_KIND_AI, GOMOKU_KIND_BLACK, GOMOKU_KIND_WHITE,
  GameAIService, GameAction
} from '../service/GameAIService';
import { GomokuEngine, GOMOKU_SIZE } from '../service/GomokuEngine';
import { DataRepository } from '../service/DataRepository';
import { GameHistoryRouteParams } from '../common/Navigation';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { ScreenKeepAlive } from '../common/ScreenKeepAlive';
import { ReplayService, ReplayRecorder, ReplayEvent, ReplayRecord } from '../service/ReplayService';
import { SoundService } from '../service/SoundService';

// 对弈方类型
type PlayerMode = 'human' | 'engine' | 'llm';
// 对局模式
type MatchMode = 'hvE' | 'hvL' | 'LvL';
// 模型弹窗目标侧别
type ModelSide = 'black' | 'white' | 'ai';

// 悔棋快照
class GomokuSnapshot {
  board: number[][];
  currentPlayer: number;

  constructor(board: number[][], currentPlayer: number) {
    this.board = board;
    this.currentPlayer = currentPlayer;
  }
}

const BLACK_PLAYER: number = 1; // 黑方（先手）
const WHITE_PLAYER: number = 2; // 白方（后手）

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
  @State currentPlayer: number = BLACK_PLAYER;
  @State gameOver: boolean = false;
  @State winner: string = ''; // 'black' | 'white' | 'draw' | ''
  @State lastR: number = -1;
  @State lastC: number = -1;

  // 对弈配置与进行
  @State matchMode: MatchMode = 'hvE';
  @State humanSide: string = 'black';
  @State blackPlayer: string = 'human';
  @State whitePlayer: string = 'engine';
  @State undoLimit: number = 3;
  @State undoUsed: number = 0;
  @State running: boolean = false;
  @State thinkingSide: string = ''; // 'black' | 'white' | ''
  @State thinkingText: string = '';
  @State moveHistory: string[] = [];
  @State setupOpen: boolean = true;
  private gameStarted: boolean = false;

  // 模型
  @State aiModelNames: string[] = [];
  @State modelsConfigured: boolean = false;
  @State showModelPicker: boolean = false;
  private pickSide: ModelSide = 'ai';
  private aiModels: LlmModelEntry[] = [];
  @State blackModelIndex: number = 0;
  @State whiteModelIndex: number = 0;
  @State aiModelIndex: number = 0;
  private blackConfig: LlmConfig | null = null;
  private whiteConfig: LlmConfig | null = null;
  private aiConfig: LlmConfig | null = null;
  private aiLoopActive: boolean = false;
  private aiFailCount: number = 0;
  @State aiThinkCount: number = 0;
  private moveStack: GomokuSnapshot[] = [];

  // 本局开始时间（战绩时长统计）
  private gameStartTime: number = 0;

  // ---- 对局回放 ----
  @State replayMode: boolean = false;
  @State replaySpeed: number = 1;
  private recorder: ReplayRecorder = new ReplayRecorder();
  private replayEvents: ReplayEvent[] = [];
  private replayIndex: number = 0;
  private replayElapsed: number = 0;
  private replayTimer: number = -1;
  private replayApplying: boolean = false;

  // AI vs AI 对弈节奏：0慢 1中 2快 3极速
  @State aiSpeedIndex: number = 1;
  // 落子停顿 timer（AI vs AI 每步展示停顿），统一清理避免泄漏
  private stepDelayTimer: number = -1;

  // 引擎难度：0简单 1中等 2困难
  @State engineDiffIndex: number = 1;

  // AI 落子提示（轮到人时点击按钮生成建议）
  @State suggestionOn: boolean = false;
  @State suggestR: number = -1;
  @State suggestC: number = -1;
  private suggestSeq: number = 0;

  // AI 思考等待计时（每秒刷新 thinkingText，避免界面长时间无变化）
  private thinkTimer: number = -1;
  private thinkStart: number = 0;
  // AI 思考累计总时长（毫秒，本局内累积）
  private aiThinkTotalMs: number = 0;

  // 棋盘尺寸（随容器自适应）
  @State boardWidth: number = 360;
  private boardCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  // ---- 启动/初始化 ----
  async aboutToAppear(): Promise<void> {
    this.parseParams();
    const params: GameRouteParams | null = AppNavigator.getParam('pages/Gomoku') as GameRouteParams | null;
    if (params !== null && params !== undefined && params.replayId.length > 0) {
      const record: ReplayRecord | null = await ReplayService.get(params.replayId);
      if (record !== null) {
        this.startReplay(record);
        return;
      }
    }
    this.initAiModels();
    this.resetBoard();
    ScreenKeepAlive.enable(getContext(this));
  }

  aboutToDisappear(): void {
    this.stopReplayTimer();
    ScreenKeepAlive.disable(getContext(this));
  }

  onPageHide(): void {
    this.running = false;
    this.aiLoopActive = false;
    this.stopThinkTimer();
    this.stopStepDelay();
  }

  // 回到前台：若用户没有主动结束且当前没有任何活动AI思考，
  // 把 running 重置为 true 并调度下一步。这样后台返回后 AI 对局不会卡住。
  onPageShow(): void {
    if (this.gameOver || this.winner.length > 0) return;
    if (this.setupOpen) return;           // 设置弹窗打开时不算暂停
    if (this.aiLoopActive) return;        // 让 thinkFor 走完即可
    if (this.thinkingSide !== '') return; // 还有思考方未走完
    // 仅当对局已由用户「开始对局」启动后才恢复暂停的调度；防止页面首次显示就提前启动 AI
    if (this.gameStarted && !this.running) {
      this.running = true;
      this.scheduleNext();
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
  private async initAiModels(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    const names: string[] = [];
    for (let i: number = 0; i < this.aiModels.length; i++) {
      names.push(GameAIService.modelLabel(this.aiModels[i]));
    }
    this.aiModelNames = names;
    this.modelsConfigured = this.aiModels.length > 0;
    // 恢复记忆的模型（黑方 / 白方 / AI 方三侧分别独立记忆）
    const blackId: string = await GameAIService.loadSavedModelId(GOMOKU_KIND_BLACK);
    const whiteId: string = await GameAIService.loadSavedModelId(GOMOKU_KIND_WHITE);
    const aiId: string = await GameAIService.loadSavedModelId(GOMOKU_KIND_AI);
    for (let i: number = 0; i < this.aiModels.length; i++) {
      if (this.aiModels[i].id === blackId) this.blackModelIndex = i;
      if (this.aiModels[i].id === whiteId) this.whiteModelIndex = i;
      if (this.aiModels[i].id === aiId) this.aiModelIndex = i;
    }
  }

  private async loadModelConfig(index: number): Promise<LlmConfig | null> {
    if (!this.modelsConfigured || index < 0 || index >= this.aiModels.length) return null;
    return await GameAIService.loadConfig(this.aiModels[index].id);
  }

  // ---- 对弈工具 ----
  private modeLabel(mode: MatchMode): string {
    if (mode === 'hvE') return '人机';
    if (mode === 'hvL') return '人对AI';
    return 'AI对AI';
  }

  // 某方类型
  private playerType(side: string): PlayerMode {
    if (this.matchMode === 'LvL') return 'llm';
    if (this.matchMode === 'hvE') {
      return side === this.humanSide ? 'human' : 'engine';
    }
    // hvL
    return side === this.humanSide ? 'human' : 'llm';
  }

  // 当前回合方
  private currentSide(): string {
    return this.currentPlayer === BLACK_PLAYER ? 'black' : 'white';
  }

  private sideLabel(side: string): string {
    return side === 'black' ? '黑方' : '白方';
  }

  // 引擎难度索引（0..4，供 GomokuEngine.findBestMove 使用）
  private engineLevelIndex(): number {
    if (this.engineDiffIndex === 0) return 1; // 简单
    if (this.engineDiffIndex === 2) return 3; // 困难
    return 2; // 中等
  }

  // ---- 对局回放 ----
  private startReplay(record: ReplayRecord): void {
    this.replayMode = true;
    this.stopReplayTimer();
    this.resetBoard();
    this.setupOpen = false;
    this.running = true;
    this.gameStarted = true;
    this.gameStartTime = 0;
    this.replayEvents = ReplayService.parseEvents(record.eventsJson);
    this.replayIndex = 0;
    this.replayElapsed = 0;
    this.replaySpeed = 1;
    this.startReplayTimer();
  }

  private startReplayTimer(): void {
    this.stopReplayTimer();
    this.replayTimer = setInterval(() => { this.replayTick(); }, 120);
  }

  private stopReplayTimer(): void {
    if (this.replayTimer !== -1) {
      clearInterval(this.replayTimer);
      this.replayTimer = -1;
    }
  }

  private replayTick(): void {
    this.replayElapsed += 120 * this.replaySpeed;
    let guard: number = 0;
    while (this.replayIndex < this.replayEvents.length &&
      this.replayEvents[this.replayIndex].t <= this.replayElapsed && guard < 60 && !this.gameOver) {
      const ev: ReplayEvent = this.replayEvents[this.replayIndex];
      if (ev.type === 'move') {
        const parts: string[] = ev.data.split(',');
        if (parts.length === 3) {
          this.replayApplying = true;
          this.applyMove(Number(parts[0]), Number(parts[1]), Number(parts[2]));
          this.replayApplying = false;
        }
      }
      this.replayIndex += 1;
      guard += 1;
    }
    if (this.gameOver || this.replayIndex >= this.replayEvents.length) {
      this.stopReplayTimer();
    }
  }

  private exitReplay(): void {
    this.stopReplayTimer();
    this.replayMode = false;
    AppNavigator.pop();
  }

  private cycleReplaySpeed(): void {
    if (this.replaySpeed === 1) this.replaySpeed = 2;
    else if (this.replaySpeed === 2) this.replaySpeed = 4;
    else this.replaySpeed = 1;
  }

  // ---- 对局控制 ----
  private resetBoard(): void {
    this.board = GomokuEngine.createBoard();
    this.boardVersion += 1;
    this.currentPlayer = BLACK_PLAYER;
    this.gameOver = false;
    this.winner = '';
    this.lastR = -1;
    this.lastC = -1;
    this.moveStack = [];
    this.undoUsed = 0;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.suggestionOn = false;
    this.suggestR = -1;
    this.suggestC = -1;
    this.stopThinkTimer();
    this.aiThinkTotalMs = 0;
    this.stopStepDelay();
  }

  // ---- 开始对局 ----
  private async startGame(): Promise<void> {
    this.replayMode = false;
    this.stopReplayTimer();
    this.recorder.start();
    if (this.matchMode === 'hvL' || this.matchMode === 'LvL') {
      if (!this.modelsConfigured) {
        promptAction.showToast({ message: '请先在 AI 对话中配置可用模型' });
        return;
      }
    }
    this.blackPlayer = this.playerType('black');
    this.whitePlayer = this.playerType('white');
    this.resetBoard();
    this.gameStartTime = Date.now();
    if (this.matchMode === 'hvL') {
      this.aiConfig = await this.loadModelConfig(this.aiModelIndex);
    } else if (this.matchMode === 'LvL') {
      this.blackConfig = await this.loadModelConfig(this.blackModelIndex);
      this.whiteConfig = await this.loadModelConfig(this.whiteModelIndex);
    }
    this.setupOpen = false;
    this.running = true;
    this.aiLoopActive = false;
    this.aiFailCount = 0;
    this.gameStarted = true;
    this.scheduleNext();
  }

  private stopGame(): void {
    this.running = false;
    this.aiLoopActive = false;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.suggestionOn = false;
    this.stopThinkTimer();
    this.stopStepDelay();
  }

  // ---- AI 思考等待计时 ----
  private startThinkTimer(prefix: string, extra: string): void {
    this.stopThinkTimer();
    this.thinkStart = Date.now();
    this.thinkTimer = setInterval(() => {
      const elapsed: number = Math.floor((Date.now() - this.thinkStart) / 1000);
      this.thinkingText = prefix + '… 已等待 ' + elapsed.toString() + 's' + extra;
    }, 1000);
  }

  private stopThinkTimer(): void {
    if (this.thinkTimer >= 0) {
      clearInterval(this.thinkTimer);
      this.thinkTimer = -1;
      this.aiThinkTotalMs += Math.max(0, Date.now() - this.thinkStart);
    }
  }

  // 清理 AI vs AI 落子停顿 timer
  private stopStepDelay(): void {
    if (this.stepDelayTimer >= 0) {
      clearTimeout(this.stepDelayTimer);
      this.stepDelayTimer = -1;
    }
  }

  // ---- 对弈调度 ----
  private scheduleNext(): void {
    if (this.replayMode) return;
    if (!this.running || this.gameOver) return;
    const side: string = this.currentSide();
    const type: PlayerMode = this.playerType(side);
    if (type === 'human') {
      this.thinkingSide = '';
      this.thinkingText = '';
      return;
    }
    this.thinkFor(side).catch((e: Object) => {
      console.error('[Gomoku] thinkFor 异常: ' + e);
      this.stopGame();
    });
  }

  // AI 落子后的节奏控制：若下一方仍为 LLM 且设定速度>0，则按档位停顿后再调度
  private scheduleNextWithStepDelay(): void {
    if (!this.running || this.gameOver) return;
    const nextSide: string = this.currentSide();
    const nextType: PlayerMode = this.playerType(nextSide);
    if (nextType !== 'llm' || this.aiSpeedIndex >= AI_SPEED_DELAYS.length ||
      AI_SPEED_DELAYS[this.aiSpeedIndex] <= 0) {
      this.scheduleNext();
      return;
    }
    const delay: number = AI_SPEED_DELAYS[this.aiSpeedIndex];
    this.thinkingSide = '';
    this.thinkingText = '下一回合 ' + this.sideLabel(nextSide) + '…';
    this.stopStepDelay();
    this.stepDelayTimer = setTimeout(() => {
      this.stepDelayTimer = -1;
      this.scheduleNext();
    }, delay);
  }

  // AI 决策（本地引擎 / LLM）
  private async thinkFor(side: string): Promise<void> {
    if (this.aiLoopActive) return;
    this.aiLoopActive = true;
    const type: PlayerMode = this.playerType(side);
    this.thinkingSide = side;
    this.thinkingText = (this.sideLabel(side) + '思考中…') +
      (type === 'engine' ? '（本地引擎）' : '（' + this.aiModelLabel(side) + '）');
    const me: number = side === 'black' ? BLACK_PLAYER : WHITE_PLAYER;
    let move: number[] | null = null;
    if (type === 'engine') {
      // 本地引擎：深拷贝棋盘，避免搜索修改 @State
      try {
        const snapshot: number[][] = GomokuEngine.cloneBoard(this.board);
        move = GomokuEngine.findBestMove(snapshot, me, this.engineLevelIndex());
      } catch (e) {
        console.error('[Gomoku] 本地引擎异常: ' + e);
        this.aiLoopActive = false;
        this.thinkingSide = '';
        this.thinkingText = '';
        return;
      }
    } else {
      const config: LlmConfig | null = this.llmConfigFor(side);
      if (config === null) {
        this.stopGame();
        promptAction.showToast({ message: '模型配置无效' });
        this.aiLoopActive = false;
        return;
      }
      this.aiFailCount = 0;
      this.aiThinkCount += 1;
      const MAX_LLM_RETRY: number = 1;
      let requestFailures: number = 0;
      // 事先生成当前方所有可选落子，供 prompt 给 LLM 选，模型只能选索引
      const moves: number[][] = GomokuEngine.candidateMoves(this.board, 30);
      for (let attempt: number = 0; attempt < MAX_LLM_RETRY; attempt++) {
        const stateText: string = GameAIService.serializeGomoku(this.board, moves, side);
        const messages = GameAIService.buildGomokuMessages(side, this.difficulty, stateText);
        if (attempt === 0) {
          this.startThinkTimer(this.sideLabel(side) + '思考中', '（' + this.aiModelLabel(side) + '）');
        } else {
          this.startThinkTimer(this.sideLabel(side) + '重新计算', '（第' + (attempt + 1).toString() + '次）');
        }
        const result = await GameAIService.decide(config, messages, 'Gomoku', 30000);
        this.stopThinkTimer();
        if (!this.running || this.gameOver) {
          this.aiLoopActive = false;
          this.thinkingSide = '';
          this.thinkingText = '';
          return;
        }
        if (!result.success) {
          requestFailures += 1;
          promptAction.showToast({ message: this.sideLabel(side) + '模型请求失败：' + result.errorMessage });
          // 请求失败达上限，用本地引擎兜底，保证对局能推进
          if (requestFailures >= MAX_LLM_RETRY) break;
          continue;
        }
        requestFailures = 0;
        const action: GameAction | null = GameAIService.parseAction('Gomoku', result.content);
        let target: number[] | null = null;
        // 序号模式：MOVE_IDX，走 moves[idx]
        if (action !== null && action.command === 'MOVE_IDX' && action.c >= 0 && action.c < moves.length) {
          target = moves[action.c];
        } else if (action !== null && action.command === 'MOVE') {
          // 兜底：旧坐标模式
          for (let i: number = 0; i < moves.length; i++) {
            if (moves[i][0] === action.r && moves[i][1] === action.c) {
              target = moves[i];
              break;
            }
          }
        }
        if (target === null || !GomokuEngine.isValidMove(this.board, target[0], target[1])) {
          // 落子非法：记录并展示模型实际回复的简短预览，便于排查
          const rawPreview: string = result.content.length > 40 ?
            result.content.substring(0, 40) + '…' : result.content;
          console.info('[Gomoku] ' + side + ' LLM 返回非法落子，重试中。原始回复=' + rawPreview);
          if (attempt === MAX_LLM_RETRY - 1) {
            promptAction.showToast({
              message: this.sideLabel(side) + 'AI 输出无法解析："' + rawPreview + '"'
            });
          }
          continue;
        }
        move = target;
        break;
      }
      // LLM 反复非法或请求失败：用本地引擎兜底，保证一定落子
      if (move === null) {
        this.thinkingText = this.sideLabel(side) + '思考中…（本地引擎兜底）';
        try {
          const snapshot: number[][] = GomokuEngine.cloneBoard(this.board);
          move = GomokuEngine.findBestMove(snapshot, me, this.engineLevelIndex());
        } catch (e) {
          console.error('[Gomoku] 本地引擎兜底异常: ' + e);
          move = null;
        }
        this.thinkingSide = '';
        this.thinkingText = '';
      }
    }
    this.aiLoopActive = false;
    if (!this.running || this.gameOver) return;
    if (move === null) {
      if (!this.gameOver && GomokuEngine.isBoardFull(this.board)) {
        this.finishGame('draw');
      }
      return;
    }
    this.thinkingSide = '';
    this.thinkingText = '';
    this.applyMove(move[0], move[1], me);
  }

  // ---- 落子核心 ----
  private applyMove(r: number, c: number, player: number): void {
    if (!GomokuEngine.isValidMove(this.board, r, c)) return;
    if (!this.replayMode) this.recorder.record('move', r.toString() + ',' + c.toString() + ',' + player.toString());
    // 保存悔棋快照
    this.moveStack.push(new GomokuSnapshot(GomokuEngine.cloneBoard(this.board), this.currentPlayer));
    GomokuEngine.place(this.board, r, c, player);
    this.lastR = r;
    this.lastC = c;
    this.suggestionOn = false;
    this.suggestR = -1;
    this.suggestC = -1;
    const sideName: string = player === BLACK_PLAYER ? '黑方' : '白方';
    this.moveHistory = this.moveHistory.concat(sideName + ' (' + r.toString() + ',' + c.toString() + ')');
    this.boardVersion += 1;
    if (GomokuEngine.checkWin(this.board, r, c, player)) {
      this.finishGame(player === BLACK_PLAYER ? 'black' : 'white');
      return;
    }
    if (GomokuEngine.isBoardFull(this.board)) {
      this.finishGame('draw');
      return;
    }
    this.currentPlayer = player === BLACK_PLAYER ? WHITE_PLAYER : BLACK_PLAYER;
    this.scheduleNextWithStepDelay();
  }

  // 玩家点击落子
  private onCellTap(r: number, c: number): void {
    if (this.replayMode) return;
    if (!this.running || this.gameOver) return;
    if (this.thinkingSide !== '') return; // AI 思考中锁定
    if (this.playerType(this.currentSide()) !== 'human') return;
    this.applyMove(r, c, this.currentPlayer);
  }

  // ---- 悔棋 ----
  private undo(): void {
    if (this.replayMode) return;
    if (!this.running && !this.gameOver) return;
    if (this.thinkingSide !== '') return;
    if (this.matchMode === 'LvL') {
      promptAction.showToast({ message: 'AI 对 AI 模式不支持悔棋' });
      return;
    }
    if (this.undoLimit > 0 && this.undoUsed >= this.undoLimit) {
      promptAction.showToast({ message: '已达本局悔棋次数上限' });
      return;
    }
    if (this.moveStack.length === 0) {
      promptAction.showToast({ message: '没有可悔的棋步' });
      return;
    }
    const snap: GomokuSnapshot = this.moveStack.pop() as GomokuSnapshot;
    // 悔棋回退到"当前方走这一步之前"的局面（即回退一整步）
    this.board = snap.board;
    this.currentPlayer = snap.currentPlayer;
    this.undoUsed += 1;
    this.boardVersion += 1;
    this.suggestionOn = false;
    this.suggestR = -1;
    this.suggestC = -1;
    this.lastR = -1;
    this.lastC = -1;
    this.gameOver = false;
    this.winner = '';
    this.thinkingSide = '';
    this.thinkingText = '';
    // 回退记谱
    if (this.moveHistory.length > 0) {
      this.moveHistory = this.moveHistory.slice(0, this.moveHistory.length - 1);
    }
    this.scheduleNextWithStepDelay();
  }

  // ---- AI 落子提示（轮到人时点击按钮）----
  private async suggestMove(): Promise<void> {
    if (!this.running || this.gameOver) return;
    if (this.thinkingSide !== '') return;
    if (this.playerType(this.currentSide()) !== 'human') return;
    if (this.matchMode === 'LvL') return;
    const side: string = this.currentSide();
    const type: PlayerMode = this.matchMode === 'hvE' ? 'engine' : 'llm';
    const me: number = side === 'black' ? BLACK_PLAYER : WHITE_PLAYER;
    this.thinkingSide = side;
    this.thinkingText = 'AI 建议中…';
    this.suggestSeq += 1;
    const seq: number = this.suggestSeq;
    let move: number[] | null = null;
    if (type === 'engine') {
      const snapshot: number[][] = GomokuEngine.cloneBoard(this.board);
      move = GomokuEngine.findBestMove(snapshot, me, this.engineLevelIndex());
    } else {
      const config: LlmConfig | null = this.llmConfigFor(side);
      if (config !== null) {
        const moves: number[][] = GomokuEngine.candidateMoves(this.board, 30);
        const stateText: string = GameAIService.serializeGomoku(this.board, moves, side);
        const messages = GameAIService.buildGomokuMessages(side, this.difficulty, stateText);
        this.startThinkTimer('AI 建议', '');
        const result = await GameAIService.decide(config, messages, 'Gomoku', 30000);
        this.stopThinkTimer();
        if (seq !== this.suggestSeq) return;
        if (result.success) {
          const action: GameAction | null = GameAIService.parseAction('Gomoku', result.content);
          if (action !== null && action.command === 'MOVE_IDX' && action.c >= 0 && action.c < moves.length) {
            move = moves[action.c];
          } else if (action !== null && action.command === 'MOVE') {
            for (let i: number = 0; i < moves.length; i++) {
              if (moves[i][0] === action.r && moves[i][1] === action.c) {
                move = moves[i];
                break;
              }
            }
          }
        } else {
          promptAction.showToast({ message: 'AI 建议失败：' + result.errorMessage });
        }
      }
    }
    if (seq !== this.suggestSeq) return;
    this.thinkingSide = '';
    this.thinkingText = '';
    if (move === null) {
      promptAction.showToast({ message: '未能生成建议落子' });
      return;
    }
    this.suggestR = move[0];
    this.suggestC = move[1];
    this.suggestionOn = true;
  }

  // 确认执行 AI 建议
  private applySuggestion(): void {
    if (!this.suggestionOn) return;
    this.applyMove(this.suggestR, this.suggestC, this.currentPlayer);
  }

  // ---- 结束与战绩 ----
  private finishGame(winner: string): void {
    if (this.replayMode) {
      this.gameOver = true;
      this.running = false;
      this.winner = winner;
      this.stopReplayTimer();
      return;
    }
    this.gameOver = true;
    this.running = false;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.suggestionOn = false;
    this.winner = winner;
    this.stopThinkTimer();
    this.stopStepDelay();
    SoundService.play(winner === 'draw' ? 'gameover' : 'win');
    // 记录战绩：仅人类参与的模式（AI 对 AI 不记）
    if (this.matchMode !== 'LvL') {
      this.recordScore(winner);
    }
    this.recorder.finish('Gomoku', this.engineDiffIndex, winner === this.humanSide ? 1 : 0,
      difficultyLabel(this.difficulty));
  }

  private recordScore(winner: string): void {
    const playerWins: boolean = winner === this.humanSide;
    const diffLabel: string = this.engineDiffIndex === 0 ? '简单' :
      this.engineDiffIndex === 2 ? '困难' : '中等';
    const duration: number = this.gameStartTime > 0 ?
      Math.max(0, Math.floor((Date.now() - this.gameStartTime) / 1000)) : 0;
    DataRepository.addGameScore('Gomoku', playerWins ? 1 : 0, this.engineDiffIndex, diffLabel,
      this.currentAiModelName(), duration, Math.floor(this.aiThinkTotalMs / 1000));
  }

  // 战绩记录用模型名（AI 对 AI 取黑方；人对 AI 取 AI 方；人机为空）
  private currentAiModelName(): string {
    if (this.matchMode === 'LvL') return this.aiModelLabel('black');
    if (this.matchMode === 'hvL') {
      return this.aiModelLabel(this.humanSide === 'black' ? 'white' : 'black');
    }
    return '';
  }

  // 当前模式、当前侧别实际使用的模型索引
  private modelIndexFor(side: string): number {
    if (this.matchMode === 'LvL') return side === 'black' ? this.blackModelIndex : this.whiteModelIndex;
    // hvL：LLM 方统一使用 ai 方模型
    return this.aiModelIndex;
  }

  private aiModelLabel(side: string): string {
    const idx: number = this.modelIndexFor(side);
    if (idx >= 0 && idx < this.aiModelNames.length) return this.aiModelNames[idx];
    return '模型';
  }

  // 当前模式、当前侧别 LLM 使用的配置
  private llmConfigFor(side: string): LlmConfig | null {
    if (this.matchMode === 'LvL') return side === 'black' ? this.blackConfig : this.whiteConfig;
    return this.aiConfig;
  }

  // ---- 尺寸 ----
  private cellSize(): number {
    return this.boardWidth / GOMOKU_SIZE;
  }

  // ---- 状态文案 ----
  private winnerText(): string {
    if (this.winner === 'draw') return '🤝 平局';
    if (this.matchMode === 'LvL') {
      return this.winner === 'black' ? '⚫ 黑方胜' : '⚪ 白方胜';
    }
    if (this.winner === this.humanSide) return '🎉 你赢了！';
    return '😔 对手获胜';
  }

  private statusTitle(): string {
    if (this.gameOver) return '🏁 ' + this.winnerText();
    if (this.thinkingSide !== '') {
      return '⏳ 思考 ' + this.aiThinkCount.toString() + ' 次 · ' + this.thinkingText;
    }
    return '🎯 轮到 ' + this.sideLabel(this.currentSide()) +
      (this.playerType(this.currentSide()) === 'human' ? '（你）' : '（AI）');
  }

  private statusSubtitle(): string {
    if (this.gameOver) return '点击「结束」可重新开始对局';
    if (this.thinkingSide !== '') return '正在请求模型，超时将自动重试或停止';
    if (this.matchMode === 'LvL') return 'AI 对 AI 自动对弈中';
    if (this.playerType(this.currentSide()) === 'human') return '点击交叉点落子';
    return 'AI 思考中，请稍候';
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

  // ---- 渲染 ----
  @Builder
  statusBar() {
    Row({ space: 12 }) {
      Column() {
        Row({ space: 8 }) {
          if (this.thinkingSide !== '') {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(this.palette.primary)
          }
          Text(this.statusTitle())
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text(this.statusSubtitle())
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Row({ space: 5 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(this.currentPlayer === BLACK_PLAYER ? '#1A1A1A' : '#F5F5F5')
          Text(this.currentPlayer === BLACK_PLAYER ? '黑方' : '白方')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
        }
        Text('悔棋 ' + this.undoUsed.toString() + '/' +
          (this.undoUnlimited ? '∞' : this.undoLimit.toString()))
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.palette.bgSurface2)
    .borderRadius(this.palette.radiusLg)
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
      // AI 建议落子高亮
      if (this.suggestionOn && this.suggestR === r && this.suggestC === c) {
        Circle()
          .width('100%')
          .height('100%')
          .fill('#2E7D3226')
          .stroke('#2E7D32')
          .strokeWidth(2)
      }
      if (this.board[r][c] === BLACK_PLAYER) {
        Circle()
          .width('86%')
          .height('86%')
          .fill('#1A1A1A')
          .shadow({ radius: 4, color: '#59000000', offsetX: 1, offsetY: 2 })
      } else if (this.board[r][c] === WHITE_PLAYER) {
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
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.actionBtn('↩', '悔棋', this.palette.bgSurface2, this.palette.textPrimary,
          () => { this.undo(); })
        this.actionBtn('💡', 'AI 提示', this.palette.primary, Color.White,
          () => { this.suggestMove(); })
        this.actionBtn('🏆', '战绩', this.palette.bgSurface2, this.palette.textPrimary,
          () => {
            AppNavigator.push('pages/GameHistory', new GameHistoryRouteParams('Gomoku'));
          })
        this.actionBtn('✕', '结束', this.palette.danger, Color.White,
          () => { this.stopGame(); this.setupOpen = true; })
      }
      .width('100%')
      if (this.matchMode === 'LvL') {
        Row({ space: 6 }) {
          Text('⚡ 节奏')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
          ForEach(AI_SPEED_OPTIONS, (label: string, i: number) => {
            Text(label)
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.aiSpeedIndex === i ? Color.White : this.palette.textSecondary)
              .fontWeight(this.aiSpeedIndex === i ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(8)
              .backgroundColor(this.aiSpeedIndex === i ? this.palette.primary : this.palette.bgSurface2)
              .onClick(() => { this.aiSpeedIndex = i; })
          }, (label: string) => label)
          Blank()
        }
        .width('100%')
      }
      if (this.suggestionOn) {
        Row({ space: 10 }) {
          Column() {
            Text('💡 建议落子')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Text('(' + this.suggestR.toString() + ',' + this.suggestC.toString() + ')')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          this.miniBtn('✓ 采纳', this.palette.primary, Color.White, () => { this.applySuggestion(); })
          this.miniBtn('取消', this.palette.bgSurface2, this.palette.textSecondary,
            () => { this.suggestionOn = false; })
        }
        .width('100%')
        .padding(10)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(this.palette.radiusLg)
        .border({ width: 1, color: this.palette.borderSubtle })
      }
      if (this.moveHistory.length > 0) {
        Column({ space: 6 }) {
          Row() {
            Text('📜 对局记录')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Blank()
            Text(this.moveHistory.length.toString() + ' 步')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          .width('100%')
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.moveHistory, (item: string, i: number) => {
                Text((i + 1).toString() + '. ' + item)
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textSecondary)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .margin({ right: 6, bottom: 6 })
                  .borderRadius(6)
                  .backgroundColor(this.palette.bgSurface2)
              }, (item: string, i: number) => i.toString())
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: this.isSm ? 104 : 150 })
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        }
        .width('100%')
        .padding(10)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(this.palette.radiusLg)
        .border({ width: 1, color: this.palette.borderSubtle })
      }
    }
    .width('100%')
  }

  @Builder
  actionBtn(icon: string, label: string, bg: ResourceColor, fg: ResourceColor, onTap: () => void) {
    Row({ space: 6 }) {
      Text(icon)
        .fontSize(this.palette.fsBase)
        .fontColor(fg)
      Text(label)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(fg)
        .fontWeight(FontWeight.Medium)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .borderRadius(this.palette.radiusLg)
    .backgroundColor(bg)
    .onClick(() => { onTap(); })
  }

  @Builder
  miniBtn(label: string, bg: ResourceColor, fg: ResourceColor, onTap: () => void) {
    Text(label)
      .fontSize(this.palette.fsSm)
      .fontFamily(this.palette.fontSans)
      .fontColor(fg)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .borderRadius(9)
      .backgroundColor(bg)
      .onClick(() => { onTap(); })
  }

  // ---- 开始前设置弹窗 ----
  @Builder
  setupDialog() {
    if (this.setupOpen) {
      Column() {
        // 遮罩
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('rgba(0, 0, 0, 0.45)')
          .onClick(() => { this.setupOpen = false; })
          .transition({ type: TransitionType.All, opacity: 0 })

        // 底部面板
        Column({ space: 14 }) {
          Row() {
            Blank()
            Text('✕')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.setupOpen = false; })
          }
          .width('100%')
          .padding({ right: 4, top: 4 })

          Column({ space: 4 }) {
            Text('对局设置')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text('选择对弈模式与规则，AI 对 AI 模式可分别为双方选择模型')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)

          Scroll() {
            Column({ space: 10 }) {
              // 对局模式
              Column({ space: 8 }) {
                this.settingLabel('对局模式')
                Row({ space: 10 }) {
                  this.modeCard('hvE', '人机', '🤖')
                  this.modeCard('hvL', '人对AI', '🧠')
                  this.modeCard('LvL', 'AI对AI', '⚔')
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(this.palette.radiusLg)
              .border({ width: 1, color: this.palette.borderSubtle })

              // 执子方
              if (this.matchMode !== 'LvL') {
                Column({ space: 8 }) {
                  this.settingLabel('执子方')
                  Row({ space: 8 }) {
                    this.chip('执黑', 'black')
                    this.chip('执白', 'white')
                    this.chip('随机', 'random')
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(this.palette.radiusLg)
                .border({ width: 1, color: this.palette.borderSubtle })
              }

              // 悔棋次数
              Column({ space: 8 }) {
                this.settingLabel('悔棋次数')
                Row({ space: 8 }) {
                  this.chip('0', '0')
                  this.chip('3', '3')
                  this.chip('5', '5')
                  this.chip('不限', 'unlimited')
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(this.palette.radiusLg)
              .border({ width: 1, color: this.palette.borderSubtle })

              // 引擎难度
              if (this.matchMode === 'hvE') {
                Column({ space: 8 }) {
                  this.settingLabel('引擎难度')
                  Row({ space: 8 }) {
                    this.chip('简单', 'easy')
                    this.chip('中等', 'medium')
                    this.chip('困难', 'hard')
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(this.palette.radiusLg)
                .border({ width: 1, color: this.palette.borderSubtle })
              }

              // AI 模型
              if (this.matchMode === 'hvL') {
                Column({ space: 8 }) {
                  this.settingLabel('AI 方模型')
                  this.modelPicker('AI 方', this.aiModelIndex, () => { this.openModelPicker('ai'); })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(this.palette.radiusLg)
                .border({ width: 1, color: this.palette.borderSubtle })
              } else if (this.matchMode === 'LvL') {
                Column({ space: 8 }) {
                  this.settingLabel('AI 模型')
                  this.modelPicker('黑方模型', this.blackModelIndex, () => { this.openModelPicker('black'); })
                  this.modelPicker('白方模型', this.whiteModelIndex, () => { this.openModelPicker('white'); })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(this.palette.radiusLg)
                .border({ width: 1, color: this.palette.borderSubtle })
              }

              // AI vs AI 对弈节奏
              if (this.matchMode === 'LvL') {
                Column({ space: 8 }) {
                  this.settingLabel('对弈节奏')
                  Row({ space: 8 }) {
                    ForEach(AI_SPEED_OPTIONS, (label: string, i: number) => {
                      Text(label)
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.aiSpeedIndex === i ? Color.White : this.palette.textSecondary)
                        .fontWeight(this.aiSpeedIndex === i ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .borderRadius(10)
                        .backgroundColor(this.aiSpeedIndex === i ? this.palette.primary : this.palette.bgSurface2)
                        .onClick(() => { this.aiSpeedIndex = i; })
                    }, (label: string) => label)
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(this.palette.radiusLg)
                .border({ width: 1, color: this.palette.borderSubtle })
              }
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 400 })

          this.startBtn()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: Math.max(20, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({ radius: 24, color: '#33000000', offsetY: -4 })
        .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
  }

  @Builder
  settingLabel(text: string) {
    Text(text)
      .fontSize(this.palette.fsSm)
      .fontFamily(this.palette.fontSans)
      .fontColor(this.palette.textSecondary)
      .fontWeight(FontWeight.Medium)
      .width('100%')
  }

  @Builder
  modeCard(mode: string, label: string, icon: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(22)
        .fontFamily(this.palette.fontSans)
      Text(label)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.matchMode === mode ? this.palette.primary : this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text(this.modeDesc(mode))
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .maxLines(2)
        .textAlign(TextAlign.Center)
      if (this.matchMode === mode) {
        Text('✓')
          .fontSize(13)
          .fontFamily(this.palette.fontSans)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .padding({ left: 9, right: 9, top: 1, bottom: 1 })
          .borderRadius(9)
          .backgroundColor(this.palette.primary)
          .margin({ top: 2 })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 12, bottom: 10, left: 4, right: 4 })
    .borderRadius(12)
    .border({ width: this.matchMode === mode ? 2 : 1,
      color: this.matchMode === mode ? this.palette.primary : this.palette.borderDefault })
    .backgroundColor(this.matchMode === mode ? this.palette.primaryDim : this.palette.bgSurface2)
    .onClick(() => { this.matchMode = mode as MatchMode; })
  }

  private modeDesc(mode: string): string {
    if (mode === 'hvE') return '对战本地引擎';
    if (mode === 'hvL') return '对战大模型';
    return '大模型互搏';
  }

  @Builder
  chip(label: string, value: string) {
    Text(label)
      .fontSize(this.palette.fsSm)
      .fontFamily(this.palette.fontSans)
      .fontColor(this.segActive(value) ? Color.White : this.palette.textSecondary)
      .fontWeight(this.segActive(value) ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(10)
      .backgroundColor(this.segActive(value) ? this.palette.primary : this.palette.bgSurface2)
      .onClick(() => { this.segTap(value); })
  }

  @Builder
  startBtn() {
    Row() {
      Text('🚀')
        .fontSize(this.palette.fsBase)
        .fontFamily(this.palette.fontSans)
      Text('开始对局')
        .fontSize(this.palette.fsMd)
        .fontFamily(this.palette.fontSans)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 14, bottom: 14 })
    .borderRadius(12)
    .backgroundColor(this.palette.primary)
    .shadow({ radius: 12, color: this.palette.primary + '55', offsetX: 0, offsetY: 4 })
    .onClick(() => { this.onSetupConfirm(); })
  }

  private undoUnlimited: boolean = false;

  private segActive(value: string): boolean {
    if (value === 'hvE' || value === 'hvL' || value === 'LvL') return this.matchMode === value;
    if (value === 'black' || value === 'white' || value === 'random') return this.humanSide === value;
    if (value === '0') return this.undoLimit === 0 && !this.undoUnlimited;
    if (value === '3') return this.undoLimit === 3;
    if (value === '5') return this.undoLimit === 5;
    if (value === 'unlimited') return this.undoLimit === 0 && this.undoUnlimited;
    if (value === 'easy') return this.engineDiffIndex === 0;
    if (value === 'medium') return this.engineDiffIndex === 1;
    if (value === 'hard') return this.engineDiffIndex === 2;
    return false;
  }

  private segTap(value: string): void {
    if (value === 'hvE') this.matchMode = 'hvE';
    else if (value === 'hvL') this.matchMode = 'hvL';
    else if (value === 'LvL') this.matchMode = 'LvL';
    else if (value === 'black') this.humanSide = 'black';
    else if (value === 'white') this.humanSide = 'white';
    else if (value === 'random') this.humanSide = Math.random() < 0.5 ? 'black' : 'white';
    else if (value === '0') { this.undoLimit = 0; this.undoUnlimited = false; }
    else if (value === '3') { this.undoLimit = 3; this.undoUnlimited = false; }
    else if (value === '5') { this.undoLimit = 5; this.undoUnlimited = false; }
    else if (value === 'unlimited') { this.undoLimit = 0; this.undoUnlimited = true; }
    else if (value === 'easy') { this.engineDiffIndex = 0; }
    else if (value === 'medium') { this.engineDiffIndex = 1; }
    else if (value === 'hard') { this.engineDiffIndex = 2; }
  }

  @Builder
  modelPicker(title: string, index: number, onOpen: () => void) {
    Row({ space: 10 }) {
      Text(title)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
        .layoutWeight(1)
      Row({ space: 6 }) {
        Text(this.aiModelNames.length > index ? this.aiModelNames[index] : '未配置')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.modelsConfigured ? this.palette.textPrimary : this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('›')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .constraintSize({ maxWidth: '62%' })
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius(9)
      .backgroundColor(this.palette.bgSurface2)
      .border({ width: 1, color: this.palette.borderSubtle })
      .onClick(() => {
        if (!this.modelsConfigured || this.aiModels.length === 0) return;
        onOpen();
      })
    }
    .width('100%')
  }

  // 打开模型选择列表（指定侧别）
  private openModelPicker(side: ModelSide): void {
    this.pickSide = side;
    this.showModelPicker = true;
  }

  // 当前弹窗侧别选中的模型索引
  private currentSideModelIndex(): number {
    if (this.pickSide === 'black') return this.blackModelIndex;
    if (this.pickSide === 'white') return this.whiteModelIndex;
    return this.aiModelIndex;
  }

  // 点选模型后：设置侧别索引并持久化记忆
  private selectModelForSide(index: number): void {
    if (index < 0 || index >= this.aiModels.length) return;
    const kind: string = this.pickSide === 'black' ? GOMOKU_KIND_BLACK :
      this.pickSide === 'white' ? GOMOKU_KIND_WHITE : GOMOKU_KIND_AI;
    if (this.pickSide === 'black') this.blackModelIndex = index;
    else if (this.pickSide === 'white') this.whiteModelIndex = index;
    else this.aiModelIndex = index;
    GameAIService.saveModelId(kind, this.aiModels[index].id);
    this.showModelPicker = false;
  }

  // 模型选择底部弹层
  @Builder
  modelPickerDialog() {
    if (this.showModelPicker) {
      Stack() {
        Column() {
          Blank()
          Column() {
            Row() {
              Row()
                .width(36)
                .height(4)
                .borderRadius(2)
                .backgroundColor(this.palette.borderSubtle)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 10, bottom: 4 })

            Row() {
              Text(this.pickSide === 'black' ? '选择黑方模型' :
                this.pickSide === 'white' ? '选择白方模型' : '选择 AI 方模型')
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(16)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .padding(8)
                .onClick(() => { this.showModelPicker = false; })
            }
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 8 })

            if (this.aiModels.length > 0) {
              Scroll() {
                Column({ space: 4 }) {
                  ForEach(this.aiModels, (m: LlmModelEntry, index: number) => {
                    Row({ space: 10 }) {
                      Column({ space: 2 }) {
                        Text(GameAIService.modelLabel(m))
                          .fontSize(this.palette.fsSm)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.textPrimary)
                          .fontWeight(index === this.currentSideModelIndex() ? FontWeight.Bold : FontWeight.Medium)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(m.model)
                          .fontSize(10)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.textTertiary)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      if (index === this.currentSideModelIndex()) {
                        Text('✓')
                          .fontSize(16)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.primary)
                          .fontWeight(FontWeight.Bold)
                      }
                    }
                    .width('100%')
                    .padding(12)
                    .borderRadius(8)
                    .backgroundColor(index === this.currentSideModelIndex() ? this.palette.primaryDim : this.palette.bgSurface)
                    .border({ width: index === this.currentSideModelIndex() ? 1 : 0,
                      color: index === this.currentSideModelIndex() ? this.palette.primary : Color.Transparent })
                    .onClick(() => { this.selectModelForSide(index); })
                  }, (m: LlmModelEntry) => m.id)
                }
                .width('100%')
              }
              .scrollBar(BarState.Off)
              .constraintSize({ maxHeight: 360 })
            } else {
              Text('没有已配置的模型，请到 AI 对话中配置')
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .padding({ top: 16, bottom: 16 })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.navBarHeight) })
          .backgroundColor(this.palette.bgBase)
          .borderRadius({ topLeft: 16, topRight: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.35)')
      .onClick(() => { this.showModelPicker = false; })
    }
  }

  private async onSetupConfirm(): Promise<void> {
    if (this.matchMode === 'hvL' || this.matchMode === 'LvL') {
      if (!this.modelsConfigured) {
        promptAction.showToast({ message: '请先在 AI 对话中配置可用模型' });
        return;
      }
    }
    await this.startGame();
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '五子棋', subtitle: this.modeLabel(this.matchMode) + ' · ' + difficultyLabel(this.difficulty) })
        if (this.replayMode) {
          Row({ space: 10 }) {
            Text('🎬 回放中 · 速度 x' + this.replaySpeed.toString())
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .layoutWeight(1)
            Button('速度')
              .fontSize(this.palette.fsSm)
              .height(30)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .onClick(() => { this.cycleReplaySpeed(); })
            Button('退出')
              .fontSize(this.palette.fsSm)
              .height(30)
              .backgroundColor(this.palette.danger)
              .fontColor('#FFFFFF')
              .onClick(() => { this.exitReplay(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
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

      this.setupDialog()
      this.modelPickerDialog()
    }
    .width('100%')
    .height('100%')
  }
}

// 智子 - 中国象棋（人机 / 人对AI / AI对AI）
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchResult, GameRouteParams } from '../common/Difficulty';
import {
  AI_SPEED_DELAYS, AI_SPEED_OPTIONS, CHESS_KIND_AI, CHESS_KIND_BLACK, CHESS_KIND_RED,
  GameAIService, GameAction, ChineseChessMoveOption
} from '../service/GameAIService';
import { ChineseChessEngine, ChineseChessMove, CHESS_COLS, CHESS_ROWS } from '../service/ChineseChessEngine';
import { ChineseChessBook } from '../service/ChineseChessBook';
import { ChineseChessNotation } from '../service/ChineseChessNotation';
import { DataRepository } from '../service/DataRepository';
import { GameHistoryRouteParams } from '../common/Navigation';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { ScreenKeepAlive } from '../common/ScreenKeepAlive';
import { SoundService } from '../service/SoundService';

// 对弈方类型
type PlayerMode = 'human' | 'engine' | 'llm';
// 对局模式
type MatchMode = 'hvE' | 'hvL' | 'LvL';
// 模型弹窗目标侧别
type ModelSide = 'red' | 'black' | 'ai';

// 悔棋快照
class BoardSnapshot {
  board: string[][];
  redTurn: boolean;

  constructor(board: string[][], redTurn: boolean) {
    this.board = board;
    this.redTurn = redTurn;
  }
}

@Component
@Entry
export struct ChineseChessPage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  // 棋盘状态
  @State board: string[][] = [];
  @State redTurn: boolean = true;
  @State gameOver: boolean = false;
  @State winner: string = ''; // 'red' | 'black' | 'draw' | ''
  @State selR: number = -1;
  @State selC: number = -1;
  @State legalTargets: number[][] = [];

  // 对弈配置与进行
  @State matchMode: MatchMode = 'hvE';
  @State humanSide: string = 'red';
  @State redPlayer: string = 'human';
  @State blackPlayer: string = 'engine';
  @State undoLimit: number = 3;
  @State undoUsed: number = 0;
  @State running: boolean = false;
  @State thinkingSide: string = ''; // 'red' | 'black' | ''
  @State thinkingText: string = '';
  @State moveHistory: string[] = [];
  @State setupOpen: boolean = true;

  // 模型
  @State aiModelNames: string[] = [];
  @State modelsConfigured: boolean = false;
  @State showModelPicker: boolean = false;
  private pickSide: ModelSide = 'ai';
  private aiModels: LlmModelEntry[] = [];
  @State redModelIndex: number = 0;
  @State blackModelIndex: number = 0;
  @State aiModelIndex: number = 0;
  private redConfig: LlmConfig | null = null;
  private blackConfig: LlmConfig | null = null;
  private aiConfig: LlmConfig | null = null;
  private aiLoopActive: boolean = false;
  private aiFailCount: number = 0;
  @State aiThinkCount: number = 0;
  private moveStack: BoardSnapshot[] = [];
  private configSeq: number = 0;

  // 本局开始时间（用于战绩时长统计）
  private gameStartTime: number = 0;

  // AI vs AI 对弈节奏：0慢 1中 2快 3极速
  @State aiSpeedIndex: number = 1;
  // 落子停顿 timer（AI vs AI 每步展示停顿），统一清理避免泄漏
  private stepDelayTimer: number = -1;

  // 开局库开关（持久化；开启时引擎走子前先查经典开局）
  @State bookEnabled: boolean = true;
  private static readonly BOOK_KEY: string = 'chineseChess_bookEnabled';

  // 最近一步走法（用于走子动画高亮来源/目标格）
  @State lastFromR: number = -1;
  @State lastFromC: number = -1;
  @State lastToR: number = -1;
  @State lastToC: number = -1;
  // 是否处于将军状态（红/黑）
  @State redInCheck: boolean = false;
  @State blackInCheck: boolean = false;
  // 对局是否已正式启动（用户点了「开始对局」）；用于防止 onPageShow 提前启动 AI 对局
  private gameStarted: boolean = false;

  // 棋盘版本号：每次 board 更新自增，ForEach 的 key 含版本号强制重建，
  // 规避 ArkUI @State 二维数组整体赋值不触发 UI 刷新的限制
  @State boardVersion: number = 0;

  // AI 落子提示
  @State suggestionOn: boolean = false;
  @State suggestFromR: number = -1;
  @State suggestFromC: number = -1;
  @State suggestToR: number = -1;
  @State suggestToC: number = -1;
  private suggestSeq: number = 0;

  private difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  private engineDepth: number = 3;
  // 弹窗内引擎难度选择：0简单 1中等 2困难
  @State engineDiffIndex: number = 1;
  // AI 思考等待计时（每秒刷新 thinkingText，避免界面长时间无变化）
  private thinkTimer: number = -1;
  private thinkStart: number = 0;
  // AI 思考累计总时长（毫秒，本局内累积）
  private aiThinkTotalMs: number = 0;

  // ---- 棋子/记谱 ----
  private pieceName(piece: string): string {
    if (piece === 'K') return '帅';
    if (piece === 'A') return '仕';
    if (piece === 'B') return '相';
    if (piece === 'H') return '马';
    if (piece === 'R') return '车';
    if (piece === 'C') return '炮';
    if (piece === 'P') return '兵';
    if (piece === 'k') return '将';
    if (piece === 'a') return '士';
    if (piece === 'b') return '象';
    if (piece === 'h') return '马';
    if (piece === 'r') return '车';
    if (piece === 'c') return '炮';
    if (piece === 'p') return '卒';
    return '?';
  }

  private sideLabel(side: string): string {
    return side === 'red' ? '红方' : '黑方';
  }

  // 把 generateMoves 结果转换成 serializeChineseChess 期望的描述字典数组
  private static toMoveOptions(board: string[][], moves: ChineseChessMove[]):
    ChineseChessMoveOption[] {
    const out: ChineseChessMoveOption[] = [];
    for (let i: number = 0; i < moves.length; i++) {
      const m: ChineseChessMove = moves[i];
      const piece: string = board[m.fromRow][m.fromCol];
      const target: string = board[m.toRow][m.toCol];
      let name: string = '?';
      if (piece === 'K') name = '红帅';
      else if (piece === 'A') name = '红仕';
      else if (piece === 'B') name = '红相';
      else if (piece === 'H') name = '红马';
      else if (piece === 'R') name = '红车';
      else if (piece === 'C') name = '红炮';
      else if (piece === 'P') name = '红兵';
      else if (piece === 'k') name = '黑将';
      else if (piece === 'a') name = '黑士';
      else if (piece === 'b') name = '黑象';
      else if (piece === 'h') name = '黑马';
      else if (piece === 'r') name = '黑车';
      else if (piece === 'c') name = '黑炮';
      else if (piece === 'p') name = '黑卒';
      let capture: string = '';
      if (target === 'K') capture = '红帅';
      else if (target === 'A') capture = '红仕';
      else if (target === 'B') capture = '红相';
      else if (target === 'H') capture = '红马';
      else if (target === 'R') capture = '红车';
      else if (target === 'C') capture = '红炮';
      else if (target === 'P') capture = '红兵';
      else if (target === 'k') capture = '黑将';
      else if (target === 'a') capture = '黑士';
      else if (target === 'b') capture = '黑象';
      else if (target === 'h') capture = '黑马';
      else if (target === 'r') capture = '黑车';
      else if (target === 'c') capture = '黑炮';
      else if (target === 'p') capture = '黑卒';
      out.push(new ChineseChessMoveOption(i + 1, m.fromRow, m.fromCol, m.toRow, m.toCol,
        name, capture));
    }
    return out;
  }

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
    return this.redTurn ? 'red' : 'black';
  }

  // ---- 启动/初始化 ----
  aboutToAppear(): void {
    const params: GameRouteParams | null = AppNavigator.getParam('pages/ChineseChess') as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.CHINESE_CHESS);
    if (!result.success || result.request === null) {
      AppNavigator.pop();
      return;
    }
    this.difficulty = result.request.difficulty;
    this.engineDepth = this.difficulty === DifficultyLevel.VERY_EASY ? 1 :
      this.difficulty === DifficultyLevel.EASY ? 2 :
        this.difficulty === DifficultyLevel.HARD ? 4 : 3;
    // 接线开局库：引擎走子前优先查经典开局
    ChineseChessEngine.bookLookup = (board: string[][], red: boolean, ply: number): ChineseChessMove | null => {
      return ChineseChessBook.lookup(board, red, ply);
    };
    // 恢复开局库开关（异步）
    DataRepository.getSetting(ChineseChessPage.BOOK_KEY, '1').then((v: string) => {
      this.bookEnabled = v !== '0';
      ChineseChessBook.enabled = this.bookEnabled;
    });
    this.initAiModels();
    this.resetBoard();
    ScreenKeepAlive.enable(getContext(this));
  }

  aboutToDisappear(): void {
    ScreenKeepAlive.disable(getContext(this));
  }

  onPageHide(): void {
    this.running = false;
    this.aiLoopActive = false;
    this.stopThinkTimer();
    this.stopStepDelay();
  }

  // 回到前台：若用户没有主动结束（gameOver=false 且无 winner），且当前没有任何活动AI思考，
  // 把 running 重置为 true 并调度下一步。这样后台返回后 AI vs AI 不会卡住。
  onPageShow(): void {
    if (this.gameOver || this.winner.length > 0) return;
    if (this.setupOpen) return;          // 设置弹窗打开时不算 paused
    if (this.aiLoopActive) return;       // 让 thinkFor 走完即可
    if (this.thinkingSide !== '') return; // 还有思考方未走完，let it finish
    // 仅当对局已由用户「开始对局」启动后才恢复暂停的调度；防止页面首次显示就提前启动 AI
    if (this.gameStarted && !this.running) {
      this.running = true;
      this.scheduleNext();
    }
  }

  private resetBoard(): void {
    this.board = ChineseChessEngine.initialBoard();
    this.boardVersion += 1;
    this.redTurn = true;
    this.gameOver = false;
    this.winner = '';
    this.selR = -1;
    this.selC = -1;
    this.legalTargets = [];
    this.moveHistory = [];
    this.moveStack = [];
    this.undoUsed = 0;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.aiFailCount = 0;
    this.aiThinkCount = 0;
    this.suggestionOn = false;
    this.lastFromR = -1;
    this.lastFromC = -1;
    this.lastToR = -1;
    this.lastToC = -1;
    this.redInCheck = false;
    this.blackInCheck = false;
    this.stopThinkTimer();
    this.aiThinkTotalMs = 0;
    this.stopStepDelay();
  }

  private async initAiModels(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    const names: string[] = [];
    for (let i: number = 0; i < this.aiModels.length; i++) {
      names.push(GameAIService.modelLabel(this.aiModels[i]));
    }
    this.aiModelNames = names;
    this.modelsConfigured = this.aiModels.length > 0;
    // 恢复记忆的模型（红/黑/AI 三侧分别独立记忆）
    const redId: string = await GameAIService.loadSavedModelId(CHESS_KIND_RED);
    const blackId: string = await GameAIService.loadSavedModelId(CHESS_KIND_BLACK);
    const aiId: string = await GameAIService.loadSavedModelId(CHESS_KIND_AI);
    for (let i: number = 0; i < this.aiModels.length; i++) {
      if (this.aiModels[i].id === redId) this.redModelIndex = i;
      if (this.aiModels[i].id === blackId) this.blackModelIndex = i;
      if (this.aiModels[i].id === aiId) this.aiModelIndex = i;
    }
  }

  private async loadModelConfig(index: number): Promise<LlmConfig | null> {
    if (!this.modelsConfigured || index < 0 || index >= this.aiModels.length) return null;
    return await GameAIService.loadConfig(this.aiModels[index].id);
  }

  // ---- 开始对局 ----
  private async startGame(): Promise<void> {
    if (this.matchMode === 'hvL' || this.matchMode === 'LvL') {
      if (!this.modelsConfigured) {
        promptAction.showToast({ message: '请先在 AI 对话中配置可用模型' });
        return;
      }
    }
    this.redPlayer = this.playerType('red');
    this.blackPlayer = this.playerType('black');
    this.resetBoard();
    this.gameStartTime = Date.now();
    if (this.matchMode === 'hvL') {
      this.aiConfig = await this.loadModelConfig(this.aiModelIndex);
    } else if (this.matchMode === 'LvL') {
      this.redConfig = await this.loadModelConfig(this.redModelIndex);
      this.blackConfig = await this.loadModelConfig(this.blackModelIndex);
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
      // 累计 AI 思考总时长（毫秒）
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
    if (!this.running || this.gameOver) return;
    const side: string = this.currentSide();
    const type: PlayerMode = this.playerType(side);
    if (type === 'human') {
      this.thinkingSide = '';
      this.thinkingText = '';
      return;
    }
    this.thinkFor(side).catch((e: Object) => {
      console.error('[ChineseChess] thinkFor 异常: ' + e);
      this.stopGame();
    });
  }

  // AI vs AI 落子后的节奏控制：若下一方仍为 LLM 且设定速度>0，则按档位停顿后再调度
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
    console.info('[ChineseChess][thinkFor] 调度 side=' + side + ' redTurn=' + this.redTurn +
      ' type=' + type + ' running=' + this.running + ' gameOver=' + this.gameOver);
    this.thinkingText = (this.sideLabel(side) + '思考中…') +
      (type === 'engine' ? '（本地引擎）' : '（' + this.aiModelLabel(side) + '）');
    let move: ChineseChessMove | null = null;
    if (type === 'engine') {
      // 本地引擎：深拷贝棋盘，避免在搜索中修改 @State
      try {
        const snapshot: string[][] = ChineseChessEngine.cloneBoard(this.board);
        move = ChineseChessEngine.searchBest(snapshot, side === 'red', this.engineDepth, this.moveHistory.length);
      } catch (e) {
        console.error('[ChineseChess] 本地引擎异常: ' + e);
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
      let llmMove: ChineseChessMove | null = null;
      // 事先生成当前方所有合法走法，供 prompt 给 LLM 选，模型只能选索引
      const legalMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(this.board, side === 'red');
      for (let attempt: number = 0; attempt < MAX_LLM_RETRY; attempt++) {
        const stateText: string = GameAIService.serializeChineseChess(this.board, side === 'red',
          ChineseChessPage.toMoveOptions(this.board, legalMoves));
        const messages = GameAIService.buildMessages('ChineseChess', this.difficulty, stateText);
        if (attempt === 0) {
          this.startThinkTimer(this.sideLabel(side) + '思考中', '（' + this.aiModelLabel(side) + '）');
        } else {
          this.startThinkTimer(this.sideLabel(side) + '重新计算', '（第' + (attempt + 1).toString() + '次）');
        }
        const result = await GameAIService.decide(config, messages, 'ChineseChess', 12000);
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
          // 请求连续失败达上限，用本地引擎兜底，保证对局能推进
          if (requestFailures >= MAX_LLM_RETRY) break;
          continue;
        }
        requestFailures = 0;
        const action: GameAction | null = GameAIService.parseAction('ChineseChess', result.content);
        // 序号模式：MOVE_IDX，走 legalMoves[idx]
        if (action !== null && action.command === 'MOVE_IDX' && action.c >= 0 && action.c < legalMoves.length) {
          llmMove = legalMoves[action.c];
        } else if (action !== null && action.command === 'MOVE') {
          // 兜底：旧坐标模式
          llmMove = new ChineseChessMove(action.r, action.c, action.value, action.toRow);
        }
        if (llmMove !== null && this.isLegal(llmMove)) {
          move = llmMove;
          break;
        }
        // 走法非法：记录并展示模型实际回复的简短预览，便于排查
        llmMove = null;
        const rawPreview: string = result.content.length > 40 ?
          result.content.substring(0, 40) + '…' : result.content;
        console.info('[ChineseChess] ' + side + ' LLM 返回非法走法，重试中。原始回复=' + rawPreview);
        if (attempt === MAX_LLM_RETRY - 1) {
          promptAction.showToast({
            message: this.sideLabel(side) + 'AI 输出无法解析："' + rawPreview + '"'
          });
        }
      }
      // LLM 反复非法或请求失败：用本地引擎兜底，保证一定落子
      if (move === null) {
        if (llmMove !== null) {
          promptAction.showToast({ message: this.sideLabel(side) + '模型多次返回非法走法，改用本地引擎' });
        }
        this.thinkingText = this.sideLabel(side) + '思考中…（本地引擎兜底）';
        try {
          const snapshot: string[][] = ChineseChessEngine.cloneBoard(this.board);
          move = ChineseChessEngine.searchBest(snapshot, side === 'red', this.engineDepth, this.moveHistory.length);
        } catch (e) {
          console.error('[ChineseChess] 本地引擎兜底异常: ' + e);
          move = null;
        }
        this.thinkingSide = '';
        this.thinkingText = '';
      }
    }
    this.aiLoopActive = false;
    if (!this.running || this.gameOver) return;
    if (move === null) {
      // 无合法走法 = 对方胜
      this.finishGame(this.sideLabel(side === 'red' ? 'black' : 'red') + '胜');
      return;
    }
    this.thinkingSide = '';
    this.thinkingText = '';
    this.applyMove(move);
  }

  // 走法合法校验（基于当前棋盘）
  private isLegal(move: ChineseChessMove): boolean {
    const side: boolean = move.fromRow >= 0 && move.fromRow < CHESS_ROWS &&
      this.board[move.fromRow][move.fromCol] !== '.';
    if (!side) return false;
    const red: boolean = this.redTurn;
    const moves: ChineseChessMove[] = ChineseChessEngine.generateMoves(this.board, red);
    for (let i: number = 0; i < moves.length; i++) {
      if (moves[i].fromRow === move.fromRow && moves[i].fromCol === move.fromCol &&
        moves[i].toRow === move.toRow && moves[i].toCol === move.toCol) {
        return true;
      }
    }
    return false;
  }

  // 执行走法并推进局面
  private applyMove(move: ChineseChessMove): void {
    // 合法性安全网：任何非法走法（含非法坐标、吃己方、送将）一律拒绝，
    // 防止 LLM 解析出错或本地引擎异常导致棋盘出现非法局面。
    if (!this.isLegal(move)) {
      console.error('[ChineseChess] 拒绝非法走法: ' + move.fromRow + ',' + move.fromCol +
        ' → ' + move.toRow + ',' + move.toCol);
      return;
    }
    console.info('[ChineseChess][applyMove] redTurn=' + this.redTurn + ' 走 ' +
      move.fromRow + ',' + move.fromCol + '→' + move.toRow + ',' + move.toCol +
      ' 记谱=' + this.sideLabel(this.redTurn ? 'red' : 'black') +
      ' 当前棋盘步数=' + this.moveHistory.length.toString());
    // 保存悔棋快照
    this.moveStack.push(new BoardSnapshot(ChineseChessEngine.cloneBoard(this.board), this.redTurn));
    // 记录走子动画状态
    this.lastFromR = move.fromRow;
    this.lastFromC = move.fromCol;
    this.lastToR = move.toRow;
    this.lastToC = move.toCol;
    // 记谱需用走子前的棋盘（识别来源棋子）。注意 sideLabel 期望 'red'/'black'，勿传中文 '红'/'黑'
    const preBoard: string[][] = this.board;
    const notation: string = ChineseChessNotation.fromMove(preBoard, move, this.redTurn);
    const sideLabel: string = this.redTurn ? '红方' : '黑方';
    this.moveHistory = this.moveHistory.concat(
      sideLabel + ' ' + (notation.length > 0 ? notation : '未知'));
    const nb: string[][] = ChineseChessEngine.cloneBoard(preBoard);
    const piece: string = nb[move.fromRow][move.fromCol];
    nb[move.toRow][move.toCol] = piece;
    nb[move.fromRow][move.fromCol] = '.';
    this.board = nb;
    // 自增版本号强制 UI 重建棋盘（规避 @State 二维数组整体赋值不刷新的限制）
    this.boardVersion += 1;
    this.selR = -1;
    this.selC = -1;
    this.legalTargets = [];
    this.suggestionOn = false;
    // 切换回合方
    this.redTurn = !this.redTurn;
    // 更新将军状态（走子后检测轮到方是否被将军）
    const nextSide: string = this.currentSide();
    this.redInCheck = ChineseChessEngine.isInCheck(this.board, true);
    this.blackInCheck = ChineseChessEngine.isInCheck(this.board, false);
    // 胜负/无子判断
    const nextMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(this.board, nextSide === 'red');
    if (nextMoves.length === 0) {
      // nextMoves.length===0 表示轮到方(nextSide)无走法，走子方(sideLabel，即刚走子的一方)胜
      this.finishGame(sideLabel + '胜');
      return;
    }
    this.scheduleNextWithStepDelay();
  }

  private finishGame(msg: string): void {
    SoundService.play(msg.indexOf('胜') >= 0 ? 'win' : 'gameover');
    this.gameOver = true;
    this.running = false;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.suggestionOn = false;
    this.winner = msg;
    this.stopThinkTimer();
    this.stopStepDelay();
    // 记录战绩：仅人类参与的模式（AI 对 AI 不记）
    if (this.matchMode !== 'LvL') {
      this.recordScore(msg);
    }
  }

  // 记录对局结果到战绩库（score: 1=玩家胜 0=玩家负；level: 难度索引；difficulty: 难度标签）
  private recordScore(msg: string): void {
    const redWins: boolean = msg.indexOf('红方') >= 0;
    const blackWins: boolean = msg.indexOf('黑方') >= 0;
    const playerWins: boolean =
      (this.humanSide === 'red' && redWins) || (this.humanSide === 'black' && blackWins);
    const diffLabel: string = this.engineDiffIndex === 0 ? '简单' :
      this.engineDiffIndex === 2 ? '困难' : '中等';
    const duration: number = this.gameStartTime > 0 ?
      Math.max(0, Math.floor((Date.now() - this.gameStartTime) / 1000)) : 0;
    DataRepository.addGameScore('ChineseChess', playerWins ? 1 : 0, this.engineDiffIndex, diffLabel,
      this.currentAiModelName(), duration, Math.floor(this.aiThinkTotalMs / 1000));
  }

  // AI 托管时使用的模型显示名（取配置中的显示名称）；纯手动/仅本地引擎返回空串
  private currentAiModelName(): string {
    if (this.matchMode === 'LvL') return this.aiModelLabel('red');
    if (this.matchMode === 'hvL') {
      return this.aiModelLabel(this.humanSide === 'red' ? 'black' : 'red');
    }
    return '';
  }

  // ---- 放入下棋棋子的操作（人） ----
  private onCellTap(r: number, c: number): void {
    if (!this.running || this.gameOver) return;
    if (this.thinkingSide !== '') return; // AI 思考中锁定
    if (this.playerType(this.currentSide()) !== 'human') return;
    const side: boolean = this.redTurn;
    const piece: string = this.board[r][c];
    // 若已选中且点击目标在合法走法内 → 落子
    if (this.selR >= 0) {
      for (let i: number = 0; i < this.legalTargets.length; i++) {
        if (this.legalTargets[i][0] === r && this.legalTargets[i][1] === c) {
          this.applyMove(new ChineseChessMove(this.selR, this.selC, r, c));
          return;
        }
      }
    }
    // 否则尝试选中己方棋子
    if (ChineseChessEngine.isPiece(piece) &&
      (side ? ChineseChessEngine.isRed(piece) : ChineseChessEngine.isBlack(piece))) {
      this.selR = r;
      this.selC = c;
      this.legalTargets = ChineseChessEngine.generateMoves(this.board, side)
        .filter((m: ChineseChessMove): boolean => m.fromRow === r && m.fromCol === c)
        .map((m: ChineseChessMove): number[] => [m.toRow, m.toCol]);
    } else {
      this.selR = -1;
      this.selC = -1;
      this.legalTargets = [];
    }
  }

  // ---- 悔棋 ----
  private undo(): void {
    if (!this.running && !this.gameOver) return;
    if (this.thinkingSide !== '') return;
    if (this.undoLimit > 0 && this.undoUsed >= this.undoLimit) {
      promptAction.showToast({ message: '已达本局悔棋次数上限' });
      return;
    }
    if (this.moveStack.length === 0) {
      promptAction.showToast({ message: '没有可悔的棋步' });
      return;
    }
    const snap: BoardSnapshot = this.moveStack.pop() as BoardSnapshot;
    // 悔棋应回退到"当前方走这一步之前"的局面（即回退一整步）
    this.board = snap.board;
    this.redTurn = snap.redTurn;
    this.undoUsed += 1;
    this.selR = -1;
    this.selC = -1;
    this.legalTargets = [];
    this.suggestionOn = false;
    this.lastFromR = -1;
    this.lastFromC = -1;
    this.lastToR = -1;
    this.lastToC = -1;
    this.redInCheck = ChineseChessEngine.isInCheck(this.board, true);
    this.blackInCheck = ChineseChessEngine.isInCheck(this.board, false);
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
    this.thinkingSide = side;
    this.thinkingText = 'AI 建议中…';
    this.suggestSeq += 1;
    const seq: number = this.suggestSeq;
    let move: ChineseChessMove | null = null;
    if (type === 'engine') {
      const snapshot: string[][] = ChineseChessEngine.cloneBoard(this.board);
      move = ChineseChessEngine.searchBest(snapshot, side === 'red', this.engineDepth, this.moveHistory.length);
    } else {
      const config: LlmConfig | null = this.llmConfigFor(side);
      if (config !== null) {
        const legalMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(this.board, side === 'red');
        const stateText: string = GameAIService.serializeChineseChess(this.board, side === 'red',
          ChineseChessPage.toMoveOptions(this.board, legalMoves));
        const messages = GameAIService.buildMessages('ChineseChess', this.difficulty, stateText);
        this.startThinkTimer('AI 建议', '');
        const result = await GameAIService.decide(config, messages, 'ChineseChess', 12000);
        this.stopThinkTimer();
        if (seq !== this.suggestSeq) return;
        if (result.success) {
          const action: GameAction | null = GameAIService.parseAction('ChineseChess', result.content);
          if (action !== null && action.command === 'MOVE_IDX' && action.c >= 0 && action.c < legalMoves.length) {
            move = legalMoves[action.c];
          } else if (action !== null && action.command === 'MOVE') {
            const m: ChineseChessMove = new ChineseChessMove(action.r, action.c, action.value, action.toRow);
            if (this.isLegal(m)) move = m;
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
      promptAction.showToast({ message: '未能生成建议走法' });
      return;
    }
    this.suggestFromR = move.fromRow;
    this.suggestFromC = move.fromCol;
    this.suggestToR = move.toRow;
    this.suggestToC = move.toCol;
    this.suggestionOn = true;
  }

  // 确认执行 AI 建议
  private applySuggestion(): void {
    if (!this.suggestionOn) return;
    this.applyMove(new ChineseChessMove(this.suggestFromR, this.suggestFromC, this.suggestToR, this.suggestToC));
  }

  // 当前模式、当前侧别实际使用的模型索引
  private modelIndexFor(side: string): number {
    if (this.matchMode === 'LvL') return side === 'red' ? this.redModelIndex : this.blackModelIndex;
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
    if (this.matchMode === 'LvL') return side === 'red' ? this.redConfig : this.blackConfig;
    return this.aiConfig;
  }

  // ---- 尺寸 ----
  @State boardWidth: number = 360;
  private boardCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  private cellSize(): number {
    return this.boardWidth / CHESS_COLS;
  }

  private boardHeight(): number {
    return this.boardWidth / CHESS_COLS * CHESS_ROWS;
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
            .fill(this.redTurn ? '#C0392B' : '#2C3E50')
          Text(this.redTurn ? '红方' : '黑方')
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
  chessboard() {
    Stack() {
      // 棋盘底图：木色 + 网格线 + 九宫格 + 标记
      Stack() {
        Canvas(this.boardCtx)
          .width(this.boardWidth)
          .height(this.boardHeight())
          .onReady(() => {
            this.drawBoard();
          })
        // 楚河汉界
        Row() {
          Blank()
          Text('楚  河')
            .fontSize(this.cellSize() * 0.74)
            .fontFamily(this.palette.fontSans)
            .fontColor('#7A4A21')
            .fontWeight(FontWeight.Bold)
          Blank()
          Blank()
          Text('汉  界')
            .fontSize(this.cellSize() * 0.74)
            .fontFamily(this.palette.fontSans)
            .fontColor('#7A4A21')
            .fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')
        .height(this.cellSize() * 2)
        .position({ x: 0, y: this.cellSize() * 4 })
        .alignItems(VerticalAlign.Center)
      }
      .width(this.boardWidth)
      .height(this.boardHeight())
      .borderRadius(10)
      .clip(true)

      // 棋子层。key 含 boardVersion：每次落子强制重建全部棋子，规避 @State 二维数组不刷新
      Column() {
        ForEach(this.board, (row: string[], r: number) => {
          Row() {
            ForEach(row, (piece: string, c: number) => {
              this.cell(this.board[r][c], r, c)
            }, (piece: string, c: number) => r.toString() + '_' + c.toString())
          }
          .width('100%')
        }, (row: string[], r: number) => r.toString() + '_v' + this.boardVersion.toString())
      }
      .width(this.boardWidth)
      .height(this.boardHeight())
    }
    .width(this.boardWidth)
    .height(this.boardHeight())
    .shadow({ radius: 18, color: '#40000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  cell(piece: string, r: number, c: number) {
    Stack() {
      if (this.isTarget(r, c)) {
        if (piece === '.') {
          Circle()
            .width(this.cellSize() * 0.26)
            .height(this.cellSize() * 0.26)
            .fill('#E53935')
        } else {
          Circle()
            .width(this.cellSize() * 0.84)
            .height(this.cellSize() * 0.84)
            .fill('#E5393545')
        }
      }
      if (this.suggestionOn &&
        ((this.suggestFromR === r && this.suggestFromC === c) ||
          (this.suggestToR === r && this.suggestToC === c))) {
        Circle()
          .width(this.cellSize() * 0.94)
          .height(this.cellSize() * 0.94)
          .fill((this.suggestToR === r && this.suggestToC === c) ? '#FF6B6B45' : '#FFD70040')
      }
      if (this.lastToR === r && this.lastToC === c && this.lastFromR >= 0) {
        // 最近落子的目标格：金色描边高亮（走子轨迹）
        Circle()
          .width(this.cellSize() * 0.98)
          .height(this.cellSize() * 0.98)
          .fill(Color.Transparent)
          .stroke('#2E7D32')
          .strokeWidth(2)
      }
      if (this.lastFromR === r && this.lastFromC === c && this.lastToR >= 0) {
        // 最近落子的来源格：灰蓝描边
        Circle()
          .width(this.cellSize() * 0.98)
          .height(this.cellSize() * 0.98)
          .fill(Color.Transparent)
          .stroke('#7A4A2140')
          .strokeWidth(1.6)
      }
      if (piece !== '.') {
        this.piece(piece, r, c)
      }
      if (this.selR === r && this.selC === c) {
        Circle()
          .width(this.cellSize() * 0.98)
          .height(this.cellSize() * 0.98)
          .fill(Color.Transparent)
          .stroke('#FFD700')
          .strokeWidth(2.5)
      }
    }
    .width(this.cellSize())
    .height(this.cellSize())
    .onClick(() => { this.onCellTap(r, c); })
  }

  // 棋子是否处于被将军状态（红方被将军时高亮红帅，黑方被将军时高亮黑将）
  private kingInCheck(p: string, r: number, c: number): boolean {
    if (p === 'K' && this.redInCheck) return true;
    if (p === 'k' && this.blackInCheck) return true;
    return false;
  }

  @Builder
  piece(p: string, r: number, c: number) {
    Stack() {
      Circle()
        .width('100%')
        .height('100%')
        .fill('#F9EFD7')
        .stroke(ChineseChessEngine.isRed(p) ? '#B71C1C' : '#263238')
        .strokeWidth(1.6)
      if (this.kingInCheck(p, r, c)) {
        // 被将军：红色脉冲高亮圈
        Circle()
          .width('118%')
          .height('118%')
          .fill(Color.Transparent)
          .stroke('#E53935')
          .strokeWidth(2.5)
      }
      Circle()
        .width('72%')
        .height('72%')
        .fill(Color.Transparent)
        .stroke(ChineseChessEngine.isRed(p) ? '#B71C1C' : '#263238')
        .strokeWidth(1)
      Text(this.pieceName(p))
        .fontSize(this.cellSize() * 0.42)
        .fontFamily(this.palette.fontSans)
        .fontColor(ChineseChessEngine.isRed(p) ? '#B71C1C' : '#263238')
        .fontWeight(FontWeight.Bold)
    }
    .width(this.cellSize() * 0.92)
    .height(this.cellSize() * 0.92)
    .shadow({ radius: 5, color: '#4D000000', offsetX: 1, offsetY: 2 })
    // 落子位置变化通过 boardVersion 重建触发；此格为最近落子目标时轻微放大提示
    .scale({
      x: (this.lastToR === r && this.lastToC === c) ? 1.06 : 1,
      y: (this.lastToR === r && this.lastToC === c) ? 1.06 : 1
    })
  }

  private isTarget(r: number, c: number): boolean {
    for (let i: number = 0; i < this.legalTargets.length; i++) {
      if (this.legalTargets[i][0] === r && this.legalTargets[i][1] === c) return true;
    }
    return false;
  }

  private redrawBoard(): void {
    setTimeout(() => {
      this.drawBoard();
    }, 0);
  }

  private drawBoard(): void {
    const ctx: CanvasRenderingContext2D = this.boardCtx;
    const cs: number = this.cellSize();
    const totalW: number = this.boardWidth;
    const totalH: number = this.boardHeight();
    const left: number = cs / 2;
    const top: number = cs / 2;
    const lineW: number = cs * (CHESS_COLS - 1);
    const lineH: number = cs * (CHESS_ROWS - 1);
    const ink: string = '#7A4A21';

    ctx.clearRect(0, 0, totalW, totalH);
    // 木色底
    ctx.fillStyle = '#E9C995';
    ctx.fillRect(0, 0, totalW, totalH);
    // 外框双线
    ctx.strokeStyle = ink;
    ctx.lineWidth = 2.5;
    ctx.strokeRect(left - 5, top - 5, lineW + 10, lineH + 10);
    ctx.lineWidth = 1;
    ctx.strokeRect(left - 1.5, top - 1.5, lineW + 3, lineH + 3);
    // 横线
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      ctx.beginPath();
      ctx.moveTo(left, top + r * cs);
      ctx.lineTo(left + lineW, top + r * cs);
      ctx.stroke();
    }
    // 竖线（河界处断开）
    for (let c: number = 0; c < CHESS_COLS; c++) {
      const x: number = left + c * cs;
      ctx.beginPath();
      ctx.moveTo(x, top);
      ctx.lineTo(x, top + 4 * cs);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x, top + 5 * cs);
      ctx.lineTo(x, top + lineH);
      ctx.stroke();
    }
    // 九宫格斜线
    ctx.beginPath();
    ctx.moveTo(left + 3 * cs, top);
    ctx.lineTo(left + 5 * cs, top + 2 * cs);
    ctx.moveTo(left + 5 * cs, top);
    ctx.lineTo(left + 3 * cs, top + 2 * cs);
    ctx.moveTo(left + 3 * cs, top + 7 * cs);
    ctx.lineTo(left + 5 * cs, top + 9 * cs);
    ctx.moveTo(left + 5 * cs, top + 7 * cs);
    ctx.lineTo(left + 3 * cs, top + 9 * cs);
    ctx.stroke();
    // 炮位标记（十字）
    const cannons: number[][] = [[2, 1], [2, 7], [7, 1], [7, 7]];
    ctx.lineWidth = 1.5;
    for (let i: number = 0; i < cannons.length; i++) {
      const x: number = left + cannons[i][1] * cs;
      const y: number = top + cannons[i][0] * cs;
      ctx.beginPath();
      ctx.moveTo(x - cs * 0.18, y);
      ctx.lineTo(x + cs * 0.18, y);
      ctx.moveTo(x, y - cs * 0.18);
      ctx.lineTo(x, y + cs * 0.18);
      ctx.stroke();
    }
    // 兵/卒位标记（圆点）
    ctx.fillStyle = ink;
    for (let rr: number = 4; rr <= 5; rr++) {
      for (let cc: number = 0; cc < CHESS_COLS; cc += 2) {
        const x: number = left + cc * cs;
        const y: number = top + rr * cs;
        ctx.beginPath();
        ctx.arc(x, y, cs * 0.09, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  private statusTitle(): string {
    if (this.gameOver) return '🏁 ' + this.winner;
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
    if (this.playerType(this.currentSide()) === 'human') return '点击己方棋子选择，再点目标格落子';
    return 'AI 思考中，请稍候';
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
            AppNavigator.push('pages/GameHistory', new GameHistoryRouteParams('ChineseChess'));
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
            Text('💡 建议走法')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Text(this.suggestFromR.toString() + ',' + this.suggestFromC.toString() +
              ' → ' + this.suggestToR.toString() + ',' + this.suggestToC.toString())
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
          // 多行自动换行展示，充分利用屏幕宽度与下方空白，避免横向滑动
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
          // 高度自适应内容；小屏上限 104，平板/大屏上限 150，避免超出屏幕
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
                    this.chip('执红', 'red')
                    this.chip('执黑', 'black')
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

              // 开局库（可开关，持久化）
              Column({ space: 8 }) {
                this.settingLabel('开局库')
                Row() {
                  Column({ space: 2 }) {
                    Text('启用经典开局库')
                      .fontSize(this.palette.fsSm)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textPrimary)
                      .fontWeight(FontWeight.Medium)
                    Text('开局阶段走经典谱着，开局更专业')
                      .fontSize(this.palette.fsXs)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.bookEnabled })
                    .selectedColor(this.palette.primary)
                    .onChange((isOn: boolean) => {
                      this.bookEnabled = isOn;
                      ChineseChessBook.enabled = isOn;
                      DataRepository.setSetting(ChineseChessPage.BOOK_KEY, isOn ? '1' : '0');
                    })
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
                  this.modelPicker('红方模型', this.redModelIndex, () => { this.openModelPicker('red'); })
                  this.modelPicker('黑方模型', this.blackModelIndex, () => { this.openModelPicker('black'); })
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

  private segActive(value: string): boolean {
    if (value === 'hvE' || value === 'hvL' || value === 'LvL') return this.matchMode === value;
    if (value === 'red' || value === 'black' || value === 'random') return this.humanSide === value;
    if (value === '0') return this.undoLimit === 0;
    if (value === '3') return this.undoLimit === 3;
    if (value === '5') return this.undoLimit === 5;
    if (value === 'unlimited') return this.undoLimit === 0 && this.undoUnlimited;
    if (value === 'easy') return this.engineDiffIndex === 0;
    if (value === 'medium') return this.engineDiffIndex === 1;
    if (value === 'hard') return this.engineDiffIndex === 2;
    return false;
  }

  private undoUnlimited: boolean = false;

  private segTap(value: string): void {
    if (value === 'hvE') this.matchMode = 'hvE';
    else if (value === 'hvL') this.matchMode = 'hvL';
    else if (value === 'LvL') this.matchMode = 'LvL';
    else if (value === 'red') this.humanSide = 'red';
    else if (value === 'black') this.humanSide = 'black';
    else if (value === 'random') this.humanSide = Math.random() < 0.5 ? 'red' : 'black';
    else if (value === '0') { this.undoLimit = 0; this.undoUnlimited = false; }
    else if (value === '3') { this.undoLimit = 3; this.undoUnlimited = false; }
    else if (value === '5') { this.undoLimit = 5; this.undoUnlimited = false; }
    else if (value === 'unlimited') { this.undoLimit = 0; this.undoUnlimited = true; }
    else if (value === 'easy') { this.engineDiffIndex = 0; this.engineDepth = 2; }
    else if (value === 'medium') { this.engineDiffIndex = 1; this.engineDepth = 3; }
    else if (value === 'hard') { this.engineDiffIndex = 2; this.engineDepth = 4; }
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
    if (this.pickSide === 'red') return this.redModelIndex;
    if (this.pickSide === 'black') return this.blackModelIndex;
    return this.aiModelIndex;
  }

  // 点选模型后：设置侧别索引并持久化记忆
  private selectModelForSide(index: number): void {
    if (index < 0 || index >= this.aiModels.length) return;
    const kind: string = this.pickSide === 'red' ? CHESS_KIND_RED :
      this.pickSide === 'black' ? CHESS_KIND_BLACK : CHESS_KIND_AI;
    if (this.pickSide === 'red') this.redModelIndex = index;
    else if (this.pickSide === 'black') this.blackModelIndex = index;
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
              Text(this.pickSide === 'red' ? '选择红方模型' :
                this.pickSide === 'black' ? '选择黑方模型' : '选择 AI 方模型')
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
        TopBar({ title: '中国象棋', subtitle: this.modeLabel(this.matchMode) })
        Scroll() {
          Column({ space: 12 }) {
            this.statusBar()
            this.chessboard()
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
          .onAreaChange((oldValue: Area, newValue: Area) => {
            const pad: number = this.isSm ? 20 : 48;
            const w: number = Math.floor(Number(newValue.width) - pad);
            const target: number = Math.min(Math.max(w, 270), 430);
            if (target > 0 && Math.abs(target - this.boardWidth) > 1) {
              this.boardWidth = target;
              this.redrawBoard();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(Color.Transparent)

      this.setupDialog()
      this.modelPickerDialog()
    }
    .width('100%')
    .height('100%')
  }
}
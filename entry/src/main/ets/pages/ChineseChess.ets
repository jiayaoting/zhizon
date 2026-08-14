// 智子 - 中国象棋（人机 / 人对AI / AI对AI）
import { promptAction, router } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchResult, GameRouteParams } from '../common/Difficulty';
import { GameAIService, GameAction } from '../service/GameAIService';
import { ChineseChessEngine, ChineseChessMove, CHESS_COLS, CHESS_ROWS } from '../service/ChineseChessEngine';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';
import { DataRepository } from '../service/DataRepository';

// 对弈方类型
type PlayerMode = 'human' | 'engine' | 'llm';
// 对局模式
type MatchMode = 'hvE' | 'hvL' | 'LvL';

// 悔棋快照
class BoardSnapshot {
  board: string[][];
  redTurn: boolean;

  constructor(board: string[][], redTurn: boolean) {
    this.board = board;
    this.redTurn = redTurn;
  }
}

const RED_MODEL_KEY: string = 'ccRedModelId';
const BLACK_MODEL_KEY: string = 'ccBlackModelId';
const AI_MODEL_KEY: string = 'ccAiModelId';

@Entry
@Component
struct ChineseChessPage {
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
  private aiModels: LlmModelEntry[] = [];
  private redModelIndex: number = 0;
  private blackModelIndex: number = 0;
  private redConfig: LlmConfig | null = null;
  private blackConfig: LlmConfig | null = null;
  private aiLoopActive: boolean = false;
  private aiFailCount: number = 0;
  private moveStack: BoardSnapshot[] = [];
  private configSeq: number = 0;

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
    const params: GameRouteParams | null = router.getParams() as GameRouteParams | null;
    const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.CHINESE_CHESS);
    if (!result.success || result.request === null) {
      router.back();
      return;
    }
    this.difficulty = result.request.difficulty;
    this.engineDepth = this.difficulty === DifficultyLevel.VERY_EASY ? 1 :
      this.difficulty === DifficultyLevel.EASY ? 2 :
        this.difficulty === DifficultyLevel.HARD ? 4 : 3;
    this.initAiModels();
    this.resetBoard();
  }

  onPageHide(): void {
    this.running = false;
    this.aiLoopActive = false;
  }

  private resetBoard(): void {
    this.board = ChineseChessEngine.initialBoard();
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
    this.suggestionOn = false;
  }

  private async initAiModels(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    const names: string[] = [];
    for (let i: number = 0; i < this.aiModels.length; i++) {
      names.push(GameAIService.modelLabel(this.aiModels[i]));
    }
    this.aiModelNames = names;
    this.modelsConfigured = this.aiModels.length > 0;
    // 恢复记忆的模型
    const redId: string = await DataRepository.getSetting(RED_MODEL_KEY, '');
    const blackId: string = await DataRepository.getSetting(BLACK_MODEL_KEY, '');
    const aiId: string = await DataRepository.getSetting(AI_MODEL_KEY, '');
    for (let i: number = 0; i < this.aiModels.length; i++) {
      if (this.aiModels[i].id === redId) this.redModelIndex = i;
      if (this.aiModels[i].id === blackId) this.blackModelIndex = i;
      if (this.aiModels[i].id === aiId) this.redModelIndex = i;
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
    this.redConfig = await this.loadModelConfig(this.redModelIndex);
    this.blackConfig = await this.loadModelConfig(this.blackModelIndex);
    this.setupOpen = false;
    this.running = true;
    this.aiLoopActive = false;
    this.aiFailCount = 0;
    this.scheduleNext();
  }

  private stopGame(): void {
    this.running = false;
    this.aiLoopActive = false;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.suggestionOn = false;
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
      this.stopGame();
    });
  }

  // AI 决策（本地引擎 / LLM）
  private async thinkFor(side: string): Promise<void> {
    if (this.aiLoopActive) return;
    this.aiLoopActive = true;
    const type: PlayerMode = this.playerType(side);
    this.thinkingSide = side;
    this.thinkingText = (this.sideLabel(side) + '思考中…') +
      (type === 'engine' ? '（本地引擎）' : '（' + this.aiModelLabel(side) + '）');
    let move: ChineseChessMove | null = null;
    if (type === 'engine') {
      // 本地引擎：深拷贝棋盘，避免在搜索中修改 @State
      const snapshot: string[][] = ChineseChessEngine.cloneBoard(this.board);
      move = ChineseChessEngine.searchBest(snapshot, side === 'red', this.engineDepth);
    } else {
      const config: LlmConfig | null = side === 'red' ? this.redConfig : this.blackConfig;
      if (config === null) {
        this.stopGame();
        promptAction.showToast({ message: '模型配置无效' });
        this.aiLoopActive = false;
        return;
      }
      const stateText: string = GameAIService.serializeChineseChess(this.board, side === 'red');
      const messages = GameAIService.buildMessages('ChineseChess', this.difficulty, stateText);
      const result = await GameAIService.decide(config, messages, 'ChineseChess');
      this.aiLoopActive = false;
      if (!this.running || this.gameOver) return;
      if (!result.success) {
        this.aiFailCount += 1;
        if (this.aiFailCount >= 3) {
          this.stopGame();
          promptAction.showToast({ message: 'AI 连续失败，已停止' });
          return;
        }
        this.thinkingSide = '';
        this.thinkingText = '';
        this.scheduleNext();
        return;
      }
      this.aiFailCount = 0;
      const action: GameAction | null = GameAIService.parseAction('ChineseChess', result.content);
      // 坐标映射：r=fromRow, c=fromCol, value=toRow, toRow=toCol
      if (action !== null) {
        move = new ChineseChessMove(action.r, action.c, action.value, action.toRow);
      }
      if (move === null || !this.isLegal(move)) {
        // AI 走法非法：重试一次
        this.thinkingSide = '';
        this.thinkingText = '';
        this.scheduleNext();
        return;
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
    // 保存悔棋快照
    this.moveStack.push(new BoardSnapshot(ChineseChessEngine.cloneBoard(this.board), this.redTurn));
    const nb: string[][] = ChineseChessEngine.cloneBoard(this.board);
    const piece: string = nb[move.fromRow][move.fromCol];
    nb[move.toRow][move.toCol] = piece;
    nb[move.fromRow][move.fromCol] = '.';
    this.board = nb;
    // 记谱
    const side: string = this.redTurn ? '红' : '黑';
    const step: number = this.moveHistory.length / 2 + (this.redTurn ? 1 : 0);
    this.moveHistory = this.moveHistory.concat(
      this.sideLabel(side) + '' + this.pieceName(piece) + ' ' +
      move.fromRow.toString() + ',' + move.fromCol.toString() + '→' +
      move.toRow.toString() + ',' + move.toCol.toString());
    this.selR = -1;
    this.selC = -1;
    this.legalTargets = [];
    this.suggestionOn = false;
    // 切换回合方
    this.redTurn = !this.redTurn;
    // 胜负/无子判断
    const nextSide: string = this.currentSide();
    const nextMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(this.board, nextSide === 'red');
    if (nextMoves.length === 0) {
      this.finishGame(this.sideLabel(side) + '胜');
      return;
    }
    this.scheduleNext();
  }

  private finishGame(msg: string): void {
    this.gameOver = true;
    this.running = false;
    this.thinkingSide = '';
    this.thinkingText = '';
    this.suggestionOn = false;
    this.winner = msg;
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
    this.gameOver = false;
    this.winner = '';
    this.thinkingSide = '';
    this.thinkingText = '';
    // 回退记谱
    if (this.moveHistory.length > 0) {
      this.moveHistory = this.moveHistory.slice(0, this.moveHistory.length - 1);
    }
    this.scheduleNext();
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
      move = ChineseChessEngine.searchBest(snapshot, side === 'red', this.engineDepth);
    } else {
      const config: LlmConfig | null = side === 'red' ? this.redConfig : this.blackConfig;
      if (config !== null) {
        const stateText: string = GameAIService.serializeChineseChess(this.board, side === 'red');
        const messages = GameAIService.buildMessages('ChineseChess', this.difficulty, stateText);
        const result = await GameAIService.decide(config, messages, 'ChineseChess');
        if (seq !== this.suggestSeq) return;
        if (result.success) {
          const action: GameAction | null = GameAIService.parseAction('ChineseChess', result.content);
          if (action !== null) {
            const m: ChineseChessMove = new ChineseChessMove(action.r, action.c, action.value, action.toRow);
            if (this.isLegal(m)) move = m;
          }
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

  private aiModelLabel(side: string): string {
    const idx: number = side === 'red' ? this.redModelIndex : this.blackModelIndex;
    if (idx >= 0 && idx < this.aiModelNames.length) return this.aiModelNames[idx];
    return '模型';
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
        Text(this.statusTitle())
          .fontSize(this.palette.fsMd)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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

      // 棋子层
      Column() {
        ForEach(this.board, (row: string[], r: number) => {
          Row() {
            ForEach(row, (piece: string, c: number) => {
              this.cell(piece, r, c)
            }, (piece: string, c: number) => r.toString() + '_' + c.toString())
          }
          .width('100%')
        }, (row: string[], r: number) => r.toString())
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
      if (piece !== '.') {
        this.piece(piece)
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

  @Builder
  piece(p: string) {
    Stack() {
      Circle()
        .width('100%')
        .height('100%')
        .fill('#F9EFD7')
        .stroke(ChineseChessEngine.isRed(p) ? '#B71C1C' : '#263238')
        .strokeWidth(1.6)
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
    if (this.thinkingSide !== '') return '⏳ ' + this.thinkingText;
    return '🎯 轮到 ' + this.sideLabel(this.currentSide()) +
      (this.playerType(this.currentSide()) === 'human' ? '（你）' : '（AI）');
  }

  private statusSubtitle(): string {
    if (this.gameOver) return '点击「结束」可重新开始对局';
    if (this.thinkingSide !== '') return 'AI 正在分析最佳走法…';
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
        this.actionBtn('✕', '结束', this.palette.danger, Color.White,
          () => { this.stopGame(); this.setupOpen = true; })
      }
      .width('100%')
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
        Scroll() {
          Text('📜 ' + this.moveHistory.join('  '))
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .width('100%')
        }
        .width('100%')
        .height(46)
        .scrollBar(BarState.Off)
        .padding(10)
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(this.palette.radiusLg)
      }
    }
    .width('100%')
  }

  @Builder
  actionBtn(icon: string, label: string, bg: string, fg: string, onTap: () => void) {
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
  miniBtn(label: string, bg: string, fg: string, onTap: () => void) {
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
      Stack() {
        Column() {
          Blank()
          Column({ space: 16 }) {
            Row() {
              Text('⚔ 对局设置')
                .fontSize(this.palette.fsLg)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              Text('✕')
                .fontSize(this.palette.fsBase)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .padding(8)
                .backgroundColor(this.palette.bgSurface2)
                .borderRadius(8)
                .onClick(() => { this.setupOpen = false; this.running = false; })
            }
            .width('100%')

            this.settingLabel('对局模式')
            Row({ space: 8 }) {
              this.seg('人机', 'hvE')
              this.seg('人对AI', 'hvL')
              this.seg('AI对AI', 'LvL')
            }
            .width('100%')

            if (this.matchMode !== 'LvL') {
              this.settingLabel('执子方')
              Row({ space: 8 }) {
                this.seg('执红', 'red')
                this.seg('执黑', 'black')
                this.seg('随机', 'random')
              }
              .width('100%')
            }

            this.settingLabel('悔棋次数')
            Row({ space: 8 }) {
              this.seg('0', '0')
              this.seg('3', '3')
              this.seg('5', '5')
              this.seg('不限', 'unlimited')
            }
            .width('100%')

            if (this.matchMode === 'hvE') {
              this.settingLabel('引擎难度')
              Row({ space: 8 }) {
                this.seg('简单', 'easy')
                this.seg('中等', 'medium')
                this.seg('困难', 'hard')
              }
              .width('100%')
            }

            if (this.matchMode === 'hvL') {
              this.settingLabel('AI 方模型')
              this.modelPicker('AI 方', this.redModelIndex, (idx: number): void => {
                this.redModelIndex = idx;
                DataRepository.setSetting(AI_MODEL_KEY, this.aiModels[idx].id);
              })
            } else if (this.matchMode === 'LvL') {
              this.settingLabel('AI 模型')
              this.modelPicker('红方模型', this.redModelIndex, (idx: number): void => {
                this.redModelIndex = idx;
                DataRepository.setSetting(RED_MODEL_KEY, this.aiModels[idx].id);
              })
              this.modelPicker('黑方模型', this.blackModelIndex, (idx: number): void => {
                this.blackModelIndex = idx;
                DataRepository.setSetting(BLACK_MODEL_KEY, this.aiModels[idx].id);
              })
            }
            this.actionBtn('🚀', '开始对局', this.palette.primary, Color.White,
              () => { this.onSetupConfirm(); })
          }
          .width('100%')
          .padding(20)
          .padding({ bottom: Math.max(20, this.navBarHeight) })
          .backgroundColor(this.palette.bgBase)
          .borderRadius({ topLeft: 24, topRight: 24 })
          .shadow({ radius: 24, color: '#33000000', offsetY: -4 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.45)')
    }
  }

  @Builder
  settingLabel(text: string) {
    Text(text)
      .fontSize(this.palette.fsXs)
      .fontFamily(this.palette.fontSans)
      .fontColor(this.palette.textTertiary)
      .margin({ top: 4 })
  }

  @Builder
  seg(label: string, value: string) {
    Text(label)
      .fontSize(this.palette.fsSm)
      .fontFamily(this.palette.fontSans)
      .fontColor(this.segActive(value) ? Color.White : this.palette.textSecondary)
      .fontWeight(this.segActive(value) ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 13, right: 13, top: 8, bottom: 8 })
      .borderRadius(10)
      .backgroundColor(this.segActive(value) ? this.palette.primary : this.palette.bgSurface2)
      .shadow(this.segActive(value) ?
        { radius: 8, color: this.palette.primary + '66', offsetX: 0, offsetY: 3 } :
        { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
      .onClick(() => { this.segTap(value); })
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
  modelPicker(title: string, index: number, onPick: (idx: number) => void) {
    Row({ space: 10 }) {
      Text(title)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
        .layoutWeight(1)
      Text(this.aiModelNames.length > index ? this.aiModelNames[index] : '未配置')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.modelsConfigured ? this.palette.textPrimary : this.palette.textTertiary)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(9)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => {
          if (!this.modelsConfigured || this.aiModels.length === 0) return;
          const next: number = (index + 1) % this.aiModels.length;
          onPick(next);
        })
      Text('切换')
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
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
            const w: number = Math.floor(newValue.width - pad);
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
    }
    .width('100%')
    .height('100%')
  }
}
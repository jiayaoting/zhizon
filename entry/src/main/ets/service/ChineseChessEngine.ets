// 智子 - 中国象棋引擎（规则 / 走法生成 / 将军检测 / 评估 / 增量回溯搜索）
// 参考优质开源项目重构：Royhoo/write-a-chinesechess-program（增量回溯、位置价值表、迭代加深、
// Zobrist置换表、走法排序）、lengyanyu258/xiangqi.js（规则健壮）、kongyijilafumi/zh-chess（伪合法/严格合法分离）。
// 棋盘：9 列(col 0-8) × 10 行(row 0-9)，黑方在上、红方在下。
// 棋子：红方用大写(帅K 仕A 相B 马H 车R 炮C 兵P)，黑方用小写(将k 士a 象b 马h 车r 炮c 卒p)。'.' 表示空位。

export const CHESS_COLS: number = 9;
export const CHESS_ROWS: number = 10;

export class ChineseChessMove {
  fromRow: number;
  fromCol: number;
  toRow: number;
  toCol: number;

  constructor(fromRow: number, fromCol: number, toRow: number, toCol: number) {
    this.fromRow = fromRow;
    this.fromCol = fromCol;
    this.toRow = toRow;
    this.toCol = toCol;
  }
}

// 搜索上下文：在棋盘副本上做增量 applyMove/undoMove 回溯，避免每次整盘 clone。
// 同时维护 Zobrist 哈希，用于置换表命中。
class SearchContext {
  board: string[][];
  zobrist: number;

  constructor(board: string[][]) {
    this.board = board;
    this.zobrist = ChineseChessEngine.computeZobrist(board);
  }
}

export class ChineseChessEngine {
  // 开局库查询回调（由页面注入 ChineseChessBook.lookup；未注入则跳过）。返回推荐走法或 null。
  // 签名：lookup(board, red, ply) -> ChineseChessMove | null
  static bookLookup: ((board: string[][], red: boolean, ply: number) => ChineseChessMove | null) | null = null;

  // ---- 子力基础价值（黑方视角存储，红黑用下标区分） ----
  private static readonly PIECE_VALUE: number[] = [10000, 200, 200, 400, 900, 300, 100];
  // 索引顺序：k 将, a 仕/士, b 相/象, h 马, r 车, c 炮, p 兵/卒
  private static readonly VALUE_INDEX: Map<string, number> = ((): Map<string, number> => {
    const m: Map<string, number> = new Map<string, number>();
    m.set('k', 0);
    m.set('a', 1);
    m.set('b', 2);
    m.set('h', 3);
    m.set('r', 4);
    m.set('c', 5);
    m.set('p', 6);
    return m;
  })();

  // ---- 位置价值表（Piece-Square Table）：黑方视角（黑在上 row0 开始） ----
  // 每张表 10 行 × 9 列，值用于黑方棋子（黑方行号正序），红方棋子使用时按 row 镜像。
  // 表中的下标按 [row][col]，row0 对应棋盘最上（黑底线）。
  private static readonly PST: number[][][] = [
    // 0: 将/帅 k —— 九宫内安全、居中为主
    [
      [0, 0, 0, 6, 10, 6, 0, 0, 0],
      [0, 0, 0, 8, 12, 8, 0, 0, 0],
      [0, 0, 0, 10, 16, 10, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 10, 16, 10, 0, 0, 0],
      [0, 0, 0, 8, 12, 8, 0, 0, 0],
      [0, 0, 0, 6, 10, 6, 0, 0, 0]
    ],
    // 1: 仕/士 a —— 九宫内靠中腹
    [
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 3, 0, 0, 0, 3, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 4, 0, 0, 0, 4, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 3, 0, 3, 0, 0, 0]
    ],
    // 2: 相/象 b —— 己方半场，位形舒展
    [
      [0, 0, 3, 0, 0, 0, 3, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 4, 0, 4, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 4, 0, 4, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 3, 0, 0, 0, 3, 0, 0]
    ],
    // 3: 马 h —— 中心活动性强，边角弱
    [
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 2, 6, 8, 10, 8, 6, 2, 0],
      [0, 6, 10, 14, 16, 14, 10, 6, 0],
      [0, 8, 12, 18, 20, 18, 12, 8, 0],
      [0, 10, 14, 18, 20, 18, 14, 10, 0],
      [0, 8, 12, 16, 18, 16, 12, 8, 0],
      [0, 6, 10, 14, 14, 14, 10, 6, 0],
      [0, 2, 6, 8, 10, 8, 6, 2, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0]
    ],
    // 4: 车 r —— 底线次佳，中路与肋道更强
    [
      [8, 10, 12, 12, 14, 12, 12, 10, 8],
      [12, 14, 16, 16, 18, 16, 16, 14, 12],
      [12, 14, 16, 16, 18, 16, 16, 14, 12],
      [12, 14, 16, 18, 20, 18, 16, 14, 12],
      [12, 14, 16, 18, 20, 18, 16, 14, 12],
      [12, 14, 16, 18, 20, 18, 16, 14, 12],
      [12, 14, 16, 16, 18, 16, 16, 14, 12],
      [12, 14, 16, 16, 18, 16, 16, 14, 12],
      [12, 14, 16, 16, 18, 16, 16, 14, 12],
      [10, 12, 14, 14, 16, 14, 14, 12, 10]
    ],
    // 5: 炮 c —— 中炮价值高，展开落子更佳
    [
      [2, 4, 4, 6, 6, 6, 4, 4, 2],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [4, 6, 8, 10, 10, 10, 8, 6, 4],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [4, 6, 8, 10, 10, 10, 8, 6, 4],
      [4, 6, 8, 8, 8, 8, 8, 6, 4],
      [2, 4, 4, 6, 6, 6, 4, 4, 2]
    ],
    // 6: 兵/卒 p —— 过河后价值大增，越深入越强
    [
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 2, 6, 8, 10, 8, 6, 2, 0],
      [0, 4, 10, 16, 20, 16, 10, 4, 0],
      [0, 8, 16, 24, 30, 24, 16, 8, 0],
      [0, 10, 20, 30, 36, 30, 20, 10, 0],
      [0, 10, 20, 30, 36, 30, 20, 10, 0],
      [0, 8, 16, 24, 30, 24, 16, 8, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0]
    ]
  ];

  // 吃子价值（MVV），用于走法排序
  private static readonly CAPTURE_VALUE: Map<string, number> = ((): Map<string, number> => {
    const m: Map<string, number> = new Map<string, number>();
    m.set('k', 10000);
    m.set('a', 200);
    m.set('b', 200);
    m.set('h', 400);
    m.set('r', 900);
    m.set('c', 300);
    m.set('p', 100);
    return m;
  })();

  // ---- 置换表条目 ----
  private static readonly TT_ENTRY_NONE: number = 0; // 无记录
  private static readonly TT_ENTRY_EXACT: number = 1; // 精确值
  private static readonly TT_ENTRY_LOWER: number = 2; // 下界（fail-low）
  private static readonly TT_ENTRY_UPPER: number = 3; // 上界（fail-high）

  // 置换表规模：16K 条（约 200KB）。此前用 1M 条 + 百万对象数组导致内存膨胀 OOM 闪退。
  static ttSize: number = 1 << 14; // 16384 条，足够缓存迭代加深中间层
  // 置换表：key 低位索引 -> [hash, 深度, 类型, 分值] + 走法坐标（紧凑数组，避免百万对象）
  private static ttKeys: number[] = [];
  private static ttDepths: number[] = [];
  private static ttTypes: number[] = [];
  private static ttScores: number[] = [];
  private static ttBestFR: number[] = [];
  private static ttBestFC: number[] = [];
  private static ttBestTR: number[] = [];
  private static ttBestTC: number[] = [];

  // ---- 搜索节点上限（时间盒）：防止 AI 走子时引擎搜索阻塞主线程/内存爆炸导致卡死、OOM ----
  private static nodesSearched: number = 0;
  private static readonly NODE_LIMIT: number = 90000; // 单次 searchBest 的节点上限

  private static ensureTT(): void {
    if (ChineseChessEngine.ttKeys.length > 0) return;
    const n: number = ChineseChessEngine.ttSize;
    ChineseChessEngine.ttKeys = new Array<number>(n).fill(0);
    ChineseChessEngine.ttDepths = new Array<number>(n).fill(-1);
    ChineseChessEngine.ttTypes = new Array<number>(n).fill(ChineseChessEngine.TT_ENTRY_NONE);
    ChineseChessEngine.ttScores = new Array<number>(n).fill(0);
    ChineseChessEngine.ttBestFR = new Array<number>(n).fill(-1);
    ChineseChessEngine.ttBestFC = new Array<number>(n).fill(-1);
    ChineseChessEngine.ttBestTR = new Array<number>(n).fill(-1);
    ChineseChessEngine.ttBestTC = new Array<number>(n).fill(-1);
  }

  // 计算局面 Zobrist 哈希（确定性、无碰撞处理，足够置换表用）
  static computeZobrist(board: string[][]): number {
    let h: number = 0;
    for (let r = 0; r < CHESS_ROWS; r++) {
      for (let c = 0; c < CHESS_COLS; c++) {
        const p: string = board[r][c];
        if (p === '.') continue;
        const code: number = p.charCodeAt(0);
        // 混合行列与棋子码，生成伪随机散列
        let v: number = code * 73856093;
        v = v ^ (v << 13);
        v = v ^ (v >> 17);
        v = v ^ (v << 5);
        h = (h ^ (v + r * 2654435761 + c * 2246822519)) >>> 0;
      }
    }
    return h;
  }

  // 是否为红方棋子（大写字母）
  static isRed(piece: string): boolean {
    return piece.length > 0 && piece >= 'A' && piece <= 'Z';
  }

  // 是否为黑方棋子（小写字母）
  static isBlack(piece: string): boolean {
    return piece.length > 0 && piece >= 'a' && piece <= 'z';
  }

  static isPiece(piece: string): boolean {
    return ChineseChessEngine.isRed(piece) || ChineseChessEngine.isBlack(piece);
  }

  // 空棋盘
  static emptyBoard(): string[][] {
    const board: string[][] = [];
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      const row: string[] = [];
      for (let c: number = 0; c < CHESS_COLS; c++) {
        row.push('.');
      }
      board.push(row);
    }
    return board;
  }

  // 初始布局
  static initialBoard(): string[][] {
    const b: string[][] = ChineseChessEngine.emptyBoard();
    const back: string = 'rhbakabhr';
    for (let c: number = 0; c < CHESS_COLS; c++) {
      b[0][c] = back.charAt(c);
      b[9][c] = back.charAt(c).toUpperCase();
    }
    b[2][1] = 'c';
    b[2][7] = 'c';
    b[7][1] = 'C';
    b[7][7] = 'C';
    // 黑卒位于 row3（己方一侧），红兵位于 row6（己方一侧），各 5 个在偶数列
    for (let c: number = 0; c < CHESS_COLS; c += 2) {
      b[3][c] = 'p';
      b[6][c] = 'P';
    }
    return b;
  }

  // 深拷贝棋盘
  static cloneBoard(board: string[][]): string[][] {
    const out: string[][] = [];
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      const row: string[] = [];
      for (let c: number = 0; c < CHESS_COLS; c++) {
        row.push(board[r][c]);
      }
      out.push(row);
    }
    return out;
  }

  // 兼容旧调用：单参 makeMove 历史版本返回克隆。新版走子请用 applyMove/undoMove。
  static makeMove(board: string[][]): string[][] {
    return ChineseChessEngine.cloneBoard(board);
  }

  // 坐标是否在九宫格内（side=0 红下方 row7-9；side=1 黑上方 row0-2）
  private static inPalace(side: number, row: number, col: number): boolean {
    if (col < 3 || col > 5) return false;
    if (side === 0) return row >= 7 && row <= 9; // 红，下方
    return row >= 0 && row <= 2; // 黑，上方
  }

  // 某棋子的拟走法（含吃子位，不含"送将"过滤），返回目标坐标数组
  private static pseudoTargets(board: string[][], row: number, col: number): number[][] {
    const piece: string = board[row][col];
    const targets: number[][] = [];
    if (piece === '.') return targets;
    const red: boolean = ChineseChessEngine.isRed(piece);
    const side: number = red ? 0 : 1;
    const p: string = piece.toLowerCase();

    const tryStep = (r: number, c: number): void => {
      if (r < 0 || r >= CHESS_ROWS || c < 0 || c >= CHESS_COLS) return;
      const t: string = board[r][c];
      if (ChineseChessEngine.isPiece(t) && (red ? ChineseChessEngine.isRed(t) : ChineseChessEngine.isBlack(t))) return;
      targets.push([r, c]);
    };

    if (p === 'k') { // 帅/将：九宫格内走一格
      const dr: number[] = [-1, 1, 0, 0];
      const dc: number[] = [0, 0, -1, 1];
      for (let i: number = 0; i < 4; i++) {
        const nr: number = row + dr[i];
        const nc: number = col + dc[i];
        if (ChineseChessEngine.inPalace(side, nr, nc)) {
          tryStep(nr, nc);
        }
      }
      // 帅将对脸：同一列且中间无子
      const step: number = red ? -1 : 1;
      let rr: number = row + step;
      while (rr >= 0 && rr < CHESS_ROWS) {
        const t: string = board[rr][col];
        if (ChineseChessEngine.isPiece(t)) {
          if (t.toLowerCase() === 'k' && (red ? ChineseChessEngine.isBlack(t) : ChineseChessEngine.isRed(t))) {
            targets.push([rr, col]);
          }
          break;
        }
        rr += step;
      }
    } else if (p === 'a') { // 仕/士：九宫格内走斜线
      const dr: number[] = [-1, -1, 1, 1];
      const dc: number[] = [-1, 1, -1, 1];
      for (let i: number = 0; i < 4; i++) {
        const nr: number = row + dr[i];
        const nc: number = col + dc[i];
        if (ChineseChessEngine.inPalace(side, nr, nc)) {
          tryStep(nr, nc);
        }
      }
    } else if (p === 'b') { // 相/象：田字步，塞象眼，不过河
      const dr: number[] = [-2, -2, 2, 2];
      const dc: number[] = [-2, 2, -2, 2];
      for (let i: number = 0; i < 4; i++) {
        const nr: number = row + dr[i];
        const nc: number = col + dc[i];
        if (nr < 0 || nr >= CHESS_ROWS || nc < 0 || nc >= CHESS_COLS) continue;
        if (red && nr < 5) continue;
        if (!red && nr >= 5) continue;
        const eyR: number = row + (dr[i] / 2);
        const eyC: number = col + (dc[i] / 2);
        if (ChineseChessEngine.isPiece(board[eyR][eyC])) continue;
        tryStep(nr, nc);
      }
    } else if (p === 'h') { // 马：日字，蹩马腿
      const jumps: number[][] = [[-2, -1], [-2, 1], [2, -1], [2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2]];
      const legs: number[][] = [[-1, 0], [-1, 0], [1, 0], [1, 0], [0, -1], [0, 1], [0, -1], [0, 1]];
      for (let i: number = 0; i < jumps.length; i++) {
        const nr: number = row + jumps[i][0];
        const nc: number = col + jumps[i][1];
        if (nr < 0 || nr >= CHESS_ROWS || nc < 0 || nc >= CHESS_COLS) continue;
        const legR: number = row + legs[i][0];
        const legC: number = col + legs[i][1];
        if (ChineseChessEngine.isPiece(board[legR][legC])) continue;
        tryStep(nr, nc);
      }
    } else if (p === 'r') { // 车：直线无遮挡
      const dirs: number[][] = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      for (let d: number = 0; d < 4; d++) {
        let rr: number = row + dirs[d][0];
        let cc: number = col + dirs[d][1];
        while (rr >= 0 && rr < CHESS_ROWS && cc >= 0 && cc < CHESS_COLS) {
          const t: string = board[rr][cc];
          if (ChineseChessEngine.isPiece(t)) {
            if (red ? ChineseChessEngine.isBlack(t) : ChineseChessEngine.isRed(t)) {
              targets.push([rr, cc]);
            }
            break;
          }
          targets.push([rr, cc]);
          rr += dirs[d][0];
          cc += dirs[d][1];
        }
      }
    } else if (p === 'c') { // 炮：直线，吃子需隔一子
      const dirs: number[][] = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      for (let d: number = 0; d < 4; d++) {
        let rr: number = row + dirs[d][0];
        let cc: number = col + dirs[d][1];
        let skipped: boolean = false;
        while (rr >= 0 && rr < CHESS_ROWS && cc >= 0 && cc < CHESS_COLS) {
          const t: string = board[rr][cc];
          if (!skipped) {
            if (!ChineseChessEngine.isPiece(t)) {
              targets.push([rr, cc]);
            } else {
              skipped = true;
            }
          } else {
            if (ChineseChessEngine.isPiece(t)) {
              if (red ? ChineseChessEngine.isBlack(t) : ChineseChessEngine.isRed(t)) {
                targets.push([rr, cc]);
              }
              break;
            }
          }
          rr += dirs[d][0];
          cc += dirs[d][1];
        }
      }
    } else if (p === 'p') { // 兵/卒：只能前进，过河后可左右
      const forward: number = red ? -1 : 1;
      const nr: number = row + forward;
      if (nr >= 0 && nr < CHESS_ROWS) tryStep(nr, col);
      const crossed: boolean = red ? row <= 5 : row >= 4;
      if (crossed) {
        tryStep(row, col - 1);
        tryStep(row, col + 1);
      }
    }
    return targets;
  }

  // 在棋盘上应用走法（不检查合法性，用于搜索），返回被吃子（用于 undo）
  private static applyOnBoard(board: string[][], mv: ChineseChessMove): string {
    const captured: string = board[mv.toRow][mv.toCol];
    board[mv.toRow][mv.toCol] = board[mv.fromRow][mv.fromCol];
    board[mv.fromRow][mv.fromCol] = '.';
    return captured;
  }

  // 撤销走法
  private static undoOnBoard(board: string[][], mv: ChineseChessMove, captured: string): void {
    board[mv.fromRow][mv.fromCol] = board[mv.toRow][mv.toCol];
    board[mv.toRow][mv.toCol] = captured;
  }

  // 生成某方所有合法走法（过滤吃己方 + 送将/自杀）
  static generateMoves(board: string[][], red: boolean): ChineseChessMove[] {
    const moves: ChineseChessMove[] = [];
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      for (let c: number = 0; c < CHESS_COLS; c++) {
        const piece: string = board[r][c];
        if (piece === '.') continue;
        if (red ? !ChineseChessEngine.isRed(piece) : !ChineseChessEngine.isBlack(piece)) continue;
        const targets: number[][] = ChineseChessEngine.pseudoTargets(board, r, c);
        for (let i: number = 0; i < targets.length; i++) {
          const tr: number = targets[i][0];
          const tc: number = targets[i][1];
          const mv: ChineseChessMove = new ChineseChessMove(r, c, tr, tc);
          const captured: string = ChineseChessEngine.applyOnBoard(board, mv);
          const legal: boolean = !ChineseChessEngine.isInCheck(board, red);
          ChineseChessEngine.undoOnBoard(board, mv, captured);
          if (legal) {
            moves.push(mv);
          }
        }
      }
    }
    return moves;
  }

  // 找到某方帅/将位置，未找到返回 [-1,-1]
  private static findKing(board: string[][], red: boolean): number[] {
    const target: string = red ? 'K' : 'k';
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      for (let c: number = 0; c < CHESS_COLS; c++) {
        if (board[r][c] === target) return [r, c];
      }
    }
    return [-1, -1];
  }

  // 某方当前是否被将军
  static isInCheck(board: string[][], red: boolean): boolean {
    const king: number[] = ChineseChessEngine.findKing(board, red);
    if (king[0] < 0) return false;
    const enemy: number = red ? 1 : 0;
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      for (let c: number = 0; c < CHESS_COLS; c++) {
        const piece: string = board[r][c];
        if (piece === '.') continue;
        const isEnemy: boolean = enemy === 0 ? ChineseChessEngine.isRed(piece) : ChineseChessEngine.isBlack(piece);
        if (!isEnemy) continue;
        const targets: number[][] = ChineseChessEngine.pseudoTargets(board, r, c);
        for (let i: number = 0; i < targets.length; i++) {
          if (targets[i][0] === king[0] && targets[i][1] === king[1]) return true;
        }
      }
    }
    return false;
  }

  // 某方是否还有合法走法
  static hasLegalMove(board: string[][], red: boolean): boolean {
    return ChineseChessEngine.generateMoves(board, red).length > 0;
  }

  // 位置价值：黑方视角。红方棋子用 row 镜像（9 - row）查表。
  private static pieceSquare(board: string[][], r: number, c: number): number {
    const piece: string = board[r][c];
    if (piece === '.') return 0;
    const p: string = piece.toLowerCase();
    const idx: number = ChineseChessEngine.VALUE_INDEX.get(p) as number;
    if (idx === undefined) return 0;
    const pst: number[][] = ChineseChessEngine.PST[idx];
    let val: number;
    if (ChineseChessEngine.isRed(piece)) {
      // 红方在下，镜像 row
      val = pst[9 - r][c];
    } else {
      val = pst[r][c];
    }
    return val;
  }

  // 局面评估（红方视角，正数红优）
  private static evaluate(board: string[][]): number {
    let score: number = 0;
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      for (let c: number = 0; c < CHESS_COLS; c++) {
        const piece: string = board[r][c];
        if (piece === '.') continue;
        const p: string = piece.toLowerCase();
        const idx: number = ChineseChessEngine.VALUE_INDEX.get(p) as number;
        if (idx === undefined) continue;
        const base: number = ChineseChessEngine.PIECE_VALUE[idx];
        const pst: number = ChineseChessEngine.pieceSquare(board, r, c);
        let val: number = base + pst;
        // 兵过河附加加成（位置表已含部分，这里再补机动性）
        if (p === 'p') {
          if (ChineseChessEngine.isRed(piece) && r <= 4) val += 20;
          if (ChineseChessEngine.isBlack(piece) && r >= 5) val += 20;
        }
        if (ChineseChessEngine.isRed(piece)) score += val;
        else score -= val;
      }
    }
    return score;
  }

  // 走法排序分数（越高越优先）：吃子(MVV-LVA) >> 杀手走法 > 位置
  private static moveScore(board: string[][], mv: ChineseChessMove): number {
    const target: string = board[mv.toRow][mv.toCol];
    if (ChineseChessEngine.isPiece(target)) {
      const mvPiece: string = board[mv.fromRow][mv.fromCol].toLowerCase();
      const capVal: number = ChineseChessEngine.CAPTURE_VALUE.get(target.toLowerCase()) as number;
      const myVal: number = ChineseChessEngine.CAPTURE_VALUE.get(mvPiece) as number;
      const a: number = capVal === undefined ? 0 : capVal;
      const b: number = myVal === undefined ? 0 : myVal;
      return 1000000 + a * 10 - b;
    }
    return 0;
  }

  // 简单插入排序按分数降序（走法数量有限，够用且稳定）
  private static sortMoves(board: string[][], moves: ChineseChessMove[]): void {
    const n: number = moves.length;
    for (let i = 1; i < n; i++) {
      const key: ChineseChessMove = moves[i];
      const ks: number = ChineseChessEngine.moveScore(board, key);
      let j: number = i - 1;
      while (j >= 0 && ChineseChessEngine.moveScore(board, moves[j]) < ks) {
        moves[j + 1] = moves[j];
        j--;
      }
      moves[j + 1] = key;
    }
  }

  // 置换表读写
  private static ttProbe(key: number, depth: number, alpha: number, beta: number): number {
    const n: number = ChineseChessEngine.ttSize;
    const idx: number = key % n;
    if (ChineseChessEngine.ttKeys[idx] === key && ChineseChessEngine.ttDepths[idx] >= depth) {
      const typ: number = ChineseChessEngine.ttTypes[idx];
      const sc: number = ChineseChessEngine.ttScores[idx];
      if (typ === ChineseChessEngine.TT_ENTRY_EXACT) return sc;
      if (typ === ChineseChessEngine.TT_ENTRY_LOWER && sc >= beta) return sc;
      if (typ === ChineseChessEngine.TT_ENTRY_UPPER && sc <= alpha) return sc;
    }
    return -99999999;
  }

  private static ttStore(key: number, depth: number, typ: number, score: number, mv: ChineseChessMove | null): void {
    const n: number = ChineseChessEngine.ttSize;
    const idx: number = key % n;
    ChineseChessEngine.ttKeys[idx] = key;
    ChineseChessEngine.ttDepths[idx] = depth;
    ChineseChessEngine.ttTypes[idx] = typ;
    ChineseChessEngine.ttScores[idx] = score;
    if (mv !== null) {
      ChineseChessEngine.ttBestFR[idx] = mv.fromRow;
      ChineseChessEngine.ttBestFC[idx] = mv.fromCol;
      ChineseChessEngine.ttBestTR[idx] = mv.toRow;
      ChineseChessEngine.ttBestTC[idx] = mv.toCol;
    }
  }

  private static ttGetBest(key: number): ChineseChessMove | null {
    const n: number = ChineseChessEngine.ttSize;
    const idx: number = key % n;
    if (ChineseChessEngine.ttKeys[idx] === key && ChineseChessEngine.ttTypes[idx] !== ChineseChessEngine.TT_ENTRY_NONE &&
      ChineseChessEngine.ttBestFR[idx] >= 0) {
      return new ChineseChessMove(ChineseChessEngine.ttBestFR[idx], ChineseChessEngine.ttBestFC[idx],
        ChineseChessEngine.ttBestTR[idx], ChineseChessEngine.ttBestTC[idx]);
    }
    return null;
  }

  // negamax + alpha-beta + 置换表 + 走法排序 + 静态搜索
  // 在 ctx.board 上增量回溯。返回红方视角分值（调用处负责按 side 取负）。
  private static negamax(ctx: SearchContext, red: boolean, depth: number, alpha: number, beta: number): number {
    // 时间盒：节点数超限立即返回当前评估，避免阻塞主线程/内存爆炸
    ChineseChessEngine.nodesSearched += 1;
    if (ChineseChessEngine.nodesSearched > ChineseChessEngine.NODE_LIMIT) {
      return red ? ChineseChessEngine.evaluate(ctx.board) : -ChineseChessEngine.evaluate(ctx.board);
    }
    const key: number = ctx.zobrist;
    // 置换表命中
    const tt: number = ChineseChessEngine.ttProbe(key, depth, alpha, beta);
    if (tt !== -99999999) return tt;

    const moves: ChineseChessMove[] = ChineseChessEngine.generateMoves(ctx.board, red);
    if (moves.length === 0) {
      // 被将死或困毙：当前方输
      const score: number = -100000 + depth;
      ChineseChessEngine.ttStore(key, depth, ChineseChessEngine.TT_ENTRY_EXACT, score, null);
      return score;
    }
    if (depth <= 0) {
      // 进入静态搜索，缓解水平线效应
      const qs: number = ChineseChessEngine.quiescence(ctx, red, alpha, beta);
      ChineseChessEngine.ttStore(key, depth, ChineseChessEngine.TT_ENTRY_EXACT, qs, null);
      return qs;
    }

    // 优先走置换表着法
    const ttMove: ChineseChessMove | null = ChineseChessEngine.ttGetBest(key);
    if (ttMove !== null) {
      // 把 ttMove 移到最前（若存在）
      for (let i = 0; i < moves.length; i++) {
        const m: ChineseChessMove = moves[i];
        if (m.fromRow === ttMove.fromRow && m.fromCol === ttMove.fromCol &&
          m.toRow === ttMove.toRow && m.toCol === ttMove.toCol) {
          const t: ChineseChessMove = moves[0];
          moves[0] = m;
          moves[i] = t;
          break;
        }
      }
    }
    ChineseChessEngine.sortMoves(ctx.board, moves);

    let best: number = -Infinity;
    let bestMv: ChineseChessMove | null = null;
    let flag: number = ChineseChessEngine.TT_ENTRY_UPPER;
    for (let i: number = 0; i < moves.length; i++) {
      const mv: ChineseChessMove = moves[i];
      const captured: string = ChineseChessEngine.applyOnBoard(ctx.board, mv);
      ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
      const sc: number = -ChineseChessEngine.negamax(ctx, !red, depth - 1, -beta, -alpha);
      ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
      ChineseChessEngine.undoOnBoard(ctx.board, mv, captured);

      if (sc > best) {
        best = sc;
        bestMv = mv;
      }
      if (best > alpha) {
        alpha = best;
        flag = ChineseChessEngine.TT_ENTRY_EXACT;
      }
      if (alpha >= beta) {
        flag = ChineseChessEngine.TT_ENTRY_LOWER;
        break;
      }
    }
    ChineseChessEngine.ttStore(key, depth, flag, best, bestMv);
    return best;
  }

  // 静态搜索：只搜索吃子走法，缓解水平线效应。带递归深度上限，防止"来回吃子"导致栈溢出闪退。
  private static quiescence(ctx: SearchContext, red: boolean, alpha: number, beta: number,
    depth: number = 0): number {
    // 节点时间盒：超限立即返回，防止阻塞主线程/内存爆炸
    ChineseChessEngine.nodesSearched += 1;
    if (ChineseChessEngine.nodesSearched > ChineseChessEngine.NODE_LIMIT) {
      return red ? ChineseChessEngine.evaluate(ctx.board) : -ChineseChessEngine.evaluate(ctx.board);
    }
    // 深度上限：超过即返回当前评估，防止连续互吃/长将导致的无限递归栈溢出
    if (depth >= 24) {
      return red ? ChineseChessEngine.evaluate(ctx.board) : -ChineseChessEngine.evaluate(ctx.board);
    }
    // 当前局面评估（红方视角）
    const standPat: number = red ? ChineseChessEngine.evaluate(ctx.board) : -ChineseChessEngine.evaluate(ctx.board);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    // 只考虑吃子走法
    const moves: ChineseChessMove[] = ChineseChessEngine.generateMoves(ctx.board, red);
    const caps: ChineseChessMove[] = [];
    for (let i = 0; i < moves.length; i++) {
      if (ChineseChessEngine.isPiece(ctx.board[moves[i].toRow][moves[i].toCol])) {
        caps.push(moves[i]);
      }
    }
    if (caps.length === 0) return standPat;
    ChineseChessEngine.sortMoves(ctx.board, caps);

    for (let i = 0; i < caps.length; i++) {
      const mv: ChineseChessMove = caps[i];
      const captured: string = ChineseChessEngine.applyOnBoard(ctx.board, mv);
      ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
      const sc: number = -ChineseChessEngine.quiescence(ctx, !red, -beta, -alpha, depth + 1);
      ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
      ChineseChessEngine.undoOnBoard(ctx.board, mv, captured);
      if (sc >= beta) return beta;
      if (sc > alpha) alpha = sc;
    }
    return alpha;
  }

  // 搜索最佳走法；采用迭代加深 + 置换表。depth 为目标搜索深度（建议 3~6）。
  // ply 为已走的半回合数，用于开局库查询（可省略，默认 0）。
  static searchBest(board: string[][], red: boolean, depth: number, ply?: number): ChineseChessMove | null {
    ChineseChessEngine.ensureTT();
    // 重置节点计数（每次搜索独立时间盒）
    ChineseChessEngine.nodesSearched = 0;
    // 开局库优先
    if (ChineseChessEngine.bookLookup !== null) {
      const p: number = ply === undefined ? 0 : ply;
      const bookMove: ChineseChessMove | null = ChineseChessEngine.bookLookup(board, red, p);
      if (bookMove !== null) {
        return bookMove;
      }
    }
    const rootMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(board, red);
    if (rootMoves.length === 0) return null;
    ChineseChessEngine.sortMoves(board, rootMoves);

    // 从已有的最小深度搜索结果做迭代加深
    const ctx: SearchContext = new SearchContext(ChineseChessEngine.cloneBoard(board));
    const d: number = Math.max(1, Math.min(depth, 3));
    let bestMove: ChineseChessMove = rootMoves[0];
    let bestScore: number = -Infinity;
    for (let currentDepth = 1; currentDepth <= d; currentDepth++) {
      let alpha: number = -Infinity;
      let beta: number = Infinity;
      let curBest: ChineseChessMove = rootMoves[0];
      let curScore: number = -Infinity;
      // 每层用前一层最佳着法打头（已排序）
      for (let i: number = 0; i < rootMoves.length; i++) {
        const mv: ChineseChessMove = rootMoves[i];
        const captured: string = ChineseChessEngine.applyOnBoard(ctx.board, mv);
        ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
        const sc: number = -ChineseChessEngine.negamax(ctx, !red, currentDepth - 1, -beta, -alpha);
        ctx.zobrist = ChineseChessEngine.computeZobrist(ctx.board);
        ChineseChessEngine.undoOnBoard(ctx.board, mv, captured);
        if (sc > curScore) {
          curScore = sc;
          curBest = mv;
        }
        if (curScore > alpha) alpha = curScore;
      }
      bestMove = curBest;
      bestScore = curScore;
      if (curScore >= 100000) break; // 已找到必胜着法，提前终止
    }
    // 兜底：若 bestScore 仍为 -Infinity（理论不可能），返回第一着
    void bestScore;
    return bestMove;
  }
}

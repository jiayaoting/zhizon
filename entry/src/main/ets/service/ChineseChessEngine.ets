// 智子 - 中国象棋引擎（规则 / 走法生成 / 将军检测 / 评估 / minimax+alpha-beta 搜索）
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

export class ChineseChessEngine {
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
    for (let c: number = 0; c < CHESS_COLS; c += 2) {
      b[4][c] = 'p';
      b[5][c] = 'P';
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

  // 执行走法，返回新棋盘（不修改原棋盘）
  static makeMove(board: string[][]): string[][] {
    return ChineseChessEngine.cloneBoard(board);
  }

  // 坐标是否在九宫格内
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
      // 不能吃己方
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
        // 不过河
        if (red && nr < 5) continue;
        if (!red && nr >= 5) continue;
        // 塞象眼
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
      const crossed: boolean = red ? row <= 4 : row >= 5;
      if (crossed) {
        tryStep(row, col - 1);
        tryStep(row, col + 1);
      }
    }
    return targets;
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
          // 走完不能让自己将军
          if (!ChineseChessEngine.leavesSelfInCheck(board, mv, red)) {
            moves.push(mv);
          }
        }
      }
    }
    return moves;
  }

  // 模拟走法后的棋盘
  private static applied(board: string[][], mv: ChineseChessMove): string[][] {
    const nb: string[][] = ChineseChessEngine.cloneBoard(board);
    nb[mv.toRow][mv.toCol] = nb[mv.fromRow][mv.fromCol];
    nb[mv.fromRow][mv.fromCol] = '.';
    return nb;
  }

  // 走完一步后是否把自己置于被将军状态
  private static leavesSelfInCheck(board: string[][], mv: ChineseChessMove, red: boolean): boolean {
    const nb: string[][] = ChineseChessEngine.applied(board, mv);
    return ChineseChessEngine.isInCheck(nb, red);
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
    // 对方任意棋子能否攻击到帅/将
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

  // 局面评估（红方视角，正数红优）
  private static evaluate(board: string[][]): number {
    let score: number = 0;
    const values: Map<string, number> = new Map<string, number>();
    values.set('k', 10000);
    values.set('a', 200);
    values.set('b', 200);
    values.set('h', 400);
    values.set('r', 900);
    values.set('c', 300);
    values.set('p', 100);
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      for (let c: number = 0; c < CHESS_COLS; c++) {
        const piece: string = board[r][c];
        if (piece === '.') continue;
        let val: number = values.get(piece.toLowerCase()) as number;
        if (val === undefined) val = 0;
        // 过河兵加分
        if (piece.toLowerCase() === 'p') {
          if (ChineseChessEngine.isRed(piece) && r <= 4) val += 100;
          if (ChineseChessEngine.isBlack(piece) && r >= 5) val += 100;
        }
        if (ChineseChessEngine.isRed(piece)) score += val;
        else score -= val;
      }
    }
    return score;
  }

  private static negamax(board: string[][], red: boolean, depth: number, alpha: number, beta: number): number {
    const moves: ChineseChessMove[] = ChineseChessEngine.generateMoves(board, red);
    if (moves.length === 0) {
      // 无走法：被将死则极大负分（当前方输），否则困毙也算输
      return -100000 + depth;
    }
    if (depth === 0) {
      const ev: number = ChineseChessEngine.evaluate(board);
      return red ? ev : -ev;
    }
    let best: number = -Infinity;
    for (let i: number = 0; i < moves.length; i++) {
      const nb: string[][] = ChineseChessEngine.applied(board, moves[i]);
      const sc: number = -ChineseChessEngine.negamax(nb, !red, depth - 1, -beta, -alpha);
      if (sc > best) best = sc;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  // 搜索最佳走法；depth 为搜索深度（3~4）
  static searchBest(board: string[][], red: boolean, depth: number): ChineseChessMove | null {
    const moves: ChineseChessMove[] = ChineseChessEngine.generateMoves(board, red);
    if (moves.length === 0) return null;
    let bestMove: ChineseChessMove = moves[0];
    let bestScore: number = -Infinity;
    for (let i: number = 0; i < moves.length; i++) {
      const nb: string[][] = ChineseChessEngine.applied(board, moves[i]);
      const sc: number = -ChineseChessEngine.negamax(nb, !red, depth - 1, -Infinity, Infinity);
      if (sc > bestScore) {
        bestScore = sc;
        bestMove = moves[i];
      }
    }
    return bestMove;
  }
}
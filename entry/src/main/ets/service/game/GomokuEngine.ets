// 智子 - 五子棋本地引擎（15×15 棋盘 / 胜负判定 / 模式打分 / 极小极大 + Alpha-Beta 剪枝）
// 棋子：0=空，1=黑（玩家先手），2=白（引擎后手）

export const GOMOKU_SIZE: number = 15;
export const GOMOKU_WIN_COUNT: number = 5;

// 候选落子排序条目
class MoveScore {
  move: number[];
  s: number;

  constructor(move: number[], s: number) {
    this.move = move;
    this.s = s;
  }
}

const GOMOKU_WIN_SCORE: number = 10000000;
const GOMOKU_NEG_INF: number = -1000000000;

export class GomokuEngine {
  // 空棋盘
  static createBoard(): number[][] {
    const board: number[][] = [];
    for (let r: number = 0; r < GOMOKU_SIZE; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < GOMOKU_SIZE; c++) row.push(0);
      board.push(row);
    }
    return board;
  }

  static isValidMove(board: number[][], r: number, c: number): boolean {
    if (r < 0 || r >= GOMOKU_SIZE || c < 0 || c >= GOMOKU_SIZE) return false;
    return board[r][c] === 0;
  }

  // 深拷贝棋盘（悔棋快照 / 引擎搜索用，避免修改 @State）
  static cloneBoard(board: number[][]): number[][] {
    const out: number[][] = [];
    for (let r: number = 0; r < board.length; r++) {
      const row: number[] = [];
      for (let c: number = 0; c < board[r].length; c++) row.push(board[r][c]);
      out.push(row);
    }
    return out;
  }

  // 落子（调用方保证合法）
  static place(board: number[][], r: number, c: number, player: number): void {
    board[r][c] = player;
  }

  // 从 (r,c) 出发在 (dr,dc) 方向连续同色棋子数
  private static countRun(board: number[][], r: number, c: number, player: number,
    dr: number, dc: number): number {
    let count: number = 0;
    let rr: number = r;
    let cc: number = c;
    while (rr >= 0 && rr < GOMOKU_SIZE && cc >= 0 && cc < GOMOKU_SIZE && board[rr][cc] === player) {
      count += 1;
      rr += dr;
      cc += dc;
    }
    return count;
  }

  // 落子后是否形成五连（含更长的连子）
  static checkWin(board: number[][], r: number, c: number, player: number): boolean {
    const dirs: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let d: number = 0; d < dirs.length; d++) {
      const back: number = GomokuEngine.countRun(board, r - dirs[d][0], c - dirs[d][1], player,
        -dirs[d][0], -dirs[d][1]);
      const fwd: number = GomokuEngine.countRun(board, r + dirs[d][0], c + dirs[d][1], player,
        dirs[d][0], dirs[d][1]);
      if (back + fwd + 1 >= GOMOKU_WIN_COUNT) return true;
    }
    return false;
  }

  static isBoardFull(board: number[][]): boolean {
    for (let r: number = 0; r < GOMOKU_SIZE; r++) {
      for (let c: number = 0; c < GOMOKU_SIZE; c++) {
        if (board[r][c] === 0) return false;
      }
    }
    return true;
  }

  // 有棋子的格子集合（用于生成候选）
  private static occupiedCells(board: number[][]): number[][] {
    const cells: number[][] = [];
    for (let r: number = 0; r < GOMOKU_SIZE; r++) {
      for (let c: number = 0; c < GOMOKU_SIZE; c++) {
        if (board[r][c] !== 0) cells.push([r, c]);
      }
    }
    return cells;
  }

  // 候选落子：已有棋子周围 2 格内的空位；首步取天元
  static candidateMoves(board: number[][], cap: number): number[][] {
    const occupied: number[][] = GomokuEngine.occupiedCells(board);
    if (occupied.length === 0) {
      const mid: number = Math.floor(GOMOKU_SIZE / 2);
      return [[mid, mid]];
    }
    const set: string[] = [];
    const keyOf: (r: number, c: number) => string = (r: number, c: number): string => r.toString() + '_' + c.toString();
    for (let i: number = 0; i < occupied.length; i++) {
      const r: number = occupied[i][0];
      const c: number = occupied[i][1];
      for (let dr: number = -2; dr <= 2; dr++) {
        for (let dc: number = -2; dc <= 2; dc++) {
          const nr: number = r + dr;
          const nc: number = c + dc;
          if (nr < 0 || nr >= GOMOKU_SIZE || nc < 0 || nc >= GOMOKU_SIZE) continue;
          if (board[nr][nc] !== 0) continue;
          const key: string = keyOf(nr, nc);
          if (set.indexOf(key) < 0) set.push(key);
        }
      }
    }
    const moves: number[][] = [];
    for (let i: number = 0; i < set.length; i++) {
      const parts: string[] = set[i].split('_');
      moves.push([parseInt(parts[0]), parseInt(parts[1])]);
    }
    if (cap > 0 && moves.length > cap) {
      // 用局部评分截断（仅用于候选排序，够用即可）
      moves.sort((a: number[], b: number[]): number => {
        return GomokuEngine.localScore(board, b[0], b[1], 1) +
          GomokuEngine.localScore(board, b[0], b[1], 2) -
          GomokuEngine.localScore(board, a[0], a[1], 1) -
          GomokuEngine.localScore(board, a[0], a[1], 2);
      });
      return moves.slice(0, cap);
    }
    return moves;
  }

  // 单个落点的局部打分（双方视角求和，用于候选排序）
  private static localScore(board: number[][], r: number, c: number, player: number): number {
    board[r][c] = player;
    const score: number = GomokuEngine.pointScore(board, r, c, player);
    board[r][c] = 0;
    return score;
  }

  // 以 (r,c) 为落点（已落子）时，该点对 player 的贡献分
  private static pointScore(board: number[][], r: number, c: number, player: number): number {
    let score: number = 0;
    const dirs: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let d: number = 0; d < dirs.length; d++) {
      const dr: number = dirs[d][0];
      const dc: number = dirs[d][1];
      // 双向连子
      const back: number = GomokuEngine.countRun(board, r - dr, c - dc, player, -dr, -dc);
      const fwd: number = GomokuEngine.countRun(board, r + dr, c + dc, player, dr, dc);
      const len: number = back + fwd + 1;
      // 两端开口
      let opens: number = 0;
      const br: number = r - dr * (back + 1);
      const bc: number = c - dc * (back + 1);
      const fr: number = r + dr * (fwd + 1);
      const fc: number = c + dc * (fwd + 1);
      if (br >= 0 && br < GOMOKU_SIZE && bc >= 0 && bc < GOMOKU_SIZE && board[br][bc] === 0) opens += 1;
      if (fr >= 0 && fr < GOMOKU_SIZE && fc >= 0 && fc < GOMOKU_SIZE && board[fr][fc] === 0) opens += 1;
      score += GomokuEngine.patternScore(len, opens);
    }
    return score;
  }

  // 连子长度 + 开口数 → 模式分
  private static patternScore(len: number, opens: number): number {
    if (len >= 5) return 10000000;
    if (len === 4) {
      if (opens === 2) return 1000000; // 活四：必胜
      if (opens === 1) return 100000;  // 冲四
      return 0;
    }
    if (len === 3) {
      if (opens === 2) return 10000;   // 活三
      if (opens === 1) return 1000;    // 眠三
      return 0;
    }
    if (len === 2) {
      if (opens === 2) return 500;
      if (opens === 1) return 50;
      return 0;
    }
    if (len === 1) {
      if (opens === 2) return 20;
      return 5;
    }
    return 0;
  }

  // 全盘评估（正值为 aiPlayer 有利；防守加权）
  static evaluateBoard(board: number[][], aiPlayer: number): number {
    const human: number = aiPlayer === 1 ? 2 : 1;
    const aiScore: number = GomokuEngine.sumScores(board, aiPlayer);
    const humanScore: number = GomokuEngine.sumScores(board, human);
    return aiScore - humanScore * 1.1;
  }

  // 只统计“连续串起点”的模式分，避免重复计数
  private static sumScores(board: number[][], player: number): number {
    let total: number = 0;
    const dirs: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let r: number = 0; r < GOMOKU_SIZE; r++) {
      for (let c: number = 0; c < GOMOKU_SIZE; c++) {
        if (board[r][c] !== player) continue;
        for (let d: number = 0; d < dirs.length; d++) {
          const dr: number = dirs[d][0];
          const dc: number = dirs[d][1];
          const pr: number = r - dr;
          const pc: number = c - dc;
          // 只有串起点才统计
          if (pr >= 0 && pr < GOMOKU_SIZE && pc >= 0 && pc < GOMOKU_SIZE && board[pr][pc] === player) {
            continue;
          }
          let len: number = 0;
          let rr: number = r;
          let cc: number = c;
          while (rr >= 0 && rr < GOMOKU_SIZE && cc >= 0 && cc < GOMOKU_SIZE && board[rr][cc] === player) {
            len += 1;
            rr += dr;
            cc += dc;
          }
          let opens: number = 0;
          if (rr >= 0 && rr < GOMOKU_SIZE && cc >= 0 && cc < GOMOKU_SIZE && board[rr][cc] === 0) opens += 1;
          if (pr >= 0 && pr < GOMOKU_SIZE && pc >= 0 && pc < GOMOKU_SIZE && board[pr][pc] === 0) opens += 1;
          total += GomokuEngine.patternScore(len, opens);
        }
      }
    }
    return total;
  }

  // 五连（含更长）快速判定（极小极大内部使用）
  private static hasFive(board: number[][], r: number, c: number, player: number): boolean {
    return GomokuEngine.checkWin(board, r, c, player);
  }

  // 深度映射：难度索引 0..4 → 深度
  static depthFor(levelIndex: number): number {
    if (levelIndex === 0) return 1;
    if (levelIndex === 1) return 2;
    if (levelIndex === 2) return 2;
    if (levelIndex === 3) return 3;
    return 3;
  }

  // 候选上限映射
  private static capFor(levelIndex: number): number {
    if (levelIndex === 0) return 8;
    if (levelIndex === 1) return 10;
    if (levelIndex === 2) return 12;
    if (levelIndex === 3) return 14;
    return 16;
  }

  // 是否随机扰动（低难度）
  private static randomizeFor(levelIndex: number): boolean {
    return levelIndex <= 1;
  }

  // 找到 aiPlayer 的最佳落子；无可用落子返回 null
  static findBestMove(board: number[][], aiPlayer: number, levelIndex: number): number[] | null {
    const moves: number[][] = GomokuEngine.candidateMoves(board, GomokuEngine.capFor(levelIndex));
    if (moves.length === 0) return null;
    const human: number = aiPlayer === 1 ? 2 : 1;
    // 攻击/防守双视角排序候选
    const scored: MoveScore[] = [];
    for (let i: number = 0; i < moves.length; i++) {
      const r: number = moves[i][0];
      const c: number = moves[i][1];
      const s: number = GomokuEngine.localScore(board, r, c, aiPlayer) * 1.05 +
        GomokuEngine.localScore(board, r, c, human);
      scored.push(new MoveScore(moves[i], s));
    }
    scored.sort((a: MoveScore, b: MoveScore): number => b.s - a.s);

    const depth: number = GomokuEngine.depthFor(levelIndex);
    let best: number[] | null = null;
    let bestScore: number = GOMOKU_NEG_INF;
    let alpha: number = GOMOKU_NEG_INF;
    const beta: number = 1000000000;
    // 简化：迭代前 cap 个候选（已按启发式排序）
    const limit: number = Math.min(scored.length, GomokuEngine.capFor(levelIndex));
    for (let i: number = 0; i < limit; i++) {
      const r: number = scored[i].move[0];
      const c: number = scored[i].move[1];
      board[r][c] = aiPlayer;
      let score: number = 0;
      if (GomokuEngine.hasFive(board, r, c, aiPlayer)) {
        score = GOMOKU_WIN_SCORE + depth * 10000;
      } else {
        score = -GomokuEngine.minimax(board, depth - 1, -beta, -alpha, human, aiPlayer, human);
      }
      board[r][c] = 0;
      if (score > bestScore) {
        bestScore = score;
        best = [r, c];
      }
      if (score > alpha) alpha = score;
    }
    if (best === null) return null;
    // 低难度随机扰动：在接近最优的候选里随机选一个
    if (GomokuEngine.randomizeFor(levelIndex) && scored.length >= 2) {
      const rand: number = Math.random();
      if (rand < 0.18) {
        const pick: number = Math.floor(Math.random() * Math.min(3, scored.length));
        return [scored[pick].move[0], scored[pick].move[1]];
      }
    }
    return best;
  }

  // 极小极大 + Alpha-Beta（negamax 形式）
  private static minimax(board: number[][], depth: number, alpha: number, beta: number,
    currentPlayer: number, aiPlayer: number, human: number): number {
    if (depth <= 0) {
      return GomokuEngine.evaluateBoard(board, aiPlayer);
    }
    const moves: number[][] = GomokuEngine.candidateMoves(board, GomokuEngine.capFor(2));
    if (moves.length === 0) {
      return GomokuEngine.evaluateBoard(board, aiPlayer);
    }
    // 候选按当前方局部分排序（简单近似，够用）
    const scored: MoveScore[] = [];
    for (let i: number = 0; i < moves.length; i++) {
      const r: number = moves[i][0];
      const c: number = moves[i][1];
      const s: number = GomokuEngine.localScore(board, r, c, currentPlayer);
      scored.push(new MoveScore(moves[i], s));
    }
    scored.sort((a: MoveScore, b: MoveScore): number => b.s - a.s);
    const limit: number = Math.min(scored.length, 10);

    let bestScore: number = GOMOKU_NEG_INF;
    for (let i: number = 0; i < limit; i++) {
      const r: number = scored[i].move[0];
      const c: number = scored[i].move[1];
      board[r][c] = currentPlayer;
      let score: number = 0;
      if (GomokuEngine.hasFive(board, r, c, currentPlayer)) {
        // 当前方连五：negamax 视角，当前方得分为极大，父节点取反
        score = GOMOKU_WIN_SCORE + depth * 10000;
      } else {
        score = -GomokuEngine.minimax(board, depth - 1, -beta, -alpha,
          currentPlayer === aiPlayer ? human : aiPlayer, aiPlayer, human);
      }
      board[r][c] = 0;
      if (score > bestScore) bestScore = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return bestScore;
  }
}

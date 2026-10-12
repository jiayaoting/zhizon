// 智子 - 数独出题与求解引擎（纯函数，无 UI 依赖，可单测）

export const SUDOKU_SIZE: number = 9;

export function copyBoard(source: number[][]): number[][] {
  const out: number[][] = [];
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    const row: number[] = [];
    for (let c: number = 0; c < SUDOKU_SIZE; c++) {
      row.push(source[r][c]);
    }
    out.push(row);
  }
  return out;
}

export function isSafe(board: number[][], r: number, c: number, value: number): boolean {
  for (let i: number = 0; i < SUDOKU_SIZE; i++) {
    if (board[r][i] === value) return false;
    if (board[i][c] === value) return false;
  }
  const br: number = Math.floor(r / 3) * 3;
  const bc: number = Math.floor(c / 3) * 3;
  for (let i: number = 0; i < 3; i++) {
    for (let j: number = 0; j < 3; j++) {
      if (board[br + i][bc + j] === value) return false;
    }
  }
  return true;
}

export function solveSudoku(board: number[][]): boolean {
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    for (let c: number = 0; c < SUDOKU_SIZE; c++) {
      if (board[r][c] !== 0) continue;
      for (let v: number = 1; v <= SUDOKU_SIZE; v++) {
        if (!isSafe(board, r, c, v)) continue;
        board[r][c] = v;
        if (solveSudoku(board)) return true;
        board[r][c] = 0;
      }
      return false;
    }
  }
  return true;
}

export function isComplete(board: number[][]): boolean {
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    for (let c: number = 0; c < SUDOKU_SIZE; c++) {
      if (board[r][c] === 0) return false;
    }
  }
  return true;
}

// 统计可行解个数（最多数到 limit 个）
export function countSolutions(board: number[][], limit: number): number {
  const work: number[][] = copyBoard(board);
  return countRecursive(work, 0, 0, limit);
}

function countRecursive(board: number[][], r: number, c: number, limit: number): number {
  if (r === SUDOKU_SIZE) return 1;
  let nr: number = r;
  let nc: number = c + 1;
  if (nc === SUDOKU_SIZE) {
    nr = r + 1;
    nc = 0;
  }
  if (board[r][c] !== 0) return countRecursive(board, nr, nc, limit);
  let total: number = 0;
  for (let v: number = 1; v <= SUDOKU_SIZE; v++) {
    if (!isSafe(board, r, c, v)) continue;
    board[r][c] = v;
    total += countRecursive(board, nr, nc, limit);
    board[r][c] = 0;
    if (total >= limit) return total;
  }
  return total;
}

// 生成一个完整终局（随机打乱候选顺序）
export function generateSolution(): number[][] {
  const board: number[][] = [];
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    const row: number[] = [];
    for (let c: number = 0; c < SUDOKU_SIZE; c++) row.push(0);
    board.push(row);
  }
  fillSolution(board, 0, 0);
  return board;
}

function fillSolution(board: number[][], r: number, c: number): boolean {
  if (r === SUDOKU_SIZE) return true;
  let nr: number = r;
  let nc: number = c + 1;
  if (nc === SUDOKU_SIZE) {
    nr = r + 1;
    nc = 0;
  }
  const values: number[] = shuffledNumbers();
  for (let i: number = 0; i < values.length; i++) {
    const v: number = values[i];
    if (!isSafe(board, r, c, v)) continue;
    board[r][c] = v;
    if (fillSolution(board, nr, nc)) return true;
    board[r][c] = 0;
  }
  return false;
}

function shuffledNumbers(): number[] {
  const arr: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  for (let i: number = arr.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: number = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

// 校验终局合法性：每行每列每宫 1-9 各出现一次
export function isValidSolution(board: number[][]): boolean {
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    for (let c: number = 0; c < SUDOKU_SIZE; c++) {
      const v: number = board[r][c];
      if (v < 1 || v > SUDOKU_SIZE) return false;
      if (!isSafe(board, r, c, v)) return false;
    }
  }
  return true;
}

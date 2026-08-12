import { describe, it, expect } from '@ohos/hypium';
import { SUDOKU_SIZE, countSolutions, generateSolution, isComplete, isValidSolution, copyBoard,
  isSafe } from '../main/ets/service/SudokuSolver';

function emptyBoard(): number[][] {
  const board: number[][] = [];
  for (let r: number = 0; r < SUDOKU_SIZE; r++) {
    const row: number[] = [];
    for (let c: number = 0; c < SUDOKU_SIZE; c++) row.push(0);
    board.push(row);
  }
  return board;
}

export default function SudokuSolverTest() {
  describe('SudokuSolverTest', () => {
    it('generates a valid complete solution', 0, () => {
      const solution = generateSolution();
      expect(solution.length).assertEqual(SUDOKU_SIZE);
      expect(isComplete(solution)).assertTrue();
      expect(isValidSolution(solution)).assertTrue();
    });

    it('generates two distinct solutions', 0, () => {
      const first = generateSolution();
      const second = generateSolution();
      let same: boolean = true;
      for (let r: number = 0; r < SUDOKU_SIZE; r++) {
        for (let c: number = 0; c < SUDOKU_SIZE; c++) {
          if (first[r][c] !== second[r][c]) {
            same = false;
            break;
          }
        }
        if (!same) break;
      }
      expect(same).assertFalse();
    });

    it('full solution has exactly one solution', 0, () => {
      const solution = generateSolution();
      expect(countSolutions(solution, 2)).assertEqual(1);
    });

    it('empty board has more than one solution', 0, () => {
      const board = emptyBoard();
      expect(countSolutions(board, 2)).assertEqual(2);
    });

    it('copyBoard does not share inner arrays', 0, () => {
      const original = emptyBoard();
      original[0][0] = 5;
      const copied = copyBoard(original);
      copied[0][0] = 9;
      expect(original[0][0]).assertEqual(5);
    });

    it('isSafe detects row column and box conflicts', 0, () => {
      const board = emptyBoard();
      board[0][0] = 5;
      expect(isSafe(board, 0, 1, 5)).assertFalse();
      expect(isSafe(board, 1, 0, 5)).assertFalse();
      expect(isSafe(board, 1, 1, 5)).assertFalse();
      expect(isSafe(board, 1, 2, 5)).assertTrue();
    });
  });
}

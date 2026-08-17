// 智子 - 中国象棋正规中文记谱工具
// 生成如「炮二平五」「马8进7」「车一平二」「兵七进一」等标准中文记谱。
// 参考主流记谱规则：
//   - 红方列号用中文数字（从右向左，第1~9列），黑方列号用阿拉伯数字（从左向右，1~9）。
//   - 纵向移动记「进/退」+ 目标列号（兵/卒/帅/将走一格时记「进一/退一」），横向记「平」+ 目标列号。
//   - 同列存在同类棋子时用「前/后」区分。

import { ChineseChessEngine, ChineseChessMove, CHESS_ROWS } from './ChineseChessEngine';

export class ChineseChessNotation {
  // 棋子显示名：小写 key -> 名称（红/黑共用同一字，颜色由棋盘方决定）
  private static readonly NAME: Map<string, string> = ((): Map<string, string> => {
    const m: Map<string, string> = new Map<string, string>();
    m.set('k', '帅');
    m.set('a', '仕');
    m.set('b', '相');
    m.set('h', '马');
    m.set('r', '车');
    m.set('c', '炮');
    m.set('p', '兵');
    return m;
  })();

  // 黑方显示名（用于黑方棋子）
  private static readonly NAME_BLACK: Map<string, string> = ((): Map<string, string> => {
    const m: Map<string, string> = new Map<string, string>();
    m.set('k', '将');
    m.set('a', '士');
    m.set('b', '象');
    m.set('h', '马');
    m.set('r', '车');
    m.set('c', '炮');
    m.set('p', '卒');
    return m;
  })();

  private static readonly CN_NUM: string[] = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

  // 生成记谱文本。red 表示走棋方（判断列号方向与进/退）。board 为走子前局面。
  static fromMove(board: string[][], mv: ChineseChessMove, red: boolean): string {
    const piece: string = board[mv.fromRow][mv.fromCol];
    if (piece === '.' || piece === '') return '';
    const p: string = piece.toLowerCase();
    const name: string = red ? ChineseChessNotation.NAME.get(p) as string : ChineseChessNotation.NAME_BLACK.get(p) as string;
    if (name === undefined || name === '') return '';

    const fromCol: number = mv.fromCol;
    const toCol: number = mv.toCol;
    const fromRow: number = mv.fromRow;
    const toRow: number = mv.toRow;

    // 列号：红方从右向左（col8->第1列），黑方从左向右（col0->第1列）
    const fromFile: number = red ? 9 - fromCol : fromCol + 1;
    const toFile: number = red ? 9 - toCol : toCol + 1;

    // 判断是否同列有同类棋子（需用「前/后」）
    const prefix: string = ChineseChessNotation.sameFilePiece(board, mv, red, p);

    // 移动方向
    const dr: number = toRow - fromRow;
    const isForward: boolean = red ? dr < 0 : dr > 0; // 红向上为进，黑向下为进
    const isSideway: boolean = dr === 0; // 平

    let movePart: string = '';
    if (isSideway) {
      movePart = '平' + ChineseChessNotation.fileText(toFile, red);
    } else {
      // 兵/卒/帅/将走一格时记「进一/退一」
      const oneStep: boolean = p === 'p' || p === 'k';
      const dir: string = isForward ? '进' : '退';
      if (oneStep) {
        movePart = dir + (red ? '一' : '1');
      } else {
        movePart = dir + ChineseChessNotation.fileText(toFile, red);
      }
    }

    return prefix + name + ChineseChessNotation.fileText(fromFile, red) + movePart;
  }

  // 列号文本：红方中文数字，黑方阿拉伯数字
  private static fileText(file: number, red: boolean): string {
    if (red) {
      return ChineseChessNotation.CN_NUM[file - 1];
    }
    return file.toString();
  }

  // 判断移动棋子是否在起始列有同类棋子（需「前/后」），返回「前」/「后」或空串
  private static sameFilePiece(board: string[][], mv: ChineseChessMove, red: boolean, p: string): string {
    const fromRow: number = mv.fromRow;
    const fromCol: number = mv.fromCol;
    // 找出同列所有同类型、同色棋子
    let count: number = 0;
    let frontMine: boolean = false;
    for (let r: number = 0; r < CHESS_ROWS; r++) {
      const cur: string = board[r][fromCol];
      if (cur === '.') continue;
      const isMine: boolean = red ? ChineseChessEngine.isRed(cur) : ChineseChessEngine.isBlack(cur);
      if (!isMine) continue;
      if (cur.toLowerCase() !== p) continue;
      count++;
      // 前进方向判定：红方 row 越小越靠前，黑方 row 越大越靠前
      const isFront: boolean = red ? r < fromRow : r > fromRow;
      if (isFront) frontMine = true;
    }
    if (count < 2) return '';
    // 若我方还有一枚在更前方，则本子为「后」，否则为「前」
    return frontMine ? '后' : '前';
  }
}

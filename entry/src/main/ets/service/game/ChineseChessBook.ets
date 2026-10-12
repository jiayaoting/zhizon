// 智子 - 中国象棋开局库（可开关）
// 参考优质开源项目（Royhoo/write-a-chinesechess-program 的 book.js、lengyanyu258/xiangqi.js 的 FEN）设计。
// 存储方式：一系列经典开局走法序列（棋盘坐标），构建成「局面哈希 -> 推荐走法列表」的映射，
// 搜索时优先查表，命中即返回库着法；未命中或开局库关闭则回退搜索。
// 走法用 ChineseChessMove{fromRow,fromCol,toRow,toCol} 表示（row 0 为黑底线，col 0 为最左）。

import { ChineseChessEngine, ChineseChessMove } from './ChineseChessEngine';

export class ChineseChessBook {
  // 开局库开关（持久化到偏好设置，默认开启）
  static enabled: boolean = true;

  // 局面哈希 -> 该局面下的推荐走法列表（红方视角；轮到哪一方由引擎当前 red 判断）
  private static table: Map<number, ChineseChessMove[]> = new Map<number, ChineseChessMove[]>();

  private static initialized: boolean = false;

  // 从走法序列构建开局库映射。每步走法用引擎校验物理合法性，非法则中止该开局（避免注入错误数据）。
  private static addOpening(sequence: number[][]): void {
    if (sequence.length === 0) return;
    const board: string[][] = ChineseChessEngine.initialBoard();
    let red: boolean = true;
    // 初始局面加入库（红方第一步）
    const startKey: number = ChineseChessEngine.computeZobrist(board);
    ChineseChessBook.addEntry(startKey, sequence[0]);
    for (let i: number = 0; i < sequence.length; i++) {
      const mvArr: number[] = sequence[i];
      if (mvArr.length < 4) return;
      const mv: ChineseChessMove = new ChineseChessMove(mvArr[0], mvArr[1], mvArr[2], mvArr[3]);
      // 校验走法在当步局面下合法
      const legalMoves: ChineseChessMove[] = ChineseChessEngine.generateMoves(board, red);
      let found: boolean = false;
      for (let j: number = 0; j < legalMoves.length; j++) {
        if (legalMoves[j].fromRow === mv.fromRow && legalMoves[j].fromCol === mv.fromCol &&
          legalMoves[j].toRow === mv.toRow && legalMoves[j].toCol === mv.toCol) {
          found = true;
          break;
        }
      }
      if (!found) return; // 走法非法，丢弃该开局
      // 应用走法并记录下一局面 -> 下一步走法
      board[mv.toRow][mv.toCol] = board[mv.fromRow][mv.fromCol];
      board[mv.fromRow][mv.fromCol] = '.';
      red = !red;
      if (i < sequence.length - 1) {
        const next: number[] = sequence[i + 1];
        if (next.length >= 4) {
          const key: number = ChineseChessEngine.computeZobrist(board);
          ChineseChessBook.addEntry(key, next);
        }
      }
    }
  }

  private static addEntry(key: number, mvArr: number[]): void {
    const mv: ChineseChessMove = new ChineseChessMove(mvArr[0], mvArr[1], mvArr[2], mvArr[3]);
    let list: ChineseChessMove[] | undefined = ChineseChessBook.table.get(key);
    if (list === undefined) {
      list = [];
      ChineseChessBook.table.set(key, list);
    }
    // 避免重复走法
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].fromRow === mv.fromRow && list[i].fromCol === mv.fromCol &&
        list[i].toRow === mv.toRow && list[i].toCol === mv.toCol) {
        return;
      }
    }
    list.push(mv);
  }

  // 初始化内置开局库
  static ensureInit(): void {
    if (ChineseChessBook.initialized) return;
    ChineseChessBook.initialized = true;
    ChineseChessBook.table.clear();
    ChineseChessBook.registerClassicOpenings();
  }

  // 内部轮换计数器：同一局面有多个库着时轮换选择，开局不千篇一律
  private static bookCounter: number = 0;

  // 查询开局库：给定局面与走棋方，返回推荐走法（无则 null）。ply 为已走的半回合数。
  static lookup(board: string[][], red: boolean, ply: number): ChineseChessMove | null {
    if (!ChineseChessBook.enabled) return null;
    // 开局库只在早期阶段生效（< 12 半回合）
    if (ply > 12) return null;
    ChineseChessBook.ensureInit();
    const key: number = ChineseChessEngine.computeZobrist(board);
    const list: ChineseChessMove[] | undefined = ChineseChessBook.table.get(key);
    if (list === undefined || list.length === 0) return null;
    // 同一局面多个库着时轮换选择，增加开局多样性
    ChineseChessBook.bookCounter += 1;
    const idx: number = ChineseChessBook.bookCounter % list.length;
    return list[idx];
  }

  // 注册经典开局（每个开局为一串红黑交替的走法 [fr,fc,tr,tc]，第0/2/4…步为红，第1/3/5…步为黑）
  // 坐标：row0 黑底线 / row9 红底线；红炮在 row7 col1&7，红马 row9 col1&7，红兵 row6 偶数列；
  //       黑炮在 row2 col1&7，黑马 row0 col1&7，黑卒 row3 偶数列。
  private static registerClassicOpenings(): void {
    // 1) 当头炮对屏风马主变（红炮二平五、黑马8进7、红马二进三、黑马2进3）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五（row7col7 -> row7col4）
      [0, 7, 2, 6], // 黑 马8进7（row0col7 -> row2col6）
      [9, 7, 7, 6], // 红 马二进三（row9col7 -> row7col6）
      [0, 1, 2, 2], // 黑 马2进3（row0col1 -> row2col2）
    ]);

    // 2) 当头炮对单提马（红炮二平五、黑马8进7、红马二进三、黑车9平8）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [0, 8, 0, 7], // 黑 车9平8（row0col8 -> row0col7，col7马已跳出）
    ]);

    // 3) 飞相局（红相三进五、黑马8进7、红马二进三、黑卒7进1）
    ChineseChessBook.addOpening([
      [9, 6, 7, 4], // 红 相三进五（row9col6 -> row7col4）
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [3, 0, 4, 0], // 黑 卒7进1（row3col0 -> row4col0）
    ]);

    // 4) 仙人指路（红兵七进一、黑卒7进1、红炮二平五）
    ChineseChessBook.addOpening([
      [6, 6, 5, 6], // 红 兵七进一（row6col6 -> row5col6）
      [3, 0, 4, 0], // 黑 卒7进1
      [7, 7, 7, 4], // 红 炮二平五
    ]);

    // 5) 起马局（红马八进七、黑马2进3、红马二进三、黑马8进7）
    ChineseChessBook.addOpening([
      [9, 1, 7, 2], // 红 马八进七（row9col1 -> row7col2）
      [0, 1, 2, 2], // 黑 马2进3
      [9, 7, 7, 6], // 红 马二进三
      [0, 7, 2, 6], // 黑 马8进7
    ]);

    // 6) 中炮对屏风马右横车（红炮二平五、黑马8进7、红马二进三、黑马2进3）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [0, 1, 2, 2], // 黑 马2进3
    ]);

    // 7) 士角炮（红炮八平六、黑马8进7、红马二进三、黑卒7进1）
    ChineseChessBook.addOpening([
      [7, 1, 7, 5], // 红 炮八平六（row7col1 -> row7col5，row7 col2/3/4 空）
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [3, 0, 4, 0], // 黑 卒7进1
    ]);

    // 8) 五六炮对屏风马（红炮二平五、黑马8进7、红马二进三、黑马2进3、红车一平二）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [0, 1, 2, 2], // 黑 马2进3
      [9, 8, 9, 7], // 红 车一平二（row9col8 -> row9col7，马已跳出）
    ]);

    // 9) 中炮过河车（红炮二平五、黑马8进7、红马二进三、黑卒7进1、红车一平二、红车二进六）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [3, 0, 4, 0], // 黑 卒7进1
      [9, 8, 9, 7], // 红 车一平二
      [9, 7, 3, 7], // 红 车二进六（row9col7 -> row3col7）
    ]);

    // 10) 顺炮直车对横车（红炮二平五、黑马8进7、红马二进三、黑卒3进1）
    ChineseChessBook.addOpening([
      [7, 7, 7, 4], // 红 炮二平五
      [0, 7, 2, 6], // 黑 马8进7
      [9, 7, 7, 6], // 红 马二进三
      [3, 2, 4, 2], // 黑 卒3进1（row3col2 -> row4col2）
    ]);
  }
}

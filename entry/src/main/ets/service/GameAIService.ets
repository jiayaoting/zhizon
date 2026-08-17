// 智子 - 游戏 AI 服务（状态序列化 / 动作解析 / LLM 调用 / 模型管理）
import { ChatRepository } from './ChatRepository';
import { DataRepository } from './DataRepository';
import { LlmClient } from './LlmClient';
import { ChatMessage, LlmConfig, LlmModelEntry, LlmResult, entryToConfig } from '../common/LlmModels';
import { AiCallContext } from './AiCallLogger';
import { DifficultyLevel, difficultyLabel } from '../common/Difficulty';
import { ChineseChessMove } from './ChineseChessEngine';
import { ChineseChessNotation } from './ChineseChessNotation';

export type GameKind = '2048' | 'Tetris' | 'Snake' | 'Minesweeper' | 'Sudoku' | 'ChineseChess';

// AI 模型记忆存储键：聊天/AI 使用默认键，各游戏独立记忆自己的键
const AI_MODEL_KEY_PREFIX = 'aiModelId';

// 中国象棋各侧别的模型记忆子键（红方 / 黑方 / AI 方需分别独立记忆）
export const CHESS_KIND_RED: string = 'ChineseChess_red';
export const CHESS_KIND_BLACK: string = 'ChineseChess_black';
export const CHESS_KIND_AI: string = 'ChineseChess_ai';

// 组装当前游戏的模型记忆键；非游戏场景（聊天/AI 默认）使用默认键
export function aiModelKeyFor(kind: string): string {
  if (kind.length === 0) return AI_MODEL_KEY_PREFIX;
  return AI_MODEL_KEY_PREFIX + '_' + kind;
}

// 贪吃蛇坐标点
export interface SnakePoint {
  x: number;
  y: number;
}

// 扫雷格子信息（仅序列化所需的只读字段）
export interface MinesweeperCellInfo {
  revealed: boolean;
  flagged: boolean;
  isMine: boolean;
  adjacent: number;
}

// 数独格子信息（仅序列化所需的只读字段）
export interface SudokuCellInfo {
  value: number;
  fixed: boolean;
}

// 解析后的标准动作：command 为动作码，r/c/value 为可选参数（扫雷/数独用）
export class GameAction {
  command: string;
  r: number;
  c: number;
  value: number;
  toRow: number;
  toCol: number;

  constructor(command: string, r: number = -1, c: number = -1, value: number = 0,
    toRow: number = -1, toCol: number = -1) {
    this.command = command;
    this.r = r;
    this.c = c;
    this.value = value;
    this.toRow = toRow;
    this.toCol = toCol;
  }
}

// 中国象棋走法描述（用于给 LLM 列出合法走法选项）
export class ChineseChessMoveOption {
  index: number;
  fr: number;
  fc: number;
  tr: number;
  tc: number;
  pieceName: string;
  capture: string;

  constructor(index: number, fr: number, fc: number, tr: number, tc: number,
    pieceName: string, capture: string) {
    this.index = index;
    this.fr = fr;
    this.fc = fc;
    this.tr = tr;
    this.tc = tc;
    this.pieceName = pieceName;
    this.capture = capture;
  }
}

// AI 展示档位：速度索引 → 每步展示窗口（毫秒）
export const AI_SPEED_OPTIONS: string[] = ['慢', '中', '快', '极速'];
export const AI_SPEED_DELAYS: number[] = [800, 400, 200, 0];
// 决策超时：游戏决策已强制关闭思考（thinkingEnabled=false），正常模型 3-8 秒即可返回；
// 30 秒足够覆盖慢网络与慢模型，超时后 decide 会自动重试一次，避免长时间无响应挂起
export const AI_DECISION_TIMEOUT: number = 30000;

export class GameAIService {
  // ---- 模型管理 ----

  // 加载已配置的模型列表（供 AI 面板选择）
  static async loadModelOptions(): Promise<LlmModelEntry[]> {
    return await ChatRepository.loadModels();
  }

  // 按模型 id 加载配置；id 为空时使用激活模型
  static async loadConfig(modelId: string): Promise<LlmConfig | null> {
    if (modelId.length > 0) {
      const models: LlmModelEntry[] = await ChatRepository.loadModels();
      for (let i: number = 0; i < models.length; i++) {
        if (models[i].id === modelId) return entryToConfig(models[i]);
      }
    }
    return await ChatRepository.loadActiveConfig();
  }

  // 模型显示名称
  static modelLabel(entry: LlmModelEntry): string {
    const base: string = entry.model.trim().length > 0 ? entry.model.trim() : entry.providerId;
    return entry.displayName.trim().length > 0 ? entry.displayName.trim() : base;
  }

  // 记忆当前应用/游戏选中的模型 id（kind 为空表示聊天/AI 默认；游戏侧别可传 CHESS_KIND_* 子键）
  static async saveModelId(kind: string, modelId: string): Promise<void> {
    await DataRepository.setSetting(aiModelKeyFor(kind), modelId);
  }

  // 读取当前应用/游戏记忆的模型 id；无记忆或模型已删除返回 ''
  static async loadSavedModelId(kind: string): Promise<string> {
    const saved: string = await DataRepository.getSetting(aiModelKeyFor(kind), '');
    if (saved.length === 0) return '';
    const models: LlmModelEntry[] = await ChatRepository.loadModels();
    for (let i: number = 0; i < models.length; i++) {
      if (models[i].id === saved) return saved;
    }
    return '';
  }

  // ---- Prompt 构建 ----

  static systemPrompt(kind: GameKind, difficulty: DifficultyLevel): string {
    const diff: string = difficultyLabel(difficulty);
    if (kind === '2048') {
      return '你正在玩 2048 游戏。棋盘是 6×6 网格，数字表示方块值，0 表示空格。\n' +
        '当前难度：' + diff + '。游戏已暂停等待你的决策，无需考虑时间因素。\n' +
        '可用动作：LEFT、RIGHT、UP、DOWN，只输出一个动作。\n' +
        '策略：优先合并大数并让大数保持在角落，避免棋盘过早填满。\n' +
        '只回复一个动作单词，不要输出任何其他文字或解释。';
    }
    if (kind === 'Tetris') {
      return '你正在玩俄罗斯方块。棋盘 10 列 20 行，0 表示空格，1 表示已填充。\n' +
        '当前难度：' + diff + '。\n' +
        '可用动作（用空格分隔一次输出多个）：LEFT、RIGHT、ROTATE、SOFT_DROP、HARD_DROP、HOLD。\n' +
        '请规划当前方块从当前位置到放置完成的完整动作序列，一次输出全部动作，最后以 HARD_DROP 收尾。\n' +
        '示例：LEFT LEFT ROTATE LEFT HARD_DROP\n' +
        '策略：优先消除行，尽量让方块落在低洼处并贴合已有方块，避免堆高，不要悬空。\n' +
        '只输出动作序列（可含空格分隔的多个动作），不要输出任何其他文字或解释。';
    }
    if (kind === 'Snake') {
      return '你正在玩贪吃蛇。棋盘 16×16，S 表示蛇身，H 表示蛇头，F 表示食物，. 表示空格。\n' +
        '当前难度：' + diff + '。\n' +
        '可用动作（用空格分隔一次输出多个）：UP、DOWN、LEFT、RIGHT。\n' +
        '请规划蛇头从当前位置到食物的移动路径，一次输出一串方向，直达食物或遇到危险就停。\n' +
        '注意：不能直接掉头（反向移动会无效）。策略：优先走向食物，同时避免撞墙和撞到自己。\n' +
        '只输出方向序列（可含空格分隔的多个方向），不要输出任何其他文字或解释。';
    }
    if (kind === 'Minesweeper') {
      return '你正在玩扫雷。网格中 0 表示未知，1-8 表示已翻开的数字（周围地雷数），* 表示地雷（仅在游戏结束后可见），F 表示已标记的旗子，空格表示已翻开且周围无雷。\n' +
        '当前难度：' + diff + '。游戏已暂停等待你的决策，无需考虑时间因素。\n' +
        '可用动作：REVEAL r c（翻开格子）、FLAG r c（标记/取消标记），r、c 从 0 开始。\n' +
        '策略：优先翻开确定安全的格子，用数字推理标记地雷，绝不翻开已知有雷的格子。\n' +
        '只输出一个动作，格式如 REVEAL 3 5 或 FLAG 1 2，不要输出任何其他文字。';
    }
    if (kind === 'ChineseChess') {
      return '你正在下中国象棋。棋盘 9 列 × 10 行，红方先手。\n' +
        '当前难度：' + diff + '。\n' +
        '棋子编码：红方大写 帅K 仕A 相B 马H 车R 炮C 兵P；黑方小写 将k 士a 象b 马h 车r 炮c 卒p。\n' +
        '走子规则：仕/士在九宫斜格，相/象走田字且不过河、塞象眼，马走日字、蹩马腿，\n' +
        '车走直线，炮隔子吃子，兵/卒只能前进、过河后可横走且不能后退，帅/将不出九宫且不能对脸相见。\n' +
        '不能把己方将/帅送入被将军的境地。\n' +
        '策略：注意防守己方将/帅，优先保护重要棋子，用炮/车/马配合进攻，避免被将军。\n' +
        '用户消息中会列出你当前所有【合法走法】（每条带【序号】和【中文记谱】）。\n' +
        '你【必须】且【只能】从合法走法列表中选择一个【序号】。\n' +
        '输出格式（严格）：MOVE 序号（例如 MOVE 1），不要输出任何其他文字、解释或坐标。';
    }
    return '你正在玩数独。棋盘 9×9，0 表示空格，1-9 为已填数字（题目给定的数字不可修改）。\n' +
      '当前难度：' + diff + '。\n' +
      '可用动作：SET r c v（在 r 行 c 列填入数字 v，一次可输出多行），r、c、v 均为 1-9。\n' +
      '规则：每行、每列、每个 3×3 宫格内数字 1-9 不重复。\n' +
      '请一次性推理出所有空格并输出，每个空格一行，格式：SET r c v\n' +
      '策略：用排除法找唯一解，只填确定无冲突的格子。\n' +
      '只按格式输出 SET 行，不要输出任何其他文字。';
  }

  // 构建请求消息：system 规则 + user 棋盘状态
  static buildMessages(kind: GameKind, difficulty: DifficultyLevel, stateText: string): ChatMessage[] {
    return [
      ChatMessage.create('system', GameAIService.systemPrompt(kind, difficulty)),
      ChatMessage.create('user', stateText)
    ];
  }

  // ---- LLM 调用（带决策超时 + 主动取消） ----

  static async decide(config: LlmConfig, messages: ChatMessage[],
    kind: GameKind = '2048', timeoutMs: number = AI_DECISION_TIMEOUT): Promise<LlmResult> {
    // 复制配置并强制关闭思考（游戏决策只认最终动作，不需要思考过程）：
    // 不修改原配置，不影响聊天等其他场景
    const gameConfig: LlmConfig = GameAIService.cloneConfig(config);
    gameConfig.thinkingEnabled = false;
    let lastResult: LlmResult | null = null;
    // 最多请求 2 次：netstack 连接池在复用闲置连接时首次请求可能无响应超时（日志规律），
    // 超时后 destroy 会销毁坏连接，紧接着的重试走全新连接必定成功。
    for (let attempt: number = 0; attempt < 2; attempt++) {
      // 非流式请求：游戏决策只需最终动作，非流式一次返回完整 JSON，比流式逐 token 快 30%+
      // （实测：非流式 22.8s vs 流式 38.7s）。配合 HTTP/1.1 + Connection: close 已根治连接问题
      const result = await GameAIService.decideOnce(gameConfig, messages, timeoutMs, kind);
      if (result.success) {
        return result;
      }
      lastResult = result;
      // 非超时错误（鉴权/限流/网络异常）直接返回，不盲目重试
      if (result.errorCode !== 'TIMEOUT' && result.errorCode !== 'DECISION_TIMEOUT' &&
        result.errorCode !== 'CANCELLED') {
        break;
      }
    }
    if (lastResult !== null) return lastResult;
    return new LlmResult(false, '', 'REQUEST_FAILED', 'AI 请求失败');
  }

  // 复制配置（ArkTS 不支持深拷贝，手动复制全部字段）
  private static cloneConfig(config: LlmConfig): LlmConfig {
    const copy: LlmConfig = new LlmConfig();
    copy.id = config.id;
    copy.displayName = config.displayName;
    copy.providerId = config.providerId;
    copy.baseUrl = config.baseUrl;
    copy.apiKey = config.apiKey;
    copy.model = config.model;
    copy.temperature = config.temperature;
    copy.apiFormat = config.apiFormat;
    copy.maxTokens = config.maxTokens;
    copy.useFullUrl = config.useFullUrl;
    copy.modelFamily = config.modelFamily;
    copy.contextTokensIn = config.contextTokensIn;
    copy.contextTokensOut = config.contextTokensOut;
    copy.workers = config.workers;
    copy.visionEnabled = config.visionEnabled;
    copy.thinkingEnabled = config.thinkingEnabled;
    copy.followDefaultConfig = config.followDefaultConfig;
    copy.vllmCompat = config.vllmCompat;
    return copy;
  }

  // 单次决策请求：非流式 + 超时主动取消底层请求
  private static async decideOnce(config: LlmConfig, messages: ChatMessage[],
    timeoutMs: number, kind: GameKind): Promise<LlmResult> {
    let settled: boolean = false;
    const cancellable = LlmClient.postCompletionCancelable(config, messages, new AiCallContext('game', kind));
    return await new Promise<LlmResult>((resolve: (value: LlmResult) => void) => {
      const timer: number = setTimeout(() => {
        if (!settled) {
          settled = true;
          cancellable.cancel();
          resolve(new LlmResult(false, '', 'DECISION_TIMEOUT',
            'AI 决策超时：请稍候重试或换用非思考模型'));
        }
      }, timeoutMs);
      cancellable.promise.then((result: LlmResult) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(result);
        }
      }).catch((e: Object) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(new LlmResult(false, '', 'REQUEST_FAILED', 'AI 请求失败'));
        }
      });
    });
  }

  // ---- 动作解析 ----

  // 从模型回复中提取标准动作；解析失败返回 null
  static parseAction(kind: GameKind, text: string): GameAction | null {
    const upper: string = text.toUpperCase();
    if (kind === '2048' || kind === 'Snake') {
      const actions: string[] = ['LEFT', 'RIGHT', 'UP', 'DOWN'];
      for (let i: number = 0; i < actions.length; i++) {
        if (GameAIService.hasWord(upper, actions[i])) return new GameAction(actions[i]);
      }
      return null;
    }
    if (kind === 'Tetris') {
      const actions: string[] = ['HARD_DROP', 'SOFT_DROP', 'ROTATE', 'HOLD', 'LEFT', 'RIGHT'];
      for (let i: number = 0; i < actions.length; i++) {
        if (GameAIService.hasWord(upper, actions[i])) return new GameAction(actions[i]);
      }
      return null;
    }
    if (kind === 'Minesweeper') {
      if (GameAIService.hasWord(upper, 'REVEAL')) {
        const nums: number[] = GameAIService.extractNumbers(text);
        if (nums.length >= 2) return new GameAction('REVEAL', nums[0], nums[1]);
        return null;
      }
      if (GameAIService.hasWord(upper, 'FLAG')) {
        const nums: number[] = GameAIService.extractNumbers(text);
        if (nums.length >= 2) return new GameAction('FLAG', nums[0], nums[1]);
        return null;
      }
      return null;
    }
    if (kind === 'Sudoku') {
      if (GameAIService.hasWord(upper, 'SET')) {
        const nums: number[] = GameAIService.extractNumbers(text);
        if (nums.length >= 3) return new GameAction('SET', nums[0], nums[1], nums[2]);
        return null;
      }
      return null;
    }
    if (kind === 'ChineseChess') {
      // 严格只从 MOVE 关键字之后的子串提取，避免模型回复前面的解释文字
      // （如"我观察 row 5 col 4 局势..."）混入坐标导致解析错误
      const moveIdx: number = upper.indexOf('MOVE');
      if (moveIdx >= 0) {
        const after: string = text.substring(moveIdx + 'MOVE'.length);
        const nums: number[] = GameAIService.extractNumbers(after);
        // 新格式：MOVE 序号（1-based）
        // 旧格式：MOVE fr fc tr tc（兜底兼容）
        if (nums.length >= 1) {
          // 序号模式：1 个数字
          if (nums.length === 1) {
            return new GameAction('MOVE_IDX', 0, nums[0] - 1); // r=0, c=index
          }
          // 兜底：4 个数字 = 坐标
          if (nums.length >= 4) {
            return new GameAction('MOVE', nums[0], nums[1], nums[2], nums[3]);
          }
        }
      }
      // 兜底：模型回复中没有 MOVE 关键字（说明它没听懂指令），返回 null 让上层重试
      return null;
    }
    return null;
  }

  // 从模型回复中按顺序提取一串动作（俄罗斯方块/贪吃蛇/数独用：一次调用包含多步）
  static parseActionSequence(kind: GameKind, text: string): GameAction[] {
    const actions: GameAction[] = [];
    const upper: string = text.toUpperCase();
    if (kind === 'Tetris' || kind === 'Snake') {
      // 简单动作序列：按出现顺序提取动作词
      const tokens: string[] = kind === 'Tetris'
        ? ['HARD_DROP', 'SOFT_DROP', 'ROTATE', 'HOLD', 'LEFT', 'RIGHT']
        : ['UP', 'DOWN', 'LEFT', 'RIGHT'];
      let remaining: string = upper;
      while (remaining.length > 0) {
        // 找到在当前剩余文本中最早出现的动作词
        let best: string = '';
        let bestIdx: number = -1;
        for (let i: number = 0; i < tokens.length; i++) {
          const idx: number = remaining.indexOf(tokens[i]);
          if (idx >= 0 && (bestIdx === -1 || idx < bestIdx)) {
            best = tokens[i];
            bestIdx = idx;
          }
        }
        if (bestIdx === -1) break;
        actions.push(new GameAction(best));
        // 跳过已匹配部分继续扫描，避免重复匹配同一 token
        remaining = remaining.substring(bestIdx + best.length);
      }
      return actions;
    }
    if (kind === 'Sudoku') {
      // 数独序列：一次输出多个 "SET r c v"，按顺序提取
      let remaining: string = upper;
      while (remaining.length > 0) {
        const setIdx: number = remaining.indexOf('SET');
        if (setIdx < 0) break;
        remaining = remaining.substring(setIdx + 'SET'.length);
        const nums: number[] = [];
        // 从 SET 之后按序提取 3 个数字（跨空格/换行）
        while (nums.length < 3 && remaining.length > 0) {
          let i: number = 0;
          while (i < remaining.length && !(remaining.charAt(i) >= '0' && remaining.charAt(i) <= '9')) i++;
          if (i >= remaining.length) break;
          let num: number = 0;
          while (i < remaining.length && remaining.charAt(i) >= '0' && remaining.charAt(i) <= '9') {
            num = num * 10 + (remaining.charCodeAt(i) - 48);
            i++;
          }
          nums.push(num);
          remaining = remaining.substring(i);
        }
        if (nums.length >= 3) {
          actions.push(new GameAction('SET', nums[0], nums[1], nums[2]));
        } else {
          break;
        }
      }
      return actions;
    }
    return actions;
  }

  private static hasWord(text: string, word: string): boolean {
    return text.indexOf(word) >= 0;
  }

  private static extractNumbers(text: string): number[] {
    const nums: number[] = [];
    let i: number = 0;
    while (i < text.length) {
      const ch: string = text.charAt(i);
      if (ch >= '0' && ch <= '9') {
        let num: number = 0;
        while (i < text.length && text.charAt(i) >= '0' && text.charAt(i) <= '9') {
          num = num * 10 + (text.charCodeAt(i) - 48);
          i++;
        }
        nums.push(num);
      } else {
        i++;
      }
    }
    return nums;
  }

  // ---- 状态序列化（各游戏棋盘转文本） ----

  static serializeGrid2048(board: number[][]): string {
    let out: string = '当前棋盘：\n';
    for (let r: number = 0; r < board.length; r++) {
      out = out + '[' + board[r].join(', ') + ']\n';
    }
    return out;
  }

  static serializeTetris(board: number[][], currentType: number, currentRotation: number,
    currentX: number, currentY: number, nextType: number, score: number, level: number): string {
    let out: string = '当前棋盘：\n';
    for (let r: number = 0; r < board.length; r++) {
      out = out + '[' + board[r].join(',') + ']\n';
    }
    out = out + '当前方块：类型 ' + currentType.toString() + '，旋转 ' + currentRotation.toString() +
      '，位置 (' + currentX.toString() + ',' + currentY.toString() + ')\n';
    out = out + '下一个方块：类型 ' + nextType.toString() + '\n';
    out = out + '分数：' + score.toString() + '，等级：' + level.toString() + '\n';
    return out;
  }

  static serializeSnake(snake: SnakePoint[], food: SnakePoint,
    cols: number, rows: number): string {
    const map: string[][] = [];
    for (let r: number = 0; r < rows; r++) {
      const line: string[] = [];
      for (let c: number = 0; c < cols; c++) line.push('.');
      map.push(line);
    }
    for (let i: number = 0; i < snake.length; i++) {
      const seg: SnakePoint = snake[i];
      if (seg.y >= 0 && seg.y < rows && seg.x >= 0 && seg.x < cols) {
        map[seg.y][seg.x] = i === 0 ? 'H' : 'S';
      }
    }
    if (food.y >= 0 && food.y < rows && food.x >= 0 && food.x < cols) {
      map[food.y][food.x] = 'F';
    }
    let out: string = '棋盘（H 蛇头，S 蛇身，F 食物）：\n';
    for (let r: number = 0; r < rows; r++) {
      out = out + map[r].join(' ') + '\n';
    }
    return out;
  }

  static serializeMinesweeper(cells: MinesweeperCellInfo[][],
    rows: number, cols: number): string {
    let out: string = '棋盘（数字=周围雷数，?=未知，F=旗子）：\n';
    for (let r: number = 0; r < rows; r++) {
      const line: string[] = [];
      for (let c: number = 0; c < cols; c++) {
        const cell: MinesweeperCellInfo = cells[r][c];
        if (cell.flagged) line.push('F');
        else if (!cell.revealed) line.push('?');
        else if (cell.adjacent === 0) line.push('0');
        else line.push(cell.adjacent.toString());
      }
      out = out + line.join(' ') + '\n';
    }
    return out;
  }

  static serializeSudoku(cells: SudokuCellInfo[][]): string {
    let out: string = '棋盘（0=空格，1-9=数字）：\n';
    for (let r: number = 0; r < cells.length; r++) {
      const line: string[] = [];
      for (let c: number = 0; c < cells[r].length; c++) {
        line.push(cells[r][c].value.toString());
      }
      out = out + '[' + line.join(',') + ']\n';
    }
    return out;
  }

  // 中国象棋棋盘序列化：当前局面 + 合法走法索引列表（让 LLM 只从列表里选，彻底避免坐标错误）
  static serializeChineseChess(board: string[][], redTurn: boolean,
    legalMoves: ChineseChessMoveOption[]): string {
    let out: string = '中国象棋棋盘，9列 × 10行。行号row和列号col都从0开始。\n';
    out = out + '重要坐标方位：row0 是【黑方】底线（上方），row9 是【红方】底线（下方），黑方在上、红方在下。\n';
    out = out + '棋子编码：红方用大写 帅K 仕A 相B 马H 车R 炮C 兵P；黑方用小写 将k 士a 象b 马h 车r 炮c 卒p；. 表示空位。\n';
    out = out + '当前轮到：' + (redTurn ? '红方' : '黑方') + ' 走棋，你只能移动己方棋子（大写=红方、小写=黑方）。\n';
    out = out + '     col:  0  1  2  3  4  5  6  7  8\n';
    for (let r: number = 0; r < board.length; r++) {
      out = out + 'row' + r.toString() + '  ' + board[r].join('  ') + '\n';
    }
    out = out + '\n【当前' + (redTurn ? '红方' : '黑方') + '的全部合法走法（按索引）】\n';
    out = out + '你必须从下面' + legalMoves.length.toString() + '个合法走法里选一个，禁止输出表中不存在的坐标。\n';
    out = out + '每条格式：序号 | 中文记谱 | 从(行,列) → 到(行,列) | 棋子 | 吃子\n';
    for (let i: number = 0; i < legalMoves.length; i++) {
      const m = legalMoves[i];
      // 为每个合法走法附带标准中文记谱（如「炮二平五」），帮助模型理解棋路
      const mv: ChineseChessMove = new ChineseChessMove(m.fr, m.fc, m.tr, m.tc);
      const notation: string = ChineseChessNotation.fromMove(board, mv, redTurn);
      out = out + '  ' + (i + 1).toString() + '  ' + notation + '  (row' + m.fr.toString() + ',col' + m.fc.toString() +
        ') → (row' + m.tr.toString() + ',col' + m.tc.toString() + ')  ' + m.pieceName +
        (m.capture.length > 0 ? '  吃' + m.capture : '') + '\n';
    }
    out = out + '\n只需要输出：MOVE 序号\n';
    out = out + '例如想走第1步则输出：MOVE 1\n';
    out = out + '不要输出任何其他文字或解释。';
    return out;
  }
}

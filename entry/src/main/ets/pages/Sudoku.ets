// 智子 - 数独
import { router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { DataRepository } from '../service/DataRepository';
import { DifficultyLevel, difficultyLabel, GameId, GameLaunchFacade, GameLaunchResult,
  GameRouteParams } from '../common/Difficulty';
import { GameHistoryRouteParams } from '../common/Navigation';
import { SUDOKU_SIZE, copyBoard, countSolutions, generateSolution } from '../service/SudokuSolver';
import { DeviceMetrics } from '../common/DeviceMetrics';
import { GameAIPanel } from '../components/GameAIPanel';
import { GameAIService, GameAction, AI_SPEED_DELAYS, SudokuCellInfo } from '../service/GameAIService';
import { LlmConfig, LlmModelEntry } from '../common/LlmModels';

// ============================================================
// 页面组件
// ============================================================

interface SudokuCell extends SudokuCellInfo {
  value: number;     // 0 表示未填
  fixed: boolean;    // 题目给定
  notes: number[];   // 笔记候选数
  conflict: boolean; // 冲突标记
}
@Entry
@Component
export struct SudokuPage {
  @State cells: SudokuCell[][] = [];
  @State selectedR: number = -1;
  @State selectedC: number = -1;
  @State noteMode: boolean = false;
  @State difficulty: DifficultyLevel = DifficultyLevel.MEDIUM;
  @State gameStarted: boolean = false;
  @State isPaused: boolean = false;
  @State isWin: boolean = false;
  @State playSeconds: number = 0;
  @State bestTime: number = 0;
  @State newRecord: boolean = false;
  @State showHintTip: boolean = false;
  @State showHelp: boolean = false;
  @State flashWin: boolean = false;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  // ---- AI 托管 ----
  @State aiRunning: boolean = false;
  @State aiStatus: string = '';
  @State aiModelNames: string[] = [];
  @State aiModelIndex: number = 0;
  @State aiSpeedIndex: number = 2;
  @State aiModelsConfigured: boolean = true;
  private aiModels: LlmModelEntry[] = [];
  private aiConfig: LlmConfig | null = null;
  private aiLoopActive: boolean = false;
  private aiFailCount: number = 0;

  private timerId: number = -1;
  private titleText: string = '数独';
  private gameStartTime: number = 0;
  private solution: number[][] = [];

  // 自适应棋盘格子尺寸
  private boardCellSize(): number {
    if (this.isSm) {
      // 手机端：TopBar + 提示条 + 信息栏 + 操作栏 + 数字键盘(160) + 间距 + 安全区
      return DeviceMetrics.fitCellSize(SUDOKU_SIZE, SUDOKU_SIZE, 442, 16, 40);
    }
    // 平板端：TopBar + 安全区
    return DeviceMetrics.fitCellSize(SUDOKU_SIZE, SUDOKU_SIZE, 140, 24, 52);
  }

  private boardSide(): number {
    return SUDOKU_SIZE * this.boardCellSize();
  }

  // 每难度挖空数
  private holesFor(level: DifficultyLevel): number {
    if (level === DifficultyLevel.VERY_EASY) return 30;
    if (level === DifficultyLevel.EASY) return 40;
    if (level === DifficultyLevel.HARD) return 58;
    if (level === DifficultyLevel.HELL) return 65;
    return 50;
  }

  private vibrate(duration: number): void {
    try {
      vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'physicalFeedback' });
    } catch (e) {
      // 设备不支持振动时静默忽略
    }
  }

  private formatDuration(seconds: number): string {
    const m: number = Math.floor(seconds / 60);
    const s: number = Math.floor(seconds % 60);
    return m > 0 ? `${m} 分 ${s} 秒` : `${s} 秒`;
  }

  private bestKey(): string {
    return 'sudokuBest_' + this.difficulty.toString();
  }

  // ---- 出题 ----
  private generatePuzzle(): void {
    const solution: number[][] = generateSolution();
    this.solution = solution;
    const target: number = this.holesFor(this.difficulty);
    const given: number[][] = copyBoard(solution);
    const positions: number[][] = [];
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      for (let c: number = 0; c < SUDOKU_SIZE; c++) positions.push([r, c]);
    }
    // 洗牌挖空顺序
    for (let i: number = positions.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number[] = positions[i];
      positions[i] = positions[j];
      positions[j] = tmp;
    }
    let dug: number = 0;
    const used: boolean[][] = [];
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      const row: boolean[] = [];
      for (let c: number = 0; c < SUDOKU_SIZE; c++) row.push(false);
      used.push(row);
    }
    for (let i: number = 0; i < positions.length && dug < target; i++) {
      const r: number = positions[i][0];
      const c: number = positions[i][1];
      if (used[r][c]) continue;
      const symR: number = SUDOKU_SIZE - 1 - r;
      const symC: number = SUDOKU_SIZE - 1 - c;
      const saved: number = given[r][c];
      given[r][c] = 0;
      let symSaved: number = 0;
      if (!(symR === r && symC === c)) {
        symSaved = given[symR][symC];
        given[symR][symC] = 0;
      }
      if (countSolutions(given, 2) === 1) {
        used[r][c] = true;
        used[symR][symC] = true;
        dug += (symR === r && symC === c) ? 1 : 2;
      } else {
        given[r][c] = saved;
        if (!(symR === r && symC === c)) given[symR][symC] = symSaved;
      }
    }
    // 构建格子
    const newCells: SudokuCell[][] = [];
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      const row: SudokuCell[] = [];
      for (let c: number = 0; c < SUDOKU_SIZE; c++) {
        const v: number = given[r][c];
        row.push({ value: v, fixed: v !== 0, notes: [], conflict: false });
      }
      newCells.push(row);
    }
    this.cells = newCells;
    this.selectedR = -1;
    this.selectedC = -1;
    this.gameStarted = true;
    this.isWin = false;
    this.isPaused = false;
    this.playSeconds = 0;
    this.newRecord = false;
  }

  // ---- 计时 ----
  private startTimer(): void {
    this.stopTimer();
    this.gameStartTime = Date.now();
    this.timerId = setInterval(() => {
      if (this.isPaused || this.isWin) return;
      this.playSeconds = Math.floor((Date.now() - this.gameStartTime) / 1000);
    }, 500);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private togglePause(): void {
    if (!this.gameStarted || this.isWin) return;
    if (this.aiRunning) {
      this.stopAi();
      this.isPaused = true;
      return;
    }
    this.isPaused = !this.isPaused;
    if (!this.isPaused) {
      this.gameStartTime = Date.now() - this.playSeconds * 1000;
    }
  }

  private restartGame(): void {
    this.stopAi();
    this.generatePuzzle();
    this.startTimer();
    this.vibrate(20);
  }

  // ---- 冲突检测 ----
  private hasConflict(r: number, c: number): boolean {
    const v: number = this.cells[r][c].value;
    if (v === 0) return false;
    for (let i: number = 0; i < SUDOKU_SIZE; i++) {
      if (i !== c && this.cells[r][i].value === v) return true;
      if (i !== r && this.cells[i][c].value === v) return true;
    }
    const br: number = Math.floor(r / 3) * 3;
    const bc: number = Math.floor(c / 3) * 3;
    for (let i: number = 0; i < 3; i++) {
      for (let j: number = 0; j < 3; j++) {
        if ((br + i !== r || bc + j !== c) && this.cells[br + i][bc + j].value === v) return true;
      }
    }
    return false;
  }

  // 填入数字（含笔记模式）
  private inputNumber(num: number): void {
    if (!this.gameStarted || this.isPaused || this.isWin) return;
    if (this.selectedR < 0 || this.selectedC < 0) return;
    const cell: SudokuCell = this.cells[this.selectedR][this.selectedC];
    if (cell.fixed) return;
    if (this.noteMode) {
      this.toggleNote(this.selectedR, this.selectedC, num);
      this.refreshConflicts();
      return;
    }
    if (cell.value === num) {
      cell.value = 0;
    } else {
      cell.value = num;
      cell.notes = [];
    }
    this.cells = this.copyCells(this.cells);
    this.refreshConflicts();
    this.vibrate(10);
    this.checkWin();
  }

  private toggleNote(r: number, c: number, num: number): void {
    const cell: SudokuCell = this.cells[r][c];
    if (cell.value !== 0) return;
    const idx: number = cell.notes.indexOf(num);
    if (idx >= 0) {
      cell.notes.splice(idx, 1);
    } else {
      cell.notes.push(num);
      cell.notes.sort((a: number, b: number) => a - b);
    }
  }

  private clearCell(): void {
    if (!this.gameStarted || this.isPaused || this.isWin) return;
    if (this.selectedR < 0 || this.selectedC < 0) return;
    const cell: SudokuCell = this.cells[this.selectedR][this.selectedC];
    if (cell.fixed) return;
    cell.value = 0;
    cell.notes = [];
    this.cells = this.copyCells(this.cells);
    this.refreshConflicts();
    this.vibrate(10);
  }

  private copyCells(source: SudokuCell[][]): SudokuCell[][] {
    const out: SudokuCell[][] = [];
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      const row: SudokuCell[] = [];
      for (let c: number = 0; c < SUDOKU_SIZE; c++) {
        row.push({
          value: source[r][c].value,
          fixed: source[r][c].fixed,
          notes: source[r][c].notes.slice(),
          conflict: source[r][c].conflict
        });
      }
      out.push(row);
    }
    return out;
  }

  private refreshConflicts(): void {
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      for (let c: number = 0; c < SUDOKU_SIZE; c++) {
        this.cells[r][c].conflict = this.hasConflict(r, c);
      }
    }
  }

  // ---- 胜利检测 ----
  private checkWin(): void {
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      for (let c: number = 0; c < SUDOKU_SIZE; c++) {
        if (this.cells[r][c].value === 0) return;
        if (this.cells[r][c].value !== this.solution[r][c]) return;
      }
    }
    this.isWin = true;
    this.stopTimer();
    this.flashWin = true;
    setTimeout(() => { this.flashWin = false; }, 900);
    this.saveScore();
  }

  private async saveScore(): Promise<void> {
    const key: string = this.bestKey();
    const stored: string = await DataRepository.getSetting(key, '0');
    const prevBest: number = Number(stored);
    if (prevBest <= 0 || this.playSeconds < prevBest) {
      await DataRepository.setSetting(key, this.playSeconds.toString());
      this.bestTime = this.playSeconds;
      this.newRecord = true;
    } else {
      this.bestTime = prevBest;
    }
    try {
      await DataRepository.addGameScore(GameId.SUDOKU, this.playSeconds, 0, difficultyLabel(this.difficulty));
    } catch (e) {
      // 战绩写入失败不影响游戏流程
    }
  }

  private async loadBest(): Promise<void> {
    const stored: string = await DataRepository.getSetting(this.bestKey(), '0');
    this.bestTime = Number(stored);
  }

  // ---- AI 托管 ----
  private async initAiPanel(): Promise<void> {
    this.aiModels = await GameAIService.loadModelOptions();
    const names: string[] = [];
    for (let i: number = 0; i < this.aiModels.length; i++) {
      names.push(GameAIService.modelLabel(this.aiModels[i]));
    }
    this.aiModelNames = names;
    this.aiModelsConfigured = this.aiModels.length > 0;
    if (this.aiModelsConfigured) {
      this.aiConfig = await GameAIService.loadConfig(this.aiModels[this.aiModelIndex].id);
    } else {
      this.aiConfig = null;
    }
  }

  private async toggleAi(): Promise<void> {
    if (this.aiRunning) {
      this.stopAi();
      return;
    }
    if (!this.aiModelsConfigured) {
      promptAction.showToast({ message: '请先在 AI 对话中配置可用模型' });
      return;
    }
    if (this.aiConfig === null) {
      promptAction.showToast({ message: '模型配置无效，请检查 AI 设置' });
      return;
    }
    if (!this.gameStarted) return;
    if (this.isWin) {
      this.restartGame();
    }
    this.isPaused = false;
    this.aiFailCount = 0;
    this.aiRunning = true;
    this.aiStatus = 'AI 准备中…';
    this.aiLoop().catch((e: Object) => {
      this.stopAi();
    });
  }

  private stopAi(): void {
    this.aiRunning = false;
    this.aiLoopActive = false;
    this.aiStatus = '';
  }

  private selectAiModel(index: number): void {
    if (this.aiRunning) return;
    this.aiModelIndex = index;
    if (this.aiModels.length > index) {
      GameAIService.loadConfig(this.aiModels[index].id).then((config: LlmConfig | null) => {
        this.aiConfig = config;
      });
    }
  }

  private changeAiSpeed(index: number): void {
    if (this.aiRunning) return;
    this.aiSpeedIndex = index;
  }

  // AI 决策循环：纯回合制，每轮 决策 → 填入数字
  private async aiLoop(): Promise<void> {
    if (!this.aiRunning || this.aiLoopActive) return;
    this.aiLoopActive = true;
    while (this.aiRunning) {
      if (this.isWin || this.isPaused) break;
      if (this.aiConfig === null) break;
      this.aiStatus = 'AI 思考中…';
      const stateText: string = GameAIService.serializeSudoku(this.cells);
      const messages = GameAIService.buildMessages('Sudoku', this.difficulty, stateText);
      const result = await GameAIService.decide(this.aiConfig, messages);
      if (!this.aiRunning) break;
      if (!result.success) {
        this.aiFailCount += 1;
        if (this.aiFailCount >= 3) {
          this.aiStatus = 'AI 模型不稳定，已退出';
          this.stopAi();
          promptAction.showToast({ message: 'AI 连续失败，已停止托管' });
          break;
        }
        continue;
      }
      this.aiFailCount = 0;
      const action: GameAction | null = GameAIService.parseAction('Sudoku', result.content);
      if (action === null) continue;
      const r: number = action.r - 1;
      const c: number = action.c - 1;
      const v: number = action.value;
      if (r < 0 || r >= SUDOKU_SIZE || c < 0 || c >= SUDOKU_SIZE || v < 1 || v > 9) continue;
      const cell: SudokuCell = this.cells[r][c];
      if (cell.fixed) continue;
      this.aiStatus = 'AI 执行 SET (' + (r + 1).toString() + ',' + (c + 1).toString() + ')=' + v.toString();
      this.selectedR = r;
      this.selectedC = c;
      this.inputNumber(v);
      if (this.isWin) break;
      if (this.aiSpeedIndex < AI_SPEED_DELAYS.length && AI_SPEED_DELAYS[this.aiSpeedIndex] > 0) {
        await new Promise<void>((resolve) => {
          setTimeout(() => { resolve(); }, AI_SPEED_DELAYS[this.aiSpeedIndex]);
        });
      }
    }
    this.aiLoopActive = false;
    if (this.aiRunning) {
      this.aiRunning = false;
      this.aiStatus = this.isWin ? 'AI 完成：数独已解出' : 'AI 已暂停';
    }
  }

  private openHistory(): void {
    router.pushUrl({
      url: 'pages/GameHistory',
      params: new GameHistoryRouteParams(GameId.SUDOKU)
    });
  }

  // ---- 生命周期 ----
  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as GameRouteParams | null;
    if (params !== undefined && params !== null) {
      const result: GameLaunchResult = GameLaunchFacade.parse(params, GameId.SUDOKU);
      if (result.success && result.request !== null) {
        this.difficulty = result.request.difficulty;
      }
    }
    this.titleText = `数独 · ${difficultyLabel(this.difficulty)}`;
    await this.loadBest();
    this.generatePuzzle();
    this.startTimer();
    this.initAiPanel();
    this.showHintTip = true;
    setTimeout(() => { this.showHintTip = false; }, 4000);
  }

  aboutToDisappear(): void {
    this.stopAi();
    this.stopTimer();
  }

  // ---- 键盘 ----
  private handleKey(code: KeyCode): void {
    if (code === KeyCode.KEYCODE_P || code === KeyCode.KEYCODE_ENTER) {
      this.togglePause();
      return;
    }
    if (code === KeyCode.KEYCODE_R) {
      this.restartGame();
      return;
    }
    if (this.aiRunning) return;
    if (code === KeyCode.KEYCODE_N) {
      this.noteMode = !this.noteMode;
      this.vibrate(10);
      return;
    }
    if (this.isPaused || this.isWin) return;
    if (code === KeyCode.KEYCODE_DEL || code === KeyCode.KEYCODE_0) {
      this.clearCell();
      return;
    }
    if (code === KeyCode.KEYCODE_1) { this.inputNumber(1); return; }
    if (code === KeyCode.KEYCODE_2) { this.inputNumber(2); return; }
    if (code === KeyCode.KEYCODE_3) { this.inputNumber(3); return; }
    if (code === KeyCode.KEYCODE_4) { this.inputNumber(4); return; }
    if (code === KeyCode.KEYCODE_5) { this.inputNumber(5); return; }
    if (code === KeyCode.KEYCODE_6) { this.inputNumber(6); return; }
    if (code === KeyCode.KEYCODE_7) { this.inputNumber(7); return; }
    if (code === KeyCode.KEYCODE_8) { this.inputNumber(8); return; }
    if (code === KeyCode.KEYCODE_9) { this.inputNumber(9); return; }
    // 方向键移动光标
    const r: number = this.selectedR;
    const c: number = this.selectedC;
    if (code === KeyCode.KEYCODE_DPAD_UP && r > 0) { this.selectCell(r - 1, c); return; }
    if (code === KeyCode.KEYCODE_DPAD_DOWN && r >= 0 && r < SUDOKU_SIZE - 1) { this.selectCell(r + 1, c); return; }
    if (code === KeyCode.KEYCODE_DPAD_LEFT && c > 0) { this.selectCell(r, c - 1); return; }
    if (code === KeyCode.KEYCODE_DPAD_RIGHT && c >= 0 && c < SUDOKU_SIZE - 1) { this.selectCell(r, c + 1); return; }
  }

  private selectCell(r: number, c: number): void {
    this.selectedR = r;
    this.selectedC = c;
    this.vibrate(8);
  }

  // ==================== 单元格文本 ====================
  private cellText(r: number, c: number): string {
    const cell: SudokuCell = this.cells[r][c];
    if (cell.value !== 0) return cell.value.toString();
    return '';
  }

  private cellFontSize(): number {
    if (this.isSm) return 20;
    return 24;
  }

  private cellTextColor(r: number, c: number): string {
    const cell: SudokuCell = this.cells[r][c];
    if (cell.fixed) return this.palette.textPrimary;
    if (cell.conflict) return this.palette.danger;
    return this.palette.primary;
  }

  private cellBackground(r: number, c: number): string {
    const cell: SudokuCell = this.cells[r][c];
    if (this.selectedR === r && this.selectedC === c) return this.palette.primaryDim;
    if (cell.conflict) return this.palette.danger + '22';
    if (cell.value !== 0 && this.isRelated(r, c)) return this.palette.bgSurface2;
    return this.palette.bgSurface;
  }

  private cellBorderWidth(r: number, c: number): number {
    const selected: boolean = this.selectedR === r && this.selectedC === c;
    if (selected) return 2;
    // 3x3 宫格边界
    if (c === 0 || c === 3 || c === 6) return 2;
    return 0.5;
  }

  private cellBorderColor(r: number, c: number): string {
    if (this.selectedR === r && this.selectedC === c) return this.palette.primary;
    if (c === 0 || c === 3 || c === 6) return this.palette.borderStrong;
    return this.palette.borderDefault;
  }

  // 选中格子的同行/同列/同宫
  private isRelated(r: number, c: number): boolean {
    if (this.selectedR < 0 || this.selectedC < 0) return false;
    if (this.selectedR === r && this.selectedC === c) return false;
    if (this.selectedR === r || this.selectedC === c) return true;
    return Math.floor(this.selectedR / 3) === Math.floor(r / 3) &&
      Math.floor(this.selectedC / 3) === Math.floor(c / 3);
  }

  private noteText(r: number, c: number): string {
    const notes: number[] = this.cells[r][c].notes;
    if (notes.length === 0) return '';
    let out: string = '';
    for (let i: number = 0; i < 9; i++) {
      const contains: boolean = notes.indexOf(i + 1) >= 0;
      out += contains ? (i + 1).toString() : ' ';
      if (i === 2 || i === 5) out += '\n';
    }
    return out;
  }

  // ==================== 信息面板 ====================
  @Builder
  infoPanel() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('用时')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.formatDuration(this.playSeconds))
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.info)
          .fontWeight(FontWeight.Bold)
          .fontFamily(this.palette.fontMono)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })

      Column({ space: 2 }) {
        Text('最佳')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.bestTime > 0 ? this.formatDuration(this.bestTime) : '--')
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.warning)
          .fontWeight(FontWeight.Bold)
          .fontFamily(this.palette.fontMono)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })

      Column({ space: 2 }) {
        Text('剩余格')
          .fontSize(this.palette.fsXs)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
        Text(this.emptyCount().toString())
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.success)
          .fontWeight(FontWeight.Bold)
          .fontFamily(this.palette.fontMono)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding(8)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(8)
      .border({ width: 1, color: this.palette.borderSubtle })
    }
    .width('100%')
  }

  private emptyCount(): number {
    let count: number = 0;
    for (let r: number = 0; r < SUDOKU_SIZE; r++) {
      for (let c: number = 0; c < SUDOKU_SIZE; c++) {
        if (this.cells[r][c].value === 0) count++;
      }
    }
    return count;
  }

  // ==================== 笔记开关 + 清除 ====================
  @Builder
  actionBar() {
    Row({ space: 8 }) {
      Row({ space: 6 }) {
        Text(this.noteMode ? '✏️' : '🔢')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
        Text('笔记')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.noteMode ? this.palette.primary : this.palette.textPrimary)
          .fontWeight(this.noteMode ? FontWeight.Bold : FontWeight.Medium)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(this.noteMode ? this.palette.primaryDim : this.palette.bgSurface)
      .border({ width: 1, color: this.noteMode ? this.palette.primary : this.palette.borderSubtle })
      .onClick(() => {
        this.noteMode = !this.noteMode;
        this.vibrate(10);
      })

      Row({ space: 6 }) {
        Text('🧹')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
        Text('清除')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface)
      .border({ width: 1, color: this.palette.borderSubtle })
      .onClick(() => { this.clearCell(); })
    }
    .width('100%')
  }

  // ==================== 数字键盘 ====================
  @Builder
  numPad() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        ForEach([1, 2, 3, 4, 5, 6, 7], (num: number) => {
          Text(num.toString())
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontMono)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .height(48)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.inputNumber(num); })
        }, (num: number) => num.toString())
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('8')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontMono)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .height(48)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .onClick(() => { this.inputNumber(8); })
        Text('9')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontMono)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .height(48)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .onClick(() => { this.inputNumber(9); })
        Text('⌫')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.danger)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .height(48)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .onClick(() => { this.clearCell(); })
      }
      .width('100%')
    }
    .width('100%')
  }

  // ==================== 棋盘 ====================
  @Builder
  board() {
    Column() {
      ForEach(this.cells, (row: SudokuCell[], r: number) => {
        Row() {
          ForEach(row, (cell: SudokuCell, c: number) => {
            Stack() {
              if (cell.value !== 0) {
                Text(this.cellText(r, c))
                  .fontSize(this.cellFontSize())
                  .fontFamily(this.palette.fontMono)
                  .fontColor(this.cellTextColor(r, c))
                  .fontWeight(cell.fixed ? FontWeight.Bold : FontWeight.Medium)
              } else if (cell.notes.length > 0) {
                Text(this.noteText(r, c))
                  .fontSize(this.isSm ? 8 : 10)
                  .fontFamily(this.palette.fontMono)
                  .fontColor(this.palette.textSecondary)
                  .textAlign(TextAlign.Center)
                  .lineHeight(this.isSm ? 8 : 10)
              }
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .backgroundColor(this.cellBackground(r, c))
            .border({
              width: this.cellBorderWidth(r, c),
              color: this.cellBorderColor(r, c)
            })
            .alignContent(Alignment.Center)
            .onClick(() => { this.selectCell(r, c); })
          }, (cell: SudokuCell, c: number) => c.toString())
        }
        .layoutWeight(1)
        .border({ width: { bottom: r === 2 || r === 5 ? 2 : 0.5 }, color: this.palette.borderStrong })
      }, (row: SudokuCell[], r: number) => r.toString())
    }
    .width('100%')
    .height('100%')
    .border({ width: 2, color: this.palette.borderStrong })
    .borderRadius(6)
    .backgroundColor(this.palette.bgSurface)
  }

  // ==================== 覆盖层 ====================
  @Builder
  winOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => {})

      Column({ space: 12 }) {
        Text('🎉')
          .fontSize(40)
          .fontFamily(this.palette.fontSans)
          .scale({ x: this.flashWin ? 1.15 : 1, y: this.flashWin ? 1.15 : 1 })
        Text('数独完成！')
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(`用时 ${this.formatDuration(this.playSeconds)}`)
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Medium)
        if (this.newRecord) {
          Text('🏆 新纪录！')
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.warning)
            .fontWeight(FontWeight.Bold)
        }
        Row({ space: 10 }) {
          Button('再玩一局')
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.palette.primary)
            .borderRadius(18)
            .height(36)
            .onClick(() => { this.restartGame(); })
          Button('历史记录')
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .backgroundColor(this.palette.bgSurface2)
            .borderRadius(18)
            .height(36)
            .onClick(() => { this.openHistory(); })
        }
      }
      .padding(24)
      .borderRadius(16)
      .backgroundColor(this.palette.bgElevated)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  pauseOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.togglePause(); })

      Column({ space: 12 }) {
        Text('已暂停')
          .fontSize(this.palette.fs2xl)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('点击任意处继续')
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
        Row({ space: 10 }) {
          Button('重新开始')
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.palette.danger)
            .borderRadius(18)
            .height(36)
            .onClick(() => { this.restartGame(); })
        }
      }
      .padding(24)
      .borderRadius(16)
      .backgroundColor(this.palette.bgElevated)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  hintTip() {
    Row({ space: 6 }) {
      Text('💡')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
      Text('先填确定的数字；打开笔记记录候选数，逐个排除。')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(this.palette.primaryDim)
    .border({ width: 1, color: this.palette.primary })
  }

  @Builder
  actionsBuilder() {
    Row({ space: 12 }) {
      // 暂停/继续
      Row() {
        Text(this.isPaused ? '▶' : '⏸')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.togglePause(); })

      // 使用说明
      Row() {
        Text('📖')
          .fontSize(14)
          .fontFamily(this.palette.fontSans)
      }
      .width(32)
      .height(32)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface2)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.showHelp = true; })
    }
  }

  // ---- 使用说明 ----
  @Builder
  helpDialog() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showHelp = false; })
          }
          .width('100%')
          .padding({ right: 4, top: 4 })

          Scroll() {
            Text('📖 数独\n\n' +
              '【目标】\n在 9×9 的格子中填入数字 1-9，使每行、每列、每个 3×3 宫格内数字都不重复。\n\n' +
              '【操作】\n' +
              '• 点击选中格子，再点击下方数字按钮填入\n' +
              '• 笔记模式：点击笔记按钮后，可在格子上标记候选数字\n' +
              '• 点击已填入数字的格子再按数字按钮可清除\n' +
              '• 提示按钮：自动填入一个正确数字\n\n' +
              '【规则】\n' +
              '• 每行 1-9 不重复\n' +
              '• 每列 1-9 不重复\n' +
              '• 每个 3×3 宫格 1-9 不重复\n' +
              '• 题目中给定的数字不可修改\n' +
              '• 填完所有空格即为胜利')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .lineHeight(22)
              .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 400 })
          .padding({ left: 20, right: 20, bottom: 16 })
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(this.palette.bgBase)
        .padding({ bottom: Math.max(16, this.navBarHeight) })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showHelp = false; })
  }

  build() {
    Stack() {
      Column() {
        TopBar({
          title: this.titleText,
          subtitle: '每行每列每宫填 1-9，不重复',
          showBack: true
        }) {
          this.actionsBuilder()
        }

        if (this.gameStarted) {
          if (this.isSm) {
            // 手机端
            Column({ space: 8 }) {
              if (this.showHintTip) { this.hintTip() }
              this.infoPanel()
              this.actionBar()
              GameAIPanel({
                modelNames: this.aiModelNames,
                selectedModelIndex: this.aiModelIndex,
                running: this.aiRunning,
                status: this.aiStatus,
                speedIndex: this.aiSpeedIndex,
                modelsConfigured: this.aiModelsConfigured,
                onSelectModel: (index: number): void => { this.selectAiModel(index); },
                onToggleRun: (): void => { this.toggleAi(); },
                onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
              })
              Stack() {
                Column() {
                  this.board()
                }
                if (this.isWin) { this.winOverlay() }
                if (this.isPaused) { this.pauseOverlay() }
              }
              .width(this.boardSide())
              .height(this.boardSide())
              .alignContent(Alignment.Center)
              this.numPad()
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 12, right: 12, top: 4, bottom: 12 })
            .justifyContent(FlexAlign.Center)
          } else {
            // 平板端
            Row({ space: 20 }) {
              Column({ space: 12 }) {
                Stack() {
                  Column() {
                    this.board()
                  }
                  if (this.isWin) { this.winOverlay() }
                  if (this.isPaused) { this.pauseOverlay() }
                }
                .width(this.boardSide())
                .height(this.boardSide())
                .alignContent(Alignment.Center)
              }
              .alignItems(HorizontalAlign.Center)

              Column({ space: 12 }) {
                this.infoPanel()
                this.actionBar()
                GameAIPanel({
                  modelNames: this.aiModelNames,
                  selectedModelIndex: this.aiModelIndex,
                  running: this.aiRunning,
                  status: this.aiStatus,
                  speedIndex: this.aiSpeedIndex,
                  modelsConfigured: this.aiModelsConfigured,
                  onSelectModel: (index: number): void => { this.selectAiModel(index); },
                  onToggleRun: (): void => { this.toggleAi(); },
                  onSpeedChange: (index: number): void => { this.changeAiSpeed(index); }
                })
                this.numPad()
                Column({ space: 6 }) {
                  Text('操作提示')
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textTertiary)
                  Column({ space: 4 }) {
                    Text('点选格子，再用数字键盘填入')
                      .fontSize(this.palette.fsSm)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textSecondary)
                    Text('笔记模式：同一格可记多个候选数')
                      .fontSize(this.palette.fsSm)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textSecondary)
                    Text('数字冲突时格子会标红')
                      .fontSize(this.palette.fsSm)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.primary)
                  }
                  .padding(16)
                  .backgroundColor(this.palette.bgSurface)
                  .borderRadius(10)
                  .border({ width: 1, color: this.palette.borderSubtle })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 24, right: 24, top: 8, bottom: 8 })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.palette.bgBase)
      .padding({ bottom: Math.max(0, this.navBarHeight) })
      .focusable(true)
      .defaultFocus(true)
      .onKeyEvent((event: KeyEvent) => {
        if (event.type !== KeyType.Down) return;
        this.handleKey(event.keyCode);
      })

      if (this.showHelp) { this.helpDialog() }
    }
    .width('100%')
    .height('100%')
  }
}
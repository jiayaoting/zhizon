// 智子 - 游戏历史战绩
import { AppNavigator } from '../common/AppNavigator';
import { DataRepository } from '../service/platform/DataRepository';
import { ScoreEntry } from '../service/platform/DatabaseHelper';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { ThemePalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { GameHistoryRouteParams } from '../common/Navigation';
import { LazyListDataSource } from '../common/LazyDataSource';

function isGameHistoryKey(key: string): boolean {
  return key === '2048' || key === 'Snake' || key === 'Tetris' || key === 'Minesweeper' ||
    key === 'Breakout' || key === 'SUDOKU' || key === 'ChineseChess' || key === 'Gomoku';
}

function gameIcon(key: string): string {
  if (key === 'Snake') return '🐍';
  if (key === 'Tetris') return '🧱';
  if (key === 'Minesweeper') return '💣';
  if (key === 'Breakout') return '🎱';
  if (key === 'SUDOKU') return '🧩';
  if (key === 'ChineseChess') return '♟️';
  if (key === 'Gomoku') return '⚫';
  return '🔢';
}

function gameName(key: string): string {
  if (key === 'Snake') return '贪吃蛇';
  if (key === 'Tetris') return '俄罗斯方块';
  if (key === 'Minesweeper') return '扫雷';
  if (key === 'Breakout') return '打砖块';
  if (key === 'SUDOKU') return '数独';
  if (key === 'ChineseChess') return '中国象棋';
  if (key === 'Gomoku') return '五子棋';
  return '2048';
}

function difficultyColor(difficulty: string, palette: ThemePalette): string {
  if (difficulty === '超简单') return palette.success;
  if (difficulty === '简单') return palette.info;
  if (difficulty === '中等') return palette.warning;
  if (difficulty === '困难') return palette.purple;
  if (difficulty === '地狱') return palette.danger;
  return palette.textSecondary;
}

function formatTime(ts: number): string {
  const d: Date = new Date(ts);
  const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
  const day: string = d.getDate().toString().padStart(2, '0');
  const h: string = d.getHours().toString().padStart(2, '0');
  const min: string = d.getMinutes().toString().padStart(2, '0');
  return `${m}-${day} ${h}:${min}`;
}

// 战绩用时格式化：000:00
function formatDuration(totalSeconds: number): string {
  const s: number = Math.max(0, Math.floor(totalSeconds));
  const h: number = Math.floor(s / 3600);
  const m: number = Math.floor((s % 3600) / 60);
  const sec: number = s % 60;
  if (h > 0) {
    return `${h.toString()}:${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
  }
  return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
}

function medalIcon(rank: number): string {
  if (rank === 0) return '🥇';
  if (rank === 1) return '🥈';
  if (rank === 2) return '🥉';
  return (rank + 1).toString();
}

@ComponentV2
@Entry
export struct GameHistoryPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local gameKey: string = '2048';
  @Local scores: ScoreEntry[] = [];
  @Local loading: boolean = true;
    
  private gameKeys: string[] = ['2048', 'Snake', 'Tetris', 'Minesweeper', 'Breakout', 'SUDOKU', 'ChineseChess', 'Gomoku'];
  private scoreSource: LazyListDataSource<ScoreEntry> = new LazyListDataSource<ScoreEntry>([]);

  aboutToAppear(): void {
    const params: GameHistoryRouteParams | null = AppNavigator.getParam('pages/GameHistory') as GameHistoryRouteParams | null;
    if (params !== null && params !== undefined && isGameHistoryKey(params.game)) {
      this.gameKey = params.game;
    }
    this.loadScores();
  }

  aboutToDisappear(): void {
    // 历史分数为单次拉取，无持久资源需要释放
  }

  async loadScores(): Promise<void> {
    this.loading = true;
    this.scores = await DataRepository.getGameScores(this.gameKey);
    this.scoreSource.replace(this.scores);
    this.loading = false;
  }

  async clearScores(): Promise<void> {
    await DataRepository.clearGameScores(this.gameKey);
    this.scores = [];
    this.scoreSource.replace(this.scores);
  }

  build() {
    Column() {
      TopBar({ title: '游戏战绩', showBack: true })

      // 游戏切换标签（横向滚动，避免内容超出屏幕宽度）
      Scroll() {
        Row({ space: this.themeState.palette.sp2 }) {
          ForEach(this.gameKeys, (key: string) => {
            Row({ space: this.themeState.palette.sp1 }) {
              Text(gameIcon(key))
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
              Text(gameName(key))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.gameKey === key ? this.themeState.palette.textPrimary : this.themeState.palette.textSecondary)
                .fontWeight(this.gameKey === key ? FontWeight.Bold : FontWeight.Normal)
            }
            .height(36)
            .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3 })
            .justifyContent(FlexAlign.Center)
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.gameKey === key ? this.themeState.palette.primaryBg :
              this.themeState.palette.bgSurface)
            .border({ width: 0.5, color: this.gameKey === key ? this.themeState.palette.primary :
              this.themeState.palette.divider })
            .onClick(() => {
              this.gameKey = key;
              this.loadScores();
            })
          })
        }
        .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp2 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.None)

      // 排行列表
      if (this.scores.length === 0 && !this.loading) {
        Column({ space: this.themeState.palette.sp3 }) {
          Text('📋')
            .fontSize(48)
            .fontFamily(this.themeState.palette.fontSans)
          Text('还没有战绩记录')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('完成一局' + gameName(this.gameKey) + '后，分数、难度与用时会自动记录在这里')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .textAlign(TextAlign.Center)
          Button('去玩一局')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .height(this.themeState.palette.touchTarget)
            .padding({ left: this.themeState.palette.sp6, right: this.themeState.palette.sp6 })
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.themeState.palette.primary)
            .margin({ top: this.themeState.palette.sp1 })
            .onClick(() => { AppNavigator.pop(); })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: this.themeState.palette.sp8, right: this.themeState.palette.sp8 })
      } else {
        Column() {
          List() {
            LazyForEach(this.scoreSource, (entry: ScoreEntry, idx: number) => {
              ListItem() {
                Row({ space: 10 }) {
                // 排名
                Text(medalIcon(idx))
                  .fontSize(this.themeState.palette.fsXl)
                  .fontFamily(this.themeState.palette.fontSans)
                  .width(32)
                  .textAlign(TextAlign.Center)

                // 分数/胜负（中国象棋：1=胜 0=负）
                Column({ space: 2 }) {
                  Text(this.gameKey === 'ChineseChess' ? (entry.score > 0 ? '胜' : '负') :
                    entry.score.toString())
                    .fontSize(this.themeState.palette.fsXl)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.gameKey === 'ChineseChess' ?
                      (entry.score > 0 ? this.themeState.palette.success : this.themeState.palette.danger) : this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Text(this.gameKey === 'ChineseChess' ? '结果' : '分数')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                Blank()

                // 等级
                Column({ space: 2 }) {
                  Text('Lv.' + entry.level.toString())
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.warning)
                    .fontWeight(FontWeight.Medium)
                  Text('等级')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                // 难度
                Column({ space: 2 }) {
                  Text(entry.difficulty)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(difficultyColor(entry.difficulty, this.themeState.palette))
                    .fontWeight(FontWeight.Medium)
                  Text('难度')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                // 模型（AI 托管时显示使用的模型显示名）
                if (entry.model.length > 0) {
                  Column({ space: 2 }) {
                    Text(entry.model)
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.info)
                      .maxLines(1)
                      .constraintSize({ maxWidth: 96 })
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('模型')
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Center)
                }

                // 用时（本局总耗时）+ AI 思考总时长（AI 托管时显示）
                Column({ space: 2 }) {
                  Text(formatDuration(entry.duration))
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textSecondary)
                    .fontWeight(FontWeight.Medium)
                  Text('用时')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                  if (entry.aiThinkTime > 0) {
                    Text('🤖 思考 ' + formatDuration(entry.aiThinkTime))
                      .fontSize(this.themeState.palette.fsXs)
                      .fontFamily(this.themeState.palette.fontSans)
                      .fontColor(this.themeState.palette.primary)
                  }
                }
                .alignItems(HorizontalAlign.Center)

                // 时间
                Text(formatTime(entry.createdAt))
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
              .width('100%')
              .constraintSize({ minHeight: this.themeState.palette.rowHeight })
              .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4,
                top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
            }
          }, (entry: ScoreEntry) => entry.id)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({
          strokeWidth: 0.5,
          color: this.themeState.palette.divider,
          startMargin: this.themeState.palette.dividerIndent,
          endMargin: 0
        })
        .backgroundColor(this.themeState.palette.bgSurface)
        .borderRadius(this.themeState.palette.radiusLg)
        .border({ width: 0.5, color: this.themeState.palette.divider })
        .clip(true)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({
        left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
        top: this.themeState.palette.sp1,
        bottom: this.themeState.palette.sp4
      })
      }

      // 底部操作栏
      Row({ space: this.themeState.palette.sp3 }) {
        Row() {
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(AppIcons.trash)
              .fontSize(18)
              .fontColor([this.themeState.palette.danger])
          } else {
            Text(AppIcons.trashEmoji)
              .fontSize(14)
              .fontFamily(this.themeState.palette.fontSans)
          }
          Text('清空战绩')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
            .margin({ left: this.themeState.palette.sp1 })
        }
        .height(this.themeState.palette.touchTarget)
        .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.themeState.palette.bgSurface)
        .borderRadius(this.themeState.palette.radiusCapsule)
        .border({ width: 0.5, color: this.themeState.palette.divider })
        .accessibilityText('清空战绩')
        .onClick(() => { this.clearScores(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: this.themeState.palette.sp4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

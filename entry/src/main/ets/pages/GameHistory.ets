// 智子 - 游戏历史战绩
import { AppNavigator } from '../common/AppNavigator';
import { DataRepository } from '../service/DataRepository';
import { ScoreEntry } from '../service/DatabaseHelper';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GameHistoryRouteParams } from '../common/Navigation';

function isGameHistoryKey(key: string): boolean {
  return key === '2048' || key === 'Snake' || key === 'Tetris' || key === 'Minesweeper' ||
    key === 'Breakout' || key === 'SUDOKU' || key === 'ChineseChess';
}

function gameIcon(key: string): string {
  if (key === 'Snake') return '🐍';
  if (key === 'Tetris') return '🧱';
  if (key === 'Minesweeper') return '💣';
  if (key === 'Breakout') return '🎱';
  if (key === 'SUDOKU') return '🧩';
  if (key === 'ChineseChess') return '♟️';
  return '🔢';
}

function gameName(key: string): string {
  if (key === 'Snake') return '贪吃蛇';
  if (key === 'Tetris') return '俄罗斯方块';
  if (key === 'Minesweeper') return '扫雷';
  if (key === 'Breakout') return '打砖块';
  if (key === 'SUDOKU') return '数独';
  if (key === 'ChineseChess') return '中国象棋';
  return '2048';
}

function difficultyColor(difficulty: string, fallback: string): string {
  if (difficulty === '超简单') return '#10B981';
  if (difficulty === '简单') return '#3B82F6';
  if (difficulty === '中等') return '#F59E0B';
  if (difficulty === '困难') return '#F97316';
  if (difficulty === '地狱') return '#EF4444';
  return fallback;
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
    
  private gameKeys: string[] = ['2048', 'Snake', 'Tetris', 'Minesweeper', 'Breakout', 'SUDOKU', 'ChineseChess'];

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
    this.loading = false;
  }

  async clearScores(): Promise<void> {
    await DataRepository.clearGameScores(this.gameKey);
    this.scores = [];
  }

  build() {
    Column() {
      TopBar({ title: '游戏战绩', showBack: true })

      // 游戏切换标签（横向滚动，避免内容超出屏幕宽度）
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.gameKeys, (key: string) => {
            Row({ space: 4 }) {
              Text(gameIcon(key))
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
              Text(gameName(key))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.gameKey === key ? this.themeState.palette.textPrimary : this.themeState.palette.textTertiary)
                .fontWeight(this.gameKey === key ? FontWeight.Bold : FontWeight.Normal)
            }
            .height(36)
            .padding({ left: 12, right: 12 })
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.gameKey === key ? this.themeState.palette.primary + '20' : Color.Transparent)
            .border({ width: this.gameKey === key ? 1.5 : 0, color: this.gameKey === key ? this.themeState.palette.primary : Color.Transparent })
            .onClick(() => {
              this.gameKey = key;
              this.loadScores();
            })
          })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.None)

      // 排行列表
      if (this.scores.length === 0 && !this.loading) {
        Column({ space: 8 }) {
          Text('📋')
            .fontSize(48)
            .fontFamily(this.themeState.palette.fontSans)
          Text('暂无战绩')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
          Text('快去玩一局吧！')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 6 }) {
          ForEach(this.scores, (entry: ScoreEntry, idx: number) => {
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
                      (entry.score > 0 ? '#10B981' : this.themeState.palette.danger) : this.themeState.palette.textPrimary)
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
                    .fontColor(difficultyColor(entry.difficulty, this.themeState.palette.textSecondary))
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
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(idx % 2 === 0 ? this.themeState.palette.bgSurface : this.themeState.palette.bgSurface2)
              .borderRadius(8)
            }
          }, (entry: ScoreEntry) => entry.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12 })
      }

      // 底部操作栏
      Row({ space: 12 }) {
        Row() {
          Text('🗑 清空战绩')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.themeState.palette.bgSurface2)
        .borderRadius(8)
        .border({ width: 1, color: this.themeState.palette.borderSubtle })
        .onClick(() => { this.clearScores(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

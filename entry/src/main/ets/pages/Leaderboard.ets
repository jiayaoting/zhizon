// 智子 - 排行榜（本地排行；Game Service Kit 云端就绪后可切换）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { LeaderboardService, LeaderboardEntry } from '../service/LeaderboardService';

function gameIcon(game: string): string {
  if (game === '2048') return '🔢';
  if (game === 'Snake') return '🐍';
  if (game === 'Tetris') return '🧱';
  if (game === 'Minesweeper') return '💣';
  if (game === 'SUDOKU') return '🧩';
  if (game === 'ChineseChess') return '♟️';
  if (game === 'Gomoku') return '⚫';
  return '🎮';
}

function gameName(game: string): string {
  if (game === '2048') return '2048';
  if (game === 'Snake') return '贪吃蛇';
  if (game === 'Tetris') return '俄罗斯方块';
  if (game === 'Minesweeper') return '扫雷';
  if (game === 'SUDOKU') return '数独';
  if (game === 'ChineseChess') return '中国象棋';
  if (game === 'Gomoku') return '五子棋';
  return game;
}

function isBoardGame(game: string): boolean {
  return game === 'Gomoku' || game === 'ChineseChess';
}

function fmtTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
  return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

function medal(rank: number): string {
  if (rank === 1) return '🥇';
  if (rank === 2) return '🥈';
  if (rank === 3) return '🥉';
  return rank.toString();
}

@ComponentV2
@Entry
export struct LeaderboardPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local gameKey: string = 'all';
  @Local entries: LeaderboardEntry[] = [];
  @Local cloud: boolean = false;
  @Local loading: boolean = true;

  private gameKeys: string[] = ['all', '2048', 'Snake', 'Tetris', 'Minesweeper', 'SUDOKU', 'ChineseChess', 'Gomoku'];

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.cloud = await LeaderboardService.cloudEnabled();
    this.entries = await LeaderboardService.localTop(this.gameKey, 50);
    this.loading = false;
  }

  build() {
    Column() {
      TopBar({ title: '排行榜', subtitle: this.cloud ? 'Game Service Kit 云端排行' : '本地排行', showBack: true })
      // 游戏选择（横向可滑动）
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.gameKeys, (key: string) => {
            Row({ space: 3 }) {
              Text(key === 'all' ? '🎮' : gameIcon(key))
                .fontSize(this.themeState.palette.fsSm)
              Text(key === 'all' ? '全部' : gameName(key))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.gameKey === key ? this.themeState.palette.textPrimary : this.themeState.palette.textTertiary)
                .fontWeight(this.gameKey === key ? FontWeight.Bold : FontWeight.Normal)
            }
            .height(32)
            .padding({ left: 10, right: 10 })
            .borderRadius(8)
            .backgroundColor(this.gameKey === key ? this.themeState.palette.primary + '22' : Color.Transparent)
            .onClick(() => {
              this.gameKey = key;
              this.load();
            })
          })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .edgeEffect(EdgeEffect.None)

      // 纵向内容
      Scroll() {
        Column() {
          if (this.loading) {
          Column() {
            LoadingProgress().width(32).height(32)
          }
          .width('100%')
          .padding(40)
        } else if (this.entries.length === 0) {
          Column({ space: 8 }) {
            Text('🏆').fontSize(44)
            Text('暂无上榜记录')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textSecondary)
          }
          .width('100%')
          .padding(40)
        } else {
          Column({ space: 6 }) {
            ForEach(this.entries, (entry: LeaderboardEntry) => {
              Row({ space: 10 }) {
                Text(medal(entry.rank))
                  .fontSize(this.themeState.palette.fsXl)
                  .width(32)
                  .textAlign(TextAlign.Center)
                Text(gameIcon(entry.game))
                  .fontSize(18)
                Column({ space: 2 }) {
                  Text(gameName(entry.game) + (isBoardGame(entry.game) ? (entry.score > 0 ? ' · 胜' : ' · 负') : ' · ' + entry.score.toString() + ' 分'))
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Text(entry.difficulty + ' · ' + fmtTime(entry.createdAt))
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (entry.model.length > 0) {
                  Text(entry.model)
                    .fontSize(10)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.info)
                    .maxLines(1)
                    .constraintSize({ maxWidth: 80 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .padding(10)
              .borderRadius(10)
              .backgroundColor(this.themeState.palette.bgSurface)
            }, (entry: LeaderboardEntry) => entry.rank.toString() + '_' + entry.createdAt.toString())
          }
          .width('100%')
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, bottom: 20 })
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

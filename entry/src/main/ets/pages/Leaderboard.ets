// 智子 - 排行榜（本地排行；Game Service Kit 云端就绪后可切换）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppNavigator } from '../common/AppNavigator';
import { LeaderboardService, LeaderboardEntry } from '../service/game/LeaderboardService';

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
        Row({ space: this.themeState.palette.sp2 }) {
          ForEach(this.gameKeys, (key: string) => {
            Row({ space: this.themeState.palette.sp1 }) {
              Text(key === 'all' ? '🎮' : gameIcon(key))
                .fontSize(this.themeState.palette.fsSm)
              Text(key === 'all' ? '全部' : gameName(key))
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
              this.load();
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

      // 纵向内容
      if (this.loading) {
        Column({ space: this.themeState.palette.sp2 }) {
          LoadingProgress().width(32).height(32)
          Text('正在加载排行榜…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.entries.length === 0) {
        Column({ space: this.themeState.palette.sp3 }) {
          Text('🏆').fontSize(44)
          Text('还没有上榜记录')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('完成一局游戏后，最高分会自动进入本地排行榜')
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
            ForEach(this.entries, (entry: LeaderboardEntry) => {
              ListItem() {
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
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.info)
                    .maxLines(1)
                    .constraintSize({ maxWidth: 80 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .constraintSize({ minHeight: this.themeState.palette.rowHeight })
              .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4,
                top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp2 })
              }
            }, (entry: LeaderboardEntry) => entry.rank.toString() + '_' + entry.createdAt.toString())
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

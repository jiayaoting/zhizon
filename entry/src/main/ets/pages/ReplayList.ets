// 智子 - 对局回放列表（查看 / 回放 / 删除）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { ReplayService, ReplayRecord } from '../service/ReplayService';
import { AppNavigator } from '../common/AppNavigator';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchRequest, GameRouteParams } from '../common/Difficulty';
import { PageKey } from '../common/Navigation';

function gameLabel(game: string): string {
  if (game === '2048') return '2048';
  if (game === 'Snake') return '贪吃蛇';
  if (game === 'Tetris') return '俄罗斯方块';
  if (game === 'Minesweeper') return '扫雷';
  if (game === 'SUDOKU') return '数独';
  if (game === 'ChineseChess') return '中国象棋';
  if (game === 'Gomoku') return '五子棋';
  return game;
}

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

function gameIdOf(game: string): GameId | null {
  if (game === '2048') return GameId.GAME_2048;
  if (game === 'Snake') return GameId.SNAKE;
  if (game === 'Gomoku') return GameId.GOMOKU;
  return null;
}

function fmtTime(ts: number): string {
  const d: Date = new Date(ts);
  const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
  return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

function fmtDuration(ms: number): string {
  const s: number = Math.floor(ms / 1000);
  const m: number = Math.floor(s / 60);
  const sec: number = s % 60;
  return m.toString() + ':' + (sec < 10 ? '0' + sec.toString() : sec.toString());
}

@ComponentV2
@Entry
export struct ReplayListPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local records: ReplayRecord[] = [];
  @Local loading: boolean = true;

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.records = await ReplayService.list();
    this.loading = false;
  }

  private async play(record: ReplayRecord): Promise<void> {
    const gameId: GameId | null = gameIdOf(record.game);
    if (gameId === null) {
      promptAction.showToast({ message: '该游戏暂不支持回放' });
      return;
    }
    const registration = GameLaunchFacade.registration(gameId);
    if (registration === null) {
      promptAction.showToast({ message: '游戏页面不可用' });
      return;
    }
    const request: GameLaunchRequest = new GameLaunchRequest(gameId, DifficultyLevel.MEDIUM,
      PageKey.Games, GameLaunchFacade.nextVersion());
    AppNavigator.push(registration.routeUrl, new GameRouteParams(request, record.id));
  }

  private async remove(record: ReplayRecord): Promise<void> {
    await ReplayService.delete(record.id);
    await this.load();
    promptAction.showToast({ message: '已删除该回放' });
  }

  @Builder
  recordCard(record: ReplayRecord) {
    Row({ space: 12 }) {
      Text(gameIcon(record.game))
        .fontSize(26)
      Column({ space: 4 }) {
        Text(gameLabel(record.game) + ' · ' + fmtTime(record.createdAt))
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Row({ space: 10 }) {
          Text('得分 ' + record.score.toString())
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
          Text('Lv.' + record.level.toString())
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
          Text('用时 ' + fmtDuration(record.durationMs))
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('▶ 回放')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(8)
        .backgroundColor(this.themeState.palette.primary)
        .onClick(() => { this.play(record); })
      Text('🗑️')
        .fontSize(16)
        .padding(6)
        .onClick(() => { this.remove(record); })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 1, color: this.themeState.palette.borderSubtle })
  }

  build() {
    Column() {
      TopBar({ title: '对局回放', subtitle: '支持 2048 / 贪吃蛇 / 五子棋', showBack: true })
      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.records.length === 0) {
        Column({ space: 8 }) {
          Text('🎬').fontSize(44)
          Text('暂无回放')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
          Text('完成一局 2048 / 贪吃蛇 / 五子棋后会自动保存回放')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
        List({ space: 10 }) {
          ForEach(this.records, (record: ReplayRecord) => {
            ListItem() {
              this.recordCard(record)
            }
          }, (record: ReplayRecord) => record.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
          top: 12, bottom: 24 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

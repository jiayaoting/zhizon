// 智子 - 对局回放列表（查看 / 回放 / 删除）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { ReplayService, ReplayRecord } from '../service/game/ReplayService';
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
    Row({ space: this.themeState.palette.sp3 }) {
      Text(gameIcon(record.game))
        .fontSize(26)
      Column({ space: this.themeState.palette.sp1 }) {
        Text(gameLabel(record.game) + ' · ' + fmtTime(record.createdAt))
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: this.themeState.palette.sp3 }) {
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
        .fontColor(this.themeState.palette.primaryOnColor)
        .height(this.themeState.palette.touchTarget)
        .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
        .textAlign(TextAlign.Center)
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.themeState.palette.primary)
        .accessibilityText('回放')
        .onClick(() => { this.play(record); })

      Row() {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(AppIcons.trash)
            .fontSize(18)
            .fontColor([this.themeState.palette.danger])
        } else {
          Text(AppIcons.trashEmoji)
            .fontSize(16)
            .fontFamily(this.themeState.palette.fontSans)
        }
      }
      .width(this.themeState.palette.touchTarget)
      .height(this.themeState.palette.touchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(this.themeState.palette.radiusSm)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .accessibilityText('删除回放')
      .onClick(() => { this.remove(record); })
    }
    .width('100%')
    .constraintSize({ minHeight: this.themeState.palette.rowHeight })
    .padding(this.themeState.palette.sp3)
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
  }

  build() {
    Column() {
      TopBar({ title: '对局回放', subtitle: '支持 2048 / 贪吃蛇 / 五子棋', showBack: true })
      if (this.loading) {
        Column({ space: this.themeState.palette.sp2 }) {
          LoadingProgress().width(32).height(32)
          Text('正在加载回放…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.records.length === 0) {
        Column({ space: this.themeState.palette.sp3 }) {
          Text('🎬').fontSize(44)
          Text('还没有可回放的对局')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('完成一局 2048 / 贪吃蛇 / 五子棋后会自动保存回放')
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
        List({ space: this.themeState.palette.cardGap }) {
          ForEach(this.records, (record: ReplayRecord) => {
            ListItem() {
              this.recordCard(record)
            }
          }, (record: ReplayRecord) => record.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp1, bottom: this.themeState.palette.sp6 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

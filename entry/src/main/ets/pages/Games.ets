// 智子 - 游戏中心
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { PAGE_PADDING, CARD_RADIUS } from '../common/Constants';
import { DifficultyDefinition, DifficultyLevel, DIFFICULTY_DEFINITIONS, GameId, GameLaunchFacade,
  GameLaunchRequest, GameLaunchResult } from '../common/Difficulty';
import { DifficultyOption } from '../components/DifficultyOption';
import { PageKey } from '../common/Navigation';

interface GameEntry {
  gameId: GameId;
  name: string;
  icon: string;
  desc: string;
  color: string;
}

@Component
export struct GamesPage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('isMd') isMd: boolean = false;
  @StorageLink('isLg') isLg: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @State selectedDifficulty: DifficultyLevel = DifficultyLevel.MEDIUM;

  private games: GameEntry[] = [
    {
      gameId: GameId.TETRIS,
      name: '俄罗斯方块',
      icon: '🧱',
      desc: '经典方块消除游戏，支持触屏手势和按钮双控制',
      color: this.palette.primary
    },
    {
      gameId: GameId.GAME_2048,
      name: '2048',
      icon: '🔢',
      desc: '滑动合并数字，挑战 2048 极限',
      color: this.palette.warning
    },
    {
      gameId: GameId.SNAKE,
      name: '贪吃蛇',
      icon: '🐍',
      desc: '经典贪吃蛇，控制方向吃食物不断变长',
      color: this.palette.success
    },
    {
      gameId: GameId.MINESWEEPER,
      name: '扫雷',
      icon: '💣',
      desc: '逻辑推理经典，翻开数字找出所有地雷',
      color: this.palette.purple
    },
    {
      gameId: GameId.BREAKOUT,
      name: '打砖块',
      icon: '🎱',
      desc: '经典街机弹球，击碎所有砖块闯关',
      color: this.palette.danger
    },
    {
      gameId: GameId.SUDOKU,
      name: '数独',
      icon: '🧩',
      desc: '数字推理经典，每行每列每宫填 1-9 不重复',
      color: this.palette.info
    }
  ];

  private async openGame(game: GameEntry): Promise<void> {
    const request: GameLaunchRequest = new GameLaunchRequest(game.gameId, this.selectedDifficulty,
      PageKey.Games, GameLaunchFacade.nextVersion());
    const result: GameLaunchResult = await GameLaunchFacade.open(request);
    if (!result.success) promptAction.showToast({ message: result.message });
  }

  @Builder
  difficultyPicker() {
    Column({ space: 8 }) {
      Text('游戏难度')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      ForEach(DIFFICULTY_DEFINITIONS, (definition: DifficultyDefinition) => {
        DifficultyOption({
          definition: definition,
          selected: this.selectedDifficulty === definition.level,
          onSelect: (level: DifficultyLevel): void => { this.selectedDifficulty = level; }
        })
      }, (definition: DifficultyDefinition) => definition.level)
    }
    .width('100%')
  }

  @Builder
  gameCard(game: GameEntry, index: number) {
    Column() {
      Row({ space: 12 }) {
        // 游戏图标
        Stack() {
          Column()
            .width(48)
            .height(48)
            .borderRadius(12)
            .backgroundColor(game.color + '1A')
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
          Text(game.icon)
            .fontSize(24)
            .fontFamily(this.palette.fontSans)
        }

        Column({ space: 4 }) {
          Text(game.name)
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text(game.desc)
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .backgroundColor(this.palette.bgSurface)
    .borderRadius(CARD_RADIUS)
    .border({ width: 1, color: this.palette.borderSubtle })
    .onClick(() => { this.openGame(game); })
    .focusable(true)
    .tabIndex(index)
  }

  build() {
    Column() {
      TopBar({ title: '游戏中心', subtitle: '休闲娱乐' })

      Scroll() {
        Column({ space: 12 }) {
          this.difficultyPicker()

          // 标题区
          Text('可用游戏')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 4, top: 8, bottom: 4 })
            .width('100%')

          ForEach(this.games, (game: GameEntry, index: number) => {
            this.gameCard(game, index)
          }, (game: GameEntry) => game.gameId)


        }
        .width('100%')
        .padding({
          left: this.isSm ? 16 : 24,
          right: this.isSm ? 16 : 24,
          bottom: 24
        })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .focusable(true)
      .onKeyEvent((event: KeyEvent) => {
        // 确保页面可聚焦，Tab 导航由系统处理
        return;
      })
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

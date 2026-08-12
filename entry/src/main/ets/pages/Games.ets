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
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @State showHelpFor: GameId | null = null;
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
      gameId: GameId.SUDOKU,
      name: '数独',
      icon: '🧩',
      desc: '数字推理经典，每行每列每宫填 1-9 不重复',
      color: this.palette.info
    }
  ];

  private gameHelpText(gameId: GameId): string {
    if (gameId === GameId.TETRIS) {
      return '🎮 俄罗斯方块\n\n' +
        '【目标】\n消除满行获取高分，尽可能坚持更久。\n\n' +
        '【操作】\n' +
        '• 方向键 ← →：左右移动方块\n' +
        '• 方向键 ↑：旋转方块\n' +
        '• 方向键 ↓：加速下落\n' +
        '• 空格键：方块直接落底\n' +
        '• 触屏：左右滑动移动，点击旋转\n' +
        '• H 按钮：暂存当前方块\n\n' +
        '【规则】\n' +
        '• 方块填满一行即可消除，消除行数越多单次得分越高\n' +
        '• 消除 1 行 = 100 分，2 行 = 300 分，3 行 = 500 分，4 行 = 800 分\n' +
        '• 方块堆叠到顶部则游戏结束';
    }
    if (gameId === GameId.GAME_2048) {
      return '🎮 2048\n\n' +
        '【目标】\n滑动合并相同数字，最终合并出 2048 方块。\n\n' +
        '【操作】\n' +
        '• 方向键 / 滑动屏幕：向对应方向滑动，所有方块一起移动\n' +
        '• 相同数字的方块碰撞后合并为它们的和\n' +
        '• 每次移动后会在空白位置随机生成一个 2 或 4\n\n' +
        '【规则】\n' +
        '• 棋盘满格且无法继续合并时游戏结束\n' +
        '• 合并出 2048 方块即为胜利，可继续挑战更高分\n' +
        '• 不同难度影响初始方块数量和 4 的出现概率';
    }
    if (gameId === GameId.SNAKE) {
      return '🎮 贪吃蛇\n\n' +
        '【目标】\n控制蛇移动吃掉食物，每吃一个蛇身增长，尽可能得高分。\n\n' +
        '【操作】\n' +
        '• 方向键 / 滑动屏幕：控制蛇的移动方向\n' +
        '• 蛇不能掉头（不能直接反向移动）\n' +
        '• 按空格键或点击暂停按钮可暂停/继续\n\n' +
        '【规则】\n' +
        '• 蛇头撞到墙壁或自己的身体则游戏结束\n' +
        '• 每吃一个食物得 10 分，蛇身长度 +1\n' +
        '• 难度越高，蛇的移动速度越快';
    }
    if (gameId === GameId.MINESWEEPER) {
      return '🎮 扫雷\n\n' +
        '【目标】\n翻开所有非地雷的格子，找出所有地雷的位置。\n\n' +
        '【操作】\n' +
        '• 左键点击格子：翻开格子\n' +
        '• 长按 / 标记按钮：标记/取消标记地雷（🚩）\n' +
        '• 翻开的数字表示周围 8 格中地雷的数量\n\n' +
        '【规则】\n' +
        '• 点到地雷则游戏结束\n' +
        '• 数字格表明周围地雷数，帮助推理安全格\n' +
        '• 标记所有地雷并翻开所有安全格即为胜利\n' +
        '• 首次点击必定安全（不会踩雷）';
    }
    if (gameId === GameId.SUDOKU) {
      return '🎮 数独\n\n' +
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
        '• 填完所有空格即为胜利';
    }
    return '';
  }

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

        // 使用说明按钮
        Row() {
          Text('📖')
            .fontSize(16)
            .fontFamily(this.palette.fontSans)
        }
        .width(36)
        .height(36)
        .borderRadius(8)
        .backgroundColor(this.palette.bgSurface2)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showHelpFor = game.gameId; })
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

  @Builder
  helpDialog() {
    if (this.showHelpFor !== null) {
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
                .onClick(() => { this.showHelpFor = null; })
            }
            .width('100%')
            .padding({ right: 4, top: 4 })

            Scroll() {
              Text(this.gameHelpText(this.showHelpFor as GameId))
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
      .onClick(() => { this.showHelpFor = null; })
    }
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

    this.helpDialog()
  }
}

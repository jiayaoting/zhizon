// 智子 - 游戏中心（v10 华为原生拟物白：图标大卡网格 + 数据入口行）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AppNavigator } from '../common/AppNavigator';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { DifficultyDefinition, DifficultyLevel, DIFFICULTY_DEFINITIONS, GameId, GameLaunchFacade,
  GameLaunchRequest, GameLaunchResult, difficultyLabel } from '../common/Difficulty';
import { DifficultyOption } from '../components/DifficultyOption';
import { PageKey } from '../common/Navigation';

interface GameEntry {
  gameId: GameId;
  name: string;
  icon: string;
  desc: string;
  color: string;
}

// 游戏数据入口行（战绩统计 / 对局回放 / 排行榜 / 成就 / 游戏设置）
class GameToolEntry {
  title: string;
  icon: Resource;
  iconEmoji: string;
  route: string;

  constructor(title: string, icon: Resource, iconEmoji: string, route: string) {
    this.title = title;
    this.icon = icon;
    this.iconEmoji = iconEmoji;
    this.route = route;
  }
}

@ComponentV2
export struct GamesPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local showHelpFor: GameId | null = null;
  // 待选难度的游戏（点击游戏卡片后弹出该游戏专属难度选择）
  @Local pendingGame: GameEntry | null = null;
  @Local pendingDifficulty: DifficultyLevel = DifficultyLevel.MEDIUM;

  private get games(): GameEntry[] {
    return [
    {
      gameId: GameId.TETRIS,
      name: '俄罗斯方块',
      icon: '🧱',
      desc: '经典方块消除游戏，支持触屏手势和按钮双控制',
      color: this.themeState.palette.primary
    },
    {
      gameId: GameId.GAME_2048,
      name: '2048',
      icon: '🔢',
      desc: '滑动合并数字，挑战 2048 极限',
      color: this.themeState.palette.warning
    },
    {
      gameId: GameId.SNAKE,
      name: '贪吃蛇',
      icon: '🐍',
      desc: '经典贪吃蛇，控制方向吃食物不断变长',
      color: this.themeState.palette.success
    },
    {
      gameId: GameId.MINESWEEPER,
      name: '扫雷',
      icon: '💣',
      desc: '逻辑推理经典，翻开数字找出所有地雷',
      color: this.themeState.palette.purple
    },
    {
      gameId: GameId.SUDOKU,
      name: '数独',
      icon: '🧩',
      desc: '数字推理经典，每行每列每宫填 1-9 不重复',
      color: this.themeState.palette.info
    },
    {
      gameId: GameId.CHINESE_CHESS,
      name: '中国象棋',
      icon: '♟️',
      desc: '人机 / 人对AI / AI对AI，经典楚河汉界',
      color: this.themeState.palette.danger
    },
    {
      gameId: GameId.GOMOKU,
      name: '五子棋',
      icon: '⚫',
      desc: '15×15 棋盘，人机对弈，率先连五获胜',
      color: this.themeState.palette.primary
    }
  ];
  }

  // 数据入口：导航目标与 Profile / 设置页保持一致
  private get tools(): GameToolEntry[] {
    return [
      new GameToolEntry('战绩统计', AppIcons.chart, AppIcons.chartEmoji, 'pages/GameStats'),
      new GameToolEntry('对局回放', AppIcons.play, AppIcons.playEmoji, 'pages/ReplayList'),
      new GameToolEntry('排行榜', AppIcons.trophy, AppIcons.trophyEmoji, 'pages/Leaderboard'),
      new GameToolEntry('成就', AppIcons.starFill, AppIcons.starFillEmoji, 'pages/Achievements'),
      new GameToolEntry('游戏设置', AppIcons.settings, AppIcons.settingsEmoji, 'pages/GameSettings')
    ];
  }

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
    if (gameId === GameId.CHINESE_CHESS) {
      return '🎮 中国象棋\n\n' +
        '【模式】\n' +
        '• 人机：你对本地 AI 引擎\n' +
        '• 人对AI：你对大模型\n' +
        '• AI对AI：两个大模型对弈（可各自选不同模型）\n\n' +
        '【操作】\n' +
        '• 点击己方棋子选中，再点击高亮目标格落子\n' +
        '• AI 思考时棋盘锁定，状态栏会提示哪方思考中\n' +
        '• 💡 AI提示：轮到你的回合点击，AI 给出建议走法，确认后落子\n' +
        '• ↩ 悔棋：回退一步（受本局悔棋次数限制）\n\n' +
        '【规则】\n' +
        '• 红方先手，帅/将不出九宫且不能对脸\n' +
        '• 马蹩腿、象塞象眼且不过河、炮隔子吃\n' +
        '• 兵/卒过河后可横走，不能后退\n' +
        '• 将死或困毙对方即获胜';
    }
    if (gameId === GameId.GOMOKU) {
      return '🎮 五子棋\n\n' +
        '【目标】\n' +
        '黑白双方轮流在交叉点落子，率先形成横、竖、斜任意方向连续 5 子（含 5 子以上）即获胜。\n\n' +
        '【操作】\n' +
        '• 点击棋盘交叉点落子，你是黑方先手\n' +
        '• 白方由本地 AI 引擎执子，难度越高思考越深\n' +
        '• ↩ 悔棋：回退上一步（每局有次数上限）\n' +
        '• 🤖 AI 托管：让大模型替你执黑落子\n\n' +
        '【规则】\n' +
        '• 连成 5 子及以上获胜，平局为棋盘下满\n' +
        '• 注意防守：对手连成 4 子时必须立即堵住';
    }
    return '';
  }

  private async openGame(game: GameEntry): Promise<void> {
    const request: GameLaunchRequest = new GameLaunchRequest(game.gameId, this.pendingDifficulty,
      PageKey.Games, GameLaunchFacade.nextVersion());
    const result: GameLaunchResult = await GameLaunchFacade.open(request);
    if (!result.success) promptAction.showToast({ message: result.message });
  }

  // 待选择难度的游戏（@Builder 中不允许局部变量声明，用 getter 取值）
  private pendingGameEntry(): GameEntry {
    return this.pendingGame as GameEntry;
  }

  // 左右安全边距：手机 16vp / 大屏 24vp
  private horizontalPadding(): string {
    return this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg;
  }

  // 卡片元信息：当前选择的难度（页面既有状态，不新增数据来源）
  private tileMeta(): string {
    return '默认难度 · ' + difficultyLabel(this.pendingDifficulty);
  }

  // 2 列网格：每行 2 个游戏卡（避免在 Scroll 内嵌 Grid 的高度问题）
  private gameRows(): GameEntry[][] {
    const all: GameEntry[] = this.games;
    const rows: GameEntry[][] = [];
    for (let i: number = 0; i < all.length; i += 2) {
      const row: GameEntry[] = [all[i]];
      if (i + 1 < all.length) row.push(all[i + 1]);
      rows.push(row);
    }
    return rows;
  }

  // 长按快捷菜单（主流程仍由点击进入难度选择）
  private tileMenu(game: GameEntry): MenuElement[] {
    const helpIcon: ResourceStr = USE_SYMBOL_ICONS ? AppIcons.doc : AppIcons.docEmoji;
    const playIcon: ResourceStr = USE_SYMBOL_ICONS ? AppIcons.play : AppIcons.playEmoji;
    const items: MenuElement[] = [
      { value: '查看帮助', icon: helpIcon, action: (): void => { this.showHelpFor = game.gameId; } },
      { value: '选择难度', icon: playIcon, action: (): void => { this.pendingGame = game; } }
    ];
    return items;
  }

  @Builder
  difficultyDialog() {
    if (this.pendingGame !== null) {
      Stack() {
        Column() {
          Blank()
          Column() {
            Row() {
              Text(this.pendingGameEntry().icon)
                .fontSize(this.themeState.palette.fs2xl)
                .fontFamily(this.themeState.palette.fontSans)
              Text(this.pendingGameEntry().name)
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
                .margin({ left: this.themeState.palette.sp2 })
              Blank()
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(AppIcons.close)
                    .fontSize(20)
                    .fontColor([this.themeState.palette.textTertiary])
                } else {
                  Text(AppIcons.closeEmoji)
                    .fontSize(this.themeState.palette.fsLg)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
              }
              .width(this.themeState.palette.touchTarget)
              .height(this.themeState.palette.touchTarget)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .borderRadius(this.themeState.palette.radiusSm)
              .accessibilityText('关闭')
              .onClick(() => { this.pendingGame = null; })
            }
            .width('100%')
            .padding({ left: this.themeState.palette.sp1, top: this.themeState.palette.sp1 })

            Text('选择难度')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: this.themeState.palette.sp2, bottom: this.themeState.palette.sp1 })

            Scroll() {
              Column({ space: this.themeState.palette.sp2 }) {
                ForEach(DIFFICULTY_DEFINITIONS, (definition: DifficultyDefinition) => {
                  DifficultyOption({
                    definition: definition,
                    selected: this.pendingDifficulty === definition.level,
                    onSelect: (level: DifficultyLevel): void => { this.pendingDifficulty = level; }
                  })
                }, (definition: DifficultyDefinition) => definition.level)
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: 360 })

            Button('开始游戏')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primaryOnColor)
              .width('100%')
              .height(this.themeState.palette.touchTarget)
              .borderRadius(this.themeState.palette.radiusCapsule)
              .backgroundColor(this.themeState.palette.primary)
              .margin({ top: this.themeState.palette.sp3 })
              .onClick(() => {
                const game: GameEntry = this.pendingGameEntry();
                this.pendingGame = null;
                this.openGame(game);
              })
          }
          .width('100%')
          .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
          .backgroundColor(this.themeState.palette.bgElevated)
          .padding({ left: this.themeState.palette.sp5, right: this.themeState.palette.sp5,
            bottom: Math.max(16, this.themeState.navBarHeight) })
          .onClick(() => {})
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.maskOverlay)
      .onClick(() => { this.pendingGame = null; })
    }
  }

  @Builder
  gameTile(game: GameEntry, index: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: this.themeState.palette.sp2 }) {
        // 图标大卡区（保留各游戏原有 emoji / 字形）
        Stack() {
          Column()
            .width(60)
            .height(60)
            .borderRadius(this.themeState.palette.radiusMd)
            .backgroundColor(game.color + '1A')
          Text(game.icon)
            .fontSize(36)
            .fontFamily(this.themeState.palette.fontSans)
        }

        Text(game.name)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.tileMeta())
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3,
        top: this.themeState.palette.sp4, bottom: this.themeState.palette.sp4 })

      // 使用说明入口（保留原有 📖 行为）
      Row() {
        if (USE_SYMBOL_ICONS) {
          SymbolGlyph(AppIcons.doc)
            .fontSize(18)
            .fontColor([this.themeState.palette.textTertiary])
        } else {
          Text(AppIcons.docEmoji)
            .fontSize(14)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
      }
      .width(this.themeState.palette.touchTarget)
      .height(this.themeState.palette.touchTarget)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(this.themeState.palette.radiusSm)
      .accessibilityText('使用说明')
      .onClick(() => { this.showHelpFor = game.gameId; })
    }
    .layoutWeight(1)
    .backgroundColor(this.themeState.palette.bgSurface)
    .borderRadius(this.themeState.palette.radiusLg)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .clip(true)
    .stateStyles({
      pressed: {
        .backgroundColor(this.themeState.palette.bgHover)
      }
    })
    .onClick(() => { this.pendingGame = game; })
    .bindMenu(this.tileMenu(game))
    .focusable(true)
    .tabIndex(index)
    .accessibilityText(game.name + '，' + game.desc)
  }

  @Builder
  gameGrid() {
    Column({ space: this.themeState.palette.cardGap }) {
      ForEach(this.gameRows(), (row: GameEntry[], rowIndex: number) => {
        Row({ space: this.themeState.palette.cardGap }) {
          ForEach(row, (game: GameEntry, colIndex: number) => {
            this.gameTile(game, rowIndex * 2 + colIndex)
          }, (game: GameEntry) => game.gameId)
          // 奇数个游戏时右侧占位，保持两列等宽
          if (row.length === 1) {
            Column().layoutWeight(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: GameEntry[], rowIndex: number) => 'gameRow_' + rowIndex.toString())
    }
    .width('100%')
  }

  // 注册表为空时的兜底空态（原因 + 下一步）
  @Builder
  emptyGames() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('🎮')
        .fontSize(44)
        .fontFamily(this.themeState.palette.fontSans)
      Text('暂无可玩游戏')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text('游戏注册表未就绪，可能是版本数据未加载完成')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      Button('前往游戏设置')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .height(this.themeState.palette.touchTarget)
        .padding({ left: this.themeState.palette.sp6, right: this.themeState.palette.sp6 })
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.themeState.palette.primary)
        .margin({ top: this.themeState.palette.sp2 })
        .onClick(() => { AppNavigator.push('pages/GameSettings'); })
    }
    .width('100%')
    .padding(this.themeState.palette.sp6)
    .backgroundColor(this.themeState.palette.bgSurface)
    .borderRadius(this.themeState.palette.radiusLg)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .justifyContent(FlexAlign.Center)
  }

  // 数据入口列表（56vp 行 + 发丝分割线 + 右箭头）
  @Builder
  toolsSection() {
    Column({ space: this.themeState.palette.sp2 }) {
      Text('游戏数据')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Column() {
        ForEach(this.tools, (tool: GameToolEntry, index: number) => {
          Column() {
            Row({ space: this.themeState.palette.sp3 }) {
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(tool.icon)
                    .fontSize(20)
                    .fontColor([this.themeState.palette.primary])
                    .accessibilityLevel('no')
                } else {
                  Text(tool.iconEmoji)
                    .fontSize(16)
                    .fontFamily(this.themeState.palette.fontSans)
                }
              }
              .width(32)
              .height(32)
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.themeState.palette.primaryBg)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)

              Text(tool.title)
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (USE_SYMBOL_ICONS) {
                SymbolGlyph(AppIcons.forward)
                  .fontSize(20)
                  .fontColor([this.themeState.palette.textTertiary])
                  .accessibilityLevel('no')
              } else {
                Text(AppIcons.forwardEmoji)
                  .fontSize(18)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
              }
            }
            .width('100%')
            .height(this.themeState.palette.rowHeight)
            .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
            .stateStyles({
              pressed: {
                .backgroundColor(this.themeState.palette.bgHover)
              }
            })
            .accessibilityText(tool.title)
            .onClick(() => { AppNavigator.push(tool.route); })

            if (index < this.tools.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color(this.themeState.palette.divider)
                .margin({ left: this.themeState.palette.dividerIndent })
            }
          }
          .width('100%')
        }, (tool: GameToolEntry) => tool.route)
      }
      .width('100%')
      .backgroundColor(this.themeState.palette.bgSurface)
      .borderRadius(this.themeState.palette.radiusLg)
      .border({ width: 0.5, color: this.themeState.palette.divider })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
              Row() {
                if (USE_SYMBOL_ICONS) {
                  SymbolGlyph(AppIcons.close)
                    .fontSize(20)
                    .fontColor([this.themeState.palette.textTertiary])
                } else {
                  Text(AppIcons.closeEmoji)
                    .fontSize(this.themeState.palette.fsLg)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
              }
              .width(this.themeState.palette.touchTarget)
              .height(this.themeState.palette.touchTarget)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .borderRadius(this.themeState.palette.radiusSm)
              .accessibilityText('关闭')
              .onClick(() => { this.showHelpFor = null; })
            }
            .width('100%')
            .padding({ right: this.themeState.palette.sp1, top: this.themeState.palette.sp1 })

            Scroll() {
              Text(this.gameHelpText(this.showHelpFor as GameId))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .lineHeight(this.themeState.palette.fsXl)
                .width('100%')
            }
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: 400 })
            .padding({ left: this.themeState.palette.sp5, right: this.themeState.palette.sp5,
              bottom: this.themeState.palette.sp4 })
          }
          .width('100%')
          .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
          .backgroundColor(this.themeState.palette.bgElevated)
          .padding({ bottom: Math.max(16, this.themeState.navBarHeight) })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.maskOverlay)
      .onClick(() => { this.showHelpFor = null; })
    }
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '游戏', subtitle: '休闲娱乐' })

        Scroll() {
          Column() {
            // 可用游戏：2 列图标大卡
            Text('全部游戏')
              .fontSize(this.themeState.palette.fsLg)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .margin({ top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp2 })

            if (this.games.length === 0) {
              this.emptyGames()
            } else {
              this.gameGrid()
            }

            // 数据与工具入口
            Column() {
              this.toolsSection()
            }
            .width('100%')
            .margin({ top: this.themeState.palette.sectionGap })

            Column().height(this.themeState.palette.sp6)
          }
          .width('100%')
          .padding({
            left: this.horizontalPadding(),
            right: this.horizontalPadding(),
            bottom: this.themeState.palette.sp6
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
      .backgroundColor(this.themeState.palette.bgBase)

      this.helpDialog()
      this.difficultyDialog()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

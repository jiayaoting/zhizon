// 智子 - 首页（沉浸光感版）
// 欢迎区 + 游戏入口大卡 + 最近游戏战绩
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { DataRepository } from '../service/DataRepository';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';
import { DifficultyLevel, GameId, GameLaunchFacade,
  GameLaunchRequest, GameLaunchResult } from '../common/Difficulty';
import { PageKey, GameHistoryRouteParams } from '../common/Navigation';
import { ParticleBackground } from '../components/ParticleBackground';

interface HomeGameEntry {
  gameId: GameId;
  name: string;
  icon: string;
  desc: string;
  color: string;
}

interface ScoreRow {
  gameId: GameId;
  name: string;
  icon: string;
  color: string;
  best: number;
}

@ComponentV2
export struct IndexPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local currentTime: string = '';
  @Local greeting: string = '';
              @Local scoreRows: ScoreRow[] = [];
  @Local loading: boolean = true;
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Event onNavigate: (key: string) => void = () => {};

  // 首页游戏入口
  private get homeGames(): HomeGameEntry[] {
    return [
    {
      gameId: GameId.TETRIS,
      name: '俄罗斯方块',
      icon: '🧱',
      desc: '经典方块消除，触屏手势 + 按钮双控制',
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
      desc: '控制方向吃食物，不断变长',
      color: this.themeState.palette.success
    },
    {
      gameId: GameId.MINESWEEPER,
      name: '扫雷',
      icon: '💣',
      desc: '逻辑推理，翻开数字找出地雷',
      color: this.themeState.palette.purple
    },
    {
      gameId: GameId.SUDOKU,
      name: '数独',
      icon: '🧩',
      desc: '数字推理，每行每列每宫填 1-9 不重复',
      color: this.themeState.palette.info
    },
    {
      gameId: GameId.GOMOKU,
      name: '五子棋',
      icon: '⚫',
      desc: '15×15 棋盘人机对弈，率先连五获胜',
      color: this.themeState.palette.primary
    }
  ];
  }

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadAvatar();
    this.loadScores();
  }

  aboutToDisappear(): void {
    // 单次拉取，无持久资源需要释放
  }

  private async loadAvatar(): Promise<void> {
    const id = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarId = id;
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
  }

  // 游戏 GameId 枚举 → 数据库存储的 game key 映射
  private gameScoreKey(gameId: GameId): string {
    if (gameId === GameId.TETRIS) return 'Tetris';
    if (gameId === GameId.GAME_2048) return '2048';
    if (gameId === GameId.SNAKE) return 'Snake';
    if (gameId === GameId.MINESWEEPER) return 'Minesweeper';
    if (gameId === GameId.SUDOKU) return 'SUDOKU';
    if (gameId === GameId.GOMOKU) return 'Gomoku';
    return '';
  }

  private async loadScores() {
    try {
      const rows: ScoreRow[] = [];
      for (const game of this.homeGames) {
        const best = await DataRepository.getGameHighScore(this.gameScoreKey(game.gameId));
        rows.push({
          gameId: game.gameId,
          name: game.name,
          icon: game.icon,
          color: game.color,
          best: best
        });
      }
      this.scoreRows = rows;
    } finally {
      this.loading = false;
    }
  }

  // 分数位数越多字号越小，避免超出卡片宽度
  private scoreFontSize(score: number): number {
    const len: number = score.toString().length;
    if (len >= 7) return 11;
    if (len >= 6) return 13;
    if (len >= 5) return 16;
    if (len >= 4) return 19;
    return 22;
  }

  private getGreeting(): string {
    const h = new Date().getHours();
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  private formatNow(): string {
    const d = new Date();
    const pad = (n: number) => n < 10 ? `0${n}` : `${n}`;
    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];
    return `${d.getFullYear()}年${pad(d.getMonth() + 1)}月${pad(d.getDate())}日 星期${weekDays[d.getDay()]}`;
  }

  // 默认中等难度启动游戏
  private async openGame(game: HomeGameEntry): Promise<void> {
    const request: GameLaunchRequest = new GameLaunchRequest(game.gameId, DifficultyLevel.MEDIUM,
      PageKey.Games, GameLaunchFacade.nextVersion());
    const result: GameLaunchResult = await GameLaunchFacade.open(request);
    if (!result.success) promptAction.showToast({ message: result.message });
  }

  // ==================== 欢迎区 ====================
  @Builder
  welcomeSection() {
    Row() {
      Column() {
        Text(this.greeting)
          .fontSize(this.themeState.palette.fsXl + 4)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.currentTime)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 用户头像（可在设置中修改样式或选择自定义图片）
      Stack() {
        if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
          Image(this.avatarUri)
            .width(this.themeState.isSm ? 40 : 44)
            .height(this.themeState.isSm ? 40 : 44)
            .borderRadius(this.themeState.isSm ? 20 : 22)
            .objectFit(ImageFit.Cover)
            .border({ width: 1.5, color: '#80FFFFFF' })
        } else {
          // 渐变底
          Column()
            .width(this.themeState.isSm ? 40 : 44)
            .height(this.themeState.isSm ? 40 : 44)
            .borderRadius(this.themeState.isSm ? 20 : 22)
            .linearGradient({
              angle: 135,
              colors: [[avatarColors(this.avatarId)[0], 0.0], [avatarColors(this.avatarId)[1], 1.0]]
            })
            .shadow({ radius: 12, color: avatarColors(this.avatarId)[0] + '55', offsetX: 0, offsetY: 4 })
          // 描边圆环
          Column()
            .width(this.themeState.isSm ? 40 : 44)
            .height(this.themeState.isSm ? 40 : 44)
            .borderRadius(this.themeState.isSm ? 20 : 22)
            .border({ width: 1.5, color: '#80FFFFFF' })
          // Z 字
          Text('Z')
            .fontSize(this.themeState.isSm ? 16 : 18)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
      }
      .onClick(() => {
        this.onNavigate('Settings');
      })
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 游戏入口大卡 ====================
  @Builder
  gameEntryCards() {
    Column({ space: 0 }) {
      Row() {
        Text('游戏中心')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('查看全部 ›')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .onClick(() => {
            this.onNavigate('Games');
          })
      }
      .width('100%')
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Column({ space: 10 }) {
        ForEach(this.homeGames, (game: HomeGameEntry, index: number) => {
          Row({ space: 14 }) {
            // 图标
            Stack() {
              Circle({ width: 48, height: 48 })
                .fill(game.color)
              Text(game.icon)
                .fontSize(24)
                .fontFamily(this.themeState.palette.fontSans)
            }
            .width(48)
            .height(48)

            // 标题 + 描述
            Column({ space: 4 }) {
              Text(game.name)
                .fontSize(this.themeState.palette.fsBase + 2)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Text(game.desc)
                .fontSize(this.themeState.palette.fsSm - 1)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 开始按钮
            Button('开始')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .backgroundColor(game.color)
              .borderRadius(14)
              .height(28)
              .padding({ left: 14, right: 14 })
              .onClick(() => {
                this.openGame(game);
              })
          }
          .width('100%')
          .padding(14)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
          .alignItems(VerticalAlign.Center)
          .focusable(true)
          .tabIndex(index)
        }, (game: HomeGameEntry) => game.gameId)
      }
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 最近游戏战绩 ====================
  @Builder
  recentScores() {
    Column({ space: 0 }) {
      Row() {
        Text('最佳战绩')
          .fontSize(this.themeState.palette.fsMd)
          .fontColor(this.themeState.palette.textPrimary)
          .fontFamily(this.themeState.palette.fontSans)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('进入游戏 ›')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .onClick(() => {
            this.onNavigate('Games');
          })
      }
      .width('100%')
      .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.scoreRows, (row: ScoreRow) => {
            Column({ space: 6 }) {
              Text(row.icon)
                .fontSize(this.themeState.palette.fsLg)
                .fontFamily(this.themeState.palette.fontSans)
              Text(row.name)
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textSecondary)
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${row.best}`)
                .fontSize(this.scoreFontSize(row.best))
                .fontColor(row.color)
                .fontWeight(FontWeight.Bold)
                .fontFamily(this.themeState.palette.fontMono)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('查看记录 ›')
                .fontSize(this.themeState.palette.fsXs - 2)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
            }
            .width(110)
            .padding({ top: 16, bottom: 16 })
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
            .alignItems(HorizontalAlign.Center)
            .onClick(() => { this.openHistory(row.gameId); })
          }, (row: ScoreRow) => row.gameId)
        }
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
  }

  // 点击战绩卡进入对应游戏的历史记录（不再固定跳 2048）
  private openHistory(gameId: GameId): void {
    const key: string = this.gameHistoryKey(gameId);
    if (key.length === 0) return;
    AppNavigator.push('pages/GameHistory', new GameHistoryRouteParams(key));
  }

  private gameHistoryKey(gameId: GameId): string {
    if (gameId === GameId.TETRIS) return 'Tetris';
    if (gameId === GameId.GAME_2048) return '2048';
    if (gameId === GameId.SNAKE) return 'Snake';
    if (gameId === GameId.MINESWEEPER) return 'Minesweeper';
    if (gameId === GameId.SUDOKU) return 'SUDOKU';
    if (gameId === GameId.GOMOKU) return 'Gomoku';
    return '';
  }

  build() {
    Stack() {
      // 星尘粒子背景
      ParticleBackground()

      Column() {
        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.themeState.palette.primary)
            Text('加载中...')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textSecondary)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 20 }) {
              // 大屏居中限制
              Column({ space: 20 }) {
                // 欢迎区
                this.welcomeSection()

                // 游戏入口大卡
                this.gameEntryCards()

                // 最佳战绩
                this.recentScores()

                // 底部留白
                Column().height(20)
              }
              .width('100%')
              .constraintSize({ maxWidth: this.themeState.isLg ? 720 : undefined })
            }
            .width('100%')
            .padding({ top: this.themeState.statusBarHeight + (this.themeState.isSm ? 16 : 24) })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
          .focusable(true)
          .onKeyEvent((event: KeyEvent) => {
            if (event.type !== KeyType.Down) return;
            const code: KeyCode = event.keyCode;
            if (code === KeyCode.KEYCODE_TAB) {
              // 默认 Tab 行为由系统处理，此处仅确保页面可聚焦
              return;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
  }
}

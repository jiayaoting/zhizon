// 智子 - 首页（沉浸光感版）
// 欢迎区 + 游戏入口大卡 + 最近游戏战绩
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { DataRepository } from '../service/DataRepository';
import { DifficultyDefinition, DifficultyLevel, DIFFICULTY_DEFINITIONS, GameId, GameLaunchFacade,
  GameLaunchRequest, GameLaunchResult } from '../common/Difficulty';
import { PageKey } from '../common/Navigation';

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

@Component
export struct IndexPage {
  @State currentTime: string = '';
  @State greeting: string = '';
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 20;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @State scoreRows: ScoreRow[] = [];
  @State loading: boolean = true;
  onNavigate: (key: string) => void = () => {};

  // 首页游戏入口
  private homeGames: HomeGameEntry[] = [
    {
      gameId: GameId.TETRIS,
      name: '俄罗斯方块',
      icon: '🧱',
      desc: '经典方块消除，触屏手势 + 按钮双控制',
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
      desc: '控制方向吃食物，不断变长',
      color: this.palette.success
    },
    {
      gameId: GameId.MINESWEEPER,
      name: '扫雷',
      icon: '💣',
      desc: '逻辑推理，翻开数字找出地雷',
      color: this.palette.purple
    },
    {
      gameId: GameId.BREAKOUT,
      name: '打砖块',
      icon: '🎱',
      desc: '弹球击碎所有砖块',
      color: this.palette.danger
    }
  ];

  aboutToAppear() {
    this.currentTime = this.formatNow();
    this.greeting = this.getGreeting();
    this.loadScores();
  }

  aboutToDisappear(): void {
    // 单次拉取，无持久资源需要释放
  }

  private async loadScores() {
    try {
      const rows: ScoreRow[] = [];
      for (const game of this.homeGames) {
        const best = await DataRepository.getGameHighScore(game.gameId);
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
          .fontSize(24)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text(this.currentTime)
          .fontSize(12)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 用户头像
      Stack() {
        Circle({ width: 40, height: 40 })
          .fill(this.palette.bgElevated)
          .border({ width: 2, color: this.palette.primary })
        Text('Z')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 游戏入口大卡 ====================
  @Builder
  gameEntryCards() {
    Column({ space: 0 }) {
      Row() {
        Text('游戏中心')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('查看全部 ›')
          .fontSize(12)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .onClick(() => {
            this.onNavigate('Games');
          })
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Column({ space: 10 }) {
        ForEach(this.homeGames, (game: HomeGameEntry) => {
          Row({ space: 14 }) {
            // 图标
            Stack() {
              Circle({ width: 48, height: 48 })
                .fill(game.color)
              Text(game.icon)
                .fontSize(24)
                .fontFamily(this.palette.fontSans)
            }
            .width(48)
            .height(48)

            // 标题 + 描述
            Column({ space: 4 }) {
              Text(game.name)
                .fontSize(15)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Bold)
              Text(game.desc)
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 开始按钮
            Button('开始')
              .fontSize(12)
              .fontFamily(this.palette.fontSans)
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
          .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
          .alignItems(VerticalAlign.Center)
        }, (game: HomeGameEntry) => game.gameId)
      }
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 最近游戏战绩 ====================
  @Builder
  recentScores() {
    Column({ space: 0 }) {
      Row() {
        Text('最佳战绩')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('历史记录 ›')
          .fontSize(12)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.primary)
          .onClick(() => {
            this.onNavigate('Games');
          })
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Row({ space: 10 }) {
        ForEach(this.scoreRows, (row: ScoreRow) => {
          Column({ space: 6 }) {
            Text(row.icon)
              .fontSize(20)
              .fontFamily(this.palette.fontSans)
            Text(row.name)
              .fontSize(11)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
              .fontWeight(FontWeight.Medium)
            Text(`${row.best}`)
              .fontSize(22)
              .fontColor(row.color)
              .fontWeight(FontWeight.Bold)
              .fontFamily(this.palette.fontMono)
            Text('最高分')
              .fontSize(9)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          .layoutWeight(1)
          .padding({ top: 16, bottom: 16 })
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
          .alignItems(HorizontalAlign.Center)
        }, (row: ScoreRow) => row.gameId)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
    }
    .width('100%')
  }

  // ==================== 难度速览 ====================
  @Builder
  difficultyQuickView() {
    Column({ space: 0 }) {
      Row() {
        Text('难度速览')
          .fontSize(16)
          .fontColor(this.palette.textPrimary)
          .fontFamily(this.palette.fontSans)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      .margin({ bottom: 12 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(DIFFICULTY_DEFINITIONS, (def: DifficultyDefinition) => {
            Column({ space: 4 }) {
              Text(def.icon)
                .fontSize(20)
                .fontFamily(this.palette.fontSans)
              Text(def.label)
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text(def.description)
                .fontSize(9)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width(110)
            .padding({ top: 14, bottom: 14 })
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .alignItems(HorizontalAlign.Center)
          }, (def: DifficultyDefinition) => def.level)
        }
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.palette.primary)
          Text('加载中...')
            .fontSize(14)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 20 }) {
            // 欢迎区
            this.welcomeSection()

            // 游戏入口大卡
            this.gameEntryCards()

            // 最佳战绩
            this.recentScores()

            // 难度速览
            this.difficultyQuickView()

            // 底部留白
            Column().height(20)
          }
          .width('100%')
          .padding({ top: this.statusBarHeight + (this.isSm ? 16 : 24) })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
    }
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

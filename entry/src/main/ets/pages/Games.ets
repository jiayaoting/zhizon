// 智子 - 游戏中心
import { router } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { PAGE_PADDING, CARD_RADIUS } from '../common/Constants';

interface GameEntry {
  key: string;
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

  private games: GameEntry[] = [
    {
      key: 'Tetris',
      name: '俄罗斯方块',
      icon: '🧱',
      desc: '经典方块消除游戏，支持触屏手势和按钮双控制',
      color: AppTheme.primary
    },
    {
      key: '2048',
      name: '2048',
      icon: '🔢',
      desc: '滑动合并数字，挑战 2048 极限',
      color: AppTheme.warning
    },
    {
      key: 'Snake',
      name: '贪吃蛇',
      icon: '🐍',
      desc: '经典贪吃蛇，控制方向吃食物不断变长',
      color: AppTheme.success
    }
  ];

  private openGame(game: GameEntry): void {
    let url: string = 'pages/Tetris';
    if (game.key === 'Tetris') {
      url = 'pages/Tetris';
    } else if (game.key === '2048') {
      url = 'pages/Game2048';
    } else if (game.key === 'Snake') {
      url = 'pages/Snake';
    }
    const params: Record<string, string> = { 'title': game.name };
    router.pushUrl({ url: url, params: params });
  }

  @Builder
  gameCard(game: GameEntry) {
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
        }

        Column({ space: 4 }) {
          Text(game.name)
            .fontSize(AppTheme.fsLg)
            .fontColor(AppTheme.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text(game.desc)
            .fontSize(AppTheme.fsSm)
            .fontColor(AppTheme.textSecondary)
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
    .backgroundColor(AppTheme.bgSurface)
    .borderRadius(CARD_RADIUS)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .onClick(() => { this.openGame(game); })
  }

  build() {
    Column() {
      TopBar({ title: '游戏中心', subtitle: '休闲娱乐' })

      Scroll() {
        Column({ space: 12 }) {
          // 标题区
          Text('可用游戏')
            .fontSize(AppTheme.fsSm)
            .fontColor(AppTheme.textTertiary)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 4, top: 8, bottom: 4 })
            .width('100%')

          ForEach(this.games, (game: GameEntry) => {
            this.gameCard(game)
          }, (game: GameEntry) => game.key)


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
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

// 智子 - 游戏历史战绩
import { router } from '@kit.ArkUI';
import { DataRepository } from '../service/DataRepository';
import { ScoreEntry } from '../service/DatabaseHelper';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GameHistoryRouteParams } from '../common/Navigation';

function isGameHistoryKey(key: string): boolean {
  return key === '2048' || key === 'Snake' || key === 'Tetris';
}

function gameIcon(key: string): string {
  if (key === 'Snake') return '🐍';
  if (key === 'Tetris') return '🧱';
  return '🔢';
}

function gameName(key: string): string {
  if (key === 'Snake') return '贪吃蛇';
  if (key === 'Tetris') return '俄罗斯方块';
  return '2048';
}

function difficultyColor(difficulty: string, fallback: string): string {
  if (difficulty === '超简单') return '#10B981';
  if (difficulty === '简单') return '#3B82F6';
  if (difficulty === '中等') return '#F59E0B';
  if (difficulty === '困难') return '#F97316';
  if (difficulty === '地狱') return '#EF4444';
  return fallback;
}

function formatTime(ts: number): string {
  const d: Date = new Date(ts);
  const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
  const day: string = d.getDate().toString().padStart(2, '0');
  const h: string = d.getHours().toString().padStart(2, '0');
  const min: string = d.getMinutes().toString().padStart(2, '0');
  return `${m}-${day} ${h}:${min}`;
}

function medalIcon(rank: number): string {
  if (rank === 0) return '🥇';
  if (rank === 1) return '🥈';
  if (rank === 2) return '🥉';
  return (rank + 1).toString();
}

@Entry
@Component
export struct GameHistoryPage {
  @State gameKey: string = '2048';
  @State scores: ScoreEntry[] = [];
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;

  private gameKeys: string[] = ['2048', 'Snake', 'Tetris'];

  aboutToAppear(): void {
    const params: GameHistoryRouteParams | null = router.getParams() as GameHistoryRouteParams | null;
    if (params !== null && params !== undefined && isGameHistoryKey(params.game)) {
      this.gameKey = params.game;
    }
    this.loadScores();
  }

  async loadScores(): Promise<void> {
    this.loading = true;
    this.scores = await DataRepository.getGameScores(this.gameKey);
    this.loading = false;
  }

  async clearScores(): Promise<void> {
    await DataRepository.clearGameScores(this.gameKey);
    this.scores = [];
  }

  build() {
    Column() {
      TopBar({ title: '游戏战绩', showBack: true })

      // 游戏切换标签
      Row({ space: 0 }) {
        ForEach(this.gameKeys, (key: string) => {
          Row({ space: 4 }) {
            Text(gameIcon(key))
              .fontSize(14)
            Text(gameName(key))
              .fontSize(this.palette.fsSm)
              .fontColor(this.gameKey === key ? this.palette.textPrimary : this.palette.textTertiary)
              .fontWeight(this.gameKey === key ? FontWeight.Bold : FontWeight.Normal)
          }
          .layoutWeight(1)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.gameKey === key ? this.palette.primary + '20' : Color.Transparent)
          .border({ width: this.gameKey === key ? 1.5 : 0, color: this.gameKey === key ? this.palette.primary : Color.Transparent })
          .margin({ right: 8 })
          .onClick(() => {
            this.gameKey = key;
            this.loadScores();
          })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 排行列表
      if (this.scores.length === 0 && !this.loading) {
        Column({ space: 8 }) {
          Text('📋')
            .fontSize(48)
          Text('暂无战绩')
            .fontSize(this.palette.fsLg)
            .fontColor(this.palette.textTertiary)
          Text('快去玩一局吧！')
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 6 }) {
          ForEach(this.scores, (entry: ScoreEntry, idx: number) => {
            ListItem() {
              Row({ space: 10 }) {
                // 排名
                Text(medalIcon(idx))
                  .fontSize(20)
                  .width(32)
                  .textAlign(TextAlign.Center)

                // 分数
                Column({ space: 2 }) {
                  Text(entry.score.toString())
                    .fontSize(this.palette.fsXl)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Bold)
                  Text('分数')
                    .fontSize(this.palette.fsXs)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                Blank()

                // 等级
                Column({ space: 2 }) {
                  Text('Lv.' + entry.level.toString())
                    .fontSize(this.palette.fsMd)
                    .fontColor(this.palette.warning)
                    .fontWeight(FontWeight.Medium)
                  Text('等级')
                    .fontSize(this.palette.fsXs)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                // 难度
                Column({ space: 2 }) {
                  Text(entry.difficulty)
                    .fontSize(this.palette.fsSm)
                    .fontColor(difficultyColor(entry.difficulty, this.palette.textSecondary))
                    .fontWeight(FontWeight.Medium)
                  Text('难度')
                    .fontSize(this.palette.fsXs)
                    .fontColor(this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Center)

                // 时间
                Text(formatTime(entry.createdAt))
                  .fontSize(this.palette.fsXs)
                  .fontColor(this.palette.textTertiary)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(idx % 2 === 0 ? this.palette.bgSurface : this.palette.bgSurface2)
              .borderRadius(8)
            }
          }, (entry: ScoreEntry) => entry.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12 })
      }

      // 底部操作栏
      Row({ space: 12 }) {
        Row() {
          Text('🗑 清空战绩')
            .fontSize(this.palette.fsSm)
            .fontColor(this.palette.textTertiary)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.palette.bgSurface2)
        .borderRadius(8)
        .border({ width: 1, color: this.palette.borderSubtle })
        .onClick(() => { this.clearScores(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

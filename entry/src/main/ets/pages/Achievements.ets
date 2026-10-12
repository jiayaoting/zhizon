// 智子 - 成就墙（解锁状态 + 进度展示）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { AchievementService } from '../service/game/AchievementService';
import { AchievementState, achievementDefinition, achievementCategoryLabel } from '../common/AchievementModels';

function fmtTime(ts: number): string {
  if (ts <= 0) return '';
  const d: Date = new Date(ts);
  const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
    ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

@ComponentV2
@Entry
export struct AchievementsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local states: AchievementState[] = [];
  @Local loading: boolean = true;

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.states = await AchievementService.getAll();
    this.loading = false;
  }

  private unlockedCount(): number {
    let n: number = 0;
    for (let i: number = 0; i < this.states.length; i++) {
      if (this.states[i].unlocked) n += 1;
    }
    return n;
  }

  private defName(id: string): string {
    const def = achievementDefinition(id);
    return def !== null ? def.name : id;
  }

  private defDesc(id: string): string {
    const def = achievementDefinition(id);
    return def !== null ? def.desc : '';
  }

  private defIcon(id: string): string {
    const def = achievementDefinition(id);
    return def !== null ? def.icon : '🏅';
  }

  private defTarget(id: string): number {
    const def = achievementDefinition(id);
    return def !== null ? def.target : 1;
  }

  private defExists(id: string): boolean {
    return achievementDefinition(id) !== null;
  }

  @Builder
  achievementCard(state: AchievementState) {
    Row({ space: this.themeState.palette.sp3 }) {
      Text(this.defIcon(state.id))
        .fontSize(28)
      Column({ space: this.themeState.palette.sp1 }) {
        Row({ space: this.themeState.palette.sp2 }) {
          Text(this.defName(state.id))
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (state.unlocked) {
            Text('✓ ' + fmtTime(state.unlockedAt))
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.success)
          }
        }
        .width('100%')
        Text(this.defDesc(state.id))
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
        if (this.defExists(state.id)) {
          Row({ space: this.themeState.palette.sp2 }) {
            Progress({
              value: Math.min(state.progress, this.defTarget(state.id)),
              total: this.defTarget(state.id),
              type: ProgressType.Linear
            })
              .height(6)
              .color(this.themeState.palette.primary)
              .layoutWeight(1)
            Text(state.progress.toString() + '/' + this.defTarget(state.id).toString())
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
          .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(this.themeState.palette.sp4)
    .borderRadius(this.themeState.palette.radiusMd)
    .backgroundColor(state.unlocked ? this.themeState.palette.primaryBg : this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: state.unlocked ? this.themeState.palette.primary : this.themeState.palette.divider })
    .opacity(state.unlocked ? 1 : 0.82)
  }

  @Builder
  categorySection(category: string, items: AchievementState[]) {
    Column({ space: this.themeState.palette.sp2 }) {
      Text(achievementCategoryLabel(category))
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: this.themeState.palette.sp2 }) {
        ForEach(items, (item: AchievementState) => {
          this.achievementCard(item)
        }, (item: AchievementState) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 空态引导：成就数据未就绪时给出重试入口
  @Builder
  emptyState() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text('🏅').fontSize(44)
      Text('成就数据未就绪')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text('成就定义尚未加载完成，重试即可重新读取')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
        .textAlign(TextAlign.Center)
      Button('重新加载')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .height(this.themeState.palette.touchTarget)
        .padding({ left: this.themeState.palette.sp6, right: this.themeState.palette.sp6 })
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.themeState.palette.primary)
        .margin({ top: this.themeState.palette.sp1 })
        .onClick(() => { this.load(); })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: this.themeState.palette.sp8, right: this.themeState.palette.sp8 })
  }

  build() {
    Column() {
      TopBar({ title: '成就', subtitle: this.unlockedCount().toString() + '/' + this.states.length.toString() + ' 已解锁', showBack: true })
      if (this.loading) {
        Column({ space: this.themeState.palette.sp2 }) {
          LoadingProgress().width(32).height(32)
          Text('正在加载成就…')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.states.length === 0) {
        this.emptyState()
      } else {
        Scroll() {
          Column({ space: this.themeState.palette.sectionGap }) {
            this.categorySection('游戏', this.states.filter((s: AchievementState): boolean =>
              achievementDefinition(s.id) !== null && achievementDefinition(s.id)!.category === '游戏'))
            this.categorySection('对话', this.states.filter((s: AchievementState): boolean =>
              achievementDefinition(s.id) !== null && achievementDefinition(s.id)!.category === '对话'))
            Column().height(this.themeState.palette.sp5)
          }
          .width('100%')
          .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: this.themeState.palette.sp3 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

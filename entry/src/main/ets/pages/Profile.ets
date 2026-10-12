// 智子 - 我的页（v10 华为原生拟物白）
// 结构（§3.2）：头部账号卡（账号 + 统计 meta）→ 热榜数据 / 游戏 / AI / 通用 四张分组卡。
// IA（§3.5 入口去重）：本页只留「看」的入口（收藏 / 周报 / 成就 / 战绩 / 回放 / 排行）与账号、通用；
// 「热榜设置」收敛到 设置 → 热榜（首页 ⚙ 保留为快捷），「搜索热榜」收敛到首页顶栏 🔍，
// 均不再在本页重复出现。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { AppConstants } from '../common/Constants';
import { LegalDocRouteParams } from '../common/Navigation';
import { DataRepository } from '../service/platform/DataRepository';
import { HuaweiAccountService } from '../service/platform/HuaweiAccountService';
import { NewsRepository, HotStats } from '../service/hot/NewsRepository';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';

@ComponentV2
export struct ProfilePage {
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Local huaweiNick: string = '';
  @Local stats: HotStats = { favoriteCount: 0, readCount: 0, aiCallCount: 0 };
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onNavigate: (key: string) => void = () => {};

  aboutToAppear(): void {
    this.loadAvatar();
    this.loadStats();
    this.loadAccount();
  }

  private async loadAccount(): Promise<void> {
    try {
      const profile = await HuaweiAccountService.getStoredProfile();
      this.huaweiNick = profile !== null ? profile.nickName : '';
    } catch (e) {
      this.huaweiNick = '';
    }
  }

  // 账号卡点击：未登录 → 登录华为账号；已登录 → 进入设置（账号与云同步组）
  private async onIdentityTap(): Promise<void> {
    if (this.huaweiNick.length > 0) {
      this.onNavigate('Settings');
      return;
    }
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      promptAction.showToast({ message: '无法获取应用上下文' });
      return;
    }
    try {
      const profile = await HuaweiAccountService.signIn(ctx);
      this.huaweiNick = profile.nickName.length > 0 ? profile.nickName : profile.openId;
      promptAction.showToast({ message: '已登录华为账号：' + this.huaweiNick });
    } catch (e) {
      promptAction.showToast({ message: '登录失败或已取消' });
    }
  }

  private async loadAvatar(): Promise<void> {
    this.avatarId = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
  }

  private async loadStats(): Promise<void> {
    try {
      this.stats = await NewsRepository.stats();
    } catch (e) {
    }
  }

  // ==================== 行构件（图标 22vp / 行高 56vp / 发丝分割线 36vp 缩进对齐标题）====================
  @Builder
  rowIcon(symbol: Resource, emoji: string) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(symbol)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
      }
    }
    .width(24)
    .height(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  forwardArrow() {
    if (USE_SYMBOL_ICONS) {
      SymbolGlyph(AppIcons.forward)
        .fontSize(16)
        .fontColor([this.themeState.palette.textTertiary])
    } else {
      Text(AppIcons.forwardEmoji)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
  }

  @Builder
  rowDivider() {
    Divider()
      .color(this.themeState.palette.divider)
      .strokeWidth(0.5)
      .margin({ left: 36 })
  }

  @Builder
  groupHeader(title: string) {
    Text(title)
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.textTertiary)
      .width('100%')
      .textAlign(TextAlign.Start)
  }

  @Builder
  navRow(symbol: Resource, emoji: string, title: string, showDivider: boolean, onTap: () => void) {
    Column({ space: 0 }) {
      Row({ space: this.themeState.palette.sp3 }) {
        this.rowIcon(symbol, emoji)
        Text(title)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        this.forwardArrow()
      }
      .width('100%')
      .height(this.themeState.palette.rowHeight)
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        pressed: {
          .backgroundColor(this.themeState.palette.bgHover)
        }
      })
      .accessibilityText(title)
      .onClick(() => {
        onTap();
      })

      if (showDivider) {
        this.rowDivider()
      }
    }
    .width('100%')
  }

  // 只读信息行（右侧为值、无箭头，如「版本」）
  @Builder
  infoRow(symbol: Resource, emoji: string, title: string, value: string, showDivider: boolean) {
    Column({ space: 0 }) {
      Row({ space: this.themeState.palette.sp3 }) {
        this.rowIcon(symbol, emoji)
        Text(title)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .maxLines(1)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Text(value)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
      }
      .width('100%')
      .height(this.themeState.palette.rowHeight)
      .alignItems(VerticalAlign.Center)
      .accessibilityText(title + '，' + value)

      if (showDivider) {
        this.rowDivider()
      }
    }
    .width('100%')
  }

  // ==================== 头部账号卡 ====================
  @Builder
  statMeta(label: string, value: number) {
    Row({ space: this.themeState.palette.sp1 }) {
      Text(value.toString())
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text(label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .accessibilityText(label + '，' + value.toString())
  }

  @Builder
  accountCard() {
    Column({ space: this.themeState.palette.sp3 }) {
      Row({ space: this.themeState.palette.sp4 }) {
        // 头像（自定义图片 / 预设渐变）
        Stack() {
          if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
            Image(this.avatarUri)
              .width(56)
              .height(56)
              .borderRadius(28)
              .objectFit(ImageFit.Cover)
              .border({ width: 0.5, color: this.themeState.palette.borderDefault })
          } else {
            Column()
              .width(56)
              .height(56)
              .borderRadius(28)
              .linearGradient({
                angle: 135,
                colors: [[avatarColors(this.avatarId)[0], 0.0], [avatarColors(this.avatarId)[1], 1.0]]
              })
            Text('Z')
              .fontSize(24)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.primaryOnColor)
              .fontWeight(FontWeight.Bold)
          }
        }
        .width(56)
        .height(56)
        .onClick(() => {
          this.onIdentityTap();
        })

        Column({ space: 2 }) {
          Text(this.huaweiNick.length > 0 ? this.huaweiNick : '未登录')
            .fontSize(this.themeState.palette.fsLg)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
          Text(this.huaweiNick.length > 0 ? '华为账号已登录' : '登录后开启云同步')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .accessibilityText(this.huaweiNick.length > 0 ? this.huaweiNick + '，华为账号已登录' : '未登录，点击登录')
        .onClick(() => {
          this.onIdentityTap();
        })

        // 未登录：登录 CTA；已登录：账号二级入口箭头
        if (this.huaweiNick.length > 0) {
          this.forwardArrow()
        } else {
          Text('登录')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primaryOnColor)
            .fontWeight(FontWeight.Medium)
            .height(36)
            .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
            .borderRadius(this.themeState.palette.radiusCapsule)
            .backgroundColor(this.themeState.palette.primary)
            .textAlign(TextAlign.Center)
            .accessibilityText('登录华为账号')
            .onClick(() => {
              this.onIdentityTap();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color(this.themeState.palette.divider)
        .strokeWidth(0.5)

      // 数据 meta（收藏 / 已读 / AI 调用）：只读展示，入口在下方分组卡
      Row({ space: this.themeState.palette.sp5 }) {
        this.statMeta('收藏', this.stats.favoriteCount)
        this.statMeta('已读', this.stats.readCount)
        this.statMeta('AI 调用', this.stats.aiCallCount)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(this.themeState.palette.sp4)
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
  }

  // ==================== 分组卡：热榜数据 ====================
  @Builder
  newsGroup() {
    Column({ space: this.themeState.palette.sp2 }) {
      this.groupHeader('热榜数据')
      Column({ space: 0 }) {
        this.navRow(AppIcons.starFill, AppIcons.starFillEmoji, '收藏', true, () => {
          AppNavigator.push('pages/NewsFavorites');
        })
        this.navRow(AppIcons.calendar, AppIcons.calendarEmoji, '阅读周报', false, () => {
          AppNavigator.push('pages/ReadingReport');
        })
      }
      .width('100%')
      .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 分组卡：游戏 ====================
  @Builder
  gameGroup() {
    Column({ space: this.themeState.palette.sp2 }) {
      this.groupHeader('游戏')
      Column({ space: 0 }) {
        this.navRow(AppIcons.trophy, AppIcons.trophyEmoji, '成就', true, () => {
          AppNavigator.push('pages/Achievements');
        })
        this.navRow(AppIcons.chart, AppIcons.chartEmoji, '战绩统计', true, () => {
          AppNavigator.push('pages/GameStats');
        })
        this.navRow(AppIcons.play, AppIcons.playEmoji, '对局回放', true, () => {
          AppNavigator.push('pages/ReplayList');
        })
        this.navRow(AppIcons.list, AppIcons.listEmoji, '排行榜', false, () => {
          AppNavigator.push('pages/Leaderboard');
        })
      }
      .width('100%')
      .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 分组卡：AI ====================
  @Builder
  aiGroup() {
    Column({ space: this.themeState.palette.sp2 }) {
      this.groupHeader('AI')
      Column({ space: 0 }) {
        // 「我的 → AI 模型」是模型配置的唯一主入口（§3.5）
        this.navRow(AppIcons.slider, AppIcons.sliderEmoji, 'AI 模型', true, () => {
          AppNavigator.push('pages/AiModelPage');
        })
        this.navRow(AppIcons.navProfile, AppIcons.navProfileEmoji, 'AI 角色模板', true, () => {
          AppNavigator.push('pages/AiRoleLibrary');
        })
        this.navRow(AppIcons.clock, AppIcons.clockEmoji, 'AI 调用记录', false, () => {
          AppNavigator.push('pages/AiCallLog');
        })
      }
      .width('100%')
      .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ==================== 分组卡：通用（设置 + 关于）====================
  @Builder
  generalGroup() {
    Column({ space: this.themeState.palette.sp2 }) {
      this.groupHeader('通用')
      Column({ space: 0 }) {
        this.navRow(AppIcons.settings, AppIcons.settingsEmoji, '设置', true, () => {
          this.onNavigate('Settings');
        })
        this.infoRow(AppIcons.doc, AppIcons.docEmoji, '版本', AppConstants.appVersion, true)
        this.navRow(AppIcons.bookmark, AppIcons.bookmarkEmoji, '用户协议', true, () => {
          AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('agreement'));
        })
        this.navRow(AppIcons.lock, AppIcons.lockEmoji, '隐私政策', true, () => {
          AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('privacy'));
        })
        this.navRow(AppIcons.link, AppIcons.linkEmoji, '开源许可', false, () => {
          AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('license'));
        })
      }
      .width('100%')
      .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
      .borderRadius(this.themeState.palette.radiusLg)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 0.5, color: this.themeState.palette.divider })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Scroll() {
        Row() {
          Column({ space: this.themeState.palette.sectionGap }) {
            this.accountCard()
            this.newsGroup()
            this.gameGroup()
            this.aiGroup()
            this.generalGroup()
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({
            left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: Math.max(this.themeState.statusBarHeight, 44) + 8,
            bottom: this.themeState.palette.sp6
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

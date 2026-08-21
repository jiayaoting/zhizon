// 智子 - 我的页（身份卡 + 业务分组入口：资讯/游戏/AI）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { SettingRow } from '../components/SettingRow';
import { DataRepository } from '../service/DataRepository';
import { HuaweiAccountService } from '../service/HuaweiAccountService';
import { NewsRepository, NewsStats } from '../service/NewsRepository';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';

@ComponentV2
export struct ProfilePage {
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Local huaweiNick: string = '';
  @Local stats: NewsStats = { favoriteCount: 0, readCount: 0, aiCallCount: 0 };
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

  // 身份区点击：未登录 → 登录华为账号；已登录 → 进入设置（账号与云同步）
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

  @Builder
  headerCard() {
    Column({ space: 14 }) {
      Row({ space: 16 }) {
        // 头像（点击进入设置）
        Stack() {
          if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
            Image(this.avatarUri)
              .width(64)
              .height(64)
              .borderRadius(32)
              .objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: '#80FFFFFF' })
          } else {
            Column()
              .width(64)
              .height(64)
              .borderRadius(32)
              .linearGradient({
                angle: 135,
                colors: [[avatarColors(this.avatarId)[0], 0.0], [avatarColors(this.avatarId)[1], 1.0]]
              })
              .shadow({ radius: 12, color: avatarColors(this.avatarId)[0] + '55', offsetX: 0, offsetY: 4 })
            Text('Z')
              .fontSize(28)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
        }
        .onClick(() => { this.onNavigate('Settings'); })

        Column({ space: 4 }) {
          Text(this.huaweiNick.length > 0 ? this.huaweiNick : '未登录')
            .fontSize(this.themeState.palette.fsXl)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.huaweiNick.length > 0 ? '华为账号已登录' : '点击登录 · 开启云同步')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .accessibilityText(this.huaweiNick.length > 0 ? this.huaweiNick + '，华为账号已登录' : '未登录，点击登录')
        .onClick(() => { this.onIdentityTap(); })

        Row() {
          Text('⚙')
            .fontSize(18)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.themeState.palette.primaryDim)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('设置')
        .onClick(() => { this.onNavigate('Settings'); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 三格数据（收藏 / 已读 / AI 资讯调用）
      Row({ space: 8 }) {
        this.statCell('⭐', this.stats.favoriteCount, '收藏', () => { AppNavigator.push('pages/NewsFavorites'); })
        this.statCell('👁', this.stats.readCount, '已读', () => { AppNavigator.push('pages/NewsStats'); })
        this.statCell('🤖', this.stats.aiCallCount, 'AI 调用', () => { AppNavigator.push('pages/AiCallLog'); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
  }

  @Builder
  statCell(icon: string, value: number, label: string, onTap?: () => void) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(14)
        .fontFamily(this.themeState.palette.fontSans)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor(this.themeState.palette.primaryDim)
      Text(value.toString())
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(this.themeState.palette.fsXs - 1)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
    .onClick(() => {
      if (onTap) {
        onTap();
      }
    })
    .accessibilityText(label + '，' + value.toString())
  }

  @Builder
  newsGroup() {
    Column({ space: 10 }) {
      Text('资讯')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: 8 }) {
        SettingRow({ icon: '⭐', title: '收藏 / 稍后读', rowClick: () => { AppNavigator.push('pages/NewsFavorites'); } })
        SettingRow({ icon: '👍', title: '我的点赞', rowClick: () => { AppNavigator.push('pages/NewsLikes'); } })
        SettingRow({ icon: '🎯', title: '为你推荐', rowClick: () => { AppNavigator.push('pages/NewsRecommend'); } })
        SettingRow({ icon: '🧠', title: '个性化画像', rowClick: () => { AppNavigator.push('pages/NewsProfile'); } })
        SettingRow({ icon: '📊', title: '资讯统计', rowClick: () => { AppNavigator.push('pages/NewsStats'); } })
        SettingRow({ icon: '📅', title: '阅读周报', rowClick: () => { AppNavigator.push('pages/ReadingReport'); } })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  gameGroup() {
    Column({ space: 10 }) {
      Text('游戏')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: 8 }) {
        SettingRow({ icon: '🏆', title: '成就', rowClick: () => { AppNavigator.push('pages/Achievements'); } })
        SettingRow({ icon: '🎬', title: '对局回放', rowClick: () => { AppNavigator.push('pages/ReplayList'); } })
        SettingRow({ icon: '📈', title: '排行榜', rowClick: () => { AppNavigator.push('pages/Leaderboard'); } })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  systemGroup() {
    Column({ space: 10 }) {
      Text('AI')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: 8 }) {
        SettingRow({ icon: '🤖', title: 'AI 模型', rowClick: () => { AppNavigator.push('pages/AiModelPage'); } })
        SettingRow({ icon: '🎭', title: 'AI 角色模板', rowClick: () => { AppNavigator.push('pages/AiRoleLibrary'); } })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Scroll() {
        Row() {
          Column({ space: 12 }) {
            this.headerCard()
            this.newsGroup()
            this.gameGroup()
            this.systemGroup()
            Column().height(20)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
            top: Math.max(this.themeState.statusBarHeight, 44) + 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

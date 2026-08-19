// 智子 - 我的页（用户信息 + 设置入口 + 关于）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { DataRepository } from '../service/DataRepository';
import { CUSTOM_AVATAR_ID, avatarColors } from '../common/AvatarOptions';
import { AppConstants } from '../common/Constants';
import { PageKey, LegalDocRouteParams } from '../common/Navigation';

interface AboutRow {
  label: string;
  value: string;
  action: number; // 0=无动作，1=检查更新，2=用户协议，3=隐私政策，4=开源许可，5=反馈
}

@ComponentV2
export struct ProfilePage {
          @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onNavigate: (key: string) => void = () => {};

  private aboutRows: AboutRow[] = [
    { label: '版本', value: AppConstants.appVersion, action: 0 },
    { label: '检查更新', value: '', action: 1 },
    { label: '用户协议', value: '', action: 2 },
    { label: '隐私政策', value: '', action: 3 },
    { label: '开源许可', value: '', action: 4 },
    { label: '反馈', value: '', action: 5 }
  ];

  aboutToAppear(): void {
    this.loadAvatar();
  }

  private async loadAvatar(): Promise<void> {
    this.avatarId = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
  }

  private handleAboutRow(row: AboutRow): void {
    if (row.action === 1) {
      promptAction.showToast({ message: '已是最新版本' });
    } else if (row.action === 2) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('agreement'));
    } else if (row.action === 3) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('privacy'));
    } else if (row.action === 4) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('license'));
    } else if (row.action === 5) {
      promptAction.showToast({ message: '反馈功能即将上线' });
    } else if (row.value.length > 0) {
      promptAction.showToast({ message: `${row.label}：${row.value}` });
    }
  }

  @Builder
  headerCard() {
    Row({ space: 16 }) {
      // 头像
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
        Text(AppConstants.appName)
          .fontSize(this.themeState.palette.fsXl)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Row({ space: 6 }) {
          Text('AI 资讯 · 智能对话 · 休闲游戏')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(20)
    .borderRadius(16)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P1_CARD, this.themeState.palette) })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  groupRow(label: string, value: string, showChevron: boolean, onClick?: () => void) {
    Row() {
      Text(label)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .layoutWeight(1)
      if (value) {
        Text(value)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ right: 6 })
      }
      if (showChevron) {
        Text('›')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 13, bottom: 13 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
    .onClick(() => {
      if (onClick) {
        onClick();
      }
    })
  }

  @Builder
  commonGroup() {
    Column({ space: 10 }) {
      Text('通用')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: 8 }) {
        this.groupRow('设置', '', true, () => { this.onNavigate('Settings'); })
        this.groupRow('AI 模型', '', true, () => {
          AppNavigator.push('pages/AiModelPage');
        })
        this.groupRow('成就', '', true, () => {
          AppNavigator.push('pages/Achievements');
        })
        this.groupRow('对局回放', '', true, () => {
          AppNavigator.push('pages/ReplayList');
        })
        this.groupRow('排行榜', '', true, () => {
          AppNavigator.push('pages/Leaderboard');
        })
        this.groupRow('收藏 / 稍后读', '', true, () => {
          AppNavigator.push('pages/NewsFavorites');
        })
        this.groupRow('为你推荐', '', true, () => {
          AppNavigator.push('pages/NewsRecommend');
        })
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
  aboutGroup() {
    Column({ space: 10 }) {
      Text('关于')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Column({ space: 8 }) {
        ForEach(this.aboutRows, (row: AboutRow) => {
          this.groupRow(row.label, row.value, row.action !== 0, () => { this.handleAboutRow(row); })
        }, (row: AboutRow) => row.label)
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
      Text('我的')
        .fontSize(this.themeState.palette.fsXl)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
          top: this.themeState.statusBarHeight + 16, bottom: 16 })

      Scroll() {
        Column({ space: 16 }) {
          this.headerCard()

          this.commonGroup()

          this.aboutGroup()

          Column().height(20)
        }
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

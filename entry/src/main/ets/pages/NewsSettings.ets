// 智子 - 热榜设置（服务器 / 账号 / 关注管理 / 数据 / 关于）
// v10 设计：doc/v10-redesign.md §4.8 设置、§3.4.4 设置与数据的边界、§5.4 超大页拆分
// 本页是「热榜域配置与数据」的唯一主入口：服务器地址、NewsNow 账号、关注源、热榜数据清理、数据源致谢。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { NewsNowClient, DEFAULT_SERVER_URL, HotPingResult } from '../service/hot/NewsNowClient';
import { NewsNowAuth } from '../service/hot/NewsNowAuth';
import { NewsNowSync, HotSyncState } from '../service/hot/NewsNowSync';
import { HotFeedStore } from '../service/hot/HotFeedStore';
import { NewsRepository, HotStats } from '../service/hot/NewsRepository';
import { HotSources } from '../common/HotSources';
import { NewsNowUser } from '../common/HotModels';
import { HotSourceBadge } from '../components/HotSourceBadge';
import { HotSourcePicker } from '../components/HotSourcePicker';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

// 分区卡：白底 + radiusLg + 发丝边（内容卡无阴影，见 §2.2 阴影规则）
@ComponentV2
struct SectionCard {
  @Param title: string = '';
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder emptyContent() {}

  build() {
    Column({ space: this.themeState.palette.sp3 }) {
      Text(this.title)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Start)
      this.content()
    }
    .width('100%')
    .padding(this.themeState.palette.sp4)
    .borderRadius(this.themeState.palette.radiusLg)
    .backgroundColor(this.themeState.palette.bgSurface)
    .border({ width: 0.5, color: this.themeState.palette.divider })
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
@Entry
export struct NewsSettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 服务器
  @Local serverUrl: string = '';
  @Local editingServer: boolean = false;
  @Local urlDraft: string = '';
  @Local pingText: string = '';
  @Local pinging: boolean = false;
  // 账号
  @Local loggedIn: boolean = false;
  @Local user: NewsNowUser | null = null;
  @Local syncText: string = '';
  @Local syncing: boolean = false;
  // 关注
  @Local focusIds: string[] = [];
  @Local showPicker: boolean = false;
  // 数据统计
  @Local stats: HotStats = { favoriteCount: 0, readCount: 0, aiCallCount: 0 };

  async aboutToAppear(): Promise<void> {
    this.serverUrl = await NewsNowClient.getBaseUrl();
    this.urlDraft = this.serverUrl;
    await this.loadAccount();
    await this.loadFocus();
    await this.loadStats();
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg });
  }

  // 危险操作二次确认（取消/确认按钮取主题 token，不写死颜色）
  private confirmDanger(title: string, message: string, onOk: () => void): void {
    promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: this.themeState.palette.textSecondary },
        { text: '确认', color: this.themeState.palette.danger }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        onOk();
      }
    }).catch(() => {
    });
  }

  private async loadAccount(): Promise<void> {
    this.loggedIn = await NewsNowAuth.isLoggedIn();
    this.user = this.loggedIn ? await NewsNowAuth.getUser() : null;
    const state: HotSyncState = NewsNowSync.state();
    let text: string = state.lastError.length > 0 ? '同步异常：' + state.lastError :
      (state.lastSyncTime > 0 ? '上次同步：' + NewsSettingsPage.timeLabel(state.lastSyncTime) : '尚未同步');
    // 凭证临近过期时提示重新登录（设计 §6.1）
    if (this.loggedIn) {
      const token: string = await NewsNowAuth.getToken();
      if (token.length > 0 && NewsNowAuth.isExpiringSoon(token)) {
        text = text + ' · 登录凭证即将过期，建议重新登录';
      }
    }
    this.syncText = text;
  }

  private async loadFocus(): Promise<void> {
    this.focusIds = await NewsNowSync.focusIds();
  }

  private async loadStats(): Promise<void> {
    try {
      this.stats = await NewsRepository.stats();
    } catch (e) {
    }
  }

  private static timeLabel(ts: number): string {
    const d: Date = new Date(ts);
    const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
    return pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  // 同步状态行配色：异常 danger / 凭证将过期 warning / 常态 textTertiary
  private syncColor(): string {
    if (this.syncText.indexOf('异常') >= 0) return this.themeState.palette.danger;
    if (this.syncText.indexOf('即将过期') >= 0) return this.themeState.palette.warning;
    return this.themeState.palette.textTertiary;
  }

  // ==================== 服务器 ====================

  private async testConnection(): Promise<void> {
    if (this.pinging) return;
    this.pinging = true;
    this.pingText = '正在检测…';
    const res: HotPingResult = await NewsNowClient.ping();
    this.pinging = false;
    if (res.ok) {
      this.pingText = res.version.length > 0 ? '✓ 连接成功，服务版本 ' + res.version : '✓ 连接成功';
    } else {
      this.pingText = '✗ ' + (res.error === null ? '无法连接' : res.error.message);
    }
  }

  private pingOk(): boolean {
    return this.pingText.startsWith('✓');
  }

  private pingColor(): string {
    if (this.pinging) return this.themeState.palette.warning;
    return this.pingOk() ? this.themeState.palette.success : this.themeState.palette.danger;
  }

  private pingBg(): string {
    if (this.pinging) return this.themeState.palette.warningBg;
    return this.pingOk() ? this.themeState.palette.successBg : this.themeState.palette.dangerBg;
  }

  private async saveServer(): Promise<void> {
    const url: string = this.urlDraft.trim();
    if (!NewsNowClient.isValidUrl(url)) {
      this.toast('请输入完整地址（以 http:// 或 https:// 开头）');
      return;
    }
    await NewsNowClient.setBaseUrl(url);
    this.serverUrl = await NewsNowClient.getBaseUrl();
    this.editingServer = false;
    this.pingText = '';
    // 换服务器后内存榜单失效
    HotFeedStore.clearAll();
    await this.loadAccount();
    this.toast('服务器地址已保存');
  }

  private async restoreDefault(): Promise<void> {
    await NewsNowClient.setBaseUrl(DEFAULT_SERVER_URL);
    this.serverUrl = await NewsNowClient.getBaseUrl();
    this.urlDraft = this.serverUrl;
    this.editingServer = false;
    this.pingText = '';
    HotFeedStore.clearAll();
    await this.loadAccount();
    this.toast('已恢复默认服务器');
  }

  // ==================== 账号 ====================

  private openLogin(): void {
    AppNavigator.push('pages/NewsLogin');
  }

  private async syncNow(): Promise<void> {
    if (this.syncing) return;
    this.syncing = true;
    this.syncText = '同步中…';
    await NewsNowSync.syncNow();
    this.syncing = false;
    await this.loadAccount();
    await this.loadFocus();
    this.toast(this.syncText.indexOf('异常') >= 0 ? '同步失败' : '同步完成');
  }

  private logout(): void {
    this.confirmDanger('退出登录', '退出后关注列表仅保存在本机，不再与网页版同步。', () => {
      NewsNowAuth.clearSession().then(() => {
        this.loadAccount();
        this.toast('已退出登录');
      });
    });
  }

  // ==================== 关注 ====================

  private async toggleStar(sourceId: string): Promise<void> {
    const starred: boolean = await NewsNowSync.toggleStar(sourceId);
    await this.loadFocus();
    this.toast(starred ? '已关注' : '已取消关注');
  }

  private async moveFocus(index: number, delta: number): Promise<void> {
    const target: number = index + delta;
    if (target < 0 || target >= this.focusIds.length) return;
    const next: string[] = this.focusIds.slice();
    const tmp: string = next[index];
    next[index] = next[target];
    next[target] = tmp;
    await NewsNowSync.reorderFocus(next);
    await this.loadFocus();
  }

  // ==================== 交互构件（触控目标 ≥ 44vp）====================

  // 图标（矢量优先，回退 emoji）；固定 24vp 盒，保证行内对齐
  @Builder
  chipIcon(symbol: Resource, emoji: string, color: string) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(symbol)
          .fontSize(18)
          .fontColor([color])
          .accessibilityLevel('no')
      } else {
        Text(emoji)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(color)
      }
    }
    .width(24)
    .height(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  // 主操作：primary 实底胶囊
  @Builder
  primaryAction(label: string, symbol: Resource, emoji: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp2 }) {
      this.chipIcon(symbol, emoji, this.themeState.palette.primaryOnColor)
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
        .fontWeight(FontWeight.Medium)
    }
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.primary)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // 次操作：主色淡底胶囊
  @Builder
  tonalAction(label: string, symbol: Resource, emoji: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp2 }) {
      this.chipIcon(symbol, emoji, this.themeState.palette.primary)
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
    }
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.primaryBg)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // 中性操作：卡内次级底胶囊（文字色由调用方给 token，如 textSecondary / primary / danger）
  @Builder
  neutralAction(label: string, color: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(color)
    }
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.bgSurface2)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // 链接式操作：透明底、通栏左对齐（管理源等展开开关）
  @Builder
  linkAction(label: string, symbol: Resource, emoji: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp2 }) {
      this.chipIcon(symbol, emoji, this.themeState.palette.primary)
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
    }
    .width('100%')
    .height(this.themeState.palette.touchTarget)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // 危险操作：dangerBg 淡底通栏胶囊（组末 + 二次确认）
  @Builder
  dangerAction(label: string, onTap: () => void) {
    Row({ space: this.themeState.palette.sp2 }) {
      this.chipIcon(AppIcons.trash, AppIcons.trashEmoji, this.themeState.palette.danger)
      Text(label)
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.danger)
    }
    .width('100%')
    .height(this.themeState.palette.touchTarget)
    .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.dangerBg)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  // 文字箭头（上/下移，无对应矢量符号）
  @Builder
  glyphTap(glyph: string, label: string, onTap: () => void) {
    Row() {
      Text(glyph)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label)
    .onClick(onTap)
  }

  // 图标点击（取消关注/退出等）
  @Builder
  iconTap(symbol: Resource, emoji: string, color: string, label: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(symbol)
          .fontSize(18)
          .fontColor([color])
      } else {
        Text(emoji)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(color)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label)
    .onClick(onTap)
  }

  // ==================== 服务器区 ====================

  @Builder
  pingBanner() {
    Row({ space: this.themeState.palette.sp2 }) {
      if (!this.pinging) {
        this.chipIcon(this.pingOk() ? AppIcons.check : AppIcons.close,
          this.pingOk() ? AppIcons.checkEmoji : AppIcons.closeEmoji, this.pingColor())
      }
      Text(this.pingText)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.pingColor())
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({
      left: this.themeState.palette.sp3,
      right: this.themeState.palette.sp3,
      top: this.themeState.palette.sp2,
      bottom: this.themeState.palette.sp2
    })
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(this.pingBg())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  serverSection() {
    SectionCard({ title: '后端服务器' }) {
      Column({ space: this.themeState.palette.sp3 }) {
        Row({ space: this.themeState.palette.sp3 }) {
          this.chipIcon(AppIcons.server, AppIcons.serverEmoji, this.themeState.palette.textTertiary)
          Column({ space: 2 }) {
            Text('当前服务器')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text(this.serverUrl)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontMono)
              .fontColor(this.themeState.palette.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          this.neutralAction(this.editingServer ? '取消' : '编辑', this.themeState.palette.primary, () => {
            this.editingServer = !this.editingServer;
            this.urlDraft = this.serverUrl;
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.editingServer) {
          Column({ space: this.themeState.palette.sp2 }) {
            TextInput({ text: this.urlDraft, placeholder: 'https://your-newsnow.example.com' })
              .height(this.themeState.palette.touchTarget)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontMono)
              .fontColor(this.themeState.palette.textPrimary)
              .placeholderColor(this.themeState.palette.textTertiary)
              .backgroundColor(this.themeState.palette.bgSurface2)
              .borderRadius(this.themeState.palette.radiusSm)
              .onChange((value: string) => {
                this.urlDraft = value;
              })
            Row({ space: this.themeState.palette.sp2 }) {
              this.primaryAction('保存', AppIcons.check, AppIcons.checkEmoji, () => {
                this.saveServer();
              })
              this.neutralAction('恢复默认', this.themeState.palette.textSecondary, () => {
                this.restoreDefault();
              })
              Blank()
            }
            .width('100%')
          }
          .width('100%')
        }

        Row({ space: this.themeState.palette.sp3 }) {
          this.tonalAction(this.pinging ? '检测中…' : '测试连接', AppIcons.refresh, AppIcons.refreshEmoji,
            () => {
              this.testConnection();
            })
          if (this.pingText.length > 0) {
            this.pingBanner()
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('热榜数据来自 NewsNow 服务端，可自建实例后在此切换。默认使用公共实例。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
        Text('若公共实例提示 403（被 Cloudflare 拦截），多为站点侧的访问策略；可改用自部署实例，或在「账号」中先用 GitHub 登录一次后重试。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .width('100%')
    }
  }

  // ==================== 账号区 ====================

  @Builder
  accountSection() {
    SectionCard({ title: 'NewsNow 账号' }) {
      Column({ space: this.themeState.palette.sp3 }) {
        if (this.loggedIn && this.user !== null) {
          Row({ space: this.themeState.palette.sp3 }) {
            if (this.user.avatar.length > 0) {
              Image(this.user.avatar)
                .width(48)
                .height(48)
                .borderRadius(24)
                .objectFit(ImageFit.Cover)
                .border({ width: 0.5, color: this.themeState.palette.divider })
            } else {
              Row() {
                this.chipIcon(AppIcons.navProfile, AppIcons.navProfileEmoji, this.themeState.palette.textSecondary)
              }
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor(this.themeState.palette.bgSurface2)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
            }
            Column({ space: 2 }) {
              Text(this.user.name.length > 0 ? this.user.name : 'GitHub 用户')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .textAlign(TextAlign.Start)
              Text(this.syncText)
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.syncColor())
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: this.themeState.palette.sp2 }) {
            this.primaryAction(this.syncing ? '同步中…' : '立即同步', AppIcons.refresh, AppIcons.refreshEmoji,
              () => {
                this.syncNow();
              })
            this.neutralAction('退出登录', this.themeState.palette.danger, () => {
              this.logout();
            })
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        } else {
          Text('未登录')
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .textAlign(TextAlign.Start)
          Text('登录后可强制刷新实时数据，并把「关注」的源同步到 NewsNow 网页版（多端一致）。')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
          Row() {
            this.primaryAction('使用 GitHub 登录', AppIcons.navProfile, AppIcons.navProfileEmoji, () => {
              this.openLogin();
            })
            Blank()
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  // ==================== 关注区 ====================

  @Builder
  focusRow(sourceId: string, index: number) {
    Column({ space: 0 }) {
      Row({ space: this.themeState.palette.sp2 }) {
        HotSourceBadge({ sourceId: sourceId, badgeSize: 28 })
        Text(HotSources.nameOf(sourceId))
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 0 }) {
          this.glyphTap('▲', '上移', () => {
            this.moveFocus(index, -1);
          })
          this.glyphTap('▼', '下移', () => {
            this.moveFocus(index, 1);
          })
          this.iconTap(AppIcons.close, AppIcons.closeEmoji, this.themeState.palette.textTertiary, '取消关注', () => {
            this.toggleStar(sourceId);
          })
        }
      }
      .width('100%')
      .height(this.themeState.palette.rowHeight)
      .alignItems(VerticalAlign.Center)

      if (index < this.focusIds.length - 1) {
        Divider()
          .color(this.themeState.palette.divider)
          .strokeWidth(0.5)
          .margin({ left: this.themeState.palette.dividerIndent })
      }
    }
    .width('100%')
  }

  @Builder
  focusSection() {
    SectionCard({ title: '关注的源（' + this.focusIds.length.toString() + '）' }) {
      Column({ space: 0 }) {
        if (this.focusIds.length === 0) {
          Text('还没有关注任何源。点击下方「管理源」挑选，或在首页源卡片点 ⭐。')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ top: this.themeState.palette.sp1, bottom: this.themeState.palette.sp2 })
        } else {
          ForEach(this.focusIds, (sourceId: string, index: number) => {
            this.focusRow(sourceId, index)
          }, (sourceId: string) => sourceId)
        }

        this.linkAction(this.showPicker ? '收起源列表' : '管理源', AppIcons.list, AppIcons.listEmoji, () => {
          this.showPicker = !this.showPicker;
        })

        if (this.showPicker) {
          Divider()
            .color(this.themeState.palette.divider)
            .strokeWidth(0.5)
            .margin({ bottom: this.themeState.palette.sp3 })
          HotSourcePicker({
            focusIds: this.focusIds,
            onToggleStar: (id: string): void => {
              this.toggleStar(id);
            }
          })
        }
      }
      .width('100%')
    }
  }

  // ==================== 数据区 ====================

  @Builder
  statCell(label: string, value: number) {
    Column({ space: 2 }) {
      Text(value.toString())
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .layoutWeight(1)
    .padding({ top: this.themeState.palette.sp3, bottom: this.themeState.palette.sp3 })
    .borderRadius(this.themeState.palette.radiusSm)
    .backgroundColor(this.themeState.palette.bgSurface2)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  dataSection() {
    SectionCard({ title: '数据' }) {
      Column({ space: this.themeState.palette.sp3 }) {
        Row({ space: this.themeState.palette.sp2 }) {
          this.statCell('收藏', this.stats.favoriteCount)
          this.statCell('已读', this.stats.readCount)
          this.statCell('AI 调用', this.stats.aiCallCount)
        }
        .width('100%')

        this.dangerAction('清除已读记录', () => {
          this.confirmDanger('清除已读记录', '清除后所有条目的已读标记将被重置。', () => {
            NewsRepository.clearRead().then(() => {
              this.loadStats();
              this.toast('已清除已读记录');
            });
          });
        })
        this.dangerAction('清除正文缓存', () => {
          this.confirmDanger('清除正文缓存', '清除离线保存的正文与搜索索引。', () => {
            NewsRepository.clearArticleCache().then(() => {
              this.toast('已清除正文缓存');
            });
          });
        })
        this.dangerAction('清空收藏', () => {
          this.confirmDanger('清空收藏', '收藏列表将被清空，且无法恢复。', () => {
            NewsRepository.clearFavorites().then(() => {
              this.loadStats();
              this.toast('已清空收藏');
            });
          });
        })
      }
      .width('100%')
    }
  }

  // ==================== 关于数据源 ====================

  @Builder
  aboutSection() {
    SectionCard({ title: '关于数据源' }) {
      Column({ space: this.themeState.palette.sp2 }) {
        Text('热榜内容来自各站点公开榜单，经 NewsNow 服务端聚合。内容版权归原站点所有。')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
        Text('NewsNow 为 MIT 许可开源项目：github.com/newsnext/newsnow')
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      TopBar({ title: '热榜设置', showBack: true })

      Scroll() {
        Column({ space: this.themeState.palette.sectionGap }) {
          this.serverSection()
          this.accountSection()
          this.focusSection()
          this.dataSection()
          this.aboutSection()
        }
        .width('100%')
        .padding({
          left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp3,
          bottom: this.themeState.palette.sp6
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

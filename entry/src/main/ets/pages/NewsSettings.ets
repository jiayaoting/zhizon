// 智子 - 热榜设置（服务器 / 账号 / 关注管理 / 数据 / 关于）
// 设计文档：doc/newsnow-redesign.md §9.6
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { SettingGroupCard } from '../components/SettingGroupCard';
import { NewsNowClient, DEFAULT_SERVER_URL, HotPingResult } from '../service/NewsNowClient';
import { NewsNowAuth } from '../service/NewsNowAuth';
import { NewsNowSync, HotSyncState } from '../service/NewsNowSync';
import { HotFeedStore } from '../service/HotFeedStore';
import { NewsRepository, HotStats } from '../service/NewsRepository';
import { HotSources } from '../common/HotSources';
import { NewsNowUser } from '../common/HotModels';
import { HotSourceBadge } from '../components/HotSourceBadge';

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

  private confirmDanger(title: string, message: string, onOk: () => void): void {
    promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '确认', color: '#E84026' }
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

  @Builder
  serverSection() {
    SettingGroupCard({ title: '后端服务器' }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Column({ space: 3 }) {
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

          Text(this.editingServer ? '取消' : '编辑')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => {
              this.editingServer = !this.editingServer;
              this.urlDraft = this.serverUrl;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.editingServer) {
          Column({ space: 8 }) {
            TextInput({ text: this.urlDraft, placeholder: 'https://your-newsnow.example.com' })
              .height(40)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontMono)
              .backgroundColor(this.themeState.palette.bgSurface2)
              .borderRadius(10)
              .onChange((value: string) => {
                this.urlDraft = value;
              })
            Row({ space: 8 }) {
              Text('保存')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(Color.White)
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor(this.themeState.palette.primary)
                .onClick(() => {
                  this.saveServer();
                })
              Text('恢复默认')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textSecondary)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor(this.themeState.palette.bgSurface2)
                .onClick(() => {
                  this.restoreDefault();
                })
              Blank()
            }
            .width('100%')
          }
          .width('100%')
        }

        Row({ space: 10 }) {
          Text(this.pinging ? '检测中…' : '测试连接')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.themeState.palette.primary + '1A')
            .onClick(() => {
              this.testConnection();
            })
          if (this.pingText.length > 0) {
            Text(this.pingText)
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.pingText.startsWith('✓') ? this.themeState.palette.success :
                this.themeState.palette.danger)
              .layoutWeight(1)
              .maxLines(2)
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

  @Builder
  accountSection() {
    SettingGroupCard({ title: 'NewsNow 账号' }) {
      Column({ space: 10 }) {
        if (this.loggedIn && this.user !== null) {
          Row({ space: 10 }) {
            if (this.user.avatar.length > 0) {
              Image(this.user.avatar)
                .width(40)
                .height(40)
                .borderRadius(20)
                .objectFit(ImageFit.Cover)
                .border({ width: 1.5, color: '#80FFFFFF' })
            } else {
              Text('👤')
                .fontSize(30)
            }
            Column({ space: 3 }) {
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
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 10 }) {
            Text(this.syncing ? '同步中…' : '立即同步')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(Color.White)
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor(this.themeState.palette.primary)
              .onClick(() => {
                this.syncNow();
              })
            Text('退出登录')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.danger)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor(this.themeState.palette.bgSurface2)
              .onClick(() => {
                this.logout();
              })
            Blank()
          }
          .width('100%')
        } else {
          Text('未登录')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .width('100%')
            .textAlign(TextAlign.Start)
          Text('登录后可强制刷新实时数据，并把「关注」的源同步到 NewsNow 网页版（多端一致）。')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
          Text('使用 GitHub 登录')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor(this.themeState.palette.primary)
            .onClick(() => {
              this.openLogin();
            })
        }
      }
      .width('100%')
    }
  }

  @Builder
  focusSection() {
    SettingGroupCard({ title: '关注的源（' + this.focusIds.length.toString() + '）' }) {
      Column({ space: 8 }) {
        if (this.focusIds.length === 0) {
          Text('还没有关注任何源。点击下方「管理源」挑选，或在首页源卡片点 ⭐。')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
        } else {
          ForEach(this.focusIds, (sourceId: string, index: number) => {
            Row({ space: 10 }) {
              HotSourceBadge({ sourceId: sourceId, badgeSize: 26 })
              Text(HotSources.nameOf(sourceId))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('▲')
                .fontSize(this.themeState.palette.fsXs)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(6)
                .onClick(() => {
                  this.moveFocus(index, -1);
                })
              Text('▼')
                .fontSize(this.themeState.palette.fsXs)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(6)
                .onClick(() => {
                  this.moveFocus(index, 1);
                })
              Text('✕')
                .fontSize(this.themeState.palette.fsSm)
                .fontColor(this.themeState.palette.textTertiary)
                .padding(6)
                .onClick(() => {
                  this.toggleStar(sourceId);
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (sourceId: string) => sourceId)
        }

        Text(this.showPicker ? '收起源列表' : '管理源')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .padding({ top: 6, bottom: 2 })
          .onClick(() => {
            this.showPicker = !this.showPicker;
          })

        if (this.showPicker) {
          this.pickerList()
        }
      }
      .width('100%')
    }
  }

  @Builder
  pickerList() {
    Column({ space: 12 }) {
      ForEach(['china', 'tech', 'finance', 'world', 'sports'], (column: string) => {
        Column({ space: 6 }) {
          Text(HotSources.groupLabel(column))
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
          ForEach(HotSources.byColumn(column), (sourceId: string) => {
            Row({ space: 10 }) {
              HotSourceBadge({ sourceId: sourceId, badgeSize: 24 })
              Text(HotSources.nameOf(sourceId))
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textSecondary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.focusIds.indexOf(sourceId) >= 0 ? '⭐' : '☆')
                .fontSize(this.themeState.palette.fsMd)
                .padding(4)
                .onClick(() => {
                  this.toggleStar(sourceId);
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (sourceId: string) => sourceId)
        }
        .width('100%')
      }, (column: string) => column)
    }
    .width('100%')
  }

  @Builder
  dataSection() {
    SettingGroupCard({ title: '数据' }) {
      Column({ space: 10 }) {
        Row({ space: 16 }) {
          this.statCell('收藏', this.stats.favoriteCount)
          this.statCell('已读', this.stats.readCount)
          this.statCell('AI 调用', this.stats.aiCallCount)
        }
        .width('100%')

        Row({ space: 10 }) {
          this.dangerChip('清除已读记录', () => {
            this.confirmDanger('清除已读记录', '清除后所有条目的已读标记将被重置。', () => {
              NewsRepository.clearRead().then(() => {
                this.loadStats();
                this.toast('已清除已读记录');
              });
            });
          })
          this.dangerChip('清除正文缓存', () => {
            this.confirmDanger('清除正文缓存', '清除离线保存的正文与搜索索引。', () => {
              NewsRepository.clearArticleCache().then(() => {
                this.toast('已清除正文缓存');
              });
            });
          })
        }
        .width('100%')

        this.dangerChip('清空收藏', () => {
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

  @Builder
  statCell(label: string, value: number) {
    Column({ space: 4 }) {
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
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  dangerChip(label: string, onTap: () => void) {
    Text(label)
      .fontSize(this.themeState.palette.fsSm)
      .fontFamily(this.themeState.palette.fontSans)
      .fontColor(this.themeState.palette.danger)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(this.themeState.palette.danger + '14')
      .onClick(onTap)
  }

  @Builder
  aboutSection() {
    SettingGroupCard({ title: '关于数据源' }) {
      Column({ space: 6 }) {
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
        Column({ space: 12 }) {
          this.serverSection()
          this.accountSection()
          this.focusSection()
          this.dataSection()
          this.aboutSection()
        }
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24,
          top: 8, bottom: 24 })
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

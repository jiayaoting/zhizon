// 智子 - NewsNow 账号登录页（ArkWeb 内嵌 GitHub OAuth）
// 设计文档：doc/newsnow-redesign.md §6.1
// 流程：加载 {base}/api/login → GitHub 授权 → 回跳 {base}/?login=github&jwt=...&user=...
//       拦截该回跳 URL，解析 jwt/user 落盘，关闭页面
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { NewsNowAuth, HotLoginCallback } from '../service/hot/NewsNowAuth';
import { NewsNowClient, NEWSNOW_UA } from '../service/hot/NewsNowClient';
import { NewsNowSync } from '../service/hot/NewsNowSync';
import { HotFeedStore } from '../service/hot/HotFeedStore';

@Entry
@ComponentV2
export struct NewsLoginPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local handled: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private loginUrl: string = '';
  private baseUrl: string = '';

  async aboutToAppear(): Promise<void> {
    this.baseUrl = await NewsNowClient.getBaseUrl();
    this.loginUrl = this.baseUrl + '/api/login';
  }

  // 是否命中登录成功回跳
  private tryHandleCallback(url: string): boolean {
    if (this.handled) return false;
    const cb: HotLoginCallback = NewsNowAuth.parseCallback(url);
    if (!cb.matched || cb.jwt.length === 0) return false;
    this.handled = true;
    this.finishLogin(cb);
    return true;
  }

  private async finishLogin(cb: HotLoginCallback): Promise<void> {
    const ok: boolean = await NewsNowAuth.saveSession(cb.jwt, cb.user);
    if (!ok) {
      this.errorMsg = '凭证保存失败，请重试';
      this.handled = false;
      return;
    }
    // 登录后拉取云端关注列表（新者胜）
    await NewsNowSync.onLogin();
    HotFeedStore.clearAll();
    promptAction.showToast({ message: '登录成功' });
    AppNavigator.pop();
  }

  @Builder
  topBar() {
    Row({ space: 10 }) {
      Text('‹')
        .fontSize(26)
        .fontColor(this.themeState.palette.textPrimary)
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          AppNavigator.pop();
        })
      Text('GitHub 登录')
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text('重新加载')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primary)
        .padding(6)
        .onClick(() => {
          this.errorMsg = '';
          this.handled = false;
          this.loading = true;
          this.controller.loadUrl(this.loginUrl);
        })
    }
    .width('100%')
    .padding({ left: this.themeState.isSm ? 12 : 20, right: this.themeState.isSm ? 12 : 20,
      top: Math.max(this.themeState.statusBarHeight, 44) + 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.topBar()

      if (this.errorMsg.length > 0) {
        Row({ space: 8 }) {
          Text('⚠️')
            .fontSize(this.themeState.palette.fsSm)
          Text(this.errorMsg)
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
      }

      Stack() {
        Web({ src: this.loginUrl, controller: this.controller })
          .width('100%')
          .height('100%')
          .userAgent(NEWSNOW_UA)
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .onPageBegin((event) => {
            this.loading = false;
          })
          .onErrorReceive((event) => {
            this.loading = false;
            if (event !== undefined && event.error !== undefined) {
              this.errorMsg = '页面加载失败：' + event.error.getErrorInfo();
            }
          })
          // 拦截登录成功回跳（URL 携带 jwt），阻止页面继续加载
          .onLoadIntercept((event) => {
            if (event !== undefined && event.data !== undefined) {
              const url: string = event.data.getRequestUrl();
              if (this.tryHandleCallback(url)) {
                return true;
              }
              // 阻止回跳到网页首页（已完成解析的场景已在上面处理）
              if (this.handled && url.indexOf(this.baseUrl) === 0 && url.indexOf('jwt=') < 0) {
                return true;
              }
            }
            return false;
          })

        if (this.loading) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(32)
              .height(32)
            Text('正在打开 GitHub 授权页…')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.themeState.palette.bgBase)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

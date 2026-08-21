import { BackgroundDisplayState, ThemeManager } from '../common/Theme';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { FxBudget } from './GlassEffect';

@ComponentV2
export struct GlobalBackgroundLayer {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  private displayUri(): string {
    if (this.themeState.backgroundDisplayState === BackgroundDisplayState.LOADING && this.themeState.backgroundCandidateUri.length > 0) {
      return this.themeState.backgroundCandidateUri;
    }
    if (this.themeState.backgroundDisplayState === BackgroundDisplayState.INVALID) return '';
    return this.themeState.globalBackgroundUri;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeState.palette.bgBase)
      if (this.displayUri().length > 0 && this.themeState.backgroundVisibleStrength > 0) {
        Image(this.displayUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.themeState.backgroundVisibleStrength / 100)
          .onComplete(() => {
            ThemeManager.getInstance().reportBackgroundReady(this.displayUri());
          })
          .onError(() => {
            ThemeManager.getInstance().reportBackgroundLoadFailure(this.displayUri());
          })
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeState.palette.isDark ? 'rgba(10, 14, 26, 0.45)' : 'rgba(245, 246, 250, 0.45)')
      if (this.themeState.liquidGlassEnabled) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeState.palette.isDark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.20)')
          .border({ width: 1, color: this.themeState.palette.isDark ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.60)' })
          .backdropBlur(FxBudget.isLowBattery() ? 0 : 12)
      }
    }
    .width('100%')
    .height('100%')
  }
}

import { BackgroundDisplayState, ThemeManager, ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct GlobalBackgroundLayer {
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('globalBackgroundUri') globalUri: string = '';
  @StorageLink('backgroundCandidateUri') candidateUri: string = '';
  @StorageLink('backgroundVisibleStrength') visibleStrength: number = 50;
  @StorageLink('backgroundDisplayState') displayState: BackgroundDisplayState = BackgroundDisplayState.READY;

  private displayUri(): string {
    if (this.displayState === BackgroundDisplayState.LOADING && this.candidateUri.length > 0) {
      return this.candidateUri;
    }
    if (this.displayState === BackgroundDisplayState.INVALID) return '';
    return this.globalUri;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette.bgBase)
      if (this.displayUri().length > 0 && this.visibleStrength > 0) {
        Image(this.displayUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.visibleStrength / 100)
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
        .backgroundColor(this.palette.isDark ? 'rgba(10, 14, 26, 0.72)' : 'rgba(245, 246, 250, 0.72)')
    }
    .width('100%')
    .height('100%')
  }
}

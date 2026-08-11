// 智子 - 设置页面（沉浸光感重构版）
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette, ColorThemeId, colorThemeName, colorThemeColor,
  ThemeManager, ThemeMode, PreferenceMutationResult, PreferenceFailureReason } from '../common/Theme';
import { BackgroundDisplayState } from '../common/Theme';
import { DataRepository } from '../service/DataRepository';
import { PickerAdapter, ImagePickResult, ImagePickState } from '../service/PickerAdapter';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { LegalDocRouteParams } from '../common/Navigation';

import { TopBar } from '../components/TopBar';

// 字号选项
interface FontSizeOption {
  label: string;
  value: string;
  preview: number;
}

// 字体选项（全部为免费商用授权）
interface FontFamilyOption {
  name: string;
  family: string;
  category: string;
}

// 分组卡片组件
@Component
struct GroupCard {
  @Prop title: string;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(this.palette.fsMd)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontSans)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct SettingsPage {
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDarkMode: boolean = true;
  @StorageLink('followSystemDark') followSystemDark: boolean = true;
  @StorageLink('colorThemeId') colorThemeId: string = 'cyan';
  @StorageLink('backgroundDisplayState') backgroundDisplayState: BackgroundDisplayState = BackgroundDisplayState.INVALID;

  // 外观
  @State fontSizeScale: string = 'standard';
  @State fontFamily: string = 'HarmonyOS Sans';
  @State showFontSizeSheet: boolean = false;
  @State showFontFamilySheet: boolean = false;
  // 安全
  @State biometricUnlock: boolean = false;
  @State autoLock: string = '5 分钟';
  // 数据
  @State autoBackup: boolean = false;

  // 字号/字体选项
  private fontSizeOptions: FontSizeOption[] = [
    { label: '小', value: 'small', preview: 11 },
    { label: '标准', value: 'standard', preview: 14 },
    { label: '大', value: 'large', preview: 18 }
  ];
  private fontFamilyOptions: FontFamilyOption[] = [
    { name: 'HarmonyOS Sans', family: 'HarmonyOS Sans', category: '系统' },
    { name: 'Inter', family: 'Inter', category: '无衬线' },
    { name: 'JetBrains Mono', family: 'JetBrains Mono', category: '等宽' },
    { name: 'Fira Code', family: 'Fira Code', category: '等宽' }
  ];

  // 主题颜色选项
  private themeColors: ColorThemeId[] = [
    ColorThemeId.CYAN, ColorThemeId.OCEAN, ColorThemeId.SUNSET,
    ColorThemeId.AURORA, ColorThemeId.SAKURA, ColorThemeId.FOREST
  ];

  // 背景图设置
  @State showBgSettings: boolean = false;
  @State globalBgUri: string = '';
  @State backgroundStrength: number = 50;

  async aboutToAppear(): Promise<void> {
    this.loading = true;
    try {
      const biometricUnlockVal = await DataRepository.getSetting('biometricUnlock', 'false');
      this.biometricUnlock = biometricUnlockVal === 'true';
      const autoBackupVal = await DataRepository.getSetting('autoBackup', 'false');
      this.autoBackup = autoBackupVal === 'true';

      this.fontSizeScale = await DataRepository.getSetting('fontSizeScale', 'standard');
      this.fontFamily = await DataRepository.getSetting('fontFamily', 'HarmonyOS Sans');
      if (!this.isSupportedFont(this.fontFamily)) {
        this.fontFamily = 'HarmonyOS Sans';
      }
      this.autoLock = await DataRepository.getSetting('autoLock', '5 分钟');

      // 加载背景图配置
      const background = ThemeManager.getInstance().getGlobalBackground();
      this.globalBgUri = background.globalUri;
      this.backgroundStrength = background.visibleStrength;
    } finally {
      this.loading = false;
    }
  }

  aboutToDisappear(): void {
    // 设置项通过 DataRepository 持久化，无内存态资源需要释放
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 打开系统文件选择器选取背景图
  private async pickBackgroundImage(): Promise<void> {
    const picked: ImagePickResult = await PickerAdapter.pickSingleImage();
    if (picked.state === ImagePickState.CANCELLED) return;
    if (picked.state === ImagePickState.FAILED) {
      this.toast('选择背景图失败');
      return;
    }
    const manager = ThemeManager.getInstance();
    manager.beginBackgroundCandidate(picked.uri);
    const mutation: PreferenceMutationResult = await manager.importBackgroundCandidate(picked.uri);
    this.applyPreferenceResult(mutation);
    if (mutation.success) {
      this.toast('背景图已设置');
    } else if (mutation.reason === PreferenceFailureReason.PERSISTENCE_FAILED) {
      this.toast('设置未保存，请重试');
    } else {
      this.toast('无法读取所选图片，请重新选择');
    }
  }

  private async updateFollowSystem(follow: boolean): Promise<void> {
    this.followSystemDark = follow;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setFollowSystem(follow);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(follow ? '已开启跟随系统深色模式' : '已切换为手动模式');
    } else {
      this.followSystemDark = !follow;
      this.toast('设置未保存，请重试');
    }
  }

  private async updateManualMode(isDark: boolean): Promise<void> {
    this.isDarkMode = isDark;
    const mode = isDark ? ThemeMode.DARK : ThemeMode.LIGHT;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setManualMode(mode);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(isDark ? '已切换为深色模式' : '已切换为浅色模式');
    } else {
      this.isDarkMode = !isDark;
      this.toast('设置未保存，请重试');
    }
  }

  private async clearBackground(): Promise<void> {
    const result: PreferenceMutationResult = await ThemeManager.getInstance().clearGlobalBackground();
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast('背景图已清除');
    } else {
      this.toast('设置未保存，请重试');
    }
  }

  private async saveBackgroundStrength(value: number): Promise<void> {
    const strength = Math.round(value);
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setBackgroundStrength(strength);
    this.applyPreferenceResult(result);
    if (!result.success) {
      this.toast('设置未保存，请重试');
    }
  }

  private async updateGlassEffect(enabled: boolean): Promise<void> {
    this.glassEnabled = enabled;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setGlassEffect(enabled);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(enabled ? '已开启毛玻璃效果' : '已关闭毛玻璃效果');
    } else {
      this.glassEnabled = !enabled;
      this.toast('设置未保存，请重试');
    }
  }

  private async updateColorTheme(themeId: ColorThemeId): Promise<void> {
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setColorTheme(themeId);
    this.applyPreferenceResult(result);
    if (!result.success) this.toast('设置未保存，请重试');
  }

  private applyPreferenceResult(result: PreferenceMutationResult): void {
    if (result.published || result.restored) {
      this.globalBgUri = result.snapshot.backgroundUri;
      this.backgroundStrength = result.snapshot.backgroundStrength;
      this.followSystemDark = result.snapshot.followSystem;
      this.colorThemeId = result.snapshot.colorThemeId;
      this.isDarkMode = result.snapshot.followSystem ? this.isDarkMode :
        result.snapshot.manualThemeMode === ThemeMode.DARK;
      this.fontSizeScale = result.snapshot.fontSizeScale;
    }
  }

  private fontSizeLabel(scale: string): string {
    if (scale === 'small') return '小';
    if (scale === 'large') return '大';
    return '标准';
  }

  // 校验字体是否为应用支持（避免旧版本保存的字体残留）
  private isSupportedFont(family: string): boolean {
    for (let i: number = 0; i < this.fontFamilyOptions.length; i++) {
      if (this.fontFamilyOptions[i].family === family) return true;
    }
    return false;
  }

  private async applyFontSize(scale: string): Promise<void> {
    if (scale === this.fontSizeScale) return;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setFontSize(scale);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(`字号：${this.fontSizeLabel(scale)}`);
    } else {
      this.toast('设置未保存，请重试');
    }
  }

  private openFontSizePicker(): void {
    this.showFontSizeSheet = true;
  }

  private pickFontSize(value: string): void {
    this.showFontSizeSheet = false;
    this.applyFontSize(value);
  }

  private async applyFontFamily(family: string): Promise<void> {
    if (family === this.fontFamily) return;
    this.fontFamily = family;
    await ThemeManager.getInstance().setFontFamily(family);
    this.toast(`字体：${family}`);
  }

  private openFontFamilyPicker(): void {
    this.showFontFamilySheet = true;
  }

  private pickFontFamily(family: string): void {
    this.showFontFamilySheet = false;
    this.applyFontFamily(family);
  }

  private confirmClearBackground(): void {
    AlertDialog.show({
      title: '清除背景图',
      message: '确定要清除当前背景图吗？此操作不可恢复。',
      confirm: {
        value: '清除',
        action: () => { this.clearBackground(); }
      }
    });
  }

  private openLegalDoc(type: string): void {
    router.pushUrl({
      url: 'pages/LegalDoc',
      params: new LegalDocRouteParams(type)
    });
  }

  @Builder valueRow(label: string, value: string, onClick?: () => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontSans)
        .layoutWeight(1)
      if (value) {
        Text(value)
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
          .margin({ right: 6 })
      }
      Text('›')
        .fontSize(14)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
    .onClick(() => {
      if (onClick) {
        onClick();
      } else {
        this.toast(value ? `${label}：${value}` : label);
      }
    })
  }

  @Builder toggleRow(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontSans)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.palette.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(6)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
  }

  // 颜色主题选择器
  @Builder colorThemeSelector() {
    Row({ space: 10 }) {
      ForEach(this.themeColors, (themeId: ColorThemeId) => {
        Column() {
          Stack() {
            Circle({ width: 36, height: 36 })
              .fill(colorThemeColor(themeId))
            if (this.colorThemeId === themeId) {
              Text('✓')
                .fontSize(14)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          Text(colorThemeName(themeId))
            .fontSize(9)
            .fontColor(this.palette.textTertiary)
            .margin({ top: 4 })
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Center)
        .onClick(async () => {
          await this.updateColorTheme(themeId);
        })
      }, (themeId: ColorThemeId) => themeId)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
  }

  // 深色模式设置
  @Builder darkModeSettings() {
    Column({ space: 8 }) {
      Row() {
        Text('跟随系统深色模式')
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.followSystemDark })
          .selectedColor(this.palette.primary)
          .onChange((v: boolean) => {
            this.updateFollowSystem(v);
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 11, bottom: 11 })
      .borderRadius(6)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))

      if (!this.followSystemDark) {
        Row() {
          Text('深色模式')
            .fontSize(13)
            .fontColor(this.palette.textPrimary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
            .selectedColor(this.palette.primary)
            .onChange((v: boolean) => {
              this.updateManualMode(v);
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 11, bottom: 11 })
        .borderRadius(6)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
      }
    }
    .width('100%')
  }

  // 背景图设置
  @Builder backgroundSettings() {
    Column({ space: 8 }) {
      Row() {
        Text('全局背景图')
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        if (this.backgroundDisplayState === BackgroundDisplayState.LOADING) {
          Text('正在应用')
            .fontSize(12)
            .fontColor(this.palette.primary)
        } else if (this.backgroundDisplayState === BackgroundDisplayState.INVALID && this.globalBgUri) {
          Text('背景失效，请重新选择')
            .fontSize(12)
            .fontColor(this.palette.warning)
        } else if (this.globalBgUri) {
          Text('已设置')
            .fontSize(12)
            .fontColor(this.palette.success)
        } else {
          Text('未设置')
            .fontSize(12)
            .fontColor(this.palette.textTertiary)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 11, bottom: 11 })
      .borderRadius(6)
      .backgroundColor(this.palette.bgSurface2)
      .onClick(() => {
        this.pickBackgroundImage();
      })

      if (this.globalBgUri) {
        Row() {
          Text('清除背景图')
            .fontSize(13)
            .fontColor(this.palette.danger)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 11, bottom: 11 })
        .borderRadius(6)
        .backgroundColor(this.palette.bgSurface2)
        .onClick(() => {
          this.confirmClearBackground();
        })
      }

      Row() {
        Text('可见强度')
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        Text(`${this.backgroundStrength}%`)
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
      Slider({ value: this.backgroundStrength, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.palette.primary)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.backgroundStrength = Math.round(value);
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.saveBackgroundStrength(this.backgroundStrength);
          }
        })
    }
    .width('100%')
  }

  // 字号选择弹层
  @Builder
  fontSizeSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showFontSizeSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('字号')
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字号大小')
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textTertiary)
          .margin({ bottom: 8 })

        ForEach(this.fontSizeOptions, (option: FontSizeOption) => {
          Row({ space: 12 }) {
            Text('Aa 智子 123')
              .fontSize(option.preview)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.fontSizeScale === option.value ? this.palette.primary : this.palette.textPrimary)
            Blank()
            Text(option.label)
              .fontSize(this.palette.fsSm)
              .fontColor(this.fontSizeScale === option.value ? this.palette.primary : this.palette.textSecondary)
            if (this.fontSizeScale === option.value) {
              Text('✓')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette.primary)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          .borderRadius(10)
          .backgroundColor(this.fontSizeScale === option.value ?
            this.palette.primaryDim : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
          .onClick(() => { this.pickFontSize(option.value); })
        }, (option: FontSizeOption) => option.value)

        Text('取消')
          .fontSize(this.palette.fsBase)
          .fontColor(this.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showFontSizeSheet = false; })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.25)', offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  // 字体选择弹层
  @Builder
  fontFamilySheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showFontFamilySheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('字体')
          .fontSize(this.palette.fsLg)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字体')
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textTertiary)
          .margin({ bottom: 8 })

        ForEach(this.fontFamilyOptions, (option: FontFamilyOption) => {
          Row({ space: 12 }) {
            Column({ space: 3 }) {
              Text(option.name)
                .fontSize(this.palette.fsSm)
                .fontFamily(option.family)
                .fontColor(this.fontFamily === option.family ? this.palette.primary : this.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Text('Aa 智子 123 — ' + option.category)
                .fontSize(11)
                .fontFamily(option.family)
                .fontColor(this.fontFamily === option.family ? this.palette.primary : this.palette.textTertiary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            if (this.fontFamily === option.family) {
              Text('✓')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette.primary)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          .borderRadius(10)
          .backgroundColor(this.fontFamily === option.family ?
            this.palette.primaryDim : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
          .onClick(() => { this.pickFontFamily(option.family); })
        }, (option: FontFamilyOption) => option.family)

        Text('取消')
          .fontSize(this.palette.fsBase)
          .fontColor(this.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showFontFamilySheet = false; })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.25)', offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  @Builder actionsBuilder() {}

  build() {
    Stack() {
      Column() {
        TopBar({ title: '设置', subtitle: '智子 v1.0.0' }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            // 外观（新设计）
            GroupCard({ title: '外观' }) {
              Column({ space: 12 }) {
                // 颜色主题选择器
                Text('颜色主题')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.colorThemeSelector()

                // 深色模式
                Text('深色模式')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.darkModeSettings()

                // 背景图
                Text('背景图')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.backgroundSettings()

                // 毛玻璃效果
                Text('毛玻璃效果')
                  .fontSize(13)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .margin({ top: 4 })
                Row() {
                  Text('启用毛玻璃效果')
                    .fontSize(13)
                    .fontColor(this.palette.textPrimary)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.glassEnabled })
                    .selectedColor(this.palette.primary)
                    .onChange((v: boolean) => {
                      this.updateGlassEffect(v);
                    })
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                .borderRadius(6)
                .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
                Text('开启后顶栏、底栏、卡片将呈现透明磨砂质感，建议搭配背景图使用。')
                  .fontSize(10)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })

                this.valueRow('字号', this.fontSizeLabel(this.fontSizeScale), () => {
                  this.openFontSizePicker();
                })
                this.valueRow('字体', this.fontFamily, () => {
                  this.openFontFamilyPicker();
                })
              }
              .width('100%')
            }

            // 安全
            GroupCard({ title: '安全' }) {
              Column({ space: 8 }) {
                this.valueRow('主密码', '已设置')
                this.toggleRow('生物识别解锁', this.biometricUnlock, (v: boolean) => {
                  this.biometricUnlock = v;
                  DataRepository.setSetting('biometricUnlock', v ? 'true' : 'false');
                  this.toast(`生物识别解锁：${v ? '已开启' : '已关闭'}`);
                })
                this.valueRow('自动锁定', this.autoLock)
              }
              .width('100%')
            }

            // 数据
            GroupCard({ title: '数据' }) {
              Column({ space: 8 }) {
                this.valueRow('导出配置', '')
                this.valueRow('导入配置', '')
                this.valueRow('清除缓存', '')
                this.toggleRow('自动备份', this.autoBackup, (v: boolean) => {
                  this.autoBackup = v;
                  DataRepository.setSetting('autoBackup', v ? 'true' : 'false');
                  this.toast(`自动备份：${v ? '已开启' : '已关闭'}`);
                })
              }
              .width('100%')
            }

            // 关于
            GroupCard({ title: '关于' }) {
              Column({ space: 8 }) {
                this.valueRow('版本', '1.0.0')
                this.valueRow('检查更新', '')
                this.valueRow('用户协议', '', () => { this.openLegalDoc('agreement'); })
                this.valueRow('隐私政策', '', () => { this.openLegalDoc('privacy'); })
                this.valueRow('开源许可', '', () => { this.openLegalDoc('license'); })
                this.valueRow('反馈', '')
              }
              .width('100%')
            }
          }
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 0, bottom: 80 })
        .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      // 字号/字体选择弹层
      if (this.showFontSizeSheet) {
        this.fontSizeSheet()
      }
      if (this.showFontFamilySheet) {
        this.fontFamilySheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}

// 智子 - 外观设置（二级页：深色模式 / 背景图 / 玻璃效果 / 字号 / 字体 / 应用图标 / 头像）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import {
  ThemeManager, ThemeMode, PreferenceMutationResult, PreferenceFailureReason,
  BackgroundDisplayState } from '../common/Theme';
import { ThemeState } from '../common/ThemeState';
import { DataRepository } from '../service/platform/DataRepository';
import { BackgroundImporter, BackgroundImportResult } from '../service/platform/BackgroundImporter';
import { PickerAdapter, ImagePickResult, ImagePickState } from '../service/platform/PickerAdapter';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { AvatarOption, AVATAR_OPTIONS, CUSTOM_AVATAR_ID, avatarLabel } from '../common/AvatarOptions';
import { TopBar } from '../components/TopBar';
import { SettingGroupCard } from '../components/SettingGroupCard';
import { SettingRow } from '../components/SettingRow';

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

// 应用图标选项
interface AppIconOption {
  id: string;          // 持久化用的标识
  label: string;       // 显示名称
  style: string;       // 风格描述
  resource: Resource;  // media 资源（字面量 $r，不用动态 $r()）
}

// 应用图标资源：字面量 $r，由编译器校验资源名（替换原先运行时拼接的动态 $r）
const APP_ICON_CLASSIC: Resource = $r('app.media.app_icon_classic');
const APP_ICON_BRIGHT_GRADIENT: Resource = $r('app.media.app_icon_bright_gradient');
const APP_ICON_GLASS: Resource = $r('app.media.app_icon_glass');
const APP_ICON_FLAT: Resource = $r('app.media.app_icon_flat');
const APP_ICON_3D_CARTOON: Resource = $r('app.media.app_icon_3d_cartoon');
const APP_ICON_LIQUID: Resource = $r('app.media.app_icon_liquid');

@ComponentV2
@Entry
export struct AppearanceSettingsPage {
  // 全局 UI 状态统一走 AppStorageV2（P4 · §5.1 状态管理统一）
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  // 外观
  @Local fontSizeScale: string = 'standard';
  @Local fontFamily: string = 'HarmonyOS Sans';
  @Local showFontSizeSheet: boolean = false;
  @Local showFontFamilySheet: boolean = false;
  @Local showAppIconSheet: boolean = false;
  @Local showAvatarSheet: boolean = false;
  @Local appIconId: string = 'liquid';
  @Local avatarId: string = 'liquid';
  @Local avatarUri: string = '';

  // 背景图设置
  @Local globalBgUri: string = '';
  @Local backgroundStrength: number = 50;

  // 字号/字体选项
  private fontSizeOptions: FontSizeOption[] = [
    { label: '超小', value: 'xsmall', preview: 9 },
    { label: '小', value: 'small', preview: 11 },
    { label: '标准', value: 'standard', preview: 16 },
    { label: '大', value: 'large', preview: 20 },
    { label: '特大', value: 'xlarge', preview: 24 }
  ];
  private fontFamilyOptions: FontFamilyOption[] = [
    { name: 'HarmonyOS Sans', family: 'HarmonyOS Sans', category: '系统' },
    { name: 'Inter', family: 'Inter', category: '无衬线' },
    { name: 'JetBrains Mono', family: 'JetBrains Mono', category: '等宽' },
    { name: 'Fira Code', family: 'Fira Code', category: '等宽' },
    { name: 'Lobster', family: 'Lobster', category: '艺术' },
    { name: 'Pacifico', family: 'Pacifico', category: '艺术' },
    { name: 'Bebas Neue', family: 'Bebas Neue', category: '艺术' },
    { name: 'Righteous', family: 'Righteous', category: '艺术' },
    { name: 'Press Start 2P', family: 'Press Start 2P', category: '艺术' },
    { name: 'Orbitron', family: 'Orbitron', category: '艺术' },
    { name: 'Dancing Script', family: 'Dancing Script', category: '艺术' },
    { name: '站酷快乐体', family: 'ZCOOL KuaiLe', category: '中文艺术' }
  ];
  // 应用图标选项（共 6 款，含当前正在使用的经典款）
  private appIconOptions: AppIconOption[] = [
    { id: 'classic',        label: '经典',   style: '当前应用图标',                         resource: APP_ICON_CLASSIC },
    { id: 'bright_gradient',label: '明亮渐变', style: '青绿到深蓝渐变 + 几何 Z 符号',         resource: APP_ICON_BRIGHT_GRADIENT },
    { id: 'glass',          label: '玻璃拟物', style: '毛玻璃方块层叠 + 折射光',             resource: APP_ICON_GLASS },
    { id: 'flat',           label: '扁平彩色', style: '四色圆点十字花瓣 + 纯白背景',         resource: APP_ICON_FLAT },
    { id: '3d_cartoon',     label: '3D 卡通', style: '圆润方块层叠 + 橡皮糖质感',           resource: APP_ICON_3D_CARTOON },
    { id: 'liquid',         label: '液态渐变', style: '流动渐变背景 + 镂空 Z 符号',         resource: APP_ICON_LIQUID }
  ];


  async aboutToAppear(): Promise<void> {
    this.fontSizeScale = await DataRepository.getSetting('fontSizeScale', 'standard');
    this.fontFamily = await DataRepository.getSetting('fontFamily', 'HarmonyOS Sans');
    if (!this.isSupportedFont(this.fontFamily)) {
      this.fontFamily = 'HarmonyOS Sans';
    }
    this.appIconId = await DataRepository.getSetting('appIconId', 'liquid');
    if (!this.isSupportedAppIcon(this.appIconId)) {
      this.appIconId = 'liquid';
    }
    this.avatarId = await DataRepository.getSetting('avatarId', 'liquid');
    this.avatarUri = await DataRepository.getSetting('avatarUri', '');
    if (this.avatarId !== CUSTOM_AVATAR_ID && !this.isSupportedAvatar(this.avatarId)) {
      this.avatarId = 'liquid';
    }
    // 加载背景图配置
    const background = ThemeManager.getInstance().getGlobalBackground();
    this.globalBgUri = background.globalUri;
    this.backgroundStrength = background.visibleStrength;
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
    this.themeState.followSystemDark = follow;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setFollowSystem(follow);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(follow ? '已开启跟随系统深色模式' : '已切换为手动模式');
    } else {
      this.themeState.followSystemDark = !follow;
      this.toast('设置未保存，请重试');
    }
  }

  private async updateManualMode(isDark: boolean): Promise<void> {
    this.themeState.isDark = isDark;
    const mode = isDark ? ThemeMode.DARK : ThemeMode.LIGHT;
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setManualMode(mode);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(isDark ? '已切换为深色模式' : '已切换为浅色模式');
    } else {
      this.themeState.isDark = !isDark;
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
    this.themeState.glassEnabled = enabled;
    if (enabled) {
      this.themeState.liquidGlassEnabled = false;
    }
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setGlassEffect(enabled);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(enabled ? '已开启毛玻璃效果' : '已关闭毛玻璃效果');
    } else {
      this.themeState.glassEnabled = !enabled;
      this.toast('设置未保存，请重试');
    }
  }

  private async updateLiquidGlassEffect(enabled: boolean): Promise<void> {
    this.themeState.liquidGlassEnabled = enabled;
    if (enabled) {
      this.themeState.glassEnabled = false;
    }
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setLiquidGlassEffect(enabled);
    if (result.success) {
      this.toast(enabled ? '已开启液态玻璃效果' : '已关闭液态玻璃效果');
    } else {
      this.themeState.liquidGlassEnabled = !enabled;
      this.toast('设置未保存，请重试');
    }
  }


  private applyPreferenceResult(result: PreferenceMutationResult): void {
    if (result.published || result.restored) {
      this.globalBgUri = result.snapshot.backgroundUri;
      this.backgroundStrength = result.snapshot.backgroundStrength;
      this.themeState.followSystemDark = result.snapshot.followSystem;
      this.themeState.isDark = result.snapshot.followSystem ? this.themeState.isDark :
        result.snapshot.manualThemeMode === ThemeMode.DARK;
      this.fontSizeScale = result.snapshot.fontSizeScale;
    }
  }

  private fontSizeLabel(scale: string): string {
    if (scale === 'xsmall') return '超小';
    if (scale === 'small') return '小';
    if (scale === 'large') return '大';
    if (scale === 'xlarge') return '特大';
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

  // ---- 应用图标 ----
  private appIconLabel(id: string): string {
    for (let i: number = 0; i < this.appIconOptions.length; i++) {
      if (this.appIconOptions[i].id === id) return this.appIconOptions[i].label;
    }
    return '液态渐变';
  }

  private isSupportedAppIcon(id: string): boolean {
    for (let i: number = 0; i < this.appIconOptions.length; i++) {
      if (this.appIconOptions[i].id === id) return true;
    }
    return false;
  }

  private async applyAppIcon(id: string): Promise<void> {
    if (id === this.appIconId) return;
    this.appIconId = id;
    await DataRepository.setSetting('appIconId', id);
    this.toast(`应用图标：${this.appIconLabel(id)}（重新打包后桌面图标生效）`);
  }

  private openAppIconPicker(): void {
    this.showAppIconSheet = true;
  }

  private pickAppIcon(id: string): void {
    this.showAppIconSheet = false;
    this.applyAppIcon(id);
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

  // ---- 头像 ----
  private isSupportedAvatar(id: string): boolean {
    for (let i: number = 0; i < AVATAR_OPTIONS.length; i++) {
      if (AVATAR_OPTIONS[i].id === id) return true;
    }
    return false;
  }

  private avatarLabelText(): string {
    if (this.avatarId === CUSTOM_AVATAR_ID) return '自定义图片';
    return avatarLabel(this.avatarId);
  }

  private openAvatarPicker(): void {
    this.showAvatarSheet = true;
  }

  private async pickAvatar(id: string): Promise<void> {
    this.showAvatarSheet = false;
    if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
      BackgroundImporter.removeSandboxFile(this.avatarUri);
    }
    this.avatarId = id;
    this.avatarUri = '';
    await DataRepository.setSetting('avatarId', id);
    await DataRepository.setSetting('avatarUri', '');
    this.toast(`头像：${this.avatarLabelText()}`);
  }

  private async pickCustomAvatar(): Promise<void> {
    const picked: ImagePickResult = await PickerAdapter.pickSingleImage();
    if (picked.state === ImagePickState.CANCELLED) return;
    if (picked.state === ImagePickState.FAILED) {
      this.toast('选择头像失败');
      return;
    }
    const context = getContext(this);
    const imported: BackgroundImportResult = await BackgroundImporter.importToSandbox(context, picked.uri);
    if (!imported.success) {
      this.toast('无法读取所选图片，请重新选择');
      return;
    }
    if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
      BackgroundImporter.removeSandboxFile(this.avatarUri);
    }
    this.showAvatarSheet = false;
    this.avatarId = CUSTOM_AVATAR_ID;
    this.avatarUri = imported.sandboxUri;
    await DataRepository.setSetting('avatarId', CUSTOM_AVATAR_ID);
    await DataRepository.setSetting('avatarUri', imported.sandboxUri);
    this.toast('头像已更新为自定义图片');
  }

  private async clearCustomAvatar(): Promise<void> {
    if (this.avatarUri.length > 0) {
      BackgroundImporter.removeSandboxFile(this.avatarUri);
    }
    this.showAvatarSheet = false;
    this.avatarId = 'liquid';
    this.avatarUri = '';
    await DataRepository.setSetting('avatarId', 'liquid');
    await DataRepository.setSetting('avatarUri', '');
    this.toast('头像已恢复默认');
  }

  @Builder actionsBuilder() {}


  // 深色模式设置
  @Builder darkModeSettings() {
    Column({ space: 8 }) {
      Row() {
        Text('跟随系统深色模式')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.themeState.followSystemDark })
          .selectedColor(this.themeState.palette.primary)
          .onChange((v: boolean) => {
            this.updateFollowSystem(v);
          })
      }
      .width('100%')
      .height(this.themeState.palette.rowHeightCompact)
      .padding({ left: 12, right: 12 })
      .borderRadius(this.themeState.palette.radiusSm)
      .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))

      if (!this.themeState.followSystemDark) {
        Row() {
          Text('深色模式')
            .fontSize(this.themeState.palette.fsBase)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.themeState.isDark })
            .selectedColor(this.themeState.palette.primary)
            .onChange((v: boolean) => {
              this.updateManualMode(v);
            })
        }
        .width('100%')
        .height(this.themeState.palette.rowHeightCompact)
        .padding({ left: 12, right: 12 })
        .borderRadius(this.themeState.palette.radiusSm)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
      }
    }
    .width('100%')
  }

  // 背景图设置
  @Builder backgroundSettings() {
    Column({ space: 8 }) {
      Row() {
        Text('全局背景图')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .layoutWeight(1)
        if (this.themeState.backgroundDisplayState === BackgroundDisplayState.LOADING) {
          Text('正在应用')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
        } else if (this.themeState.backgroundDisplayState === BackgroundDisplayState.INVALID && this.globalBgUri) {
          Text('背景失效，请重新选择')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.warning)
        } else if (this.globalBgUri) {
          Text('已设置')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.success)
        } else {
          Text('未设置')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
      }
      .width('100%')
      .height(this.themeState.palette.rowHeightCompact)
      .padding({ left: 12, right: 12 })
      .borderRadius(this.themeState.palette.radiusSm)
      .backgroundColor(this.themeState.palette.bgSurface2)
      .onClick(() => {
        this.pickBackgroundImage();
      })

      if (this.globalBgUri) {
        Row() {
          Text('清除背景图')
            .fontSize(this.themeState.palette.fsBase)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
        }
        .width('100%')
        .height(this.themeState.palette.rowHeightCompact)
        .padding({ left: 12, right: 12 })
        .borderRadius(this.themeState.palette.radiusSm)
        .backgroundColor(this.themeState.palette.bgSurface2)
        .onClick(() => {
          this.confirmClearBackground();
        })
      }

      Row() {
        Text('可见强度')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .layoutWeight(1)
        Text(`${this.backgroundStrength}%`)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      Slider({ value: this.backgroundStrength, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.themeState.palette.primary)
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
        .backgroundColor(this.themeState.palette.maskOverlay)
        .onClick(() => { this.showFontSizeSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('字号')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字号大小')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ bottom: 8 })

        ForEach(this.fontSizeOptions, (option: FontSizeOption) => {
          Row({ space: 12 }) {
            Text('Aa 智子 123')
              .fontSize(option.preview)
              .fontFamily(this.themeState.palette.fontSans)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.fontSizeScale === option.value ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
            Blank()
            Text(option.label)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.fontSizeScale === option.value ? this.themeState.palette.primary : this.themeState.palette.textSecondary)
            if (this.fontSizeScale === option.value) {
              Text('✓')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeState.palette.primary)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          .borderRadius(this.themeState.palette.radiusSm)
          .backgroundColor(this.fontSizeScale === option.value ?
            this.themeState.palette.primaryBgStrong : GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
          .onClick(() => { this.pickFontSize(option.value); })
        }, (option: FontSizeOption) => option.value)

        Text('取消')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showFontSizeSheet = false; })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.themeState.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
      .shadow({ radius: 24, color: this.themeState.palette.maskOverlay, offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
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
        .backgroundColor(this.themeState.palette.maskOverlay)
        .onClick(() => { this.showFontFamilySheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('字体')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字体')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 4 }) {
            ForEach(this.fontFamilyOptions, (option: FontFamilyOption) => {
              Row({ space: 12 }) {
                Column({ space: 3 }) {
                  Text(option.name)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(option.family)
                    .fontColor(this.fontFamily === option.family ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text('Aa 智子 123 — ' + option.category)
                    .fontSize(this.themeState.palette.fsSm - 1)
                    .fontFamily(option.family)
                    .fontColor(this.fontFamily === option.family ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.fontFamily === option.family) {
                  Text('✓')
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeState.palette.primary)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 13, bottom: 13 })
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.fontFamily === option.family ?
                this.themeState.palette.primaryBgStrong : GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
              .onClick(() => { this.pickFontFamily(option.family); })
            }, (option: FontFamilyOption) => option.family)
          }
          .width('100%')
          .padding({ right: 2 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        Text('取消')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showFontFamilySheet = false; })
      }
      .width('100%')
      .height('70%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.themeState.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
      .shadow({ radius: 24, color: this.themeState.palette.maskOverlay, offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  // 应用图标选择弹层
  @Builder
  appIconSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.themeState.palette.maskOverlay)
        .onClick(() => { this.showAppIconSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('应用图标')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择应用图标（重新打包发布后桌面图标生效）')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.appIconOptions, (option: AppIconOption) => {
              Row({ space: 12 }) {
                Image(option.resource)
                  .width(48)
                  .height(48)
                  .borderRadius(this.themeState.palette.radiusSm)
                  .border({
                    width: this.appIconId === option.id ? 2 : 1,
                    color: this.appIconId === option.id ? this.themeState.palette.primary : this.themeState.palette.borderSubtle
                  })
                Column({ space: 2 }) {
                  Text(option.label)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.appIconId === option.id ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(option.style)
                    .fontSize(this.themeState.palette.fsSm - 1)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.appIconId === option.id ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.appIconId === option.id) {
                  Text('✓')
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeState.palette.primary)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.appIconId === option.id ?
                this.themeState.palette.primaryBgStrong : GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
              .onClick(() => { this.pickAppIcon(option.id); })
            }, (option: AppIconOption) => option.id)
          }
          .width('100%')
          .padding({ right: 2 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        Text('取消')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showAppIconSheet = false; })
      }
      .width('100%')
      .height('70%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.themeState.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
      .shadow({ radius: 24, color: this.themeState.palette.maskOverlay, offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  // 头像选择弹层
  @Builder
  avatarSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.themeState.palette.maskOverlay)
        .onClick(() => { this.showAvatarSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('头像')
          .fontSize(this.themeState.palette.fsLg)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择头像样式，或从相册选择自定义图片')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 8 }) {
            // 自定义图片入口
            Row({ space: 12 }) {
              Stack() {
                if (this.avatarId === CUSTOM_AVATAR_ID && this.avatarUri.length > 0) {
                  Image(this.avatarUri)
                    .width(48)
                    .height(48)
                    .borderRadius(this.themeState.palette.radiusCapsule)
                    .objectFit(ImageFit.Cover)
                    .border({
                      width: 2,
                      color: this.themeState.palette.primary
                    })
                } else {
                  Circle({ width: 48, height: 48 })
                    .fill(this.themeState.palette.bgSurface2)
                    .border({
                      width: this.avatarId === CUSTOM_AVATAR_ID ? 2 : 1,
                      color: this.avatarId === CUSTOM_AVATAR_ID ? this.themeState.palette.primary : this.themeState.palette.borderSubtle
                    })
                  Text('＋')
                    .fontSize(24)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primary)
                    .fontWeight(FontWeight.Bold)
                }
              }
              Column({ space: 2 }) {
                Text('自定义图片')
                  .fontSize(this.themeState.palette.fsSm)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.avatarId === CUSTOM_AVATAR_ID ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                Text('从相册选择一张图片作为头像')
                  .fontSize(this.themeState.palette.fsSm - 1)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.avatarId === CUSTOM_AVATAR_ID ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.avatarId === CUSTOM_AVATAR_ID) {
                Text('✓')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.themeState.palette.primary)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .borderRadius(this.themeState.palette.radiusSm)
            .backgroundColor(this.avatarId === CUSTOM_AVATAR_ID ?
              this.themeState.palette.primaryBgStrong : GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
            .onClick(() => { this.pickCustomAvatar(); })

            ForEach(AVATAR_OPTIONS, (option: AvatarOption) => {
              Row({ space: 12 }) {
                Stack() {
                  // 渐变底
                  Column()
                    .width(48)
                    .height(48)
                    .borderRadius(this.themeState.palette.radiusCapsule)
                    .linearGradient({
                      angle: 135,
                      colors: [[option.colors[0], 0.0], [option.colors[1], 1.0]]
                    })
                    .border({
                      width: this.avatarId === option.id ? 2 : 1,
                      color: this.avatarId === option.id ? this.themeState.palette.primary : this.themeState.palette.borderSubtle
                    })
                  Text('Z')
                    .fontSize(20)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.primaryOnColor)
                    .fontWeight(FontWeight.Bold)
                }
                Column({ space: 2 }) {
                  Text(option.label)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.avatarId === option.id ? this.themeState.palette.primary : this.themeState.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(option.style)
                    .fontSize(this.themeState.palette.fsSm - 1)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.avatarId === option.id ? this.themeState.palette.primary : this.themeState.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.avatarId === option.id) {
                  Text('✓')
                    .fontSize(this.themeState.palette.fsMd)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeState.palette.primary)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(this.themeState.palette.radiusSm)
              .backgroundColor(this.avatarId === option.id ?
                this.themeState.palette.primaryBgStrong : GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
              .onClick(() => { this.pickAvatar(option.id); })
            }, (option: AvatarOption) => option.id)

            if (this.avatarId === CUSTOM_AVATAR_ID) {
              Text('恢复默认')
                .fontSize(this.themeState.palette.fsBase)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.danger)
                .padding({ top: 8, bottom: 4 })
                .width('100%')
                .textAlign(TextAlign.Center)
                .onClick(() => { this.clearCustomAvatar(); })
            }
          }
          .width('100%')
          .padding({ right: 2 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        Text('取消')
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showAvatarSheet = false; })
      }
      .width('100%')
      .height('70%')
      .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.themeState.navBarHeight + 8) })
      .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette))
      .borderRadius({ topLeft: this.themeState.palette.radiusXl, topRight: this.themeState.palette.radiusXl })
      .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P0_BAR, this.themeState.palette) })
      .shadow({ radius: 24, color: this.themeState.palette.maskOverlay, offsetY: -4 })
      .backgroundBlurStyle(glassBlurStyle(this.themeState.glassEnabled, GlassLevel.P0_BAR))
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '外观', subtitle: '主题 / 背景 / 字号 / 字体 / 头像', showBack: true }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            SettingGroupCard({ title: '深色模式' }) {
              Column({ space: 8 }) {
                this.darkModeSettings()
              }
              .width('100%')
            }

            SettingGroupCard({ title: '背景图' }) {
              Column({ space: 8 }) {
                this.backgroundSettings()
              }
              .width('100%')
            }

            SettingGroupCard({ title: '玻璃效果' }) {
              Column({ space: 8 }) {
                Row() {
                  Text('启用毛玻璃效果')
                    .fontSize(this.themeState.palette.fsBase)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textPrimary)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.themeState.glassEnabled })
                    .selectedColor(this.themeState.palette.primary)
                    .onChange((v: boolean) => {
                      this.updateGlassEffect(v);
                    })
                }
                .width('100%')
                .height(this.themeState.palette.rowHeightCompact)
                .padding({ left: 12, right: 12 })
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
                Text('开启后顶栏、底栏、卡片将呈现透明磨砂质感，建议搭配背景图使用。')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })

                Row() {
                  Text('启用液态玻璃效果')
                    .fontSize(this.themeState.palette.fsBase)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textPrimary)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.themeState.liquidGlassEnabled })
                    .selectedColor(this.themeState.palette.primary)
                    .onChange((v: boolean) => {
                      this.updateLiquidGlassEffect(v);
                    })
                }
                .width('100%')
                .height(this.themeState.palette.rowHeightCompact)
                .padding({ left: 12, right: 12 })
                .borderRadius(this.themeState.palette.radiusSm)
                .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.liquidGlassEnabled, this.themeState.palette))
                Text('开启后界面呈现更通透的液态玻璃质感，与毛玻璃互斥。')
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .width('100%')
            }

            SettingGroupCard({ title: '文字与图标' }) {
              Column({ space: 8 }) {
                SettingRow({
                  icon: '🔠',
                  title: '字号',
                  value: this.fontSizeLabel(this.fontSizeScale),
                  rowClick: () => { this.openFontSizePicker(); }
                })
                SettingRow({
                  icon: '🔤',
                  title: '字体',
                  value: this.fontFamily,
                  rowClick: () => { this.openFontFamilyPicker(); }
                })
                SettingRow({
                  icon: '🖼',
                  title: '应用图标',
                  value: this.appIconLabel(this.appIconId),
                  rowClick: () => { this.openAppIconPicker(); }
                })
                SettingRow({
                  icon: '👤',
                  title: '头像',
                  value: this.avatarLabelText(),
                  rowClick: () => { this.openAvatarPicker(); }
                })
              }
              .width('100%')
            }
            Column().height(20)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: 12, bottom: Math.max(24, this.themeState.navBarHeight + 8) })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.bgBase)

      // 弹层
      if (this.showFontSizeSheet) {
        this.fontSizeSheet()
      }
      if (this.showFontFamilySheet) {
        this.fontFamilySheet()
      }
      if (this.showAppIconSheet) {
        this.appIconSheet()
      }
      if (this.showAvatarSheet) {
        this.avatarSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
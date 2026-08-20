// 智子 - 设置页面（沉浸光感重构版）
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette, ColorThemeId, colorThemeName, colorThemeColor,
  ThemeManager, ThemeMode, PreferenceMutationResult, PreferenceFailureReason } from '../common/Theme';
import { BackgroundDisplayState } from '../common/Theme';
import { DataRepository } from '../service/DataRepository';
import { BackgroundImporter, BackgroundImportResult } from '../service/BackgroundImporter';
import { PickerAdapter, ImagePickResult, ImagePickState } from '../service/PickerAdapter';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { AvatarOption, AVATAR_OPTIONS, CUSTOM_AVATAR_ID, avatarLabel } from '../common/AvatarOptions';
import { SecurityService, autoLockLabel, AUTO_LOCK_OPTIONS } from '../service/SecurityService';
import { BiometricHelper } from '../service/BiometricHelper';
import { SoundService } from '../service/SoundService';
import { HuaweiAccountService } from '../service/HuaweiAccountService';
import { CloudSyncService } from '../service/CloudSyncService';
import { AppNavigator } from '../common/AppNavigator';
import { NEWS_SOURCES, NEWS_CHANNELS } from '../common/NewsChannels';
import { NewsSourceDef, NewsChannel } from '../common/NewsModels';
import { NewsModelSelector } from '../components/NewsModelSelector';
import { NewsAiService } from '../service/NewsAiService';
import { NewsRepository } from '../service/NewsRepository';
import { NewsService } from '../service/NewsService';

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

// 应用图标选项
interface AppIconOption {
  id: string;       // 持久化用的标识
  label: string;    // 显示名称
  style: string;    // 风格描述
  resource: string; // media 资源名（不带 $media: 前缀）
}

// 自定义 RSS 订阅持久化结构（settings.newsCustomRss）
interface CustomRssSetting {
  name: string;
  url: string;
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
  @StorageLink('liquidGlassEnabled') liquidGlassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDarkMode: boolean = true;
  @StorageLink('followSystemDark') followSystemDark: boolean = true;
  @StorageLink('colorThemeId') colorThemeId: string = 'cyan';
  @StorageLink('backgroundDisplayState') backgroundDisplayState: BackgroundDisplayState = BackgroundDisplayState.INVALID;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  onBack: () => void = () => {};

  // 外观
  @State fontSizeScale: string = 'standard';
  @State fontFamily: string = 'HarmonyOS Sans';
  @State showFontSizeSheet: boolean = false;
  @State showFontFamilySheet: boolean = false;
  @State showAppIconSheet: boolean = false;
  @State showAvatarSheet: boolean = false;
  @State appIconId: string = 'liquid';
  @State avatarId: string = 'liquid';
  @State avatarUri: string = '';
  // 安全
  @State biometricUnlock: boolean = false;
  @State autoLock: string = '关闭';
  @State hasMasterPassword: boolean = false;
  // 主密码弹窗
  @State showPasswordSheet: boolean = false;
  @State passwordInput: string = '';
  @State passwordConfirm: string = '';
  @State passwordMode: string = 'set'; // set / change / clear / verify
  @State passwordError: string = '';
  @State passwordBusy: boolean = false;
  // 自动锁定选择弹窗
  @State showAutoLockSheet: boolean = false;
  // 数据
  @State autoBackup: boolean = false;
  // 游戏
  @State soundEnabled: boolean = true;
  // 云同步
  @State huaweiNick: string = '';
  @State cloudSyncLast: string = '从未同步';
  @State syncBusy: boolean = false;
  // Agent
  @State agentEnabled: boolean = false;
  // 资讯
  @State newsEnabledIds: string[] = [];
  @State customRssName: string = '';
  @State customRssUrl: string = '';
  @State customSources: NewsSourceDef[] = [];
  // 关闭个性化的频道 id 列表（默认空 = 全部频道个性化；动态适配频道增减）
  @State newsPersonalizedOff: string[] = [];
  // LLM 智能标签开关（默认关闭，M4）
  @State newsTagLlmEnabled: boolean = false;
  // 个性化模式（M2 增强）：standard / aggressive / hot / explore
  @State newsPersonalizedMode: string = 'standard';
  // OPML 导入
  @State showOpmlSheet: boolean = false;
  @State opmlText: string = '';
  @State opmlResult: string = '';

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
    { id: 'classic',        label: '经典',   style: '当前应用图标',                         resource: 'app_icon_classic' },
    { id: 'bright_gradient',label: '明亮渐变', style: '青绿到深蓝渐变 + 几何 Z 符号',         resource: 'app_icon_bright_gradient' },
    { id: 'glass',          label: '玻璃拟物', style: '毛玻璃方块层叠 + 折射光',             resource: 'app_icon_glass' },
    { id: 'flat',           label: '扁平彩色', style: '四色圆点十字花瓣 + 纯白背景',         resource: 'app_icon_flat' },
    { id: '3d_cartoon',     label: '3D 卡通', style: '圆润方块层叠 + 橡皮糖质感',           resource: 'app_icon_3d_cartoon' },
    { id: 'liquid',         label: '液态渐变', style: '流动渐变背景 + 镂空 Z 符号',         resource: 'app_icon_liquid' }
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
      this.biometricUnlock = await SecurityService.isBiometricEnabled();
      const autoBackupVal = await DataRepository.getSetting('autoBackup', 'false');
      this.autoBackup = autoBackupVal === 'true';
      this.soundEnabled = SoundService.isEnabled();
      this.agentEnabled = await DataRepository.getSetting('agentEnabled', 'false') === 'true';
      this.loadNewsSourceSettings();
      this.loadNewsPersonalized();
      this.loadTagLlmState();
      this.loadNewsMode();
      const profile = await HuaweiAccountService.getStoredProfile();
      this.huaweiNick = profile !== null ? profile.nickName : '';
      this.cloudSyncLast = await CloudSyncService.lastSyncLabel();
      this.hasMasterPassword = await SecurityService.hasPassword();
      this.autoLock = autoLockLabel(await SecurityService.getAutoLockValue());

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

  // ==================== 资讯 ====================

  private async loadNewsPersonalized(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsPersonalizedChannels', '');
      if (raw.trim().length === 0) {
        this.newsPersonalizedOff = [];
        return;
      }
      const parsed: Object = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const ids: string[] = [];
        const arr: Object[] = parsed as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') ids.push(arr[i] as string);
        }
        this.newsPersonalizedOff = ids;
      }
    } catch (e) {
      this.newsPersonalizedOff = [];
    }
  }

  private channelPersonalized(id: string): boolean {
    return this.newsPersonalizedOff.indexOf(id) < 0;
  }

  // ==================== LLM 智能标签（M4） ====================

  private async loadTagLlmState(): Promise<void> {
    this.newsTagLlmEnabled = await NewsAiService.isTagLlmEnabled();
  }

  private async onTagLlmToggle(on: boolean): Promise<void> {
    await NewsAiService.setTagLlmEnabled(on);
    this.newsTagLlmEnabled = on;
    this.toast(on ? '已开启智能标签（将把新闻标题/摘要发送至所选模型）' : '已关闭智能标签');
  }

  // ==================== 个性化模式（M2 增强） ====================

  private async loadNewsMode(): Promise<void> {
    this.newsPersonalizedMode = await DataRepository.getSetting('newsPersonalizedMode', 'standard');
  }

  private modeLabel(mode: string): string {
    if (mode === 'aggressive') return '高个性化';
    if (mode === 'explore') return '探索';
    if (mode === 'hot') return '仅热点';
    return '标准';
  }

  private async onNewsModePick(): Promise<void> {
    promptAction.showActionMenu({
      title: '个性化模式',
      buttons: [
        { text: '标准（推荐）', color: '#666666' },
        { text: '高个性化', color: '#666666' },
        { text: '仅热点', color: '#666666' },
        { text: '探索', color: '#666666' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const modes: string[] = ['standard', 'aggressive', 'hot', 'explore'];
      if (result.index >= 0 && result.index < modes.length) {
        const mode: string = modes[result.index];
        this.newsPersonalizedMode = mode;
        DataRepository.setSetting('newsPersonalizedMode', mode).then(() => {
          this.toast('个性化模式：' + this.modeLabel(mode));
        });
      }
    }).catch(() => {
    });
  }

  private async onChannelPersonalizedToggle(id: string, on: boolean): Promise<void> {
    await NewsRepository.setChannelPersonalized(id, on);
    this.loadNewsPersonalized();
  }

  private async loadNewsSourceSettings(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsEnabledSources', '');
      if (raw.trim().length > 0) {
        const parsed: Object = JSON.parse(raw) as Object;
        if (Array.isArray(parsed)) {
          const ids: string[] = [];
          const arr: Object[] = parsed as Object[];
          for (let i: number = 0; i < arr.length; i++) {
            if (typeof arr[i] === 'string') ids.push(arr[i] as string);
          }
          this.newsEnabledIds = ids;
        }
      }
    } catch (e) {
    }
    this.loadCustomRss();
  }

  private newsSourceEnabled(id: string): boolean {
    return this.newsEnabledIds.indexOf(id) >= 0;
  }

  private sourceNameOf(id: string): string {
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      if (NEWS_SOURCES[i].id === id) return NEWS_SOURCES[i].name;
    }
    return id;
  }

  private async onNewsSourceToggle(id: string, enabled: boolean): Promise<void> {
    let ids: string[] = this.newsEnabledIds.slice();
    const pos: number = ids.indexOf(id);
    if (enabled && pos < 0) {
      ids = ids.concat([id]);
    }
    if (!enabled && pos >= 0) {
      ids.splice(pos, 1);
    }
    this.newsEnabledIds = ids;
    await DataRepository.setSetting('newsEnabledSources', JSON.stringify(ids));
    this.toast((enabled ? '已开启：' : '已关闭：') + this.sourceNameOf(id));
  }

  private async loadCustomRss(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsCustomRss', '');
      const sources: NewsSourceDef[] = [];
      if (raw.trim().length > 0) {
        const parsed: Object = JSON.parse(raw) as Object;
        if (Array.isArray(parsed)) {
          const arr: Object[] = parsed as Object[];
          for (let i: number = 0; i < arr.length; i++) {
            const entry: Record<string, Object> = arr[i] as Record<string, Object>;
            const name: string = typeof entry['name'] === 'string' ? entry['name'] as string : '';
            const url: string = typeof entry['url'] === 'string' ? entry['url'] as string : '';
            if (name.trim().length > 0 && url.trim().length > 0) {
              sources.push(new NewsSourceDef('custom:' + url, name.trim(), 'recommend', 'rss', url.trim()));
            }
          }
        }
      }
      this.customSources = sources;
    } catch (e) {
      this.customSources = [];
    }
  }

  private async persistCustomRss(): Promise<void> {
    const rows: CustomRssSetting[] = [];
    for (let i: number = 0; i < this.customSources.length; i++) {
      const row: CustomRssSetting = { name: this.customSources[i].name, url: this.customSources[i].url };
      rows.push(row);
    }
    await DataRepository.setSetting('newsCustomRss', JSON.stringify(rows));
  }

  private async addCustomRss(): Promise<void> {
    const name: string = this.customRssName.trim();
    let url: string = this.customRssUrl.trim();
    if (name.length === 0 || url.length === 0) {
      this.toast('请填写订阅名称和 RSS 地址');
      return;
    }
    if (url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0) {
      this.toast('RSS 地址需以 http:// 或 https:// 开头');
      return;
    }
    for (let i: number = 0; i < this.customSources.length; i++) {
      if (this.customSources[i].url === url) {
        this.toast('该订阅已存在');
        return;
      }
    }
    this.customSources = this.customSources.concat([new NewsSourceDef('custom:' + url, name, 'recommend', 'rss', url)]);
    await this.persistCustomRss();
    this.customRssName = '';
    this.customRssUrl = '';
    this.toast('已添加订阅：' + name + '（刷新资讯页后生效）');
  }

  private async removeCustomRss(url: string): Promise<void> {
    const next: NewsSourceDef[] = [];
    for (let i: number = 0; i < this.customSources.length; i++) {
      if (this.customSources[i].url !== url) {
        next.push(this.customSources[i]);
      }
    }
    this.customSources = next;
    await this.persistCustomRss();
    this.toast('已删除订阅');
  }

  // 解析并导入 OPML（按 URL 去重合并到自定义订阅）
  private async importOpml(): Promise<void> {
    const sources: NewsSourceDef[] = NewsService.parseOpml(this.opmlText);
    if (sources.length === 0) {
      this.opmlResult = '未解析到有效订阅，请检查 OPML 内容';
      return;
    }
    let added: number = 0;
    let skipped: number = 0;
    for (let i: number = 0; i < sources.length; i++) {
      let exists: boolean = false;
      for (let j: number = 0; j < this.customSources.length; j++) {
        if (this.customSources[j].url === sources[i].url) {
          exists = true;
          break;
        }
      }
      if (exists) {
        skipped = skipped + 1;
      } else {
        this.customSources = this.customSources.concat([sources[i]]);
        added = added + 1;
      }
    }
    await this.persistCustomRss();
    this.opmlResult = '导入完成：新增 ' + added.toString() + ' 个，跳过重复 ' + skipped.toString() + ' 个';
    this.opmlText = '';
    this.toast('已导入 ' + added.toString() + ' 个订阅');
  }

  // OPML 导入弹层
  @Builder
  opmlSheet() {
    Stack() {
      Column() {
        Blank()
        Column({ space: 12 }) {
          Row() {
            Text('导入 OPML 订阅')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => {
                this.showOpmlSheet = false;
                this.opmlText = '';
                this.opmlResult = '';
              })
          }
          .width('100%')

          TextArea({ placeholder: '粘贴 OPML XML 内容（含 <outline xmlUrl=…/> 的订阅）', text: this.opmlText })
            .width('100%')
            .height(150)
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .onChange((v: string) => { this.opmlText = v; })

          if (this.opmlResult.length > 0) {
            Text(this.opmlResult)
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .width('100%')
          }

          Button('解析并导入')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.palette.primary)
            .width('100%')
            .height(42)
            .borderRadius(10)
            .onClick(() => { this.importOpml(); })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => {
      this.showOpmlSheet = false;
      this.opmlText = '';
      this.opmlResult = '';
    })
  }

  // ==================== 游戏音效 ====================
  private async onSoundToggle(v: boolean): Promise<void> {
    this.soundEnabled = v;
    await SoundService.setEnabled(v);
    this.toast(v ? '游戏音效已开启' : '游戏音效已关闭');
  }

  // ==================== 云同步 ====================
  private async onHuaweiSignIn(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.toast('无法获取应用上下文');
      return;
    }
    try {
      const profile = await HuaweiAccountService.signIn(ctx);
      this.huaweiNick = profile.nickName.length > 0 ? profile.nickName : profile.openId;
      this.toast('已登录华为账号：' + this.huaweiNick);
    } catch (e) {
      this.toast('登录失败或已取消');
    }
  }

  private async onHuaweiSignOut(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.toast('无法获取应用上下文');
      return;
    }
    await HuaweiAccountService.signOut(ctx);
    this.huaweiNick = '';
    this.toast('已退出华为账号');
  }

  private async onCloudBackup(): Promise<void> {
    if (this.syncBusy) return;
    this.syncBusy = true;
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        this.toast('无法获取应用上下文');
        return;
      }
      const result = await CloudSyncService.backupNow(ctx);
      this.toast(result.message);
      this.cloudSyncLast = await CloudSyncService.lastSyncLabel();
    } finally {
      this.syncBusy = false;
    }
  }

  private async onCloudRestore(): Promise<void> {
    if (this.syncBusy) return;
    this.syncBusy = true;
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        this.toast('无法获取应用上下文');
        return;
      }
      const result = await CloudSyncService.restoreNow(ctx);
      this.toast(result.message);
      this.cloudSyncLast = await CloudSyncService.lastSyncLabel();
    } finally {
      this.syncBusy = false;
    }
  }

  // ==================== 安全 ====================

  // 点击主密码行：未设置 → 设置；已设置 → 修改/清除
  private onMasterPasswordRow(): void {
    if (this.hasMasterPassword) {
      // 已设置：先验证当前密码，弹出 修改 / 清除 选择
      this.passwordMode = 'verify';
      this.passwordInput = '';
      this.passwordConfirm = '';
      this.passwordError = '';
      this.showPasswordSheet = true;
    } else {
      this.passwordMode = 'set';
      this.passwordInput = '';
      this.passwordConfirm = '';
      this.passwordError = '';
      this.showPasswordSheet = true;
    }
  }

  // 验证模式通过后：提供 修改 / 清除 两个入口
  private onVerifySuccess(): void {
    this.showPasswordSheet = false;
    AlertDialog.show({
      title: '主密码',
      message: '已设置主密码，选择要执行的操作：',
      primaryButton: {
        value: '修改密码',
        action: () => {
          this.passwordMode = 'change';
          this.passwordInput = '';
          this.passwordConfirm = '';
          this.passwordError = '';
          this.showPasswordSheet = true;
        }
      },
      secondaryButton: {
        value: '清除密码',
        fontColor: Color.Red,
        action: () => {
          this.clearMasterPassword();
        }
      }
    });
  }

  private async clearMasterPassword(): Promise<void> {
    await SecurityService.clearPassword();
    this.hasMasterPassword = false;
    this.biometricUnlock = false;
    this.autoLock = '关闭';
    this.toast('主密码已清除，相关安全功能已关闭');
  }

  // 确认设置/修改密码
  private async confirmPassword(): Promise<void> {
    const pwd: string = this.passwordInput;
    const confirm: string = this.passwordConfirm;
    if (pwd.length < 4) {
      this.passwordError = '密码至少 4 位';
      return;
    }
    if (this.passwordMode === 'set' || this.passwordMode === 'change') {
      if (pwd !== confirm) {
        this.passwordError = '两次输入的密码不一致';
        return;
      }
    }
    this.passwordBusy = true;
    if (this.passwordMode === 'set') {
      await SecurityService.setPassword(pwd);
      this.hasMasterPassword = true;
      this.showPasswordSheet = false;
      this.toast('主密码已设置');
    } else if (this.passwordMode === 'change') {
      await SecurityService.setPassword(pwd);
      this.hasMasterPassword = true;
      this.showPasswordSheet = false;
      this.toast('主密码已修改');
    } else if (this.passwordMode === 'verify') {
      const ok: boolean = await SecurityService.verifyPassword(pwd);
      if (ok) {
        this.showPasswordSheet = false;
        this.onVerifySuccess();
      } else {
        this.passwordError = '密码错误，请重试';
      }
    }
    this.passwordBusy = false;
  }

  // 生物识别开关：未设置主密码时不允许开启
  private async onBiometricToggle(v: boolean): Promise<void> {
    if (v && !this.hasMasterPassword) {
      this.toast('请先设置主密码');
      this.biometricUnlock = false;
      return;
    }
    if (v) {
      if (!BiometricHelper.isSupported()) {
        this.toast('当前设备不支持或未录入生物识别');
        this.biometricUnlock = false;
        return;
      }
      const ok: boolean = await BiometricHelper.authenticate('验证身份以开启生物识别解锁');
      if (!ok) {
        this.toast('身份验证未通过');
        this.biometricUnlock = false;
        return;
      }
      this.biometricUnlock = true;
      await SecurityService.setBiometricEnabled(true);
      this.toast('生物识别解锁：已开启');
    } else {
      this.biometricUnlock = false;
      await SecurityService.setBiometricEnabled(false);
      this.toast('生物识别解锁：已关闭');
    }
  }

  // 自动锁定选择
  private async onAutoLockSelect(value: number): Promise<void> {
    if (value !== 0 && !this.hasMasterPassword) {
      this.toast('请先设置主密码');
      this.showAutoLockSheet = false;
      return;
    }
    await SecurityService.setAutoLockValue(value);
    this.autoLock = autoLockLabel(value);
    this.showAutoLockSheet = false;
    this.toast('自动锁定：' + autoLockLabel(value));
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
    if (enabled) {
      this.liquidGlassEnabled = false;
    }
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setGlassEffect(enabled);
    this.applyPreferenceResult(result);
    if (result.success) {
      this.toast(enabled ? '已开启毛玻璃效果' : '已关闭毛玻璃效果');
    } else {
      this.glassEnabled = !enabled;
      this.toast('设置未保存，请重试');
    }
  }

  private async updateLiquidGlassEffect(enabled: boolean): Promise<void> {
    this.liquidGlassEnabled = enabled;
    if (enabled) {
      this.glassEnabled = false;
    }
    const result: PreferenceMutationResult = await ThemeManager.getInstance().setLiquidGlassEffect(enabled);
    if (result.success) {
      this.toast(enabled ? '已开启液态玻璃效果' : '已关闭液态玻璃效果');
    } else {
      this.liquidGlassEnabled = !enabled;
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

  @Builder valueRow(label: string, value: string, onClick?: () => void) {
    Row() {
      Text(label)
        .fontSize(this.palette.fsBase)
        .fontColor(this.palette.textPrimary)
        .fontFamily(this.palette.fontSans)
        .layoutWeight(1)
      if (value) {
        Text(value)
          .fontSize(this.palette.fsSm)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontSans)
          .margin({ right: 6 })
      }
      Text('›')
        .fontSize(this.palette.fsMd)
        .fontFamily(this.palette.fontSans)
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
        .fontSize(this.palette.fsBase)
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
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Bold)
            }
          }
          Text(colorThemeName(themeId))
            .fontSize(this.palette.fsXs - 1)
            .fontFamily(this.palette.fontSans)
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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
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
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        if (this.backgroundDisplayState === BackgroundDisplayState.LOADING) {
          Text('正在应用')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.primary)
        } else if (this.backgroundDisplayState === BackgroundDisplayState.INVALID && this.globalBgUri) {
          Text('背景失效，请重新选择')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.warning)
        } else if (this.globalBgUri) {
          Text('已设置')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.success)
        } else {
          Text('未设置')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
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
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
        Text(`${this.backgroundStrength}%`)
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字号大小')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .margin({ bottom: 8 })

        ForEach(this.fontSizeOptions, (option: FontSizeOption) => {
          Row({ space: 12 }) {
            Text('Aa 智子 123')
              .fontSize(option.preview)
              .fontFamily(this.palette.fontSans)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.fontSizeScale === option.value ? this.palette.primary : this.palette.textPrimary)
            Blank()
            Text(option.label)
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.fontSizeScale === option.value ? this.palette.primary : this.palette.textSecondary)
            if (this.fontSizeScale === option.value) {
              Text('✓')
                .fontSize(this.palette.fsMd)
                .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
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
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择全局字体')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 4 }) {
            ForEach(this.fontFamilyOptions, (option: FontFamilyOption) => {
              Row({ space: 12 }) {
                Column({ space: 3 }) {
                  Text(option.name)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(option.family)
                    .fontColor(this.fontFamily === option.family ? this.palette.primary : this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text('Aa 智子 123 — ' + option.category)
                    .fontSize(this.palette.fsSm - 1)
                    .fontFamily(option.family)
                    .fontColor(this.fontFamily === option.family ? this.palette.primary : this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.fontFamily === option.family) {
                  Text('✓')
                    .fontSize(this.palette.fsMd)
                    .fontFamily(this.palette.fontSans)
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
          }
          .width('100%')
          .padding({ right: 2 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        Text('取消')
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showFontFamilySheet = false; })
      }
      .width('100%')
      .height('70%')
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

  // 应用图标选择弹层
  @Builder
  appIconSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showAppIconSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('应用图标')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择应用图标（重新打包发布后桌面图标生效）')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.appIconOptions, (option: AppIconOption) => {
              Row({ space: 12 }) {
                Image($r(`app.media.${option.resource}`))
                  .width(48)
                  .height(48)
                  .borderRadius(12)
                  .border({
                    width: this.appIconId === option.id ? 2 : 1,
                    color: this.appIconId === option.id ? this.palette.primary : this.palette.borderSubtle
                  })
                Column({ space: 2 }) {
                  Text(option.label)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.appIconId === option.id ? this.palette.primary : this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(option.style)
                    .fontSize(this.palette.fsSm - 1)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.appIconId === option.id ? this.palette.primary : this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.appIconId === option.id) {
                  Text('✓')
                    .fontSize(this.palette.fsMd)
                    .fontFamily(this.palette.fontSans)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.palette.primary)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(10)
              .backgroundColor(this.appIconId === option.id ?
                this.palette.primaryDim : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showAppIconSheet = false; })
      }
      .width('100%')
      .height('70%')
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

  // 头像选择弹层
  @Builder
  avatarSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showAvatarSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Text('头像')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
        Text('选择头像样式，或从相册选择自定义图片')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
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
                    .borderRadius(24)
                    .objectFit(ImageFit.Cover)
                    .border({
                      width: 2,
                      color: this.palette.primary
                    })
                } else {
                  Circle({ width: 48, height: 48 })
                    .fill(this.palette.bgSurface2)
                    .border({
                      width: this.avatarId === CUSTOM_AVATAR_ID ? 2 : 1,
                      color: this.avatarId === CUSTOM_AVATAR_ID ? this.palette.primary : this.palette.borderSubtle
                    })
                  Text('＋')
                    .fontSize(24)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.primary)
                    .fontWeight(FontWeight.Bold)
                }
              }
              Column({ space: 2 }) {
                Text('自定义图片')
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.avatarId === CUSTOM_AVATAR_ID ? this.palette.primary : this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                Text('从相册选择一张图片作为头像')
                  .fontSize(this.palette.fsSm - 1)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.avatarId === CUSTOM_AVATAR_ID ? this.palette.primary : this.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.avatarId === CUSTOM_AVATAR_ID) {
                Text('✓')
                  .fontSize(this.palette.fsMd)
                  .fontFamily(this.palette.fontSans)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.palette.primary)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .borderRadius(10)
            .backgroundColor(this.avatarId === CUSTOM_AVATAR_ID ?
              this.palette.primaryDim : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
            .onClick(() => { this.pickCustomAvatar(); })

            ForEach(AVATAR_OPTIONS, (option: AvatarOption) => {
              Row({ space: 12 }) {
                Stack() {
                  // 渐变底
                  Column()
                    .width(48)
                    .height(48)
                    .borderRadius(24)
                    .linearGradient({
                      angle: 135,
                      colors: [[option.colors[0], 0.0], [option.colors[1], 1.0]]
                    })
                    .border({
                      width: this.avatarId === option.id ? 2 : 1,
                      color: this.avatarId === option.id ? this.palette.primary : this.palette.borderSubtle
                    })
                  Text('Z')
                    .fontSize(20)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                Column({ space: 2 }) {
                  Text(option.label)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.avatarId === option.id ? this.palette.primary : this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                  Text(option.style)
                    .fontSize(this.palette.fsSm - 1)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.avatarId === option.id ? this.palette.primary : this.palette.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.avatarId === option.id) {
                  Text('✓')
                    .fontSize(this.palette.fsMd)
                    .fontFamily(this.palette.fontSans)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.palette.primary)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(10)
              .backgroundColor(this.avatarId === option.id ?
                this.palette.primaryDim : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
              .onClick(() => { this.pickAvatar(option.id); })
            }, (option: AvatarOption) => option.id)

            if (this.avatarId === CUSTOM_AVATAR_ID) {
              Text('恢复默认')
                .fontSize(this.palette.fsBase)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.danger)
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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textSecondary)
          .padding({ top: 12, bottom: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showAvatarSheet = false; })
      }
      .width('100%')
      .height('70%')
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

  // ---- 主密码弹窗 ----
  @Builder
  passwordSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showPasswordSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 12 }) {
        Row() {
          Blank()
          Text('✕')
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .padding(8)
            .onClick(() => { this.showPasswordSheet = false; })
        }
        .width('100%')
        .padding({ right: 4, top: 4 })

        Text(this.passwordMode === 'set' ? '设置主密码' :
          (this.passwordMode === 'change' ? '修改主密码' : '验证主密码'))
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text(this.passwordMode === 'verify' ? '请输入当前主密码以继续操作' :
          '设置后可用于解锁应用，至少 4 位')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .width('100%')

        TextInput({ text: this.passwordInput, placeholder: '请输入密码' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface)
          .borderRadius(8)
          .border({ width: 1, color: this.palette.borderSubtle })
          .height(44)
          .type(InputType.Password)
          .width('100%')
          .onChange((value: string) => { this.passwordInput = value; })

        if (this.passwordMode === 'set' || this.passwordMode === 'change') {
          TextInput({ text: this.passwordConfirm, placeholder: '请再次输入密码' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(44)
            .type(InputType.Password)
            .width('100%')
            .onChange((value: string) => { this.passwordConfirm = value; })
        }

        if (this.passwordError.length > 0) {
          Text(this.passwordError)
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.danger)
            .width('100%')
        }

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.palette.bgSurface2)
            .fontColor(this.palette.textPrimary)
            .borderRadius(8)
            .onClick(() => { this.showPasswordSheet = false; })
          Button(this.passwordBusy ? '处理中…' : '确认')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.palette.primary)
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .enabled(!this.passwordBusy)
            .onClick(() => { this.confirmPassword(); })
        }
        .width('100%')

        Text('主密码仅以加盐哈希保存在本机，无法找回，请妥善保管。')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.palette.bgBase)
      .borderRadius({ topLeft: 16, topRight: 16 })
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  // ---- 自动锁定选择弹窗 ----
  @Builder
  autoLockSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => { this.showAutoLockSheet = false; })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 底部面板
      Column({ space: 4 }) {
        Row() {
          Blank()
          Text('✕')
            .fontSize(this.palette.fsLg)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .padding(8)
            .onClick(() => { this.showAutoLockSheet = false; })
        }
        .width('100%')
        .padding({ right: 4, top: 4 })

        Text('自动锁定')
          .fontSize(this.palette.fsLg)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

        ForEach(AUTO_LOCK_OPTIONS, (value: number) => {
          Row() {
            Text(autoLockLabel(value))
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .layoutWeight(1)
            if (this.autoLock === autoLockLabel(value)) {
              Text('✓')
                .fontSize(this.palette.fsLg)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor(this.autoLock === autoLockLabel(value) ? this.palette.primaryDim : this.palette.bgSurface)
          .border({ width: this.autoLock === autoLockLabel(value) ? 1 : 0,
            color: this.autoLock === autoLockLabel(value) ? this.palette.primary : Color.Transparent })
          .onClick(() => { this.onAutoLockSelect(value); })
        }, (value: number) => value.toString())

        Text('开启后，应用切到后台超过设定时间将锁定，需主密码或生物识别解锁。')
          .fontSize(this.palette.fsXs)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .lineHeight(15)
          .width('100%')
          .padding({ left: 4, right: 4, top: 8 })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.palette.bgBase)
      .borderRadius({ topLeft: 16, topRight: 16 })
      .transition({ type: TransitionType.All, translate: { y: '100%' }, opacity: 0 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '设置', subtitle: '智子 v1.0.0', showBack: true, onBackTap: this.onBack }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            GroupCard({ title: '📰 资讯' }) {
              Column({ space: 8 }) {
                this.valueRow('资讯源开关设置', NEWS_SOURCES.length.toString() + ' 个源', () => {
                  AppNavigator.push('pages/NewsSourceSettings');
                })
                Text('关闭的源不再出现在资讯流中，支持全部打开/关闭。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')

                this.valueRow('个性化频道设置', '', () => {
                  AppNavigator.push('pages/NewsChannelSettings');
                })
                Text('默认全部频道启用个性化；关闭的频道恢复纯时间排序，支持全部打开/关闭。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })
                this.valueRow('个性化模式', this.modeLabel(this.newsPersonalizedMode), () => {
                  this.onNewsModePick();
                })
                Text('标准=混合排序｜高个性化=反馈权重更高｜仅热点=纯时间排序｜探索=更多新内容')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                this.valueRow('个性化画像（兴趣/厌恶管理）', '查看与调整', () => {
                  AppNavigator.push('pages/NewsProfile');
                })
                this.valueRow('重置推荐画像', '清空全部权重', () => {
                  NewsRepository.resetProfile().then(() => {
                    this.toast('已重置推荐画像');
                  });
                })

                Text('翻译模型')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 8 })
                Text('翻译默认使用资讯功能模型；可单独选择并记忆翻译模型。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                NewsModelSelector({
                  settingKey: 'newsTranslateModelId',
                  followLabel: '跟随资讯模型',
                  followDesc: '翻译默认使用资讯功能模型，可单独选择并记忆'
                })
                  .width(220)
                  .margin({ top: 4 })
                this.valueRow('清除翻译缓存', '', () => {
                  NewsRepository.clearTranslations().then(() => {
                    this.toast('已清除翻译缓存');
                  });
                })

                Text('AI 智能标签')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 8 })
                this.toggleRow('智能标签（LLM 精标）', this.newsTagLlmEnabled, (v: boolean) => {
                  this.onTagLlmToggle(v);
                })
                Text('开启后：将把新闻标题/摘要发送至你选择的模型服务商，用于生成更细标签；失败自动回退本地规则。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                NewsModelSelector({
                  settingKey: 'newsTagModelId',
                  followLabel: '跟随资讯模型',
                  followDesc: '智能标签默认使用资讯功能模型，可单独选择并记忆'
                })
                  .width(220)
                  .margin({ top: 4 })
                this.valueRow('清除标签缓存', '', () => {
                  NewsRepository.clearTags().then(() => {
                    this.toast('已清除标签缓存');
                  });
                })

                this.valueRow('AI 摘要 / 翻译 / 问 AI', '手动触发', () => {
                  this.toast('在新闻详情页手动触发，使用「我的 → AI 模型」配置的模型');
                })
                this.valueRow('AI 今日要闻 / 为你推荐', '', () => {
                  AppNavigator.push('pages/NewsRecommend');
                })
                Text('自定义 RSS 订阅')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 8 })
                TextInput({ placeholder: '订阅名称（如 我的博客）', text: this.customRssName })
                  .width('100%')
                  .height(38)
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .onChange((v: string) => { this.customRssName = v; })
                Row({ space: 8 }) {
                  TextInput({ placeholder: 'https://example.com/feed', text: this.customRssUrl })
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .onChange((v: string) => { this.customRssUrl = v; })
                  Button('添加')
                    .height(38)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(Color.White)
                    .backgroundColor(this.palette.primary)
                    .borderRadius(8)
                    .onClick(() => { this.addCustomRss(); })
                }
                .width('100%')
                if (this.customSources.length > 0) {
                  ForEach(this.customSources, (s: NewsSourceDef) => {
                    Row() {
                      Text('📡 ' + s.name)
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text('✕')
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textTertiary)
                        .padding(6)
                        .onClick(() => { this.removeCustomRss(s.url); })
                    }
                    .width('100%')
                    .padding({ left: 8, right: 8 })
                    .borderRadius(6)
                    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
                  }, (s: NewsSourceDef) => s.url)
                } else {
                  Text('暂无自定义订阅，添加后自动并入「推荐」频道。')
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textTertiary)
                    .width('100%')
                }
                this.valueRow('导入 OPML 订阅', '批量导入', () => {
                  this.showOpmlSheet = true;
                })
                this.valueRow('清空阅读记录', '', () => {
                  NewsRepository.clearRead().then(() => {
                    this.toast('已清空阅读记录');
                  });
                })
                this.valueRow('清空资讯缓存', '', () => {
                  NewsRepository.clearChannelCache().then(() => {
                    NewsRepository.clearArticleCache().then(() => {
                      NewsService.clearCache();
                      this.toast('已清空资讯缓存（频道快照与离线正文）');
                    });
                  });
                })
              }
              .width('100%')
            }

            // 游戏
            GroupCard({ title: '游戏' }) {
              Column({ space: 8 }) {
                this.valueRow('游戏设置', '音效等', () => {
                  AppNavigator.push('pages/GameSettings');
                })
              }
              .width('100%')
            }

            // 外观（新设计）
            GroupCard({ title: '外观' }) {
              Column({ space: 12 }) {
                // 颜色主题选择器
                Text('颜色主题')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.colorThemeSelector()

                // 深色模式
                Text('深色模式')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.darkModeSettings()

                // 背景图
                Text('背景图')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                this.backgroundSettings()

                // 毛玻璃效果
                Text('毛玻璃效果')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .margin({ top: 4 })
                Row() {
                  Text('启用毛玻璃效果')
                    .fontSize(this.palette.fsBase)
                    .fontFamily(this.palette.fontSans)
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
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })

                // 液态玻璃效果
                Text('液态玻璃效果')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .margin({ top: 12 })
                Row() {
                  Text('启用液态玻璃效果')
                    .fontSize(this.palette.fsBase)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textPrimary)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.liquidGlassEnabled })
                    .selectedColor(this.palette.primary)
                    .onChange((v: boolean) => {
                      this.updateLiquidGlassEffect(v);
                    })
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                .borderRadius(6)
                .backgroundColor(GlassStyle.innerBackgroundColor(this.liquidGlassEnabled, this.palette))
                Text('开启后界面呈现更通透的液态玻璃质感，与毛玻璃互斥。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })

                this.valueRow('字号', this.fontSizeLabel(this.fontSizeScale), () => {
                  this.openFontSizePicker();
                })
                this.valueRow('字体', this.fontFamily, () => {
                  this.openFontFamilyPicker();
                })
                this.valueRow('应用图标', this.appIconLabel(this.appIconId), () => {
                  this.openAppIconPicker();
                })
                this.valueRow('头像', this.avatarLabelText(), () => {
                  this.openAvatarPicker();
                })
              }
              .width('100%')
            }

            // Agent
            GroupCard({ title: 'Agent' }) {
              Column({ space: 8 }) {
                this.toggleRow('Agent 模式', this.agentEnabled, (v: boolean) => {
                  this.agentEnabled = v;
                  DataRepository.setSetting('agentEnabled', v ? 'true' : 'false');
                  this.toast(v ? '已开启 Agent 模式（对话中可调用计算器/时间/联网搜索）' : '已关闭 Agent 模式');
                })
                Text('开启后，AI 可主动调用工具分步完成任务；关闭后为纯文本对话。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .width('100%')
            }

            // 安全
            GroupCard({ title: '安全' }) {
              Column({ space: 8 }) {
                this.valueRow('主密码', this.hasMasterPassword ? '已设置' : '未设置', () => {
                  this.onMasterPasswordRow();
                })
                this.toggleRow('生物识别解锁', this.biometricUnlock, (v: boolean) => {
                  this.onBiometricToggle(v);
                })
                this.valueRow('自动锁定', this.autoLock, () => {
                  this.showAutoLockSheet = true;
                })
              }
              .width('100%')
            }

            // 数据
            GroupCard({ title: '数据' }) {
              Column({ space: 8 }) {
                this.valueRow('华为账号', this.huaweiNick.length > 0 ? this.huaweiNick : '未登录', () => {
                  if (this.huaweiNick.length > 0) {
                    this.onHuaweiSignOut();
                  } else {
                    this.onHuaweiSignIn();
                  }
                })
                this.valueRow('立即备份', this.cloudSyncLast, () => {
                  this.onCloudBackup();
                })
                this.valueRow('立即恢复', '', () => {
                  this.onCloudRestore();
                })
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

      // 字号/字体/应用图标选择弹层
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
      // 安全弹层
      if (this.showPasswordSheet) {
        this.passwordSheet()
      }
      if (this.showAutoLockSheet) {
        this.autoLockSheet()
      }
      // 资讯 OPML 导入弹层
      if (this.showOpmlSheet) {
        this.opmlSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}

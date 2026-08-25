// 智子 - 设置页面（分组索引版：账号云同步 / 外观 / 资讯 / 游戏 / Agent / 安全隐私 / 数据存储 / 关于）
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { DataRepository } from '../service/DataRepository';
import { GlassStyle } from '../components/GlassEffect';
import { SecurityService, autoLockLabel } from '../service/SecurityService';
import { BiometricHelper } from '../service/BiometricHelper';
import { HuaweiAccountService } from '../service/HuaweiAccountService';
import { CloudSyncService } from '../service/CloudSyncService';
import { AppNavigator } from '../common/AppNavigator';
import { AppConstants } from '../common/Constants';
import { LegalDocRouteParams } from '../common/Navigation';
import { NewsRepository } from '../service/NewsRepository';
import { NewsService } from '../service/NewsService';
import { TopBar } from '../components/TopBar';
import { SettingGroupCard } from '../components/SettingGroupCard';
import { SettingRowKind, SettingActionId, SettingItem, SettingGroup, settingMatches } from '../common/SettingModels';
import { SettingRow, SettingSwitchRow } from '../components/SettingRow';
import { PasswordSheet } from '../components/PasswordSheet';
import { AutoLockSheet } from '../components/AutoLockSheet';

@Component
export struct SettingsPage {
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  onBack: () => void = () => {};

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
  // 云同步
  @State huaweiNick: string = '';
  @State cloudSyncLast: string = '从未同步';
  @State syncBusy: boolean = false;
  // Agent
  @State agentEnabled: boolean = false;
  // 无痕模式（对话消息不落库）
  @State incognitoEnabled: boolean = false;
  // 设置搜索
  @State searchText: string = '';

  async aboutToAppear(): Promise<void> {
    this.loading = true;
    try {
      this.biometricUnlock = await SecurityService.isBiometricEnabled();
      const autoBackupVal = await DataRepository.getSetting('autoBackup', 'false');
      this.autoBackup = autoBackupVal === 'true';
      this.agentEnabled = await DataRepository.getSetting('agentEnabled', 'false') === 'true';
      this.incognitoEnabled = await DataRepository.getSetting('incognitoEnabled', 'false') === 'true';
      const profile = await HuaweiAccountService.getStoredProfile();
      this.huaweiNick = profile !== null ? profile.nickName : '';
      this.cloudSyncLast = await CloudSyncService.lastSyncLabel();
      this.hasMasterPassword = await SecurityService.hasPassword();
      this.autoLock = autoLockLabel(await SecurityService.getAutoLockValue());
    } finally {
      this.loading = false;
    }
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 危险操作统一确认（清空/重置等不可恢复操作）
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

  // 华为账号：未登录 → 登录；已登录 → 展示账号信息，退出需二次确认
  private onHuaweiAccountRow(): void {
    if (this.huaweiNick.length === 0) {
      this.onHuaweiSignIn();
      return;
    }
    promptAction.showDialog({
      title: '华为账号',
      message: '当前登录：' + this.huaweiNick + '\n云同步：' + this.cloudSyncLast +
        '\n\n退出后本地数据不会丢失，云同步需重新登录后继续。',
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '退出登录', color: '#E84026' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.onHuaweiSignOut();
      }
    }).catch(() => {
    });
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
      const appCtx: common.Context = ctx;
      // 先预览备份内容并校验，用户确认后才执行恢复
      const preview = await CloudSyncService.restorePreview(appCtx);
      if (!preview.ok) {
        this.toast(preview.message);
        return;
      }
      const checksumLine: string = !preview.hasChecksum ? '校验：旧备份未校验' :
        (preview.checksumOk ? '校验：通过 ✓' : '校验：失败 ✗');
      const summary: string =
        '备份内容（合并式恢复，不清空本地数据）：\n' +
        '· 会话 ' + preview.sessionCount + ' 个 / 消息 ' + preview.messageCount + ' 条\n' +
        '· 战绩 ' + preview.scoreCount + ' 条\n' +
        '· 成就 ' + preview.achievementCount + ' 项\n' +
        '· 设置 ' + preview.settingsCount + ' 项\n' +
        checksumLine + '\n\n' +
        '确认后将备份内容合并到本地，确定恢复？';
      AlertDialog.show({
        title: '恢复备份',
        message: summary,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '确认恢复',
          fontColor: Color.Red,
          action: () => {
            this.performRestore(appCtx);
          }
        }
      });
    } finally {
      this.syncBusy = false;
    }
  }

  // 用户确认后执行合并式恢复
  private async performRestore(ctx: common.Context): Promise<void> {
    this.syncBusy = true;
    try {
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

  // ==================== 数据驱动配置（渲染 + 搜索） ====================
  private visibleGroups(): SettingGroup[] {
    const keyword: string = this.searchText;
    const groups: SettingGroup[] = [];
    const accountItems: SettingItem[] = [];
    accountItems.push(new SettingItem('account', '华为账号', '👤',
      this.huaweiNick.length > 0 ? this.huaweiNick : '未登录', '',
      SettingRowKind.NAV, false, SettingActionId.ACCOUNT));
    accountItems.push(new SettingItem('autoBackup', '自动备份', '🔄', '',
      '开启后自动备份配置到华为云。', SettingRowKind.SWITCH, false, SettingActionId.AUTO_BACKUP));
    groups.push(new SettingGroup('account', '账号与云同步', accountItems));
    groups.push(new SettingGroup('appearance', '外观', [
      new SettingItem('appearance', '外观设置', '🎨', '主题 / 背景 / 字号 / 字体 / 头像',
        '颜色主题、深色模式、背景图、玻璃效果、字号、字体、应用图标与头像。',
        SettingRowKind.NAV, false, SettingActionId.APPEARANCE)
    ]));
    groups.push(new SettingGroup('news', '资讯', [
      new SettingItem('news', '资讯设置', '📰', '源 / 频道 / 个性化 / 模型 / RSS',
        '资讯源开关、频道个性化、推荐画像、翻译与智能标签模型、自定义 RSS。',
        SettingRowKind.NAV, false, SettingActionId.NEWS),
      new SettingItem('readingReport', '阅读周报', '📅', '近 7 天阅读画像',
        '本周阅读 / 收藏 / AI 调用统计与可视化图表。',
        SettingRowKind.NAV, false, SettingActionId.READING_REPORT)
    ]));
    groups.push(new SettingGroup('game', '游戏', [
      new SettingItem('game', '游戏设置', '🎮', '音效等', '',
        SettingRowKind.NAV, false, SettingActionId.GAME)
    ]));
    groups.push(new SettingGroup('agent', 'Agent', [
      new SettingItem('agent', 'Agent 模式', '🤖', '',
        '开启后，AI 可主动调用工具分步完成任务；关闭后为纯文本对话。',
        SettingRowKind.SWITCH, false, SettingActionId.AGENT),
      new SettingItem('aiRoles', 'AI 角色模板', '🎭', '8+ 角色可选',
        '内置角色库 + 自定义角色，一键应用到当前模型的系统提示词。',
        SettingRowKind.NAV, false, SettingActionId.AI_ROLES)
    ]));
    groups.push(new SettingGroup('bettafish', '微舆', [
      new SettingItem('bettaServer', '服务器配置', '🌐', '',
        'BettaFish 服务器地址（协议/域名/端口）多套配置管理与测试连接。',
        SettingRowKind.NAV, false, SettingActionId.BETTA_SERVER),
      new SettingItem('bettaSystem', '系统管理', '🖥', '',
        'BettaFish 系统启停、四引擎状态与运行日志。',
        SettingRowKind.NAV, false, SettingActionId.BETTA_SYSTEM)
    ]));
    groups.push(new SettingGroup('security', '安全与隐私', [
      new SettingItem('masterPassword', '主密码', '🔒',
        this.hasMasterPassword ? '已设置' : '未设置', '',
        SettingRowKind.NAV, false, SettingActionId.MASTER_PASSWORD),
      new SettingItem('biometric', '生物识别解锁', '🔐', '',
        '需先设置主密码，使用系统生物识别解锁应用。', SettingRowKind.SWITCH, false, SettingActionId.BIOMETRIC),
      new SettingItem('autoLock', '自动锁定', '🕐', this.autoLock, '',
        SettingRowKind.NAV, false, SettingActionId.AUTO_LOCK),
      new SettingItem('incognito', '无痕模式', '🕶️', '',
        '开启后，对话消息不会保存到本地数据库（会话仍保留）。', SettingRowKind.SWITCH, false, SettingActionId.NONE)
    ]));
    groups.push(new SettingGroup('storage', '数据与存储', [
      new SettingItem('clearRead', '清空阅读记录', '🗑', '',
        '删除全部已读记录，此操作不可恢复。', SettingRowKind.NAV, true, SettingActionId.CLEAR_READ),
      new SettingItem('clearCache', '清空资讯缓存', '🧹', '',
        '清除频道快照与离线正文，下次打开资讯时重新下载。', SettingRowKind.NAV, true, SettingActionId.CLEAR_CACHE)
    ]));
    groups.push(new SettingGroup('about', '关于', [
      new SettingItem('version', '版本', '', AppConstants.appVersion, '',
        SettingRowKind.NAV, false, SettingActionId.NONE, false),
      new SettingItem('update', '检查更新', '', '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_UPDATE),
      new SettingItem('agreement', '用户协议', '', '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_AGREEMENT),
      new SettingItem('privacy', '隐私政策', '', '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_PRIVACY),
      new SettingItem('license', '开源许可', '', '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_LICENSE),
      new SettingItem('feedback', '反馈', '', '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_FEEDBACK)
    ]));
    // 搜索过滤：仅保留含匹配项的分组
    const filtered: SettingGroup[] = [];
    for (let i: number = 0; i < groups.length; i++) {
      const kept: SettingItem[] = [];
      for (let j: number = 0; j < groups[i].items.length; j++) {
        if (settingMatches(groups[i].items[j], keyword)) {
          kept.push(groups[i].items[j]);
        }
      }
      if (kept.length > 0) {
        filtered.push(new SettingGroup(groups[i].key, groups[i].title, kept));
      }
    }
    return filtered;
  }

  private switchValue(key: string): boolean {
    if (key === 'autoBackup') return this.autoBackup;
    if (key === 'agent') return this.agentEnabled;
    if (key === 'biometric') return this.biometricUnlock;
    if (key === 'incognito') return this.incognitoEnabled;
    return false;
  }

  private onSwitch(key: string, v: boolean): void {
    if (key === 'autoBackup') {
      this.autoBackup = v;
      DataRepository.setSetting('autoBackup', v ? 'true' : 'false');
      this.toast(`自动备份：${v ? '已开启' : '已关闭'}`);
    } else if (key === 'agent') {
      this.agentEnabled = v;
      DataRepository.setSetting('agentEnabled', v ? 'true' : 'false');
      this.toast(v ? '已开启 Agent 模式（对话中可调用计算器/时间/联网搜索）' : '已关闭 Agent 模式');
    } else if (key === 'biometric') {
      this.onBiometricToggle(v);
    } else if (key === 'incognito') {
      this.incognitoEnabled = v;
      DataRepository.setSetting('incognitoEnabled', v ? 'true' : 'false');
      this.toast(v ? '已开启无痕模式：对话消息不会保存' : '已关闭无痕模式');
    }
  }

  private onAction(item: SettingItem): void {
    const action: SettingActionId = item.action;
    if (action === SettingActionId.ACCOUNT) {
      this.onHuaweiAccountRow();
    } else if (action === SettingActionId.APPEARANCE) {
      AppNavigator.push('pages/AppearanceSettings');
    } else if (action === SettingActionId.NEWS) {
      AppNavigator.push('pages/NewsSettings');
    } else if (action === SettingActionId.GAME) {
      AppNavigator.push('pages/GameSettings');
    } else if (action === SettingActionId.MASTER_PASSWORD) {
      this.onMasterPasswordRow();
    } else if (action === SettingActionId.AUTO_LOCK) {
      this.showAutoLockSheet = true;
    } else if (action === SettingActionId.CLEAR_READ) {
      this.confirmDanger('清空阅读记录', '将删除全部已读记录，此操作不可恢复。', () => {
        NewsRepository.clearRead().then(() => {
          this.toast('已清空阅读记录');
        });
      });
    } else if (action === SettingActionId.CLEAR_CACHE) {
      this.confirmDanger('清空资讯缓存', '将清除频道快照与离线正文，下次打开资讯时重新下载。', () => {
        NewsRepository.clearChannelCache().then(() => {
          NewsRepository.clearArticleCache().then(() => {
            NewsService.clearCache();
            this.toast('已清空资讯缓存（频道快照与离线正文）');
          });
        });
      });
    } else if (action === SettingActionId.ABOUT_UPDATE) {
      promptAction.showToast({ message: '已是最新版本' });
    } else if (action === SettingActionId.ABOUT_AGREEMENT) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('agreement'));
    } else if (action === SettingActionId.ABOUT_PRIVACY) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('privacy'));
    } else if (action === SettingActionId.ABOUT_LICENSE) {
      AppNavigator.push('pages/LegalDoc', new LegalDocRouteParams('license'));
    } else if (action === SettingActionId.ABOUT_FEEDBACK) {
      promptAction.showToast({ message: '反馈功能即将上线' });
    } else if (action === SettingActionId.READING_REPORT) {
      AppNavigator.push('pages/ReadingReport');
    } else if (action === SettingActionId.AI_ROLES) {
      AppNavigator.push('pages/AiRoleLibrary');
    } else if (action === SettingActionId.BETTA_SERVER) {
      AppNavigator.push('pages/BettaFishServerConfig');
    } else if (action === SettingActionId.BETTA_SYSTEM) {
      AppNavigator.push('pages/BettaFishSystem');
    }
  }

  // 账号组特殊行（备份/恢复）是否显示：搜索时按关键词过滤
  private showAccountActions(): boolean {
    const kw: string = this.searchText.trim();
    return kw.length === 0 || kw.indexOf('备份') >= 0 || kw.indexOf('恢复') >= 0;
  }

  @Builder actionsBuilder() {}



  build() {
    Stack() {
      Column() {
        TopBar({ title: '设置', subtitle: AppConstants.appName + ' v' + AppConstants.appVersion, showBack: true, onBackTap: this.onBack }) {
          this.actionsBuilder()
        }
        // 搜索框
        Row({ space: 8 }) {
          Text('🔍')
            .fontSize(14)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
          TextInput({ placeholder: '搜索设置项', text: this.searchText })
            .layoutWeight(1)
            .height(36)
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface2)
            .borderRadius(18)
            .onChange((v: string) => { this.searchText = v; })
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: 4 })

        if (this.visibleGroups().length === 0) {
          Column() {
            Text('未找到相关设置项，换个关键词试试')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          .width('100%')
          .padding({ top: 60 })
        } else {
          List({ space: 16 }) {
            ForEach(this.visibleGroups(), (group: SettingGroup) => {
              ListItem() {
                SettingGroupCard({ title: group.title }) {
                  Column({ space: 8 }) {
                    ForEach(group.items, (item: SettingItem) => {
                      if (item.kind === SettingRowKind.SWITCH) {
                        SettingSwitchRow({
                          icon: item.icon,
                          title: item.title,
                          desc: item.desc,
                          isOn: this.switchValue(item.key),
                          onSwitchChange: (v: boolean) => {
                            this.onSwitch(item.key, v);
                          }
                        })
                      } else {
                        SettingRow({
                          icon: item.icon,
                          title: item.title,
                          value: item.value,
                          desc: item.desc,
                          showArrow: item.showArrow,
                          danger: item.danger,
                          rowClick: () => {
                            this.onAction(item);
                          }
                        })
                      }
                    }, (item: SettingItem) => item.key)
                    // 账号组特殊行：立即备份/立即恢复（搜索时按关键词过滤）
                    if (group.key === 'account' && this.showAccountActions()) {
                        Row({ space: 12 }) {
                          Text('☁')
                            .fontSize(16)
                            .fontFamily(this.palette.fontSans)
                            .width(32)
                            .height(32)
                            .textAlign(TextAlign.Center)
                            .borderRadius(10)
                            .backgroundColor(this.palette.primaryDim)
                          Text('立即备份')
                            .fontSize(this.palette.fsBase)
                            .fontFamily(this.palette.fontSans)
                            .fontColor(this.palette.textPrimary)
                            .layoutWeight(1)
                          if (this.syncBusy) {
                            LoadingProgress()
                              .width(18)
                              .height(18)
                          } else {
                            Text(this.cloudSyncLast)
                              .fontSize(this.palette.fsSm)
                              .fontFamily(this.palette.fontSans)
                              .fontColor(this.palette.textTertiary)
                              .margin({ right: 6 })
                            Text('›')
                              .fontSize(this.palette.fsMd)
                              .fontFamily(this.palette.fontSans)
                              .fontColor(this.palette.textTertiary)
                          }
                        }
                        .width('100%')
                        .height(48)
                        .padding({ left: 12, right: 12 })
                        .borderRadius(8)
                        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
                        .onClick(() => {
                          if (!this.syncBusy) {
                            this.onCloudBackup();
                          }
                        })
                        .stateStyles({
                          pressed: {
                            .backgroundColor(this.palette.bgHover)
                          }
                        })
                        .accessibilityText('立即备份' + (this.syncBusy ? '，同步中' : this.cloudSyncLast.length > 0 ? '，' + this.cloudSyncLast : ''))
                        Row({ space: 12 }) {
                          Text('↺')
                            .fontSize(16)
                            .fontFamily(this.palette.fontSans)
                            .width(32)
                            .height(32)
                            .textAlign(TextAlign.Center)
                            .borderRadius(10)
                            .backgroundColor(this.palette.primaryDim)
                          Text('立即恢复')
                            .fontSize(this.palette.fsBase)
                            .fontFamily(this.palette.fontSans)
                            .fontColor(this.palette.textPrimary)
                            .layoutWeight(1)
                          if (this.syncBusy) {
                            LoadingProgress()
                              .width(18)
                              .height(18)
                          } else {
                            Text('›')
                              .fontSize(this.palette.fsMd)
                              .fontFamily(this.palette.fontSans)
                              .fontColor(this.palette.textTertiary)
                          }
                        }
                        .width('100%')
                        .height(48)
                        .padding({ left: 12, right: 12 })
                        .borderRadius(8)
                        .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
                        .onClick(() => {
                          if (!this.syncBusy) {
                            this.onCloudRestore();
                          }
                        })
                        .stateStyles({
                          pressed: {
                            .backgroundColor(this.palette.bgHover)
                          }
                        })
                        .accessibilityText('立即恢复' + (this.syncBusy ? '，同步中' : ''))
                    }
                  }
                  .width('100%')
                }
              }
            }, (group: SettingGroup) => group.key)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .layoutWeight(1)
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12, bottom: 16 })
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      // 安全弹层（组件化）
      if (this.showPasswordSheet) {
        PasswordSheet({
          mode: this.passwordMode,
          busy: this.passwordBusy,
          error: this.passwordError,
          input: this.passwordInput,
          confirm: this.passwordConfirm,
          onCancel: () => { this.showPasswordSheet = false; },
          onInputChange: (v: string) => { this.passwordInput = v; },
          onConfirmChange: (v: string) => { this.passwordConfirm = v; },
          onConfirmTap: () => { this.confirmPassword(); }
        })
      }
      if (this.showAutoLockSheet) {
        AutoLockSheet({
          currentLabel: this.autoLock,
          onCancel: () => { this.showAutoLockSheet = false; },
          onOptionSelect: (value: number) => { this.onAutoLockSelect(value); }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
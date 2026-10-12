// 智子 - 设置页面（v10 华为原生拟物白 · 分组索引版）
// 分组：账号与云同步 / 外观 / 热榜 / 游戏 / Agent / 微舆 / 安全与隐私 / 关于。
// 边界归位（§3.4.4 + §3.5）：
//  · 账号置顶，账号与云同步（含备份/恢复）留在本页；
//  · 数据操作（清空阅读记录 / 清空热榜缓存）收敛到「热榜设置 → 数据」，本页不再重复；
//  · 阅读周报主入口收敛到「我的 → 阅读周报」，本页不再重复；
//  · AI 角色模板主入口收敛到「我的 → AI 角色模板」，Agent 组只留模式开关。
// P4（V2 状态迁移）：V1 状态装饰器全部改 V2（ComponentV2 / Local / Event），
// 主题色与窗口断点改由 ThemeState（AppStorageV2）提供；公开属性名 onBack 保持不变。
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ThemeState } from '../common/ThemeState';
import { DataRepository } from '../service/platform/DataRepository';
import { SecurityService, autoLockLabel } from '../service/platform/SecurityService';
import { BiometricHelper } from '../service/platform/BiometricHelper';
import { HuaweiAccountService } from '../service/platform/HuaweiAccountService';
import { CloudSyncService } from '../service/platform/CloudSyncService';
import { AppNavigator } from '../common/AppNavigator';
import { AppConstants } from '../common/Constants';
import { LegalDocRouteParams } from '../common/Navigation';
import { TopBar } from '../components/TopBar';
import { SettingRow } from '../components/SettingRow';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';
import { SettingRowKind, SettingActionId, SettingItem, SettingGroup, settingMatches } from '../common/SettingModels';
import { PasswordSheet } from '../components/PasswordSheet';
import { AutoLockSheet } from '../components/AutoLockSheet';

@ComponentV2
export struct SettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Event onBack: () => void = () => {};

  // 安全
  @Local biometricUnlock: boolean = false;
  @Local autoLock: string = '关闭';
  @Local hasMasterPassword: boolean = false;
  // 主密码弹窗
  @Local showPasswordSheet: boolean = false;
  @Local passwordInput: string = '';
  @Local passwordConfirm: string = '';
  @Local passwordMode: string = 'set'; // set / change / clear / verify
  @Local passwordError: string = '';
  @Local passwordBusy: boolean = false;
  // 自动锁定选择弹窗
  @Local showAutoLockSheet: boolean = false;
  // 数据
  @Local autoBackup: boolean = false;
  // 云同步
  @Local huaweiNick: string = '';
  @Local cloudSyncLast: string = '从未同步';
  @Local syncBusy: boolean = false;
  // Agent
  @Local agentEnabled: boolean = false;
  // 无痕模式（对话消息不落库）
  @Local incognitoEnabled: boolean = false;
  // 设置搜索
  @Local searchText: string = '';

  async aboutToAppear(): Promise<void> {
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
    } catch (e) {
      // 读取失败时保留默认值（开关回落为关闭态）
    }
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
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
    groups.push(new SettingGroup('account', '账号与云同步', [
      new SettingItem('account', '华为账号', AppIcons.navProfile, AppIcons.navProfileEmoji,
        this.huaweiNick.length > 0 ? this.huaweiNick : '未登录', '',
        SettingRowKind.NAV, false, SettingActionId.ACCOUNT),
      new SettingItem('autoBackup', '自动备份', AppIcons.refresh, AppIcons.refreshEmoji, '',
        '开启后自动备份配置到华为云。', SettingRowKind.SWITCH, false, SettingActionId.AUTO_BACKUP),
      new SettingItem('backupNow', '立即备份', AppIcons.upload, AppIcons.uploadEmoji,
        this.syncBusy ? '同步中…' : this.cloudSyncLast, '上传本地数据到华为云。',
        SettingRowKind.NAV, false, SettingActionId.BACKUP_NOW),
      new SettingItem('restoreNow', '立即恢复', AppIcons.download, AppIcons.downloadEmoji, '',
        '从华为云合并式恢复，不清空本地数据。', SettingRowKind.NAV, false, SettingActionId.RESTORE_NOW)
    ]));
    groups.push(new SettingGroup('appearance', '外观', [
      new SettingItem('appearance', '外观设置', AppIcons.photo, AppIcons.photoEmoji,
        '主题 / 背景 / 字号 / 字体 / 头像',
        '颜色主题、深色模式、背景图、玻璃效果、字号、字体、应用图标与头像。',
        SettingRowKind.NAV, false, SettingActionId.APPEARANCE)
    ]));
    // 热榜：只保留「热榜设置」（数据操作已收在本页二级页的「数据」分组）
    groups.push(new SettingGroup('news', '热榜', [
      new SettingItem('news', '热榜设置', AppIcons.navHot, AppIcons.navHotEmoji,
        '服务器 / 账号 / 关注 / 数据',
        'NewsNow 服务器地址、GitHub 登录与关注同步、数据清理。',
        SettingRowKind.NAV, false, SettingActionId.NEWS)
    ]));
    groups.push(new SettingGroup('game', '游戏', [
      new SettingItem('game', '游戏设置', AppIcons.navGame, AppIcons.navGameEmoji, '音效等', '',
        SettingRowKind.NAV, false, SettingActionId.GAME)
    ]));
    groups.push(new SettingGroup('agent', 'Agent', [
      new SettingItem('agent', 'Agent 模式', AppIcons.navChat, AppIcons.navChatEmoji, '',
        '开启后，AI 可主动调用工具分步完成任务；关闭后为纯文本对话。',
        SettingRowKind.SWITCH, false, SettingActionId.AGENT)
    ]));
    groups.push(new SettingGroup('bettafish', '微舆', [
      new SettingItem('bettaServer', '服务器配置', AppIcons.server, AppIcons.serverEmoji, '',
        'BettaFish 服务器地址（协议/域名/端口）多套配置管理与测试连接。',
        SettingRowKind.NAV, false, SettingActionId.BETTA_SERVER),
      new SettingItem('bettaSystem', '系统管理', AppIcons.chart, AppIcons.chartEmoji, '',
        'BettaFish 系统启停、四引擎状态与运行日志。',
        SettingRowKind.NAV, false, SettingActionId.BETTA_SYSTEM)
    ]));
    groups.push(new SettingGroup('security', '安全与隐私', [
      new SettingItem('masterPassword', '主密码', AppIcons.lock, AppIcons.lockEmoji,
        this.hasMasterPassword ? '已设置' : '未设置', '',
        SettingRowKind.NAV, false, SettingActionId.MASTER_PASSWORD),
      new SettingItem('biometric', '生物识别解锁', AppIcons.check, AppIcons.checkEmoji, '',
        '需先设置主密码，使用系统生物识别解锁应用。', SettingRowKind.SWITCH, false, SettingActionId.BIOMETRIC),
      new SettingItem('autoLock', '自动锁定', AppIcons.clock, AppIcons.clockEmoji, this.autoLock, '',
        SettingRowKind.NAV, false, SettingActionId.AUTO_LOCK),
      new SettingItem('incognito', '无痕模式', AppIcons.close, AppIcons.closeEmoji, '',
        '开启后，对话消息不会保存到本地数据库（会话仍保留）。', SettingRowKind.SWITCH, false, SettingActionId.NONE)
    ]));
    groups.push(new SettingGroup('about', '关于', [
      new SettingItem('version', '版本', AppIcons.doc, AppIcons.docEmoji, AppConstants.appVersion, '',
        SettingRowKind.NAV, false, SettingActionId.NONE, false),
      new SettingItem('update', '检查更新', AppIcons.refresh, AppIcons.refreshEmoji, '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_UPDATE),
      new SettingItem('agreement', '用户协议', AppIcons.bookmark, AppIcons.bookmarkEmoji, '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_AGREEMENT),
      new SettingItem('privacy', '隐私政策', AppIcons.lock, AppIcons.lockEmoji, '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_PRIVACY),
      new SettingItem('license', '开源许可', AppIcons.link, AppIcons.linkEmoji, '', '',
        SettingRowKind.NAV, false, SettingActionId.ABOUT_LICENSE),
      new SettingItem('feedback', '反馈', AppIcons.more, AppIcons.moreEmoji, '', '',
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

  // ForEach 键值包含行内动态内容（账号名 / 备份时间 / 开关态 / 搜索命中数），
  // 避免「键值不变则不更新子节点」导致分组卡显示陈旧值。
  private groupKey(group: SettingGroup): string {
    let key: string = group.key;
    for (let i: number = 0; i < group.items.length; i++) {
      const item: SettingItem = group.items[i];
      key += '|' + item.key + '=' + item.value;
      if (item.kind === SettingRowKind.SWITCH) {
        key += '=' + (this.switchValue(item.key) ? '1' : '0');
      }
    }
    return key;
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
    } else if (action === SettingActionId.BACKUP_NOW) {
      if (!this.syncBusy) {
        this.onCloudBackup();
      }
    } else if (action === SettingActionId.RESTORE_NOW) {
      if (!this.syncBusy) {
        this.onCloudRestore();
      }
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
    } else if (action === SettingActionId.BETTA_SERVER) {
      AppNavigator.push('pages/BettaFishServerConfig');
    } else if (action === SettingActionId.BETTA_SYSTEM) {
      AppNavigator.push('pages/BettaFishSystem');
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
    }
  }

  @Builder actionsBuilder() {}

  build() {
    Stack() {
      Column() {
        TopBar({ title: '设置', subtitle: AppConstants.appName + ' v' + AppConstants.appVersion, showBack: true,
          onBackTap: (): void => { this.onBack(); } }) {
          this.actionsBuilder()
        }
        // 搜索框（胶囊 + 矢量图标）
        Row() {
          Row({ space: this.themeState.palette.sp2 }) {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.search)
                .fontSize(18)
                .fontColor([this.themeState.palette.textTertiary])
                .accessibilityLevel('no')
            } else {
              Text(AppIcons.searchEmoji)
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
            TextInput({ placeholder: '搜索设置项', text: this.searchText })
              .layoutWeight(1)
              .height(40)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .placeholderColor(this.themeState.palette.textTertiary)
              .backgroundColor(Color.Transparent)
              .onChange((v: string) => {
                this.searchText = v;
              })
          }
          .width('100%')
          .height(40)
          .padding({ left: this.themeState.palette.sp3, right: this.themeState.palette.sp3 })
          .borderRadius(this.themeState.palette.radiusCapsule)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({
          left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
          top: this.themeState.palette.sp2,
          bottom: this.themeState.palette.sp1
        })

        if (this.visibleGroups().length === 0) {
          // 空态：说明原因 + 下一步
          Column({ space: this.themeState.palette.sp2 }) {
            Text('没有找到相关设置项')
              .fontSize(this.themeState.palette.fsMd)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
            Text('换个关键词，或清空搜索框浏览全部分组')
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ top: 64, left: this.themeState.palette.pagePadding, right: this.themeState.palette.pagePadding })
          .alignItems(HorizontalAlign.Center)
        } else {
          List({ space: this.themeState.palette.sectionGap }) {
            ForEach(this.visibleGroups(), (group: SettingGroup) => {
              ListItem() {
                Column({ space: this.themeState.palette.sp2 }) {
                  Text(group.title)
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .width('100%')
                    .textAlign(TextAlign.Start)
                  Column({ space: 0 }) {
                    ForEach(group.items, (item: SettingItem, index: number) => {
                      SettingRow({
                        title: item.title,
                        desc: item.desc,
                        value: item.value,
                        danger: item.danger,
                        showArrow: item.showArrow,
                        showDivider: index < group.items.length - 1,
                        useSymbol: true,
                        symbol: item.symbol,
                        icon: item.icon,
                        isSwitch: item.kind === SettingRowKind.SWITCH,
                        switchValue: this.switchValue(item.key),
                        rowClick: (): void => { this.onAction(item); },
                        onSwitchChange: (v: boolean): void => { this.onSwitch(item.key, v); }
                      })
                    }, (item: SettingItem) => item.key)
                  }
                  .width('100%')
                  .padding({ left: this.themeState.palette.sp4, right: this.themeState.palette.sp4 })
                  .borderRadius(this.themeState.palette.radiusLg)
                  .backgroundColor(this.themeState.palette.bgSurface)
                  .border({ width: 0.5, color: this.themeState.palette.divider })
                  .clip(true)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (group: SettingGroup) => this.groupKey(group))
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .layoutWeight(1)
          .padding({
            left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
            top: this.themeState.palette.sp3,
            bottom: this.themeState.palette.sp6
          })
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.bgBase)

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

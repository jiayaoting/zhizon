// 智子 - AI 角色模板库（内置角色 + 自定义角色，一键应用到当前模型）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { AiRoleTemplate, BUILTIN_ROLE_TEMPLATES, loadCustom, saveCustom } from '../common/RoleTemplates';
import { ChatRepository } from '../service/ChatRepository';

@ComponentV2
@Entry
export struct AiRoleLibraryPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local builtinRoles: AiRoleTemplate[] = BUILTIN_ROLE_TEMPLATES;
  @Local customRoles: AiRoleTemplate[] = [];
  @Local loading: boolean = true;
  @Local applyingId: string = '';
  @Local showCreateDialog: boolean = false;
  @Local newRoleName: string = '';
  @Local newRolePrompt: string = '';

  aboutToAppear(): void {
    this.loadCustomRoles();
  }

  private async loadCustomRoles(): Promise<void> {
    try {
      this.customRoles = await loadCustom();
    } catch (e) {
      this.customRoles = [];
    }
    this.loading = false;
  }

  // 应用角色：把 system prompt 写入当前激活模型
  private async applyRole(role: AiRoleTemplate): Promise<void> {
    if (this.applyingId.length > 0) return;
    this.applyingId = role.id;
    try {
      const id: string = await ChatRepository.loadActiveModelId();
      const ok: boolean = await ChatRepository.updateModelSystemPrompt(id, role.prompt);
      if (ok) {
        promptAction.showToast({ message: '已应用角色：' + role.name });
      } else {
        promptAction.showToast({ message: '应用失败：请先在 AI 模型页配置模型' });
      }
    } catch (e) {
      promptAction.showToast({ message: '应用失败：请先在 AI 模型页配置模型' });
    }
    this.applyingId = '';
  }

  private openCreateDialog(): void {
    this.newRoleName = '';
    this.newRolePrompt = '';
    this.showCreateDialog = true;
  }

  private closeCreateDialog(): void {
    this.showCreateDialog = false;
  }

  private async createCustomRole(): Promise<void> {
    const name: string = this.newRoleName.trim();
    const prompt: string = this.newRolePrompt.trim();
    if (name.length === 0 || prompt.length === 0) {
      promptAction.showToast({ message: '请填写角色名称与提示词' });
      return;
    }
    const role: AiRoleTemplate = new AiRoleTemplate(
      'role-custom-' + Date.now().toString(36), name, '🧩', '自定义角色', prompt, false);
    const added: AiRoleTemplate[] = [role];
    const list: AiRoleTemplate[] = this.customRoles.concat(added);
    try {
      await saveCustom(list);
      this.customRoles = list;
      this.showCreateDialog = false;
      promptAction.showToast({ message: '已保存角色：' + name });
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  private async removeCustomRole(role: AiRoleTemplate): Promise<void> {
    AlertDialog.show({
      title: '删除角色',
      message: '确定要删除「' + role.name + '」吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          const list: AiRoleTemplate[] = [];
          for (let i: number = 0; i < this.customRoles.length; i++) {
            if (this.customRoles[i].id !== role.id) list.push(this.customRoles[i]);
          }
          try {
            await saveCustom(list);
            this.customRoles = list;
            promptAction.showToast({ message: '已删除角色：' + role.name });
          } catch (e) {
            promptAction.showToast({ message: '删除失败，请重试' });
          }
        }
      }
    });
  }

  @Builder
  sectionHeader(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text(count.toString() + ' 个')
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 2, top: 4 })
  }

  @Builder
  roleCard(role: AiRoleTemplate, isCustom: boolean) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(role.icon)
          .fontSize(20)
          .fontFamily(this.themeState.palette.fontSans)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .borderRadius(10)
          .backgroundColor(this.themeState.palette.primaryDim)
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(role.name)
              .fontSize(this.themeState.palette.fsBase)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (!role.builtin) {
              Text('自定义')
                .fontSize(10)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.primary)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
                .backgroundColor(this.themeState.palette.primaryDim)
            }
          }
          .width('100%')
          Text(role.description)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // prompt 预览：截断 3 行
      Text(role.prompt)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        if (isCustom) {
          Button('删除')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
            .backgroundColor(Color.Transparent)
            .borderRadius(14)
            .height(30)
            .onClick(() => { this.removeCustomRole(role); })
        }
        Button(this.applyingId === role.id ? '应用中…' : '应用')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(14)
          .height(30)
          .enabled(this.applyingId.length === 0)
          .onClick(() => { this.applyRole(role); })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  // 新建角色弹层：两个 TextInput（名称 + 提示词）+ 确认 / 取消
  @Builder
  createDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick(() => { this.closeCreateDialog(); })

      Column({ space: 14 }) {
        Text('新建角色')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Center)

        TextInput({ text: this.newRoleName, placeholder: '角色名称，如：面试官' })
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .placeholderColor(this.themeState.palette.textTertiary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(8)
          .border({ width: 1, color: this.themeState.palette.borderSubtle })
          .height(40)
          .width('100%')
          .onChange((value: string) => { this.newRoleName = value; })

        TextInput({ text: this.newRolePrompt, placeholder: '角色提示词（system prompt）' })
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .placeholderColor(this.themeState.palette.textTertiary)
          .backgroundColor(this.themeState.palette.bgSurface2)
          .borderRadius(8)
          .border({ width: 1, color: this.themeState.palette.borderSubtle })
          .height(40)
          .width('100%')
          .onChange((value: string) => { this.newRolePrompt = value; })

        Row({ space: 10 }) {
          Button('取消')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
            .backgroundColor(this.themeState.palette.bgSurface2)
            .borderRadius(14)
            .height(36)
            .layoutWeight(1)
            .onClick(() => { this.closeCreateDialog(); })
          Button('确认')
            .fontSize(this.themeState.palette.fsSm)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.themeState.palette.primary)
            .borderRadius(14)
            .height(36)
            .layoutWeight(1)
            .onClick(() => { this.createCustomRole(); })
        }
        .width('100%')
      }
      .width('86%')
      .constraintSize({ maxWidth: 360 })
      .padding(18)
      .borderRadius(16)
      .backgroundColor(this.themeState.palette.bgSurface)
      .border({ width: 1, color: this.themeState.palette.borderSubtle })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: 'AI 角色模板', subtitle: '一键应用到当前模型', showBack: true })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              this.sectionHeader('内置角色', this.builtinRoles.length)
              ForEach(this.builtinRoles, (role: AiRoleTemplate) => {
                this.roleCard(role, false)
              }, (role: AiRoleTemplate) => role.id)

              Column().height(4)

              this.sectionHeader('我的自定义', this.customRoles.length)
              if (this.customRoles.length === 0) {
                Column({ space: 6 }) {
                  Text('🧩')
                    .fontSize(28)
                    .fontFamily(this.themeState.palette.fontSans)
                  Text('还没有自定义角色，点击下方按钮创建')
                    .fontSize(this.themeState.palette.fsSm)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                }
                .width('100%')
                .padding(20)
                .borderRadius(12)
                .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
                .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
              } else {
                ForEach(this.customRoles, (role: AiRoleTemplate) => {
                  this.roleCard(role, true)
                }, (role: AiRoleTemplate) => role.id)
              }

              Row() {
                Text('＋ 新建角色')
                  .fontSize(this.themeState.palette.fsMd)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .height(44)
              .borderRadius(12)
              .backgroundColor(this.themeState.palette.primary)
              .justifyContent(FlexAlign.Center)
              .onClick(() => { this.openCreateDialog(); })

              Column().height(20)
            }
            .width('100%')
            .constraintSize({ maxWidth: 720 })
            .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeState.palette.bgBase)

      if (this.showCreateDialog) {
        this.createDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}

// 智子 - AI 对话配置页（多模型管理：列表 + 编辑）
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { ChatRepository } from '../service/ChatRepository';
import { LlmClient } from '../service/LlmClient';
import { API_FORMAT_LABELS, ApiFormat, LLM_PROVIDER_TEMPLATES, LlmConfig, LlmModelEntry,
  LlmProviderTemplate, LlmResult, modelDisplayName, providerTemplateById } from '../common/LlmModels';

@Entry
@Component
struct ChatConfig {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  // 模型列表
  @State models: LlmModelEntry[] = [];
  @State editing: boolean = false;
  @State editingIndex: number = -1;
  // 当前激活模型 id（用于列表高亮）
  @State activeModelId: string = '';

  // 编辑表单
  @State displayName: string = '';
  @State providerId: string = 'deepseek';
  @State baseUrl: string = '';
  @State apiKey: string = '';
  @State model: string = '';
  @State temperature: number = 0.7;
  @State apiFormat: ApiFormat = 'openai';
  @State maxTokens: number = 4096;
  @State showKey: boolean = false;
  @State testing: boolean = false;
  @State showProviderSheet: boolean = false;
  @State showModelSheet: boolean = false;
  @State showFormatSheet: boolean = false;
  @State tempText: string = '0.7';
  @State maxTokensText: string = '4096';
  @State customModelInput: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.models = await ChatRepository.loadModels();
    this.activeModelId = await ChatRepository.loadActiveModelId();
  }

  // ---- 列表操作 ----

  private async addModel(): Promise<void> {
    this.editingIndex = -1;
    this.resetForm();
    this.editing = true;
  }

  private editModel(index: number): void {
    const m: LlmModelEntry = this.models[index];
    this.editingIndex = index;
    this.displayName = m.displayName;
    // 保留原 providerId，不强制兜底为 deepseek，避免覆盖用户自定义配置
    this.providerId = m.providerId && m.providerId.length > 0 ? m.providerId : 'custom';
    this.baseUrl = m.baseUrl;
    this.apiKey = m.apiKey;
    this.model = m.model;
    this.temperature = m.temperature;
    this.apiFormat = m.apiFormat || 'openai';
    this.maxTokens = m.maxTokens || 4096;
    this.tempText = this.temperature.toFixed(1);
    this.maxTokensText = this.maxTokens.toString();
    this.editing = true;
  }

  private backToList(): void {
    this.editing = false;
    this.load();
  }

  private async removeModel(index: number): Promise<void> {
    const m: LlmModelEntry = this.models[index];
    AlertDialog.show({
      title: '删除模型',
      message: '确定要删除「' + modelDisplayName(m) + '」吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => {
          ChatRepository.deleteModel(m.id);
          this.load();
        }
      }
    });
  }

  private async activateModel(index: number): Promise<void> {
    const m: LlmModelEntry = this.models[index];
    await ChatRepository.setActiveModelId(m.id);
    this.activeModelId = m.id;
    promptAction.showToast({ message: '已切换为「' + modelDisplayName(m) + '」' });
  }

  private resetForm(): void {
    this.displayName = '';
    this.providerId = 'deepseek';
    this.baseUrl = '';
    this.apiKey = '';
    this.model = '';
    this.temperature = 0.7;
    this.apiFormat = 'openai';
    this.maxTokens = 4096;
    this.tempText = '0.7';
    this.maxTokensText = '4096';
  }

  // ---- 表单辅助 ----

  private applyTemplate(template: LlmProviderTemplate): void {
    this.providerId = template.id;
    this.baseUrl = template.baseUrl;
    this.model = template.defaultModel;
    this.apiFormat = template.apiFormat;
    this.showProviderSheet = false;
  }

  private providerLabel(): string {
    const template: LlmProviderTemplate | null = providerTemplateById(this.providerId);
    return template !== null ? template.name : '自定义';
  }

  private formatLabel(): string {
    const label: string = API_FORMAT_LABELS[this.apiFormat];
    return label !== undefined ? label : 'OpenAI Chat Completions';
  }

  private isLocalProvider(): boolean {
    const template: LlmProviderTemplate | null = providerTemplateById(this.providerId);
    return template !== null && template.isLocal;
  }

  private isCustomProvider(): boolean {
    return this.providerId === 'custom';
  }

  private modelOptions(): string[] {
    const template: LlmProviderTemplate | null = providerTemplateById(this.providerId);
    const options: string[] = [];
    if (template !== null) {
      for (let i: number = 0; i < template.models.length; i++) {
        options.push(template.models[i]);
      }
    }
    // 已手动填入的模型不在模板列表时，追加展示，保证可回选
    const cur: string = this.model.trim();
    if (cur.length > 0 && options.indexOf(cur) === -1) {
      options.push(cur);
    }
    if (options.length === 0) {
      options.push('自定义模型');
    }
    return options;
  }

  private applyCustomModel(): void {
    const value: string = this.customModelInput.trim();
    if (value.length === 0) return;
    this.model = value;
    this.customModelInput = '';
    this.showModelSheet = false;
  }

  private fillConfig(config: LlmConfig): void {
    config.providerId = this.providerId;
    config.baseUrl = this.baseUrl.trim();
    config.apiKey = this.apiKey.trim();
    config.model = this.model.trim();
    config.temperature = this.temperature;
    config.apiFormat = this.apiFormat;
    config.maxTokens = this.maxTokens;
  }

  private async save(): Promise<void> {
    const config: LlmConfig = new LlmConfig();
    this.fillConfig(config);
    if (!config.baseUrl) {
      promptAction.showToast({ message: '请填写接口地址' });
      return;
    }
    if (config.needsKey && !config.apiKey) {
      promptAction.showToast({ message: '请填写 API Key' });
      return;
    }
    if (!config.model) {
      promptAction.showToast({ message: '请填写模型名称' });
      return;
    }
    if (config.apiFormat === 'anthropic' && config.maxTokens <= 0) {
      promptAction.showToast({ message: '请填写有效的 max_tokens' });
      return;
    }
    const entry = new LlmModelEntry();
    if (this.editingIndex >= 0) {
      const old: LlmModelEntry = this.models[this.editingIndex];
      entry.id = old.id;
    } else {
      entry.id = ChatRepository.newModelId();
    }
    entry.displayName = this.displayName.trim();
    entry.providerId = config.providerId;
    entry.baseUrl = config.baseUrl;
    entry.apiKey = config.apiKey;
    entry.model = config.model;
    entry.temperature = config.temperature;
    entry.apiFormat = config.apiFormat;
    entry.maxTokens = config.maxTokens;

    let list: LlmModelEntry[] = this.models.concat([]);
    if (this.editingIndex >= 0) {
      list[this.editingIndex] = entry;
    } else {
      list.push(entry);
    }
    await ChatRepository.saveModels(list);
    // 首次添加时自动设为激活模型
    if (this.models.length === 0) {
      await ChatRepository.setActiveModelId(entry.id);
      this.activeModelId = entry.id;
    }
    this.models = list;
    this.editing = false;
    promptAction.showToast({ message: '已保存模型' });
  }

  private async test(): Promise<void> {
    const config: LlmConfig = new LlmConfig();
    this.fillConfig(config);
    if (!config.baseUrl || (config.needsKey && !config.apiKey) || !config.model) {
      promptAction.showToast({ message: '请先完整填写配置' });
      return;
    }
    this.testing = true;
    const result: LlmResult = await LlmClient.testConnection(config);
    this.testing = false;
    if (result.success) {
      promptAction.showToast({ message: '连接成功：' + result.content.substring(0, 20) });
    } else {
      promptAction.showToast({ message: '连接失败：' + result.errorMessage });
    }
  }

  private onTempTextChange(text: string): void {
    this.tempText = text;
    const value: number = Number(text);
    if (!Number.isNaN(value) && value >= 0 && value <= 2) {
      this.temperature = value;
    }
  }

  private onMaxTokensChange(text: string): void {
    this.maxTokensText = text;
    const value: number = Number(text);
    if (!Number.isNaN(value) && value > 0 && value <= 200000) {
      this.maxTokens = value;
    }
  }

  private async clearKey(): Promise<void> {
    AlertDialog.show({
      title: '清除 API Key',
      message: '确定要清除已保存的 API Key 吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清除',
        fontColor: Color.Red,
        action: () => {
          this.apiKey = '';
        }
      }
    });
  }

  // ---- 弹层 ----

  @Builder
  providerSheet() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.palette.borderSubtle)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Row() {
            Text('选择服务商')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showProviderSheet = false; })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 8 })

          Scroll() {
            Column({ space: 4 }) {
              ForEach(LLM_PROVIDER_TEMPLATES, (template: LlmProviderTemplate) => {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Row({ space: 6 }) {
                      Text(template.name)
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textPrimary)
                        .fontWeight(template.id === this.providerId ? FontWeight.Bold : FontWeight.Medium)
                      if (template.id === 'custom') {
                        Text('+')
                          .fontSize(11)
                          .fontFamily(this.palette.fontSans)
                          .fontColor(this.palette.primary)
                          .fontWeight(FontWeight.Bold)
                          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                          .borderRadius(4)
                          .backgroundColor(this.palette.primaryDim)
                      }
                    }
                    if (template.id !== 'custom' && template.baseUrl.length > 0) {
                      Text(template.baseUrl)
                        .fontSize(10)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textTertiary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    } else if (template.id === 'custom') {
                      Text('手动填写接口地址与模型')
                        .fontSize(10)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textTertiary)
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (template.id === this.providerId) {
                    Text('✓')
                      .fontSize(16)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.primary)
                      .fontWeight(FontWeight.Bold)
                  }
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor(template.id === this.providerId ? this.palette.primaryDim : this.palette.bgSurface)
                .border({ width: template.id === this.providerId ? 1 : 0,
                  color: template.id === this.providerId ? this.palette.primary : Color.Transparent })
                .onClick(() => { this.applyTemplate(template); })
              }, (template: LlmProviderTemplate) => template.id)
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 360 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick((event: ClickEvent) => { event.stopPropagation(); })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showProviderSheet = false; })
  }

  @Builder
  modelSheet() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.palette.borderSubtle)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Row() {
            Text('选择模型')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showModelSheet = false; })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 8 })

          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.modelOptions(), (modelName: string) => {
                Row() {
                  Text(modelName)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textPrimary)
                    .layoutWeight(1)
                  if (modelName === this.model) {
                    Text('✓')
                      .fontSize(16)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.primary)
                      .fontWeight(FontWeight.Bold)
                  }
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor(modelName === this.model ? this.palette.primaryDim : this.palette.bgSurface)
                .border({ width: modelName === this.model ? 1 : 0,
                  color: modelName === this.model ? this.palette.primary : Color.Transparent })
                .onClick(() => {
                  this.model = modelName;
                  this.customModelInput = '';
                  this.showModelSheet = false;
                })
              }, (modelName: string) => modelName)
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 220 })

          // 手动输入模型名
          Column({ space: 6 }) {
            Text('没有你需要的模型？手动输入模型名')
              .fontSize(10)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Row({ space: 8 }) {
              TextInput({ text: this.customModelInput, placeholder: '如 deepseek-r1-0528' })
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .placeholderColor(this.palette.textTertiary)
                .backgroundColor(this.palette.bgSurface2)
                .borderRadius(8)
                .border({ width: 1, color: this.palette.borderSubtle })
                .height(40)
                .layoutWeight(1)
                .onChange((value: string) => { this.customModelInput = value; })
              Text('确定')
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .borderRadius(8)
                .backgroundColor(this.palette.primary)
                .onClick(() => { this.applyCustomModel(); })
            }
            .width('100%')
          }
          .width('100%')
          .padding(10)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick((event: ClickEvent) => { event.stopPropagation(); })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showModelSheet = false; })
  }

  @Builder
  formatSheet() {
    Stack() {
      Column() {
        Blank()
        Column() {
          Row() {
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.palette.borderSubtle)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 4 })

          Row() {
            Text('选择 API 格式')
              .fontSize(this.palette.fsMd)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => { this.showFormatSheet = false; })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 8 })

          Column({ space: 4 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('OpenAI Chat Completions')
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(this.apiFormat === 'openai' ? FontWeight.Bold : FontWeight.Medium)
                Text('适用于 OpenAI / DeepSeek / 通义千问 等兼容接口')
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.apiFormat === 'openai') {
                Text('✓')
                  .fontSize(16)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(this.apiFormat === 'openai' ? this.palette.primaryDim : this.palette.bgSurface)
            .border({ width: this.apiFormat === 'openai' ? 1 : 0,
              color: this.apiFormat === 'openai' ? this.palette.primary : Color.Transparent })
            .onClick(() => {
              this.apiFormat = 'openai';
              this.showFormatSheet = false;
            })

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('Anthropic Messages')
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(this.apiFormat === 'anthropic' ? FontWeight.Bold : FontWeight.Medium)
                Text('适用于 Anthropic Claude 系列模型')
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.apiFormat === 'anthropic') {
                Text('✓')
                  .fontSize(16)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(this.apiFormat === 'anthropic' ? this.palette.primaryDim : this.palette.bgSurface)
            .border({ width: this.apiFormat === 'anthropic' ? 1 : 0,
              color: this.apiFormat === 'anthropic' ? this.palette.primary : Color.Transparent })
            .onClick(() => {
              this.apiFormat = 'anthropic';
              this.showFormatSheet = false;
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: Math.max(16, this.navBarHeight) })
        .backgroundColor(this.palette.bgBase)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick((event: ClickEvent) => { event.stopPropagation(); })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => { this.showFormatSheet = false; })
  }

  @Builder
  rowLabel(title: string, desc: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      if (desc.length > 0) {
        Text(desc)
          .fontSize(10)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  // ---- 编辑表单 ----

  @Builder
  editForm() {
    Scroll() {
      Column({ space: 16 }) {
        // 显示名称
        Column({ space: 6 }) {
          this.rowLabel('显示名称', '对话中显示的模型名字，留空自动使用服务商 + 模型名')
          TextInput({ text: this.displayName, placeholder: '如：我的 DeepSeek' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(44)
            .width('100%')
            .onChange((value: string) => { this.displayName = value; })
        }
        .width('100%')

        // 服务商
        Column({ space: 10 }) {
          this.rowLabel('服务商', '选择后自动填入接口地址与推荐模型')
          Row() {
            Text(this.providerLabel())
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .layoutWeight(1)
            Text('›')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .onClick(() => { this.showProviderSheet = true; })
        }
        .width('100%')

        // API 格式（仅自定义时显示）
        if (this.isCustomProvider()) {
          Column({ space: 6 }) {
            this.rowLabel('API 格式', '选择接口协议类型')
            Row() {
              Text(this.formatLabel())
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textPrimary)
                .layoutWeight(1)
              Text('›')
                .fontSize(16)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => { this.showFormatSheet = true; })
          }
          .width('100%')
        }

        // 接口地址
        Column({ space: 6 }) {
          this.rowLabel('接口地址 (Base URL)',
            this.apiFormat === 'anthropic' ? '如 https://api.anthropic.com' : '如 https://api.deepseek.com/v1')
          TextInput({ text: this.baseUrl, placeholder: 'https://api.example.com' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(44)
            .onChange((value: string) => { this.baseUrl = value; })
        }
        .width('100%')

        // API Key
        Column({ space: 6 }) {
          this.rowLabel('API Key',
            this.isLocalProvider() ? '本地服务无需填写' :
              (this.apiFormat === 'anthropic' ? '使用 x-api-key 请求头' : '仅加密保存在本机，不会上传'))
          Row({ space: 8 }) {
            TextInput({ text: this.apiKey, placeholder: 'sk-...' })
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .placeholderColor(this.palette.textTertiary)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: this.palette.borderSubtle })
              .height(44)
              .type(this.showKey ? InputType.Normal : InputType.Password)
              .layoutWeight(1)
              .onChange((value: string) => { this.apiKey = value; })
            Text(this.showKey ? '隐藏' : '显示')
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .padding(8)
              .onClick(() => { this.showKey = !this.showKey; })
            if (this.apiKey.length > 0) {
              Text('清除')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.danger)
                .padding(8)
                .onClick(() => { this.clearKey(); })
            }
          }
          .width('100%')
        }
        .width('100%')

        // 模型
        Column({ space: 6 }) {
          this.rowLabel('模型名称', '推荐使用模板默认模型')
          Row() {
            TextInput({ text: this.model, placeholder: 'deepseek-chat' })
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .placeholderColor(this.palette.textTertiary)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: this.palette.borderSubtle })
              .height(44)
              .layoutWeight(1)
              .onChange((value: string) => { this.model = value; })
              .onClick((event: ClickEvent) => { event.stopPropagation(); })
            Text('∨')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(10)
          }
          .width('100%')
          .borderRadius(8)
          .onClick(() => { this.showModelSheet = true; })
        }
        .width('100%')

        // max_tokens（Anthropic 格式时显示）
        if (this.apiFormat === 'anthropic') {
          Column({ space: 6 }) {
            this.rowLabel('max_tokens', '最大输出 Token 数（1-200000）')
            TextInput({ text: this.maxTokensText, placeholder: '4096' })
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .placeholderColor(this.palette.textTertiary)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: this.palette.borderSubtle })
              .height(44)
              .type(InputType.Number)
              .width('100%')
              .onChange((value: string) => { this.onMaxTokensChange(value); })
          }
          .width('100%')
        }

        // 温度
        Column({ space: 6 }) {
          this.rowLabel('温度（0-2，越高越随机）', '当前：' + this.tempText)
          TextInput({ text: this.tempText, placeholder: '0.7' })
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .placeholderColor(this.palette.textTertiary)
            .backgroundColor(this.palette.bgSurface)
            .borderRadius(8)
            .border({ width: 1, color: this.palette.borderSubtle })
            .height(44)
            .type(InputType.Number)
            .width('100%')
            .onChange((value: string) => { this.onTempTextChange(value); })
        }
        .width('100%')

        // 按钮
        Row({ space: 12 }) {
          Button('保存模型')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontWeight(FontWeight.Medium)
            .height(44)
            .layoutWeight(1)
            .backgroundColor(this.palette.primary)
            .fontColor('#FFFFFF')
            .borderRadius(10)
            .onClick(() => { this.save(); })
          Button(this.testing ? '测试中…' : '测试连接')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontWeight(FontWeight.Medium)
            .height(44)
            .layoutWeight(1)
            .backgroundColor(this.palette.bgSurface2)
            .fontColor(this.palette.textPrimary)
            .borderRadius(10)
            .border({ width: 1, color: this.palette.borderSubtle })
            .enabled(!this.testing)
            .onClick(() => { this.test(); })
        }
        .width('100%')

        Text('隐私说明：API Key 仅以 AES-256 加密形式保存在本机数据库，发送请求时直接携带给所选服务商，不经过任何第三方中转。')
          .fontSize(10)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .lineHeight(16)
          .width('100%')
          .padding(12)
          .borderRadius(8)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
      }
      .width('100%')
      .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: 32 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // ---- 模型列表 ----

  @Builder
  modelList() {
    Column({ space: 12 }) {
      // 说明
      Text('配置多个大模型，在对话中可随时切换。每个模型可单独设置显示名称。')
        .fontSize(11)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .lineHeight(16)
        .width('100%')

      if (this.models.length === 0) {
        Column({ space: 10 }) {
          Text('🤖')
            .fontSize(40)
            .fontFamily(this.palette.fontSans)
          Text('还没有配置任何模型')
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
          Text('点击下方按钮添加你的第一个大模型')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 48, bottom: 40 })
      } else {
        // 模型卡片
        ForEach(this.models, (m: LlmModelEntry, index: number) => {
          Column({ space: 6 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Row({ space: 8 }) {
                  Text(modelDisplayName(m))
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textPrimary)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (m.displayName.trim().length > 0) {
                    Text('自定义')
                      .fontSize(9)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.primary)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                      .borderRadius(4)
                      .backgroundColor(this.palette.primaryDim)
                  }
                }
                Text(m.model + ' · ' + m.baseUrl)
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('编辑')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .padding(6)
                .onClick(() => { this.editModel(index); })
              Text('✕')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.danger)
                .padding(6)
                .onClick(() => { this.removeModel(index); })
            }
            .width('100%')

            Row({ space: 8 }) {
              if (m.id === this.activeModelId) {
                Text('✓ 当前使用')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.success)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .backgroundColor(this.palette.bgSurface2)
              } else {
                Text('设为当前')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .backgroundColor(this.palette.primaryDim)
                  .onClick(() => { this.activateModel(index); })
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(12)
          .borderRadius(10)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
        }, (m: LlmModelEntry) => m.id)
      }

      // 添加按钮
      Row() {
        Text('＋ 添加模型')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .borderRadius(10)
      .backgroundColor(this.palette.primary)
      .onClick(() => { this.addModel(); })

      Text('隐私说明：API Key 仅以 AES-256 加密形式保存在本机数据库，发送请求时直接携带给所选服务商，不经过任何第三方中转。')
        .fontSize(10)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
        .lineHeight(16)
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor(this.palette.bgSurface)
        .border({ width: 1, color: this.palette.borderSubtle })
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: 32 })
  }

  build() {
    Stack() {
      Column() {
        TopBar({
          title: this.editing ? '编辑模型' : '模型管理',
          subtitle: 'OpenAI / Anthropic 兼容接口',
          showBack: true
        }) {
          if (this.editing) {
            Row() {
              Text('‹ 返回')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .onClick(() => { this.backToList(); })
            }
          }
        }

        if (this.editing) {
          this.editForm()
        } else {
          Scroll() {
            this.modelList()
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.bgBase)
      .padding({ bottom: Math.max(0, this.navBarHeight) })

      if (this.showProviderSheet) { this.providerSheet() }
      if (this.showModelSheet) { this.modelSheet() }
      if (this.showFormatSheet) { this.formatSheet() }
    }
    .width('100%')
    .height('100%')
  }
}

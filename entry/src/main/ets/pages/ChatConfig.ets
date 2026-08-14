// 智子 - AI 对话配置页（多模型管理：列表 + 编辑）
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { ChatRepository } from '../service/ChatRepository';
import { LlmClient } from '../service/LlmClient';
import { API_FORMAT_LABELS, ApiFormat, LLM_PROVIDER_TEMPLATES, LlmConfig, LlmModelEntry,
  LlmProviderTemplate, LlmResult, modelDisplayName, providerTemplateById } from '../common/LlmModels';

class ContextChipItem {
  value: number;
  selected: boolean;
  field: 'in' | 'out';

  constructor(value: number, selected: boolean, field: 'in' | 'out') {
    this.value = value;
    this.selected = selected;
    this.field = field;
  }
}

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
  @State maxTokensText: string = '4096';
  @State customModelInput: string = '';
  // 自定义模型高级配置
  @State useFullUrl: boolean = false;
  @State advancedExpanded: boolean = false;
  @State modelFamily: string = '';
  @State contextTokensInText: string = '128000';
  @State contextTokensOutText: string = '4096';
  @State workersText: string = '1';
  @State visionEnabled: boolean = false;
  @State thinkingEnabled: boolean = false;
  @State followDefaultConfig: boolean = true;
  @State vllmCompat: boolean = false;
  @State modelEnabled: boolean = true;
  // 进入编辑/复制时的原始快照：用于判断表单是否有实际修改
  private formSnapshot: LlmModelEntry | null = null;

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

  // 将模型条目回显到表单，并保存快照用于“无修改不可保存”判断
  private fillFormFromEntry(m: LlmModelEntry): void {
    this.displayName = m.displayName;
    // 保留原 providerId，不强制兜底为 deepseek，避免覆盖用户自定义配置
    this.providerId = m.providerId && m.providerId.length > 0 ? m.providerId : 'custom';
    this.baseUrl = m.baseUrl;
    this.apiKey = m.apiKey;
    this.model = m.model;
    this.temperature = m.temperature;
    this.apiFormat = m.apiFormat || 'openai';
    this.maxTokens = m.maxTokens || 4096;
    this.maxTokensText = this.maxTokens.toString();
    this.useFullUrl = m.useFullUrl || false;
    this.advancedExpanded = false;
    this.modelFamily = m.modelFamily || '';
    this.contextTokensInText = (m.contextTokensIn || 128000).toString();
    this.contextTokensOutText = (m.contextTokensOut || 4096).toString();
    this.workersText = (m.workers || 1).toString();
    this.visionEnabled = m.visionEnabled || false;
    this.thinkingEnabled = m.thinkingEnabled || false;
    this.followDefaultConfig = m.followDefaultConfig !== false;
    this.vllmCompat = m.vllmCompat || false;
    this.modelEnabled = m.enabled !== false;
    this.editing = true;
  }

  private editModel(index: number): void {
    this.editingIndex = index;
    const m: LlmModelEntry = this.models[index];
    this.fillFormFromEntry(m);
    this.formSnapshot = this.cloneEntry(m);
  }

  // 复制模型：回显全部字段作为一个新模型（新 id，不影响原模型）
  private copyModel(index: number): void {
    this.editingIndex = -1;
    const m: LlmModelEntry = this.models[index];
    this.fillFormFromEntry(m);
    // 复制即新增：快照保存原字段，未修改任何内容时不允许保存
    this.formSnapshot = this.cloneEntry(m);
  }

  private cloneEntry(m: LlmModelEntry): LlmModelEntry {
    const c: LlmModelEntry = new LlmModelEntry();
    c.id = m.id;
    c.displayName = m.displayName;
    c.providerId = m.providerId;
    c.baseUrl = m.baseUrl;
    c.apiKey = m.apiKey;
    c.model = m.model;
    c.temperature = m.temperature;
    c.apiFormat = m.apiFormat;
    c.maxTokens = m.maxTokens;
    c.useFullUrl = m.useFullUrl;
    c.modelFamily = m.modelFamily;
    c.contextTokensIn = m.contextTokensIn;
    c.contextTokensOut = m.contextTokensOut;
    c.workers = m.workers;
    c.visionEnabled = m.visionEnabled;
    c.thinkingEnabled = m.thinkingEnabled;
    c.followDefaultConfig = m.followDefaultConfig;
    c.vllmCompat = m.vllmCompat;
    c.enabled = m.enabled;
    return c;
  }

  // 判断当前表单与快照是否有差异（差异才允许保存）
  private hasChanges(): boolean {
    const s: LlmModelEntry | null = this.formSnapshot;
    if (s === null) return true;
    if (this.displayName.trim() !== s.displayName.trim()) return true;
    if (this.providerId !== s.providerId) return true;
    if (this.baseUrl.trim() !== s.baseUrl.trim()) return true;
    if (this.apiKey.trim() !== s.apiKey.trim()) return true;
    if (this.model.trim() !== s.model.trim()) return true;
    if (this.temperature !== s.temperature) return true;
    if (this.apiFormat !== s.apiFormat) return true;
    if (this.maxTokens !== s.maxTokens) return true;
    if (this.useFullUrl !== s.useFullUrl) return true;
    if (this.modelFamily.trim() !== s.modelFamily.trim()) return true;
    if (this.contextTokensInText.trim() !== s.contextTokensIn.toString()) return true;
    if (this.contextTokensOutText.trim() !== s.contextTokensOut.toString()) return true;
    if (this.workersText.trim() !== s.workers.toString()) return true;
    if (this.visionEnabled !== s.visionEnabled) return true;
    if (this.thinkingEnabled !== s.thinkingEnabled) return true;
    if (this.followDefaultConfig !== s.followDefaultConfig) return true;
    if (this.vllmCompat !== s.vllmCompat) return true;
    if (this.modelEnabled !== s.enabled) return true;
    return false;
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
        action: async () => {
          // 先从内存过滤，保证删除后列表立即刷新
          const list: LlmModelEntry[] = [];
          for (let i: number = 0; i < this.models.length; i++) {
            if (this.models[i].id !== m.id) list.push(this.models[i]);
          }
          this.models = list;
          // 若删除的是当前激活模型，切换到第一个启用的模型
          if (m.id === this.activeModelId) {
            let fallbackId: string = '';
            for (let i: number = 0; i < list.length; i++) {
              if (list[i].enabled !== false) { fallbackId = list[i].id; break; }
            }
            await ChatRepository.setActiveModelId(fallbackId);
            this.activeModelId = fallbackId;
          }
          try {
            await ChatRepository.saveModels(list);
          } catch (e) {
            promptAction.showToast({ message: '删除失败，请重试' });
            await this.load();
            return;
          }
          promptAction.showToast({ message: '已删除「' + modelDisplayName(m) + '」' });
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

  // 启用/禁用模型：立即持久化
  private async toggleEnabled(index: number, value: boolean): Promise<void> {
    const m: LlmModelEntry = this.models[index];
    const list: LlmModelEntry[] = this.models.concat([]);
    const target: LlmModelEntry = this.cloneEntry(m);
    target.enabled = value;
    list[index] = target;
    try {
      await ChatRepository.saveModels(list);
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试' });
      return;
    }
    this.models = list;
    // 若禁用的是当前激活模型，需切换激活到其他启用模型，避免对话无可用模型
    if (m.id === this.activeModelId && !value) {
      let fallbackId: string = '';
      for (let i: number = 0; i < list.length; i++) {
        if (list[i].enabled) { fallbackId = list[i].id; break; }
      }
      if (fallbackId.length > 0) {
        await ChatRepository.setActiveModelId(fallbackId);
        this.activeModelId = fallbackId;
      }
    }
    promptAction.showToast({ message: value ? '已启用该模型' : '已禁用该模型' });
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
    this.maxTokensText = '4096';
    this.useFullUrl = false;
    this.advancedExpanded = false;
    this.modelFamily = '';
    this.contextTokensInText = '128000';
    this.contextTokensOutText = '4096';
    this.workersText = '1';
    this.visionEnabled = false;
    this.thinkingEnabled = false;
    this.followDefaultConfig = true;
    this.vllmCompat = false;
    this.modelEnabled = true;
    this.formSnapshot = null;
  }

  // ---- 表单辅助 ----

  private applyTemplate(template: LlmProviderTemplate): void {
    this.providerId = template.id;
    this.baseUrl = template.baseUrl;
    this.model = template.defaultModel;
    this.apiFormat = template.apiFormat;
    this.useFullUrl = false;
    this.modelFamily = '';
    this.followDefaultConfig = true;
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
    config.useFullUrl = this.useFullUrl;
    config.modelFamily = this.modelFamily.trim();
    const ctxIn: number = Number(this.contextTokensInText);
    const ctxOut: number = Number(this.contextTokensOutText);
    const workers: number = Number(this.workersText);
    config.contextTokensIn = !Number.isNaN(ctxIn) && ctxIn > 0 ? ctxIn : 128000;
    config.contextTokensOut = !Number.isNaN(ctxOut) && ctxOut > 0 ? ctxOut : 4096;
    config.workers = !Number.isNaN(workers) && workers > 0 ? workers : 1;
    config.visionEnabled = this.visionEnabled;
    config.thinkingEnabled = this.thinkingEnabled;
    config.followDefaultConfig = this.followDefaultConfig;
    config.vllmCompat = this.vllmCompat;
    config.enabled = this.modelEnabled;
  }

  private async save(): Promise<void> {
    // 必须有实际修改才能保存
    if (!this.hasChanges()) {
      promptAction.showToast({ message: '未做任何修改' });
      return;
    }
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
    entry.useFullUrl = config.useFullUrl;
    entry.modelFamily = config.modelFamily;
    entry.contextTokensIn = config.contextTokensIn;
    entry.contextTokensOut = config.contextTokensOut;
    entry.workers = config.workers;
    entry.visionEnabled = config.visionEnabled;
    entry.thinkingEnabled = config.thinkingEnabled;
    entry.followDefaultConfig = config.followDefaultConfig;
    entry.vllmCompat = config.vllmCompat;
    entry.enabled = config.enabled;

    let list: LlmModelEntry[] = this.models.concat([]);
    if (this.editingIndex >= 0) {
      list[this.editingIndex] = entry;
    } else {
      list.push(entry);
    }
    try {
      await ChatRepository.saveModels(list);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      promptAction.showToast({ message: '保存失败：' + (err.message ? err.message : '存储异常') });
      return;
    }
    // 首次添加时自动设为激活模型（仅当启用状态）
    if (this.models.length === 0 && entry.enabled) {
      await ChatRepository.setActiveModelId(entry.id);
      this.activeModelId = entry.id;
    }
    this.models = list;
    // 若保存后当前激活模型被禁用，回退到第一个启用的模型
    if (entry.id === this.activeModelId && !entry.enabled) {
      let fallbackId: string = '';
      for (let i: number = 0; i < list.length; i++) {
        if (list[i].enabled) { fallbackId = list[i].id; break; }
      }
      if (fallbackId.length > 0) {
        await ChatRepository.setActiveModelId(fallbackId);
        this.activeModelId = fallbackId;
      }
    }
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

  private onMaxTokensChange(text: string): void {
    this.maxTokensText = text;
    const value: number = Number(text);
    if (!Number.isNaN(value) && value > 0 && value <= 200000) {
      this.maxTokens = value;
    }
  }

  private onContextTokensInChange(text: string): void {
    this.contextTokensInText = text;
  }

  private onContextTokensOutChange(text: string): void {
    this.contextTokensOutText = text;
  }

  private onWorkersChange(text: string): void {
    this.workersText = text;
  }

  private applyContextChip(field: 'in' | 'out', value: number): void {
    if (field === 'in') {
      this.contextTokensInText = value.toString();
    } else {
      this.contextTokensOutText = value.toString();
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

  @Builder
  toggleRow(label: string, desc: string, checked: boolean, onChange: (value: boolean) => void) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(label)
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
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor(this.palette.primary)
        .switchPointColor(Color.White)
        .onChange(onChange)
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.palette.bgSurface)
    .border({ width: 1, color: this.palette.borderSubtle })
  }

  private contextChipLabel(chip: number): string {
    if (chip >= 1000000) return (chip / 1000000).toFixed(0) + 'M';
    if (chip >= 1000) return (chip / 1000).toFixed(0) + 'k';
    return chip.toString();
  }

  private buildContextChipItems(text: string, chips: number[], field: 'in' | 'out'): ContextChipItem[] {
    const items: ContextChipItem[] = [];
    for (let i: number = 0; i < chips.length; i++) {
      const value: number = chips[i];
      items.push(new ContextChipItem(value, text === value.toString(), field));
    }
    return items;
  }

  @Builder
  contextTokenField(label: string, placeholder: string, text: string,
    chips: number[], onChange: (value: string) => void, field: 'in' | 'out') {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Row({ space: 8 }) {
        TextInput({ text: text, placeholder: placeholder })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface2)
          .borderRadius(8)
          .border({ width: 1, color: this.palette.borderSubtle })
          .height(40)
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange(onChange)
        ForEach(this.buildContextChipItems(text, chips, field), (item: ContextChipItem) => {
          Text(this.contextChipLabel(item.value))
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(item.selected ? Color.White : this.palette.textSecondary)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(6)
            .backgroundColor(item.selected ? this.palette.primary : this.palette.bgSurface2)
            .onClick(() => { this.applyContextChip(item.field, item.value); })
        }, (item: ContextChipItem) => item.value.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  advancedSection() {
    Column({ space: 12 }) {
      // 展开/折叠头部
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('高级配置')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('上下文窗口、特殊能力等')
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(this.advancedExpanded ? '▲' : '▼')
          .fontSize(12)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
      .padding(12)
      .borderRadius(8)
      .backgroundColor(this.palette.bgSurface)
      .border({ width: 1, color: this.palette.borderSubtle })
      .onClick(() => { this.advancedExpanded = !this.advancedExpanded; })

      if (this.advancedExpanded) {
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

        // 上下文窗口
        this.contextTokenField('上下文窗口（Token）· 输入', '请输入数值，留空则使用最佳默认值',
          this.contextTokensInText, [128000, 256000, 512000, 1000000],
          (value: string) => { this.onContextTokensInChange(value); }, 'in')
        this.contextTokenField('上下文窗口（Token）· 输出', '请输入数值，留空则使用最佳默认值',
          this.contextTokensOutText, [4096, 16384, 32768, 128000],
          (value: string) => { this.onContextTokensOutChange(value); }, 'out')

        // 工作线程数
        Column({ space: 6 }) {
          this.rowLabel('工作线程数', '并发请求数，通常保持 1')
          TextInput({ text: this.workersText, placeholder: '1' })
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
            .onChange((value: string) => { this.onWorkersChange(value); })
        }
        .width('100%')

        // 能力开关
        this.toggleRow('启用此模型', '关闭后该模型不可在对话中选择与使用', this.modelEnabled,
          (value: boolean) => { this.modelEnabled = value; })
        this.toggleRow('支持图片输入', '开启后模型可接收图片消息', this.visionEnabled,
          (value: boolean) => { this.visionEnabled = value; })
        this.toggleRow('思考模式', '适用于 Claude 等支持 extended thinking 的模型', this.thinkingEnabled,
          (value: boolean) => { this.thinkingEnabled = value; })
        this.toggleRow('跟随模型默认配置', '使用模型官方推荐的默认参数', this.followDefaultConfig,
          (value: boolean) => { this.followDefaultConfig = value; })
        this.toggleRow('vLLM 兼容模式',
          '服务端为 vLLM 部署时开启（如 api.do.top 的 Qwen3 系列）；普通网关（tokenrhythm/硅基流动等）请保持关闭',
          this.vllmCompat, (value: boolean) => { this.vllmCompat = value; })
      }
    }
    .width('100%')
  }

  // ---- 编辑表单 ----

  @Builder
  editForm() {
    Scroll() {
      Column({ space: 16 }) {
        // 显示名称 / 模型展示名称
        Column({ space: 6 }) {
          this.rowLabel(this.isCustomProvider() ? '模型展示名称' : '显示名称',
            this.isCustomProvider()
              ? '在模型列表中展示的名称，未设置时默认显示模型 ID'
              : '对话中显示的模型名字，留空自动使用服务商 + 模型名')
          TextInput({ text: this.displayName, placeholder: this.isCustomProvider() ? '如我的自定义模型' : '如：我的 DeepSeek' })
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

        // 接口地址 / 自定义请求地址
        Column({ space: 6 }) {
          this.rowLabel(this.isCustomProvider() ? '自定义请求地址' : '接口地址 (Base URL)',
            this.apiFormat === 'anthropic' ? '如 https://api.anthropic.com' : '如 https://api.deepseek.com/v1')
          Row({ space: 8 }) {
            TextInput({ text: this.baseUrl, placeholder: 'https://api.example.com' })
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .placeholderColor(this.palette.textTertiary)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: this.palette.borderSubtle })
              .height(44)
              .layoutWeight(1)
              .onChange((value: string) => { this.baseUrl = value; })
            if (this.isCustomProvider()) {
              Row({ space: 4 }) {
                Text('完整 URL')
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textSecondary)
                Toggle({ type: ToggleType.Switch, isOn: this.useFullUrl })
                  .selectedColor(this.palette.primary)
                  .switchPointColor(Color.White)
                  .onChange((value: boolean) => { this.useFullUrl = value; })
              }
            }
          }
          .width('100%')
          if (this.isCustomProvider()) {
            Text(this.useFullUrl
              ? '已开启完整 URL，将不会自动补全 /chat/completions 或 /v1/messages 路径'
              : '关闭时系统会自动补全 /chat/completions 或 /v1/messages 路径')
              .fontSize(10)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .width('100%')
          }
        }
        .width('100%')

        // API Key / API 密钥
        Column({ space: 6 }) {
          this.rowLabel(this.isCustomProvider() ? 'API 密钥' : 'API Key',
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

        // 模型 / 模型 ID
        Column({ space: 6 }) {
          this.rowLabel(this.isCustomProvider() ? '模型 ID' : '模型名称',
            this.isCustomProvider() ? '输入模型 ID' : '推荐使用模板默认模型')
          if (this.isCustomProvider()) {
            TextInput({ text: this.model, placeholder: '如 deepseek-chat' })
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .placeholderColor(this.palette.textTertiary)
              .backgroundColor(this.palette.bgSurface)
              .borderRadius(8)
              .border({ width: 1, color: this.palette.borderSubtle })
              .height(44)
              .width('100%')
              .onChange((value: string) => { this.model = value; })
          } else {
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
                .onClick(() => {})
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
        }
        .width('100%')

        // 高级配置（仅自定义，默认折叠）
        if (this.isCustomProvider()) {
          this.advancedSection()
        }

        // max_tokens（非自定义模板直接显示，Anthropic 格式时）
        if (!this.isCustomProvider()) {
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
        }

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
              Text('复制')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.primary)
                .padding(6)
                .onClick(() => { this.copyModel(index); })
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
              Text(m.enabled ? '启用' : '已禁用')
                .fontSize(this.palette.fsXs)
                .fontFamily(this.palette.fontSans)
                .fontColor(m.enabled ? this.palette.success : this.palette.textTertiary)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .borderRadius(12)
                .backgroundColor(m.enabled ? this.palette.bgSurface2 : this.palette.bgSurface2)
                .onClick(() => { this.toggleEnabled(index, !m.enabled); })
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

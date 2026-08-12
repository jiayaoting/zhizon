// 智子 - AI 对话页
import { promptAction, router } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { ChatRepository } from '../service/ChatRepository';
import { LlmClient } from '../service/LlmClient';
import { ChatMessage, LlmConfig, LlmModelEntry, LlmResult, modelDisplayName,
  modelDisplayNameFromConfig } from '../common/LlmModels';

@Entry
@Component
struct Chat {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State sending: boolean = false;
  @State configReady: boolean = false;
  @State configHint: string = '未配置';
  @State streamingContent: string = '';
  @State streaming: boolean = false;

  // 模型切换
  @State models: LlmModelEntry[] = [];
  @State activeModelId: string = '';
  @State showModelPicker: boolean = false;
  private activeConfig: LlmConfig | null = null;

  // 搜索
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State searchRole: string = 'all';

  private scrollController: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.refreshModels();
  }

  private async load(): Promise<void> {
    this.messages = await ChatRepository.loadHistory();
    if (this.messages.length === 0) {
      this.messages.push(new ChatMessage('assistant',
        '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。'));
    }
    await this.refreshModels();
  }

  private async refreshModels(): Promise<void> {
    this.models = await ChatRepository.loadModels();
    this.activeModelId = await ChatRepository.loadActiveModelId();
    this.activeConfig = await ChatRepository.loadActiveConfig();
    this.configReady = this.activeConfig !== null && this.activeConfig.configured;
    if (this.configReady && this.activeConfig !== null) {
      this.configHint = modelDisplayNameFromConfig(this.activeConfig);
    } else {
      this.configHint = '请先完成配置';
    }
  }

  private currentModelName(): string {
    if (this.activeConfig !== null && this.activeConfig.displayName.trim().length > 0) {
      return this.activeConfig.displayName.trim();
    }
    if (this.activeConfig !== null && this.activeConfig.model.trim().length > 0) {
      return this.activeConfig.model.trim();
    }
    return '未选择模型';
  }

  private async selectModel(index: number): Promise<void> {
    const m: LlmModelEntry = this.models[index];
    await ChatRepository.setActiveModelId(m.id);
    this.activeModelId = m.id;
    this.activeConfig = await ChatRepository.loadActiveConfig();
    this.configReady = this.activeConfig !== null && this.activeConfig.configured;
    this.configHint = modelDisplayName(m);
    this.showModelPicker = false;
  }

  private openConfig(): void {
    router.pushUrl({ url: 'pages/ChatConfig' });
  }

  private async clearChat(): Promise<void> {
    AlertDialog.show({
      title: '清空对话',
      message: '确定要清空当前全部对话记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: () => {
          this.messages = [];
          this.streamingContent = '';
          this.showSearch = false;
          this.searchQuery = '';
          ChatRepository.clearHistory();
        }
      }
    });
  }

  private onInputChange(value: string): void {
    this.inputText = value;
  }

  private async send(): Promise<void> {
    const text: string = this.inputText.trim();
    if (text.length === 0 || this.sending || this.streaming) return;
    const config: LlmConfig | null = this.activeConfig;
    if (config === null || !config.configured) {
      promptAction.showToast({ message: '请先配置大模型 API' });
      return;
    }
    if (config.needsKey && !config.apiKey) {
      promptAction.showToast({ message: '请先配置 API Key' });
      return;
    }
    this.inputText = '';
    const userMessage: ChatMessage = new ChatMessage('user', text);
    const assistantMessage: ChatMessage = new ChatMessage('assistant', '');
    const newMessages: ChatMessage[] = this.messages.concat([userMessage, assistantMessage]);
    this.messages = newMessages;
    this.sending = true;
    this.streaming = true;
    this.streamingContent = '';
    this.scrollToBottom();

    const history: ChatMessage[] = ChatRepository.requestMessages(newMessages.slice(0, newMessages.length - 1));
    const result: LlmResult = await LlmClient.postCompletionStream(config, history, (delta: string) => {
      const next: string = this.streamingContent + delta;
      this.streamingContent = next;
      const list: ChatMessage[] = this.messages.concat([]);
      const lastIndex: number = list.length - 1;
      list[lastIndex].content = next;
      this.messages = list;
      this.scrollToBottom();
    });
    this.sending = false;
    this.streaming = false;
    const list: ChatMessage[] = this.messages.concat([]);
    const lastIndex: number = list.length - 1;
    if (result.success) {
      list[lastIndex].content = result.content;
      this.streamingContent = '';
    } else {
      list[lastIndex].content = '⚠️ 请求失败：' + result.errorMessage;
      this.streamingContent = '';
    }
    this.messages = list;
    await ChatRepository.saveHistory(this.messages);
    this.scrollToBottom();
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scrollController.scrollEdge(Edge.Bottom);
    }, 30);
  }

  private formatTime(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    return hh + ':' + mm;
  }

  // ---- 搜索 ----

  private exitSearch(): void {
    this.showSearch = false;
    this.searchQuery = '';
    this.searchRole = 'all';
  }

  private displayMessages(): ChatMessage[] {
    if (!this.showSearch) return this.messages;
    let result: ChatMessage[] = this.messages;
    if (this.searchRole !== 'all') {
      result = result.filter((m: ChatMessage): boolean => m.role === this.searchRole);
    }
    const q: string = this.searchQuery.trim().toLowerCase();
    if (q.length > 0) {
      result = result.filter((m: ChatMessage): boolean => m.content.toLowerCase().indexOf(q) >= 0);
    }
    return result;
  }

  private searchResultCount(): number {
    if (!this.showSearch) return this.messages.length;
    return this.displayMessages().length;
  }

  @Builder
  filterChip(label: string, role: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.searchRole === role ? '#FFFFFF' : this.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
    }
    .height(28)
    .padding({ left: 12, right: 12 })
    .borderRadius(14)
    .backgroundColor(this.searchRole === role ? this.palette.primary : this.palette.bgSurface2)
    .border({ width: 1, color: this.searchRole === role ? this.palette.primary : this.palette.borderSubtle })
    .onClick(() => { this.searchRole = role; })
  }

  @Builder
  searchBar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('🔍')
          .fontSize(14)
          .fontFamily(this.palette.fontSans)
        TextInput({ text: this.searchQuery, placeholder: '搜索对话记录…' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(Color.Transparent)
          .height(40)
          .layoutWeight(1)
          .onChange((value: string) => { this.searchQuery = value; })
        Text('✕')
          .fontSize(16)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .padding(8)
          .onClick(() => { this.exitSearch(); })
      }
      .width('100%')
      .padding({ left: 12, right: 4 })
      .height(44)
      .backgroundColor(this.palette.bgSurface)
      .borderRadius(10)
      .border({ width: 1, color: this.palette.borderSubtle })

      Row({ space: 6 }) {
        this.filterChip('全部', 'all')
        this.filterChip('用户', 'user')
        this.filterChip('助手', 'assistant')
        Blank()
        Text('共 ' + this.searchResultCount().toString() + ' 条')
          .fontSize(10)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8 })
  }

  @Builder
  emptyWelcome() {
    Column({ space: 12 }) {
      Text('🗨️')
        .fontSize(44)
        .fontFamily(this.palette.fontSans)
      Text('智子 AI 助手')
        .fontSize(this.palette.fsXl)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text('配置你自己的大模型 API Key，开始对话')
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 80, bottom: 40 })
  }

  // 搜索无结果
  @Builder
  searchEmpty() {
    Column({ space: 8 }) {
      Text('🔍')
        .fontSize(36)
        .fontFamily(this.palette.fontSans)
      Text('未找到匹配的对话')
        .fontSize(this.palette.fsBase)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textSecondary)
      Text('试试其他关键词或筛选条件')
        .fontSize(this.palette.fsXs)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 60, bottom: 40 })
  }

  @Builder
  messageBubble(message: ChatMessage, index: number) {
    Row() {
      if (message.role === 'user') {
        Blank()
        Column({ space: 4 }) {
          Text(message.content)
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor('#FFFFFF')
            .lineHeight(20)
            .padding(12)
            .borderRadius(12)
            .backgroundColor(this.palette.primary)
            .constraintSize({ maxWidth: this.isSm ? 260 : 420 })
        }
        .alignItems(HorizontalAlign.End)
      } else {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('🤖')
              .fontSize(14)
              .fontFamily(this.palette.fontSans)
            Text('智子 AI')
              .fontSize(11)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
            Text(this.formatTime(message.time))
              .fontSize(9)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
          }
          Text(message.content.length > 0 ? message.content : '…')
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textPrimary)
            .lineHeight(20)
            .padding(12)
            .borderRadius(12)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .constraintSize({ maxWidth: this.isSm ? 280 : 440 })
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  inputBar() {
    Row({ space: 8 }) {
      TextInput({ text: this.inputText, placeholder: '输入消息…' })
        .fontSize(this.palette.fsSm)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .placeholderColor(this.palette.textTertiary)
        .backgroundColor(this.palette.bgSurface)
        .borderRadius(10)
        .border({ width: 1, color: this.palette.borderSubtle })
        .height(44)
        .layoutWeight(1)
        .onChange((value: string) => { this.onInputChange(value); })
        .onSubmit(() => { this.send(); })
      Row() {
        Text(this.sending || this.streaming ? '…' : '发送')
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .height(44)
      .padding({ left: 16, right: 16 })
      .borderRadius(10)
      .backgroundColor(this.palette.primary)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.send(); })
    }
    .width('100%')
  }

  @Builder
  modelPicker() {
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
          .onClick(() => { this.showModelPicker = false; })
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 8 })

      Scroll() {
        Column({ space: 4 }) {
          ForEach(this.models, (m: LlmModelEntry, index: number) => {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(modelDisplayName(m))
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(m.id === this.activeModelId ? FontWeight.Bold : FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(m.model)
                  .fontSize(10)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (m.id === this.activeModelId) {
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
            .backgroundColor(m.id === this.activeModelId ? this.palette.primaryDim : this.palette.bgSurface)
            .border({ width: m.id === this.activeModelId ? 1 : 0,
              color: m.id === this.activeModelId ? this.palette.primary : Color.Transparent })
            .onClick(() => { this.selectModel(index); })
          }, (m: LlmModelEntry) => m.id)
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

  build() {
    Stack() {
      Column() {
        TopBar({
          title: 'AI 对话',
          subtitle: this.showSearch ? '搜索模式' : this.configHint,
          showBack: true
        }) {
          Row({ space: 12 }) {
            Text('🔍')
              .fontSize(16)
              .fontFamily(this.palette.fontSans)
              .opacity(this.showSearch ? 0.5 : 1)
              .onClick(() => {
                if (this.messages.length > 0) {
                  this.showSearch = !this.showSearch;
                  if (!this.showSearch) {
                    this.searchQuery = '';
                    this.searchRole = 'all';
                  }
                } else {
                  promptAction.showToast({ message: '暂无对话记录可搜索' });
                }
              })
            Text('🧹')
              .fontSize(18)
              .fontFamily(this.palette.fontSans)
              .onClick(() => { this.clearChat(); })
            Text('⚙️')
              .fontSize(18)
              .fontFamily(this.palette.fontSans)
              .onClick(() => { this.openConfig(); })
          }
        }

        // 搜索栏
        if (this.showSearch) {
          this.searchBar()
        }

        // 消息列表
        if (this.messages.length === 0) {
          this.emptyWelcome()
        } else if (this.showSearch && this.searchResultCount() === 0) {
          this.searchEmpty()
        } else {
          List({ space: 12, scroller: this.scrollController }) {
            ForEach(this.showSearch ? this.displayMessages() : this.messages,
              (message: ChatMessage, index: number) => {
              ListItem() {
                this.messageBubble(message, index)
              }
            }, (message: ChatMessage, index: number) => message.time.toString() + '_' + index.toString())
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12 })
        }

        // 底部区域
        if (this.showSearch) {
          // 搜索模式下显示退出按钮
          Row() {
            Text('退出搜索，返回对话')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .height(44)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .borderRadius(10)
          .onClick(() => { this.exitSearch(); })
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24,
            bottom: Math.max(8, this.navBarHeight) })
        } else {
          Column({ space: 8 }) {
            if (!this.configReady) {
              Row() {
                Text('⚠️ 尚未配置大模型 API，点击去配置')
                  .fontSize(11)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.warning)
                  .layoutWeight(1)
                Text('去配置 ›')
                  .fontSize(11)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.primary)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(10)
              .borderRadius(8)
              .backgroundColor(this.palette.bgSurface)
              .border({ width: 1, color: this.palette.borderSubtle })
              .onClick(() => { this.openConfig(); })
            }
            // 当前模型切换
            Row({ space: 6 }) {
              Text('🤖')
                .fontSize(12)
                .fontFamily(this.palette.fontSans)
              Text(this.currentModelName())
                .fontSize(11)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('▾')
                .fontSize(10)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(this.palette.bgSurface)
            .border({ width: 1, color: this.palette.borderSubtle })
            .onClick(() => {
              if (this.models.length > 0) {
                this.showModelPicker = true;
              } else {
                promptAction.showToast({ message: '请先配置模型' });
              }
            })
            this.inputBar()
          }
          .width('100%')
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: Math.max(8, this.navBarHeight) })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.bgBase)

      // 模型选择弹层
      if (this.showModelPicker) {
        Stack() {
          Column() {
            Blank()
            this.modelPicker()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick(() => { this.showModelPicker = false; })
      }
    }
    .width('100%')
    .height('100%')
  }
}
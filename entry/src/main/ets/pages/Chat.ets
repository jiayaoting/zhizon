// 智子 - AI 对话页
import { promptAction } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { pasteboard } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { GlobalBackgroundLayer } from '../components/GlobalBackgroundLayer';
import { ChatRepository } from '../service/ChatRepository';
import { LlmClient } from '../service/LlmClient';
import { AiCallContext } from '../service/AiCallLogger';
import { ChatExporter, ImportedChat } from '../service/ChatExporter';
import { ImageAttachment, AttachmentResult } from '../service/ImageAttachment';
import { ChatViewModel, ChatPhase } from '../service/ChatViewModel';
import { ChatMessage, ChatSession, entryToConfig, LlmConfig, LlmModelEntry, LlmResult,
  modelDisplayName, modelDisplayNameFromConfig } from '../common/LlmModels';
import { MarkdownConverter, MdBlock, InlineSpan } from '../common/MarkdownConverter';
import { ChatMessageBubble } from '../components/ChatMessageBubble';
import { ChatInputBar } from '../components/ChatInputBar';
import { ChatSessionDrawer } from '../components/ChatSessionDrawer';

@Component
export struct ChatTab {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('isDarkMode') isDark: boolean = false;
  // 宿主（AppShell）在 Chat 子页返回/切换 Tab 时递增该 token，驱动本组件刷新模型配置
  @StorageLink('chatRefreshToken') @Watch('onRefreshToken') chatRefreshToken: number = 0;

  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State sending: boolean = false;
  @State configReady: boolean = false;
  @State configHint: string = '未配置';
  @State streamingContent: string = '';
  @State streamingReasoning: string = '';
  @State streaming: boolean = false;

  // 多会话
  @State sessions: ChatSession[] = [];
  @State activeSessionId: string = '';
  @State showSessionDrawer: boolean = false;
  @State drawerRenameId: string = '';
  @State drawerRenameText: string = '';
  @State drawerSessions: ChatSession[] = [];
  @State drawerSearch: string = '';
  // 生成阶段与计时（idle / connecting / streaming）
  @State chatPhase: string = 'idle';
  @State elapsedSeconds: number = 0;
  // 流式渲染节流：同一时刻最多一次定时刷新
  private renderScheduled: boolean = false;
  // 当前待触发的流式刷新定时器（流结束时需取消，防止用清空后的 streamingContent 覆盖最终内容）
  private flushTimer: number = -1;
  // 输入区高度（TextArea 动态增高）
  @State inputHeight: number = 44;
  // 图片附件（vision 模型）
  @State attachmentDataUrl: string = '';
  @State attachmentName: string = '';
  // 编辑重发目标索引（-1 表示普通发送）
  private editTargetIndex: number = -1;
  // 用户主动停止标记：停止后保留已生成内容
  private stopRequested: boolean = false;
  // 生成状态机（阶段/计时/停止标记集中管理）
  private chatVm: ChatViewModel = new ChatViewModel();

  // 模型切换
  @State models: LlmModelEntry[] = [];
  @State activeModelId: string = '';
  @State showModelPicker: boolean = false;
  @State activeConfig: LlmConfig | null = null;
  // 当前流式请求的 httpRequest 引用，停止按钮调用 destroy() 中断
  private streamRequest: http.HttpRequest | null = null;
  // 上次失败时缓存的 user 消息，用于重试
  private lastUserText: string = '';

  // 搜索
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State searchRole: string = 'all';

  // 多选删除
  @State selectionMode: boolean = false;
  @State selectedIds: string[] = [];

  // 长按操作面板：显示单条消息的复制/分享/多选/删除
  @State actionSheetIndex: number = -1;

  // 全屏 markdown 查看
  @State fullscreenIndex: number = -1;
  private fullscreenController: webview.WebviewController = new webview.WebviewController();

  private readonly scrollController: Scroller = new Scroller();

  aboutToAppear(): void {
    // 订阅状态机回调，驱动 UI 状态
    this.chatVm.onPhaseChange = (phase: ChatPhase): void => { this.chatPhase = phase; };
    this.chatVm.onElapsedChange = (seconds: number): void => { this.elapsedSeconds = seconds; };
    this.load();
  }

  aboutToDisappear(): void {
    this.chatVm.dispose();
    // 页面销毁时取消未触发的流式刷新定时器，避免回调在组件销毁后仍写入消息对象
    this.cancelRenderFlush();
  }

  // 作为 Tab 嵌入后无 onPageShow，改为监听宿主递增的刷新 token（ChatConfig 返回/切回本 Tab 时触发）
  onRefreshToken(): void {
    if (this.chatRefreshToken > 0) {
      this.refreshModels();
      setTimeout(() => { this.scrollToBottom(); }, 100);
    }
  }

  private async load(): Promise<void> {
    this.sessions = await ChatRepository.ensureSessions();
    let activeId: string = await ChatRepository.loadActiveSessionId();
    if (activeId.length === 0 && this.sessions.length > 0) {
      activeId = this.sessions[0].id;
      await ChatRepository.setActiveSessionId(activeId);
    }
    this.activeSessionId = activeId;
    this.messages = activeId.length > 0 ? await ChatRepository.loadMessages(activeId) : [];
    if (this.messages.length === 0) {
      const welcome: ChatMessage = ChatMessage.create('assistant',
        '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
      this.messages = [welcome];
    }
    await this.refreshModels();
    // 等列表渲染完成后滚动到底部
    setTimeout(() => { this.scrollToBottom(); }, 150);
  }

  private async refreshModels(): Promise<void> {
    this.models = await ChatRepository.loadModels();
    this.activeModelId = await ChatRepository.loadActiveModelId();
    this.activeConfig = await ChatRepository.loadActiveConfig();
    // 激活 id 与现有模型不匹配时（如已删除），同步为当前生效模型，保证列表高亮与状态一致
    if (this.activeConfig !== null && this.activeModelId !== this.activeConfig.id) {
      this.activeModelId = this.activeConfig.id;
    }
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

  // 仅启用状态的模型可用于对话
  private enabledModels(): LlmModelEntry[] {
    const result: LlmModelEntry[] = [];
    for (let i: number = 0; i < this.models.length; i++) {
      if (this.models[i].enabled !== false) result.push(this.models[i]);
    }
    return result;
  }

  private async selectModel(index: number): Promise<void> {
    const enabled: LlmModelEntry[] = this.enabledModels();
    if (index < 0 || index >= enabled.length) return;
    const m: LlmModelEntry = enabled[index];
    try {
      await ChatRepository.setActiveModelId(m.id);
    } catch (e) {
      promptAction.showToast({ message: '切换失败，请重试' });
      return;
    }
    this.activeModelId = m.id;
    this.activeConfig = entryToConfig(m);
    this.configReady = this.activeConfig.configured;
    this.configHint = modelDisplayName(m);
    this.showModelPicker = false;
  }

  private openConfig(): void {
    AppNavigator.push('pages/ChatConfig');
  }

  // ==================== 多会话管理 ====================

  private openSessionDrawer(): void {
    this.drawerRenameId = '';
    this.drawerSearch = '';
    this.drawerSessions = this.sessions.concat([]);
    this.showSessionDrawer = true;
  }

  // 抽屉内搜索：标题或消息正文命中（标题 + 正文取并集去重）
  private onDrawerSearch(value: string): void {
    this.drawerSearch = value;
    this.refreshDrawerSessions();
  }

  private async refreshDrawerSessions(): Promise<void> {
    if (this.drawerSearch.trim().length === 0) {
      this.drawerSessions = this.sessions.concat([]);
      return;
    }
    const byTitle: ChatSession[] = await ChatRepository.searchSessions(this.drawerSearch);
    const byMsg: ChatSession[] = await ChatRepository.searchSessionsByMessage(this.drawerSearch);
    const merged: ChatSession[] = [];
    for (let i: number = 0; i < byTitle.length; i++) {
      merged.push(byTitle[i]);
    }
    for (let i: number = 0; i < byMsg.length; i++) {
      let dup: boolean = false;
      for (let j: number = 0; j < merged.length; j++) {
        if (merged[j].id === byMsg[i].id) {
          dup = true;
          break;
        }
      }
      if (!dup) merged.push(byMsg[i]);
    }
    this.drawerSessions = merged;
  }

  private closeSessionDrawer(): void {
    this.showSessionDrawer = false;
  }

  // 切换会话
  private async switchSession(id: string): Promise<void> {
    if (id === this.activeSessionId) {
      this.closeSessionDrawer();
      return;
    }
    if (this.sending || this.streaming) {
      promptAction.showToast({ message: '请先停止当前生成，再切换会话' });
      return;
    }
    this.activeSessionId = id;
    await ChatRepository.setActiveSessionId(id);
    this.messages = await ChatRepository.loadMessages(id);
    this.showSessionDrawer = false;
    this.exitSearch();
    this.exitSelectionMode();
    this.closeActionSheet();
    this.editTargetIndex = -1;
    this.inputText = '';
    this.streamingContent = '';
    this.streamingReasoning = '';
    setTimeout(() => { this.scrollToBottom(); }, 120);
  }

  // 新建会话
  private async newSession(): Promise<void> {
    if (this.sending || this.streaming) {
      promptAction.showToast({ message: '请先停止当前生成' });
      return;
    }
    const session: ChatSession = await ChatRepository.createSession('新的对话');
    this.sessions = await ChatRepository.loadSessions();
    this.activeSessionId = session.id;
    await ChatRepository.setActiveSessionId(session.id);
    this.messages = [];
    this.showSessionDrawer = false;
    this.editTargetIndex = -1;
    this.inputText = '';
    this.streamingContent = '';
    this.streamingReasoning = '';
  }

  // 会话重命名（抽屉内联编辑）
  private beginRenameSession(id: string): void {
    let title: string = '';
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === id) {
        title = this.sessions[i].title;
        break;
      }
    }
    this.drawerRenameId = id;
    this.drawerRenameText = title;
  }

  private async confirmRenameSession(): Promise<void> {
    if (this.drawerRenameId.length === 0) return;
    const id: string = this.drawerRenameId;
    this.drawerRenameId = '';
    await ChatRepository.renameSession(id, this.drawerRenameText);
    this.sessions = await ChatRepository.loadSessions();
    await this.refreshDrawerSessions();
  }

  // 固定 / 取消固定
  private async toggleSessionPin(id: string): Promise<void> {
    let pinned: boolean = false;
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === id) {
        pinned = this.sessions[i].pinned;
        break;
      }
    }
    await ChatRepository.setSessionPinned(id, !pinned);
    this.sessions = await ChatRepository.loadSessions();
    await this.refreshDrawerSessions();
  }

  // 删除会话（当前会话被删时自动切换到最近会话或新建）
  private async deleteSessionFromDrawer(id: string): Promise<void> {
    let title: string = '该会话';
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === id) {
        title = this.sessions[i].title;
        break;
      }
    }
    AlertDialog.show({
      title: '删除会话',
      message: '确定要删除「' + title + '」及其全部消息吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          await ChatRepository.deleteSession(id);
          this.sessions = await ChatRepository.loadSessions();
          if (this.activeSessionId === id) {
            let next: string = this.sessions.length > 0 ? this.sessions[0].id : '';
            if (next.length === 0) {
              const created: ChatSession = await ChatRepository.createSession('新的对话');
              this.sessions = await ChatRepository.loadSessions();
              next = created.id;
            }
            this.activeSessionId = next;
            await ChatRepository.setActiveSessionId(next);
            this.messages = await ChatRepository.loadMessages(next);
            this.editTargetIndex = -1;
            this.inputText = '';
          }
          this.closeSessionDrawer();
          promptAction.showToast({ message: '已删除会话' });
        }
      }
    });
  }

  // 会话标题（抽屉与顶栏显示）
  private activeSessionTitle(): string {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === this.activeSessionId) return this.sessions[i].title;
    }
    return 'AI 对话';
  }

  // ==================== 生成计时与流式节流 ====================

  // 流式渲染节流：增量先累积到 streamingContent，定时（约 60ms）一次性刷新到消息对象，
  // 避免每个 SSE 分片都触发整条消息重渲染
  private scheduleRenderFlush(assistantMessage: ChatMessage): void {
    if (this.renderScheduled) return;
    this.renderScheduled = true;
    this.flushTimer = setTimeout(() => {
      this.renderScheduled = false;
      this.flushTimer = -1;
      // 内容未变化时跳过赋值，避免无意义的整条重渲染（@ObjectLink 监听赋值）
      if (assistantMessage.content !== this.streamingContent ||
        assistantMessage.reasoning !== this.streamingReasoning) {
        assistantMessage.content = this.streamingContent;
        assistantMessage.reasoning = this.streamingReasoning;
        this.scrollToBottom();
      }
    }, 60);
  }

  // 流结束/停止时取消尚未触发的刷新定时器：
  // 若不清除，定时器会在 streamingContent 被清空后触发，用空字符串覆盖最终内容，
  // 导致流式结束消息只剩占位符 …（useMarkdown 判定内容为空）
  private cancelRenderFlush(): void {
    if (this.flushTimer >= 0) {
      clearTimeout(this.flushTimer);
      this.flushTimer = -1;
    }
    this.renderScheduled = false;
  }


  private async clearChat(): Promise<void> {
    AlertDialog.show({
      title: '清空会话',
      message: '确定要清空当前会话的全部消息吗？（会话本身会保留）',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: async () => {
          this.messages = [];
          this.streamingContent = '';
          this.showSearch = false;
          this.searchQuery = '';
          await ChatRepository.clearSessionMessages(this.activeSessionId);
          // 清空后恢复欢迎语，保持一致体验
          const welcome: ChatMessage = ChatMessage.create('assistant',
            '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
          this.messages = [welcome];
        }
      }
    });
  }

  private onInputChange(value: string): void {
    this.inputText = value;
    // 多行输入：按字符数估算行数，44~120 之间动态增高
    const len: number = value.length;
    const lines: number = Math.max(1, Math.ceil(len / 24));
    const h: number = Math.min(120, 44 + (lines - 1) * 20);
    this.inputHeight = Math.max(44, h);
  }

  // 输入框下方提示：Token 估算 / 上下文接近预警
  // 选取并压缩图片附件
  private async pickImageAttachment(): Promise<void> {
    if (this.activeConfig === null || !this.activeConfig.visionEnabled) {
      promptAction.showToast({ message: '当前模型不支持图片输入' });
      return;
    }
    const result: AttachmentResult | null = await ImageAttachment.pickAndCompress();
    if (result !== null) {
      this.attachmentDataUrl = result.dataUrl;
      this.attachmentName = result.name;
    }
  }

  // 移除图片附件
  private removeImageAttachment(): void {
    this.attachmentDataUrl = '';
    this.attachmentName = '';
  }

  private inputTokenHint(): string {
    const text: string = this.inputText.trim();
    if (text.length === 0) return '';
    const est: number = ChatRepository.estimateTokens(text);
    let hint: string = '≈ ' + est.toString() + ' tokens';
    const budget: number = this.activeConfig !== null ? this.activeConfig.contextTokensIn : 128000;
    if (est > Math.floor(budget * 0.8)) hint = hint + ' · 接近上下文上限';
    return hint;
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
    this.lastUserText = text;
    this.stopRequested = false;
    // 编辑重发：截断到编辑位置，并记录需从数据库删除的消息
    let base: ChatMessage[] = this.messages;
    const removedIds: string[] = [];
    if (this.editTargetIndex >= 0 && this.editTargetIndex < base.length) {
      for (let i: number = this.editTargetIndex; i < base.length; i++) {
        removedIds.push(base[i].id);
      }
      base = base.slice(0, this.editTargetIndex);
      this.editTargetIndex = -1;
    }
    const userMessage: ChatMessage = ChatMessage.create('user', text);
    userMessage.modelId = config.id;
    userMessage.modelName = this.currentModelName();
    if (this.attachmentDataUrl.length > 0) {
      userMessage.imageDataUrl = this.attachmentDataUrl;
    }
    this.attachmentDataUrl = '';
    this.attachmentName = '';
    const assistantMessage: ChatMessage = ChatMessage.create('assistant', '');
    const newMessages: ChatMessage[] = base.concat([userMessage, assistantMessage]);
    this.messages = newMessages;
    this.sending = true;
    this.streaming = true;
    this.chatVm.start();
    this.streamingContent = '';
    this.streamingReasoning = '';
    this.scrollToBottom();

    const history: ChatMessage[] = ChatRepository.requestMessages(
      newMessages.slice(0, newMessages.length - 1), config.contextTokensIn);
    const result: LlmResult = await LlmClient.postCompletionStream(config, history,
      (delta: string) => {
        // 流式增量先累积，再定时一次性刷新（约 60ms），避免每个分片都触发整条重渲染
        this.streamingContent = this.streamingContent + delta;
        this.chatVm.markStreaming();
        this.scheduleRenderFlush(assistantMessage);
      },
      (reasoningDelta: string) => {
        this.streamingReasoning = this.streamingReasoning + reasoningDelta;
        this.scheduleRenderFlush(assistantMessage);
      }, new AiCallContext('chat'));
    this.sending = false;
    this.streaming = false;
    this.chatVm.finish();
    // 取消尚未触发的流式刷新定时器：此时 streamingContent 即将被清空，
    // 若定时器稍后触发会把空字符串写回消息，覆盖刚设置好的最终内容
    this.cancelRenderFlush();
    this.streamRequest = null;
    // 记录状态与用量
    assistantMessage.status = result.success ? 'ok' : 'failed';
    assistantMessage.errorCode = result.errorCode;
    assistantMessage.errorMessage = result.errorMessage;
    assistantMessage.modelId = config.id;
    assistantMessage.modelName = this.currentModelName();
    assistantMessage.inputTokens = result.tokenUsage.inputTokens;
    assistantMessage.cachedTokens = result.tokenUsage.cachedTokens;
    assistantMessage.outputTokens = result.tokenUsage.outputTokens;
    assistantMessage.totalTokens = result.tokenUsage.totalTokens;
    if (this.stopRequested) {
      // 用户主动停止：保留已生成内容，标记为 stopped；无内容则移除空回复
      this.stopRequested = false;
      if (this.streamingContent.length === 0 && this.streamingReasoning.length === 0) {
        this.messages = this.messages.filter((m: ChatMessage): boolean => m.id !== assistantMessage.id);
        this.streamingContent = '';
        this.streamingReasoning = '';
        await ChatRepository.deleteMessages(this.activeSessionId, removedIds);
        await ChatRepository.appendMessages(this.activeSessionId, [userMessage]);
        await ChatRepository.touchSession(this.activeSessionId);
        this.sessions = await ChatRepository.loadSessions();
        this.chatVm.finish();
        this.scrollToBottom();
        return;
      }
      assistantMessage.content = this.streamingContent;
      assistantMessage.reasoning = this.streamingReasoning;
      assistantMessage.status = 'stopped';
      this.streamingContent = '';
      this.streamingReasoning = '';
    } else if (result.success) {
      assistantMessage.content = result.content;
      assistantMessage.reasoning = result.reasoning;
      this.streamingContent = '';
      this.streamingReasoning = '';
    } else {
      assistantMessage.content = '⚠️ 请求失败：' + result.errorMessage;
      this.streamingContent = '';
      this.streamingReasoning = '';
    }
    // 持久化：编辑重发时先删除被替换的消息，再追加新消息
    try {
      if (removedIds.length > 0) {
        await ChatRepository.deleteMessages(this.activeSessionId, removedIds);
      }
      await ChatRepository.appendMessages(this.activeSessionId, [userMessage, assistantMessage]);
      await ChatRepository.touchSession(this.activeSessionId);
      this.sessions = await ChatRepository.loadSessions();
    } catch (e) {
      promptAction.showToast({ message: '消息保存失败' });
    }
    this.scrollToBottom();
  }

  // 停止当前流式请求（保留已生成内容，标记为 stopped）
  private stopStreaming(): void {
    this.stopRequested = true;
    if (this.streamRequest !== null) {
      try {
        this.streamRequest.destroy();
      } catch (e) {
      }
      this.streamRequest = null;
    }
    this.streaming = false;
    this.sending = false;
    this.chatVm.stopByUser();
    // 取消尚未触发的流式刷新定时器（避免其稍后用旧 streamingContent 覆盖）
    this.cancelRenderFlush();
    if (this.streamingContent.length === 0 && this.streamingReasoning.length === 0) {
      // 若停止时无内容，移除最后一条空的 assistant 消息
      if (this.messages.length > 0) {
        const last: ChatMessage = this.messages[this.messages.length - 1];
        if (last.role === 'assistant' && last.content.length === 0 && last.reasoning.length === 0) {
          this.messages = this.messages.slice(0, this.messages.length - 1);
        }
      }
    } else {
      // 有内容则保留已收到的部分
      if (this.messages.length > 0) {
        const last: ChatMessage = this.messages[this.messages.length - 1];
        if (last.role === 'assistant') {
          last.content = this.streamingContent;
          last.reasoning = this.streamingReasoning;
          last.status = 'stopped';
        }
      }
    }
    // 注意：不清空 streamingContent/streamingReasoning，
    // send() 恢复执行后需要依据它们决定是否保留已生成内容
  }

  // 重试上次失败的请求
  private async retryLast(): Promise<void> {
    if (this.sending || this.streaming) return;
    if (this.lastUserText.length === 0) {
      promptAction.showToast({ message: '无可重试的消息' });
      return;
    }
    const text: string = this.lastUserText;
    // 移除最后一条失败的 assistant 消息（内存 + 数据库）
    if (this.messages.length > 0) {
      const last: ChatMessage = this.messages[this.messages.length - 1];
      if (last.role === 'assistant' && last.content.indexOf('⚠️ 请求失败') === 0) {
        this.messages = this.messages.slice(0, this.messages.length - 1);
        await ChatRepository.deleteMessages(this.activeSessionId, [last.id]);
      }
    }
    this.inputText = text;
    await this.send();
  }

  // 重新生成：移除指定 assistant 消息及其后全部消息，重发该条之前的最近用户消息
  private async regenerateAssistant(index: number): Promise<void> {
    if (this.sending || this.streaming) return;
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const target: ChatMessage = displayed[index];
    if (target.role !== 'assistant') return;
    let userText: string = '';
    for (let i: number = index - 1; i >= 0; i--) {
      if (displayed[i].role === 'user') {
        userText = displayed[i].content;
        break;
      }
    }
    if (userText.length === 0) {
      promptAction.showToast({ message: '没有可重新生成的用户消息' });
      return;
    }
    // 按 id 定位到真实消息数组中的位置（搜索模式下索引可能不一致）
    let realIndex: number = -1;
    for (let i: number = 0; i < this.messages.length; i++) {
      if (this.messages[i].id === target.id) {
        realIndex = i;
        break;
      }
    }
    if (realIndex < 0) return;
    const removedIds: string[] = [];
    for (let i: number = realIndex; i < this.messages.length; i++) {
      removedIds.push(this.messages[i].id);
    }
    this.messages = this.messages.slice(0, realIndex);
    if (removedIds.length > 0) {
      await ChatRepository.deleteMessages(this.activeSessionId, removedIds);
    }
    this.closeActionSheet();
    this.inputText = userText;
    await this.send();
  }

  // 编辑用户消息并重发：载入输入框，发送时替换该条及其后全部消息
  private editUserMessage(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const target: ChatMessage = displayed[index];
    if (target.role !== 'user') return;
    let realIndex: number = -1;
    for (let i: number = 0; i < this.messages.length; i++) {
      if (this.messages[i].id === target.id) {
        realIndex = i;
        break;
      }
    }
    if (realIndex < 0) return;
    this.editTargetIndex = realIndex;
    this.inputText = target.content;
    this.closeActionSheet();
    promptAction.showToast({ message: '已载入编辑，发送后将替换后续消息' });
  }

  // 复制代码块内容（MarkdownText 回调）
  private copyCode(lang: string, code: string): void {
    this.copyText(code);
  }

  // 导出当前会话为 Markdown（复制到剪贴板）
  private async exportCurrentSession(): Promise<void> {
    let session: ChatSession | null = null;
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === this.activeSessionId) {
        session = this.sessions[i];
        break;
      }
    }
    if (session === null) {
      promptAction.showToast({ message: '会话不存在' });
      return;
    }
    const md: string = ChatExporter.toMarkdown(session, this.messages);
    this.copyText(md);
    this.closeSessionDrawer();
  }

  // 从剪贴板导入会话 JSON（智子导出的格式）
  private async importSessionFromClipboard(): Promise<void> {
    try {
      const pb: pasteboard.PasteData = await pasteboard.getSystemPasteboard().getData();
      let text: string = '';
      try {
        text = pb.getPrimaryText();
      } catch (e) {
        text = '';
      }
      if (text.trim().length === 0) {
        promptAction.showToast({ message: '剪贴板中没有可导入的内容' });
        return;
      }
      const imported: ImportedChat | null = ChatExporter.parseImport(text.trim());
      if (imported === null) {
        promptAction.showToast({ message: '格式无效：请复制智子导出的 JSON' });
        return;
      }
      const session: ChatSession = await ChatRepository.createSession(imported.title);
      await ChatRepository.appendMessages(session.id, imported.messages);
      this.sessions = await ChatRepository.loadSessions();
      this.activeSessionId = session.id;
      await ChatRepository.setActiveSessionId(session.id);
      this.messages = await ChatRepository.loadMessages(session.id);
      this.closeSessionDrawer();
      promptAction.showToast({ message: '已导入 ' + imported.messages.length.toString() + ' 条消息' });
    } catch (e) {
      promptAction.showToast({ message: '读取剪贴板失败' });
    }
  }

  // 直接滚动到底部，去除 setTimeout 队列堆积
  private scrollToBottom(): void {
    this.scrollController.scrollEdge(Edge.Bottom);
  }

  private formatTime(time: number): string {
    if (time <= 0) return '';
    const d: Date = new Date(time);
    const hh: string = d.getHours().toString().padStart(2, '0');
    const mm: string = d.getMinutes().toString().padStart(2, '0');
    return hh + ':' + mm;
  }

  // ---- 消息操作（复制/分享/删除） ----

  // 长按消息：弹出单条操作面板（复制/分享/多选/删除）
  private showActionSheet(index: number): void {
    this.actionSheetIndex = index;
  }

  private closeActionSheet(): void {
    this.actionSheetIndex = -1;
  }

  // 操作面板消息预览文本（截取前 80 字）
  private actionSheetPreviewText(): string {
    const m: ChatMessage | null = this.actionSheetMessage();
    if (m === null) return '';
    const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
    const raw: string = roleName + '：' + m.content;
    return raw.length > 80 ? raw.substring(0, 80) + '…' : raw;
  }

  private actionSheetMessage(): ChatMessage | null {
    const displayed: ChatMessage[] = this.displayMessages();
    if (this.actionSheetIndex < 0 || this.actionSheetIndex >= displayed.length) return null;
    return displayed[this.actionSheetIndex];
  }

  // 操作面板按消息角色显示：用户消息 → 编辑重发；助手消息 → 重新生成
  private actionSheetRole(): string {
    const m: ChatMessage | null = this.actionSheetMessage();
    return m !== null ? m.role : 'assistant';
  }

  // 单条复制
  private copyMessage(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    this.copyText(displayed[index].content);
    this.closeActionSheet();
  }

  // 复制文本到剪贴板
  private copyText(text: string): void {
    if (text.length === 0) return;
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pb.setData(data);
      promptAction.showToast({ message: '已复制到剪贴板' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // 单条分享：拉起系统分享面板
  private shareMessage(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const m: ChatMessage = displayed[index];
    this.shareText(this.formatMessageForShare(m));
    this.closeActionSheet();
  }

  // 批量分享
  private shareSelected(): void {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '请先选择消息' });
      return;
    }
    this.shareText(this.formatSelectedForShare());
  }

  // 拼接单条消息为分享文本
  private formatMessageForShare(m: ChatMessage): string {
    const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
    let text: string = roleName + '：' + m.content;
    if (m.reasoning.trim().length > 0) {
      text = roleName + '（思考过程）\n' + m.reasoning.trim() + '\n\n' + text;
    }
    return text + '\n\n—— 来自 智子 AI 助手';
  }

  // 拼接选中的多条消息（按时间顺序）
  private formatSelectedForShare(): string {
    const selected: ChatMessage[] = this.messages.filter((m: ChatMessage): boolean =>
      this.selectedIds.indexOf(m.id) >= 0);
    selected.sort((a: ChatMessage, b: ChatMessage): number => a.time - b.time);
    let text: string = '';
    for (let i: number = 0; i < selected.length; i++) {
      const m: ChatMessage = selected[i];
      const roleName: string = m.role === 'user' ? '用户' : '智子 AI';
      if (i > 0) text = text + '\n\n';
      text = text + roleName + '：' + m.content;
    }
    return text + '\n\n—— 来自 智子 AI 助手';
  }

  // 批量复制
  private copySelected(): void {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '请先选择消息' });
      return;
    }
    this.copyText(this.formatSelectedForShare());
    this.exitSelectionMode();
  }

  // 拉起系统分享面板分享文本
  private shareText(text: string): void {
    if (text.length === 0) return;
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: text
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const options: systemShare.ShareControllerOptions = {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      };
      controller.show(context, options).catch((e: Object) => {
        // 用户取消分享面板时忽略错误
      });
    } catch (e) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  // 多选模式中单条删除：从选中列表移除
  private deleteSingle(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const target: ChatMessage = displayed[index];
    this.selectedIds = [target.id];
    this.deleteSelected();
    this.closeActionSheet();
  }

  // 进入多选模式（从操作面板触发）
  private enterMultiSelectFromSheet(): void {
    const m: ChatMessage | null = this.actionSheetMessage();
    this.selectionMode = true;
    this.selectedIds = m !== null ? [m.id] : [];
    this.closeActionSheet();
  }

  // ---- 多选删除 ----

  private isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelect(index: number): void {
    const displayed: ChatMessage[] = this.displayMessages();
    if (index < 0 || index >= displayed.length) return;
    const id: string = displayed[index].id;
    if (this.isSelected(id)) {
      this.selectedIds = this.selectedIds.filter((i: string): boolean => i !== id);
    } else {
      this.selectedIds = this.selectedIds.concat([id]);
    }
  }

  private exitSelectionMode(): void {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  // 删除选中的消息
  private async deleteSelected(): Promise<void> {
    if (this.selectedIds.length === 0) {
      this.exitSelectionMode();
      return;
    }
    const count: number = this.selectedIds.length;
    AlertDialog.show({
      title: '删除消息',
      message: '确定删除选中的 ' + count.toString() + ' 条消息吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          const remaining: ChatMessage[] = await ChatRepository.deleteMessages(this.activeSessionId, this.selectedIds);
          this.messages = remaining.length > 0 ? remaining : [];
          this.exitSelectionMode();
          if (this.messages.length === 0) {
            const welcome: ChatMessage = ChatMessage.create('assistant',
              '你好，我是智子 AI 助手。请先点击右上角完成大模型 API 配置，然后就可以开始对话了。');
            this.messages = [welcome];
          }
          promptAction.showToast({ message: '已删除 ' + count.toString() + ' 条消息' });
        }
      }
    });
  }

  // ---- 全屏 markdown 查看 ----

  private openFullscreen(index: number): void {
    this.fullscreenIndex = index;
  }

  private closeFullscreen(): void {
    this.fullscreenIndex = -1;
  }

  // 展开思考后滚动定位到对应消息
  private expandReasoning(index: number): void {
    if (index >= 0) {
      this.scrollController.scrollToIndex(index, true);
    }
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
      .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
      .borderRadius(10)
      .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
      .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)

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
  modelPicker() {
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
              .onClick(() => { this.showModelPicker = false; })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 8 })

          if (this.enabledModels().length > 0) {
            Scroll() {
              Column({ space: 4 }) {
                ForEach(this.enabledModels(), (m: LlmModelEntry, index: number) => {
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
          } else {
            Text('没有已启用的模型，请到模型管理中启用')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding({ top: 16, bottom: 16 })
          }
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
    .onClick(() => { this.showModelPicker = false; })
  }

  build() {
    Stack() {
      // 全局背景层：与首页/其他子页保持一致的视觉氛围
      GlobalBackgroundLayer()
      Column() {
        TopBar({
          title: this.selectionMode ? '已选 ' + this.selectedIds.length.toString() + ' 条' : 'AI 对话',
          subtitle: this.selectionMode ? '长按消息进入多选' : (this.showSearch ? '搜索模式' : this.configHint),
          showLeading: true,
          onLeadingTap: (): void => { this.openSessionDrawer(); }
        }) {
          if (this.selectionMode) {
            Row({ space: 16 }) {
              Text('删除')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.danger)
                .fontWeight(FontWeight.Medium)
                .onClick(() => { this.deleteSelected(); })
              Text('取消')
                .fontSize(14)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .onClick(() => { this.exitSelectionMode(); })
            }
          } else {
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
        }

        // 搜索栏
        if (this.showSearch && !this.selectionMode) {
          this.searchBar()
        }

        // 消息列表
        if (this.messages.length === 0) {
          this.emptyWelcome()
        } else if (this.showSearch && !this.selectionMode && this.searchResultCount() === 0) {
          this.searchEmpty()
        } else {
          List({ space: 12, scroller: this.scrollController }) {
            ForEach(this.selectionMode ? this.messages : (this.showSearch ? this.displayMessages() : this.messages),
              (message: ChatMessage, index: number) => {
              ListItem() {
                // 使用子组件，通过 @ObjectLink 监听 @Observed ChatMessage 的变化
                ChatMessageBubble({ message: message, index: index,
                  selectionMode: this.selectionMode,
                  selected: this.isSelected(message.id),
                  isStreaming: this.streaming,
                  onRetry: (i: number): void => { this.retryLast(); },
                  onLongPressMessage: (i: number): void => { this.showActionSheet(i); },
                  onToggleSelect: (i: number): void => { this.toggleSelect(i); },
                  onExpandReasoning: (i: number): void => { this.expandReasoning(i); },
                  onFullscreen: (i: number): void => { this.openFullscreen(i); },
                  onCopyCode: (lang: string, code: string): void => { this.copyCode(lang, code); } })
              }
            }, (message: ChatMessage) => message.id)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12 })
        }

        // 底部区域
        if (this.selectionMode) {
          Row({ space: 8 }) {
            Button(this.selectedIds.length === 0 ? '全选' : '取消全选')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => {
                if (this.selectedIds.length === this.messages.length) {
                  this.selectedIds = [];
                } else {
                  this.selectedIds = this.messages.map((m: ChatMessage): string => m.id);
                }
              })
            Button('复制')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => { this.copySelected(); })
            Button('分享')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.bgSurface)
              .fontColor(this.palette.textPrimary)
              .borderRadius(8)
              .onClick(() => { this.shareSelected(); })
            Button('删除 (' + this.selectedIds.length.toString() + ')')
              .fontSize(this.palette.fsSm)
              .fontFamily(this.palette.fontSans)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.palette.danger)
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => { this.deleteSelected(); })
          }
          .width('100%')
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8,
            bottom: Math.max(8, this.navBarHeight) })
        } else if (this.showSearch) {
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
          .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
          .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
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
              .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
              .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
              .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
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
            .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
            .backgroundBlurStyle(this.glassEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .onClick(() => {
              if (this.enabledModels().length > 0) {
                this.showModelPicker = true;
              } else if (this.models.length > 0) {
                promptAction.showToast({ message: '所有模型均已禁用，请先启用' });
              } else {
                promptAction.showToast({ message: '请先配置模型' });
              }
            })
            ChatInputBar({
              inputText: this.inputText,
              inputHeight: this.inputHeight,
              sending: this.sending,
              streaming: this.streaming,
              chatPhase: this.chatPhase,
              elapsedSeconds: this.elapsedSeconds,
              tokenHint: this.inputTokenHint(),
              sessionTokensText: (!this.showSearch && this.messages.length > 0)
                ? ChatRepository.estimateSessionTokens(this.messages).toString() + ' tokens 已用' : '',
              visionEnabled: this.activeConfig !== null && this.activeConfig.visionEnabled,
              attachmentName: this.attachmentName,
              onChangeText: (value: string): void => { this.onInputChange(value); },
              onSend: (): void => { this.send(); },
              onStop: (): void => { this.stopStreaming(); },
              onPickImage: (): void => { this.pickImageAttachment(); },
              onRemoveImage: (): void => { this.removeImageAttachment(); }
            })
          }
          .width('100%')
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 8, bottom: Math.max(8, this.navBarHeight) })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.bgBase)

      if (this.showModelPicker) { this.modelPicker() }
      if (this.showSessionDrawer) {
        ChatSessionDrawer({
          sessions: this.drawerSessions,
          activeSessionId: this.activeSessionId,
          drawerRenameId: this.drawerRenameId,
          drawerRenameText: this.drawerRenameText,
          onClose: (): void => { this.closeSessionDrawer(); },
          onNewSession: (): void => { this.newSession(); },
          onSwitchSession: (id: string): void => { this.switchSession(id); },
          onBeginRename: (id: string): void => { this.beginRenameSession(id); },
          onRenameTextChange: (value: string): void => { this.drawerRenameText = value; },
          onConfirmRename: (): void => { this.confirmRenameSession(); },
          onCancelRename: (): void => { this.drawerRenameId = ''; },
          onTogglePin: (id: string): void => { this.toggleSessionPin(id); },
          onDeleteSession: (id: string): void => { this.deleteSessionFromDrawer(id); },
          onExport: (): void => { this.exportCurrentSession(); },
          onImport: (): void => { this.importSessionFromClipboard(); },
          onSearchChange: (value: string): void => { this.onDrawerSearch(value); }
        })
      }

      // 长按消息操作面板（复制/分享/多选/删除）
      if (this.actionSheetIndex >= 0) {
        Stack() {
          Column() {
            Column({ space: 0 }) {
              // 消息预览（截取前 80 字）
              Text(this.actionSheetPreviewText())
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textTertiary)
                .lineHeight(18)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding(12)
              // 操作按钮
              Row({ space: 0 }) {
                if (this.actionSheetRole() === 'user') {
                  Column({ space: 4 }) {
                    Text('✏️')
                      .fontSize(22)
                      .fontFamily(this.palette.fontSans)
                    Text('编辑')
                      .fontSize(11)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textSecondary)
                  }
                  .layoutWeight(1)
                  .padding({ top: 8, bottom: 8 })
                  .onClick(() => { this.editUserMessage(this.actionSheetIndex); })
                } else {
                  Column({ space: 4 }) {
                    Text('🔄')
                      .fontSize(22)
                      .fontFamily(this.palette.fontSans)
                    Text('重新生成')
                      .fontSize(11)
                      .fontFamily(this.palette.fontSans)
                      .fontColor(this.palette.textSecondary)
                  }
                  .layoutWeight(1)
                  .padding({ top: 8, bottom: 8 })
                  .onClick(() => { this.regenerateAssistant(this.actionSheetIndex); })
                }

                Column({ space: 4 }) {
                  Text('📋')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('复制')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.copyMessage(this.actionSheetIndex); })

                Column({ space: 4 }) {
                  Text('📤')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('分享')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.shareMessage(this.actionSheetIndex); })

                Column({ space: 4 }) {
                  Text('☑️')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('多选')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.enterMultiSelectFromSheet(); })

                Column({ space: 4 }) {
                  Text('🗑️')
                    .fontSize(22)
                    .fontFamily(this.palette.fontSans)
                  Text('删除')
                    .fontSize(11)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textSecondary)
                }
                .layoutWeight(1)
                .padding({ top: 8, bottom: 8 })
                .onClick(() => { this.deleteSingle(this.actionSheetIndex); })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })

              // 取消
              Text('取消')
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor(this.palette.textSecondary)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .height(44)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.palette.bgSurface)
                .borderRadius(10)
                .onClick(() => { this.closeActionSheet(); })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette.bgBase)
            .borderRadius({ topLeft: 16, topRight: 16 })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick(() => { this.closeActionSheet(); })
      }

      // 全屏 markdown 查看（双击助手消息打开）
      if (this.fullscreenIndex >= 0) {
        Stack() {
          Column() {
            Row() {
              Text('Markdown 预览')
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
                .onClick(() => { this.closeFullscreen(); })
            }
            .width('100%')
            .padding({ left: 16, right: 8, top: 12, bottom: 8 })

            // 全屏 markdown 渲染（Web 组件，带滚动）
            Scroll() {
              Column() {
                if (this.fullscreenIndex >= 0 && this.fullscreenIndex < this.messages.length) {
                  Web({ src: 'about:blank',
                    controller: this.fullscreenController })
                    .width('100%')
                    .height(2000)
                    .backgroundColor(Color.Transparent)
                    .onControllerAttached(() => {
                      const m: ChatMessage = this.messages[this.fullscreenIndex];
                      const content: string = m.reasoning.trim().length > 0 ?
                        '💭 思考过程\n\n' + m.reasoning.trim() + '\n\n---\n\n' + m.content : m.content;
                      this.fullscreenController.loadData(
                        MarkdownConverter.toHtml(content, this.isDark), 'text/html', 'UTF-8', 'data');
                    })
                }
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .layoutWeight(1)
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor(this.palette.bgBase)
          .padding({ bottom: Math.max(0, this.navBarHeight) })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
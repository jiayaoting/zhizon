// 智子 - 聊天消息列表（渲染隔离组件）
// 数据由父组件通过 LazyListDataSource 驱动（仅在消息增删/分页/搜索/多选时 replace），
// 输入框每次按键等高频父组件状态变化不会重建本组件，避免整条消息列表反复 diff。
import { ChatMessage } from '../common/LlmModels';
import { LazyListDataSource } from '../common/LazyDataSource';
import { ChatMessageBubble } from './ChatMessageBubble';

@Component
export struct ChatMessageList {
  @StorageLink('isSm') isSm: boolean = false;
  // 消息数据源（父组件维护；普通模式=消息窗口，搜索模式=过滤结果）
  source: LazyListDataSource<ChatMessage> = new LazyListDataSource<ChatMessage>([]);
  // 滚动控制器（父组件持有：发送后滚底、补载后保持位置）
  scroller: Scroller = new Scroller();
  @Prop isStreaming: boolean = false;
  @Prop selectionMode: boolean = false;
  @Prop speakingId: string = '';
  onReachStart: () => void = () => {};
  onRetry: (index: number) => void = () => {};
  onLongPressMessage: (index: number) => void = () => {};
  onToggleSelect: (index: number) => void = () => {};
  onExpandReasoning: (index: number) => void = () => {};
  onFullscreen: (index: number) => void = () => {};
  onCopyCode: (lang: string, code: string) => void = () => {};
  onSpeak: (index: number) => void = () => {};
  isSelected: (id: string) => boolean = (): boolean => false;

  build() {
    List({ space: 12, scroller: this.scroller }) {
      LazyForEach(this.source, (message: ChatMessage, index: number) => {
        ListItem() {
          ChatMessageBubble({ message: message, index: index,
            selectionMode: this.selectionMode,
            selected: this.isSelected(message.id),
            isStreaming: this.isStreaming,
            speaking: this.speakingId === message.id,
            onRetry: this.onRetry,
            onLongPressMessage: this.onLongPressMessage,
            onToggleSelect: this.onToggleSelect,
            onExpandReasoning: this.onExpandReasoning,
            onFullscreen: this.onFullscreen,
            onCopyCode: this.onCopyCode,
            onSpeak: this.onSpeak })
        }
      }, (message: ChatMessage) => message.id)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12 })
    .onReachStart(() => { this.onReachStart(); })
  }
}

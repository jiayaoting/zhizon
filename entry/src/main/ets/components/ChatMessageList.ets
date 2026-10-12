// 智子 - 聊天消息列表（渲染隔离组件）
// 数据由父组件通过 LazyListDataSource 驱动（仅在消息增删/分页/搜索/多选时 replace），
// 输入框每次按键等高频父组件状态变化不会重建本组件，避免整条消息列表反复 diff。
// v10：消息流底色 bgBase，条目间距 sp3，左右留白按断点取 pagePadding / pagePaddingLg。
import { AppStorageV2 } from '@kit.ArkUI';
import { ChatMessage } from '../common/LlmModels';
import { LazyListDataSource } from '../common/LazyDataSource';
import { ThemeState } from '../common/ThemeState';
import { ChatMessageBubble } from './ChatMessageBubble';

@ComponentV2
export struct ChatMessageList {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 消息数据源（父组件维护；普通模式=消息窗口，搜索模式=过滤结果）
  // v10：V2 父组件只能初始化子组件的 @Param/@Event，故由普通属性改为 @Param
  @Param source: LazyListDataSource<ChatMessage> = new LazyListDataSource<ChatMessage>([]);
  // 滚动控制器（父组件持有：发送后滚底、补载后保持位置）
  @Param scroller: Scroller = new Scroller();
  @Param isStreaming: boolean = false;
  @Param selectionMode: boolean = false;
  @Param speakingId: string = '';
  @Event onReachStart: () => void = () => {};
  @Event onRetry: (index: number) => void = () => {};
  @Event onLongPressMessage: (index: number) => void = () => {};
  @Event onToggleSelect: (index: number) => void = () => {};
  @Event onExpandReasoning: (index: number) => void = () => {};
  @Event onFullscreen: (index: number) => void = () => {};
  @Event onCopyCode: (lang: string, code: string) => void = () => {};
  @Event onSpeak: (index: number) => void = () => {};
  @Event isSelected: (id: string) => boolean = (): boolean => false;

  build() {
    List({ space: this.themeState.palette.sp3, scroller: this.scroller }) {
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
    .backgroundColor(this.themeState.palette.bgBase)
    .padding({ left: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg,
      right: this.themeState.isSm ? this.themeState.palette.pagePadding : this.themeState.palette.pagePaddingLg, top: this.themeState.palette.sp3 })
    .onReachStart(() => { this.onReachStart(); })
  }
}

// 智子 - 聊天输入条（多行自动增高、发送/停止三态、状态与 Token 提示）
import { ThemePalette, defaultLightPalette } from '../common/Theme';

@Component
export struct ChatInputBar {
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('isDarkMode') isDark: boolean = false;
  @Prop inputText: string = '';
  @Prop inputHeight: number = 44;
  @Prop sending: boolean = false;
  @Prop streaming: boolean = false;
  @Prop chatPhase: string = 'idle';
  @Prop elapsedSeconds: number = 0;
  @Prop tokenHint: string = '';
  @Prop sessionTokensText: string = '';
  @Prop visionEnabled: boolean = false;
  @Prop attachmentName: string = '';
  onChangeText: (value: string) => void = () => {};
  onSend: () => void = () => {};
  onStop: () => void = () => {};
  onPickImage: () => void = () => {};
  onRemoveImage: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      // 图片附件预览（vision 模型可选图）
      if (this.attachmentName.length > 0) {
        Row({ space: 6 }) {
          Text('🖼 ')
            .fontSize(12)
            .fontFamily(this.palette.fontSans)
          Text(this.attachmentName)
            .fontSize(11)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('✕')
            .fontSize(13)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .padding(4)
            .onClick(() => { this.onRemoveImage(); })
        }
        .width('100%')
        .padding({ left: 10, right: 6, top: 4, bottom: 4 })
        .borderRadius(8)
        .backgroundColor(this.palette.bgSurface2)
      }
      Row({ space: 8 }) {
        // 附件按钮：仅 vision 模型且未在生成中显示
        if (this.visionEnabled && !this.streaming && !this.sending) {
          Row() {
            Text('+')
              .fontSize(18)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textSecondary)
          }
          .width(40)
          .height(this.inputHeight)
          .borderRadius(10)
          .backgroundColor(this.palette.bgSurface)
          .border({ width: 1, color: this.palette.borderSubtle })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.onPickImage(); })
        }
        TextArea({ text: this.inputText, placeholder: '输入消息…' })
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .placeholderColor(this.palette.textTertiary)
          .backgroundColor(this.palette.bgSurface)
          .borderRadius(10)
          .border({ width: 1, color: this.palette.borderSubtle })
          .height(this.inputHeight)
          .layoutWeight(1)
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => { this.onChangeText(value); })
          .onSubmit(() => { this.onSend(); })
        // 流式过程中显示停止按钮，否则显示发送按钮
        if (this.streaming) {
          Row() {
            Text('■')
              .fontSize(14)
              .fontFamily(this.palette.fontSans)
              .fontColor('#FFFFFF')
          }
          .height(this.inputHeight)
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .backgroundColor(this.palette.danger)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.onStop(); })
        } else {
          Row() {
            if (this.sending) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color('#FFFFFF')
            } else {
              Text('发送')
                .fontSize(this.palette.fsSm)
                .fontFamily(this.palette.fontSans)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
            }
          }
          .height(this.inputHeight)
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .backgroundColor(this.palette.primary)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.onSend(); })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      // 状态与提示行：连接中 / 生成计时 / Token 估算
      Row({ space: 8 }) {
        if (this.chatPhase === 'connecting') {
          Text('正在连接…')
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        } else if (this.chatPhase === 'streaming') {
          Text('生成中 ' + this.elapsedSeconds.toString() + 's')
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        } else if (this.tokenHint.length > 0) {
          Text(this.tokenHint)
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        } else {
          Text('Enter 发送 · 可多行输入')
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
        Blank()
        if (this.sessionTokensText.length > 0) {
          Text(this.sessionTokensText)
            .fontSize(10)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
        }
      }
      .width('100%')
    }
    .width('100%')
  }

}

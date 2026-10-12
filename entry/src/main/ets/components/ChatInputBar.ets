// 智子 - 聊天输入条（v10 华为智慧助手式输入胶囊）
// 结构：单个圆角胶囊容器（radiusCapsule + bgSurface + 发丝分割线）内嵌无边框 TextArea，
//      胶囊内尾随 📷 图片 / 📄 OCR / 🎙 语音操作，右侧悬浮圆形发送钮（流式中变 danger 停止钮）。
// 保留：多行自动增高、发送/停止三态、状态与 Token 预算提示、语音听写、附件预览。
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { AppIcons, USE_SYMBOL_ICONS } from '../common/AppIcons';

@ComponentV2
export struct ChatInputBar {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Param inputText: string = '';
  @Param inputHeight: number = 48;
  @Param sending: boolean = false;
  @Param streaming: boolean = false;
  @Param chatPhase: string = 'idle';
  @Param elapsedSeconds: number = 0;
  @Param tokenHint: string = '';
  @Param sessionTokens: number = 0;
  @Param contextTokens: number = 128000;
  @Param visionEnabled: boolean = false;
  @Param attachmentName: string = '';
  @Param recognizing: boolean = false;
  @Param webSearchBusy: boolean = false;
  @Param ocrBusy: boolean = false;
  @Event onChangeText: (value: string) => void = () => {};
  @Event onSend: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onPickImage: () => void = () => {};
  @Event onRemoveImage: () => void = () => {};
  @Event onMicTap: () => void = () => {};
  @Event onOcrTap: () => void = () => {};

  // 上下文预算百分比（0-100）
  private budgetPercent(): number {
    if (this.contextTokens <= 0) return 0;
    const p: number = Math.round(this.sessionTokens / this.contextTokens * 100);
    if (p < 0) return 0;
    return p > 100 ? 100 : p;
  }

  // 输入框高度：华为输入胶囊最小 48vp，随内容增高（上限由父组件限制）
  private textAreaHeight(): number {
    return this.inputHeight < 48 ? 48 : this.inputHeight;
  }

  // 胶囊内尾随操作钮：44×44 触控目标，矢量图标跟随 textSecondary
  @Builder
  capsuleAction(icon: Resource, emoji: string, label: string, onTap: () => void) {
    Row() {
      if (USE_SYMBOL_ICONS) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([this.themeState.palette.textSecondary])
      } else {
        Text(emoji)
          .fontSize(18)
          .fontFamily(this.themeState.palette.fontSans)
      }
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusCapsule)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(label)
    .onClick(onTap)
  }

  // 听写中的停止钮（danger 实底 + ■），与发送钮形成"录制/发送"两态
  @Builder
  recordingStop() {
    Row() {
      Text('■')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.primaryOnColor)
    }
    .width(this.themeState.palette.touchTarget)
    .height(this.themeState.palette.touchTarget)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.themeState.palette.danger)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText('结束听写')
    .onClick(() => { this.onMicTap(); })
  }

  // 悬浮圆形发送 / 停止钮（≥44vp，主色/危险色实底 + 轻阴影）
  @Builder
  sendButton() {
    Row() {
      if (this.streaming) {
        Text('■')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
      } else if (this.sending) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.themeState.palette.primaryOnColor)
      } else if (USE_SYMBOL_ICONS) {
        SymbolGlyph(AppIcons.forward)
          .fontSize(24)
          .fontColor([this.themeState.palette.primaryOnColor])
      } else {
        Text(AppIcons.forwardEmoji)
          .fontSize(24)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primaryOnColor)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(48)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.themeState.palette.radiusCapsule)
    .backgroundColor(this.streaming ? this.themeState.palette.danger : this.themeState.palette.primary)
    .shadow({ radius: 10, color: this.themeState.palette.maskOverlay, offsetX: 0, offsetY: 3 })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .accessibilityText(this.streaming ? '停止生成' : '发送')
    .onClick(() => {
      if (this.streaming) {
        this.onStop();
      } else {
        this.onSend();
      }
    })
  }

  build() {
    Column({ space: this.themeState.palette.sp2 }) {
      // 图片附件预览（vision 模型可选图）
      if (this.attachmentName.length > 0) {
        Row({ space: 6 }) {
          if (USE_SYMBOL_ICONS) {
            SymbolGlyph(AppIcons.photo)
              .fontSize(16)
              .fontColor([this.themeState.palette.textSecondary])
          } else {
            Text(AppIcons.photoEmoji)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
          }
          Text(this.attachmentName)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Row() {
            if (USE_SYMBOL_ICONS) {
              SymbolGlyph(AppIcons.close)
                .fontSize(16)
                .fontColor([this.themeState.palette.textTertiary])
            } else {
              Text(AppIcons.closeEmoji)
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
            }
          }
          .width(32)
          .height(32)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .accessibilityText('移除图片')
          .onClick(() => { this.onRemoveImage(); })
        }
        .width('100%')
        .padding({ left: 12, right: 4, top: 4, bottom: 4 })
        .borderRadius(this.themeState.palette.radiusSm)
        .backgroundColor(this.themeState.palette.bgSurface2)
      }

      // 输入胶囊 + 悬浮发送钮
      Row({ space: this.themeState.palette.sp2 }) {
        Row({ space: 0 }) {
          // 无边框 TextArea：直接铺在胶囊里，不再套一层输入框外观
          TextArea({ text: this.inputText, placeholder: this.recognizing ? '正在听写…' : '输入消息…' })
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .placeholderColor(this.themeState.palette.textTertiary)
            .caretColor(this.themeState.palette.primary)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .height(this.textAreaHeight())
            .layoutWeight(1)
            .padding({ left: 6, right: 4, top: 4, bottom: 4 })
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => { this.onChangeText(value); })
            .onSubmit(() => { this.onSend(); })
          // 胶囊内尾随操作：图片（仅 vision 模型） / OCR / 语音
          if (this.visionEnabled && !this.streaming && !this.sending) {
            this.capsuleAction(AppIcons.photo, AppIcons.photoEmoji, '选择图片', (): void => {
              this.onPickImage();
            })
          }
          if (!this.streaming && !this.sending) {
            if (this.ocrBusy) {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(this.themeState.palette.primary)
              }
              .width(this.themeState.palette.touchTarget)
              .height(this.themeState.palette.touchTarget)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
            } else {
              this.capsuleAction(AppIcons.doc, AppIcons.docEmoji, '图片取字', (): void => {
                this.onOcrTap();
              })
            }
            if (this.recognizing) {
              this.recordingStop()
            } else {
              this.capsuleAction(AppIcons.mic, AppIcons.micEmoji, '语音输入', (): void => {
                this.onMicTap();
              })
            }
          }
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 52 })
        .borderRadius(this.themeState.palette.radiusCapsule)
        .backgroundColor(this.themeState.palette.bgSurface)
        .border({ width: 1, color: this.themeState.palette.divider })
        .padding({ left: 10, right: 4, top: 2, bottom: 2 })
        .alignItems(VerticalAlign.Bottom)

        this.sendButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      // 状态与提示行：连接中 / 生成计时 / Token 估算 / 听写状态
      Row({ space: 8 }) {
        if (this.recognizing) {
          Text('正在听写… 点击停止结束')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.danger)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        } else if (this.chatPhase === 'connecting') {
          Text('正在连接…')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .layoutWeight(1)
        } else if (this.chatPhase === 'streaming') {
          Text('生成中 ' + this.elapsedSeconds.toString() + 's')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .layoutWeight(1)
        } else if (this.webSearchBusy) {
          Text('正在联网搜索…')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.primary)
            .layoutWeight(1)
        } else if (this.tokenHint.length > 0) {
          Text(this.tokenHint)
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .layoutWeight(1)
        } else {
          Text('Enter 发送 · 可多行输入 · 支持语音输入')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        // 上下文预算：进度条 + 用量文字
        if (this.sessionTokens > 0) {
          Row({ space: 6 }) {
            Progress({ value: this.budgetPercent(), total: 100, type: ProgressType.Linear })
              .width(72)
              .height(4)
              .color(this.budgetPercent() >= 80 ? this.themeState.palette.warning :
                (this.budgetPercent() >= 95 ? this.themeState.palette.danger : this.themeState.palette.primary))
              .backgroundColor(this.themeState.palette.bgSurface2)
            Text(this.sessionTokens.toString() + ' / ' + this.contextTokens.toString() + ' tokens')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.budgetPercent() >= 80 ? this.themeState.palette.warning : this.themeState.palette.textTertiary)
          }
        }
      }
      .width('100%')
    }
    .width('100%')
  }

}

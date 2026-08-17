// 智子 - AI 模型主页（模型配置 + 调用记录入口）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppNavigator } from '../common/AppNavigator';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { AiCallLogger } from '../service/AiCallLogger';

@ComponentV2
@Entry
export struct AiModelPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local logCount: number = 0;
        
  aboutToAppear(): void {
    this.refreshCount();
  }

  private async refreshCount(): Promise<void> {
    try {
      this.logCount = await AiCallLogger.getLogCount();
    } catch (e) {
      this.logCount = 0;
    }
  }

  onPageShow(): void {
    this.refreshCount();
  }

  // 入口卡片
  @Builder
  entryCard(icon: string, title: string, desc: string, onClick: () => void) {
    Row({ space: 14 }) {
      Text(icon)
        .fontSize(26)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(this.themeState.palette.fsBase)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(desc)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .onClick(onClick)
  }

  build() {
    Column() {
      TopBar({
        title: 'AI 模型',
        subtitle: '模型配置与调用记录',
        showBack: true
      })

      Scroll() {
        Column({ space: 12 }) {
          this.entryCard('🤖', '模型配置', '添加、编辑大模型，切换对话使用的模型', () => {
            AppNavigator.push('pages/ChatConfig');
          })
          this.entryCard('📋', '调用记录', this.logCount > 0 ? '共 ' + this.logCount.toString() + ' 条 AI 调用记录' : '查看 AI 调用记录', () => {
            AppNavigator.push('pages/AiCallLog');
          })

          Text('在对话中可随时切换模型，游戏 AI 托管也会记录调用摘要。')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
            .width('100%')
            .lineHeight(16)
            .padding({ left: 4, right: 4, top: 8 })
        }
        .width('100%')
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12,
          bottom: Math.max(16, this.themeState.navBarHeight) })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

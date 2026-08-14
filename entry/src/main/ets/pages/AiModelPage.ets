// 智子 - AI 模型主页（模型配置 + 调用记录入口）
import { promptAction, router } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { AiCallLogger } from '../service/AiCallLogger';

@Entry
@Component
struct AiModelPage {
  @State logCount: number = 0;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;

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
          .fontSize(this.palette.fsBase)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(desc)
          .fontSize(this.palette.fsSm)
          .fontFamily(this.palette.fontSans)
          .fontColor(this.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(this.palette.fsMd)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textTertiary)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
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
            router.pushUrl({ url: 'pages/ChatConfig' });
          })
          this.entryCard('📋', '调用记录', this.logCount > 0 ? '共 ' + this.logCount.toString() + ' 条 AI 调用记录' : '查看 AI 调用记录', () => {
            router.pushUrl({ url: 'pages/AiCallLog' });
          })

          Text('在对话中可随时切换模型，游戏 AI 托管也会记录调用摘要。')
            .fontSize(this.palette.fsXs)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textTertiary)
            .width('100%')
            .lineHeight(16)
            .padding({ left: 4, right: 4, top: 8 })
        }
        .width('100%')
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12,
          bottom: Math.max(16, this.navBarHeight) })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

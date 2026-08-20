// 智子 - 个性化频道设置（子页：全部打开/关闭 + 逐频道开关）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NEWS_CHANNELS } from '../common/NewsChannels';
import { NewsChannel } from '../common/NewsModels';
import { DataRepository } from '../service/DataRepository';

@ComponentV2
@Entry
export struct NewsChannelSettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 关闭个性化的频道 id 列表（默认空 = 全部频道个性化；新增频道自动默认启用）
  @Local offIds: string[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsPersonalizedChannels', '');
      if (raw.trim().length === 0) {
        this.offIds = [];
        return;
      }
      const parsed: Object = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const ids: string[] = [];
        const arr: Object[] = parsed as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') ids.push(arr[i] as string);
        }
        this.offIds = ids;
      }
    } catch (e) {
      this.offIds = [];
    }
  }

  private personalized(id: string): boolean {
    return this.offIds.indexOf(id) < 0;
  }

  private async save(off: string[]): Promise<void> {
    await DataRepository.setSetting('newsPersonalizedChannels', JSON.stringify(off));
    this.offIds = off;
  }

  private async setAll(on: boolean): Promise<void> {
    if (on) {
      await this.save([]);
      promptAction.showToast({ message: '全部频道已启用个性化' });
    } else {
      const all: string[] = [];
      for (let i: number = 0; i < NEWS_CHANNELS.length; i++) {
        all.push(NEWS_CHANNELS[i].id);
      }
      await this.save(all);
      promptAction.showToast({ message: '全部频道已关闭个性化' });
    }
  }

  private async toggle(id: string, on: boolean): Promise<void> {
    const off: string[] = this.offIds.slice();
    const idx: number = off.indexOf(id);
    if (on && idx >= 0) {
      off.splice(idx, 1);
    } else if (!on && idx < 0) {
      off.push(id);
    }
    await this.save(off);
  }

  @Builder
  toggleRow(channel: NewsChannel, enabled: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(channel.icon + ' ' + channel.name)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.themeState.palette.primary)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
  }

  build() {
    Column() {
      TopBar({ title: '个性化频道设置', subtitle: '关闭的频道恢复纯时间排序', showBack: true })

      Scroll() {
        Row() {
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Button('全部打开')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(Color.White)
                .backgroundColor(this.themeState.palette.primary)
                .borderRadius(14)
                .height(36)
                .layoutWeight(1)
                .enabled(this.offIds.length > 0)
                .onClick(() => { this.setAll(true); })
              Button('全部关闭')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(Color.White)
                .backgroundColor(this.themeState.palette.danger)
                .borderRadius(14)
                .height(36)
                .layoutWeight(1)
                .enabled(this.offIds.length < NEWS_CHANNELS.length)
                .onClick(() => { this.setAll(false); })
            }
            .width('100%')

            Column({ space: 8 }) {
              ForEach(NEWS_CHANNELS, (channel: NewsChannel) => {
                this.toggleRow(channel, this.personalized(channel.id), (v: boolean) => {
                  this.toggle(channel.id, v);
                })
              }, (channel: NewsChannel) => channel.id)
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })

            Text('新增频道自动默认启用个性化。')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')

            Column().height(20)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeState.palette.bgBase)
  }
}

// 智子 - 资讯源开关设置（子页：全部打开/关闭 + 逐源开关）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NEWS_SOURCES } from '../common/NewsChannels';
import { NewsSourceDef } from '../common/NewsModels';
import { DataRepository } from '../service/DataRepository';

@ComponentV2
@Entry
export struct NewsSourceSettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 启用的源 id 列表（空数组 = 全部启用；['__none__'] = 全部关闭）
  @Local enabledIds: string[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsEnabledSources', '');
      if (raw.trim().length === 0) {
        this.enabledIds = [];
        return;
      }
      const parsed: Object = JSON.parse(raw) as Object;
      if (Array.isArray(parsed)) {
        const ids: string[] = [];
        const arr: Object[] = parsed as Object[];
        for (let i: number = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') ids.push(arr[i] as string);
        }
        this.enabledIds = ids;
      }
    } catch (e) {
      this.enabledIds = [];
    }
  }

  private isEnabled(id: string): boolean {
    // 空列表 = 全部启用
    if (this.enabledIds.length === 0) return true;
    return this.enabledIds.indexOf(id) >= 0;
  }

  private allOn(): boolean {
    return this.enabledIds.length === 0;
  }

  private async save(ids: string[]): Promise<void> {
    await DataRepository.setSetting('newsEnabledSources', JSON.stringify(ids));
    this.enabledIds = ids;
  }

  private async setAll(on: boolean): Promise<void> {
    if (on) {
      await this.save([]);
      promptAction.showToast({ message: '已全部开启资讯源' });
    } else {
      await this.save(['__none__']);
      promptAction.showToast({ message: '已全部关闭资讯源' });
    }
  }

  private async toggle(id: string, on: boolean): Promise<void> {
    let ids: string[] = this.enabledIds.slice();
    // 空列表表示全部启用：第一次关闭某个源时，先展开为全部源列表
    if (ids.length === 0) {
      ids = [];
      for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
        ids.push(NEWS_SOURCES[i].id);
      }
    }
    const idx: number = ids.indexOf(id);
    if (on && idx < 0) {
      ids.push(id);
    } else if (!on && idx >= 0) {
      ids.splice(idx, 1);
    }
    // 全部选中 = 恢复空列表语义（全部启用）
    if (ids.length === NEWS_SOURCES.length) {
      ids = [];
    }
    await this.save(ids);
  }

  @Builder
  toggleRow(source: NewsSourceDef, enabled: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(source.name)
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
      TopBar({ title: '资讯源开关设置', subtitle: '关闭的源不再出现在资讯流中', showBack: true })

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
                .enabled(!this.allOn())
                .onClick(() => { this.setAll(true); })
              Button('全部关闭')
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(Color.White)
                .backgroundColor(this.themeState.palette.danger)
                .borderRadius(14)
                .height(36)
                .layoutWeight(1)
                .enabled(this.enabledIds.length > 0)
                .onClick(() => { this.setAll(false); })
            }
            .width('100%')

            Column({ space: 8 }) {
              ForEach(NEWS_SOURCES, (source: NewsSourceDef) => {
                this.toggleRow(source, this.isEnabled(source.id), (v: boolean) => {
                  this.toggle(source.id, v);
                })
              }, (source: NewsSourceDef) => source.id)
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })

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

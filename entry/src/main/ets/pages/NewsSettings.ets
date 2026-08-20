// 智子 - 资讯设置（二级页：资讯源/频道 / 个性化推荐 / AI 能力 / 自定义订阅）
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { AppNavigator } from '../common/AppNavigator';
import { NEWS_SOURCES } from '../common/NewsChannels';
import { NewsSourceDef } from '../common/NewsModels';
import { NewsModelSelector } from '../components/NewsModelSelector';
import { NewsAiService } from '../service/NewsAiService';
import { NewsRepository } from '../service/NewsRepository';
import { NewsService } from '../service/NewsService';
import { DataRepository } from '../service/DataRepository';
import { SettingGroupCard } from '../components/SettingGroupCard';
import { SettingRow, SettingSwitchRow } from '../components/SettingRow';

// 自定义 RSS 订阅持久化结构（settings.newsCustomRss）
interface CustomRssSetting {
  name: string;
  url: string;
}

@Component
@Entry
export struct NewsSettingsPage {
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  @StorageLink('navBarHeight') navBarHeight: number = 12;

  // 自定义 RSS
  @State customRssName: string = '';
  @State customRssUrl: string = '';
  @State customSources: NewsSourceDef[] = [];
  // LLM 智能标签开关（默认关闭，M4）
  @State newsTagLlmEnabled: boolean = false;
  // 个性化模式（M2 增强）：standard / aggressive / hot / explore
  @State newsPersonalizedMode: string = 'standard';
  // OPML 导入
  @State showOpmlSheet: boolean = false;
  @State opmlText: string = '';
  @State opmlResult: string = '';

  aboutToAppear(): void {
    this.loadTagLlmState();
    this.loadNewsMode();
    this.loadCustomRss();
  }

  private toast(msg: string) {
    promptAction.showToast({ message: msg });
  }

  // 危险操作统一确认（重置画像等不可恢复操作）
  private confirmDanger(title: string, message: string, onOk: () => void): void {
    promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: '#888888' },
        { text: '确认', color: '#E84026' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        onOk();
      }
    }).catch(() => {
    });
  }

  // ==================== LLM 智能标签（M4） ====================
  private async loadTagLlmState(): Promise<void> {
    this.newsTagLlmEnabled = await NewsAiService.isTagLlmEnabled();
  }

  private async onTagLlmToggle(on: boolean): Promise<void> {
    await NewsAiService.setTagLlmEnabled(on);
    this.newsTagLlmEnabled = on;
    this.toast(on ? '已开启智能标签（将把新闻标题/摘要发送至所选模型）' : '已关闭智能标签');
  }

  // ==================== 个性化模式（M2 增强） ====================
  private async loadNewsMode(): Promise<void> {
    this.newsPersonalizedMode = await DataRepository.getSetting('newsPersonalizedMode', 'standard');
  }

  private modeLabel(mode: string): string {
    if (mode === 'aggressive') return '高个性化';
    if (mode === 'explore') return '探索';
    if (mode === 'hot') return '仅热点';
    return '标准';
  }

  private async onNewsModePick(): Promise<void> {
    promptAction.showActionMenu({
      title: '个性化模式',
      buttons: [
        { text: '标准（推荐）', color: '#666666' },
        { text: '高个性化', color: '#666666' },
        { text: '仅热点', color: '#666666' },
        { text: '探索', color: '#666666' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const modes: string[] = ['standard', 'aggressive', 'hot', 'explore'];
      if (result.index >= 0 && result.index < modes.length) {
        const mode: string = modes[result.index];
        this.newsPersonalizedMode = mode;
        DataRepository.setSetting('newsPersonalizedMode', mode).then(() => {
          this.toast('个性化模式：' + this.modeLabel(mode));
        });
      }
    }).catch(() => {
    });
  }

  // ==================== 自定义 RSS ====================
  private async loadCustomRss(): Promise<void> {
    try {
      const raw: string = await DataRepository.getSetting('newsCustomRss', '');
      const sources: NewsSourceDef[] = [];
      if (raw.trim().length > 0) {
        const parsed: Object = JSON.parse(raw) as Object;
        if (Array.isArray(parsed)) {
          const arr: Object[] = parsed as Object[];
          for (let i: number = 0; i < arr.length; i++) {
            const entry: Record<string, Object> = arr[i] as Record<string, Object>;
            const name: string = typeof entry['name'] === 'string' ? entry['name'] as string : '';
            const url: string = typeof entry['url'] === 'string' ? entry['url'] as string : '';
            if (name.trim().length > 0 && url.trim().length > 0) {
              sources.push(new NewsSourceDef('custom:' + url, name.trim(), 'recommend', 'rss', url.trim()));
            }
          }
        }
      }
      this.customSources = sources;
    } catch (e) {
      this.customSources = [];
    }
  }

  private async persistCustomRss(): Promise<void> {
    const rows: CustomRssSetting[] = [];
    for (let i: number = 0; i < this.customSources.length; i++) {
      const row: CustomRssSetting = { name: this.customSources[i].name, url: this.customSources[i].url };
      rows.push(row);
    }
    await DataRepository.setSetting('newsCustomRss', JSON.stringify(rows));
  }

  private async addCustomRss(): Promise<void> {
    const name: string = this.customRssName.trim();
    let url: string = this.customRssUrl.trim();
    if (name.length === 0 || url.length === 0) {
      this.toast('请填写订阅名称和 RSS 地址');
      return;
    }
    if (url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0) {
      this.toast('RSS 地址需以 http:// 或 https:// 开头');
      return;
    }
    for (let i: number = 0; i < this.customSources.length; i++) {
      if (this.customSources[i].url === url) {
        this.toast('该订阅已存在');
        return;
      }
    }
    this.customSources = this.customSources.concat([new NewsSourceDef('custom:' + url, name, 'recommend', 'rss', url)]);
    await this.persistCustomRss();
    this.customRssName = '';
    this.customRssUrl = '';
    this.toast('已添加订阅：' + name + '（刷新资讯页后生效）');
  }

  private async removeCustomRss(url: string): Promise<void> {
    const next: NewsSourceDef[] = [];
    for (let i: number = 0; i < this.customSources.length; i++) {
      if (this.customSources[i].url !== url) {
        next.push(this.customSources[i]);
      }
    }
    this.customSources = next;
    await this.persistCustomRss();
    this.toast('已删除订阅');
  }

  // 解析并导入 OPML（按 URL 去重合并到自定义订阅）
  private async importOpml(): Promise<void> {
    const sources: NewsSourceDef[] = NewsService.parseOpml(this.opmlText);
    if (sources.length === 0) {
      this.opmlResult = '未解析到有效订阅，请检查 OPML 内容';
      return;
    }
    let added: number = 0;
    let skipped: number = 0;
    for (let i: number = 0; i < sources.length; i++) {
      let exists: boolean = false;
      for (let j: number = 0; j < this.customSources.length; j++) {
        if (this.customSources[j].url === sources[i].url) {
          exists = true;
          break;
        }
      }
      if (exists) {
        skipped = skipped + 1;
      } else {
        this.customSources = this.customSources.concat([sources[i]]);
        added = added + 1;
      }
    }
    await this.persistCustomRss();
    this.opmlResult = '导入完成：新增 ' + added.toString() + ' 个，跳过重复 ' + skipped.toString() + ' 个';
    this.opmlText = '';
    this.toast('已导入 ' + added.toString() + ' 个订阅');
  }

  @Builder actionsBuilder() {}


  // OPML 导入弹层
  @Builder
  opmlSheet() {
    Stack() {
      Column() {
        Blank()
        Column({ space: 12 }) {
          Row() {
            Text('导入 OPML 订阅')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('✕')
              .fontSize(this.palette.fsLg)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.textTertiary)
              .padding(8)
              .onClick(() => {
                this.showOpmlSheet = false;
                this.opmlText = '';
                this.opmlResult = '';
              })
          }
          .width('100%')

          TextArea({ placeholder: '粘贴 OPML XML 内容（含 <outline xmlUrl=…/> 的订阅）', text: this.opmlText })
            .width('100%')
            .height(150)
            .fontSize(this.palette.fsSm)
            .fontFamily(this.palette.fontSans)
            .onChange((v: string) => { this.opmlText = v; })

          if (this.opmlResult.length > 0) {
            Text(this.opmlResult)
              .fontSize(this.palette.fsXs)
              .fontFamily(this.palette.fontSans)
              .fontColor(this.palette.primary)
              .width('100%')
          }

          Button('解析并导入')
            .fontSize(this.palette.fsMd)
            .fontFamily(this.palette.fontSans)
            .fontColor(Color.White)
            .backgroundColor(this.palette.primary)
            .width('100%')
            .height(42)
            .borderRadius(10)
            .onClick(() => { this.importOpml(); })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: Math.max(20, this.navBarHeight + 8) })
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette))
        .borderRadius({ topLeft: 24, topRight: 24 })
        .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P0_BAR, this.palette) })
        .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.25)', offsetY: -4 })
        .backgroundBlurStyle(glassBlurStyle(this.glassEnabled, GlassLevel.P0_BAR))
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.35)')
    .onClick(() => {
      this.showOpmlSheet = false;
      this.opmlText = '';
      this.opmlResult = '';
    })
  }

  build() {
    Stack() {
      Column() {
        TopBar({ title: '资讯设置', subtitle: '资讯源 / 个性化 / 模型 / RSS', showBack: true }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            // 资讯源与频道
            SettingGroupCard({ title: '资讯源与频道' }) {
              Column({ space: 8 }) {
                SettingRow({
                  icon: '📡',
                  title: '资讯源管理',
                  value: NEWS_SOURCES.length.toString() + ' 个源 · 分组/搜索/批量开关',
                  rowClick: () => { AppNavigator.push('pages/NewsSourceSettings'); }
                })
                Text('关闭的源不再出现在资讯流中，支持全部打开/关闭。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                SettingRow({
                  icon: '📻',
                  title: '个性化频道设置',
                  rowClick: () => { AppNavigator.push('pages/NewsChannelSettings'); }
                })
                Text('默认全部频道启用个性化；关闭的频道恢复纯时间排序，支持全部打开/关闭。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                  .margin({ top: 2 })
              }
              .width('100%')
            }

            // 个性化推荐
            SettingGroupCard({ title: '个性化推荐' }) {
              Column({ space: 8 }) {
                SettingRow({
                  icon: '🎯',
                  title: '个性化模式',
                  value: this.modeLabel(this.newsPersonalizedMode),
                  rowClick: () => { this.onNewsModePick(); }
                })
                Text('标准=混合排序｜高个性化=反馈权重更高｜仅热点=纯时间排序｜探索=更多新内容')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                SettingRow({
                  icon: '🧠',
                  title: '个性化画像（兴趣/厌恶管理）',
                  value: '查看与调整',
                  rowClick: () => { AppNavigator.push('pages/NewsProfile'); }
                })
                SettingRow({
                  icon: '🧹',
                  title: '重置推荐画像',
                  value: '清空全部权重',
                  danger: true,
                  rowClick: () => {
                    this.confirmDanger('重置推荐画像', '将清空全部兴趣/厌恶权重，推荐回到初始状态，此操作不可撤销。', () => {
                      NewsRepository.resetProfile().then(() => {
                        this.toast('已重置推荐画像');
                      });
                    });
                  }
                })
              }
              .width('100%')
            }

            // AI 能力
            SettingGroupCard({ title: 'AI 能力' }) {
              Column({ space: 8 }) {
                Text('翻译模型')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 8 })
                Text('翻译默认使用资讯功能模型；可单独选择并记忆翻译模型。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                NewsModelSelector({
                  settingKey: 'newsTranslateModelId',
                  followLabel: '跟随资讯模型',
                  followDesc: '翻译默认使用资讯功能模型，可单独选择并记忆'
                })
                  .width(220)
                  .margin({ top: 4 })
                SettingRow({
                  icon: '🗑',
                  title: '清除翻译缓存',
                  rowClick: () => {
                    NewsRepository.clearTranslations().then(() => {
                      this.toast('已清除翻译缓存');
                    });
                  }
                })

                Text('AI 智能标签')
                  .fontSize(this.palette.fsBase)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ top: 8 })
                SettingSwitchRow({
                  icon: '🏷',
                  title: '智能标签（LLM 精标）',
                  isOn: this.newsTagLlmEnabled,
                  onSwitchChange: (v: boolean) => {
                    this.onTagLlmToggle(v);
                  }
                })
                Text('开启后：将把新闻标题/摘要发送至你选择的模型服务商，用于生成更细标签；失败自动回退本地规则。')
                  .fontSize(this.palette.fsXs)
                  .fontFamily(this.palette.fontSans)
                  .fontColor(this.palette.textTertiary)
                  .width('100%')
                NewsModelSelector({
                  settingKey: 'newsTagModelId',
                  followLabel: '跟随资讯模型',
                  followDesc: '智能标签默认使用资讯功能模型，可单独选择并记忆'
                })
                  .width(220)
                  .margin({ top: 4 })
                SettingRow({
                  icon: '🗑',
                  title: '清除标签缓存',
                  rowClick: () => {
                    NewsRepository.clearTags().then(() => {
                      this.toast('已清除标签缓存');
                    });
                  }
                })

                SettingRow({
                  icon: '✨',
                  title: 'AI 摘要 / 翻译 / 问 AI',
                  value: '手动触发',
                  rowClick: () => {
                    this.toast('在新闻详情页手动触发，使用「我的 → AI 模型」配置的模型');
                  }
                })
                SettingRow({
                  icon: '📌',
                  title: 'AI 今日要闻 / 为你推荐',
                  rowClick: () => { AppNavigator.push('pages/NewsRecommend'); }
                })
              }
              .width('100%')
            }

            // 自定义订阅
            SettingGroupCard({ title: '自定义订阅' }) {
              Column({ space: 8 }) {
                TextInput({ placeholder: '订阅名称（如 我的博客）', text: this.customRssName })
                  .width('100%')
                  .height(38)
                  .fontSize(this.palette.fsSm)
                  .fontFamily(this.palette.fontSans)
                  .onChange((v: string) => { this.customRssName = v; })
                Row({ space: 8 }) {
                  TextInput({ placeholder: 'https://example.com/feed', text: this.customRssUrl })
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .onChange((v: string) => { this.customRssUrl = v; })
                  Button('添加')
                    .height(38)
                    .fontSize(this.palette.fsSm)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(Color.White)
                    .backgroundColor(this.palette.primary)
                    .borderRadius(8)
                    .onClick(() => { this.addCustomRss(); })
                }
                .width('100%')
                if (this.customSources.length > 0) {
                  ForEach(this.customSources, (s: NewsSourceDef) => {
                    Row() {
                      Text('📡 ' + s.name)
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text('✕')
                        .fontSize(this.palette.fsSm)
                        .fontFamily(this.palette.fontSans)
                        .fontColor(this.palette.textTertiary)
                        .padding(6)
                        .onClick(() => { this.removeCustomRss(s.url); })
                    }
                    .width('100%')
                    .padding({ left: 8, right: 8 })
                    .borderRadius(6)
                    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
                  }, (s: NewsSourceDef) => s.url)
                } else {
                  Text('暂无自定义订阅，添加后自动并入「推荐」频道。')
                    .fontSize(this.palette.fsXs)
                    .fontFamily(this.palette.fontSans)
                    .fontColor(this.palette.textTertiary)
                    .width('100%')
                }
                SettingRow({
                  icon: '📥',
                  title: '导入 OPML 订阅',
                  value: '批量导入',
                  rowClick: () => { this.showOpmlSheet = true; }
                })
              }
              .width('100%')
            }
            Column().height(20)
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, top: 12, bottom: Math.max(24, this.navBarHeight + 8) })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.bgBase)

      // OPML 导入弹层
      if (this.showOpmlSheet) {
        this.opmlSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
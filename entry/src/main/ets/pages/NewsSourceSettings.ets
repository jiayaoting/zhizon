// 智子 - 资讯源管理（子页：分组/搜索/批量开关/自定义订阅/OPML 导出）
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { NEWS_SOURCES, SOURCE_LANGUAGES } from '../common/NewsChannels';
import { NewsSourceDef } from '../common/NewsModels';
import { DataRepository } from '../service/DataRepository';

// 自定义 RSS 持久化结构（与 NewsSettings 共用 settings.newsCustomRss）
interface CustomRssSetting {
  name: string;
  url: string;
}

// 分组元信息（推荐/科技/财经/国际；AI 专题为关键词派生频道，无独立源）
interface SourceGroupMeta {
  id: string;
  title: string;
  icon: string;
  desc: string;
}

const GROUP_META: SourceGroupMeta[] = [
  { id: 'recommend', title: '推荐', icon: '🔥', desc: '全源合并流，推荐页聚合所有启用源' },
  { id: 'tech', title: '科技', icon: '💻', desc: '科技媒体 / 开发者 / AI 博客（AI 专题由此派生）' },
  { id: 'finance', title: '财经', icon: '📈', desc: '财经媒体 / 行情 / 宏观数据' },
  { id: 'world', title: '国际', icon: '🌍', desc: '国际新闻与海外媒体' }
];

// 行内标签：代理类源（稳定性取决于第三方服务）
const PROXY_MARK = /(anyfeeder|wechat2rss|injahow|longpink|bestblogs|rssforever|xgo.ing|feedpress|quail|aishort)/i;

@ComponentV2
@Entry
export struct NewsSourceSettingsPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  // 启用的源 id 列表（空数组 = 全部启用；['__none__'] = 全部关闭）
  @Local enabledIds: string[] = [];
  // 搜索关键词（匹配名称/地址/源 id）
  @Local keyword: string = '';
  // 仅显示已启用
  @Local onlyEnabled: boolean = false;
  // 折叠的分组 id 列表
  @Local collapsedGroups: string[] = [];
  // 自定义 RSS
  @Local customSources: NewsSourceDef[] = [];
  @Local customName: string = '';
  @Local customUrl: string = '';

  aboutToAppear(): void {
    this.loadEnabled();
    this.loadCustomRss();
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg });
  }

  // ==================== 启用状态 ====================

  private async loadEnabled(): Promise<void> {
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

  // 有效启用列表（展开语义：空=全开，['__none__']=全关）
  private effectiveIds(): string[] {
    if (this.enabledIds.length === 0) {
      const all: string[] = [];
      for (let i: number = 0; i < NEWS_SOURCES.length; i++) all.push(NEWS_SOURCES[i].id);
      return all;
    }
    if (this.enabledIds.length === 1 && this.enabledIds[0] === '__none__') return [];
    return this.enabledIds;
  }

  private isEnabled(id: string): boolean {
    if (this.enabledIds.length === 0) return true;
    if (this.enabledIds.length === 1 && this.enabledIds[0] === '__none__') return false;
    return this.enabledIds.indexOf(id) >= 0;
  }

  private async save(ids: string[]): Promise<void> {
    // 全部启用 → 存空数组（保持「空=全开」语义）
    if (ids.length === NEWS_SOURCES.length) {
      await DataRepository.setSetting('newsEnabledSources', '');
      this.enabledIds = [];
      return;
    }
    // 全部关闭 → 存 __none__
    if (ids.length === 0) {
      await DataRepository.setSetting('newsEnabledSources', JSON.stringify(['__none__']));
      this.enabledIds = ['__none__'];
      return;
    }
    await DataRepository.setSetting('newsEnabledSources', JSON.stringify(ids));
    this.enabledIds = ids;
  }

  private async setAll(on: boolean): Promise<void> {
    if (on) {
      await this.save([]);
      this.toast('已全部开启资讯源（' + NEWS_SOURCES.length.toString() + ' 个）');
    } else {
      await DataRepository.setSetting('newsEnabledSources', JSON.stringify(['__none__']));
      this.enabledIds = ['__none__'];
      this.toast('已全部关闭资讯源');
    }
  }

  // 分组内（经搜索/过滤后）实际展示的条数
  private groupShownCount(groupId: string): number {
    let count: number = 0;
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      const s: NewsSourceDef = NEWS_SOURCES[i];
      if (s.category === groupId && this.matchesFilter(s)) count++;
    }
    return count;
  }

  private async toggleSource(id: string, on: boolean): Promise<void> {
    const eff: string[] = this.effectiveIds();
    const idx: number = eff.indexOf(id);
    if (on && idx < 0) {
      eff.push(id);
    } else if (!on && idx >= 0) {
      eff.splice(idx, 1);
    }
    await this.save(eff);
  }

  // 组级批量开关
  private async toggleGroup(groupIds: string[], on: boolean): Promise<void> {
    const eff: string[] = this.effectiveIds();
    if (on) {
      for (let i: number = 0; i < groupIds.length; i++) {
        if (eff.indexOf(groupIds[i]) < 0) eff.push(groupIds[i]);
      }
    } else {
      for (let i: number = 0; i < groupIds.length; i++) {
        const idx: number = eff.indexOf(groupIds[i]);
        if (idx >= 0) eff.splice(idx, 1);
      }
    }
    await this.save(eff);
  }

  // ==================== 分组与过滤 ====================

  private matchesFilter(s: NewsSourceDef): boolean {
    if (this.onlyEnabled && !this.isEnabled(s.id)) return false;
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) return true;
    const hay: string = (s.name + ' ' + s.url + ' ' + s.id).toLowerCase();
    return hay.indexOf(kw) >= 0;
  }

  private isCollapsed(groupId: string): boolean {
    return this.collapsedGroups.indexOf(groupId) >= 0;
  }

  private toggleCollapse(groupId: string): void {
    const arr: string[] = this.collapsedGroups.slice();
    const idx: number = arr.indexOf(groupId);
    if (idx >= 0) {
      arr.splice(idx, 1);
    } else {
      arr.push(groupId);
    }
    this.collapsedGroups = arr;
  }

  private groupEnabledCount(groupId: string): number {
    const eff: string[] = this.effectiveIds();
    let count: number = 0;
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      if (NEWS_SOURCES[i].category === groupId && eff.indexOf(NEWS_SOURCES[i].id) >= 0) count++;
    }
    return count;
  }

  private groupIds(groupId: string): string[] {
    const ids: string[] = [];
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      if (NEWS_SOURCES[i].category === groupId) ids.push(NEWS_SOURCES[i].id);
    }
    return ids;
  }

  private groupSize(groupId: string): number {
    let count: number = 0;
    for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
      if (NEWS_SOURCES[i].category === groupId) count++;
    }
    return count;
  }

  private langOf(s: NewsSourceDef): string {
    const preset: string | undefined = SOURCE_LANGUAGES[s.id];
    if (preset !== undefined && preset.length > 0) return preset === 'zh' ? '中' : '英';
    return /[一-鿿]/.test(s.name) ? '中' : '英';
  }

  private isProxy(s: NewsSourceDef): boolean {
    return PROXY_MARK.test(s.url);
  }

  private enabledTotal(): number {
    return this.effectiveIds().length;
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
    const name: string = this.customName.trim();
    let url: string = this.customUrl.trim();
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
    this.customName = '';
    this.customUrl = '';
    this.toast('已添加订阅：' + name + '（刷新资讯页后生效）');
  }

  private async removeCustomRss(url: string): Promise<void> {
    const next: NewsSourceDef[] = [];
    for (let i: number = 0; i < this.customSources.length; i++) {
      if (this.customSources[i].url !== url) next.push(this.customSources[i]);
    }
    this.customSources = next;
    await this.persistCustomRss();
    this.toast('已删除订阅');
  }

  // ==================== OPML 导出（复制到剪贴板） ====================

  private xmlEscape(s: string): string {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  private async exportOpml(): Promise<void> {
    const eff: string[] = this.effectiveIds();
    if (eff.length === 0) {
      this.toast('当前没有启用的源');
      return;
    }
    const order: string[] = ['recommend', 'tech', 'finance', 'world'];
    let xml: string = '<?xml version="1.0" encoding="UTF-8"?>\n<opml version="2.0">\n  <body>\n';
    for (let g: number = 0; g < order.length; g++) {
      const gid: string = order[g];
      const rows: string[] = [];
      for (let i: number = 0; i < NEWS_SOURCES.length; i++) {
        const s: NewsSourceDef = NEWS_SOURCES[i];
        if (s.category === gid && eff.indexOf(s.id) >= 0) {
          rows.push('    <outline type="rss" text="' + this.xmlEscape(s.name) + '" xmlUrl="' + this.xmlEscape(s.url) + '"/>');
        }
      }
      if (rows.length > 0) {
        xml = xml + '    <outline text="' + gid + '">\n' + rows.join('\n') + '\n    </outline>\n';
      }
    }
    xml = xml + '  </body>\n</opml>';
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, xml);
      await pasteboard.getSystemPasteboard().setData(data);
      this.toast('已复制 ' + eff.length.toString() + ' 个源的 OPML（可在其他阅读器导入）');
    } catch (e) {
      this.toast('复制失败');
    }
  }

  // ==================== 构建 ====================

  @Builder
  sourceRow(source: NewsSourceDef, enabled: boolean) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(source.name)
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.langOf(source) === '英') {
            Text('EN')
              .fontSize(9)
              .fontColor(this.themeState.palette.textTertiary)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(4)
              .border({ width: 0.5, color: this.themeState.palette.textTertiary })
          }
          if (this.isProxy(source)) {
            Text('代理')
              .fontSize(9)
              .fontColor(this.themeState.palette.primary)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(4)
              .border({ width: 0.5, color: this.themeState.palette.primary })
          }
        }
        .width('100%')
        Text(source.url)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.themeState.palette.primary)
        .onChange((v: boolean) => { this.toggleSource(source.id, v); })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
  }

  @Builder
  groupHeader(meta: SourceGroupMeta, enabledCount: number, size: number) {
    Row({ space: 8 }) {
      Text(meta.icon + ' ' + meta.title)
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Medium)
      Text(enabledCount.toString() + '/' + size.toString())
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
      Blank()
      Text('全开')
        .fontSize(this.themeState.palette.fsXs)
        .fontColor(this.themeState.palette.primary)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(6)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
        .onClick(() => { this.toggleGroup(this.groupIds(meta.id), true); })
      Text('全关')
        .fontSize(this.themeState.palette.fsXs)
        .fontColor(this.themeState.palette.textSecondary)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(6)
        .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
        .onClick(() => { this.toggleGroup(this.groupIds(meta.id), false); })
      Text(this.isCollapsed(meta.id) ? '▸' : '▾')
        .fontSize(this.themeState.palette.fsSm)
        .fontColor(this.themeState.palette.textTertiary)
        .padding(6)
        .onClick(() => { this.toggleCollapse(meta.id); })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
  }

  @Builder
  customRow(source: NewsSourceDef) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('📡 ' + source.name)
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(source.url)
          .fontSize(this.themeState.palette.fsXs)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('✕')
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.danger)
        .padding(6)
        .onClick(() => { this.removeCustomRss(source.url); })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .borderRadius(8)
    .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
  }

  build() {
    Column() {
      TopBar({ title: '资讯源管理', subtitle: '内置 ' + NEWS_SOURCES.length.toString() + ' 源 · 分组 / 搜索 / 批量开关', showBack: true })

      // 统计 + 全部开关
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('已启用 ' + this.enabledTotal().toString() + ' / ' + NEWS_SOURCES.length.toString())
            .fontSize(this.themeState.palette.fsMd)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textPrimary)
            .fontWeight(FontWeight.Medium)
          Text('关闭的源不再出现在资讯流中')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('全部打开')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(12)
          .height(34)
          .onClick(() => { this.setAll(true); })
        Button('全部关闭')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.danger)
          .borderRadius(12)
          .height(34)
          .onClick(() => { this.setAll(false); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // 搜索 + 仅看已启用
      Row({ space: 8 }) {
        TextInput({ placeholder: '🔍 搜索源名称 / 地址 / ID', text: this.keyword })
          .layoutWeight(1)
          .height(34)
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .onChange((v: string) => { this.keyword = v; })
        Row({ space: 4 }) {
          Text('仅看已启用')
            .fontSize(this.themeState.palette.fsXs)
            .fontFamily(this.themeState.palette.fontSans)
            .fontColor(this.themeState.palette.textSecondary)
          Toggle({ type: ToggleType.Switch, isOn: this.onlyEnabled })
            .selectedColor(this.themeState.palette.primary)
            .scale({ x: 0.75, y: 0.75 })
            .onChange((v: boolean) => { this.onlyEnabled = v; })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      Scroll() {
        Column({ space: 10 }) {
          // 分组列表
          ForEach(GROUP_META, (meta: SourceGroupMeta) => {
            Column({ space: 6 }) {
              this.groupHeader(meta, this.groupEnabledCount(meta.id), this.groupSize(meta.id))
              if (!this.isCollapsed(meta.id)) {
                Text(meta.desc)
                  .fontSize(this.themeState.palette.fsXs)
                  .fontFamily(this.themeState.palette.fontSans)
                  .fontColor(this.themeState.palette.textTertiary)
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 0, bottom: 2 })
                ForEach(NEWS_SOURCES.filter((s: NewsSourceDef) => s.category === meta.id && this.matchesFilter(s)),
                  (source: NewsSourceDef) => {
                    this.sourceRow(source, this.isEnabled(source.id))
                  }, (source: NewsSourceDef) => source.id)
                if ((this.keyword.trim().length > 0 || this.onlyEnabled) && this.groupShownCount(meta.id) === 0) {
                  Text('该分组无匹配源')
                    .fontSize(this.themeState.palette.fsXs)
                    .fontFamily(this.themeState.palette.fontSans)
                    .fontColor(this.themeState.palette.textTertiary)
                    .width('100%')
                    .padding(12)
                }
              }
            }
            .width('100%')
            .padding(8)
            .borderRadius(12)
            .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
            .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
          }, (meta: SourceGroupMeta) => meta.id)

          // 自定义订阅
          Column({ space: 6 }) {
            Row() {
              Text('📥 自定义订阅（' + this.customSources.length.toString() + '）')
                .fontSize(this.themeState.palette.fsMd)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textPrimary)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text('OPML 导出')
                .fontSize(this.themeState.palette.fsXs)
                .fontColor(this.themeState.palette.primary)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(6)
                .backgroundColor(GlassStyle.innerBackgroundColor(this.themeState.glassEnabled, this.themeState.palette))
                .onClick(() => { this.exportOpml(); })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 2 })

            TextInput({ placeholder: '订阅名称（如 我的博客）', text: this.customName })
              .width('100%')
              .height(34)
              .fontSize(this.themeState.palette.fsSm)
              .fontFamily(this.themeState.palette.fontSans)
              .onChange((v: string) => { this.customName = v; })
            Row({ space: 8 }) {
              TextInput({ placeholder: 'https://example.com/feed', text: this.customUrl })
                .layoutWeight(1)
                .height(34)
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .onChange((v: string) => { this.customUrl = v; })
              Button('添加')
                .height(34)
                .fontSize(this.themeState.palette.fsSm)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(Color.White)
                .backgroundColor(this.themeState.palette.primary)
                .borderRadius(8)
                .onClick(() => { this.addCustomRss(); })
            }
            .width('100%')

            if (this.customSources.length > 0) {
              ForEach(this.customSources, (s: NewsSourceDef) => {
                this.customRow(s)
              }, (s: NewsSourceDef) => s.url)
            } else {
              Text('暂无自定义订阅；自定义订阅自动并入「推荐」频道。')
                .fontSize(this.themeState.palette.fsXs)
                .fontFamily(this.themeState.palette.fontSans)
                .fontColor(this.themeState.palette.textTertiary)
                .width('100%')
                .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            }
            Text('提示：批量导入请到「资讯设置 → 导入 OPML 订阅」；「AI 专题」为关键词派生频道，无需单独开关。')
              .fontSize(this.themeState.palette.fsXs)
              .fontFamily(this.themeState.palette.fontSans)
              .fontColor(this.themeState.palette.textTertiary)
              .width('100%')
              .padding({ left: 12, right: 12, top: 4, bottom: 8 })
          }
          .width('100%')
          .padding(8)
          .borderRadius(12)
          .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
          .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })

          Column().height(20)
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 8 })
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

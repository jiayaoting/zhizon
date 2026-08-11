// 智子 - 告警中心页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { MetricCard } from '../components/MetricCard';
import { EmptyState } from '../components/EmptyState';
import { GlassStyle, GlassLevel, glassBlurStyle } from '../components/GlassEffect';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { DataRepository } from '../service/DataRepository';
import { Alert } from '../model/Models';

@Component
export struct AlertsPage {

  @State alertFilter: string = '全部';
  @State resolvedMap: Record<string, boolean> = {};
  @State alerts: Alert[] = [];
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
  private filters: string[] = ['全部', '未处理', '严重', '警告', '信息'];
  private alertsDataSource: ArrayDataSource<Alert> = new ArrayDataSource<Alert>();

  aboutToAppear(): void {
    DataRepository.getAlerts().then((data: Alert[]) => {
      this.alerts = data;
      this.refreshAlertsDataSource();
      this.loading = false;
    }).catch(() => {
      this.loading = false;
    });
  }

  aboutToDisappear(): void {
    // 告警数据为单次拉取，无持久资源需要释放
  }

  // 刷新 LazyForEach 数据源
  private refreshAlertsDataSource(): void {
    this.alertsDataSource.reloadAll(this.filteredAlerts());
  }

  // 级别颜色
  private levelColor(level: string): string {
    if (level === 'critical') return this.palette.danger;
    if (level === 'warning') return this.palette.warning;
    return this.palette.info;
  }

  // 级别文本
  private levelText(level: string): string {
    if (level === 'critical') return '严重';
    if (level === 'warning') return '警告';
    return '信息';
  }

  // 级别半透明背景
  private levelDimColor(level: string): string {
    if (level === 'critical') return 'rgba(239, 68, 68, 0.15)';
    if (level === 'warning') return 'rgba(245, 158, 11, 0.15)';
    return 'rgba(59, 130, 246, 0.15)';
  }

  // 是否已处理
  private isResolved(a: Alert): boolean {
    return this.resolvedMap[a.id] ?? a.resolved;
  }

  private unresolvedCount(): number {
    return this.alerts.filter(a => !this.isResolved(a)).length;
  }

  // 筛选后的告警
  private filteredAlerts(): Alert[] {
    return this.alerts.filter(a => {
      if (this.alertFilter === '全部') return true;
      if (this.alertFilter === '未处理') return !this.isResolved(a);
      if (this.alertFilter === '严重') return a.level === 'critical';
      if (this.alertFilter === '警告') return a.level === 'warning';
      if (this.alertFilter === '信息') return a.level === 'info';
      return true;
    });
  }

  private markResolved(a: Alert) {
    DataRepository.resolveAlert(a.id).then(() => {
      const newMap: Record<string, boolean> = {};
      Object.keys(this.resolvedMap).forEach((key: string) => {
        newMap[key] = this.resolvedMap[key];
      });
      newMap[a.id] = true;
      this.resolvedMap = newMap;
      this.refreshAlertsDataSource();
      promptAction.showToast({ message: '已标记为已处理' });
    });
  }

  private markAllRead() {
    DataRepository.resolveAllAlerts().then(() => {
      const map: Record<string, boolean> = {};
      this.alerts.forEach(a => { map[a.id] = true; });
      this.resolvedMap = map;
      this.refreshAlertsDataSource();
      promptAction.showToast({ message: '已全部标记已读' });
    });
  }

  @Builder actionsBuilder() {
    Button('全部标记已读')
      .fontSize(12)
      .fontColor(this.palette.textSecondary)
      .backgroundColor(this.palette.bgSurface2)
      .borderRadius(6)
      .height(30)
      .onClick(() => this.markAllRead())
  }

  @Builder filterTag(f: string) {
    Text(f)
      .fontSize(12)
      .fontColor(f === this.alertFilter ? Color.White : this.palette.textSecondary)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(f === this.alertFilter ? this.palette.primary : GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
      .border({ width: 1, color: f === this.alertFilter ? this.palette.primary : this.palette.borderSubtle })
      .onClick(() => { this.alertFilter = f; this.refreshAlertsDataSource(); })
  }

  @Builder alertCard(a: Alert) {
    Row() {
      // 左侧 3px 色条
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.levelColor(a.level))

      // 主体内容
      Column({ space: 8 }) {
        // 标题行：标题 + 级别徽章 + 时间
        Row() {
          Text(a.title)
            .fontSize(this.palette.fsMd)
            .fontColor(this.palette.textPrimary)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.levelText(a.level))
            .fontSize(10)
            .fontColor(this.levelColor(a.level))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .backgroundColor(this.levelDimColor(a.level))
            .margin({ right: 8 })
          Text(a.time)
            .fontSize(11)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontMono)
        }
        .width('100%')

        // 详情
          Text(a.detail)
          .fontSize(12)
          .fontColor(this.palette.textSecondary)
          .width('100%')

        // 来源行：source + 查看 + 标记已处理
        Row() {
          Text(a.source)
            .fontSize(11)
            .fontColor(this.palette.textTertiary)
            .fontFamily(this.palette.fontMono)
            .layoutWeight(1)
          Text('查看')
            .fontSize(11)
            .fontColor(this.palette.primary)
            .margin({ right: 12 })
            .onClick(() => {
              promptAction.showToast({ message: `查看 ${a.source}` });
            })
          if (!this.isResolved(a)) {
            Text('标记已处理')
              .fontSize(11)
              .fontColor(this.palette.warning)
              .onClick(() => this.markResolved(a))
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .padding(14)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
    .opacity(this.isResolved(a) ? 0.5 : 1)
    .backgroundBlurStyle(glassBlurStyle(this.glassEnabled, GlassLevel.P2_LIST))
  }

  @Builder loadingBuilder() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.palette.primary)
      Text('加载中...')
        .fontSize(13)
        .fontColor(this.palette.textTertiary)
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      TopBar({ title: '告警中心', subtitle: `${this.unresolvedCount()} 条未处理` }) {
        this.actionsBuilder()
      }
      if (this.loading) {
        this.loadingBuilder()
      }
      Scroll() {
          Column({ space: 16 }) {
            // 顶部统计卡
            Row({ space: 12 }) {
              MetricCard({
                title: '严重',
                value: `${this.alerts.filter(a => a.level === 'critical').length}`,
                unit: '条',
                sub: `未处理 ${this.alerts.filter(a => a.level === 'critical' && !this.isResolved(a)).length}`,
                color: this.palette.danger
              })
              MetricCard({
                title: '警告',
                value: `${this.alerts.filter(a => a.level === 'warning').length}`,
                unit: '条',
                sub: `未处理 ${this.alerts.filter(a => a.level === 'warning' && !this.isResolved(a)).length}`,
                color: this.palette.warning
              })
              MetricCard({
                title: '信息',
                value: `${this.alerts.filter(a => a.level === 'info').length}`,
                unit: '条',
                sub: `未处理 ${this.alerts.filter(a => a.level === 'info' && !this.isResolved(a)).length}`,
                color: this.palette.info
              })
            }
            .width('100%')

            // 过滤标签
            Row({ space: 8 }) {
              ForEach(this.filters, (f: string) => {
                this.filterTag(f)
              }, (f: string) => f)
            }
            .width('100%')
          }
          .padding(this.isSm ? 16 : 24)
          .width('100%')
        }
        .align(Alignment.Top)

        // 告警列表（LazyForEach 按需渲染）
        if (this.alertsDataSource.totalCount() === 0) {
          EmptyState({ icon: '✅', title: '暂无告警', desc: '所有服务器运行正常' })
        } else {
          List({ space: 12 }) {
            LazyForEach(this.alertsDataSource, (a: Alert) => {
              ListItem() {
                this.alertCard(a)
              }
            }, (a: Alert) => a.id)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24 })
        }
      }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}
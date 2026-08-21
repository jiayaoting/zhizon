// 智子 - 阅读周报（近 7 天阅读画像：统计卡 + Canvas 趋势图 + 本地规则周报文案）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { DatabaseHelper, WeeklyReadingStats } from '../service/DatabaseHelper';

@ComponentV2
@Entry
export struct ReadingReportPage {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
  @Local stats: WeeklyReadingStats | null = null;
  @Local loading: boolean = true;
  private chartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      this.stats = await DatabaseHelper.getWeeklyReadingStats();
    } catch (e) {
      this.stats = null;
    }
    this.loading = false;
    this.redrawChart();
  }

  // Canvas.onReady 只在挂载时触发一次，数据异步加载完成后需手动重绘
  private redrawChart(): void {
    setTimeout(() => {
      try {
        this.drawChart();
      } catch (e) {
      }
    }, 60);
  }

  // 本地规则生成的 AI 风格周报文案（不调用模型）
  private reportText(): string {
    if (this.stats === null) return '';
    const s: WeeklyReadingStats = this.stats;
    if (s.totalReads <= 0) return '本周还没有阅读记录，去资讯页看看吧';
    let bestLabel: string = '';
    if (s.bestDayIndex >= 0 && s.bestDayIndex < s.dates.length) {
      bestLabel = s.dates[s.bestDayIndex];
    }
    let bestCount: number = 0;
    if (s.bestDayIndex >= 0 && s.bestDayIndex < s.reads.length) {
      bestCount = s.reads[s.bestDayIndex];
    }
    let text: string = '本周共阅读 ' + s.totalReads.toString() + ' 篇';
    text += '，收藏 ' + s.totalFavorites.toString() + ' 篇';
    text += '，AI 资讯调用 ' + s.totalAiCalls.toString() + ' 次';
    text += '，活跃 ' + s.activeDays.toString() + ' 天';
    if (bestLabel.length > 0) {
      text += '。最活跃的一天是 ' + bestLabel + '（' + bestCount.toString() + ' 篇）';
    } else {
      text += '。';
    }
    if (s.totalReads >= 20) {
      text += ' 本周阅读量非常可观，继续保持！';
    } else if (s.totalReads >= 10) {
      text += ' 阅读节奏不错，试着每天都读一点。';
    } else {
      text += ' 碎片时间也可以读一篇资讯，积少成多。';
    }
    return text;
  }

  @Builder
  statCard(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(this.themeState.palette.fsLg)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(this.themeState.palette.fsXs)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textTertiary)
    }
    .layoutWeight(1)
    .padding(10)
    .borderRadius(10)
    .backgroundColor(this.themeState.palette.bgSurface)
  }

  @Builder
  chartArea() {
    Column({ space: 8 }) {
      Text('近 7 天阅读趋势')
        .fontSize(this.themeState.palette.fsMd)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Canvas(this.chartCtx)
        .width('100%')
        .height(200)
        .onReady(() => { this.drawChart(); })
        .backgroundColor(this.themeState.palette.bgSurface)
        .borderRadius(10)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
  }

  @Builder
  reportCard() {
    Column({ space: 8 }) {
      Row() {
        Text('🤖 AI 周报')
          .fontSize(this.themeState.palette.fsMd)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.primary)
          .fontWeight(FontWeight.Bold)
        Text('本地规则生成，不消耗 AI 额度')
          .fontSize(10)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.reportText())
        .fontSize(this.themeState.palette.fsSm)
        .fontFamily(this.themeState.palette.fontSans)
        .fontColor(this.themeState.palette.textSecondary)
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor(GlassStyle.backgroundColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.themeState.glassEnabled, GlassLevel.P2_LIST, this.themeState.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  private drawChart(): void {
    const ctx: CanvasRenderingContext2D = this.chartCtx;
    const w: number = ctx.width > 0 ? ctx.width : (this.themeState.isSm ? 320 : 480);
    const h: number = ctx.height > 0 ? ctx.height : 200;
    ctx.clearRect(0, 0, w, h);
    if (this.stats === null) {
      ctx.fillStyle = this.themeState.palette.textSecondary;
      ctx.font = '16px sans-serif';
      ctx.fillText('正在生成周报…', 20, h / 2);
      return;
    }
    const reads: number[] = this.stats.reads;
    const dates: string[] = this.stats.dates;
    if (reads.length === 0 || this.stats.totalReads <= 0) {
      ctx.fillStyle = this.themeState.palette.textSecondary;
      ctx.font = '16px sans-serif';
      ctx.fillText('本周还没有阅读记录', 20, h / 2);
      return;
    }
    let max: number = 1;
    for (let i: number = 0; i < reads.length; i++) {
      if (reads[i] > max) max = reads[i];
    }
    const leftPad: number = 34;
    const rightPad: number = 10;
    const topPad: number = 24;
    const bottomPad: number = 30;
    const plotW: number = w - leftPad - rightPad;
    const plotH: number = h - topPad - bottomPad;
    const half: number = max / 2;
    // Y 轴刻度：0 / 一半 / 最大值三条网格线
    const gridValues: number[] = [0, half, max];
    for (let gi: number = 0; gi < gridValues.length; gi++) {
      const gy: number = h - bottomPad - (gridValues[gi] / max) * plotH;
      ctx.strokeStyle = this.themeState.palette.borderSubtle;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(leftPad, gy);
      ctx.lineTo(w - rightPad, gy);
      ctx.stroke();
      ctx.fillStyle = this.themeState.palette.textTertiary;
      ctx.font = '10px sans-serif';
      ctx.fillText(Math.round(gridValues[gi]).toString(), 4, gy + 3);
    }
    // 柱状图：每日阅读数 + 柱顶数值 + X 轴日期
    const slot: number = plotW / reads.length;
    const barW: number = Math.max(3, slot * 0.5);
    for (let i: number = 0; i < reads.length; i++) {
      const x: number = leftPad + slot * i + (slot - barW) / 2;
      const value: number = reads[i];
      if (value > 0) {
        const barH: number = Math.max(3, (value / max) * plotH);
        const y: number = h - bottomPad - barH;
        ctx.fillStyle = this.themeState.palette.primary;
        ctx.fillRect(x, y, barW, barH);
        ctx.fillStyle = this.themeState.palette.textSecondary;
        ctx.font = '11px sans-serif';
        const label: string = value.toString();
        ctx.fillText(label, x + barW / 2 - label.length * 3, y - 4);
      }
      // X 轴日期标签（旧 → 新）
      if (i < dates.length) {
        const dateLabel: string = dates[i];
        ctx.fillStyle = this.themeState.palette.textSecondary;
        ctx.font = '10px sans-serif';
        ctx.fillText(dateLabel, x + barW / 2 - dateLabel.length * 3, h - 10);
      }
    }
    // 图注：最高阅读日
    ctx.fillStyle = this.themeState.palette.textSecondary;
    ctx.font = '12px sans-serif';
    ctx.fillText('最高 ' + max.toString() + ' 篇', leftPad, 14);
  }

  @Builder
  loadingState() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
        Text('正在生成周报…')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textTertiary)
      } else {
        Text('周报加载失败，请重试')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(this.themeState.palette.textSecondary)
        Button('重试')
          .fontSize(this.themeState.palette.fsSm)
          .fontFamily(this.themeState.palette.fontSans)
          .fontColor(Color.White)
          .backgroundColor(this.themeState.palette.primary)
          .borderRadius(14)
          .height(32)
          .onClick(() => { this.load(); })
      }
    }
    .width('100%')
    .padding({ top: 80 })
  }

  build() {
    Column() {
      TopBar({ title: '阅读周报', subtitle: '近 7 天阅读画像', showBack: true })

      Scroll() {
        Column({ space: 12 }) {
          if (this.stats === null) {
            this.loadingState()
          } else {
            Row({ space: 10 }) {
              this.statCard('总阅读', this.stats.totalReads.toString())
              this.statCard('总收藏', this.stats.totalFavorites.toString())
              this.statCard('AI 调用', this.stats.totalAiCalls.toString())
              this.statCard('活跃天数', this.stats.activeDays.toString() + '天')
            }
            .width('100%')

            this.chartArea()
            this.reportCard()
            Column().height(20)
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: this.themeState.isSm ? 16 : 24, right: this.themeState.isSm ? 16 : 24, top: 12 })
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

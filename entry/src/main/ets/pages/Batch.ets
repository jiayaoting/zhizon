// 智子 - 批量操作页面
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';

import { TopBar } from '../components/TopBar';
import { StatusBadge } from '../components/StatusBadge';
import { DataRepository } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { Server } from '../model/Models';

// 批量执行结果
interface BatchResult {
  serverId: string;
  serverName: string;
  host: string;
  status: 'success' | 'failed';
  duration: string;
  output: string;
}

// 分组卡片组件
@Component
struct SectionCard {
  @Prop title: string;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder defaultContent() {}

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(AppTheme.fsMd)
        .fontColor(AppTheme.textPrimary)
        .fontWeight(FontWeight.Bold)
      this.content()
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: 1, color: AppTheme.borderSubtle })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct BatchPage {
  
  @State selectedServers: string[] = [];
  @State commandInput: string = '';
  @State results: BatchResult[] = [];
  @State expandedId: string = '';
  @State servers: Server[] = [];
  @State loading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  private templates: string[] = ['系统信息', '磁盘检查', '服务重启', '日志查看'];
  private textareaController: TextAreaController = new TextAreaController();

  // 模板命令映射
  private templateMap: Record<string, string> = {
    '系统信息': 'uptime\nuname -a\nfree -h',
    '磁盘检查': 'df -h\ndu -sh /var/log',
    '服务重启': 'systemctl restart nginx',
    '日志查看': 'tail -n 100 /var/log/syslog'
  };

  aboutToAppear(): void {
    this.loadServers();
  }

  private async loadServers(): Promise<void> {
    try {
      this.servers = await DataRepository.getServers();
    } catch (e) {
      console.error('Failed to load servers:', JSON.stringify(e));
    } finally {
      this.loading = false;
    }
  }

  private isSelected(id: string): boolean {
    return this.selectedServers.indexOf(id) >= 0;
  }

  private toggleServer(id: string) {
    if (this.isSelected(id)) {
      this.selectedServers = this.selectedServers.filter(x => x !== id);
    } else {
      this.selectedServers = [...this.selectedServers, id];
    }
  }

  private allSelected(): boolean {
    return this.servers.length > 0 && this.selectedServers.length === this.servers.length;
  }

  private toggleAll() {
    if (this.allSelected()) {
      this.selectedServers = [];
    } else {
      this.selectedServers = this.servers.map(s => s.id);
    }
  }

  private insertTemplate(name: string) {
    const tpl = this.templateMap[name] || '';
    const newText = this.commandInput ? this.commandInput + '\n' + tpl : tpl;
    this.commandInput = newText;
    promptAction.showToast({ message: `已插入模板：${name}` });
  }

  private async runBatch() {
    if (this.selectedServers.length === 0) {
      promptAction.showToast({ message: '请先选择目标服务器' });
      return;
    }
    if (!this.commandInput.trim()) {
      promptAction.showToast({ message: '请输入要执行的命令' });
      return;
    }

    const command = this.commandInput.trim();
    const tasks = this.selectedServers.map(async (id) => {
      const srv = this.servers.find(s => s.id === id);
      if (!srv) {
        return {
          serverId: id,
          serverName: id,
          host: '',
          status: 'failed',
          duration: '0.00s',
          output: '服务器未找到'
        } as BatchResult;
      }

      const start = Date.now();
      try {
        const output = await SshService.exec(srv, command);
        const duration = ((Date.now() - start) / 1000).toFixed(2) + 's';
        return {
          serverId: id,
          serverName: srv.name,
          host: srv.host,
          status: 'success',
          duration: duration,
          output: output
        } as BatchResult;
      } catch (e) {
        const duration = ((Date.now() - start) / 1000).toFixed(2) + 's';
        const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
        return {
          serverId: id,
          serverName: srv.name,
          host: srv.host,
          status: 'failed',
          duration: duration,
          output: `ssh: connect to host ${srv.host} port ${srv.port}: ${errMsg}`
        } as BatchResult;
      }
    });

    this.results = await Promise.all(tasks);
    this.expandedId = '';
    promptAction.showToast({ message: `已对 ${this.selectedServers.length} 台服务器执行命令` });
  }

  @Builder actionsBuilder() {
    Button('执行')
      .fontSize(12)
      .fontColor(Color.White)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .onClick(() => this.runBatch())
  }

  // 勾选框（Stack 模拟）
  @Builder checkbox(checked: boolean) {
    Stack() {
      if (checked) {
        Text('✓')
          .fontSize(12)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(16)
    .height(16)
    .borderRadius(3)
    .backgroundColor(checked ? AppTheme.primary : Color.Transparent)
    .border({ width: 1, color: checked ? AppTheme.primary : AppTheme.textTertiary })
  }

  @Builder serverRow(srv: Server) {
    Row({ space: 12 }) {
      this.checkbox(this.isSelected(srv.id))
      Column({ space: 2 }) {
        Text(srv.name)
          .fontSize(13)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(`${srv.host}:${srv.port}`)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      StatusBadge({ status: srv.status, badgeSize: 'small' })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(6)
    .backgroundColor(AppTheme.bgSurface2)
    .onClick(() => this.toggleServer(srv.id))
  }

  @Builder templateTag(name: string) {
    Text(name)
      .fontSize(11)
      .fontColor(AppTheme.textSecondary)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(AppTheme.bgSurface2)
      .border({ width: 1, color: AppTheme.borderSubtle })
      .onClick(() => this.insertTemplate(name))
  }

  @Builder resultRow(r: BatchResult) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text(r.serverName)
          .fontSize(13)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        StatusBadge({ status: r.status, badgeSize: 'small' })
        Text(r.duration)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
        Text('查看详情')
          .fontSize(11)
          .fontColor(AppTheme.primary)
          .onClick(() => {
            this.expandedId = this.expandedId === r.serverId ? '' : r.serverId;
          })
      }
      .width('100%')

      // 可展开的结果文本
      if (this.expandedId === r.serverId) {
        Text(r.output)
          .fontSize(12)
          .fontColor(r.status === 'success' ? AppTheme.primary : AppTheme.danger)
          .fontFamily(AppTheme.fontMono)
          .width('100%')
          .padding(10)
          .borderRadius(6)
          .backgroundColor(AppTheme.bgSurface2)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(6)
    .backgroundColor(AppTheme.bgSurface2)
  }

  build() {
    Column() {
      TopBar({ title: '批量操作', subtitle: '多服务器并行执行' }) {
        this.actionsBuilder()
      }
      Scroll() {
          Column({ space: 16 }) {
            // 选择服务器区
            SectionCard({ title: '目标服务器' }) {
              Column({ space: 8 }) {
                Row() {
                  Text(`已选 ${this.selectedServers.length}/${this.servers.length} 台`)
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                    .layoutWeight(1)
                  Text(this.allSelected() ? '取消全选' : '全选')
                    .fontSize(11)
                    .fontColor(AppTheme.primary)
                    .onClick(() => this.toggleAll())
                }
                .width('100%')

                ForEach(this.servers, (srv: Server) => {
                  this.serverRow(srv)
                }, (srv: Server) => srv.id)
              }
              .width('100%')
            }

            // 命令输入区
            SectionCard({ title: '执行命令' }) {
              Column({ space: 10 }) {
                TextArea({ placeholder: '输入要批量执行的命令，如：df -h\nfree -m\nuptime', controller: this.textareaController })
                  .width('100%')
                  .height(120)
                  .fontSize(12)
                  .fontFamily(AppTheme.fontMono)
                  .fontColor(AppTheme.textPrimary)
                  .backgroundColor(AppTheme.bgSurface2)
                  .borderRadius(6)
                  .onChange((val: string) => { this.commandInput = val; })

                Row({ space: 8 }) {
                  Text('常用模板：')
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                  ForEach(this.templates, (t: string) => {
                    this.templateTag(t)
                  }, (t: string) => t)
                }
                .width('100%')
              }
              .width('100%')
            }

            // 执行结果区
            SectionCard({ title: '执行结果' }) {
              Column({ space: 8 }) {
                Row() {
                  Text(this.results.length > 0
                    ? `${this.results.filter(r => r.status === 'success').length}/${this.results.length} 完成`
                    : '尚未执行')
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                    .layoutWeight(1)
                }
                .width('100%')

                if (this.results.length === 0) {
                  Text('点击右上角"执行"按钮开始批量执行')
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(16)
                }

                ForEach(this.results, (r: BatchResult) => {
                  this.resultRow(r)
                }, (r: BatchResult) => r.serverId)
              }
              .width('100%')
            }
          }
          .padding(this.isSm ? 16 : 24)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}
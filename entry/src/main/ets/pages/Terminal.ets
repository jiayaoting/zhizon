// 智子 - SSH 终端页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { SshService } from '../service/SshService';
import { Server } from '../model/Models';

@Component
export struct TerminalPage {
  @State activeSession: number = 0;
  @State cmdInput: string = '';
  @State terminalLines: string[] = [];
  @State isLoading: boolean = true;
  @StorageLink('isSm') isSm: boolean = false;
  private sessions: string[] = ['prod-web-01', 'prod-db-master', 'dev-test-01'];
  private sessionCwds: string[] = ['~/projects', '~/data', '~/test'];
  private quickCmds: string[] = ['ls -la', 'cd ~', 'top', 'df -h', 'free -h', 'docker ps', 'uptime', 'cat /etc/os-release'];

  // 根据当前会话构建 Server 对象
  private getServer(): Server {
    return {
      id: '',
      name: this.sessions[this.activeSession],
      host: '',
      port: 22,
      username: 'root',
      authType: 'password',
      tags: [],
      status: 'online',
      metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
      createdAt: 0
    };
  }

  // 判断是否为命令提示符行
  private isPromptLine(line: string): boolean {
    return line.includes('root@') || line.includes('#');
  }

  // 页面即将出现时加载终端输出
  async aboutToAppear(): Promise<void> {
    try {
      const server = this.getServer();
      this.terminalLines = await SshService.getTerminalOutput(server);
    } catch (e) {
      this.terminalLines = [`连接失败: ${JSON.stringify(e)}`];
    } finally {
      this.isLoading = false;
    }
  }

  // 发送命令
  private async sendCommand(cmd: string) {
    if (!cmd.trim()) return;
    const server = this.getServer();
    const prompt = `root@${server.name}:~# ${cmd}`;
    this.terminalLines = [...this.terminalLines, prompt];
    this.cmdInput = '';
    try {
      const output = await SshService.exec(server, cmd);
      this.terminalLines = [...this.terminalLines, output, `root@${server.name}:~# `];
    } catch (e) {
      this.terminalLines = [...this.terminalLines, `错误: ${JSON.stringify(e)}`, `root@${server.name}:~# `];
    }
  }

  @Builder actionsBuilder() {
    Button('新建会话')
      .fontSize(12)
      .fontColor(AppTheme.bgBase)
      .backgroundColor(AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        promptAction.showToast({ message: '新建会话功能开发中' });
      })
  }

  // 左侧会话项
  @Builder sessionItem(name: string, cwd: string, idx: number) {
    Column({ space: 4 }) {
      Text(name)
        .fontSize(12)
        .fontColor(idx === this.activeSession ? AppTheme.primary : AppTheme.textPrimary)
        .fontWeight(idx === this.activeSession ? FontWeight.Medium : FontWeight.Regular)
      Text(cwd)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(6)
    .backgroundColor(idx === this.activeSession ? AppTheme.primaryDim : Color.Transparent)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.activeSession = idx; })
  }

  // 顶部 Tab 项
  @Builder tabItem(name: string, idx: number) {
    Column({ space: 6 }) {
      Text(name)
        .fontSize(12)
        .fontColor(idx === this.activeSession ? AppTheme.primary : AppTheme.textSecondary)
        .fontWeight(idx === this.activeSession ? FontWeight.Medium : FontWeight.Regular)
      Column()
        .width('100%')
        .height(2)
        .backgroundColor(idx === this.activeSession ? AppTheme.primary : Color.Transparent)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 0 })
    .onClick(() => { this.activeSession = idx; })
  }

  // 快捷命令标签
  @Builder quickCmdTag(cmd: string) {
    Text(cmd)
      .fontSize(11)
      .fontColor(AppTheme.textSecondary)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(6)
      .backgroundColor(AppTheme.bgSurface2)
      .fontFamily(AppTheme.fontMono)
      .onClick(() => {
        this.sendCommand(cmd);
      })
  }

  build() {
    Column() {
      TopBar({ title: 'SSH 终端', subtitle: '多标签会话' }) {
        this.actionsBuilder()
      }

      // 主区域：左侧会话列表(平板) + 右侧终端
      Row() {
        // 左侧会话列表 — 仅平板端显示
        if (!this.isSm) {
          Column({ space: 4 }) {
            ForEach(this.sessions, (name: string, idx: number) => {
              this.sessionItem(name, this.sessionCwds[idx], idx)
            }, (name: string) => name)
          }
          .width(200)
          .padding(8)
          .backgroundColor(AppTheme.bgSurface)
          .alignItems(HorizontalAlign.Start)
          .height('100%')
        }

        // 右侧终端区
        Column() {
          // 顶部 Tab 栏
          Row() {
            ForEach(this.sessions, (name: string, idx: number) => {
              this.tabItem(name, idx)
            }, (name: string) => name)
          }
          .width('100%')
          .border({ width: { bottom: 1 }, color: AppTheme.borderSubtle })

          // 终端内容区
          Scroll() {
            Column({ space: 0 }) {
              if (this.isLoading) {
                Text('加载中...')
                  .fontSize(14)
                  .fontColor('#00D9A3')
                  .fontFamily(AppTheme.fontMono)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 40 })
              } else {
                ForEach(this.terminalLines, (line: string) => {
                  Text(line)
                    .fontSize(12)
                    .fontFamily(AppTheme.fontMono)
                    .fontColor(this.isPromptLine(line) ? '#00FF88' : '#00D9A3')
                    .width('100%')
                }, (line: string, idx: number) => `${idx}-${line}`)
              }
            }
            .width('100%')
            .padding(this.isSm ? 10 : 12)
          }
          .layoutWeight(1)
          .backgroundColor('#000000')
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)

          // 快捷命令栏
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.quickCmds, (cmd: string) => {
                this.quickCmdTag(cmd)
              }, (cmd: string) => cmd)
            }
            .padding({ left: this.isSm ? 10 : 12, right: this.isSm ? 10 : 12, top: 8, bottom: 8 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .backgroundColor(AppTheme.bgSurface)

          // 底部输入栏
          Row({ space: 8 }) {
            TextInput({ placeholder: '输入命令...', text: $$this.cmdInput })
              .fontSize(12)
              .fontColor(AppTheme.textPrimary)
              .fontFamily(AppTheme.fontMono)
              .backgroundColor(AppTheme.bgSurface2)
              .borderRadius(6)
              .height(32)
              .layoutWeight(1)
            Button('发送')
              .fontSize(12)
              .fontColor(AppTheme.bgBase)
              .backgroundColor(AppTheme.primary)
              .borderRadius(6)
              .height(32)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.sendCommand(this.cmdInput);
              })
          }
          .width('100%')
          .padding({ left: this.isSm ? 10 : 12, right: this.isSm ? 10 : 12, top: 8, bottom: 8 })
          .backgroundColor(AppTheme.bgSurface)
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(AppTheme.bgBase)
      }
      .layoutWeight(1)
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}
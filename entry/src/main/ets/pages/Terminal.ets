// 智子 - SSH 终端页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { SshService, SshEngine } from '../service/SshService';
import { DataRepository } from '../service/DataRepository';
import { Server } from '../model/Models';

@Component
export struct TerminalPage {
  @State cmdInput: string = '';
  @State terminalLines: string[] = [];
  @State isLoading: boolean = true;
  @State connected: boolean = false;
  @State serverName: string = '终端';
  @State serverHost: string = '';
  @StorageLink('isSm') isSm: boolean = false;
  private server: Server | null = null;
  private engine: SshEngine | null = null;
  private prompt: string = '$ ';
  private quickCmds: string[] = ['ls -la', 'cd ~', 'top -bn1', 'df -h', 'free -h', 'docker ps', 'uptime', 'cat /etc/os-release', 'whoami', 'hostname', 'ps aux', 'netstat -tlnp'];

  async aboutToAppear(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, string>;
      const serverId = params?.serverId || '';

      if (serverId) {
        // 从数据库加载真实服务器
        const server = await DataRepository.getServer(serverId);
        if (server) {
          this.server = server;
          this.serverName = server.name;
          this.serverHost = server.host;
          await this.connectServer();
        } else {
          this.terminalLines = ['错误: 未找到服务器 (ID: ' + serverId + ')'];
          this.isLoading = false;
        }
      } else {
        // 无 serverId，尝试从 AppStorage 获取上次连接的服务器
        this.terminalLines = ['请从服务器列表选择要连接的服务器'];
        this.isLoading = false;
      }
    } catch (e) {
      this.terminalLines = ['初始化失败: ' + JSON.stringify(e)];
      this.isLoading = false;
    }
  }

  aboutToDisappear(): void {
    // 页面销毁时断开连接
    if (this.server) {
      SshService.disconnect(this.server);
    }
  }

  // 连接服务器并获取初始输出
  private async connectServer(): Promise<void> {
    if (!this.server) return;

    this.isLoading = true;
    this.terminalLines = [`正在连接 ${this.server.name} (${this.server.host}:${this.server.port})...`];

    try {
      const output = await SshService.getTerminalOutput(this.server);
      this.terminalLines = output;

      // 检查是否连接成功
      const firstLine = output.length > 0 ? output[0] : '';
      this.connected = firstLine.includes('连接成功');

      if (this.connected) {
        // 获取提示符
        const lastLine = output[output.length - 1] || '';
        if (lastLine.includes('#') || lastLine.includes('$')) {
          this.prompt = lastLine;
        }

        // 更新服务器状态和最后连接时间
        await DataRepository.updateServer(this.server.id, {
          status: 'online',
          lastConnected: Date.now()
        });
      }
    } catch (e) {
      this.terminalLines = [...this.terminalLines, `连接失败: ${JSON.stringify(e)}`];
      this.connected = false;
    } finally {
      this.isLoading = false;
    }
  }

  // 发送命令
  private async sendCommand(cmd: string): Promise<void> {
    if (!cmd.trim() || !this.server) return;

    // 显示输入的命令
    const cmdLine = `${this.prompt}${cmd}`;
    this.terminalLines = [...this.terminalLines, cmdLine];
    this.cmdInput = '';

    // 如果未连接，先连接
    if (!this.connected) {
      await this.connectServer();
      if (!this.connected) return;
    }

    try {
      const output = await SshService.exec(this.server, cmd);

      // 解析输出并显示
      if (output.trim()) {
        const lines = output.split('\n').filter((l: string) => l.trim() !== '');
        this.terminalLines = [...this.terminalLines, ...lines];
      }

      // 添加新的提示符
      this.terminalLines = [...this.terminalLines, this.prompt];
    } catch (e) {
      this.terminalLines = [...this.terminalLines, `错误: ${JSON.stringify(e)}`, this.prompt];
    }
  }

  @Builder actionsBuilder() {
    Button('重连')
      .fontSize(12)
      .fontColor(this.connected ? AppTheme.textSecondary : AppTheme.bgBase)
      .backgroundColor(this.connected ? AppTheme.bgSurface2 : AppTheme.primary)
      .borderRadius(6)
      .height(30)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.connectServer();
      })
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

  // 判断是否为命令提示符行
  private isPromptLine(line: string): boolean {
    return line.includes('root@') || line.includes('#') && !line.includes('错误') && !line.includes('失败') && !line.includes('Error');
  }

  private isErrorLine(line: string): boolean {
    return line.includes('错误') || line.includes('失败') || line.includes('Error') || line.includes('error');
  }

  build() {
    Column() {
      TopBar({ title: this.serverName, subtitle: this.connected ? `${this.serverHost} · 已连接` : '未连接' }) {
        this.actionsBuilder()
      }

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
                .fontColor(this.isErrorLine(line) ? '#EF4444' : (this.isPromptLine(line) ? '#00FF88' : '#00D9A3'))
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
          .onSubmit(() => {
            this.sendCommand(this.cmdInput);
          })
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
}

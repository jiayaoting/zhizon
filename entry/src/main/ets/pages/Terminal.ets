// 智子 - SSH 终端页面（多会话标签页容器）
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { SshService, SshEngine } from '../service/SshService';
import { DataRepository } from '../service/DataRepository';
import { Server, TerminalSession } from '../model/Models';
import { TerminalView } from '../terminal/TerminalView';

// 会话状态
interface SessionState {
  session: TerminalSession;
  engine: SshEngine | null;
  lines: string[];
  prompt: string;
  cmdInput: string;
  isLoading: boolean;
  isReconnecting: boolean;
}

@Component
export struct TerminalPage {
  @State sessions: SessionState[] = [];
  @State activeIndex: number = 0;
  @State serverName: string = '终端';
  @State serverHost: string = '';
  @StorageLink('isSm') isSm: boolean = false;
  private server: Server | null = null;
  private allServers: Server[] = [];
  private quickCmds: string[] = [
    'ls -la', 'cd ~', 'top -bn1', 'df -h', 'free -h', 'docker ps',
    'uptime', 'cat /etc/os-release', 'whoami', 'hostname', 'ps aux', 'netstat -tlnp'
  ];
  private sessionCounter: number = 0;

  async aboutToAppear(): Promise<void> {
    try {
      // 预加载服务器列表供会话选择器使用
      this.allServers = await DataRepository.getServers();

      const params = router.getParams() as Record<string, string>;
      const serverId = params?.serverId || '';

      if (serverId) {
        const server = await DataRepository.getServer(serverId);
        if (server) {
          this.server = server;
          this.serverName = server.name;
          this.serverHost = server.host;
          this.addSession(server);
          await this.connectActiveSession();
        } else {
          // serverId 无效，弹出选择器
          this.showServerPicker();
        }
      } else {
        // 从底部 Tab 进入，弹出服务器选择器
        this.showServerPicker();
      }
    } catch (e) {
      console.error('TerminalPage init failed:', JSON.stringify(e));
      this.showServerPicker();
    }
  }

  aboutToDisappear(): void {
    // 断开所有会话
    for (const state of this.sessions) {
      if (state.engine) {
        state.engine.closeTerminal();
      }
    }
    if (this.server) {
      SshService.disconnect(this.server);
    }
  }

  // 弹出服务器选择器（独立 Tab 进入或无 serverId 时使用）
  private showServerPicker(): void {
    if (this.allServers.length === 0) {
      promptAction.showToast({ message: '暂无服务器，请先添加 SSH 服务器' });
      return;
    }

    // 构建选择器选项（title 前缀状态标识，避免 icon 字段需要图片资源）
    const sheets: Array<SheetInfo> = [];
    for (const s of this.allServers) {
      const statusMark = s.status === 'online' ? '● ' : '○ ';
      sheets.push({
        title: statusMark + s.name,
        action: () => {
          this.server = s;
          this.serverName = s.name;
          this.serverHost = s.host;
          // 创建该服务器的第一个会话并连接
          this.sessions = [];
          this.addSession(s);
          this.connectActiveSession();
        }
      });
    }

    this.getUIContext().showActionSheet({
      title: '选择 SSH 服务器',
      message: `共 ${this.allServers.length} 台服务器`,
      sheets: sheets
    });
  }

  // 获取当前活动会话
  private get activeSession(): SessionState | null {
    if (this.activeIndex >= 0 && this.activeIndex < this.sessions.length) {
      return this.sessions[this.activeIndex];
    }
    return null;
  }

  // 添加新会话（基于服务器对象）
  private addSession(server: Server): void {
    this.server = server;
    this.serverName = server.name;
    this.serverHost = server.host;
    this.sessionCounter++;
    const session: TerminalSession = {
      id: `session_${Date.now()}_${this.sessionCounter}`,
      serverId: server.id,
      serverName: server.name,
      host: server.host,
      username: server.username,
      cwd: '~',
      history: [],
      connected: false,
      reconnecting: false
    };
    this.sessions.push({
      session: session,
      engine: null,
      lines: [`终端 ${server.name} - ${server.host}`],
      prompt: '$ ',
      cmdInput: '',
      isLoading: false,
      isReconnecting: false
    });
    this.activeIndex = this.sessions.length - 1;
  }

  // 关闭会话
  private closeSession(index: number): void {
    if (this.sessions.length <= 1) return;
    const state = this.sessions[index];
    if (state.engine) {
      state.engine.closeTerminal();
    }
    this.sessions.splice(index, 1);
    if (this.activeIndex >= this.sessions.length) {
      this.activeIndex = this.sessions.length - 1;
    }
  }

  // 连接当前活动会话
  private async connectActiveSession(): Promise<void> {
    if (!this.server) return;
    const state = this.activeSession;
    if (!state) return;

    state.isLoading = true;
    state.lines = [`正在连接 ${state.session.serverName} (${state.session.host})...`];

    try {
      const output = await SshService.getTerminalOutput(this.server);
      state.lines = output;
      const firstLine = output.length > 0 ? output[0] : '';
      state.session.connected = firstLine.includes('连接成功');

      if (state.session.connected) {
        const lastLine = output[output.length - 1] || '';
        if (lastLine.includes('#') || lastLine.includes('$')) {
          state.prompt = lastLine;
        }
        await DataRepository.updateServer(this.server.id, {
          status: 'online',
          lastConnected: Date.now()
        });
      }
    } catch (e) {
      state.lines = [...state.lines, `连接失败: ${JSON.stringify(e)}`];
      state.session.connected = false;
    } finally {
      state.isLoading = false;
    }
  }

  // 发送命令
  private async sendCommand(cmd: string, state: SessionState): Promise<void> {
    if (!cmd.trim() || !this.server) return;

    const cmdLine = `${state.prompt}${cmd}`;
    state.lines = [...state.lines, cmdLine];
    state.cmdInput = '';
    state.session.history.push(cmd);

    if (!state.session.connected) {
      await this.connectActiveSession();
      if (!state.session.connected) return;
    }

    try {
      const output = await SshService.exec(this.server, cmd);
      if (output.trim()) {
        const outputLines = output.split('\n').filter((l: string) => l.trim() !== '');
        state.lines = [...state.lines, ...outputLines];
      }
      state.lines = [...state.lines, state.prompt];
    } catch (e) {
      state.lines = [...state.lines, `错误: ${JSON.stringify(e)}`, state.prompt];
    }
  }

  // 重连
  private async reconnect(state: SessionState): Promise<void> {
    state.isReconnecting = true;
    try {
      await this.connectActiveSession();
    } finally {
      state.isReconnecting = false;
    }
  }

  // 终端尺寸变化
  private onTerminalResize(cols: number, rows: number): void {
    const state = this.activeSession;
    if (state?.engine) {
      try {
        // AgentEngine 支持 resizeTerminal，DirectEngine 不支持
        state.engine.resizeTerminal?.(cols, rows);
      } catch (e) {
        // 忽略
      }
    }
  }

  build() {
    Column() {
      TopBar({
        title: this.serverName,
        subtitle: this.activeSession?.session.connected
          ? `${this.serverHost} · 已连接`
          : '未连接'
      }) {
        Row({ space: 8 }) {
          Button('重连')
            .fontSize(12)
            .fontColor(this.activeSession?.session.connected ? AppTheme.textSecondary : AppTheme.bgBase)
            .backgroundColor(this.activeSession?.session.connected ? AppTheme.bgSurface2 : AppTheme.primary)
            .borderRadius(6)
            .height(30)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              const s = this.activeSession;
              if (s) this.reconnect(s);
            })
          Button('+ 新会话')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .backgroundColor(AppTheme.bgSurface2)
            .borderRadius(6)
            .height(30)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              // 弹出服务器选择器，让用户选择连接到哪个服务器
              this.showServerPicker();
            })
        }
      }

      // 会话标签栏
      if (this.sessions.length > 1) {
        Scroll() {
          Row({ space: 0 }) {
            ForEach(this.sessions, (state: SessionState, index: number) => {
              Row({ space: 4 }) {
                Text(state.session.serverName)
                  .fontSize(12)
                  .fontFamily(AppTheme.fontMono)
                  .fontColor(index === this.activeIndex ? AppTheme.primary : AppTheme.textSecondary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: 100 })
                // 连接状态点
                Circle({ width: 6, height: 6 })
                  .fill(state.session.connected ? AppTheme.success : AppTheme.textTertiary)
                Button({ type: ButtonType.Circle }) {
                  Text('×')
                    .fontSize(12)
                    .fontColor(AppTheme.textTertiary)
                }
                .width(16)
                .height(16)
                .backgroundColor('transparent')
                .onClick(() => this.closeSession(index))
              }
              .padding({ left: 10, right: 6, top: 6, bottom: 6 })
              .borderRadius(6)
              .backgroundColor(index === this.activeIndex ? AppTheme.bgElevated : AppTheme.bgSurface)
              .margin({ right: 6 })
              .onClick(() => { this.activeIndex = index; })
            }, (state: SessionState, idx: number) => state.session.id)
          }
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .backgroundColor(AppTheme.bgSurface)
      }

      // 终端视图
      if (this.activeSession) {
        TerminalView({
          lines: this.activeSession.lines,
          prompt: this.activeSession.prompt,
          isConnected: this.activeSession.session.connected,
          isReconnecting: this.activeSession.isReconnecting,
          session: this.activeSession.session,
          cmdInput: $cmdInput,
          isLoading: this.activeSession.isLoading,
          quickCmds: this.quickCmds,
          onSendCommand: (cmd: string) => {
            const s = this.activeSession;
            if (s) this.sendCommand(cmd, s);
          },
          onResize: (cols: number, rows: number) => {
            this.onTerminalResize(cols, rows);
          },
          onReconnect: () => {
            const s = this.activeSession;
            if (s) this.reconnect(s);
          }
        })
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

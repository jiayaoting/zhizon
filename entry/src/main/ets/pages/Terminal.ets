// 智子 - SSH 终端页面（多会话标签页容器 + 流式终端）
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
  @State showPicker: boolean = false;
  @State pickerServers: Server[] = [];
  private server: Server | null = null;
  private allServers: Server[] = [];
  private quickCmds: string[] = [
    'ls -la', 'cd ~', 'top -bn1', 'df -h', 'free -h', 'docker ps',
    'uptime', 'cat /etc/os-release', 'whoami', 'hostname', 'ps aux', 'netstat -tlnp'
  ];
  private sessionCounter: number = 0;

  async aboutToAppear(): Promise<void> {
    try {
      this.allServers = await DataRepository.getServers();
      const params = router.getParams() as Record<string, string>;
      const serverId: string = params?.serverId || '';

      if (serverId) {
        const server: Server | undefined = await DataRepository.getServer(serverId);
        if (server) {
          this.server = server;
          this.serverName = server.name;
          this.serverHost = server.host;
          this.addSession(server);
          await this.connectActiveSession();
        } else {
          this.showPicker = true;
          this.pickerServers = this.allServers;
        }
      } else {
        this.showPicker = true;
        this.pickerServers = this.allServers;
      }
    } catch (e) {
      console.error('TerminalPage init failed:', JSON.stringify(e));
      this.showPicker = true;
      this.pickerServers = this.allServers;
    }
  }

  aboutToDisappear(): void {
    for (const state of this.sessions) {
      if (state.engine) {
        state.engine.closeTerminal();
      }
    }
    if (this.server) {
      SshService.disconnect(this.server);
    }
  }

  // 选择服务器
  private onSelectServer(s: Server): void {
    this.showPicker = false;
    this.server = s;
    this.serverName = s.name;
    this.serverHost = s.host;
    this.sessions = [];
    this.addSession(s);
    this.connectActiveSession();
  }

  // 获取当前活动会话
  private get activeSession(): SessionState | null {
    if (this.activeIndex >= 0 && this.activeIndex < this.sessions.length) {
      return this.sessions[this.activeIndex];
    }
    return null;
  }

  // 添加新会话
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
    if (this.sessions.length <= 1) {
      return;
    }
    const state: SessionState = this.sessions[index];
    if (state.engine) {
      state.engine.closeTerminal();
    }
    this.sessions.splice(index, 1);
    if (this.activeIndex >= this.sessions.length) {
      this.activeIndex = this.sessions.length - 1;
    }
  }

  // 连接当前活动会话（流式终端）
  private async connectActiveSession(): Promise<void> {
    if (!this.server) {
      return;
    }
    const state: SessionState | null = this.activeSession;
    if (!state) {
      return;
    }

    state.isLoading = true;
    state.lines = [`正在连接 ${state.session.serverName} (${state.session.host})...`];

    try {
      // 先用 exec 获取初始信息
      const output: string[] = await SshService.getTerminalOutput(this.server);
      state.lines = output;
      const firstLine: string = output.length > 0 ? output[0] : '';
      state.session.connected = firstLine.includes('连接成功');

      if (state.session.connected) {
        const lastLine: string = output[output.length - 1] || '';
        if (lastLine.includes('#') || lastLine.includes('$')) {
          state.prompt = lastLine;
        }

        // 建立流式终端连接
        try {
          const engine: SshEngine = await SshService.openTerminal(this.server);
          state.engine = engine;
          engine.onTerminalData((data: string) => {
            if (data.trim()) {
              state.lines = [...state.lines, data];
            }
          });
        } catch (termErr) {
          console.warn('openTerminal failed, using exec mode:', JSON.stringify(termErr));
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
    if (!cmd.trim() || !this.server) {
      return;
    }

    const cmdLine: string = `${state.prompt}${cmd}`;
    state.lines = [...state.lines, cmdLine];
    state.cmdInput = '';
    state.session.history.push(cmd);

    if (!state.session.connected) {
      await this.connectActiveSession();
      if (!state.session.connected) {
        return;
      }
    }

    // 如果已建立流式终端，直接发送输入
    if (state.engine) {
      state.engine.sendTerminalInput(cmd + '\n');
    } else {
      // 降级为 exec 模式
      try {
        const output: string = await SshService.exec(this.server, cmd);
        if (output.trim()) {
          const outputLines: string[] = output.split('\n').filter((l: string) => l.trim() !== '');
          state.lines = [...state.lines, ...outputLines];
        }
        state.lines = [...state.lines, state.prompt];
      } catch (e) {
        state.lines = [...state.lines, `错误: ${JSON.stringify(e)}`, state.prompt];
      }
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
    const state: SessionState | null = this.activeSession;
    if (state?.engine) {
      try {
        state.engine.resizeTerminal?.(cols, rows);
      } catch (e) {
        // 忽略
      }
    }
  }

  // 服务器状态点颜色
  private serverStatusColor(s: Server): string {
    if (s.status === 'online') {
      return AppTheme.success;
    }
    return AppTheme.textTertiary;
  }

  build() {
    Stack() {
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
              const s: SessionState | null = this.activeSession;
              if (s) {
                this.reconnect(s);
              }
            })
          Button('+ 新会话')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .backgroundColor(AppTheme.bgSurface2)
            .borderRadius(6)
            .height(30)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.pickerServers = this.allServers;
              this.showPicker = true;
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
              .onClick(() => {
                this.activeIndex = index;
              })
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
            const s: SessionState | null = this.activeSession;
            if (s) {
              this.sendCommand(cmd, s);
            }
          },
          onResize: (cols: number, rows: number) => {
            this.onTerminalResize(cols, rows);
          },
          onReconnect: () => {
            const s: SessionState | null = this.activeSession;
            if (s) {
              this.reconnect(s);
            }
          }
        })
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)

    // 自定义服务器选择弹窗
    if (this.showPicker) {
      Stack() {
        // 半透明遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .onClick(() => {
            this.showPicker = false;
          })

        // 弹窗卡片
        Column({ space: 0 }) {
          // 标题栏
          Row() {
            Text('选择 SSH 服务器')
              .fontSize(16)
              .fontColor(AppTheme.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Button({ type: ButtonType.Circle }) {
              Text('✕')
                .fontSize(14)
                .fontColor(AppTheme.textTertiary)
            }
            .width(28)
            .height(28)
            .backgroundColor(AppTheme.bgSurface2)
            .onClick(() => {
              this.showPicker = false;
            })
          }
          .width('100%')
          .padding({ left: 20, right: 16, top: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center)

          Text(`共 ${this.pickerServers.length} 台服务器`)
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 12 })

          Divider()
            .width('100%')
            .strokeWidth(0.5)
            .color(AppTheme.borderSubtle)

          // 服务器列表
          if (this.pickerServers.length === 0) {
            Column({ space: 8 }) {
              Text('📡')
                .fontSize(36)
              Text('暂无服务器')
                .fontSize(14)
                .fontColor(AppTheme.textTertiary)
              Text('请先添加 SSH 服务器')
                .fontSize(12)
                .fontColor(AppTheme.textTertiary)
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            Scroll() {
              Column({ space: 0 }) {
                ForEach(this.pickerServers, (s: Server) => {
                  Column() {
                    Row({ space: 12 }) {
                      Column() {
                        Text(s.name)
                          .fontSize(14)
                          .fontColor(AppTheme.textPrimary)
                          .fontWeight(FontWeight.Medium)
                        Text(`${s.host}:${s.port}`)
                          .fontSize(11)
                          .fontColor(AppTheme.textTertiary)
                          .fontFamily(AppTheme.fontMono)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      // 状态点
                      Circle({ width: 8, height: 8 })
                        .fill(this.serverStatusColor(s))

                      // 连接模式标签
                      Text(s.connectionMode === 'direct' ? '直连' : 'Agent')
                        .fontSize(10)
                        .fontColor(s.connectionMode === 'direct' ? AppTheme.warning : AppTheme.primary)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(4)
                        .backgroundColor(s.connectionMode === 'direct' ? 'rgba(245,158,11,0.12)' : AppTheme.primaryDim)

                      Image($r('sys.media.ohos_ic_public_arrow_right'))
                        .width(16)
                        .height(16)
                        .fillColor(AppTheme.textTertiary)
                    }
                    .width('100%')
                    .padding({ left: 20, right: 16, top: 14, bottom: 14 })
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => {
                      this.onSelectServer(s);
                    })

                    Divider()
                      .width('100%')
                      .strokeWidth(0.5)
                      .color(AppTheme.borderSubtle)
                      .margin({ left: 20 })
                  }
                  .width('100%')
                }, (s: Server) => s.id)
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: this.isSm ? 420 : 520 })
          }
        }
        .width(this.isSm ? '92%' : '76%')
        .constraintSize({ maxWidth: 500 })
        .borderRadius(16)
        .backgroundColor(AppTheme.bgSurface)
        .shadow({
          radius: 24,
          color: 'rgba(0,0,0,0.4)',
          offsetY: 8
        })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
    }
  }
}

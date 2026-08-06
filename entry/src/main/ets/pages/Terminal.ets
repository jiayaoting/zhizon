// 智子 - SSH 终端页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { SshService } from '../service/SshService';
import { DataRepository } from '../service/DataRepository';
import { Server, TerminalSession } from '../model/Models';

// 会话状态
interface SessionState {
  session: TerminalSession;
  lines: string[];
  prompt: string;
  cmdInput: string;
  isLoading: boolean;
}

@Component
export struct TerminalPage {
  @StorageLink('isSm') isSm: boolean = false;
  @State sessions: SessionState[] = [];
  @State activeIndex: number = 0;
  @State serverName: string = '终端';
  @State serverHost: string = '';
  @State showPicker: boolean = false;
  @State pickerServers: Server[] = [];
  @State loading: boolean = true;
  private server: Server | null = null;
  private allServers: Server[] = [];
  private sessionCounter: number = 0;

  aboutToAppear(): void {
    this.initPage();
  }

  private async initPage(): Promise<void> {
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
          return;
        }
      }
      this.showPicker = true;
      this.pickerServers = this.allServers;
    } catch (e) {
      console.error('TerminalPage init failed:', JSON.stringify(e));
      this.showPicker = true;
      this.pickerServers = this.allServers;
    } finally {
      this.loading = false;
    }
  }

  aboutToDisappear(): void {
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
      lines: [`准备连接 ${server.name} (${server.host})...`],
      prompt: '$ ',
      cmdInput: '',
      isLoading: false
    });
    this.activeIndex = this.sessions.length - 1;
  }

  // 关闭会话
  private closeSession(index: number): void {
    if (this.sessions.length <= 1) {
      return;
    }
    this.sessions.splice(index, 1);
    if (this.activeIndex >= this.sessions.length) {
      this.activeIndex = this.sessions.length - 1;
    }
  }

  // 连接当前活动会话
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
      // 获取终端初始输出（连接 + 系统信息）
      const output: string[] = await SshService.getTerminalOutput(this.server);
      state.lines = output;
      state.session.connected = output.length > 1 && output[0].includes('连接成功');

      if (state.session.connected) {
        // 提取 prompt
        const lastLine: string = output[output.length - 1] || '';
        if (lastLine.includes('#') || lastLine.includes('$')) {
          state.prompt = lastLine;
        }

        // 更新数据库状态
        await DataRepository.updateServer(this.server.id, {
          status: 'online',
          lastConnected: Date.now()
        });
      } else {
        state.lines = [...state.lines, '连接失败，请检查服务器凭据和网络'];
      }
    } catch (e) {
      state.lines = [...state.lines, `连接异常: ${JSON.stringify(e)}`];
      state.session.connected = false;
    } finally {
      state.isLoading = false;
    }
  }

  // 发送命令
  private async sendCommand(cmd: string): Promise<void> {
    if (!cmd.trim() || !this.server) {
      return;
    }
    const state: SessionState | null = this.activeSession;
    if (!state) {
      return;
    }

    // 追加命令行到输出
    const cmdLine: string = `${state.prompt}${cmd}`;
    state.lines = [...state.lines, cmdLine];
    state.cmdInput = '';
    state.session.history.push(cmd);

    if (!state.session.connected) {
      state.lines = [...state.lines, '未连接，正在重连...'];
      await this.connectActiveSession();
      if (!state.session.connected) {
        state.lines = [...state.lines, '重连失败'];
        return;
      }
    }

    try {
      const output: string = await SshService.exec(this.server, cmd);
      if (output.trim()) {
        const outputLines: string[] = output.split('\n');
        state.lines = [...state.lines, ...outputLines];
      }
      // 追加空 prompt 表示命令完成
      state.lines = [...state.lines, state.prompt];
    } catch (e) {
      state.lines = [...state.lines, `执行失败: ${JSON.stringify(e)}`, state.prompt];
    }
  }

  // 重连
  private async reconnect(): Promise<void> {
    await this.connectActiveSession();
  }

  // 服务器状态点颜色
  private serverStatusColor(s: Server): string {
    return s.status === 'online' ? AppTheme.success : AppTheme.textTertiary;
  }

  build() {
    if (this.loading) {
      Column() {
        TopBar({ title: '终端', subtitle: 'SSH 命令行' })
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(AppTheme.primary)
          Text('加载中...')
            .fontSize(14)
            .fontColor(AppTheme.textTertiary)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.bgBase)
    } else {
      Stack() {
        Column() {
          // 顶部栏
          TopBar({
            title: this.serverName,
            subtitle: this.activeSession?.session.connected
              ? `${this.serverHost} · 已连接`
              : '未连接'
          }) {
            Row({ space: 8 }) {
              Button('+ 会话')
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

          // 终端输出区域
          Scroll() {
            Column({ space: 0 }) {
              // 重连按钮
              if (!this.activeSession?.session.connected) {
                Row() {
                  Button('重新连接')
                    .fontSize(12)
                    .fontColor(AppTheme.bgBase)
                    .backgroundColor(AppTheme.primary)
                    .borderRadius(6)
                    .height(30)
                    .padding({ left: 16, right: 16 })
                    .onClick(() => this.reconnect())
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ top: 8, bottom: 8 })
              }

              // 加载指示器
              if (this.activeSession?.isLoading) {
                Row({ space: 8 }) {
                  LoadingProgress()
                    .width(14)
                    .height(14)
                    .color(AppTheme.primary)
                  Text('连接中...')
                    .fontSize(12)
                    .fontColor(AppTheme.textTertiary)
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })
              }

              // 终端行
              ForEach(this.activeSession?.lines || [], (line: string, index: number) => {
                Text(line)
                  .fontSize(13)
                  .fontFamily(AppTheme.fontMono)
                  .fontColor(AppTheme.textSecondary)
                  .padding({ left: 12, right: 12, top: 1, bottom: 1 })
                  .width('100%')
              }, (line: string, idx: number) => `${idx}_${line.substring(0, 20)}`)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .layoutWeight(1)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
          .backgroundColor(AppTheme.bgBase)
          .align(Alignment.TopStart)

          // 命令输入栏
          Row({ space: 8 }) {
            Text(this.activeSession?.prompt || '$ ')
              .fontSize(13)
              .fontFamily(AppTheme.fontMono)
              .fontColor(AppTheme.primary)
              .constraintSize({ maxWidth: '40%' })
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            TextInput({ text: this.activeSession?.cmdInput || '', placeholder: '输入命令...' })
              .fontSize(13)
              .fontFamily(AppTheme.fontMono)
              .fontColor(AppTheme.textPrimary)
              .placeholderColor(AppTheme.textTertiary)
              .backgroundColor(AppTheme.bgSurface)
              .borderRadius(6)
              .height(36)
              .layoutWeight(1)
              .onChange((value: string) => {
                const s: SessionState | null = this.activeSession;
                if (s) {
                  s.cmdInput = value;
                }
              })
              .onSubmit((enterKey: EnterKeyType) => {
                const s: SessionState | null = this.activeSession;
                if (s) {
                  this.sendCommand(s.cmdInput);
                }
              })

            Button('发送')
              .fontSize(12)
              .fontColor(AppTheme.bgBase)
              .backgroundColor(AppTheme.primary)
              .borderRadius(6)
              .height(36)
              .padding({ left: 14, right: 14 })
              .onClick(() => {
                const s: SessionState | null = this.activeSession;
                if (s) {
                  this.sendCommand(s.cmdInput);
                }
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 10 })
          .backgroundColor(AppTheme.bgSurface)
          .border({ width: { top: 0.5 }, color: AppTheme.borderSubtle })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.bgBase)

        // 自定义服务器选择弹窗
        if (this.showPicker) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0,0,0,0.6)')
              .onClick(() => {
                this.showPicker = false;
              })

            Column({ space: 0 }) {
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

              if (this.pickerServers.length === 0) {
                Column({ space: 8 }) {
                  Text('暂无服务器')
                    .fontSize(14)
                    .fontColor(AppTheme.textTertiary)
                  Text('请先在服务器管理中添加 SSH 服务器')
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

                          Circle({ width: 8, height: 8 })
                            .fill(this.serverStatusColor(s))

                          Text(s.connectionMode === 'direct' ? '直连' : 'Agent')
                            .fontSize(10)
                            .fontColor(s.connectionMode === 'direct' ? AppTheme.warning : AppTheme.primary)
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .borderRadius(4)
                            .backgroundColor(s.connectionMode === 'direct'
                              ? 'rgba(245,158,11,0.12)' : AppTheme.primaryDim)

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
}

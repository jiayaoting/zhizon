// 智子 - SSH 终端页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { MockData } from '../service/MockData';

@Component
export struct TerminalPage {
  @State activeSession: number = 0;
  @State cmdInput: string = '';
  @State terminalLines: string[] = [...MockData.terminalLines];
  private sessions: string[] = ['prod-web-01', 'prod-db-master', 'dev-test-01'];
  private sessionCwds: string[] = ['~/projects', '~/data', '~/test'];
  private quickCmds: string[] = ['ls -la', 'cd ~', 'top', 'df -h', 'free -h', 'docker ps', 'uptime', 'cat /etc/os-release'];

  // 判断是否为命令提示符行
  private isPromptLine(line: string): boolean {
    return line.includes('root@') || line.includes('#');
  }

  // 发送命令（mock 实现：追加到终端输出）
  private sendCommand(cmd: string) {
    if (!cmd.trim()) return;
    const server = this.sessions[this.activeSession] || 'server';
    const prompt = `root@${server}:~# ${cmd}`;
    // Mock 响应
    let output = '';
    if (cmd === 'ls -la' || cmd === 'ls') {
      output = 'total 32\ndrwxr-xr-x  4 root root 4096 Aug  4 09:15 .\ndrwxr-xr-x  3 root root 4096 Aug  3 21:05 ..\n-rw-------  1 root root 12800 Aug  3 21:05 .bash_history';
    } else if (cmd === 'uptime') {
      output = ' 09:15:22 up 52 days,  7:36,  2 users,  load average: 0.42, 0.38, 0.40';
    } else if (cmd === 'df -h') {
      output = 'Filesystem      Size  Used Avail Use% Mounted on\n/dev/vda1        50G   31G   17G  62% /';
    } else if (cmd === 'free -h') {
      output = '               total        used        free      shared  buff/cache   available\nMem:            16Gi       7.2Gi       4.8Gi       256Mi       4.0Gi       8.5Gi';
    } else if (cmd === 'docker ps') {
      output = 'CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES\na1b2c3d4e5f6   nginx:latest   Up 3 days      0.0.0.0:80->80/tcp     web-nginx';
    } else {
      output = `bash: ${cmd}: command mock executed`;
    }
    this.terminalLines = [...this.terminalLines, prompt, output, `root@${server}:~# `];
    this.cmdInput = '';
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

      // 主区域：左侧会话列表 + 右侧终端
      Row() {
        // 左侧会话列表
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
              ForEach(this.terminalLines, (line: string) => {
                Text(line)
                  .fontSize(12)
                  .fontFamily(AppTheme.fontMono)
                  .fontColor(this.isPromptLine(line) ? '#00FF88' : '#00D9A3')
                  .width('100%')
              }, (line: string, idx: number) => `${idx}-${line}`)
            }
            .width('100%')
            .padding(12)
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
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
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
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
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

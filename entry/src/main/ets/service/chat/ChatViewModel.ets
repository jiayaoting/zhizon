// 智子 - 聊天生成状态机（idle → connecting → streaming → idle / stopped）
// 集中管理生成阶段、计时器与用户停止标记，UI 通过回调订阅状态变化

export type ChatPhase = 'idle' | 'connecting' | 'streaming' | 'stopped';

export class ChatViewModel {
  private phase: ChatPhase = 'idle';
  private elapsedSeconds: number = 0;
  private timer: number = -1;
  private timerActive: boolean = false;
  private stoppedByUser: boolean = false;

  // 状态回调（由 UI 组件注入，更新 @State）
  onPhaseChange: (phase: ChatPhase) => void = () => {};
  onElapsedChange: (seconds: number) => void = () => {};

  getPhase(): ChatPhase {
    return this.phase;
  }

  getElapsedSeconds(): number {
    return this.elapsedSeconds;
  }

  getStoppedByUser(): boolean {
    return this.stoppedByUser;
  }

  // 开始生成：进入 connecting，重置计时并启动 1s 定时器
  start(): void {
    this.phase = 'connecting';
    this.elapsedSeconds = 0;
    this.stoppedByUser = false;
    this.onPhaseChange(this.phase);
    this.onElapsedChange(this.elapsedSeconds);
    this.startTimer();
  }

  // 首个增量到达：connecting → streaming
  markStreaming(): void {
    if (this.phase === 'connecting') {
      this.phase = 'streaming';
      this.onPhaseChange(this.phase);
    }
  }

  // 用户点击停止：记录标记并进入 stopped（保留已生成内容）
  stopByUser(): void {
    this.stoppedByUser = true;
    this.phase = 'stopped';
    this.stopTimer();
    this.onPhaseChange(this.phase);
  }

  // 生成流程结束（无论成功/失败/停止）：回到 idle 并停止计时
  finish(): void {
    this.phase = 'idle';
    this.stopTimer();
    this.onPhaseChange(this.phase);
  }

  // 组件销毁时清理定时器
  dispose(): void {
    this.stopTimer();
  }

  private startTimer(): void {
    this.stopTimer();
    this.timerActive = true;
    this.timer = setInterval(() => {
      this.elapsedSeconds = this.elapsedSeconds + 1;
      this.onElapsedChange(this.elapsedSeconds);
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerActive && this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.timer = -1;
    this.timerActive = false;
  }
}

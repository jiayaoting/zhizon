// 智子 - 数据模型定义

// 快捷命令
export interface Command {
  id: string;
  name: string;
  cmd: string;
  category: string;
  uses: number;
}

// 告警
export interface Alert {
  id: string;
  level: 'critical' | 'warning' | 'info';
  source: string;
  title: string;
  detail: string;
  time: string;
  resolved: boolean;
}

// 统计数据
export interface Stats {
  total: number;
  online: number;
  warning: number;
  offline: number;
  alerts: number;
}

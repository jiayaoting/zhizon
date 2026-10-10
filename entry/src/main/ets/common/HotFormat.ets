// 智子 - 热榜时间格式化工具

// 相对时间（条目时间戳 → 「3 分钟前」）
export function hotRelativeTime(ts: number): string {
  if (ts <= 0) return '';
  const diff: number = Date.now() - ts;
  if (diff < 60000) return '刚刚';
  const min: number = Math.floor(diff / 60000);
  if (min < 60) return min.toString() + ' 分钟前';
  const hours: number = Math.floor(min / 60);
  if (hours < 24) return hours.toString() + ' 小时前';
  const days: number = Math.floor(hours / 24);
  if (days === 1) return '昨天';
  if (days < 7) return days.toString() + ' 天前';
  const d: Date = new Date(ts);
  return (d.getMonth() + 1).toString() + '-' + d.getDate().toString();
}

// 时钟时间（榜单更新时间 → 「10:24」；跨天显示「昨天 10:24」）
export function hotClockTime(ts: number): string {
  if (ts <= 0) return '';
  const d: Date = new Date(ts);
  const pad = (n: number): string => n < 10 ? '0' + n.toString() : n.toString();
  const clock: string = pad(d.getHours()) + ':' + pad(d.getMinutes());
  const now: Date = new Date();
  const sameDay: boolean = d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
  if (sameDay) return clock;
  return (d.getMonth() + 1).toString() + '-' + d.getDate().toString() + ' ' + clock;
}

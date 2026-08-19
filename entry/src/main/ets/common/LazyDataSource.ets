// 智子 - LazyForEach 通用数据源（长列表懒加载）
export class LazyListDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private data: T[] = [];

  constructor(data: T[]) {
    this.data = data;
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): T {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 整体刷新（数组内容变化后调用）
  reload(): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }

  // 替换底层数组并整体刷新
  replace(data: T[]): void {
    this.data = data;
    this.reload();
  }

  // 原地更新单个元素
  change(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataChange(index);
    }
  }

  // 通知新增（index 为新元素位置）
  add(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataAdd(index);
    }
  }

  // 通知删除
  remove(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataDelete(index);
    }
  }

  // 直接访问底层数组（供页面读取，避免额外副本）
  items(): T[] {
    return this.data;
  }

  setDataAt(index: number, value: T): void {
    this.data[index] = value;
  }
}

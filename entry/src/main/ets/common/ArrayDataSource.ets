// 智子 - 通用数组数据源（LazyForEach 适配）
// 用于长列表的按需渲染，避免一次性创建全部子组件

export class ArrayDataSource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(items: T[] = []) {
    this.items = items;
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): T {
    return this.items[index];
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

  // 全量替换数据并通知刷新
  reloadAll(items: T[]): void {
    this.items = items;
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }

  // 追加单条数据
  append(item: T): void {
    this.items.push(item);
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataAdd(this.items.length - 1);
    }
  }

  // 获取当前数据快照（只读用途）
  snapshot(): T[] {
    return this.items;
  }

  // 清空数据
  clear(): void {
    this.items = [];
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}

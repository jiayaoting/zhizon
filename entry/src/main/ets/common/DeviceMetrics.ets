// 智子 - 设备尺寸工具：跨设备自适应棋盘格子计算
import { display } from '@kit.ArkUI';

export class DeviceMetrics {
  static widthVp(): number {
    try {
      const d = display.getDefaultDisplaySync();
      const w: number = d.width / d.densityPixels;
      return w > 0 ? w : 360;
    } catch (e) {
      return 360;
    }
  }

  static heightVp(): number {
    try {
      const d = display.getDefaultDisplaySync();
      const h: number = d.height / d.densityPixels;
      return h > 0 ? h : 800;
    } catch (e) {
      return 800;
    }
  }

  // 计算棋盘格子尺寸：同时满足宽度与高度约束，并限制在 [minCell, maxCell]
  static fitCellSize(cols: number, rows: number, overheadH: number, minCell: number, maxCell: number): number {
    const availW: number = DeviceMetrics.widthVp() - 32;
    const availH: number = DeviceMetrics.heightVp() - overheadH;
    let cell: number = Math.floor(Math.min(availW / cols, availH / rows));
    if (cell < minCell) cell = minCell;
    if (cell > maxCell) cell = maxCell;
    return cell;
  }
}

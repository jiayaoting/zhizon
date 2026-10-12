// 智子 - 毛玻璃效果工具组件
// 用法：作为属性方法调用，根据开关状态自动切换玻璃/纯色
import { ThemePalette } from '../common/Theme';
import { batteryInfo } from '@kit.BasicServicesKit';

// 玻璃效果级别：P0(顶栏/底栏)、P1(指标卡)、P2(列表卡)
export enum GlassLevel {
  P0_BAR = 'P0_BAR',
  P1_CARD = 'P1_CARD',
  P2_LIST = 'P2_LIST'
}

// 视觉特效性能预算：低电量时由各视觉组件自动降级（batterySOC 为静态常量，无需权限）
export class FxBudget {
  // 电量低于 20% 视为低电量；个别设备/模拟器不可用时返回 false（不降级）
  static isLowBattery(): boolean {
    try {
      return batteryInfo.batterySOC < 20;
    } catch (err) {
      console.error('FxBudget.isLowBattery failed: ' + JSON.stringify(err));
      return false;
    }
  }
}

// 封装：v10 起玻璃材质**仅用于 P0 级**（底栏/侧边栏/悬浮条）；
// P1/P2 内容卡一律返回纯色面（白底上玻璃会显脏），边框使用发丝分割线。
export class GlassStyle {
  // 返回该级别应使用的背景色（考虑玻璃开关）
  static backgroundColor(enabled: boolean, level: GlassLevel, palette: ThemePalette): string {
    if (level === GlassLevel.P0_BAR) {
      return enabled ? palette.bgGlassBar : palette.bgSurface;
    }
    // 内容卡不再使用玻璃
    return palette.bgSurface;
  }

  // 返回该级别应使用的边框色（考虑玻璃开关）
  static borderColor(enabled: boolean, level: GlassLevel, palette: ThemePalette): string {
    if (level === GlassLevel.P0_BAR && enabled) return palette.borderGlass;
    return palette.divider;
  }

  // 返回卡内次级元素背景色（如 card 内的 badge、btn）
  static innerBackgroundColor(enabled: boolean, palette: ThemePalette): string {
    return palette.bgSurface2;
  }
}

// ============================================================
// 通用 Glass 属性包裹：在组件 build 中作为修饰器链调用
//
// 使用示例：
//   Column() { ... }
//     .width('100%')
//     .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette))
//     .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P1_CARD, this.palette) })
//     // 最后调用：如果开启，则加 blur
//     .backgroundBlurStyle(this.glassEnabled ? BlurStyle.Component_Thick : BlurStyle.None)
// ============================================================

// GlassBlur 映射：v10 仅 P0（底栏/侧边栏/悬浮条）允许模糊
export function glassBlurStyle(enabled: boolean, level: GlassLevel): BlurStyle {
  if (!enabled) return BlurStyle.NONE;
  if (level === GlassLevel.P0_BAR) return BlurStyle.COMPONENT_THICK;
  return BlurStyle.NONE;
}

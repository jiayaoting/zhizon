// 智子 - 毛玻璃效果工具组件
// 用法：作为属性方法调用，根据开关状态自动切换玻璃/纯色
import { ThemePalette, defaultLightPalette } from '../common/Theme';

// 玻璃效果级别：P0(顶栏/底栏)、P1(指标卡)、P2(列表卡)
export enum GlassLevel {
  P0_BAR = 'P0_BAR',
  P1_CARD = 'P1_CARD',
  P2_LIST = 'P2_LIST'
}

// 封装：对组件根容器有条件地应用玻璃 blur 样式
// - 开启时: backgroundBlurStyle + 半透明玻璃色 + 玻璃边框
// - 关闭时: 使用 palette 原色作为 fallback
export class GlassStyle {
  // 返回该级别应使用的背景色（考虑开关）
  static backgroundColor(enabled: boolean, level: GlassLevel, palette: ThemePalette): string {
    if (!enabled) {
      if (level === GlassLevel.P0_BAR) return palette.bgSurface;
      if (level === GlassLevel.P1_CARD) return palette.bgSurface;
      return palette.bgSurface;
    }
    if (level === GlassLevel.P0_BAR) return palette.bgGlassBar;
    if (level === GlassLevel.P1_CARD) return palette.bgGlassCard;
    return palette.bgGlassCard;
  }

  // 返回该级别应使用的边框色（考虑开关）
  static borderColor(enabled: boolean, level: GlassLevel, palette: ThemePalette): string {
    if (!enabled) return palette.borderSubtle;
    return palette.borderGlass;
  }

  // 返回卡内次级元素背景色（如 card 内的 badge、btn）
  static innerBackgroundColor(enabled: boolean, palette: ThemePalette): string {
    if (!enabled) return palette.bgSurface2;
    return palette.bgGlassCard2;
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

// GlassBlur 映射：不同级别对应不同 BlurStyle preset
export function glassBlurStyle(enabled: boolean, level: GlassLevel): BlurStyle {
  if (!enabled) return BlurStyle.NONE;
  if (level === GlassLevel.P0_BAR) return BlurStyle.COMPONENT_THICK;
  if (level === GlassLevel.P1_CARD) return BlurStyle.COMPONENT_THIN;
  return BlurStyle.COMPONENT_THIN;
}

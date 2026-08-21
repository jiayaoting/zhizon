// 智子 - 星尘粒子背景（基于 HarmonyOS Particle 粒子动画组件）
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';
import { FxBudget } from './GlassEffect';

@ComponentV2
export struct ParticleBackground {
  @Local themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;

  build() {
    Stack() {
      if (!FxBudget.isLowBattery()) {
        Particle({
        particles: [
          {
            emitter: {
              particle: {
                type: ParticleType.POINT,
                config: { radius: 2 },
                count: 50,
                lifetime: 8000,
                lifetimeRange: 4000
              },
              emitRate: 12,
              shape: ParticleEmitterShape.RECTANGLE,
              position: [0, 0],
              size: ['100%', '100%']
            },
            color: {
              range: [this.themeState.palette.primary, this.themeState.palette.purple],
              distributionType: DistributionType.UNIFORM
            },
            opacity: {
              range: [0.12, 0.55],
              updater: {
                type: ParticleUpdater.CURVE,
                config: [
                  { from: 0.0, to: 0.55, startMillis: 0, endMillis: 4000, curve: Curve.EaseInOut },
                  { from: 0.55, to: 0.0, startMillis: 4000, endMillis: 8000, curve: Curve.EaseInOut }
                ]
              }
            },
            scale: {
              range: [0.5, 1.1],
              updater: {
                type: ParticleUpdater.CURVE,
                config: [
                  { from: 0.3, to: 1.0, startMillis: 0, endMillis: 8000, curve: Curve.EaseInOut }
                ]
              }
            },
            velocity: {
              speed: [8, 26],
              angle: [255, 285]
            },
            acceleration: {
              speed: { range: [1, 3] },
              angle: { range: [270, 270] }
            }
          },
          {
            emitter: {
              particle: {
                type: ParticleType.POINT,
                config: { radius: 1.2 },
                count: 30,
                lifetime: 10000,
                lifetimeRange: 5000
              },
              emitRate: 6,
              shape: ParticleEmitterShape.RECTANGLE,
              position: [0, 0],
              size: ['100%', '100%']
            },
            color: {
              range: ['rgba(255,255,255,0.9)', 'rgba(190,205,255,0.9)'],
              distributionType: DistributionType.UNIFORM
            },
            opacity: {
              range: [0.08, 0.35],
              updater: {
                type: ParticleUpdater.CURVE,
                config: [
                  { from: 0.0, to: 0.35, startMillis: 0, endMillis: 5000, curve: Curve.EaseInOut },
                  { from: 0.35, to: 0.0, startMillis: 5000, endMillis: 10000, curve: Curve.EaseInOut }
                ]
              }
            },
            scale: {
              range: [0.3, 0.7]
            },
            velocity: {
              speed: [4, 14],
              angle: [250, 290]
            }
          }
        ]
      })
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}

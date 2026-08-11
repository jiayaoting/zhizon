// 智子 - 开源字体注册（全部为免费商用授权，无版权风险）
// 授权说明：
//   JetBrains Mono   - SIL OFL 1.1
//   Fira Code        - SIL OFL 1.1
//   Inter            - SIL OFL 1.1
import { font } from '@kit.ArkUI';

@Component
export struct FontRegistry {
  // 在 UI 上下文中注册 rawfile 内打包的开源字体
  aboutToAppear(): void {
    try {
      font.registerFont({
        familyName: 'JetBrains Mono',
        familySrc: $rawfile('fonts/JetBrainsMono-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Fira Code',
        familySrc: $rawfile('fonts/FiraCode-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Inter',
        familySrc: $rawfile('fonts/Inter-Regular.ttf')
      });
    } catch (e) {
      // 注册失败时静默回退系统字体
    }
  }

  build() {
    // 无可见 UI
    Row()
      .width(0)
      .height(0)
  }
}

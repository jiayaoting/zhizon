// 智子 - 开源字体注册（全部为免费商用授权，无版权风险）
// 授权说明（SIL OFL 1.1）：
//   JetBrains Mono   - The JetBrains Mono Project Authors
//   Fira Code        - The Fira Code Project Authors
//   Inter            - The Inter Project Authors
//   Lobster          - The Lobster Project Authors
//   Pacifico         - The Pacifico Project Authors
//   Bebas Neue       - The Bebas Neue Project Authors
//   Righteous        - The Righteous Project Authors
//   Press Start 2P   - The Press Start 2P Project Authors
//   Orbitron         - The Orbitron Project Authors
//   Dancing Script   - The Dancing Script Project Authors
//   ZCOOL KuaiLe     - The ZCOOL KuaiLe Project Authors（中文字体）
import { font } from '@kit.ArkUI';

@ComponentV2
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
      font.registerFont({
        familyName: 'Lobster',
        familySrc: $rawfile('fonts/Lobster-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Pacifico',
        familySrc: $rawfile('fonts/Pacifico-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Bebas Neue',
        familySrc: $rawfile('fonts/BebasNeue-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Righteous',
        familySrc: $rawfile('fonts/Righteous-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Press Start 2P',
        familySrc: $rawfile('fonts/PressStart2P-Regular.ttf')
      });
      font.registerFont({
        familyName: 'Orbitron',
        familySrc: $rawfile('fonts/Orbitron-Variable.ttf')
      });
      font.registerFont({
        familyName: 'Dancing Script',
        familySrc: $rawfile('fonts/DancingScript-Variable.ttf')
      });
      font.registerFont({
        familyName: 'ZCOOL KuaiLe',
        familySrc: $rawfile('fonts/ZCOOLKuaiLe-Regular.ttf')
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

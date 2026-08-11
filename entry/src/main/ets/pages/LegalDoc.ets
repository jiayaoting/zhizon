// 智子 - 用户协议 / 隐私政策 / 开源许可 通用展示页
import { router } from '@kit.ArkUI';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { LegalDocRouteParams } from '../common/Navigation';

export enum LegalDocType {
  AGREEMENT = 'agreement',
  PRIVACY = 'privacy',
  LICENSE = 'license'
}

interface DocSection {
  title: string;
  paragraphs: string[];
}

export function isLegalDocType(value: string): boolean {
  return value === LegalDocType.AGREEMENT || value === LegalDocType.PRIVACY || value === LegalDocType.LICENSE;
}

function docTitle(type: LegalDocType): string {
  if (type === LegalDocType.PRIVACY) return '隐私政策';
  if (type === LegalDocType.LICENSE) return '开源许可';
  return '用户协议';
}

function docUpdateTime(type: LegalDocType): string {
  if (type === LegalDocType.PRIVACY) return '更新日期：2026 年 8 月 11 日';
  if (type === LegalDocType.LICENSE) return '生效日期：2026 年 8 月 11 日';
  return '更新日期：2026 年 8 月 11 日';
}

function agreementSections(): DocSection[] {
  return [
    {
      title: '一、协议的接受与适用范围',
      paragraphs: [
        '欢迎使用「智子」（以下简称"本应用"）。本用户协议（以下简称"本协议"）是您与本应用开发者之间就使用本应用所达成的法律协议。',
        '在下载、安装、使用本应用前，请您仔细阅读并充分理解本协议的全部内容。您一旦使用本应用，即视为您已阅读并同意接受本协议的全部条款。若您不同意本协议的任何条款，请立即停止使用本应用。'
      ]
    },
    {
      title: '二、服务内容',
      paragraphs: [
        '本应用向您提供休闲小游戏服务（包括俄罗斯方块、2048、贪吃蛇）以及个性化外观设置服务（包括多套颜色主题、明暗模式、自定义背景图与毛玻璃效果）。',
        '本应用有权根据运营需要，随时对服务内容进行调整、变更、暂停或终止，并尽可能以合理方式提前通知您。'
      ]
    },
    {
      title: '三、用户行为规范',
      paragraphs: [
        '您在使用本应用时应遵守法律法规，不得利用本应用从事任何违法、违规或侵害他人合法权益的行为。',
        '您不得对本应用进行反向工程、反编译、反汇编，不得复制、修改、传播本应用的源代码，不得利用本应用从事商业牟利活动。'
      ]
    },
    {
      title: '四、数据与隐私',
      paragraphs: [
        '本应用会依法收集和使用您的个人信息，具体内容与方式详见《隐私政策》。',
        '您设置的本地数据（如游戏战绩、外观偏好）仅保存在您的设备本地，本应用不进行云端存储。'
      ]
    },
    {
      title: '五、知识产权',
      paragraphs: [
        '本应用及其相关的软件、界面设计、图标、文字内容等知识产权归开发者所有，受相关法律法规保护。',
        '未经开发者书面许可，您不得以任何形式复制、转载、修改或传播本应用的相关内容。'
      ]
    },
    {
      title: '六、免责声明',
      paragraphs: [
        '本应用按"现状"提供，开发者不对服务的适用性、可靠性作出任何明示或默示的保证。',
        '在法律允许的最大范围内，因您使用本应用或无法使用本应用而导致的直接或间接损失，开发者不承担赔偿责任。'
      ]
    },
    {
      title: '七、协议的变更',
      paragraphs: [
        '开发者有权根据法律法规变化或业务需要修改本协议。协议更新后，将在应用内以适当方式提示您。',
        '若您在本协议变更后继续使用本应用，即视为您已接受变更后的协议。'
      ]
    },
    {
      title: '八、联系我们',
      paragraphs: [
        '如您对本协议或本应用有任何疑问、意见或建议，可通过应用内的"反馈"入口与我们联系。',
        '本协议自您开始使用本应用之日起生效。'
      ]
    }
  ];
}

function privacySections(): DocSection[] {
  return [
    {
      title: '一、引言',
      paragraphs: [
        '本隐私政策旨在向您说明「智子」（以下简称"本应用"）如何收集、使用、存储和保护您的个人信息。我们非常重视您的隐私，并承诺遵循合法、正当、必要和诚信原则处理您的信息。',
        '本政策自发布之日起生效。请您在使用本应用前仔细阅读本政策，若您不同意本政策的任何内容，请停止使用本应用。'
      ]
    },
    {
      title: '二、我们收集的信息',
      paragraphs: [
        '本地设置信息：包括您选择的颜色主题、明暗模式、字号字体、毛玻璃开关、自定义背景图等外观偏好，以及自动备份等开关状态。这些信息仅保存在您的设备本地。',
        '游戏战绩信息：包括您在俄罗斯方块、2048、贪吃蛇中的得分、难度等级与完成时间，仅保存在您的设备本地数据库。',
        '设备权限信息：当您选择自定义背景图时，我们会在您的授权下访问系统相册中的图片（读取媒体文件权限），仅用于设置应用背景图，不会上传或用于其他用途。'
      ]
    },
    {
      title: '三、我们如何使用信息',
      paragraphs: [
        '提供与优化服务：根据您的偏好设置呈现对应外观，记录游戏成绩以提供历史战绩与排行功能。',
        '改进产品体验：通过分析功能使用情况（本地统计）持续优化界面与交互，不涉及任何个人信息上传。'
      ]
    },
    {
      title: '四、信息的存储与保护',
      paragraphs: [
        '本应用产生的数据均存储于您的设备本地，不进行云端存储或同步。',
        '我们采用设备系统提供的安全存储能力保护您的数据，并建议您妥善保管设备与系统账户。'
      ]
    },
    {
      title: '五、权限说明',
      paragraphs: [
        '读取媒体文件（ohos.permission.READ_MEDIA / WRITE_MEDIA）：仅在您主动选择自定义背景图时申请使用，用于读取并设置所选图片，设置完成后不再访问。',
        '您可以随时在系统设置中关闭本应用的权限授权，关闭后仅影响对应功能（如更换背景图），不影响其他功能的使用。'
      ]
    },
    {
      title: '六、未成年人保护',
      paragraphs: [
        '本应用面向一般公众提供休闲娱乐服务。若您为未成年人，请在监护人指导下使用本应用，并征得监护人同意。',
        '我们不会主动收集未成年人的个人信息，如监护人发现未成年人提供了个人信息，可通过"反馈"入口联系我们处理。'
      ]
    },
    {
      title: '七、政策的更新',
      paragraphs: [
        '我们可能适时修订本政策。政策变更后，我们会在应用内以显著方式提示您。',
        '重大变更包括但不限于：收集信息的范围、信息的使用目的、您对信息的控制方式等发生变化。'
      ]
    },
    {
      title: '八、联系我们',
      paragraphs: [
        '若您对本隐私政策有任何疑问、意见或建议，可通过应用内的"反馈"入口与我们联系。',
        '我们将在收到您的反馈后尽快予以处理与答复。'
      ]
    }
  ];
}

function licenseSections(): DocSection[] {
  return [
    {
      title: '一、本应用许可证',
      paragraphs: [
        '「智子」应用本体基于 MIT License 发布，版权归应用开发者所有。',
        'MIT License 允许任何人免费使用、复制、修改、合并、发布、分发、再许可和/或销售本软件的副本，但需在软件和软件的所有副本中保留上述版权声明和本许可声明。'
      ]
    },
    {
      title: '二、MIT License',
      paragraphs: [
        'Copyright (c) 2026 智子开发者',
        '',
        'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:',
        'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.',
        'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'
      ]
    },
    {
      title: '三、第三方开源组件',
      paragraphs: [
        '本应用当前版本不依赖任何第三方运行时组件，所有功能均基于 HarmonyOS 系统能力与开源软件构建。',
        '本应用使用 HarmonyOS SDK 提供的标准能力（ArkUI 声明式开发框架、Ability 框架、本地数据库等），其使用遵循华为开发者协议及相关开源许可。'
      ]
    },
    {
      title: '四、测试依赖',
      paragraphs: [
        '本应用的单元测试使用 @ohos/hypium（1.0.21）测试框架，遵循其对应的 Apache License 2.0 开源协议。',
        'Apache License 2.0 允许使用者自由使用、修改、分发软件，并允许商业化使用，但需保留原始版权声明并注明修改内容。'
      ]
    },
    {
      title: '五、字体说明',
      paragraphs: [
        '应用内可选字体均为免费商用授权，不涉及版权风险：',
        'HarmonyOS Sans：系统内置字体，随 HarmonyOS 系统免费授权使用，版权归华为技术有限公司所有。',
        'Inter：SIL Open Font License 1.1，可免费商用，版权归 The Inter Project Authors。',
        'JetBrains Mono：SIL OFL 1.1，可免费商用，版权归 The JetBrains Mono Project Authors。',
        'Fira Code：SIL OFL 1.1，可免费商用，版权归 The Fira Code Project Authors。',
        'Lobster：SIL OFL 1.1，艺术展示体，版权归 The Lobster Project Authors。',
        'Pacifico：SIL OFL 1.1，手写波浪体，版权归 The Pacifico Project Authors。',
        'Bebas Neue：SIL OFL 1.1，紧凑标题体，版权归 The Bebas Neue Project Authors。',
        'Righteous：SIL OFL 1.1，圆润展示体，版权归 The Righteous Project Authors。',
        'Press Start 2P：SIL OFL 1.1，像素风游戏字体，版权归 The Press Start 2P Project Authors。',
        'Orbitron：SIL OFL 1.1，科技感几何体，版权归 The Orbitron Project Authors。',
        'Dancing Script：SIL OFL 1.1，优雅手写斜体，版权归 The Dancing Script Project Authors。',
        '站酷快乐体（ZCOOL KuaiLe）：SIL OFL 1.1，中文艺术字体，含常用中文字形，版权归 The ZCOOL KuaiLe Project Authors。',
        '以上开源字体文件及其 OFL 许可文本均已随应用打包（rawfile/fonts 目录）。'
      ]
    },
    {
      title: '六、其他声明',
      paragraphs: [
        '本应用内置的游戏图标与界面设计素材，版权归开发者所有，未经许可不得擅自使用。',
        '如您对本应用的开源许可有任何疑问，可通过应用内的"反馈"入口与我们联系。'
      ]
    }
  ];
}

@Entry
@Component
export struct LegalDocPage {
  @State docType: LegalDocType = LegalDocType.AGREEMENT;
  @StorageLink('isSm') isSm: boolean = false;
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;

  aboutToAppear(): void {
    const params: LegalDocRouteParams | null = router.getParams() as LegalDocRouteParams | null;
    if (params !== null && params !== undefined && isLegalDocType(params.type)) {
      this.docType = params.type as LegalDocType;
    }
  }

  private sections(): DocSection[] {
    if (this.docType === LegalDocType.PRIVACY) return privacySections();
    if (this.docType === LegalDocType.LICENSE) return licenseSections();
    return agreementSections();
  }

  @Builder
  sectionCard(section: DocSection) {
    Column({ space: 10 }) {
      Text(section.title)
        .fontSize(this.palette.fsMd)
        .fontFamily(this.palette.fontSans)
        .fontColor(this.palette.textPrimary)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      ForEach(section.paragraphs, (paragraph: string) => {
        if (paragraph.length > 0) {
          Text(paragraph)
            .fontSize(this.palette.fsBase)
            .fontFamily(this.palette.fontSans)
            .fontColor(this.palette.textSecondary)
            .lineHeight(22)
            .width('100%')
        } else {
          Row()
            .height(8)
            .width('100%')
        }
      }, (paragraph: string) => paragraph)
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      TopBar({ title: docTitle(this.docType), subtitle: docUpdateTime(this.docType), showBack: true })

      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.sections(), (section: DocSection) => {
            this.sectionCard(section)
          }, (section: DocSection) => section.title)
        }
        .width('100%')
        .padding({ left: this.isSm ? 16 : 24, right: this.isSm ? 16 : 24, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .height('100%')
    .backgroundColor(this.palette.bgBase)
  }
}

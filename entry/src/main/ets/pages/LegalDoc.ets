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
  if (type === LegalDocType.PRIVACY) return '更新日期：2026 年 8 月 12 日';
  if (type === LegalDocType.LICENSE) return '生效日期：2026 年 8 月 12 日';
  return '更新日期：2026 年 8 月 12 日';
}

function agreementSections(): DocSection[] {
  return [
    {
      title: '一、协议的接受与适用范围',
      paragraphs: [
        '欢迎使用「智子」（以下简称"本应用"）。本用户协议（以下简称"本协议"）是您与本应用开发者之间就使用本应用所达成的法律协议。',
        '在下载、安装、使用本应用前，请您仔细阅读并充分理解本协议的全部内容。您一旦使用本应用，即视为您已阅读并同意接受本协议的全部条款。若您不同意本协议的任何条款，请立即停止使用本应用。',
        '本应用为开源软件，源码托管于 GitHub（https://github.com/jiayaoting/zhizon），遵循 MIT 开源许可协议发布。任何人可自由使用、复制、修改、合并、发布、分发本软件，但须保留原始版权声明与许可声明。',
        '本应用由 AI（大语言模型）辅助开发。开发过程中，AI 参与了代码生成、架构设计、文档撰写等环节，并由开发者最终审核与确认。本协议中"开发者"指对该应用承担最终责任的自然人或法人。'
      ]
    },
    {
      title: '二、服务内容',
      paragraphs: [
        '本应用向您提供以下服务：(1) 休闲小游戏服务（包括俄罗斯方块、2048、贪吃蛇、扫雷、打砖块、数独）；(2) AI 对话服务（支持用户自行配置大模型 API Key，通过 OpenAI 兼容接口与 LLM 进行对话）；(3) 个性化外观设置服务（包括多套颜色主题、明暗模式、字体字号、应用图标、自定义背景图与毛玻璃效果）。',
        '本应用有权根据运营需要，随时对服务内容进行调整、变更、暂停或终止，并尽可能以合理方式提前通知您。',
        '本应用为本地离线应用，所有游戏数据、设置偏好均存储于您的设备本地。AI 对话功能中，API Key 经 AES-256-GCM 加密后存储于本地，对话请求直接发送至您配置的服务商，本应用不进行任何中转、存储或分析。'
      ]
    },
    {
      title: '三、用户行为规范',
      paragraphs: [
        '您在使用本应用时应遵守中华人民共和国法律法规，包括但不限于《网络安全法》、《个人信息保护法》、《数据安全法》等，不得利用本应用从事任何违法、违规或侵害他人合法权益的行为。',
        '您对本应用的引用、修改和再分发须遵守以下要求：(1) 保留本应用的原始版权声明与 MIT 许可声明；(2) 注明出处，包括但不限于原始 GitHub 仓库地址（https://github.com/jiayaoting/zhizon）；(3) 若修改后发布，需在显著位置标明修改内容与修改时间；(4) 不得移除或隐藏本应用中的开源许可信息。',
        '您不得利用本应用进行任何危害网络安全、国家安全、社会公共利益的活动。'
      ]
    },
    {
      title: '四、数据与隐私',
      paragraphs: [
        '本应用依法收集和使用您的个人信息，具体内容与方式详见《隐私政策》。本应用严格遵守《个人信息保护法》的相关规定，遵循合法、正当、必要和诚信原则处理您的个人信息。',
        '您设置的本地数据（如游戏战绩、外观偏好）仅保存在您的设备本地，本应用不会将您的个人信息传输至境外，不会进行云端存储，不会与第三方共享。',
        '本应用仅在您主动授权时访问设备权限（如读取媒体文件以设置自定义背景图），您可以随时在系统设置中关闭权限。'
      ]
    },
    {
      title: '五、知识产权与开源许可',
      paragraphs: [
        '本应用的源代码基于 MIT License 开源发布，版权归开发者所有。您可以在遵守 MIT 许可条款的前提下，自由使用、复制、修改、合并、发布、分发本软件的源代码。',
        'MIT License 的全文可在本应用内"开源许可"页面查看，也可在 GitHub 仓库的 LICENSE 文件中查阅。',
        '本应用的应用图标、界面设计素材等视觉资产，版权归开发者所有。除 MIT 许可明确授权的范围外，未经开发者书面许可，不得将本应用的视觉资产用于其他产品或服务。',
        '本应用使用的开源字体（包括 Inter、JetBrains Mono、Fira Code、Lobster、Pacifico、Bebas Neue、Righteous、Press Start 2P、Orbitron、Dancing Script、站酷快乐体等）均遵循 SIL Open Font License 1.1 或 Apache License 2.0，可免费商用。各字体的版权声明与许可文本已随应用打包。'
      ]
    },
    {
      title: '六、免责声明',
      paragraphs: [
        '本应用按"现状"提供，开发者不对服务的适用性、可靠性、准确性、及时性作出任何明示或默示的保证。',
        '在法律允许的最大范围内，因您使用本应用或无法使用本应用而导致的任何直接、间接、附带、特殊或后果性损失，开发者不承担赔偿责任。',
        '本应用由 AI 辅助开发，开发者虽已尽力审核代码质量与功能正确性，但不对因代码缺陷导致的任何问题承担责任。如您发现任何缺陷或问题，欢迎通过 GitHub Issues 或应用内反馈渠道报告。'
      ]
    },
    {
      title: '七、协议的变更',
      paragraphs: [
        '开发者有权根据法律法规变化或业务需要修改本协议。协议更新后，将在应用内以适当方式提示您，并在 GitHub 仓库同步更新。',
        '若您在本协议变更后继续使用本应用，即视为您已接受变更后的协议。如您不同意变更，请停止使用本应用。'
      ]
    },
    {
      title: '八、法律适用与争议解决',
      paragraphs: [
        '本协议的订立、执行、解释及争议解决，均适用中华人民共和国大陆地区法律。',
        '如双方就本协议内容或其执行发生任何争议，应首先友好协商解决；协商不成的，任何一方均可向开发者所在地有管辖权的人民法院提起诉讼。'
      ]
    },
    {
      title: '九、联系我们',
      paragraphs: [
        '如您对本协议或本应用有任何疑问、意见或建议，可通过以下方式与我们联系：',
        'GitHub 仓库：https://github.com/jiayaoting/zhizon（提交 Issue 或 Pull Request）',
        '应用内反馈：通过"更多"菜单中的"反馈"入口提交',
        '本协议自您开始使用本应用之日起生效，最新版本可随时在 GitHub 仓库查阅。'
      ]
    }
  ];
}

function privacySections(): DocSection[] {
  return [
    {
      title: '一、引言',
      paragraphs: [
        '本隐私政策旨在向您说明「智子」（以下简称"本应用"）如何收集、使用、存储和保护您的个人信息。我们非常重视您的隐私权，并承诺严格遵循《中华人民共和国个人信息保护法》、《中华人民共和国网络安全法》、《中华人民共和国数据安全法》等法律法规的规定，遵循合法、正当、必要和诚信原则处理您的信息。',
        '本应用由 AI（大语言模型）辅助开发，源码托管于 GitHub（https://github.com/jiayaoting/zhizon），遵循 MIT 开源许可协议发布。',
        '本政策自发布之日起生效。请您在使用本应用前仔细阅读本政策，若您不同意本政策的任何内容，请停止使用本应用。'
      ]
    },
    {
      title: '二、我们收集的信息',
      paragraphs: [
        '本地设置信息：包括您选择的颜色主题、明暗模式、字号字体、应用图标、毛玻璃开关、自定义背景图等外观偏好，以及自动备份等开关状态。这些信息仅保存在您的设备本地，不进行任何形式的网络传输。',
        '游戏战绩信息：包括您在俄罗斯方块、2048、贪吃蛇、扫雷、打砖块、数独中的得分、难度等级与完成时间，仅保存在您的设备本地数据库。',
        'AI 对话配置信息：包括您自行配置的大模型服务商、接口地址、API Key（加密存储）、模型名称、温度参数。API Key 使用 AES-256-GCM 算法加密后存储于本地数据库，不会以明文形式泄露。对话历史记录保存于本地，不进行云端同步。',
        'AI 对话请求数据：当您使用 AI 对话功能时，对话内容会直接发送至您配置的大模型服务商（如 OpenAI、DeepSeek 等），本应用不进行数据中转、存储或分析。对话请求仅在您主动发起时建立网络连接，发送完成后即断开。',
        '设备权限信息：当您选择自定义背景图时，我们会在您的授权下访问系统相册中的图片（读取媒体文件权限），仅用于设置应用背景图，不会上传或用于其他用途。当您进行游戏时，我们会调用设备振动功能（振动权限），仅用于触觉反馈，不涉及信息收集。AI 对话功能需要网络权限（INTERNET）以连接您配置的大模型服务商。'
      ]
    },
    {
      title: '三、我们如何使用信息',
      paragraphs: [
        '提供与优化服务：根据您的偏好设置呈现对应外观，记录游戏成绩以提供历史战绩与排行功能。AI 对话场景中，根据您的配置连接相应大模型服务商以提供对话能力。',
        '改进产品体验：通过分析功能使用情况（本地统计）持续优化界面与交互，不涉及任何个人信息上传。',
        '我们不会将您的个人信息用于自动化决策，不会基于您的个人信息进行用户画像，不会将您的个人信息用于任何商业营销目的。'
      ]
    },
    {
      title: '四、信息的存储与保护',
      paragraphs: [
        '本应用产生的所有数据均存储于您的设备本地，不进行云端存储或同步。AI 对话的 API Key 使用 AES-256-GCM 加密后存储，对话历史记录存储于本地数据库。',
        '我们采用 HarmonyOS 系统提供的安全存储能力（RelationalStore）保护您的数据，并建议您妥善保管设备与系统账户。',
        '根据《个人信息保护法》的要求，我们不会将您的个人信息传输至中华人民共和国境外。AI 对话内容由您直接发送至您配置的服务商，数据流向取决于您所选择的服务商服务器所在地。',
        '如因业务需要确需向境外提供，我们将严格按照法律规定取得您的单独同意并进行安全评估。'
      ]
    },
    {
      title: '五、权限说明',
      paragraphs: [
        '网络权限（ohos.permission.INTERNET）：当您使用 AI 对话功能时，用于连接您自行配置的大模型服务商 API。本应用不会通过该权限进行任何其他网络通信，不会上传任何您的个人信息。',
        '读取/写入媒体文件（ohos.permission.READ_MEDIA / WRITE_MEDIA）：仅在您主动选择自定义背景图时申请使用，用于读取并设置所选图片，设置完成后不再访问。',
        '振动（ohos.permission.VIBRATE）：用于游戏内的触觉反馈（如消除方块、翻出地雷等），不涉及信息收集。',
        '您可以随时在系统设置中关闭本应用的权限授权，关闭后仅影响对应功能（如 AI 对话、更换背景图、振动反馈），不影响其他功能的使用。'
      ]
    },
    {
      title: '六、未成年人保护',
      paragraphs: [
        '本应用面向一般公众提供休闲娱乐服务。若您为未满 14 周岁的未成年人，请在监护人指导下使用本应用，并征得监护人同意。',
        '我们不会主动收集未成年人的个人信息。根据《个人信息保护法》及《儿童个人信息网络保护规定》的要求，如监护人发现未成年人提供了个人信息，可通过"反馈"入口或 GitHub Issues 联系我们处理，我们将在核实后及时删除相关信息。'
      ]
    },
    {
      title: '七、用户权利',
      paragraphs: [
        '根据《个人信息保护法》，您享有以下权利：',
        '(1) 查阅、复制权：您有权查阅、复制您的个人信息，由于本应用数据均存储在本地，您可直接在应用内查看；',
        '(2) 更正、删除权：您有权更正不准确的个人信息或删除您的个人信息，您可在应用内直接修改或删除；',
        '(3) 撤回同意权：您有权撤回对个人信息处理的同意，可通过关闭权限或删除应用行使；',
        '(4) 注销账号权：由于本应用不涉及账号注册，您卸载应用即视为终止使用，所有本地数据将被清除。',
        '如您需要行使上述权利遇到困难，可通过 GitHub Issues 或应用内反馈渠道联系我们。'
      ]
    },
    {
      title: '八、政策的更新',
      paragraphs: [
        '我们可能适时修订本政策。政策变更后，我们会在应用内以显著方式提示您，并在 GitHub 仓库同步更新。',
        '重大变更包括但不限于：收集信息的范围变更、信息的使用目的变更、您对信息的控制方式变更。'
      ]
    },
    {
      title: '九、联系我们',
      paragraphs: [
        '若您对本隐私政策有任何疑问、意见或建议，可通过以下方式与我们联系：',
        'GitHub 仓库：https://github.com/jiayaoting/zhizon（提交 Issue）',
        '应用内反馈：通过"更多"菜单中的"反馈"入口提交',
        '我们将在收到您的反馈后尽快予以处理与答复。'
      ]
    }
  ];
}

function licenseSections(): DocSection[] {
  return [
    {
      title: '零、AI 开发声明',
      paragraphs: [
        '「智子」应用由 AI（大语言模型）辅助开发。开发过程中，AI 参与了代码生成、架构设计、界面布局、文档撰写、测试用例生成等环节，所有由 AI 生成的内容均经过人类开发者审核与确认。',
        '本应用的开源性质不因 AI 参与开发而改变。所有源代码按 MIT License 发布，您可在遵守许可条款的前提下自由使用、复制、修改、合并、发布、分发。',
        'AI 辅助开发的具体范围包括：ArkTS 代码编写、ArkUI 组件构建、游戏逻辑实现、主题系统设计、响应式布局适配、字体注册与管理、法律文档起草等。',
        '项目源码地址：https://github.com/jiayaoting/zhizon'
      ]
    },
    {
      title: '一、本应用许可证',
      paragraphs: [
        '「智子」应用本体（包括所有源代码、配置文件、资源文件）基于 MIT License 发布，版权归应用开发者所有。',
        'MIT License 允许任何人免费使用、复制、修改、合并、发布、分发、再许可和/或销售本软件的副本，但需在软件和软件的所有副本中保留上述版权声明和本许可声明。',
        '如需引用或修改本应用，请遵守以下要求：',
        '(1) 保留原始版权声明与 MIT 许可声明；',
        '(2) 在显著位置注明出处，包括原始 GitHub 仓库地址（https://github.com/jiayaoting/zhizon）；',
        '(3) 若修改后发布，请在修改处或文档中注明修改内容与修改时间；',
        '(4) 不得移除或隐藏本应用中的开源许可信息与版权声明。'
      ]
    },
    {
      title: '二、MIT License 原文',
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
        '本应用使用 HarmonyOS SDK 提供的标准能力（ArkUI 声明式开发框架、Ability 框架、本地数据库 RelationalStore 等），其使用遵循华为开发者协议及相关开源许可。',
        '本应用的单元测试使用 @ohos/hypium（1.0.21）测试框架，遵循 Apache License 2.0 开源协议。Apache License 2.0 允许使用者自由使用、修改、分发软件，并允许商业化使用，但需保留原始版权声明并注明修改内容。',
        'AI 对话功能通过 OpenAI 兼容 API 协议（/v1/chat/completions）与第三方大模型服务商通信，用户可自行选择服务商（包括 OpenAI、DeepSeek、阿里云通义千问、月之暗面 Kimi、智谱 GLM、本地 Ollama 等）。本应用不关联、不代理、不中转任何第三方 API 请求，用户与各服务商的关系由用户自行与服务商建立并遵守其各自的服务条款。'
      ]
    },
    {
      title: '四、开源字体许可',
      paragraphs: [
        '本应用内置以下开源字体，均遵循 SIL Open Font License 1.1（OFL 1.1）或 Apache License 2.0，可免费商用。各字体的原始 OFL 许可文本与版权声明已随应用打包（rawfile/fonts 目录）。',
        '',
        'HarmonyOS Sans：系统内置字体，随 HarmonyOS 系统免费授权使用，版权归华为技术有限公司所有。',
        'Inter：SIL OFL 1.1，可免费商用，版权归 The Inter Project Authors（https://github.com/rsms/inter）。',
        'JetBrains Mono：SIL OFL 1.1，可免费商用，版权归 The JetBrains Mono Project Authors（https://github.com/JetBrains/JetBrainsMono）。',
        'Fira Code：SIL OFL 1.1，可免费商用，版权归 The Fira Code Project Authors（https://github.com/tonsky/FiraCode）。',
        'Lobster：SIL OFL 1.1，艺术展示体，版权归 The Lobster Project Authors（https://github.com/impallari/Lobster）。',
        'Pacifico：SIL OFL 1.1，手写波浪体，版权归 The Pacifico Project Authors（https://github.com/googlefonts/Pacifico）。',
        'Bebas Neue：SIL OFL 1.1，紧凑标题体，版权归 The Bebas Neue Project Authors（https://github.com/dharmatype/Bebas-Neue）。',
        'Righteous：SIL OFL 1.1，圆润展示体，版权归 The Righteous Project Authors（https://github.com/googlefonts/Righteous）。',
        'Press Start 2P：SIL OFL 1.1，像素风游戏字体，版权归 The Press Start 2P Project Authors（https://github.com/googlefonts/PressStart2P）。',
        'Orbitron：SIL OFL 1.1，科技感几何体，版权归 The Orbitron Project Authors（https://github.com/theleagueof/Orbitron）。',
        'Dancing Script：SIL OFL 1.1，优雅手写斜体，版权归 The Dancing Script Project Authors（https://github.com/googlefonts/DancingScript）。',
        '站酷快乐体（ZCOOL KuaiLe）：SIL OFL 1.1，中文艺术字体，含常用中文字形，版权归 The ZCOOL KuaiLe Project Authors（https://github.com/googlefonts/zcool-kuaile）。'
      ]
    },
    {
      title: '五、其他声明',
      paragraphs: [
        '本应用内置的游戏图标（app_icon.jpg 及 app_icon_*.jpg）与界面设计素材，版权归开发者所有。这些视觉资产不属于 MIT 许可范围，未经开发者书面许可，不得擅自用于其他产品或服务。',
        '本应用使用的游戏概念（俄罗斯方块、2048、贪吃蛇、扫雷、打砖块）均为广泛流传的经典游戏玩法，其具体实现代码为原创开发，版权归开发者所有。',
        '如您对本应用的开源许可有任何疑问，可通过以下方式联系：',
        'GitHub 仓库：https://github.com/jiayaoting/zhizon（提交 Issue）',
        '应用内反馈：通过"更多"菜单中的"反馈"入口提交'
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

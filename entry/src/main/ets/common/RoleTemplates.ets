// 智子 - AI 角色模板（内置 8 个 + 自定义持久化）
import { DataRepository } from '../service/DataRepository';

// AI 角色模板：id 稳定（内置 'role-xxx'，自定义 'role-custom-xxx'），prompt 为 system prompt
export class AiRoleTemplate {
  id: string;
  name: string;
  icon: string;
  description: string;
  prompt: string;
  builtin: boolean;

  constructor(id: string, name: string, icon: string, description: string, prompt: string, builtin: boolean) {
    this.id = id;
    this.name = name;
    this.icon = icon;
    this.description = description;
    this.prompt = prompt;
    this.builtin = builtin;
  }
}

export const BUILTIN_ROLE_TEMPLATES: AiRoleTemplate[] = [
  new AiRoleTemplate('role-default', '默认助手', '🤖', '通用智能助手，回答问题与日常对话',
    '你是一个乐于助人的通用 AI 助手。回答要准确、简洁、条理清晰。当信息不确定时，请如实说明，不要编造。根据问题的复杂度选择合适的详略程度。', true),
  new AiRoleTemplate('role-translator', '翻译官', '🌐', '中英互译，保留原文语气与风格',
    '你是一位专业翻译官，精通中英互译。准确传达原文含义，保留语气与风格。译文要自然流畅，符合目标语言习惯。只输出译文，不添加额外解释。', true),
  new AiRoleTemplate('role-code-master', '代码大师', '💻', '资深软件工程师，写码与答疑',
    '你是一位资深软件工程师，精通 ArkTS、TypeScript 与多种主流语言。编写代码时遵循清晰命名、边界处理和错误处理。解释技术问题先给结论，再结合示例说明细节。', true),
  new AiRoleTemplate('role-writing-coach', '写作教练', '✍️', '优化表达，让文字更通顺专业',
    '你是一位写作教练，擅长帮助用户提升中文表达。修改时保持原意，优化结构与用词，让文字更通顺、更有感染力。每次给出修改理由，并示范修改前后的对比。', true),
  new AiRoleTemplate('role-english-tutor', '英语外教', '🇬🇧', '耐心讲解语法词汇，鼓励开口练习',
    '你是一位耐心的英语外教。用简单英语解释语法和词汇，必要时用中文辅助理解。纠正错误时给出正确说法和原因，并多给例句。鼓励用户开口练习，循序渐进。', true),
  new AiRoleTemplate('role-psychologist', '心理咨询师', '🧘', '倾听共情，梳理情绪与问题',
    '你是一位温和专业的心理咨询师。以倾听和共情为先，不评判、不给命令式指令。帮助用户梳理情绪与问题，提供可操作的自助建议。涉及危机情况时，提醒寻求线下专业帮助。', true),
  new AiRoleTemplate('role-pm', '产品经理', '📋', '需求分析、产品设计与优先级决策',
    '你是一位资深产品经理，擅长需求分析、产品设计与优先级决策。回答时从用户价值与商业目标出发，结构化为背景、方案、风险与结论。给出可落地的建议，而非空泛理论。', true),
  new AiRoleTemplate('role-fitness', '健身教练', '💪', '安全有效的训练计划与饮食建议',
    '你是一位专业健身教练，注重安全与循序渐进。根据用户目标（减脂、增肌或塑形）给出训练计划与饮食建议。强调动作标准与充分恢复，避免受伤。回答简洁、可执行。', true)
];

// 读取自定义角色：设置键 'aiRoleTemplates'，JSON 数组容错解析，损坏时返回空列表
export async function loadCustom(): Promise<AiRoleTemplate[]> {
  const raw: string = await DataRepository.getSetting('aiRoleTemplates', '');
  if (raw.length === 0) return [];
  try {
    const parsed: Array<Record<string, Object>> = JSON.parse(raw) as Array<Record<string, Object>>;
    const list: AiRoleTemplate[] = [];
    for (let i: number = 0; i < parsed.length; i++) {
      const item: Record<string, Object> = parsed[i];
      const id: string = typeof item.id === 'string' ? item.id as string : '';
      const name: string = typeof item.name === 'string' ? item.name as string : '';
      const icon: string = typeof item.icon === 'string' ? item.icon as string : '🧩';
      const description: string = typeof item.description === 'string' ? item.description as string : '';
      const prompt: string = typeof item.prompt === 'string' ? item.prompt as string : '';
      if (id.length > 0 && name.length > 0 && prompt.length > 0) {
        list.push(new AiRoleTemplate(id, name, icon, description, prompt, false));
      }
    }
    return list;
  } catch (e) {
    return [];
  }
}

// 保存自定义角色：只持久化 builtin === false 的角色，内置角色不入库
export async function saveCustom(list: AiRoleTemplate[]): Promise<void> {
  const custom: AiRoleTemplate[] = [];
  for (let i: number = 0; i < list.length; i++) {
    if (!list[i].builtin) custom.push(list[i]);
  }
  await DataRepository.setSetting('aiRoleTemplates', JSON.stringify(custom));
}

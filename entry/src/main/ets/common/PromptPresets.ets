// 智子 - 提示词预设（斜杠命令快捷指令）
export class PromptPreset {
  id: string;
  command: string;    // 斜杠命令关键字（不含 /）
  name: string;       // 展示名
  icon: string;
  description: string;
  // 提示词模板：{text} 会被替换为命令后的内容
  prompt: string;

  constructor(id: string, command: string, name: string, icon: string, description: string,
    prompt: string) {
    this.id = id;
    this.command = command;
    this.name = name;
    this.icon = icon;
    this.description = description;
    this.prompt = prompt;
  }
}

export const PROMPT_PRESETS: PromptPreset[] = [
  new PromptPreset('translate', 'translate', '翻译', '🌐',
    '翻译文本（中文↔英文）', '请将以下内容翻译成中文；若原文为中文则翻译成英文，只输出译文：\n{text}'),
  new PromptPreset('summarize', 'summarize', '总结', '📝',
    '提炼要点，简洁总结', '请用简洁的语言总结以下内容的要点，分条列出：\n{text}'),
  new PromptPreset('code', 'code', '代码', '💻',
    '生成 / 解释代码', '请根据以下需求生成完整可运行的代码，并附简要说明：\n{text}'),
  new PromptPreset('polish', 'polish', '润色', '✨',
    '让文字更通顺专业', '请润色以下文字，使其表达更通顺、专业、简洁，保持原意：\n{text}'),
  new PromptPreset('explain', 'explain', '解释', '💡',
    '通俗解释概念', '请用通俗易懂的语言解释以下概念，可配例子：\n{text}'),
  new PromptPreset('write', 'write', '写作', '✍️',
    '按主题创作文字', '请围绕以下主题写一段文字（正文即可，无需标题）：\n{text}'),
  new PromptPreset('role', 'role', '角色', '🎭',
    '让 AI 扮演角色', '请扮演以下角色，并以该角色身份与我对话：\n{text}'),
  new PromptPreset('plan', 'plan', '规划', '🗺️',
    '制定步骤计划', '请为以下目标制定一份清晰的实施计划，分步骤列出并标注优先级：\n{text}')
];

// 输入以 / 开头时，返回匹配的预设（按命令关键字前缀过滤；无关键字返回全部）
export function presetMatches(input: string): PromptPreset[] {
  const rest: string = input.substring(1).trim();
  let keyword: string = rest;
  const spaceIdx: number = rest.indexOf(' ');
  if (spaceIdx >= 0) keyword = rest.substring(0, spaceIdx);
  const kw: string = keyword.toLowerCase();
  const result: PromptPreset[] = [];
  if (kw.length === 0) {
    for (let i: number = 0; i < PROMPT_PRESETS.length; i++) result.push(PROMPT_PRESETS[i]);
    return result;
  }
  for (let i: number = 0; i < PROMPT_PRESETS.length; i++) {
    if (PROMPT_PRESETS[i].command.toLowerCase().startsWith(kw)) result.push(PROMPT_PRESETS[i]);
  }
  return result;
}

// 应用预设：命令后的内容替换 {text}；无内容时保留占位提示
export function applyPreset(preset: PromptPreset, input: string): string {
  const rest: string = input.substring(1).trim();
  const spaceIdx: number = rest.indexOf(' ');
  const tail: string = spaceIdx >= 0 ? rest.substring(spaceIdx + 1).trim() : '';
  return preset.prompt.replace('{text}', tail);
}

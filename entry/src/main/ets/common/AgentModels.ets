// 智子 - Agent 化数据模型（工具定义 / 工具调用 / 工具结果 / 执行步骤）
import { LlmTokenUsage } from './LlmModels';

export type ToolLevel = 'SAFE' | 'CONFIRM' | 'DENIED';

export class ToolDefinition {
  name: string;
  description: string;
  parametersJson: string;
  level: ToolLevel;

  constructor(name: string, description: string, parametersJson: string, level: ToolLevel) {
    this.name = name;
    this.description = description;
    this.parametersJson = parametersJson;
    this.level = level;
  }
}

export class ToolCall {
  id: string;
  name: string;
  argumentsJson: string;

  constructor(id: string, name: string, argumentsJson: string) {
    this.id = id;
    this.name = name;
    this.argumentsJson = argumentsJson;
  }
}

export class ToolResult {
  callId: string;
  ok: boolean;
  content: string;
  error: string;

  constructor(callId: string, ok: boolean, content: string, error: string) {
    this.callId = callId;
    this.ok = ok;
    this.content = content;
    this.error = error;
  }
}

export class AgentStep {
  stepIndex: number;
  status: string; // running / done / failed
  toolName: string;
  args: string;
  result: string;
  startedAt: number;
  endedAt: number;

  constructor(stepIndex: number, status: string, toolName: string, args: string, result: string,
    startedAt: number, endedAt: number) {
    this.stepIndex = stepIndex;
    this.status = status;
    this.toolName = toolName;
    this.args = args;
    this.result = result;
    this.startedAt = startedAt;
    this.endedAt = endedAt;
  }
}

export class LlmAgentResult {
  success: boolean;
  content: string;
  reasoning: string;
  toolCalls: ToolCall[];
  errorCode: string;
  errorMessage: string;
  tokenUsage: LlmTokenUsage;

  constructor(success: boolean, content: string, reasoning: string, toolCalls: ToolCall[],
    errorCode: string, errorMessage: string, tokenUsage: LlmTokenUsage) {
    this.success = success;
    this.content = content;
    this.reasoning = reasoning;
    this.toolCalls = toolCalls;
    this.errorCode = errorCode;
    this.errorMessage = errorMessage;
    this.tokenUsage = tokenUsage;
  }
}

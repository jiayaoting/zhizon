// 智子 - Agent 编排器（P0：非流式工具闭环，最大步数 + 取消 + 步骤回调）
import { LlmClient } from './LlmClient';
import { LlmConfig, ChatMessage, LlmTokenUsage } from '../common/LlmModels';
import { ToolRegistry } from './ToolRegistry';
import { AgentStep, ToolCall, ToolResult, LlmAgentResult } from '../common/AgentModels';

const AGENT_INSTRUCTION = '你可以调用工具完成任务。工具结果会以 [工具结果:工具名] 的形式作为下一条用户消息返回给你，请基于结果继续，最终给出简洁答案；不要重复调用已成功执行且参数相同的工具。';

export class AgentOrchestrator {
  // 运行一次 Agent 循环；onStep 用于 UI 展示步骤，shouldStop 用于用户取消
  static async run(config: LlmConfig, messages: ChatMessage[], maxSteps: number,
    onStep: (step: AgentStep) => void, shouldStop: () => boolean): Promise<LlmAgentResult> {
    const working: ChatMessage[] = [];
    for (let i: number = 0; i < messages.length; i++) {
      working.push(messages[i]);
    }
    let lastUsage: LlmTokenUsage = new LlmTokenUsage();
    const tools = ToolRegistry.listTools();
    for (let step: number = 0; step < maxSteps; step++) {
      if (shouldStop()) {
        return new LlmAgentResult(false, '', '', [], 'CANCELLED', '已停止', lastUsage);
      }
      const startedAt: number = Date.now();
      const result: LlmAgentResult = await LlmClient.postCompletionAgent(config, working, tools,
        AGENT_INSTRUCTION);
      lastUsage = result.tokenUsage;
      if (!result.success) {
        onStep(new AgentStep(step, 'failed', '', '', result.errorMessage, startedAt, Date.now()));
        return result;
      }
      if (result.toolCalls.length === 0) {
        return result;
      }
      for (let j: number = 0; j < result.toolCalls.length; j++) {
        const call: ToolCall = result.toolCalls[j];
        const toolResult: ToolResult = await ToolRegistry.execute(call.name, call.argumentsJson);
        const status: string = toolResult.ok ? 'done' : 'failed';
        const resultText: string = toolResult.ok ? toolResult.content : toolResult.error;
        onStep(new AgentStep(step, status, call.name, call.argumentsJson, resultText, startedAt, Date.now()));
        working.push(ChatMessage.create('user', '[工具结果:' + call.name + '] ' + resultText));
      }
    }
    return new LlmAgentResult(false, '', '', [], 'MAX_STEPS', '已达到最大执行步数，请重新提问', lastUsage);
  }
}

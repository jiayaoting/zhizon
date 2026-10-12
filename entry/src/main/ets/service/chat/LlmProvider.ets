// 智子 - 大模型客户端接缝（v10 §5.3 可注入单例）
// 目的：把「LLM 网络调用」从各业务调用点解耦，单测可注入 Fake 实现，
//      不依赖网络与服务端；生产路径默认使用 LlmClient（行为完全不变）。
import { ChatMessage, LlmConfig, LlmResult } from '../../common/LlmModels';
import { ToolDefinition, LlmAgentResult } from '../../common/AgentModels';
import { AiCallContext } from '../platform/AiCallLogger';
import { CancelableLlmRequest, LlmClient } from './LlmClient';

// 大模型客户端契约（签名与 LlmClient 的 5 个公开静态方法一一对应）
export interface ILlmClient {
  testConnection(config: LlmConfig): Promise<LlmResult>;
  postCompletion(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): Promise<LlmResult>;
  postCompletionAgent(config: LlmConfig, messages: ChatMessage[], tools: ToolDefinition[],
    systemExtra: string): Promise<LlmAgentResult>;
  postCompletionCancelable(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): CancelableLlmRequest;
  postCompletionStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void,
    context?: AiCallContext): Promise<LlmResult>;
}

// 默认实现：委托给 LlmClient（静态方法，行为零变化）
export class LlmClientProvider implements ILlmClient {
  testConnection(config: LlmConfig): Promise<LlmResult> {
    return LlmClient.testConnection(config);
  }

  postCompletion(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): Promise<LlmResult> {
    return LlmClient.postCompletion(config, messages, context);
  }

  postCompletionAgent(config: LlmConfig, messages: ChatMessage[], tools: ToolDefinition[],
    systemExtra: string): Promise<LlmAgentResult> {
    return LlmClient.postCompletionAgent(config, messages, tools, systemExtra);
  }

  postCompletionCancelable(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): CancelableLlmRequest {
    return LlmClient.postCompletionCancelable(config, messages, context);
  }

  postCompletionStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void,
    context?: AiCallContext): Promise<LlmResult> {
    return LlmClient.postCompletionStream(config, messages, onDelta, onReasoning, context);
  }
}

// 注册表：默认返回真实实现；测试可 inject(Fake) / reset()
export class LlmProviders {
  private static override: ILlmClient | null = null;
  private static fallback: ILlmClient = new LlmClientProvider();

  static inject(provider: ILlmClient): void {
    LlmProviders.override = provider;
  }

  static reset(): void {
    LlmProviders.override = null;
  }

  static get(): ILlmClient {
    return LlmProviders.override === null ? LlmProviders.fallback : LlmProviders.override;
  }

  // 是否处于测试注入态（供断言）
  static isInjected(): boolean {
    return LlmProviders.override !== null;
  }
}

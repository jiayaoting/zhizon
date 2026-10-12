import { describe, it, expect } from '@ohos/hypium';
import { ILlmClient, LlmProviders } from '../main/ets/service/chat/LlmProvider';
import { CancelableLlmRequest } from '../main/ets/service/chat/LlmClient';
import { ChatMessage, LlmConfig, LlmResult, LlmTokenUsage } from '../main/ets/common/LlmModels';
import { ToolDefinition, LlmAgentResult } from '../main/ets/common/AgentModels';
import { AiCallContext } from '../main/ets/service/platform/AiCallLogger';

// 假客户端：验证「可注入单例」接缝（无需网络/服务端）
class FakeLlmClient implements ILlmClient {
  streamCallCount: number = 0;

  testConnection(config: LlmConfig): Promise<LlmResult> {
    return Promise.resolve(new LlmResult(true, 'fake-test'));
  }

  postCompletion(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): Promise<LlmResult> {
    return Promise.resolve(new LlmResult(true, 'fake-completion'));
  }

  postCompletionAgent(config: LlmConfig, messages: ChatMessage[], tools: ToolDefinition[],
    systemExtra: string): Promise<LlmAgentResult> {
    return Promise.resolve(new LlmAgentResult(true, 'fake-agent', '', [], '', '', new LlmTokenUsage()));
  }

  postCompletionCancelable(config: LlmConfig, messages: ChatMessage[],
    context?: AiCallContext): CancelableLlmRequest {
    return new CancelableLlmRequest(Promise.resolve(new LlmResult(true, 'fake-cancelable')),
      (): void => {});
  }

  postCompletionStream(config: LlmConfig, messages: ChatMessage[],
    onDelta: (delta: string) => void, onReasoning?: (reasoning: string) => void,
    context?: AiCallContext): Promise<LlmResult> {
    this.streamCallCount++;
    onDelta('fake');
    return Promise.resolve(new LlmResult(true, 'fake-stream'));
  }
}

export default function LlmProviderTest() {
  describe('LlmProviderTest', () => {
    it('defaults to the real LlmClient-backed provider', 0, () => {
      LlmProviders.reset();
      expect(LlmProviders.isInjected()).assertFalse();
      expect(LlmProviders.get() !== null).assertTrue();
    });

    it('inject/reset swaps the singleton used by callers', 0, () => {
      const fake: FakeLlmClient = new FakeLlmClient();
      LlmProviders.inject(fake);
      expect(LlmProviders.isInjected()).assertTrue();
      expect(LlmProviders.get() === fake).assertTrue();
      LlmProviders.reset();
      expect(LlmProviders.isInjected()).assertFalse();
      expect(LlmProviders.get() === fake).assertFalse();
    });

    it('calls through the registry reach the injected fake (completion)', 0, async () => {
      const fake: FakeLlmClient = new FakeLlmClient();
      LlmProviders.inject(fake);
      const config: LlmConfig = new LlmConfig();
      const messages: ChatMessage[] = [ChatMessage.create('user', '你好')];
      const res: LlmResult = await LlmProviders.get().postCompletion(config, messages);
      expect(res.success).assertTrue();
      expect(res.content).assertEqual('fake-completion');
      LlmProviders.reset();
    });

    it('a second call path (stream) also reaches the injected fake', 0, async () => {
      const fake: FakeLlmClient = new FakeLlmClient();
      LlmProviders.inject(fake);
      const config: LlmConfig = new LlmConfig();
      const messages: ChatMessage[] = [ChatMessage.create('user', '你好')];
      let deltas: string = '';
      const res: LlmResult = await LlmProviders.get().postCompletionStream(config, messages,
        (delta: string) => {
          deltas = deltas + delta;
        });
      expect(res.content).assertEqual('fake-stream');
      expect(deltas).assertEqual('fake');
      expect(fake.streamCallCount).assertEqual(1);
      LlmProviders.reset();
    });
  });
}

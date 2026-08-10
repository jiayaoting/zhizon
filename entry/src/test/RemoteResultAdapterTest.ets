import { describe, it, expect } from '@ohos/hypium';
import { RemoteFailureCategory, RemoteResult } from '../main/ets/model/GovernanceModels';
import { RemoteResultAdapter } from '../main/ets/service/RemoteResultAdapter';

export default function RemoteResultAdapterTest() {
  describe('RemoteResultAdapterTest', () => {
    it('represents successful empty list separately from failure', 0, () => {
      const empty = RemoteResultAdapter.success<string[]>([]);
      const failed = RemoteResultAdapter.fromHttpStatus<string[]>(503);
      expect(empty.success).assertTrue();
      expect(empty.value === null ? -1 : empty.value.length).assertEqual(0);
      expect(failed.success).assertFalse();
      expect(failed.value).assertEqual(null);
      expect(failed.failure === null ? '' : failed.failure.category).assertEqual(RemoteFailureCategory.HTTP);
    });

    it('maps authentication, timeout and protocol failures without raw exception text', 0, () => {
      const auth = RemoteResultAdapter.fromHttpStatus<boolean>(401);
      const timeout = RemoteResultAdapter.fromException<boolean>(new Error('request timeout password=secret'));
      const protocol = RemoteResultAdapter.protocolFailure<boolean>();
      expect(auth.failure === null ? '' : auth.failure.category).assertEqual(RemoteFailureCategory.AUTHENTICATION);
      expect(auth.failure === null ? true : auth.failure.retryable).assertFalse();
      expect(timeout.failure === null ? '' : timeout.failure.category).assertEqual(RemoteFailureCategory.TIMEOUT);
      expect(RemoteResultAdapter.publicMessage(timeout).indexOf('password=secret')).assertEqual(-1);
      expect(protocol.failure === null ? '' : protocol.failure.category).assertEqual(RemoteFailureCategory.PROTOCOL);
    });

    it('marks gateway timeout as retryable without exposing response content', 0, () => {
      const failed: RemoteResult<string[]> = RemoteResultAdapter.fromHttpStatus<string[]>(504);
      expect(failed.success).assertFalse();
      expect(failed.value).assertEqual(null);
      expect(failed.failure === null ? false : failed.failure.retryable).assertTrue();
      expect(RemoteResultAdapter.publicMessage(failed)).assertEqual('远程服务返回异常状态，请稍后重试');
    });
  });
}

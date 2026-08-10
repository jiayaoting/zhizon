import { describe, it, expect } from '@ohos/hypium';
import { RemoteFailureCategory } from '../main/ets/model/GovernanceModels';
import { RemoteOperation } from '../main/ets/service/RemoteOperation';

export default function RemoteOperationTest() {
  describe('RemoteOperationTest', () => {
    it('accepts valid host port path and timeout values', 0, () => {
      const result = new RemoteOperation('pve', '192.0.2.1', 8006, '/nodes', 15000, 15000).validate();
      expect(result.success).assertTrue();
      expect(result.value === null ? '' : result.value.path).assertEqual('/nodes');
    });

    it('rejects invalid identity and numeric boundaries', 0, () => {
      const invalidIdentity = new RemoteOperation('', '', 8006, 'nodes', 15000, 15000).validate();
      const invalidNumbers = new RemoteOperation('pve', 'host', 65536, '/nodes', 0, -1).validate();
      expect(invalidIdentity.success).assertFalse();
      expect(invalidNumbers.success).assertFalse();
      expect(invalidNumbers.failure === null ? '' : invalidNumbers.failure.category)
        .assertEqual(RemoteFailureCategory.VALIDATION);
    });
  });
}

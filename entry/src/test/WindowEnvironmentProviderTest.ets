import { describe, it, expect } from '@ohos/hypium';
import { WindowEnvironmentConfidence, WindowEnvironmentProvider } from '../main/ets/service/WindowEnvironmentProvider';

export default function WindowEnvironmentProviderTest() {
  describe('WindowEnvironmentProviderTest', () => {
    it('supports idempotent detach before attach', 0, () => {
      const provider = new WindowEnvironmentProvider();
      provider.detach();
      provider.detach();
      expect(provider.isAttached()).assertFalse();
      expect(provider.snapshot().confidence).assertEqual(WindowEnvironmentConfidence.FALLBACK);
    });
  });
}

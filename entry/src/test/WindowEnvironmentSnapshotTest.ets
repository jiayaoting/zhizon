import { describe, it, expect } from '@ohos/hypium';
import { WindowDeviceType, WindowEnvironmentConfidence, WindowEnvironmentSnapshot, WindowFoldState,
  WindowOrientation } from '../main/ets/service/WindowEnvironmentProvider';

export default function WindowEnvironmentSnapshotTest() {
  describe('WindowEnvironmentSnapshotTest', () => {
    it('preserves supplied environment values and unknown fold state', 0, () => {
      const snapshot = new WindowEnvironmentSnapshot(WindowDeviceType.TABLET, 800, 1200,
        WindowOrientation.PORTRAIT, 2, 44, 24, WindowEnvironmentConfidence.EXACT);
      expect(snapshot.deviceType).assertEqual(WindowDeviceType.TABLET);
      expect(snapshot.width).assertEqual(800);
      expect(snapshot.height).assertEqual(1200);
      expect(snapshot.orientation).assertEqual(WindowOrientation.PORTRAIT);
      expect(snapshot.foldState).assertEqual(WindowFoldState.UNKNOWN);
      expect(snapshot.confidence).assertEqual(WindowEnvironmentConfidence.EXACT);
    });
  });
}

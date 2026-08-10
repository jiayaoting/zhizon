import { describe, it, expect } from '@ohos/hypium';
import { MainNavKey, NavigationFacade, NavigationFailure, NavigationFailureReason, NavigationSource,
  NavigationState, NavigationSuccess, PageKey } from '../main/ets/common/Navigation';

export default function NavigationFacadeTest() {
  describe('NavigationFacadeTest', () => {
    it('atomically updates page and selected main navigation', 0, () => {
      const previous = new NavigationState(PageKey.Index, MainNavKey.Index);
      const result = NavigationFacade.navigate(previous, PageKey.Servers, NavigationSource.MAIN_NAV);
      expect(result.success).assertTrue();
      if (result.success) {
        const success: NavigationSuccess = result as NavigationSuccess;
        expect(success.nextSnapshot.currentPage).assertEqual(PageKey.Servers);
        expect(success.nextSnapshot.selectedMain).assertEqual(MainNavKey.Servers);
      }
    });

    it('preserves previous snapshot for unavailable target', 0, () => {
      const previous = new NavigationState(PageKey.Pve, MainNavKey.Pve);
      const result = NavigationFacade.navigate(previous, PageKey.ServerDetail, NavigationSource.MAIN_NAV);
      expect(result.success).assertFalse();
      if (!result.success) {
        const failure: NavigationFailure = result as NavigationFailure;
        expect(failure.reason).assertEqual(NavigationFailureReason.PAGE_UNAVAILABLE);
        expect(failure.previousSnapshot.currentPage).assertEqual(PageKey.Pve);
        expect(failure.previousSnapshot.selectedMain).assertEqual(MainNavKey.Pve);
      }
    });

    it('rejects empty detail route parameters', 0, () => {
      const result = NavigationFacade.vmDetailParameters(null);
      expect(result.valid).assertFalse();
      expect(result.value).assertEqual(null);
    });

  });
}

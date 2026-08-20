import { describe, it, expect } from '@ohos/hypium';
import { NewsRepository } from '../main/ets/service/NewsRepository';

export default function NewsRepositoryTest() {
  describe('NewsRepositoryTest', () => {
    it('todayKey follows yyyyMMdd format', 0, () => {
      const key: string = NewsRepository.todayKey();
      expect(key.length).assertEqual(8);
      const year: string = key.substring(0, 4);
      const month: string = key.substring(4, 6);
      const day: string = key.substring(6, 8);
      expect(Number(year)).assertGreaterThan(2020);
      expect(Number(month)).assertLessThan(13);
      expect(Number(day)).assertLessThan(32);
    });

    it('todayLabel contains month and day', 0, () => {
      const label: string = NewsRepository.todayLabel();
      expect(label.indexOf('月')).assertGreaterThan(-1);
      expect(label.indexOf('日')).assertGreaterThan(-1);
    });

    it('digestId distinguishes digest and hotspot modes', 0, () => {
      const key: string = NewsRepository.todayKey();
      expect(NewsRepository.digestId('digest')).assertEqual('digest-' + key);
      expect(NewsRepository.digestId('hotspot')).assertEqual('digest-' + key + '-hotspot');
    });
  });
}

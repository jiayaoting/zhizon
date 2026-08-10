import { describe, it, expect } from '@ohos/hypium';
import { AffectedFeature, DefectInput, DefectStatus, EvidenceConclusion,
  EvidenceType, FixEvidence } from '../main/ets/model/GovernanceModels';
import { DefectWorkflow } from '../main/ets/service/DefectWorkflow';

export default function DefectWorkflowTest() {
  describe('DefectWorkflowTest', () => {
    it('sanitizes sensitive values before persistence workflow', 0, () => {
      const input = new DefectInput('token=secret', 'password:abc', ['C:\\private\\log.txt'], ['open'],
        'ok', 'privateKey:xyz', 'phone', 'token:raw', [AffectedFeature.DATA_SECURITY]);
      const sanitized: DefectInput = DefectWorkflow.sanitize(input);
      expect(sanitized.title).assertEqual('token:[REDACTED]');
      expect(sanitized.symptom).assertEqual('password:[REDACTED]');
      expect(sanitized.actualBehavior).assertEqual('privateKey:[REDACTED]');
      expect(sanitized.preconditions[0]).assertEqual('[REDACTED_PATH]');
    });

    it('requires device or user confirmation evidence for confirmed state', 0, () => {
      const staticEvidence = new FixEvidence('e1', EvidenceType.STATIC, EvidenceConclusion.PASSED,
        'static review', ['source review'], Date.now(), 'tester');
      const deviceEvidence = new FixEvidence('e2', EvidenceType.DEVICE, EvidenceConclusion.PASSED,
        'user device', ['phone'], Date.now(), 'tester');
      expect(staticEvidence.type).assertEqual(EvidenceType.STATIC);
      expect(deviceEvidence.type).assertEqual(EvidenceType.DEVICE);
      expect(DefectWorkflow.canConfirm(staticEvidence)).assertFalse();
      expect(DefectWorkflow.canConfirm(deviceEvidence)).assertTrue();
    });

    it('rejects static and failed device evidence for confirmed state', 0, () => {
      const failedDeviceEvidence = new FixEvidence('e3', EvidenceType.DEVICE, EvidenceConclusion.FAILED,
        'device run', ['phone'], Date.now(), 'tester');
      expect(DefectWorkflow.canConfirm(null)).assertFalse();
      expect(DefectWorkflow.canConfirm(failedDeviceEvidence)).assertFalse();
      expect(DefectStatus.NOT_REPRODUCED === DefectStatus.CONFIRMED).assertFalse();
    });
  });
}

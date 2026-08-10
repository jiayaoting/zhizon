import { AffectedFeature, DefectInput, DefectSeverity } from '../model/GovernanceModels';

export class DefectClassification { severity: DefectSeverity; priority: number; constructor(severity: DefectSeverity, priority: number) { this.severity = severity; this.priority = priority; } }

export class DefectClassifier {
  static classify(input: DefectInput): DefectClassification {
    if (DefectClassifier.has(input.affectedFeatures, AffectedFeature.STARTUP) || DefectClassifier.has(input.affectedFeatures, AffectedFeature.DATA_SECURITY)) return new DefectClassification(DefectSeverity.BLOCKING, 1);
    if (DefectClassifier.has(input.affectedFeatures, AffectedFeature.REMOTE) || DefectClassifier.has(input.affectedFeatures, AffectedFeature.NAVIGATION)) return new DefectClassification(DefectSeverity.CRITICAL, 2);
    if (DefectClassifier.has(input.affectedFeatures, AffectedFeature.PAGE) || DefectClassifier.has(input.affectedFeatures, AffectedFeature.DATA)) return new DefectClassification(DefectSeverity.MAJOR, 3);
    return new DefectClassification(DefectSeverity.MINOR, 4);
  }
  private static has(features: AffectedFeature[], target: AffectedFeature): boolean { return features.indexOf(target) >= 0; }
}

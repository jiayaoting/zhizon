export enum AppErrorCategory {
  STARTUP = 'STARTUP',
  NAVIGATION = 'NAVIGATION',
  THEME = 'THEME',
  BACKGROUND = 'BACKGROUND',
  PERSISTENCE = 'PERSISTENCE',
  GAME_ARGUMENT = 'GAME_ARGUMENT',
  SAFE_AREA = 'SAFE_AREA',
  INPUT = 'INPUT'
}

export enum RecoveryAction {
  RETRY = 'RETRY',
  RETURN = 'RETURN',
  RECONFIGURE = 'RECONFIGURE',
  RESTORE_SNAPSHOT = 'RESTORE_SNAPSHOT'
}

export class AppFailure {
  category: AppErrorCategory;
  code: string;
  message: string;
  retryable: boolean;
  action: RecoveryAction;

  constructor(category: AppErrorCategory, code: string, message: string, retryable: boolean,
    action: RecoveryAction) {
    this.category = category;
    this.code = code;
    this.message = message;
    this.retryable = retryable;
    this.action = action;
  }
}

export class RecoverableResult<T> {
  success: boolean;
  value: T | null;
  failure: AppFailure | null;
  previousSnapshot: T | null;

  constructor(success: boolean, value: T | null, failure: AppFailure | null, previousSnapshot: T | null) {
    this.success = success;
    this.value = value;
    this.failure = failure;
    this.previousSnapshot = previousSnapshot;
  }
}

export enum DefectSeverity { BLOCKING = 'BLOCKING', CRITICAL = 'CRITICAL', MAJOR = 'MAJOR', MINOR = 'MINOR' }
export enum DefectStatus { ANALYZING = 'ANALYZING', NEEDS_INFO = 'NEEDS_INFO', TO_FIX = 'TO_FIX', TO_VERIFY = 'TO_VERIFY', CONFIRMED = 'CONFIRMED', NOT_REPRODUCED = 'NOT_REPRODUCED' }
export enum AffectedFeature { STARTUP = 'STARTUP', NAVIGATION = 'NAVIGATION', DATA_SECURITY = 'DATA_SECURITY', PAGE = 'PAGE', THEME = 'THEME', BACKGROUND = 'BACKGROUND', DATA = 'DATA', GAME = 'GAME', SAFE_AREA = 'SAFE_AREA' }
export enum EvidenceType { STATIC = 'STATIC', CODE = 'CODE', DEVICE = 'DEVICE', USER_CONFIRMATION = 'USER_CONFIRMATION' }
export enum EvidenceConclusion { PASSED = 'PASSED', FAILED = 'FAILED', PENDING = 'PENDING' }

export class FixEvidence {
  id: string; type: EvidenceType; conclusion: EvidenceConclusion; source: string; conditions: string[]; recordedAt: number; operator: string;
  constructor(id: string, type: EvidenceType, conclusion: EvidenceConclusion, source: string, conditions: string[], recordedAt: number, operator: string) {
    this.id = id; this.type = type; this.conclusion = conclusion; this.source = source; this.conditions = conditions; this.recordedAt = recordedAt; this.operator = operator;
  }
}

export class FixResult {
  scope: AffectedFeature[]; expectedBehavior: string; failureBehavior: string; validationConditions: string[]; residualRisks: string[];
  constructor(scope: AffectedFeature[], expectedBehavior: string, failureBehavior: string, validationConditions: string[], residualRisks: string[]) {
    this.scope = scope; this.expectedBehavior = expectedBehavior; this.failureBehavior = failureBehavior; this.validationConditions = validationConditions; this.residualRisks = residualRisks;
  }
}

export class DefectInput {
  title: string; symptom: string; preconditions: string[]; steps: string[]; expectedBehavior: string; actualBehavior: string; deviceInfo: string; source: string; affectedFeatures: AffectedFeature[];
  constructor(title: string, symptom: string, preconditions: string[], steps: string[], expectedBehavior: string, actualBehavior: string, deviceInfo: string, source: string, affectedFeatures: AffectedFeature[]) {
    this.title = title; this.symptom = symptom; this.preconditions = preconditions; this.steps = steps; this.expectedBehavior = expectedBehavior; this.actualBehavior = actualBehavior; this.deviceInfo = deviceInfo; this.source = source; this.affectedFeatures = affectedFeatures;
  }
}

export class DefectRecord {
  defectKey: string; title: string; symptom: string; preconditions: string[]; steps: string[]; expectedBehavior: string; actualBehavior: string; deviceInfo: string; source: string; severity: DefectSeverity; status: DefectStatus; priority: number; affectedFeatures: AffectedFeature[]; evidence: FixEvidence[]; fixResult: FixResult | null; createdAt: number; updatedAt: number;
  constructor(key: string, input: DefectInput, severity: DefectSeverity, status: DefectStatus, priority: number, evidence: FixEvidence[], fixResult: FixResult | null, now: number) {
    this.defectKey = key; this.title = input.title; this.symptom = input.symptom; this.preconditions = input.preconditions; this.steps = input.steps; this.expectedBehavior = input.expectedBehavior; this.actualBehavior = input.actualBehavior; this.deviceInfo = input.deviceInfo; this.source = input.source; this.severity = severity; this.status = status; this.priority = priority; this.affectedFeatures = input.affectedFeatures; this.evidence = evidence; this.fixResult = fixResult; this.createdAt = now; this.updatedAt = now;
  }
}

export class DefectTransitionCommand { defectKey: string; target: DefectStatus; operator: string; trigger: string; evidence: FixEvidence | null; constructor(defectKey: string, target: DefectStatus, operator: string, trigger: string, evidence: FixEvidence | null) { this.defectKey = defectKey; this.target = target; this.operator = operator; this.trigger = trigger; this.evidence = evidence; } }
export class DefectStateHistory { id: string; defectKey: string; fromStatus: DefectStatus; toStatus: DefectStatus; operator: string; trigger: string; evidenceId: string; recordedAt: number; constructor(id: string, key: string, from: DefectStatus, to: DefectStatus, operator: string, trigger: string, evidenceId: string, time: number) { this.id = id; this.defectKey = key; this.fromStatus = from; this.toStatus = to; this.operator = operator; this.trigger = trigger; this.evidenceId = evidenceId; this.recordedAt = time; } }

export class ValidationResult { valid: boolean; code: string; message: string; constructor(valid: boolean, code: string, message: string) { this.valid = valid; this.code = code; this.message = message; } }
export class PreferenceSnapshot { followSystem: boolean; manualThemeMode: string; colorThemeId: string; fontSizeScale: string; backgroundUri: string; backgroundStrength: number; glassEffectEnabled: boolean; operationVersion: number; constructor(followSystem: boolean, manualThemeMode: string, colorThemeId: string, fontSizeScale: string, backgroundUri: string, backgroundStrength: number, glassEffectEnabled: boolean, operationVersion: number) { this.followSystem = followSystem; this.manualThemeMode = manualThemeMode; this.colorThemeId = colorThemeId; this.fontSizeScale = fontSizeScale; this.backgroundUri = backgroundUri; this.backgroundStrength = backgroundStrength; this.glassEffectEnabled = glassEffectEnabled; this.operationVersion = operationVersion; } }
export class PreferencePersistenceResult { success: boolean; code: string; snapshot: PreferenceSnapshot; rollbackSnapshot: PreferenceSnapshot; constructor(success: boolean, code: string, snapshot: PreferenceSnapshot, rollbackSnapshot: PreferenceSnapshot) { this.success = success; this.code = code; this.snapshot = snapshot; this.rollbackSnapshot = rollbackSnapshot; } }

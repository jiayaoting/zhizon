import { DefectInput, DefectRecord, DefectStateHistory, DefectStatus, DefectTransitionCommand, EvidenceConclusion, EvidenceType, FixEvidence, RecoverableResult } from '../model/GovernanceModels';
import { DefectClassifier } from './DefectClassifier';
import { DataRepository } from './DataRepository';

export class DefectWorkflow {
  static sanitize(input: DefectInput): DefectInput {
    return DefectWorkflow.sanitizeInput(input);
  }

  static canConfirm(evidence: FixEvidence | null): boolean {
    return evidence !== null && (evidence.type === EvidenceType.DEVICE ||
      evidence.type === EvidenceType.USER_CONFIRMATION) && evidence.conclusion === EvidenceConclusion.PASSED;
  }

  static async create(input: DefectInput): Promise<DefectRecord> {
    const safeInput: DefectInput = DefectWorkflow.sanitizeInput(input);
    const classification = DefectClassifier.classify(safeInput);
    const status: DefectStatus = DefectWorkflow.hasRequiredInput(safeInput) ? DefectStatus.ANALYZING : DefectStatus.NEEDS_INFO;
    const now: number = Date.now();
    const record = new DefectRecord(DataRepository.generateId('defect'), safeInput, classification.severity, status, classification.priority, [], null, now);
    const saved: RecoverableResult<DefectRecord> = await DataRepository.saveDefect(record);
    if (!saved.success) throw new Error('PERSISTENCE_FAILED');
    return record;
  }

  static async update(record: DefectRecord): Promise<DefectRecord> { const safe: DefectRecord = DefectWorkflow.sanitizeRecord(record); const saved: RecoverableResult<DefectRecord> = await DataRepository.updateDefect(safe); if (!saved.success) throw new Error('PERSISTENCE_FAILED'); return safe; }

  static async transition(command: DefectTransitionCommand): Promise<DefectRecord> {
    const current: DefectRecord | null = await DataRepository.getDefect(command.defectKey);
    if (current === null || !DefectWorkflow.allowed(current.status, command.target) || !DefectWorkflow.evidenceAllowed(command)) throw new Error('INVALID_TRANSITION');
    const candidate: DefectRecord = DefectWorkflow.copyRecord(current);
    const history = new DefectStateHistory(DataRepository.generateId('history'), current.defectKey, current.status, command.target, DefectWorkflow.clean(command.operator), DefectWorkflow.clean(command.trigger), command.evidence === null ? '' : command.evidence.id, Date.now());
    candidate.status = command.target; candidate.updatedAt = Date.now();
    if (command.evidence !== null) candidate.evidence.push(command.evidence);
    const saved: RecoverableResult<DefectRecord> = await DataRepository.transitionDefect(candidate, history, command.evidence); if (!saved.success) throw new Error('PERSISTENCE_FAILED');
    return candidate;
  }

  static async appendEvidence(defectKey: string, evidence: FixEvidence): Promise<DefectRecord> {
    const current: DefectRecord | null = await DataRepository.getDefect(defectKey);
    if (current === null) throw new Error('DEFECT_NOT_FOUND');
    const candidate: DefectRecord = DefectWorkflow.copyRecord(current);
    const safeConditions: string[] = DefectWorkflow.cleanValues(evidence.conditions);
    const safeEvidence = new FixEvidence(evidence.id, evidence.type, evidence.conclusion,
      DefectWorkflow.clean(evidence.source), safeConditions, evidence.recordedAt,
      DefectWorkflow.clean(evidence.operator));
    candidate.evidence.push(safeEvidence); candidate.updatedAt = Date.now(); const saved: RecoverableResult<DefectRecord> = await DataRepository.appendEvidence(candidate, safeEvidence); if (!saved.success) throw new Error('PERSISTENCE_FAILED'); return candidate;
  }

  private static hasRequiredInput(input: DefectInput): boolean { return input.symptom.length > 0 && input.actualBehavior.length > 0 && input.preconditions.length > 0 && input.steps.length > 0; }
  private static allowed(from: DefectStatus, to: DefectStatus): boolean { if (from === DefectStatus.ANALYZING) return to === DefectStatus.NEEDS_INFO || to === DefectStatus.TO_FIX || to === DefectStatus.NOT_REPRODUCED; if (from === DefectStatus.NEEDS_INFO) return to === DefectStatus.ANALYZING; if (from === DefectStatus.TO_FIX) return to === DefectStatus.TO_VERIFY || to === DefectStatus.NOT_REPRODUCED; if (from === DefectStatus.TO_VERIFY) return to === DefectStatus.CONFIRMED || to === DefectStatus.TO_FIX || to === DefectStatus.NOT_REPRODUCED; return false; }
  private static evidenceAllowed(command: DefectTransitionCommand): boolean { if (command.target !== DefectStatus.CONFIRMED) return true; return DefectWorkflow.canConfirm(command.evidence); }
  private static sanitizeInput(input: DefectInput): DefectInput { return new DefectInput(DefectWorkflow.clean(input.title), DefectWorkflow.clean(input.symptom), DefectWorkflow.cleanValues(input.preconditions), DefectWorkflow.cleanValues(input.steps), DefectWorkflow.clean(input.expectedBehavior), DefectWorkflow.clean(input.actualBehavior), DefectWorkflow.clean(input.deviceInfo), DefectWorkflow.clean(input.source), input.affectedFeatures.slice()); }
  private static sanitizeRecord(record: DefectRecord): DefectRecord { const safe: DefectRecord = DefectWorkflow.copyRecord(record); safe.title = DefectWorkflow.clean(record.title); safe.symptom = DefectWorkflow.clean(record.symptom); safe.actualBehavior = DefectWorkflow.clean(record.actualBehavior); return safe; }
  private static copyRecord(record: DefectRecord): DefectRecord {
    const input = new DefectInput(record.title, record.symptom, record.preconditions.slice(), record.steps.slice(),
      record.expectedBehavior, record.actualBehavior, record.deviceInfo, record.source, record.affectedFeatures.slice());
    const copy = new DefectRecord(record.defectKey, input, record.severity, record.status, record.priority,
      record.evidence.slice(), record.fixResult, record.createdAt);
    copy.updatedAt = record.updatedAt;
    return copy;
  }
  private static cleanValues(values: string[]): string[] {
    const cleaned: string[] = [];
    for (let index: number = 0; index < values.length; index++) {
      cleaned.push(DefectWorkflow.clean(values[index]));
    }
    return cleaned;
  }

  private static clean(value: string): string {
    let cleaned: string = value;
    cleaned = DefectWorkflow.redactAssignment(cleaned, 'password');
    cleaned = DefectWorkflow.redactAssignment(cleaned, 'token');
    cleaned = DefectWorkflow.redactAssignment(cleaned, 'privatekey');
    cleaned = DefectWorkflow.redactAssignment(cleaned, 'secret');
    return DefectWorkflow.redactWindowsPaths(cleaned);
  }

  private static redactAssignment(value: string, key: string): string {
    const lowerValue: string = value.toLowerCase();
    let result: string = '';
    let cursor: number = 0;
    while (cursor < value.length) {
      const keyStart: number = lowerValue.indexOf(key, cursor);
      if (keyStart < 0) {
        result += value.substring(cursor);
        break;
      }
      let separator: number = keyStart + key.length;
      while (separator < value.length && DefectWorkflow.isWhitespace(value.charAt(separator))) separator++;
      if (separator >= value.length || (value.charAt(separator) !== ':' && value.charAt(separator) !== '=')) {
        result += value.substring(cursor, keyStart + key.length);
        cursor = keyStart + key.length;
        continue;
      }
      let secretStart: number = separator + 1;
      while (secretStart < value.length && DefectWorkflow.isWhitespace(value.charAt(secretStart))) secretStart++;
      let secretEnd: number = secretStart;
      while (secretEnd < value.length && !DefectWorkflow.isSecretDelimiter(value.charAt(secretEnd))) secretEnd++;
      result += value.substring(cursor, separator) + ':[REDACTED]';
      cursor = secretEnd;
    }
    return result;
  }

  private static redactWindowsPaths(value: string): string {
    let result: string = '';
    let cursor: number = 0;
    while (cursor < value.length) {
      if (cursor + 2 < value.length && DefectWorkflow.isAsciiLetter(value.charAt(cursor)) &&
        value.charAt(cursor + 1) === ':' && value.charAt(cursor + 2) === '\\') {
        let pathEnd: number = cursor + 3;
        while (pathEnd < value.length && !DefectWorkflow.isWhitespace(value.charAt(pathEnd))) pathEnd++;
        result += '[REDACTED_PATH]';
        cursor = pathEnd;
      } else {
        result += value.charAt(cursor);
        cursor++;
      }
    }
    return result;
  }

  private static isWhitespace(value: string): boolean {
    return value === ' ' || value === '\t' || value === '\r' || value === '\n';
  }

  private static isSecretDelimiter(value: string): boolean {
    return DefectWorkflow.isWhitespace(value) || value === ',' || value === ';';
  }

  private static isAsciiLetter(value: string): boolean {
    const code: number = value.charCodeAt(0);
    return code >= 65 && code <= 90 || code >= 97 && code <= 122;
  }
}

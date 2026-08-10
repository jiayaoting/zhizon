import { AppErrorCategory, AppFailure, RecoveryAction } from '../model/GovernanceModels';

export class FailureMapping {
  code: string; impact: string; retryable: boolean; action: RecoveryAction; message: string;
  constructor(code: string, impact: string, retryable: boolean, action: RecoveryAction, message: string) { this.code = code; this.impact = impact; this.retryable = retryable; this.action = action; this.message = message; }
}

export class FailureMapper {
  static map(category: AppErrorCategory, code: string): AppFailure {
    const mapping: FailureMapping = FailureMapper.mapping(category, code);
    return new AppFailure(category, mapping.code, mapping.message, mapping.retryable, mapping.action);
  }
  private static mapping(category: AppErrorCategory, code: string): FailureMapping {
    switch (category) {
      case AppErrorCategory.REMOTE_AUTHENTICATION: return new FailureMapping(code, '远程认证不可用', false, RecoveryAction.RECONFIGURE, '认证失败，请检查服务器配置');
      case AppErrorCategory.REMOTE_TIMEOUT: return new FailureMapping(code, '远程服务响应超时', true, RecoveryAction.RETRY, '连接超时，请重试');
      case AppErrorCategory.REMOTE_UNREACHABLE: return new FailureMapping(code, '远程服务不可达', true, RecoveryAction.RETRY, '连接失败，请检查网络后重试');
      case AppErrorCategory.PERSISTENCE: return new FailureMapping(code, '本地数据未保存', true, RecoveryAction.RESTORE_SNAPSHOT, '保存失败，请重试');
      case AppErrorCategory.NAVIGATION: return new FailureMapping(code, '目标页面不可用', true, RecoveryAction.RETURN, '页面打开失败');
      default: return new FailureMapping(code, '当前操作未完成', true, RecoveryAction.RETRY, '操作失败，请重试');
    }
  }
}

export class FailurePresenter {
  static present(failure: AppFailure): string { return failure.message; }
  static logCode(failure: AppFailure): string { return `${failure.category}:${failure.code}`; }
}

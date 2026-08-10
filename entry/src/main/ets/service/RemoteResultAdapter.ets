import { RemoteFailure, RemoteFailureCategory, RemoteResult } from '../model/GovernanceModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x9201;

export class RemoteResultAdapter {
  static success<T>(value: T): RemoteResult<T> {
    return new RemoteResult<T>(true, value, null);
  }

  static failure<T>(category: RemoteFailureCategory, code: string, message: string, retryable: boolean,
    httpStatus: number = 0): RemoteResult<T> {
    return new RemoteResult<T>(false, null,
      new RemoteFailure(category, code, message, retryable, httpStatus));
  }

  static fromHttpStatus<T>(status: number): RemoteResult<T> {
    if (status === 401) {
      return RemoteResultAdapter.failure<T>(RemoteFailureCategory.AUTHENTICATION, 'REMOTE_AUTH_FAILED',
        '认证失败，请返回配置页检查凭据', false, status);
    }
    if (status === 403) {
      return RemoteResultAdapter.failure<T>(RemoteFailureCategory.PERMISSION, 'REMOTE_PERMISSION_DENIED',
        '当前账号没有执行此操作的权限', false, status);
    }
    return RemoteResultAdapter.failure<T>(RemoteFailureCategory.HTTP, 'REMOTE_HTTP_FAILED',
      '远程服务返回异常状态，请稍后重试', status >= 500, status);
  }

  static fromException<T>(error: Error | null): RemoteResult<T> {
    const text: string = error === null ? '' : error.message.toLowerCase();
    if (text.indexOf('timeout') >= 0 || text.indexOf('timed out') >= 0 || text.indexOf('超时') >= 0) {
      return RemoteResultAdapter.failure<T>(RemoteFailureCategory.TIMEOUT, 'REMOTE_TIMEOUT',
        '远程操作超时，请重试', true);
    }
    if (text.indexOf('auth') >= 0 || text.indexOf('password') >= 0 || text.indexOf('credential') >= 0) {
      return RemoteResultAdapter.failure<T>(RemoteFailureCategory.AUTHENTICATION, 'REMOTE_AUTH_FAILED',
        '认证失败，请返回配置页检查凭据', false);
    }
    if (text.indexOf('permission') >= 0 || text.indexOf('denied') >= 0) {
      return RemoteResultAdapter.failure<T>(RemoteFailureCategory.PERMISSION, 'REMOTE_PERMISSION_DENIED',
        '当前账号没有执行此操作的权限', false);
    }
    return RemoteResultAdapter.failure<T>(RemoteFailureCategory.UNREACHABLE, 'REMOTE_UNREACHABLE',
      '远程服务不可达，请检查网络后重试', true);
  }

  static protocolFailure<T>(): RemoteResult<T> {
    return RemoteResultAdapter.failure<T>(RemoteFailureCategory.PROTOCOL, 'REMOTE_PROTOCOL_INVALID',
      '远程响应格式异常，请稍后重试', true);
  }

  static publicMessage<T>(result: RemoteResult<T>): string {
    return result.failure === null ? '' : result.failure.message;
  }

  static logFailure<T>(operation: string, result: RemoteResult<T>): void {
    if (result.failure !== null) {
      hilog.error(DOMAIN, 'RemoteResult',
        'category=%{public}s code=%{public}s rollback=%{public}s',
        result.failure.category, result.failure.code, 'preserved');
    }
  }
}

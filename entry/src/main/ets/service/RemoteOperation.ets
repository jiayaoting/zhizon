import { RemoteFailureCategory, RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from './RemoteResultAdapter';

export class RemoteOperation {
  operation: string;
  host: string;
  port: number;
  path: string;
  connectTimeoutMs: number;
  readTimeoutMs: number;

  constructor(operation: string, host: string, port: number, path: string,
    connectTimeoutMs: number, readTimeoutMs: number) {
    this.operation = operation;
    this.host = host;
    this.port = port;
    this.path = path;
    this.connectTimeoutMs = connectTimeoutMs;
    this.readTimeoutMs = readTimeoutMs;
  }

  validate(): RemoteResult<RemoteOperation> {
    if (this.operation.trim().length === 0 || this.host.trim().length === 0 ||
      this.path.trim().length === 0 || this.path.indexOf('/') !== 0) {
      return RemoteResultAdapter.failure<RemoteOperation>(RemoteFailureCategory.VALIDATION,
        'REMOTE_REQUEST_INVALID', '远程请求参数无效', false);
    }
    if (!Number.isInteger(this.port) || this.port < 1 || this.port > 65535 ||
      !Number.isInteger(this.connectTimeoutMs) || this.connectTimeoutMs < 1 ||
      !Number.isInteger(this.readTimeoutMs) || this.readTimeoutMs < 1) {
      return RemoteResultAdapter.failure<RemoteOperation>(RemoteFailureCategory.VALIDATION,
        'REMOTE_REQUEST_INVALID', '远程请求参数无效', false);
    }
    return RemoteResultAdapter.success<RemoteOperation>(this);
  }
}

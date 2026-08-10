import { http } from '@kit.NetworkKit';
import { RemoteResult } from '../model/GovernanceModels';
import { RemoteOperation } from './RemoteOperation';
import { RemoteResultAdapter } from './RemoteResultAdapter';

export class PveTransportResponse {
  statusCode: number = 0;
  body: Object | null = null;
}

export class PveTransportAdapter {
  static async request(operation: RemoteOperation, method: http.RequestMethod, url: string,
    headers: Object, body: string = ''): Promise<RemoteResult<PveTransportResponse>> {
    const validation: RemoteResult<RemoteOperation> = operation.validate();
    if (!validation.success) {
      return new RemoteResult<PveTransportResponse>(false, null, validation.failure);
    }
    const request: http.HttpRequest = http.createHttp();
    try {
      const response = await request.request(url, {
        method: method,
        header: headers,
        extraData: body.length > 0 ? body : undefined,
        expectDataType: http.HttpDataType.OBJECT,
        connectTimeout: operation.connectTimeoutMs,
        readTimeout: operation.readTimeoutMs
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return RemoteResultAdapter.fromHttpStatus<PveTransportResponse>(response.responseCode);
      }
      if (response.result === null || response.result === undefined) {
        return RemoteResultAdapter.protocolFailure<PveTransportResponse>();
      }
      const transportResponse = new PveTransportResponse();
      transportResponse.statusCode = response.responseCode;
      transportResponse.body = response.result as Object;
      return RemoteResultAdapter.success<PveTransportResponse>(transportResponse);
    } catch (error) {
      return RemoteResultAdapter.fromException<PveTransportResponse>(error instanceof Error ? error : null);
    } finally {
      request.destroy();
    }
  }
}

// 智子 - 生物识别辅助（User Authentication Kit 封装）
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const BIOMETRIC_DOMAIN: number = 0x9201;

const FINGERPRINT: userAuth.UserAuthType = userAuth.UserAuthType.FINGERPRINT;
const FACE: userAuth.UserAuthType = userAuth.UserAuthType.FACE;

export class BiometricHelper {
  // 设备是否支持生物识别（指纹/人脸任一可用即可）
  static isSupported(): boolean {
    return BiometricHelper.supported(FINGERPRINT) || BiometricHelper.supported(FACE);
  }

  private static supported(type: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(type, userAuth.AuthTrustLevel.ATL3);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 发起生物识别认证，返回是否通过
  static authenticate(title: string): Promise<boolean> {
    const promise = new Promise<boolean>((resolve: (value: boolean) => void) => {
      BiometricHelper.startAuth(title, resolve);
    });
    return promise;
  }

  private static startAuth(title: string, resolve: (value: boolean) => void): void {
    let challenge: Uint8Array = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
    try {
      const rand: cryptoFramework.Random = cryptoFramework.createRandom();
      const blob: cryptoFramework.DataBlob | null = rand.generateRandomSync(16);
      if (blob !== null && blob.data !== undefined) {
        challenge = blob.data;
      }
    } catch (e) {
      challenge = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
    }
    const authParam: userAuth.AuthParam = {
      challenge: challenge,
      authType: [FINGERPRINT, FACE],
      authTrustLevel: userAuth.AuthTrustLevel.ATL3
    };
    const widgetParam: userAuth.WidgetParam = {
      title: title
    };
    try {
      const instance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      instance.on('result', {
        onResult(result: userAuth.UserAuthResult): void {
          instance.off('result');
          resolve(result.result === userAuth.UserAuthResultCode.SUCCESS);
        }
      });
      instance.start();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      resolve(false);
      hilog.error(BIOMETRIC_DOMAIN, 'BiometricHelper', 'start failed code=%{public}d msg=%{public}s',
        err.code, err.message);
    }
  }
}

// 智子 - 华为账号服务（Account Kit 统一认证：登录 / 资料 / 取消授权）
import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { DataRepository } from './DataRepository';

const KEY_PROFILE = 'huaweiAccountProfile';

export class HuaweiAccountProfile {
  openId: string;
  unionId: string;
  nickName: string;
  avatarUri: string;

  constructor(openId: string, unionId: string, nickName: string, avatarUri: string) {
    this.openId = openId;
    this.unionId = unionId;
    this.nickName = nickName;
    this.avatarUri = avatarUri;
  }
}

export class HuaweiAccountService {
  // 拉起华为账号授权（scopes: openid + profile），成功返回资料并本地持久化
  static async signIn(context: common.Context): Promise<HuaweiAccountProfile> {
    const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
    const request: authentication.AuthorizationWithHuaweiIDRequest =
      provider.createAuthorizationWithHuaweiIDRequest();
    request.scopes = ['openid', 'profile'];
    request.state = 'zhizon-' + Date.now().toString();

    const controller: authentication.AuthenticationController =
      new authentication.AuthenticationController(context);
    const response: authentication.AuthorizationWithHuaweiIDResponse =
      await controller.executeRequest(request);
    const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = response.data;
    if (credential === undefined) {
      throw new Error('HUAWEI_ACCOUNT_AUTH_CANCELLED');
    }
    const profile: HuaweiAccountProfile = new HuaweiAccountProfile(
      credential.openID !== undefined ? credential.openID : '',
      credential.unionID !== undefined ? credential.unionID : '',
      credential.nickName !== undefined ? credential.nickName : '',
      credential.avatarUri !== undefined ? credential.avatarUri : '');
    await DataRepository.setSetting(KEY_PROFILE, JSON.stringify(profile));
    return profile;
  }

  // 读取上次登录留下的本地资料，未登录返回 null
  static async getStoredProfile(): Promise<HuaweiAccountProfile | null> {
    const raw: string = await DataRepository.getSetting(KEY_PROFILE, '');
    if (raw.length === 0) return null;
    try {
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      return new HuaweiAccountProfile(
        parsed['openId'] as string, parsed['unionId'] as string,
        parsed['nickName'] as string, parsed['avatarUri'] as string);
    } catch (e) {
      return null;
    }
  }

  // 主动解除授权（退出登录）并清除本地资料
  static async signOut(context: common.Context): Promise<void> {
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const request: authentication.CancelAuthorizationRequest =
        provider.createCancelAuthorizationRequest();
      request.state = 'zhizon-' + Date.now().toString();
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(context);
      await controller.executeRequest(request);
    } catch (e) {
    }
    await DataRepository.setSetting(KEY_PROFILE, '');
  }
}

// 智子 - NewsNow 账号（GitHub 登录）凭证与资料管理
// 设计文档：doc/newsnow-redesign.md §6
// JWT 用 HUKS AES-256-GCM 加密后存 settings（与 API Key 同策略）
import { util } from '@kit.ArkTS';
import { DataRepository } from './DataRepository';
import { CryptoHelper } from '../common/CryptoHelper';
import { NewsNowUser } from '../common/HotModels';
import { NewsNowClient } from './NewsNowClient';

const KEY_JWT_ENC = 'hot_jwt_enc';
const KEY_USER = 'hot_user';
// 剩余有效期少于该阈值时提示重新登录
const EXPIRE_WARN_SEC = 3 * 24 * 60 * 60;

// 登录回调解析结果
export class HotLoginCallback {
  matched: boolean;      // 是否为登录成功回调
  jwt: string;
  user: NewsNowUser | null;

  constructor(matched: boolean, jwt: string, user: NewsNowUser | null) {
    this.matched = matched;
    this.jwt = jwt;
    this.user = user;
  }
}

export class NewsNowAuth {
  private static tokenCache: string = '';
  private static tokenLoaded: boolean = false;

  // ==================== 凭证 ====================

  // 取 JWT（明文，内存缓存 + 落盘密文）
  static async getToken(): Promise<string> {
    if (NewsNowAuth.tokenLoaded) return NewsNowAuth.tokenCache;
    const enc: string = await DataRepository.getSetting(KEY_JWT_ENC, '');
    if (enc.length === 0) {
      NewsNowAuth.tokenCache = '';
      NewsNowAuth.tokenLoaded = true;
      return '';
    }
    let plain: string = '';
    try {
      plain = await CryptoHelper.decrypt(enc);
    } catch (e) {
      plain = '';
    }
    NewsNowAuth.tokenCache = plain;
    NewsNowAuth.tokenLoaded = true;
    return plain;
  }

  static async isLoggedIn(): Promise<boolean> {
    const token: string = await NewsNowAuth.getToken();
    return token.length > 0;
  }

  // 保存登录态
  static async saveSession(jwt: string, user: NewsNowUser | null): Promise<boolean> {
    let enc: string = '';
    try {
      enc = await CryptoHelper.encrypt(jwt);
    } catch (e) {
      return false;
    }
    if (enc.length === 0) return false;
    await DataRepository.setSetting(KEY_JWT_ENC, enc);
    await DataRepository.setSetting(KEY_USER, user === null ? '' : JSON.stringify(user));
    NewsNowAuth.tokenCache = jwt;
    NewsNowAuth.tokenLoaded = true;
    return true;
  }

  // 退出登录（本地 focus 数据保留）
  static async clearSession(): Promise<void> {
    await DataRepository.setSetting(KEY_JWT_ENC, '');
    await DataRepository.setSetting(KEY_USER, '');
    NewsNowAuth.tokenCache = '';
    NewsNowAuth.tokenLoaded = true;
  }

  static async getUser(): Promise<NewsNowUser | null> {
    const raw: string = await DataRepository.getSetting(KEY_USER, '');
    if (raw.length === 0) return null;
    try {
      const obj: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const idObj: Object = obj['id'];
      const nameObj: Object = obj['name'];
      const avatarObj: Object = obj['avatar'];
      return new NewsNowUser(
        idObj === undefined || idObj === null ? '' : idObj.toString(),
        nameObj === undefined || nameObj === null ? '' : nameObj.toString(),
        avatarObj === undefined || avatarObj === null ? '' : avatarObj.toString());
    } catch (e) {
      return null;
    }
  }

  // ==================== JWT 解析 ====================

  // 从 JWT payload 取 exp（秒）；失败返回 0
  static expiryOf(jwt: string): number {
    const parts: string[] = jwt.split('.');
    if (parts.length < 2) return 0;
    try {
      const b64: string = NewsNowAuth.base64UrlToBase64(parts[1]);
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = new Uint8Array(helper.decodeSync(b64));
      const decoder: util.TextDecoder = new util.TextDecoder();
      const text: string = decoder.decodeToString(bytes);
      const obj: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const exp: Object = obj['exp'];
      if (exp === undefined || exp === null) return 0;
      const n: number = Number(exp.toString());
      return isNaN(n) ? 0 : n;
    } catch (e) {
      return 0;
    }
  }

  // 从 JWT payload 取 GitHub 用户 id（同步/展示用）
  static subjectOf(jwt: string): string {
    const parts: string[] = jwt.split('.');
    if (parts.length < 2) return '';
    try {
      const b64: string = NewsNowAuth.base64UrlToBase64(parts[1]);
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = new Uint8Array(helper.decodeSync(b64));
      const decoder: util.TextDecoder = new util.TextDecoder();
      const text: string = decoder.decodeToString(bytes);
      const obj: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const id: Object = obj['id'];
      return id === undefined || id === null ? '' : id.toString();
    } catch (e) {
      return '';
    }
  }

  // 是否已过期
  static isExpired(jwt: string): boolean {
    const exp: number = NewsNowAuth.expiryOf(jwt);
    if (exp === 0) return false; // 无 exp 视为长期有效，交由 401 兜底
    return Date.now() / 1000 >= exp;
  }

  // 是否临近过期（用于提示重新登录）
  static isExpiringSoon(jwt: string): boolean {
    const exp: number = NewsNowAuth.expiryOf(jwt);
    if (exp === 0) return false;
    return exp - Date.now() / 1000 < EXPIRE_WARN_SEC;
  }

  // ==================== 登录流程 ====================

  // 登录页地址（302 跳 GitHub 授权）
  static async loginUrl(): Promise<string> {
    const base: string = await NewsNowClient.getBaseUrl();
    return base + '/api/login';
  }

  // 判断当前 URL 是否为登录成功回调；是则解析出 jwt 与用户
  static parseCallback(url: string): HotLoginCallback {
    if (url === undefined || url === null || url.indexOf('jwt=') < 0) {
      return new HotLoginCallback(false, '', null);
    }
    const qIdx: number = url.indexOf('?');
    if (qIdx < 0) return new HotLoginCallback(false, '', null);
    const query: string = url.substring(qIdx + 1);
    const pairs: string[] = query.split('&');
    let jwt: string = '';
    let login: string = '';
    let userRaw: string = '';
    for (let i: number = 0; i < pairs.length; i++) {
      const eq: number = pairs[i].indexOf('=');
      if (eq < 0) continue;
      const k: string = pairs[i].substring(0, eq);
      const v: string = pairs[i].substring(eq + 1);
      if (k === 'jwt') jwt = decodeURIComponent(v);
      else if (k === 'login') login = decodeURIComponent(v);
      else if (k === 'user') userRaw = decodeURIComponent(v);
    }
    if (jwt.length === 0) return new HotLoginCallback(false, '', null);

    let user: NewsNowUser | null = null;
    if (userRaw.length > 0) {
      try {
        const obj: Record<string, Object> = JSON.parse(userRaw) as Record<string, Object>;
        const nameObj: Object = obj['name'];
        const avatarObj: Object = obj['avatar'];
        user = new NewsNowUser(NewsNowAuth.subjectOf(jwt),
          nameObj === undefined || nameObj === null ? '' : nameObj.toString(),
          avatarObj === undefined || avatarObj === null ? '' : avatarObj.toString());
      } catch (e) {
        user = new NewsNowUser(NewsNowAuth.subjectOf(jwt), '', '');
      }
    } else {
      user = new NewsNowUser(NewsNowAuth.subjectOf(jwt), '', '');
    }
    return new HotLoginCallback(login.length === 0 || login === 'github', jwt, user);
  }

  private static base64UrlToBase64(src: string): string {
    let s: string = src.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4 !== 0) s = s + '=';
    return s;
  }
}

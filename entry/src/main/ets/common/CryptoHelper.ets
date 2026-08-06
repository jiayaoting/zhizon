// 智子 - 凭据加密助手（AES-256-GCM）
// 用于加密存储密码与私钥内容，密钥由设备首次运行时生成并持久化在应用沙箱
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const PREF_NAME = 'zhizon_crypto';
const KEY_MASTER = 'master_key_v1';
const TAG_ALGO = 'AES256|GCM|PKCS7';
const IV_LEN = 12;
const TAG_LEN = 16; // GCM 认证标签固定 16 字节

// 密文格式 v2: v1:<iv_b64>:<payload_b64>
// GCM 组合模式：payload = 密文 + authTag（末尾 16 字节）
// 兼容旧格式 v1:<iv_b64>:<tag_b64>:<data_b64>
export class CryptoHelper {
  private static masterKey: cryptoFramework.SymKey | null = null;
  private static prefs: preferences.Preferences | null = null;
  private static base64: util.Base64Helper = new util.Base64Helper();

  // 初始化：加载或生成主密钥（幂等）
  static async init(context: common.Context): Promise<void> {
    if (CryptoHelper.masterKey) return;
    CryptoHelper.prefs = await preferences.getPreferences(context, PREF_NAME);
    const existing = await CryptoHelper.prefs.get(KEY_MASTER, '');
    if (typeof existing === 'string' && existing.length > 0) {
      CryptoHelper.masterKey = await CryptoHelper.importKey(existing);
    } else {
      const gen = cryptoFramework.createSymKeyGenerator('AES256');
      const key = await gen.generateSymKey();
      const encoded = await key.getEncoded();
      const b64 = CryptoHelper.base64.encodeToStringSync(encoded.data);
      await CryptoHelper.prefs.put(KEY_MASTER, b64);
      await CryptoHelper.prefs.flush();
      CryptoHelper.masterKey = key;
    }
  }

  // 加密明文，返回可持久化字符串；失败返回空串
  static async encrypt(plain: string): Promise<string> {
    if (!plain) return '';
    try {
      if (!CryptoHelper.masterKey) throw new Error('CryptoHelper not initialized');
      const rand = cryptoFramework.createRandom();
      const ivData = await rand.generateRandom(IV_LEN);
      const params: cryptoFramework.GcmParamsSpec = {
        iv: { data: ivData.data },
        aad: { data: new Uint8Array(0) },
        authTag: { data: new Uint8Array(0) },
        algName: 'GCM'
      };
      const cipher = cryptoFramework.createCipher(TAG_ALGO);
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, CryptoHelper.masterKey, params);
      // GCM 组合模式：doFinal 输出 = 密文 + authTag（末尾 16 字节）
      const out = await cipher.doFinal({ data: CryptoHelper.strToBytes(plain) });
      return `v1:${CryptoHelper.base64.encodeToStringSync(ivData.data)}:${CryptoHelper.base64.encodeToStringSync(out.data)}`;
    } catch (e) {
      console.error('CryptoHelper.encrypt failed:', e);
      return '';
    }
  }

  // 解密，失败返回空串
  static async decrypt(token: string): Promise<string> {
    if (!token) return '';
    try {
      if (!CryptoHelper.masterKey) throw new Error('CryptoHelper not initialized');
      const parts = token.split(':');
      if (parts[0] !== 'v1') throw new Error('Bad cipher format');
      let iv: Uint8Array;
      let ciphertext: Uint8Array;
      let tag: Uint8Array;
      if (parts.length === 3) {
        // v2 组合模式：payload = 密文 + authTag（末尾 16 字节）
        iv = CryptoHelper.base64.decodeSync(parts[1]);
        const payload = CryptoHelper.base64.decodeSync(parts[2]);
        if (payload.length < TAG_LEN) throw new Error('Bad cipher length');
        ciphertext = payload.subarray(0, payload.length - TAG_LEN);
        tag = payload.subarray(payload.length - TAG_LEN);
      } else if (parts.length === 4) {
        // 兼容旧格式：iv / tag / data 分离
        iv = CryptoHelper.base64.decodeSync(parts[1]);
        tag = CryptoHelper.base64.decodeSync(parts[2]);
        ciphertext = CryptoHelper.base64.decodeSync(parts[3]);
      } else {
        throw new Error('Bad cipher format');
      }
      const params: cryptoFramework.GcmParamsSpec = {
        iv: { data: iv },
        aad: { data: new Uint8Array(0) },
        authTag: { data: tag },
        algName: 'GCM'
      };
      const cipher = cryptoFramework.createCipher(TAG_ALGO);
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, CryptoHelper.masterKey, params);
      const out = await cipher.doFinal({ data: ciphertext });
      return CryptoHelper.bytesToStr(out.data);
    } catch (e) {
      console.error('CryptoHelper.decrypt failed:', e);
      return '';
    }
  }

  // 从 Base64 字符串导入主密钥（首次加载）
  private static async importKey(b64: string): Promise<cryptoFramework.SymKey> {
    const gen = cryptoFramework.createSymKeyGenerator('AES256');
    const data = CryptoHelper.base64.decodeSync(b64);
    return await gen.convertKey({ data: data });
  }

  private static strToBytes(s: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(s);
  }

  private static bytesToStr(bytes: Uint8Array): string {
    const decoder = new util.TextDecoder();
    return decoder.decodeToString(bytes);
  }
}

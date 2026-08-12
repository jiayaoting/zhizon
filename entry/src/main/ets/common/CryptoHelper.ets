// 智子 - 凭据加密助手（HUKS 硬件密钥库 / AES-256-GCM）
// 主密钥由 HUKS 在 TEE/SE 硬件内生成与持久化，不可导出；App 仅持有密钥别名
// 密文格式 v2: v2:<iv_b64>:<payload_b64>  其中 payload = 密文 + authTag（末 16 字节）
import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CRYPTO_DOMAIN = 0x9201;
const KEY_ALIAS = 'zhizon_master_v2'; // HUKS 密钥别名，固定常量
const PREF_NAME_LEGACY = 'zhizon_crypto'; // 旧明文主密钥 preferences 名
const KEY_MASTER_LEGACY = 'master_key_v1'; // 旧明文主密钥键名
const IV_LEN = 12;
const TAG_LEN = 16; // GCM 认证标签固定 16 字节

export class CryptoHelper {
  private static initialized: boolean = false;
  private static base64: util.Base64Helper = new util.Base64Helper();

  // 初始化：探测或生成 HUKS 密钥，并清理旧明文残留（幂等）
  static async init(context: common.Context): Promise<void> {
    if (CryptoHelper.initialized) return;

    // 1. 探测密钥是否已存在
    const exists: boolean = await CryptoHelper.keyExists();
    if (!exists) {
      // 2. 不存在则生成（密钥本体留在硬件内，App 拿不到明文）
      await CryptoHelper.generateKey();
    }

    // 3. 清理旧明文主密钥残留（开发期数据丢弃策略）
    await CryptoHelper.cleanupLegacyMasterKey(context);

    CryptoHelper.initialized = true;
  }

  // 加密明文，返回可持久化字符串（v2:<iv_b64>:<payload_b64>）
  static async encrypt(plain: string): Promise<string> {
    if (!plain) return '';
    if (!CryptoHelper.initialized) {
      throw new Error('CryptoHelper 未初始化，请退出应用后重试');
    }
    try {
      // 1. 生成 12 字节随机 IV
      const rand: cryptoFramework.Random = cryptoFramework.createRandom();
      const ivBlob: cryptoFramework.DataBlob = await rand.generateRandom(IV_LEN);
      const iv: Uint8Array = new Uint8Array(ivBlob.data);

      // 2. 构造 HUKS 加密 options：inData 放明文，properties 放算法参数
      const plainBytes: Uint8Array = CryptoHelper.strToBytes(plain);
      const options: huks.HuksOptions = {
        properties: [
          { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
          { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
          { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
          { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
          { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
          { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
          { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new Uint8Array(0) }
        ],
        inData: plainBytes
      };

      // 3. initSession 拿到 handle
      const session: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
      const handle: number = session.handle;

      // 4. finishSession 输出 = 密文 + authTag（GCM 组合输出，末 16 字节为 tag）
      const finishOptions: huks.HuksOptions = {
        properties: [],
        inData: plainBytes
      };
      const out: huks.HuksReturnResult = await huks.finishSession(handle, finishOptions);
      if (!out.outData) {
        throw new Error('HUKS finishSession 返回空数据');
      }
      const payload: Uint8Array = out.outData;

      // 5. 拼装密文：v2:<iv_b64>:<payload_b64>
      const ivB64: string = CryptoHelper.base64.encodeToStringSync(iv);
      const payloadB64: string = CryptoHelper.base64.encodeToStringSync(payload);
      return `v2:${ivB64}:${payloadB64}`;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(CRYPTO_DOMAIN, 'CryptoHelper', '%{public}s',
        `operation=credential-encrypt category=DATA_SECURITY code=CREDENTIAL_ENCRYPT_FAILED huks_code=${err.code} msg=${err.message}`);
      throw new Error(`CREDENTIAL_ENCRYPT_FAILED: huks_code=${err.code} msg=${err.message}`);
    }
  }

  // 解密，失败返回空串
  static async decrypt(token: string): Promise<string> {
    if (!token) return '';
    try {
      if (!CryptoHelper.initialized) throw new Error('CryptoHelper not initialized');
      const parts: string[] = token.split(':');
      if (parts[0] !== 'v2') {
        // 旧 v1 格式或未知格式，开发期数据丢弃，直接返回空串
        throw new Error('Unsupported cipher format (legacy data dropped)');
      }
      if (parts.length !== 3) throw new Error('Bad cipher format');

      // 1. 解析 IV 与 payload
      const iv: Uint8Array = new Uint8Array(CryptoHelper.base64.decodeSync(parts[1]));
      const payload: Uint8Array = new Uint8Array(CryptoHelper.base64.decodeSync(parts[2]));
      if (payload.length < TAG_LEN) throw new Error('Bad cipher length');

      // 2. 切分密文与 authTag（末 16 字节）
      const ciphertext: Uint8Array = payload.subarray(0, payload.length - TAG_LEN);
      const tag: Uint8Array = payload.subarray(payload.length - TAG_LEN);

      // 3. 构造 HUKS 解密 options：inData 放密文，properties 含 IV + AE_TAG
      const options: huks.HuksOptions = {
        properties: [
          { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
          { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
          { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
          { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
          { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
          { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
          { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new Uint8Array(0) },
          { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag }
        ],
        inData: ciphertext
      };

      // 4. initSession + finishSession
      const session: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options);
      const finishOptions: huks.HuksOptions = {
        properties: [],
        inData: ciphertext
      };
      const out: huks.HuksReturnResult = await huks.finishSession(session.handle, finishOptions);
      if (!out.outData) {
        throw new Error('HUKS finishSession 返回空数据');
      }
      return CryptoHelper.bytesToStr(out.outData);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(CRYPTO_DOMAIN, 'CryptoHelper', '%{public}s',
        `operation=credential-decrypt category=DATA_SECURITY code=CREDENTIAL_DECRYPT_FAILED huks_code=${err.code} msg=${err.message} rollback=empty-value`);
      return '';
    }
  }

  // 探测 HUKS 密钥是否已存在
  private static async keyExists(): Promise<boolean> {
    try {
      // 用空 properties 探测；密钥存在时返回成功，不存在时抛错
      const emptyOptions: huks.HuksOptions = { properties: [] };
      await huks.getKeyItemProperties(KEY_ALIAS, emptyOptions);
      return true;
    } catch (e) {
      // 密钥不存在会抛 HUKS 错误码（如 12000011 / 401 等），统一视为不存在
      return false;
    }
  }

  // 生成 HUKS 密钥（密钥留在硬件内，不可导出）
  private static async generateKey(): Promise<void> {
    const keyProperties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NO_AUTH_REQUIRED, value: true } // 开发期不绑定生物识别，上架前可改
    ];
    const genOptions: huks.HuksOptions = { properties: keyProperties };
    await huks.generateKeyItem(KEY_ALIAS, genOptions);
  }

  // 清理旧明文主密钥残留（开发期数据丢弃策略）
  private static async cleanupLegacyMasterKey(context: common.Context): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, PREF_NAME_LEGACY);
      const existing = await prefs.get(KEY_MASTER_LEGACY, '');
      if (typeof existing === 'string' && existing.length > 0) {
        await prefs.delete(KEY_MASTER_LEGACY);
        await prefs.flush();
        hilog.info(CRYPTO_DOMAIN, 'CryptoHelper', '%{public}s',
          'operation=cleanup-legacy-master-key category=DATA_SECURITY result=removed');
      }
    } catch (e) {
      // 清理失败不影响主流程
      hilog.warn(CRYPTO_DOMAIN, 'CryptoHelper', '%{public}s',
        'operation=cleanup-legacy-master-key category=DATA_SECURITY result=skipped reason=cleanup-error');
    }
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

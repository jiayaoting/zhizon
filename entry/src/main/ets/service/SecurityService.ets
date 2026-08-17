// 智子 - 安全服务（主密码哈希存储 / 生物识别开关 / 自动锁定 / 锁定状态）
// 所有功能默认关闭：未设置主密码时，生物识别与自动锁定均不生效
import { DataRepository } from './DataRepository';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { AppStorageV2 } from '@kit.ArkUI';
import { ThemeState } from '../common/ThemeState';

const KEY_PASSWORD_HASH = 'securityPasswordHash';
const KEY_BIOMETRIC = 'biometricUnlock';
const KEY_AUTO_LOCK = 'autoLock';

export const AUTO_LOCK_OFF = 0;        // 关闭
export const AUTO_LOCK_IMMEDIATE = -1; // 立即
export const AUTO_LOCK_OPTIONS: number[] = [0, -1, 1, 5, 15, 30];

export function autoLockLabel(value: number): string {
  if (value === 0) return '关闭';
  if (value === -1) return '立即';
  return value.toString() + ' 分钟';
}

export class SecurityService {
  // ---- 主密码（SHA-256 加盐哈希，不存明文）----

  static async hasPassword(): Promise<boolean> {
    const stored: string = await DataRepository.getSetting(KEY_PASSWORD_HASH, '');
    return stored.length > 0;
  }

  static async setPassword(password: string): Promise<void> {
    if (password.length === 0) {
      throw new Error('EMPTY_PASSWORD');
    }
    const saltB64: string = await SecurityService.randomSalt();
    const hashB64: string = await SecurityService.hashPassword(password, saltB64);
    await DataRepository.setSetting(KEY_PASSWORD_HASH, saltB64 + ':' + hashB64);
  }

  static async verifyPassword(password: string): Promise<boolean> {
    const stored: string = await DataRepository.getSetting(KEY_PASSWORD_HASH, '');
    if (stored.length === 0) return false;
    const parts: string[] = stored.split(':');
    if (parts.length !== 2) return false;
    const hashB64: string = await SecurityService.hashPassword(password, parts[0]);
    return hashB64 === parts[1];
  }

  // 清除主密码时一并关闭生物识别与自动锁定（保持默认关闭）
  static async clearPassword(): Promise<void> {
    await DataRepository.setSetting(KEY_PASSWORD_HASH, '');
    await SecurityService.setBiometricEnabled(false);
    await SecurityService.setAutoLockValue(AUTO_LOCK_OFF);
  }

  // ---- 生物识别解锁 ----

  static async isBiometricEnabled(): Promise<boolean> {
    const raw: string = await DataRepository.getSetting(KEY_BIOMETRIC, 'false');
    return raw === 'true';
  }

  static async setBiometricEnabled(enabled: boolean): Promise<void> {
    await DataRepository.setSetting(KEY_BIOMETRIC, enabled ? 'true' : 'false');
  }

  // ---- 自动锁定（0=关闭，-1=立即，正数=分钟数）----

  static async getAutoLockValue(): Promise<number> {
    const raw: string = await DataRepository.getSetting(KEY_AUTO_LOCK, '');
    if (raw.length === 0) return AUTO_LOCK_OFF;
    const value: number = Number(raw);
    if (Number.isNaN(value)) return AUTO_LOCK_OFF;
    return value;
  }

  static async setAutoLockValue(value: number): Promise<void> {
    await DataRepository.setSetting(KEY_AUTO_LOCK, value.toString());
  }

  // ---- 锁定状态（AppStorage）----

  static isLocked(): boolean {
    return AppStorage.get<boolean>('appLocked') === true;
  }

  static lock(): void {
    AppStorage.setOrCreate('appLocked', true);
    const themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
    themeState.appLocked = true;
  }

  static unlock(): void {
    AppStorage.setOrCreate('appLocked', false);
    const themeState: ThemeState = AppStorageV2.connect(ThemeState, 'themeState', () => new ThemeState())!;
    themeState.appLocked = false;
  }

  // 应用进入后台：记录时间；"立即锁定"时直接锁定
  static async onBackground(): Promise<void> {
    AppStorage.setOrCreate('appBackgroundTime', Date.now());
    if ((await SecurityService.hasPassword()) &&
      (await SecurityService.getAutoLockValue()) === AUTO_LOCK_IMMEDIATE) {
      SecurityService.lock();
    }
  }

  // 应用回到前台：按自动锁定策略判定是否需要锁定
  static async checkAndLockOnForeground(): Promise<void> {
    if (!(await SecurityService.hasPassword())) {
      SecurityService.unlock();
      return;
    }
    const value: number = await SecurityService.getAutoLockValue();
    if (value === AUTO_LOCK_OFF) {
      SecurityService.unlock();
      return;
    }
    if (value === AUTO_LOCK_IMMEDIATE) {
      SecurityService.lock();
      return;
    }
    const bgTime: number = AppStorage.get<number>('appBackgroundTime') ?? 0;
    if (bgTime > 0 && Date.now() - bgTime >= value * 60000) {
      SecurityService.lock();
    }
  }

  // ---- 内部工具 ----

  private static async randomSalt(): Promise<string> {
    const rand: cryptoFramework.Random = cryptoFramework.createRandom();
    const blob: cryptoFramework.DataBlob = await rand.generateRandom(16);
    return SecurityService.bytesToB64(blob.data);
  }

  private static async hashPassword(password: string, saltB64: string): Promise<string> {
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    const salt: Uint8Array = SecurityService.b64ToBytes(saltB64);
    const pwdBytes: Uint8Array = SecurityService.strToBytes(password);
    const combined: Uint8Array = new Uint8Array(salt.length + pwdBytes.length);
    combined.set(salt, 0);
    combined.set(pwdBytes, salt.length);
    const input: cryptoFramework.DataBlob = { data: combined };
    await md.update(input);
    const digest: cryptoFramework.DataBlob = await md.digest();
    return SecurityService.bytesToB64(digest.data);
  }

  private static base64: util.Base64Helper = new util.Base64Helper();

  private static bytesToB64(bytes: Uint8Array): string {
    return SecurityService.base64.encodeToStringSync(bytes);
  }

  private static b64ToBytes(b64: string): Uint8Array {
    return new Uint8Array(SecurityService.base64.decodeSync(b64));
  }

  private static strToBytes(s: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(s);
  }
}

// 智子 - 游戏音效服务（SoundPool 低时延短音频播放）
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { DatabaseHelper } from './DatabaseHelper';

export type SoundName = 'click' | 'move' | 'eat' | 'clear' | 'gameover' | 'win' | 'achievement';

const SOUND_FILES: Record<string, string> = {
  'click': 'sounds/click.wav',
  'move': 'sounds/move.wav',
  'eat': 'sounds/eat.wav',
  'clear': 'sounds/clear.wav',
  'gameover': 'sounds/gameover.wav',
  'win': 'sounds/win.wav',
  'achievement': 'sounds/achievement.wav'
};

export class SoundService {
  private static pool: media.SoundPool | null = null;
  private static soundIds: Record<string, number> = {};
  private static enabled: boolean = true;
  private static ready: boolean = false;

  // 应用启动时初始化：读取开关并预加载全部音效
  static async init(context: common.Context): Promise<void> {
    try {
      const raw: string = await DatabaseHelper.getSetting('soundEffectsEnabled', 'true');
      SoundService.enabled = raw === 'true';
      if (!SoundService.enabled) return;

      const audioRendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      SoundService.pool = await media.createSoundPool(8, audioRendererInfo);
      const keys: string[] = Object.keys(SOUND_FILES);
      for (let i: number = 0; i < keys.length; i++) {
        const key: string = keys[i];
        const fd = await context.resourceManager.getRawFd(SOUND_FILES[key]);
        const soundId: number = await SoundService.pool.load(fd.fd, fd.offset, fd.length);
        SoundService.soundIds[key] = soundId;
      }
      SoundService.ready = true;
    } catch (e) {
      // 音效非关键路径：加载失败时静默降级
      SoundService.ready = false;
    }
  }

  static isEnabled(): boolean {
    return SoundService.enabled;
  }

  static async setEnabled(enabled: boolean): Promise<void> {
    SoundService.enabled = enabled;
    await DatabaseHelper.setSetting('soundEffectsEnabled', enabled ? 'true' : 'false');
    if (!enabled) {
      await SoundService.release();
    }
  }

  // 播放指定音效；未初始化或关闭时静默忽略
  static async play(name: SoundName): Promise<void> {
    if (!SoundService.enabled || !SoundService.ready || SoundService.pool === null) return;
    const soundId: number | undefined = SoundService.soundIds[name];
    if (soundId === undefined) return;
    const params: media.PlayParameters = {
      loop: 0,
      rate: 1,
      leftVolume: 0.6,
      rightVolume: 0.6,
      priority: 0
    };
    try {
      await SoundService.pool.play(soundId, params);
    } catch (e) {
    }
  }

  static async release(): Promise<void> {
    if (SoundService.pool !== null) {
      try {
        await SoundService.pool.release();
      } catch (e) {
      }
    }
    SoundService.pool = null;
    SoundService.soundIds = {};
    SoundService.ready = false;
  }
}

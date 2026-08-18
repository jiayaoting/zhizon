// 智子 - 语音服务（Speech Kit：语音转文字 + TTS 朗读）
// 语音识别：AudioCapturer 采集麦克风 PCM → speechRecognizer.writeAudio 逐块送入 → onResult 回调
// TTS：textToSpeech 引擎朗读文本
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, Permissions, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 识别回调
export interface SpeechRecognitionCallbacks {
  // 中间结果（随说话实时更新）
  onPartial: (text: string) => void;
  // 最终结果（识别完成）
  onFinal: (text: string) => void;
  // 错误
  onError: (code: number, message: string) => void;
}

// TTS 状态回调
export interface SpeechSpeakCallbacks {
  onStart?: () => void;
  onComplete?: () => void;
  onError?: (code: number, message: string) => void;
}

export class SpeechService {
  // ---- 麦克风权限 ----
  static async requestMicPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      if (result.authResults === undefined || result.authResults.length === 0) return false;
      return result.authResults[0] === 0; // 0 = granted
    } catch (e) {
      return false;
    }
  }

  // ==================== 语音转文字 ====================

  private static recEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private static capturer: audio.AudioCapturer | null = null;
  private static recSessionId: string = '';
  private static recListening: boolean = false;
  private static recStarted: boolean = false;
  private static recCallbacks: SpeechRecognitionCallbacks | null = null;
  private static recBuffer: number[] = [];

  // 开始语音识别（自动请求麦克风权限；返回是否成功启动）
  static async startRecognition(context: common.UIAbilityContext,
    callbacks: SpeechRecognitionCallbacks): Promise<boolean> {
    SpeechService.stopRecognition();
    const granted: boolean = await SpeechService.requestMicPermission(context);
    if (!granted) {
      callbacks.onError(-1, '未获得麦克风权限');
      return false;
    }
    try {
      // 创建识别引擎（在线模式，中文）
      const engine = await speechRecognizer.createEngine({
        language: 'zh-CN',
        online: 0
      });
      SpeechService.recEngine = engine;
      SpeechService.recCallbacks = callbacks;
      SpeechService.recSessionId = 'zhizon-rec-' + Date.now().toString();
      engine.setListener({
        onStart: (sessionId: string, eventMessage: string): void => {
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          if (SpeechService.recCallbacks === null) return;
          if (result.isFinal) {
            if (SpeechService.recCallbacks !== null) {
              SpeechService.recCallbacks.onFinal(result.result);
            }
          } else {
            if (SpeechService.recCallbacks !== null) {
              SpeechService.recCallbacks.onPartial(result.result);
            }
          }
        },
        onComplete: (sessionId: string, eventMessage: string): void => {
          SpeechService.stopRecognition();
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
          SpeechService.stopRecognition();
          if (SpeechService.recCallbacks !== null) {
            const cb: SpeechRecognitionCallbacks = SpeechService.recCallbacks;
            SpeechService.recCallbacks = null;
            cb.onError(errorCode, errorMessage);
          }
        }
      });
      // 开始监听：16kHz / 单声道 / 16bit PCM
      engine.startListening({
        sessionId: SpeechService.recSessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      });
      // 启动麦克风采集
      const started: boolean = await SpeechService.startCapturer();
      if (!started) {
        SpeechService.stopRecognition();
        if (SpeechService.recCallbacks !== null) {
          const cb: SpeechRecognitionCallbacks = SpeechService.recCallbacks;
          SpeechService.recCallbacks = null;
          cb.onError(-2, '麦克风启动失败');
        }
        return false;
      }
      SpeechService.recListening = true;
      return true;
    } catch (e) {
      SpeechService.stopRecognition();
      const err: BusinessError = e as BusinessError;
      if (SpeechService.recCallbacks !== null) {
        const cb: SpeechRecognitionCallbacks = SpeechService.recCallbacks;
        SpeechService.recCallbacks = null;
        cb.onError(err.code, err.message);
      }
      return false;
    }
  }

  private static async startCapturer(): Promise<boolean> {
    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };
      const options: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      };
      const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options);
      await capturer.start();
      SpeechService.capturer = capturer;
      SpeechService.recBuffer = [];
      const bufferSize: number = await capturer.getBufferSize();
      // 异步读取循环：读一块 → 拆 640 字节块送入识别引擎
      SpeechService.readAudioLoop(capturer, bufferSize);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 读取一次采集缓冲并拆成 640 字节块送入引擎（异步循环）
  private static async readAudioLoop(capturer: audio.AudioCapturer, bufferSize: number): Promise<void> {
    while (SpeechService.recListening && SpeechService.capturer === capturer &&
      SpeechService.recEngine !== null) {
      try {
        const data: ArrayBuffer = await capturer.read(bufferSize, true);
        const bytes: Uint8Array = new Uint8Array(data);
        const pending: number[] = SpeechService.recBuffer;
        for (let i: number = 0; i < bytes.length; i++) {
          pending.push(bytes[i]);
        }
        // 每 640 字节（20ms）为一块；不足的留在缓冲中
        const CHUNK: number = 640;
        while (pending.length >= CHUNK) {
          const chunk: Uint8Array = new Uint8Array(CHUNK);
          for (let i: number = 0; i < CHUNK; i++) {
            chunk[i] = pending[i];
          }
          pending.splice(0, CHUNK);
          try {
            if (SpeechService.recEngine !== null) {
              SpeechService.recEngine.writeAudio(SpeechService.recSessionId, chunk);
            }
          } catch (e) {
            // 引擎繁忙等场景忽略单块写入失败
          }
        }
      } catch (e) {
        SpeechService.stopRecognition();
        break;
      }
    }
  }

  // 结束识别（提交剩余音频并等待最终结果）
  static stopRecognition(): void {
    SpeechService.recListening = false;
    if (SpeechService.capturer !== null) {
      try {
        SpeechService.capturer.stop();
      } catch (e) {
      }
      try {
        SpeechService.capturer.release();
      } catch (e) {
      }
      SpeechService.capturer = null;
    }
    if (SpeechService.recEngine !== null) {
      try {
        if (SpeechService.recStarted && SpeechService.recSessionId.length > 0) {
          // 有采集则先 finish 拿最终结果
          SpeechService.recEngine.finish(SpeechService.recSessionId);
        } else {
          SpeechService.recEngine.cancel(SpeechService.recSessionId);
        }
      } catch (e) {
        try {
          SpeechService.recEngine.cancel(SpeechService.recSessionId);
        } catch (e2) {
        }
      }
      try {
        SpeechService.recEngine.shutdown();
      } catch (e) {
      }
      SpeechService.recEngine = null;
    }
    SpeechService.recStarted = false;
    SpeechService.recBuffer = [];
  }

  static isRecognizing(): boolean {
    return SpeechService.recListening;
  }

  // ==================== TTS 朗读 ====================

  private static ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private static ttsCallbacks: SpeechSpeakCallbacks | null = null;
  private static ttsBusy: boolean = false;

  // 朗读文本（自动初始化引擎；若正在朗读则先停止）
  static async speak(text: string, callbacks: SpeechSpeakCallbacks = {}): Promise<void> {
    const content: string = text.trim();
    if (content.length === 0) return;
    if (SpeechService.ttsBusy) {
      SpeechService.stopSpeaking();
    }
    SpeechService.ttsCallbacks = callbacks;
    try {
      if (SpeechService.ttsEngine === null) {
        SpeechService.ttsEngine = await textToSpeech.createEngine({
          language: 'zh-CN',
          person: 0,
          online: 0
        });
        SpeechService.ttsEngine.setListener({
          onStart: (requestId: string, response: textToSpeech.StartResponse): void => {
          },
          onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
            SpeechService.ttsBusy = false;
            if (SpeechService.ttsCallbacks !== null && SpeechService.ttsCallbacks.onComplete !== undefined) {
              SpeechService.ttsCallbacks.onComplete();
            }
          },
          onStop: (requestId: string, response: textToSpeech.StopResponse): void => {
            SpeechService.ttsBusy = false;
          },
          onError: (requestId: string, errorCode: number, errorMessage: string): void => {
            SpeechService.ttsBusy = false;
            if (SpeechService.ttsCallbacks !== null && SpeechService.ttsCallbacks.onError !== undefined) {
              SpeechService.ttsCallbacks.onError(errorCode, errorMessage);
            }
          },
          onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse): void => {
          }
        });
      }
      SpeechService.ttsBusy = true;
      SpeechService.ttsEngine.speak(content, {
        requestId: 'zhizon-tts-' + Date.now().toString()
      });
    } catch (e) {
      SpeechService.ttsBusy = false;
      const err: BusinessError = e as BusinessError;
      if (SpeechService.ttsCallbacks !== null && SpeechService.ttsCallbacks.onError !== undefined) {
        SpeechService.ttsCallbacks.onError(err.code, err.message);
      }
      SpeechService.ttsCallbacks = null;
    }
  }

  // 停止朗读
  static stopSpeaking(): void {
    SpeechService.ttsBusy = false;
    SpeechService.ttsCallbacks = null;
    if (SpeechService.ttsEngine !== null) {
      try {
        SpeechService.ttsEngine.stop();
      } catch (e) {
      }
    }
  }

  static isSpeaking(): boolean {
    return SpeechService.ttsBusy;
  }

  // 释放 TTS 引擎（页面销毁时调用）
  static releaseTts(): void {
    SpeechService.ttsBusy = false;
    SpeechService.ttsCallbacks = null;
    if (SpeechService.ttsEngine !== null) {
      try {
        SpeechService.ttsEngine.shutdown();
      } catch (e) {
      }
      SpeechService.ttsEngine = null;
    }
  }
}

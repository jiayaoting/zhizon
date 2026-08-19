// 智子 - 端侧 AI（Core Vision Kit 通用文字识别 OCR）
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { PickerAdapter, ImagePickResult, ImagePickState } from './PickerAdapter';

const DB_DOMAIN = 0x9201;

export class OcrResult {
  ok: boolean;
  text: string;
  message: string;

  constructor(ok: boolean, text: string, message: string) {
    this.ok = ok;
    this.text = text;
    this.message = message;
  }
}

export class OnDeviceAiService {
  private static ready: boolean = false;

  // 初始化文字识别模型（首次调用自动加载）
  static async ensureReady(): Promise<boolean> {
    if (OnDeviceAiService.ready) return true;
    try {
      const ok: boolean = await textRecognition.init();
      OnDeviceAiService.ready = ok;
      return ok;
    } catch (e) {
      OnDeviceAiService.ready = false;
      return false;
    }
  }

  static async release(): Promise<void> {
    if (!OnDeviceAiService.ready) return;
    try {
      await textRecognition.release();
    } catch (e) {
    }
    OnDeviceAiService.ready = false;
  }

  // 拉起图库选图并识别文字
  static async pickAndRecognize(): Promise<OcrResult> {
    const picked: ImagePickResult = await PickerAdapter.pickSingleImage();
    if (picked.state !== ImagePickState.SELECTED || picked.uri.length === 0) {
      return new OcrResult(false, '', picked.state === ImagePickState.CANCELLED ? '已取消选择' : '图片选择失败');
    }
    return await OnDeviceAiService.recognizeFromUri(picked.uri);
  }

  // 从图片 URI 识别文字（端侧，不出网）
  static async recognizeFromUri(uri: string): Promise<OcrResult> {
    const ready: boolean = await OnDeviceAiService.ensureReady();
    if (!ready) {
      return new OcrResult(false, '', '端侧识别服务初始化失败');
    }
    let file: fileIo.File | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: PixelMap | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(file.fd);
      pixelMap = await imageSource.createPixelMap();
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const configuration: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: false
      };
      const result: textRecognition.TextRecognitionResult =
        await textRecognition.recognizeText(visionInfo, configuration);
      const text: string = result.value.trim();
      if (text.length === 0) {
        return new OcrResult(false, '', '未识别到文字');
      }
      return new OcrResult(true, text, '识别成功');
    } catch (e) {
      return new OcrResult(false, '', '识别失败：' + OnDeviceAiService.errMsg(e));
    } finally {
      if (pixelMap !== null) {
        try { pixelMap.release(); } catch (e) {}
      }
      if (imageSource !== null) {
        try { imageSource.release(); } catch (e) {}
      }
      if (file !== null) {
        try { fileIo.closeSync(file); } catch (e) {}
      }
    }
  }

  private static errMsg(e: Object): string {
    const err = e as Error;
    if (err.message !== undefined && err.message.length > 0) return err.message;
    return '未知错误';
  }
}

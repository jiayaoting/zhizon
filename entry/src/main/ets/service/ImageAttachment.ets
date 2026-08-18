// 智子 - 图片附件服务（相册选取 + 压缩 + base64 data URL）
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';

// 附件结果：原始 uri（预留）、显示名、data URL（data:image/jpeg;base64,xxx）
export class AttachmentResult {
  uri: string;
  name: string;
  dataUrl: string;

  constructor(uri: string, name: string, dataUrl: string) {
    this.uri = uri;
    this.name = name;
    this.dataUrl = dataUrl;
  }
}

export class ImageAttachment {
  // 相册选取一张图片并压缩为 JPEG data URL（质量 80）
  static async pickAndCompress(): Promise<AttachmentResult | null> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) return null;
      const uri: string = result.photoUris[0];
      const name: string = ImageAttachment.nameFromUri(uri);
      const bytes: ArrayBuffer = await ImageAttachment.readAndCompress(uri);
      const base64: string = ImageAttachment.toBase64(bytes);
      return new AttachmentResult(uri, name, 'data:image/jpeg;base64,' + base64);
    } catch (e) {
      return null;
    }
  }

  private static nameFromUri(uri: string): string {
    const idx: number = uri.lastIndexOf('/');
    const tail: string = idx >= 0 ? uri.substring(idx + 1) : uri;
    return tail.length > 24 ? tail.substring(0, 24) + '…' : tail;
  }

  private static async readAndCompress(uri: string): Promise<ArrayBuffer> {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(uri);
    const buf = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buf);
    fs.closeSync(file);
    const src: image.ImageSource = image.createImageSource(buf);
    const pixelMap: image.PixelMap = await src.createPixelMap();
    const packer: image.ImagePacker = image.createImagePacker();
    const packingOptions: image.PackingOption = { format: 'image/jpeg', quality: 80 };
    const packed: ArrayBuffer = await packer.packing(pixelMap, packingOptions);
    src.release();
    pixelMap.release();
    packer.release();
    return packed;
  }

  private static toBase64(bytes: ArrayBuffer): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(new Uint8Array(bytes));
  }
}

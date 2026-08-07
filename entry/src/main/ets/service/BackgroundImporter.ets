import { fileIo } from '@kit.CoreFileKit';

export enum BackgroundImportFailure {
  SOURCE_UNREADABLE = 'SOURCE_UNREADABLE',
  EMPTY_FILE = 'EMPTY_FILE',
  FILE_TOO_LARGE = 'FILE_TOO_LARGE',
  UNSUPPORTED_IMAGE = 'UNSUPPORTED_IMAGE',
  SANDBOX_WRITE_FAILED = 'SANDBOX_WRITE_FAILED'
}

export class BackgroundImportResult {
  success: boolean;
  sandboxUri: string;
  reason: BackgroundImportFailure | null;

  constructor(success: boolean, sandboxUri: string, reason: BackgroundImportFailure | null) {
    this.success = success;
    this.sandboxUri = sandboxUri;
    this.reason = reason;
  }
}

export class BackgroundImporter {
  private static sequence: number = 0;
  private static readonly MAX_FILE_SIZE: number = 20 * 1024 * 1024;

  static importToSandbox(context: Context, sourceUri: string): BackgroundImportResult {
    let sourceFile: fileIo.File | null = null;
    try {
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(sourceFile.fd);
      if (stat.size <= 0) {
        fileIo.closeSync(sourceFile);
        return new BackgroundImportResult(false, '', BackgroundImportFailure.EMPTY_FILE);
      }
      if (stat.size > BackgroundImporter.MAX_FILE_SIZE) {
        fileIo.closeSync(sourceFile);
        return new BackgroundImportResult(false, '', BackgroundImportFailure.FILE_TOO_LARGE);
      }
      const buffer = new ArrayBuffer(stat.size);
      const readLength = fileIo.readSync(sourceFile.fd, buffer);
      fileIo.closeSync(sourceFile);
      sourceFile = null;
      if (readLength <= 0 || readLength !== stat.size) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.EMPTY_FILE);
      }
      const bytes = new Uint8Array(buffer);
      if (!BackgroundImporter.isSupportedImage(bytes, readLength)) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.UNSUPPORTED_IMAGE);
      }
      BackgroundImporter.sequence++;
      const fileName = 'global_background_' + Date.now().toString() + '_' +
        BackgroundImporter.sequence.toString() + BackgroundImporter.extension(bytes, readLength);
      const targetPath = context.filesDir + '/' + fileName;
      const targetFile = fileIo.openSync(targetPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        const writeLength = fileIo.writeSync(targetFile.fd, buffer);
        if (writeLength !== readLength) {
          return new BackgroundImportResult(false, '', BackgroundImportFailure.SANDBOX_WRITE_FAILED);
        }
      } finally {
        fileIo.closeSync(targetFile);
      }
      return new BackgroundImportResult(true, targetPath, null);
    } catch (e) {
      if (sourceFile !== null) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (closeError) {
        }
      }
      return new BackgroundImportResult(false, '', BackgroundImportFailure.SANDBOX_WRITE_FAILED);
    }
  }

  private static isSupportedImage(bytes: Uint8Array, length: number): boolean {
    if (length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return true;
    if (length >= 8 && bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71 &&
      bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10) return true;
    if (length >= 6 && bytes[0] === 71 && bytes[1] === 73 && bytes[2] === 70 && bytes[3] === 56 &&
      (bytes[4] === 55 || bytes[4] === 57) && bytes[5] === 97) return true;
    return length >= 12 && bytes[0] === 82 && bytes[1] === 73 && bytes[2] === 70 && bytes[3] === 70 &&
      bytes[8] === 87 && bytes[9] === 69 && bytes[10] === 66 && bytes[11] === 80;
  }

  private static extension(bytes: Uint8Array, length: number): string {
    if (length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return '.jpg';
    if (length >= 8 && bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71) return '.png';
    if (length >= 6 && bytes[0] === 71 && bytes[1] === 73 && bytes[2] === 70) return '.gif';
    return '.webp';
  }
}

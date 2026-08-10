import { fileIo } from '@kit.CoreFileKit';

export enum BackgroundImportFailure {
  INVALID_URI = 'INVALID_URI',
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
  private static readonly CHUNK_SIZE: number = 256 * 1024;

  static async importToSandbox(context: Context, sourceUri: string): Promise<BackgroundImportResult> {
    if (sourceUri.trim().length === 0) {
      return new BackgroundImportResult(false, '', BackgroundImportFailure.INVALID_URI);
    }
    let sourceFile: fileIo.File | null = null;
    let targetFile: fileIo.File | null = null;
    let targetPath: string = '';
    let failure: BackgroundImportFailure = BackgroundImportFailure.SOURCE_UNREADABLE;
    let completed: boolean = false;
    try {
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(sourceFile.fd);
      if (stat.size <= 0) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.EMPTY_FILE);
      }
      if (stat.size > BackgroundImporter.MAX_FILE_SIZE) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.FILE_TOO_LARGE);
      }

      const firstChunkSize = Math.min(BackgroundImporter.CHUNK_SIZE, stat.size);
      const firstBuffer = new ArrayBuffer(firstChunkSize);
      const firstReadLength = await fileIo.read(sourceFile.fd, firstBuffer);
      if (firstReadLength <= 0) return new BackgroundImportResult(false, '', BackgroundImportFailure.EMPTY_FILE);
      const firstBytes = new Uint8Array(firstBuffer);
      if (!BackgroundImporter.isSupportedImage(firstBytes, firstReadLength)) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.UNSUPPORTED_IMAGE);
      }

      BackgroundImporter.sequence++;
      const fileName = 'global_background_' + Date.now().toString() + '_' +
        BackgroundImporter.sequence.toString() + BackgroundImporter.extension(firstBytes, firstReadLength);
      targetPath = context.filesDir + '/' + fileName;
      failure = BackgroundImportFailure.SANDBOX_WRITE_FAILED;
      targetFile = fileIo.openSync(targetPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);

      const firstWriteLength = await fileIo.write(targetFile.fd,
        firstReadLength === firstChunkSize ? firstBuffer : firstBuffer.slice(0, firstReadLength));
      if (firstWriteLength !== firstReadLength) {
        return new BackgroundImportResult(false, '', BackgroundImportFailure.SANDBOX_WRITE_FAILED);
      }

      let copied = firstReadLength;
      failure = BackgroundImportFailure.SOURCE_UNREADABLE;
      while (copied < stat.size) {
        const nextSize = Math.min(BackgroundImporter.CHUNK_SIZE, stat.size - copied);
        const nextBuffer = new ArrayBuffer(nextSize);
        const readLength = await fileIo.read(sourceFile.fd, nextBuffer);
        if (readLength <= 0) return new BackgroundImportResult(false, '', BackgroundImportFailure.SOURCE_UNREADABLE);
        failure = BackgroundImportFailure.SANDBOX_WRITE_FAILED;
        const writeLength = await fileIo.write(targetFile.fd,
          readLength === nextSize ? nextBuffer : nextBuffer.slice(0, readLength));
        if (writeLength !== readLength) {
          return new BackgroundImportResult(false, '', BackgroundImportFailure.SANDBOX_WRITE_FAILED);
        }
        copied += readLength;
        failure = BackgroundImportFailure.SOURCE_UNREADABLE;
      }
      if (copied !== stat.size) return new BackgroundImportResult(false, '', BackgroundImportFailure.SOURCE_UNREADABLE);
      completed = true;
      return new BackgroundImportResult(true, targetPath, null);
    } catch (e) {
      return new BackgroundImportResult(false, '', failure);
    } finally {
      BackgroundImporter.closeFile(targetFile);
      BackgroundImporter.closeFile(sourceFile);
      if (targetPath.length > 0 && !completed) BackgroundImporter.removeSandboxFile(targetPath);
    }
  }

  static removeSandboxFile(path: string): void {
    if (path.length === 0) return;
    try { fileIo.unlinkSync(path); } catch (e) {}
  }

  private static closeFile(file: fileIo.File | null): void {
    if (file === null) return;
    try { fileIo.closeSync(file); } catch (e) {}
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

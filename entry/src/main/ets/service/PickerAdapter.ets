import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const USER_CANCELLED_CODE: number = 13900012;

export enum ImagePickState {
  SELECTED = 'SELECTED',
  CANCELLED = 'CANCELLED',
  FAILED = 'FAILED'
}

export class ImagePickResult {
  state: ImagePickState;
  uri: string;

  constructor(state: ImagePickState, uri: string) {
    this.state = state;
    this.uri = uri;
  }
}

export class PickerAdapter {
  static async pickSingleImage(): Promise<ImagePickResult> {
    const photoPicker = new picker.PhotoViewPicker();
    const options: picker.PhotoSelectOptions = {
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    };
    try {
      const selected = await photoPicker.select(options);
      if (selected.photoUris === undefined || selected.photoUris.length === 0) {
        return new ImagePickResult(ImagePickState.CANCELLED, '');
      }
      const uri = selected.photoUris[0].trim();
      if (uri.length === 0) {
        return new ImagePickResult(ImagePickState.FAILED, '');
      }
      return new ImagePickResult(ImagePickState.SELECTED, uri);
    } catch (e) {
      const error = e as BusinessError;
      if (error.code === USER_CANCELLED_CODE) {
        return new ImagePickResult(ImagePickState.CANCELLED, '');
      }
      return new ImagePickResult(ImagePickState.FAILED, '');
    }
  }
}

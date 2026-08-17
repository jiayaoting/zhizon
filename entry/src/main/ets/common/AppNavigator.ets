// 智子 - 全局导航封装（当前使用 router 页面路由）
import { router } from '@kit.ArkUI';

export class AppNavigator {
  static push(name: string, param?: Object): void {
    if (param !== undefined) {
      router.pushUrl({ url: name, params: param });
    } else {
      router.pushUrl({ url: name });
    }
  }

  static replace(name: string, param?: Object): void {
    if (param !== undefined) {
      router.replaceUrl({ url: name, params: param });
    } else {
      router.replaceUrl({ url: name });
    }
  }

  static pop(): void {
    router.back();
  }

  static getParam(name: string): Object | null {
    const param: Object = router.getParams() as Object;
    return param === undefined ? null : param;
  }
}

// 智子 - NewsNow 后端客户端
// 设计文档：doc/newsnow-redesign.md §5
// 三个公开接口：/api/latest（探测）、/api/s（单源榜单）、/api/s/entire（批量缓存）
// 两个同步接口：/api/me/sync（GET 拉取 / POST 上传，需 JWT）
import { http } from '@kit.NetworkKit';
import { DataRepository } from '../platform/DataRepository';
import { NewsNowAuth } from './NewsNowAuth';
import { HotBoardData, HotItem, HotNowError, FocusMetadata } from '../../common/HotModels';
import { HotSources } from '../../common/HotSources';

// 服务器地址配置键
const KEY_SERVER_URL = 'hot_server_url';
// 默认公共实例（可切换自部署）
export const DEFAULT_SERVER_URL = 'https://newsnow.busiyi.world';

const CONNECT_TIMEOUT = 8000;
const READ_TIMEOUT = 8000;

// 与 NewsLogin 的 WebView 保持一致的浏览器标识（Cloudflare WAF 依赖 UA 判定）
export const NEWSNOW_UA = 'Mozilla/5.0 (Linux; Android 12; HarmonyOS) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

// 单源榜单结果
export class HotBoardResult {
  ok: boolean;
  sourceId: string;
  data: HotBoardData | null;
  error: HotNowError | null;

  constructor(ok: boolean, sourceId: string, data: HotBoardData | null, error: HotNowError | null) {
    this.ok = ok;
    this.sourceId = sourceId;
    this.data = data;
    this.error = error;
  }

  static success(sourceId: string, data: HotBoardData): HotBoardResult {
    return new HotBoardResult(true, sourceId, data, null);
  }

  static failure(sourceId: string, error: HotNowError): HotBoardResult {
    return new HotBoardResult(false, sourceId, null, error);
  }
}

// 批量取榜结果
export class HotBoardsResult {
  ok: boolean;
  boards: HotBoardResult[];
  error: HotNowError | null;

  constructor(ok: boolean, boards: HotBoardResult[], error: HotNowError | null) {
    this.ok = ok;
    this.boards = boards;
    this.error = error;
  }
}

// 连通性探测结果
export class HotPingResult {
  ok: boolean;
  version: string;
  error: HotNowError | null;

  constructor(ok: boolean, version: string, error: HotNowError | null) {
    this.ok = ok;
    this.version = version;
    this.error = error;
  }
}

// 同步拉取结果
export class HotMetaResult {
  ok: boolean;
  meta: FocusMetadata | null;
  error: HotNowError | null;

  constructor(ok: boolean, meta: FocusMetadata | null, error: HotNowError | null) {
    this.ok = ok;
    this.meta = meta;
    this.error = error;
  }
}

export class NewsNowClient {
  // ==================== 服务器配置 ====================

  static async getBaseUrl(): Promise<string> {
    const raw: string = await DataRepository.getSetting(KEY_SERVER_URL, DEFAULT_SERVER_URL);
    return NewsNowClient.normalizeUrl(raw);
  }

  static async setBaseUrl(url: string): Promise<void> {
    await DataRepository.setSetting(KEY_SERVER_URL, NewsNowClient.normalizeUrl(url));
  }

  // 去掉尾部斜杠；空值回落到默认
  static normalizeUrl(url: string): string {
    let u: string = url === undefined || url === null ? '' : url.trim();
    if (u.length === 0) return DEFAULT_SERVER_URL;
    while (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  // 地址格式校验：必须是 http(s)://host[:port][/path]
  static isValidUrl(url: string): boolean {
    const u: string = url.trim();
    if (!u.startsWith('https://') && !u.startsWith('http://')) return false;
    const rest: string = u.startsWith('https://') ? u.substring(8) : u.substring(7);
    if (rest.length === 0) return false;
    return rest.indexOf(' ') < 0;
  }

  // ==================== 连通性探测 ====================

  static async ping(): Promise<HotPingResult> {
    const base: string = await NewsNowClient.getBaseUrl();
    const res: http.HttpResponse | null = await NewsNowClient.doGet(base, '/api/latest');
    if (res === null) {
      return new HotPingResult(false, '', new HotNowError('network', 0, '网络不可达或地址错误'));
    }
    if (res.responseCode !== 200) {
      return new HotPingResult(false, '',
        NewsNowClient.httpErrorWithBody(res.responseCode, res.result));
    }
    const obj: Record<string, Object> | null = NewsNowClient.parseObject(res.result);
    if (obj === null) {
      return new HotPingResult(false, '', new HotNowError('server', 200, '响应格式异常'));
    }
    const v: Object = obj['v'];
    const version: string = v === undefined || v === null ? '' : v.toString();
    return new HotPingResult(true, version, null);
  }

  // ==================== 榜单 ====================

  // 单源榜单；latest = true 时请求服务端强制抓取（需登录，未登录服务端会返回缓存）
  static async fetchBoard(sourceId: string, latest: boolean): Promise<HotBoardResult> {
    const base: string = await NewsNowClient.getBaseUrl();
    const path: string = '/api/s?id=' + encodeURIComponent(sourceId) + (latest ? '&latest=true' : '');
    const res: http.HttpResponse | null = await NewsNowClient.doGet(base, path);
    if (res === null) {
      return HotBoardResult.failure(sourceId, new HotNowError('network', 0, '网络不可达'));
    }
    if (res.responseCode !== 200) {
      return HotBoardResult.failure(sourceId, NewsNowClient.httpErrorWithBody(res.responseCode, res.result));
    }
    const obj: Record<string, Object> | null = NewsNowClient.parseObject(res.result);
    if (obj === null) {
      return HotBoardResult.failure(sourceId, new HotNowError('server', 200, '响应格式异常'));
    }
    const data: HotBoardData = NewsNowClient.toBoardData(sourceId, obj);
    return HotBoardResult.success(sourceId, data);
  }

  // 批量取缓存（毫秒级，不触发源站抓取）；entire 不可用时逐源降级
  static async fetchBoards(sourceIds: string[]): Promise<HotBoardsResult> {
    if (sourceIds.length === 0) return new HotBoardsResult(true, [], null);
    const base: string = await NewsNowClient.getBaseUrl();
    const payload: Record<string, Object> = {};
    payload['sources'] = sourceIds;
    const res: http.HttpResponse | null =
      await NewsNowClient.doPost(base, '/api/s/entire', JSON.stringify(payload));
    const boards: HotBoardResult[] = [];
    let entireOk: boolean = false;
    if (res !== null && res.responseCode === 200) {
      const arr: Object[] | null = NewsNowClient.parseArray(res.result);
      if (arr !== null) {
        entireOk = true;
        for (let i: number = 0; i < arr.length; i++) {
          const obj: Record<string, Object> = arr[i] as Record<string, Object>;
          const idObj: Object = obj['id'];
          const id: string = idObj === undefined || idObj === null ? '' : idObj.toString();
          if (id.length === 0) continue;
          boards.push(HotBoardResult.success(id, NewsNowClient.toBoardData(id, obj)));
        }
      }
    }
    if (entireOk) return new HotBoardsResult(true, boards, null);

    // 降级：逐源单独取缓存
    const fallback: HotBoardResult[] = [];
    const tasks: Promise<HotBoardResult>[] = [];
    for (let i: number = 0; i < sourceIds.length; i++) {
      tasks.push(NewsNowClient.fetchBoard(sourceIds[i], false));
    }
    for (let i: number = 0; i < tasks.length; i++) {
      fallback.push(await tasks[i]);
    }
    let anyOk: boolean = false;
    for (let i: number = 0; i < fallback.length; i++) {
      if (fallback[i].ok) anyOk = true;
    }
    const err: HotNowError | null = anyOk ? null : new HotNowError('network', 0, '无法连接热榜服务器');
    return new HotBoardsResult(anyOk, fallback, err);
  }

  // ==================== 同步（需登录） ====================

  // 拉取云端 metadata；未登录返回 ok=false 且 error.code='unauthorized'
  static async pullMetadata(): Promise<HotMetaResult> {
    const jwt: string = await NewsNowAuth.getToken();
    if (jwt.length === 0) {
      return new HotMetaResult(false, null, new HotNowError('unauthorized', 401, '未登录'));
    }
    const base: string = await NewsNowClient.getBaseUrl();
    const res: http.HttpResponse | null =
      await NewsNowClient.doGet(base, '/api/me/sync', jwt);
    if (res === null) {
      return new HotMetaResult(false, null, new HotNowError('network', 0, '网络不可达'));
    }
    if (res.responseCode === 401) {
      return new HotMetaResult(false, null, new HotNowError('unauthorized', 401, '登录已过期'));
    }
    if (res.responseCode === 506) {
      return new HotMetaResult(false, null, new HotNowError('not_configured', 506, '该服务器未开启账号功能'));
    }
    if (res.responseCode !== 200) {
      return new HotMetaResult(false, null,
        NewsNowClient.httpErrorWithBody(res.responseCode, res.result));
    }
    const obj: Record<string, Object> | null = NewsNowClient.parseObject(res.result);
    if (obj === null) {
      return new HotMetaResult(true, null, null);
    }
    const dataObj: Object = obj['data'];
    if (dataObj === undefined || dataObj === null) {
      return new HotMetaResult(true, null, null);
    }
    const data: Record<string, Object> = dataObj as Record<string, Object>;
    const focus: string[] = NewsNowClient.toStringArray(data['focus']);
    const updatedObj: Object = obj['updatedTime'];
    const updated: number = updatedObj === undefined || updatedObj === null
      ? 0 : NewsNowClient.toNumber(updatedObj);
    return new HotMetaResult(true, new FocusMetadata(focus, updated), null);
  }

  // 上传 focus（其余三列按源目录补全，保持与网页版读取兼容）
  static async pushMetadata(meta: FocusMetadata): Promise<HotNowError | null> {
    const jwt: string = await NewsNowAuth.getToken();
    if (jwt.length === 0) {
      return new HotNowError('unauthorized', 401, '未登录');
    }
    const base: string = await NewsNowClient.getBaseUrl();
    const data: Record<string, Object> = {};
    data['focus'] = meta.focusSources;
    data['hottest'] = HotSources.hottestIds();
    data['realtime'] = HotSources.realtimeIds();
    data['updated'] = HotSources.updatedIds();
    const body: Record<string, Object> = {};
    body['data'] = data;
    body['updatedTime'] = meta.updatedTime;
    const res: http.HttpResponse | null =
      await NewsNowClient.doPost(base, '/api/me/sync', JSON.stringify(body), jwt);
    if (res === null) return new HotNowError('network', 0, '网络不可达');
    if (res.responseCode === 401) return new HotNowError('unauthorized', 401, '登录已过期');
    if (res.responseCode === 506) return new HotNowError('not_configured', 506, '该服务器未开启账号功能');
    if (res.responseCode !== 200) {
      return NewsNowClient.httpError(res.responseCode);
    }
    return null;
  }

  // ==================== 内部：HTTP ====================

  // HTTP 状态码 → 错误（403 特指 Cloudflare WAF 拦截，给出可操作建议）
  private static httpError(code: number): HotNowError {
    if (code === 403) {
      return new HotNowError('forbidden', 403,
        '403：被 Cloudflare 拦截。可先在「账号」用 GitHub 登录一次（内嵌浏览器会带浏览器标识访问），或改用自部署实例');
    }
    if (code === 404) {
      return new HotNowError('http', 404, '404：接口不存在，请确认服务器地址是否正确');
    }
    if (code === 506) {
      return new HotNowError('not_configured', 506, '该服务器未开启账号功能');
    }
    return new HotNowError('http', code, 'HTTP ' + code.toString());
  }

  // 带响应体的错误：优先透出服务端 message（如 D1 过载 / 源站抓取失败），便于判断是服务端问题而非 App 问题
  private static httpErrorWithBody(code: number, result: string | Object | ArrayBuffer): HotNowError {
    const fallback: HotNowError = NewsNowClient.httpError(code);
    const obj: Record<string, Object> | null = NewsNowClient.parseObject(result);
    if (obj === null) return fallback;
    const msg: Object = obj['message'];
    if (msg === undefined || msg === null) return fallback;
    let text: string = msg.toString().trim();
    if (text.length === 0) return fallback;
    if (text.length > 140) text = text.substring(0, 140) + '…';
    return new HotNowError(fallback.code, code, 'HTTP ' + code.toString() + '：' + text);
  }

  // 公共实例多在 Cloudflare 之后，缺少浏览器标识的请求会被 WAF 直接 403（实测：仅带 Accept 必 403，
  // 补齐 UA/Accept/Accept-Language/Referer 后 200）。因此所有请求统一携带浏览器化请求头。
  private static browserHeaders(base: string, jwt: string, json: boolean): Record<string, string> {
    const header: Record<string, string> = {
      'User-Agent': NEWSNOW_UA,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Referer': base + '/',
      'Origin': base,
      'Connection': 'close'
    };
    if (json) header['Content-Type'] = 'application/json';
    if (jwt.length > 0) header['Authorization'] = 'Bearer ' + jwt;
    return header;
  }

  private static async doGet(base: string, path: string, jwt: string = ''): Promise<http.HttpResponse | null> {
    const req: http.HttpRequest = http.createHttp();
    try {
      return await req.request(base + path, {
        method: http.RequestMethod.GET,
        header: NewsNowClient.browserHeaders(base, jwt, false),
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      });
    } catch (e) {
      return null;
    } finally {
      req.destroy();
    }
  }

  private static async doPost(base: string, path: string, body: string,
    jwt: string = ''): Promise<http.HttpResponse | null> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = NewsNowClient.browserHeaders(base, jwt, true);
      return await req.request(base + path, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: body,
        connectTimeout: CONNECT_TIMEOUT,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      });
    } catch (e) {
      return null;
    } finally {
      req.destroy();
    }
  }

  // ==================== 内部：解析 ====================

  private static resultToString(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') return result as string;
    if (result === undefined || result === null) return '';
    return JSON.stringify(result);
  }

  private static parseObject(result: string | Object | ArrayBuffer): Record<string, Object> | null {
    try {
      const text: string = NewsNowClient.resultToString(result);
      if (text.length === 0) return null;
      return JSON.parse(text) as Record<string, Object>;
    } catch (e) {
      return null;
    }
  }

  private static parseArray(result: string | Object | ArrayBuffer): Object[] | null {
    try {
      const text: string = NewsNowClient.resultToString(result);
      if (text.length === 0) return null;
      const parsed: Object = JSON.parse(text) as Object;
      if (parsed === null || parsed === undefined || !Array.isArray(parsed)) return null;
      return parsed as Object[];
    } catch (e) {
      return null;
    }
  }

  private static toNumber(v: Object): number {
    if (typeof v === 'number') return v as number;
    if (typeof v === 'string') {
      const n: number = Number(v as string);
      return isNaN(n) ? 0 : n;
    }
    return 0;
  }

  private static toStringArray(v: Object): string[] {
    const out: string[] = [];
    if (v === undefined || v === null || !Array.isArray(v)) return out;
    const arr: Object[] = v as Object[];
    for (let i: number = 0; i < arr.length; i++) {
      if (typeof arr[i] === 'string') out.push(arr[i] as string);
    }
    return out;
  }

  // SourceResponse → HotBoardData
  private static toBoardData(sourceId: string, obj: Record<string, Object>): HotBoardData {
    const statusObj: Object = obj['status'];
    const status: string = statusObj === undefined || statusObj === null ? '' : statusObj.toString();
    const updatedObj: Object = obj['updatedTime'];
    const updated: number = updatedObj === undefined || updatedObj === null
      ? 0 : NewsNowClient.toNumber(updatedObj);
    const items: HotItem[] = [];
    const rawItems: Object = obj['items'];
    if (rawItems !== undefined && rawItems !== null && Array.isArray(rawItems)) {
      const arr: Object[] = rawItems as Object[];
      for (let i: number = 0; i < arr.length; i++) {
        const it: HotItem | null = NewsNowClient.toHotItem(arr[i] as Record<string, Object>);
        if (it !== null) items.push(it);
      }
    }
    return new HotBoardData(sourceId, status === 'cache', updated, items);
  }

  // NewsItem → HotItem
  private static toHotItem(obj: Record<string, Object>): HotItem | null {
    if (obj === undefined || obj === null) return null;
    const idObj: Object = obj['id'];
    const id: string = idObj === undefined || idObj === null ? '' : idObj.toString();
    const titleObj: Object = obj['title'];
    const title: string = titleObj === undefined || titleObj === null ? '' : titleObj.toString();
    const urlObj: Object = obj['url'];
    const url: string = urlObj === undefined || urlObj === null ? '' : urlObj.toString();
    if (title.length === 0) return null;

    const mobileObj: Object = obj['mobileUrl'];
    const mobileUrl: string = mobileObj === undefined || mobileObj === null ? url : mobileObj.toString();

    // extra：info（热度描述）+ date（部分源用 extra.date 给时间）
    let info: string = '';
    let extraDate: number = 0;
    const extraObj: Object = obj['extra'];
    if (extraObj !== undefined && extraObj !== null && typeof extraObj === 'object' && !Array.isArray(extraObj)) {
      const extra: Record<string, Object> = extraObj as Record<string, Object>;
      const infoObj: Object = extra['info'];
      if (infoObj !== undefined && infoObj !== null && typeof infoObj !== 'boolean') {
        info = infoObj.toString();
      }
      const dateObj: Object = extra['date'];
      if (dateObj !== undefined && dateObj !== null) {
        extraDate = NewsNowClient.toNumber(dateObj);
      }
    }

    let pubDate: number = extraDate;
    if (pubDate === 0) {
      const pubObj: Object = obj['pubDate'];
      if (pubObj !== undefined && pubObj !== null) {
        pubDate = NewsNowClient.toNumber(pubObj);
        // 秒级时间戳归一化为毫秒（源多为秒）
        if (pubDate > 0 && pubDate < 100000000000) pubDate = pubDate * 1000;
      }
    }
    const key: string = id.length > 0 ? id : url;
    return new HotItem(key, title, url, mobileUrl, pubDate, info);
  }
}

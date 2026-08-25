// 智子 - BettaFish（微舆）HTTP 客户端
// 直连自部署 BettaFish Flask 主端口（默认 5000），对接 REST 接口
// 网络经验沿用 LlmClient：HTTP/1.1 + usingCache=false，规避 netstack 连接复用缺陷
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BettaServerConfig, BettaSystemStatus, BettaApiResult, BettaEngineStatus,
  BettaReportStatus, BettaSearchResult, BettaGenerateResult, BettaReportTask,
  BettaForumMessage, BettaForumHistoryResult, BettaSystemActionResult } from '../common/BettaFishModels';

const BETTA_DOMAIN = 0x9202;
const READ_TIMEOUT = 30000;

export class BettaFishApiClient {
  // 组装 baseUrl：scheme://host:port + basePath
  static buildBaseUrl(server: BettaServerConfig): string {
    let host = server.host.trim();
    if (host.length === 0) return '';
    let basePath = server.basePath.trim();
    if (basePath.length > 0 && !basePath.startsWith('/')) {
      basePath = '/' + basePath;
    }
    if (basePath.length > 1 && basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    const scheme: string = server.scheme === 'https' ? 'https' : 'http';
    return scheme + '://' + host + ':' + server.port.toString() + basePath;
  }

  // ========== 系统 ==========

  // GET /api/system/status：系统启动状态（连接测试）
  static async systemStatus(server: BettaServerConfig): Promise<BettaApiResult<BettaSystemStatus>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.GET, '/api/system/status');
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaSystemStatus>(result.code, result.message);
    }
    const status = new BettaSystemStatus();
    status.started = result.data.started === true;
    status.starting = result.data.starting === true;
    return new BettaApiResult<BettaSystemStatus>(true, status, '', '');
  }

  // POST /api/system/start
  static async systemStart(server: BettaServerConfig): Promise<BettaApiResult<BettaSystemActionResult>> {
    return BettaFishApiClient.systemAction(server, '/api/system/start');
  }

  // POST /api/system/shutdown
  static async systemShutdown(server: BettaServerConfig): Promise<BettaApiResult<BettaSystemActionResult>> {
    return BettaFishApiClient.systemAction(server, '/api/system/shutdown');
  }

  private static async systemAction(server: BettaServerConfig, path: string): Promise<BettaApiResult<BettaSystemActionResult>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.POST, path);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaSystemActionResult>(result.code, result.message);
    }
    const action = new BettaSystemActionResult();
    action.success = result.data.success === true;
    action.message = BettaFishApiClient.strField(result.data, 'message');
    action.logs = BettaFishApiClient.strField(result.data, 'logs');
    return new BettaApiResult<BettaSystemActionResult>(true, action, '', '');
  }

  // GET /api/status：四引擎状态
  static async engineStatus(server: BettaServerConfig): Promise<BettaApiResult<BettaEngineStatus[]>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.GET, '/api/status');
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaEngineStatus[]>(result.code, result.message);
    }
    const list: BettaEngineStatus[] = [];
    const names: string[] = ['insight', 'media', 'query', 'forum'];
    for (let i: number = 0; i < names.length; i++) {
      const appName = names[i];
      const raw: Object = result.data[appName];
      if (raw === undefined || raw === null) continue;
      const obj = raw as Record<string, Object>;
      const engine = new BettaEngineStatus();
      engine.appName = appName;
      engine.status = BettaFishApiClient.strField(obj, 'status');
      if (engine.status.length === 0) engine.status = 'stopped';
      const port = obj.port;
      engine.port = typeof port === 'number' ? port : 0;
      const lines = obj.output_lines;
      engine.outputLines = typeof lines === 'number' ? lines : 0;
      list.push(engine);
    }
    return new BettaApiResult<BettaEngineStatus[]>(true, list, '', '');
  }

  // GET /api/output/<app>：引擎输出日志
  static async engineOutput(server: BettaServerConfig, appName: string): Promise<BettaApiResult<string>> {
    return BettaFishApiClient.requestText(server, http.RequestMethod.GET, '/api/output/' + appName);
  }

  // ========== 分析 ==========

  // POST /api/search {query}
  static async submitSearch(server: BettaServerConfig, query: string): Promise<BettaApiResult<BettaSearchResult>> {
    const body: Record<string, Object> = { 'query': query };
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.POST, '/api/search', body);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaSearchResult>(result.code, result.message);
    }
    const search = new BettaSearchResult();
    search.success = result.data.success === true;
    search.query = BettaFishApiClient.strField(result.data, 'query');
    const results = result.data.results;
    search.results = results === undefined || results === null ? '' : JSON.stringify(results);
    return new BettaApiResult<BettaSearchResult>(true, search, '', '');
  }

  // ========== 论坛 ==========

  // GET /api/forum/log：全量消息
  static async forumLogAll(server: BettaServerConfig): Promise<BettaApiResult<BettaForumMessage[]>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.GET, '/api/forum/log');
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaForumMessage[]>(result.code, result.message);
    }
    const list: BettaForumMessage[] = [];
    const rawList = result.data.parsed_messages;
    if (rawList !== undefined && Array.isArray(rawList)) {
      const items = rawList as Object[];
      for (let i: number = 0; i < items.length; i++) {
        const obj = items[i] as Record<string, Object>;
        const msg = new BettaForumMessage();
        msg.type = BettaFishApiClient.strField(obj, 'type');
        msg.sender = BettaFishApiClient.strField(obj, 'sender');
        msg.content = BettaFishApiClient.strField(obj, 'content');
        msg.timestamp = BettaFishApiClient.strField(obj, 'timestamp');
        msg.source = BettaFishApiClient.strField(obj, 'source');
        list.push(msg);
      }
    }
    return new BettaApiResult<BettaForumMessage[]>(true, list, '', '');
  }

  // POST /api/forum/log/history {position, max_lines}
  static async forumLogHistory(server: BettaServerConfig, position: number,
    maxLines: number): Promise<BettaApiResult<BettaForumHistoryResult>> {
    const body: Record<string, Object> = { 'position': position, 'max_lines': maxLines };
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.POST, '/api/forum/log/history', body);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaForumHistoryResult>(result.code, result.message);
    }
    const history = new BettaForumHistoryResult();
    const lines = result.data.log_lines;
    if (lines !== undefined && Array.isArray(lines)) {
      const items = lines as Object[];
      history.logLines = items.map((v: Object): string => String(v));
    }
    const pos = result.data.position;
    history.position = typeof pos === 'number' ? pos : 0;
    history.hasMore = result.data.has_more === true;
    return new BettaApiResult<BettaForumHistoryResult>(true, history, '', '');
  }

  // ========== 报告 ==========

  // GET /api/report/status
  static async reportStatus(server: BettaServerConfig): Promise<BettaApiResult<BettaReportStatus>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.GET, '/api/report/status');
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaReportStatus>(result.code, result.message);
    }
    const status = new BettaReportStatus();
    status.initialized = result.data.initialized === true;
    status.enginesReady = result.data.engines_ready === true;
    status.currentTask = BettaFishApiClient.strField(result.data, 'current_task');
    const files = result.data.files_found;
    if (files !== undefined && Array.isArray(files)) {
      status.filesFound = (files as Object[]).map((v: Object): string => String(v));
    }
    const missing = result.data.missing_files;
    if (missing !== undefined && Array.isArray(missing)) {
      status.missingFiles = (missing as Object[]).map((v: Object): string => String(v));
    }
    return new BettaApiResult<BettaReportStatus>(true, status, '', '');
  }

  // POST /api/report/generate {query, custom_template}
  static async reportGenerate(server: BettaServerConfig, query: string): Promise<BettaApiResult<BettaGenerateResult>> {
    const body: Record<string, Object> = { 'query': query };
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.POST, '/api/report/generate', body);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaGenerateResult>(result.code, result.message);
    }
    const generate = new BettaGenerateResult();
    generate.taskId = BettaFishApiClient.strField(result.data, 'task_id');
    generate.streamUrl = BettaFishApiClient.strField(result.data, 'stream_url');
    const task = result.data.task;
    if (task !== undefined && task !== null) {
      generate.task = BettaFishApiClient.taskFromObject(task as Record<string, Object>);
    }
    return new BettaApiResult<BettaGenerateResult>(true, generate, '', '');
  }

  // GET /api/report/progress/<task_id>
  static async reportProgress(server: BettaServerConfig, taskId: string): Promise<BettaApiResult<BettaReportTask>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.GET,
      '/api/report/progress/' + taskId);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<BettaReportTask>(result.code, result.message);
    }
    const task = result.data.task;
    if (task === undefined || task === null) {
      return new BettaApiResult<BettaReportTask>(false, null, 'NO_TASK', '未找到任务');
    }
    return new BettaApiResult<BettaReportTask>(true, BettaFishApiClient.taskFromObject(task as Record<string, Object>), '', '');
  }

  // POST /api/report/cancel/<task_id>
  static async reportCancel(server: BettaServerConfig, taskId: string): Promise<BettaApiResult<string>> {
    const result = await BettaFishApiClient.requestJsonObject(server, http.RequestMethod.POST,
      '/api/report/cancel/' + taskId);
    if (!result.ok || result.data === null) {
      return BettaFishApiClient.fail<string>(result.code, result.message);
    }
    return new BettaApiResult<string>(true, BettaFishApiClient.strField(result.data, 'message'), '', '');
  }

  // GET /api/report/log：报告引擎日志
  static async reportLog(server: BettaServerConfig): Promise<BettaApiResult<string>> {
    return BettaFishApiClient.requestText(server, http.RequestMethod.GET, '/api/report/log');
  }

  // ========== 下载导出 ==========

  // GET /api/report/download/<task_id> → 本地文件
  static async reportDownload(server: BettaServerConfig, taskId: string, localPath: string): Promise<BettaApiResult<string>> {
    return BettaFishApiClient.downloadLocal(server, '/api/report/download/' + taskId, localPath);
  }

  static async reportExportMd(server: BettaServerConfig, taskId: string, localPath: string): Promise<BettaApiResult<string>> {
    return BettaFishApiClient.downloadLocal(server, '/api/report/export/md/' + taskId, localPath);
  }

  static async reportExportPdf(server: BettaServerConfig, taskId: string, localPath: string): Promise<BettaApiResult<string>> {
    return BettaFishApiClient.downloadLocal(server, '/api/report/export/pdf/' + taskId, localPath);
  }

  // 通用下载：远端路径 → 本地文件
  static async downloadLocal(server: BettaServerConfig, path: string, localPath: string): Promise<BettaApiResult<string>> {
    const baseUrl = BettaFishApiClient.buildBaseUrl(server);
    if (baseUrl.length === 0) {
      return new BettaApiResult<string>(false, null, 'INVALID_CONFIG', '请先填写服务器地址');
    }
    const url = baseUrl + path;
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: (server.timeoutSec > 0 ? server.timeoutSec : 10) * 1000,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      };
      const response = await httpRequest.request(url, options);
      if (response.responseCode !== 200) {
        return new BettaApiResult<string>(false, null, 'HTTP_' + response.responseCode.toString(),
          '下载失败：服务端返回 ' + response.responseCode.toString());
      }
      const buffer = response.result as ArrayBuffer;
      const file = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, buffer);
      fs.closeSync(file);
      return new BettaApiResult<string>(true, localPath, '', '');
    } catch (e) {
      const err = e as BusinessError;
      return new BettaApiResult<string>(false, null, 'DOWNLOAD_FAILED',
        err.message !== undefined ? String(err.message) : '下载失败');
    } finally {
      httpRequest.destroy();
    }
  }

  // ========== 基础请求 ==========

  // 通用 JSON 请求：返回解析后的对象（顶层 success 校验）
  static async requestJsonObject(server: BettaServerConfig, method: http.RequestMethod, path: string,
    body?: Record<string, Object>): Promise<BettaApiResult<Record<string, Object>>> {
    const baseUrl = BettaFishApiClient.buildBaseUrl(server);
    if (baseUrl.length === 0) {
      return new BettaApiResult<Record<string, Object>>(false, null, 'INVALID_CONFIG', '请先填写服务器地址');
    }
    const url = baseUrl + path;
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Connection': 'close'
      };
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: (server.timeoutSec > 0 ? server.timeoutSec : 10) * 1000,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      };
      if (body !== undefined) {
        options.extraData = JSON.stringify(body);
      }
      const response = await httpRequest.request(url, options);
      const code: number = response.responseCode;
      if (code !== 200) {
        const text: string = BettaFishApiClient.resultToString(response.result);
        let message: string = '服务端返回 ' + code.toString();
        try {
          const parsed = JSON.parse(text) as Record<string, Object>;
          const msg = parsed.message;
          if (msg !== undefined && msg !== null) {
            message = String(msg);
          }
        } catch (e) {
        }
        return new BettaApiResult<Record<string, Object>>(false, null, 'HTTP_' + code.toString(), message);
      }
      const text: string = BettaFishApiClient.resultToString(response.result);
      if (text.trim().length === 0) {
        return new BettaApiResult<Record<string, Object>>(false, null, 'EMPTY_RESPONSE', '服务端返回空响应');
      }
      let parsed: Record<string, Object>;
      try {
        parsed = JSON.parse(text) as Record<string, Object>;
      } catch (e) {
        return new BettaApiResult<Record<string, Object>>(false, null, 'NOT_BETTAFISH', '响应不是 BettaFish JSON 格式');
      }
      const success: boolean = parsed.success === undefined || parsed.success === true;
      if (!success) {
        const message: string = parsed.message !== undefined ? String(parsed.message) : '服务端处理失败';
        return new BettaApiResult<Record<string, Object>>(false, null, 'SERVER_ERROR', message);
      }
      return new BettaApiResult<Record<string, Object>>(true, parsed, '', '');
    } catch (e) {
      const err = e as BusinessError;
      const code: string = typeof err.code === 'number' ? 'NET_' + err.code.toString() : 'NETWORK_ERROR';
      const message: string = err.message !== undefined ? String(err.message) : '网络请求失败';
      return new BettaApiResult<Record<string, Object>>(false, null, code, message);
    } finally {
      httpRequest.destroy();
    }
  }

  // 文本响应请求（日志等）
  static async requestText(server: BettaServerConfig, method: http.RequestMethod, path: string): Promise<BettaApiResult<string>> {
    const baseUrl = BettaFishApiClient.buildBaseUrl(server);
    if (baseUrl.length === 0) {
      return new BettaApiResult<string>(false, null, 'INVALID_CONFIG', '请先填写服务器地址');
    }
    const url = baseUrl + path;
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        connectTimeout: (server.timeoutSec > 0 ? server.timeoutSec : 10) * 1000,
        readTimeout: READ_TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        usingCache: false
      };
      const response = await httpRequest.request(url, options);
      if (response.responseCode !== 200) {
        return new BettaApiResult<string>(false, null, 'HTTP_' + response.responseCode.toString(),
          '服务端返回 ' + response.responseCode.toString());
      }
      return new BettaApiResult<string>(true, BettaFishApiClient.resultToString(response.result), '', '');
    } catch (e) {
      const err = e as BusinessError;
      return new BettaApiResult<string>(false, null, 'NETWORK_ERROR',
        err.message !== undefined ? String(err.message) : '网络请求失败');
    } finally {
      httpRequest.destroy();
    }
  }

  // ========== 解析工具 ==========

  static taskFromObject(obj: Record<string, Object>): BettaReportTask {
    const task = new BettaReportTask();
    task.taskId = BettaFishApiClient.strField(obj, 'task_id');
    task.query = BettaFishApiClient.strField(obj, 'query');
    task.status = BettaFishApiClient.strField(obj, 'status');
    task.errorMessage = BettaFishApiClient.strField(obj, 'error_message');
    task.createdAt = BettaFishApiClient.strField(obj, 'created_at');
    task.updatedAt = BettaFishApiClient.strField(obj, 'updated_at');
    const progress = obj.progress;
    task.progress = typeof progress === 'number' ? progress : 0;
    task.hasResult = obj.has_result === true;
    task.reportFileReady = obj.report_file_ready === true;
    task.reportFileName = BettaFishApiClient.strField(obj, 'report_file_name');
    task.reportFilePath = BettaFishApiClient.strField(obj, 'report_file_path');
    task.markdownFileReady = obj.markdown_file_ready === true;
    task.markdownFileName = BettaFishApiClient.strField(obj, 'markdown_file_name');
    task.markdownFilePath = BettaFishApiClient.strField(obj, 'markdown_file_path');
    return task;
  }

  static strField(obj: Record<string, Object>, key: string): string {
    const value = obj[key];
    if (value === undefined || value === null) return '';
    return String(value);
  }

  // 构造失败结果（避免不同泛型之间的强转）
  static fail<T>(code: string, message: string): BettaApiResult<T> {
    return new BettaApiResult<T>(false, null, code, message);
  }

  private static resultToString(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') return result;
    if (result instanceof ArrayBuffer) {
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(result));
    }
    return String(result);
  }

  static logWarn(message: string): void {
    hilog.warn(BETTA_DOMAIN, 'BettaFishApiClient', '%{public}s', message);
  }
}

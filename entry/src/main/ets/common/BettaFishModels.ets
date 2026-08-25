// 智子 - BettaFish（微舆）数据模型
// 与服务端接口契约对齐（见 doc/BettaFish_HarmonyOS_设计方案.md §5/§9）

// 服务器配置（可多套，保存至 RDB bettafish_servers）
export class BettaServerConfig {
  id: string = '';
  name: string = '默认服务器';
  scheme: string = 'http';          // 'http' | 'https'
  host: string = '';
  port: number = 5000;
  basePath: string = '';
  timeoutSec: number = 10;
  isCurrent: boolean = false;
  forumPosition: number = 0;        // 论坛增量轮询断点（按服务器保存）
}

// 系统状态（GET /api/system/status）
export class BettaSystemStatus {
  started: boolean = false;
  starting: boolean = false;

  constructor(started: boolean = false, starting: boolean = false) {
    this.started = started;
    this.starting = starting;
  }
}

// 引擎状态（GET /api/status 单项）
export class BettaEngineStatus {
  appName: string = '';             // insight | media | query | forum
  status: string = 'stopped';       // running | stopped | starting
  port: number = 0;
  outputLines: number = 0;
}

// 论坛消息（GET /api/forum/log → parsed_messages[]）
export class BettaForumMessage {
  type: string = 'agent';           // host | agent | raw
  sender: string = '';
  content: string = '';
  timestamp: string = '';
  source: string = '';              // HOST | QUERY | MEDIA | INSIGHT | RAW
}

// 报告任务（服务端 ReportTask.to_dict 同构）
export class BettaReportTask {
  taskId: string = '';
  query: string = '';
  status: string = 'pending';       // pending|running|completed|error|cancelled
  progress: number = 0;
  errorMessage: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  hasResult: boolean = false;
  reportFileReady: boolean = false;
  reportFileName: string = '';
  reportFilePath: string = '';
  markdownFileReady: boolean = false;
  markdownFileName: string = '';
  markdownFilePath: string = '';
}

// SSE 事件（服务端帧 data 同构；id 可能为 'hb-...'，统一字符串化存储）
export class BettaReportEvent {
  id: string = '';
  type: string = '';                // status|progress|stage|log|warning|heartbeat|completed|error|cancelled
  taskId: string = '';
  timestamp: string = '';
  payload: Record<string, Object> = {};   // 读取时需类型收窄
}

// 本地历史项（RDB bettafish_history）
export class BettaHistoryItem {
  taskId: string = '';
  query: string = '';
  status: string = '';
  progress: number = 0;
  baseUrl: string = '';
  serverId: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  savedAt: number = 0;
  localHtmlPath: string = '';
  localMdPath: string = '';
  localPdfPath: string = '';
}

// 报告引擎状态（GET /api/report/status）
export class BettaReportStatus {
  initialized: boolean = false;
  enginesReady: boolean = false;
  filesFound: string[] = [];
  missingFiles: string[] = [];
  currentTask: string = '';
}

// 论坛增量结果（POST /api/forum/log/history）
export class BettaForumHistoryResult {
  logLines: string[] = [];
  position: number = 0;
  hasMore: boolean = false;
}

// 发起分析结果（POST /api/search）
export class BettaSearchResult {
  success: boolean = false;
  query: string = '';
  results: string = '';
}

// 生成报告结果（POST /api/report/generate）
export class BettaGenerateResult {
  taskId: string = '';
  streamUrl: string = '';
  task: BettaReportTask | null = null;
}

// 系统操作结果（start / shutdown）
export class BettaSystemActionResult {
  success: boolean = false;
  message: string = '';
  logs: string = '';
}

// API 统一返回
export class BettaApiResult<T> {
  ok: boolean;
  data: T | null;
  code: string;        // 业务错误码（SERVER_UNREACHABLE / TIMEOUT / NOT_BETTAFISH / HTTP_xxx / 服务端 message）
  message: string;

  constructor(ok: boolean, data: T | null, code: string, message: string) {
    this.ok = ok;
    this.data = data;
    this.code = code;
    this.message = message;
  }
}

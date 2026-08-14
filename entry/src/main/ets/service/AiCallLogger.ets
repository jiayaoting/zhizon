// 智子 - AI 调用日志（仅记录摘要：时间/场景/模型/成败/耗时/字符量，不存 prompt 与响应全文）
import { DatabaseHelper, AiCallLogEntry, AiTokenStats } from './DatabaseHelper';
import { ChatMessage, LlmConfig, LlmResult } from '../common/LlmModels';

// 调用场景类型
export type AiCallType = 'chat' | 'game' | 'test';

// 场景上下文：由调用方注入，区分聊天/游戏/测试
export class AiCallContext {
  type: AiCallType;
  game: string; // 仅 game 类型有值：2048/Tetris/Snake/Minesweeper/Sudoku/ChineseChess

  constructor(type: AiCallType, game: string = '') {
    this.type = type;
    this.game = game;
  }
}

// 一次调用待落库的记录（先在内存中组装，结束时写库）
export class AiCallLog {
  id: string;
  type: string;
  game: string;
  model: string;
  provider: string;
  startTime: number;
  endTime: number;
  durationMs: number;
  success: boolean;
  errorCode: string;
  errorMsg: string;
  promptChars: number;
  responseChars: number;
  // Token 消耗（服务端 usage，未返回时为 0）
  inputTokens: number;
  cachedTokens: number;
  outputTokens: number;
  totalTokens: number;

  constructor(id: string, type: string, game: string, model: string, provider: string,
    startTime: number, promptChars: number) {
    this.id = id;
    this.type = type;
    this.game = game;
    this.model = model;
    this.provider = provider;
    this.startTime = startTime;
    this.endTime = startTime;
    this.durationMs = 0;
    this.success = true;
    this.errorCode = '';
    this.errorMsg = '';
    this.promptChars = promptChars;
    this.responseChars = 0;
    this.inputTokens = 0;
    this.cachedTokens = 0;
    this.outputTokens = 0;
    this.totalTokens = 0;
  }
}

export class AiCallLogger {
  // 调用开始：组装内存记录（异步写入在结束时进行）
  static start(config: LlmConfig, context: AiCallContext, messages: ChatMessage[], startTime: number): AiCallLog {
    let promptChars: number = 0;
    for (let i: number = 0; i < messages.length; i++) {
      promptChars = promptChars + messages[i].content.length;
    }
    const id: string = 'ail-' + startTime.toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    return new AiCallLog(id, context.type, context.game, config.model.trim(), config.providerId,
      startTime, promptChars);
  }

  // 调用结束：写入结果并落库（异步、不阻塞调用方）
  static end(log: AiCallLog, result: LlmResult, endTime: number): void {
    log.endTime = endTime;
    log.durationMs = Math.max(0, endTime - log.startTime);
    log.success = result.success;
    log.errorCode = result.errorCode;
    log.errorMsg = result.errorMessage;
    log.responseChars = result.content.length;
    log.inputTokens = result.tokenUsage.inputTokens;
    log.cachedTokens = result.tokenUsage.cachedTokens;
    log.outputTokens = result.tokenUsage.outputTokens;
    log.totalTokens = result.tokenUsage.totalTokens;
    const entry: AiCallLogEntry = {
      id: log.id,
      type: log.type,
      game: log.game,
      model: log.model,
      provider: log.provider,
      startTime: log.startTime,
      endTime: log.endTime,
      durationMs: log.durationMs,
      success: log.success,
      errorCode: log.errorCode,
      errorMsg: log.errorMsg,
      promptChars: log.promptChars,
      responseChars: log.responseChars,
      inputTokens: log.inputTokens,
      cachedTokens: log.cachedTokens,
      outputTokens: log.outputTokens,
      totalTokens: log.totalTokens
    };
    DatabaseHelper.insertAiCallLog(entry);
  }

  // 读取最近日志（按时间倒序）
  static async loadLogs(limit: number = 500): Promise<AiCallLogEntry[]> {
    return await DatabaseHelper.queryAiCallLogs(limit);
  }

  // 日志总数
  static async getLogCount(): Promise<number> {
    return await DatabaseHelper.countAiCallLogs();
  }

  // 累计统计（所有模型调用记录总和，删除模型/清空调用记录不会重置）
  static async getTokenStats(): Promise<AiTokenStats> {
    return await DatabaseHelper.getAiTokenStats();
  }

  // 清空全部日志
  static async clearLogs(): Promise<void> {
    await DatabaseHelper.clearAiCallLogs();
  }
}
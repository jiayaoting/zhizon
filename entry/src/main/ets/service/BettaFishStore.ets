// 智子 - BettaFish（微舆）本地数据存储门面
// 依赖 DatabaseHelper（RDB v17：bettafish_servers / bettafish_history 两表）
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from './DatabaseHelper';
import { BettaServerConfig, BettaHistoryItem } from '../common/BettaFishModels';
import { generateId } from './DataRepository';

const BETTA_DOMAIN = 0x9202;
const TABLE_SERVERS = 'bettafish_servers';
const TABLE_HISTORY = 'bettafish_history';

function getStore(): relationalStore.RdbStore {
  return DatabaseHelper.getStore();
}

export class BettaFishStore {
  // ========== 服务器配置 ==========

  static async listServers(): Promise<BettaServerConfig[]> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
    predicates.orderByAsc('updated_at');
    const resultSet = await store.query(predicates);
    const list: BettaServerConfig[] = [];
    try {
      while (resultSet.goToNextRow()) {
        list.push(BettaFishStore.rowToServer(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return list;
  }

  static async getCurrent(): Promise<BettaServerConfig | null> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
    predicates.equalTo('is_current', 1);
    const resultSet = await store.query(predicates);
    try {
      if (resultSet.goToNextRow()) {
        return BettaFishStore.rowToServer(resultSet);
      }
      return null;
    } finally {
      resultSet.close();
    }
  }

  // 保存配置：存在则更新，否则插入；isCurrent=true 时先清除其余标记
  static async saveServer(config: BettaServerConfig): Promise<void> {
    const store = getStore();
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      'name': config.name,
      'scheme': config.scheme,
      'host': config.host,
      'port': config.port,
      'base_path': config.basePath,
      'timeout_sec': config.timeoutSec,
      'forum_position': config.forumPosition,
      'updated_at': now
    };
    if (config.isCurrent) {
      const clearAll = new relationalStore.RdbPredicates(TABLE_SERVERS);
      clearAll.equalTo('is_current', 1);
      const clearBucket: relationalStore.ValuesBucket = { 'is_current': 0 };
      await store.update(clearBucket, clearAll);
    }
    if (config.id.length === 0) {
      config.id = generateId('betta');
      bucket['id'] = config.id;
      bucket['is_current'] = config.isCurrent ? 1 : 0;
      bucket['created_at'] = now;
      await store.insert(TABLE_SERVERS, bucket);
    } else {
      bucket['is_current'] = config.isCurrent ? 1 : 0;
      const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
      predicates.equalTo('id', config.id);
      await store.update(bucket, predicates);
    }
  }

  static async deleteServer(id: string): Promise<void> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
    predicates.equalTo('id', id);
    await store.delete(predicates);
    // 若删除的是当前配置，则自动切换到最近更新的一条
    const list = await BettaFishStore.listServers();
    let anyCurrent: boolean = false;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].isCurrent) {
        anyCurrent = true;
        break;
      }
    }
    if (list.length > 0 && !anyCurrent) {
      await BettaFishStore.setCurrent(list[0].id);
    }
  }

  static async setCurrent(id: string): Promise<void> {
    const store = getStore();
    const clearAll = new relationalStore.RdbPredicates(TABLE_SERVERS);
    clearAll.equalTo('is_current', 1);
    await store.update({ 'is_current': 0 }, clearAll);
    const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
    predicates.equalTo('id', id);
    await store.update({ 'is_current': 1 }, predicates);
  }

  static async updateForumPosition(serverId: string, position: number): Promise<void> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_SERVERS);
    predicates.equalTo('id', serverId);
    await store.update({ 'forum_position': position }, predicates);
  }

  // ========== 报告历史 ==========

  static async upsertHistory(item: BettaHistoryItem): Promise<void> {
    const store = getStore();
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      'task_id': item.taskId,
      'query': item.query,
      'status': item.status,
      'progress': item.progress,
      'base_url': item.baseUrl,
      'server_id': item.serverId,
      'updated_at': now,
      'saved_at': item.savedAt,
      'local_html_path': item.localHtmlPath,
      'local_md_path': item.localMdPath,
      'local_pdf_path': item.localPdfPath
    };
    const predicates = new relationalStore.RdbPredicates(TABLE_HISTORY);
    predicates.equalTo('task_id', item.taskId);
    const resultSet = await store.query(predicates);
    let exists = false;
    try {
      exists = resultSet.goToNextRow();
    } finally {
      resultSet.close();
    }
    if (exists) {
      await store.update(bucket, predicates);
    } else {
      bucket['created_at'] = item.createdAt > 0 ? item.createdAt : now;
      await store.insert(TABLE_HISTORY, bucket);
    }
  }

  static async listHistory(limit: number = 100): Promise<BettaHistoryItem[]> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_HISTORY);
    predicates.orderByDesc('created_at');
    if (limit > 0) {
      predicates.limitAs(limit);
    }
    const resultSet = await store.query(predicates);
    const list: BettaHistoryItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item = new BettaHistoryItem();
        item.taskId = BettaFishStore.getString(resultSet, 'task_id');
        item.query = BettaFishStore.getString(resultSet, 'query');
        item.status = BettaFishStore.getString(resultSet, 'status');
        item.progress = BettaFishStore.getLong(resultSet, 'progress');
        item.baseUrl = BettaFishStore.getString(resultSet, 'base_url');
        item.serverId = BettaFishStore.getString(resultSet, 'server_id');
        item.createdAt = BettaFishStore.getLong(resultSet, 'created_at');
        item.updatedAt = BettaFishStore.getLong(resultSet, 'updated_at');
        item.savedAt = BettaFishStore.getLong(resultSet, 'saved_at');
        item.localHtmlPath = BettaFishStore.getString(resultSet, 'local_html_path');
        item.localMdPath = BettaFishStore.getString(resultSet, 'local_md_path');
        item.localPdfPath = BettaFishStore.getString(resultSet, 'local_pdf_path');
        list.push(item);
      }
    } finally {
      resultSet.close();
    }
    return list;
  }

  static async deleteHistory(taskId: string): Promise<void> {
    const store = getStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_HISTORY);
    predicates.equalTo('task_id', taskId);
    await store.delete(predicates);
  }

  // ========== 内部工具 ==========

  private static rowToServer(resultSet: relationalStore.ResultSet): BettaServerConfig {
    const config = new BettaServerConfig();
    config.id = BettaFishStore.getString(resultSet, 'id');
    config.name = BettaFishStore.getString(resultSet, 'name');
    config.scheme = BettaFishStore.getString(resultSet, 'scheme');
    config.host = BettaFishStore.getString(resultSet, 'host');
    config.port = BettaFishStore.getLong(resultSet, 'port');
    config.basePath = BettaFishStore.getString(resultSet, 'base_path');
    config.timeoutSec = BettaFishStore.getLong(resultSet, 'timeout_sec');
    config.isCurrent = BettaFishStore.getLong(resultSet, 'is_current') === 1;
    config.forumPosition = BettaFishStore.getLong(resultSet, 'forum_position');
    return config;
  }

  private static getString(resultSet: relationalStore.ResultSet, column: string): string {
    const index = resultSet.getColumnIndex(column);
    if (index < 0) return '';
    return resultSet.getString(index);
  }

  private static getLong(resultSet: relationalStore.ResultSet, column: string): number {
    const index = resultSet.getColumnIndex(column);
    if (index < 0) return 0;
    return resultSet.getLong(index);
  }

  static logWarn(tag: string, message: string): void {
    hilog.warn(BETTA_DOMAIN, tag, '%{public}s', message);
  }
}

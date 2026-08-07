// 智子 - 数据库管理（RDB Store）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Server, PveCluster, Command, Alert, FileItem } from '../model/Models';
import { CryptoHelper } from '../common/CryptoHelper';

export interface ScoreEntry {
  id: string;
  score: number;
  level: number;
  difficulty: string;
  createdAt: number;
}

const DB_NAME = 'zhizon.db';
const DB_VERSION = 3;

// 建表 SQL
const SQL_CREATE_SERVERS = `
  CREATE TABLE IF NOT EXISTS servers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    port INTEGER DEFAULT 22,
    username TEXT NOT NULL,
    auth_type TEXT DEFAULT 'password',
    password_enc TEXT,
    key_id TEXT,
    grp TEXT,
    tags TEXT,
    os TEXT,
    created_at INTEGER,
    last_connected INTEGER DEFAULT 0,
    connection_mode TEXT DEFAULT 'direct',
    agent_token TEXT DEFAULT 'zhizon-agent',
    private_key_path TEXT
  )
`;

// v2 迁移：为已有 servers 表新增列
const SQL_MIGRATE_V2 = [
  'ALTER TABLE servers ADD COLUMN connection_mode TEXT DEFAULT \'agent\'',
  'ALTER TABLE servers ADD COLUMN agent_token TEXT DEFAULT \'zhizon-agent\'',
  'ALTER TABLE servers ADD COLUMN private_key_path TEXT'
];

// v3 迁移：servers 表新增私钥内容列（加密存储）
const SQL_MIGRATE_V3 = [
  'ALTER TABLE servers ADD COLUMN key_content TEXT'
];

const SQL_CREATE_PVE_CLUSTERS = `
  CREATE TABLE IF NOT EXISTS pve_clusters (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    port INTEGER DEFAULT 8006,
    username TEXT NOT NULL,
    auth_type TEXT DEFAULT 'password',
    password_enc TEXT,
    token_id TEXT,
    token_secret_enc TEXT,
    verify_tls INTEGER DEFAULT 1,
    created_at INTEGER,
    last_sync INTEGER DEFAULT 0
  )
`;

const SQL_CREATE_COMMANDS = `
  CREATE TABLE IF NOT EXISTS commands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    cmd TEXT NOT NULL,
    category TEXT DEFAULT '通用',
    uses INTEGER DEFAULT 0,
    created_at INTEGER
  )
`;

const SQL_CREATE_ALERTS = `
  CREATE TABLE IF NOT EXISTS alerts (
    id TEXT PRIMARY KEY,
    level TEXT DEFAULT 'info',
    source TEXT,
    title TEXT NOT NULL,
    detail TEXT,
    time TEXT,
    resolved INTEGER DEFAULT 0,
    created_at INTEGER
  )
`;

const SQL_CREATE_SETTINGS = `
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )
`;

const SQL_CREATE_GAME_SCORES = `
  CREATE TABLE IF NOT EXISTS game_scores (
    id TEXT PRIMARY KEY,
    game TEXT NOT NULL,
    score INTEGER NOT NULL,
    level INTEGER DEFAULT 1,
    difficulty TEXT DEFAULT '中等',
    created_at INTEGER
  )
`;

export class DatabaseHelper {
  private static store: relationalStore.RdbStore | null = null;

  // 初始化数据库
  static async init(context: common.Context): Promise<void> {
    if (DatabaseHelper.store) return;

    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    DatabaseHelper.store = await relationalStore.getRdbStore(context, config);

    // 创建表
    await DatabaseHelper.store.executeSql(SQL_CREATE_SERVERS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_PVE_CLUSTERS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_COMMANDS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_ALERTS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_SETTINGS);
    await DatabaseHelper.store.executeSql(SQL_CREATE_GAME_SCORES);

    // v2 迁移：为已有 servers 表新增列（安全执行，列已存在时忽略错误）
    await DatabaseHelper.migrateV2();
    // v3 迁移：servers 表新增 key_content 列
    await DatabaseHelper.migrateV3();

    // 清理历史种子假数据（对旧版本播种的假 id 生效）
    await DatabaseHelper.cleanupLegacySeedData();
  }

  static getStore(): relationalStore.RdbStore {
    if (!DatabaseHelper.store) throw new Error('Database not initialized');
    return DatabaseHelper.store;
  }

  // v2 迁移：安全添加列（列已存在时忽略错误）
  private static async migrateV2(): Promise<void> {
    for (const sql of SQL_MIGRATE_V2) {
      try {
        await DatabaseHelper.store!.executeSql(sql);
      } catch (e) {
        // 列已存在，忽略错误
        console.info('Migration column already exists, skipping:', sql);
      }
    }
  }

  // v3 迁移：安全添加 key_content 列（列已存在时忽略错误）
  private static async migrateV3(): Promise<void> {
    for (const sql of SQL_MIGRATE_V3) {
      try {
        await DatabaseHelper.store!.executeSql(sql);
      } catch (e) {
        console.info('Migration column already exists, skipping:', sql);
      }
    }
  }

  // ========== 服务器 CRUD ==========

  static async getServers(): Promise<Server[]> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('servers');
    const resultSet = await store.query(predicates);
    const servers: Server[] = [];

    while (resultSet.goToNextRow()) {
      servers.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        host: resultSet.getString(resultSet.getColumnIndex('host')),
        port: resultSet.getLong(resultSet.getColumnIndex('port')),
        username: resultSet.getString(resultSet.getColumnIndex('username')),
        authType: (resultSet.getString(resultSet.getColumnIndex('auth_type')) || 'password') as 'password' | 'key',
        connectionMode: (resultSet.getString(resultSet.getColumnIndex('connection_mode')) || 'direct') as 'direct' | 'agent',
        agentToken: resultSet.getString(resultSet.getColumnIndex('agent_token')) || undefined,
        privateKeyPath: resultSet.getString(resultSet.getColumnIndex('private_key_path')) || undefined,
        group: resultSet.getString(resultSet.getColumnIndex('grp')) || undefined,
        tags: DatabaseHelper.parseTags(resultSet.getString(resultSet.getColumnIndex('tags'))),
        os: resultSet.getString(resultSet.getColumnIndex('os')) || undefined,
        status: 'offline',
        metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        lastConnected: resultSet.getLong(resultSet.getColumnIndex('last_connected')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      });
    }
    resultSet.close();
    return servers;
  }

  static async getServer(id: string): Promise<Server | undefined> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('servers');
    predicates.equalTo('id', id);
    const resultSet = await store.query(predicates);
    if (resultSet.goToNextRow()) {
      const s: Server = {
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        host: resultSet.getString(resultSet.getColumnIndex('host')),
        port: resultSet.getLong(resultSet.getColumnIndex('port')),
        username: resultSet.getString(resultSet.getColumnIndex('username')),
        authType: (resultSet.getString(resultSet.getColumnIndex('auth_type')) || 'password') as 'password' | 'key',
        connectionMode: (resultSet.getString(resultSet.getColumnIndex('connection_mode')) || 'direct') as 'direct' | 'agent',
        agentToken: resultSet.getString(resultSet.getColumnIndex('agent_token')) || undefined,
        privateKeyPath: resultSet.getString(resultSet.getColumnIndex('private_key_path')) || undefined,
        group: resultSet.getString(resultSet.getColumnIndex('grp')) || undefined,
        tags: DatabaseHelper.parseTags(resultSet.getString(resultSet.getColumnIndex('tags'))),
        os: resultSet.getString(resultSet.getColumnIndex('os')) || undefined,
        status: 'offline',
        metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        lastConnected: resultSet.getLong(resultSet.getColumnIndex('last_connected')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      };
      resultSet.close();
      return s;
    }
    resultSet.close();
    return undefined;
  }

  static async addServer(server: Server): Promise<void> {
    const store = DatabaseHelper.getStore();
    const valueBucket: relationalStore.ValuesBucket = {
      id: server.id,
      name: server.name,
      host: server.host,
      port: server.port,
      username: server.username,
      auth_type: server.authType,
      grp: server.group || '',
      tags: server.tags.join(','),
      os: server.os || '',
      created_at: server.createdAt,
      last_connected: server.lastConnected || 0,
      connection_mode: server.connectionMode || 'direct',
      agent_token: server.agentToken || 'zhizon-agent',
      private_key_path: server.privateKeyPath || ''
    };
    // 加密凭据落库（明文不持久化）
    if (server.password) {
      valueBucket['password_enc'] = await CryptoHelper.encrypt(server.password);
    }
    if (server.privateKeyContent) {
      valueBucket['key_content'] = await CryptoHelper.encrypt(server.privateKeyContent);
    }
    await store.insert('servers', valueBucket);
  }

  static async updateServer(id: string, updates: Partial<Server>): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {};
    if (updates.name !== undefined) bucket['name'] = updates.name;
    if (updates.host !== undefined) bucket['host'] = updates.host;
    if (updates.port !== undefined) bucket['port'] = updates.port;
    if (updates.username !== undefined) bucket['username'] = updates.username;
    if (updates.authType !== undefined) bucket['auth_type'] = updates.authType;
    if (updates.group !== undefined) bucket['grp'] = updates.group;
    if (updates.tags !== undefined) bucket['tags'] = updates.tags.join(',');
    if (updates.lastConnected !== undefined) bucket['last_connected'] = updates.lastConnected;
    if (updates.connectionMode !== undefined) bucket['connection_mode'] = updates.connectionMode;
    if (updates.agentToken !== undefined) bucket['agent_token'] = updates.agentToken;
    if (updates.privateKeyPath !== undefined) bucket['private_key_path'] = updates.privateKeyPath;
    // 凭据更新：显式传入明文时加密落库
    if (updates.password !== undefined && updates.password.length > 0) {
      bucket['password_enc'] = await CryptoHelper.encrypt(updates.password);
    }
    if (updates.privateKeyContent !== undefined && updates.privateKeyContent.length > 0) {
      bucket['key_content'] = await CryptoHelper.encrypt(updates.privateKeyContent);
    }

    const predicates = new relationalStore.RdbPredicates('servers');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  // 保存密码/密钥内容（加密后落库）；传空字符串则清除
  static async saveCredentials(id: string, password?: string, keyContent?: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {};
    if (password !== undefined) {
      if (password.length > 0) {
        bucket['password_enc'] = await CryptoHelper.encrypt(password);
      } else {
        bucket['password_enc'] = '';
      }
    }
    if (keyContent !== undefined) {
      if (keyContent.length > 0) {
        bucket['key_content'] = await CryptoHelper.encrypt(keyContent);
      } else {
        bucket['key_content'] = '';
      }
    }
    if (Object.keys(bucket).length === 0) return;
    const predicates = new relationalStore.RdbPredicates('servers');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  // 读取解密后的密码（无则返回空串）
  static async getPassword(id: string): Promise<string> {
    const enc = await DatabaseHelper.getEncColumn(id, 'password_enc');
    if (!enc) return '';
    return await CryptoHelper.decrypt(enc);
  }

  // 读取解密后的私钥内容（无则返回空串）
  static async getKeyContent(id: string): Promise<string> {
    const enc = await DatabaseHelper.getEncColumn(id, 'key_content');
    if (!enc) return '';
    return await CryptoHelper.decrypt(enc);
  }

  // 读取单个加密列（按 id）
  private static async getEncColumn(id: string, column: string): Promise<string> {
    try {
      const store = DatabaseHelper.getStore();
      const predicates = new relationalStore.RdbPredicates('servers');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      let val = '';
      if (resultSet.goToNextRow()) {
        val = resultSet.getString(resultSet.getColumnIndex(column)) || '';
      }
      resultSet.close();
      return val;
    } catch (e) {
      console.error('getEncColumn failed:', column, e);
      return '';
    }
  }

  static async deleteServer(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('servers');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  // ========== PVE 集群 CRUD ==========

  static async getPveClusters(): Promise<PveCluster[]> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('pve_clusters');
    const resultSet = await store.query(predicates);
    const clusters: PveCluster[] = [];

    while (resultSet.goToNextRow()) {
      clusters.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        host: resultSet.getString(resultSet.getColumnIndex('host')),
        port: resultSet.getLong(resultSet.getColumnIndex('port')),
        username: resultSet.getString(resultSet.getColumnIndex('username')),
        authType: (resultSet.getString(resultSet.getColumnIndex('auth_type')) || 'password') as 'password' | 'token',
        verifyTls: resultSet.getLong(resultSet.getColumnIndex('verify_tls')) === 1,
        version: '',
        lastSync: '从未同步',
        nodes: []
      });
    }
    resultSet.close();
    return clusters;
  }

  static async addPveCluster(cluster: PveCluster): Promise<void> {
    const store = DatabaseHelper.getStore();
    const valueBucket: relationalStore.ValuesBucket = {
      id: cluster.id,
      name: cluster.name,
      host: cluster.host,
      port: cluster.port,
      username: cluster.username,
      auth_type: cluster.authType,
      verify_tls: cluster.verifyTls ? 1 : 0,
      created_at: Date.now()
    };
    // 加密凭据落库（明文不持久化）
    if (cluster.password) {
      valueBucket['password_enc'] = await CryptoHelper.encrypt(cluster.password);
    }
    if (cluster.tokenId) {
      valueBucket['token_id'] = cluster.tokenId;
    }
    if (cluster.tokenSecret) {
      valueBucket['token_secret_enc'] = await CryptoHelper.encrypt(cluster.tokenSecret);
    }
    await store.insert('pve_clusters', valueBucket);
  }

  static async updatePveCluster(id: string, updates: Partial<PveCluster>): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {};
    if (updates.name !== undefined) bucket['name'] = updates.name;
    if (updates.host !== undefined) bucket['host'] = updates.host;
    if (updates.port !== undefined) bucket['port'] = updates.port;
    if (updates.username !== undefined) bucket['username'] = updates.username;
    if (updates.authType !== undefined) bucket['auth_type'] = updates.authType;
    if (updates.verifyTls !== undefined) bucket['verify_tls'] = updates.verifyTls ? 1 : 0;
    if (updates.tokenId !== undefined) bucket['token_id'] = updates.tokenId;
    // 凭据更新：显式传入明文时加密落库
    if (updates.password !== undefined && updates.password.length > 0) {
      bucket['password_enc'] = await CryptoHelper.encrypt(updates.password);
    }
    if (updates.tokenSecret !== undefined && updates.tokenSecret.length > 0) {
      bucket['token_secret_enc'] = await CryptoHelper.encrypt(updates.tokenSecret);
    }

    const predicates = new relationalStore.RdbPredicates('pve_clusters');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  // 保存 PVE 密码/Token Secret（加密后落库）；传空字符串则清除
  static async savePveCredentials(id: string, password?: string, tokenSecret?: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {};
    if (password !== undefined) {
      if (password.length > 0) {
        bucket['password_enc'] = await CryptoHelper.encrypt(password);
      } else {
        bucket['password_enc'] = '';
      }
    }
    if (tokenSecret !== undefined) {
      if (tokenSecret.length > 0) {
        bucket['token_secret_enc'] = await CryptoHelper.encrypt(tokenSecret);
      } else {
        bucket['token_secret_enc'] = '';
      }
    }
    if (Object.keys(bucket).length === 0) return;
    const predicates = new relationalStore.RdbPredicates('pve_clusters');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  // 读取解密后的 PVE 密码（无则返回空串）
  static async getPvePassword(id: string): Promise<string> {
    const enc = await DatabaseHelper.getPveEncColumn(id, 'password_enc');
    if (!enc) return '';
    return await CryptoHelper.decrypt(enc);
  }

  // 读取解密后的 PVE Token Secret（无则返回空串）
  static async getPveTokenSecret(id: string): Promise<string> {
    const enc = await DatabaseHelper.getPveEncColumn(id, 'token_secret_enc');
    if (!enc) return '';
    return await CryptoHelper.decrypt(enc);
  }

  // 读取 PVE Token ID（不加密）
  static async getPveTokenId(id: string): Promise<string> {
    try {
      const store = DatabaseHelper.getStore();
      const predicates = new relationalStore.RdbPredicates('pve_clusters');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      let val = '';
      if (resultSet.goToNextRow()) {
        val = resultSet.getString(resultSet.getColumnIndex('token_id')) || '';
      }
      resultSet.close();
      return val;
    } catch (e) {
      console.error('getPveTokenId failed:', e);
      return '';
    }
  }

  // 读取 PVE 单个加密列（按 id）
  private static async getPveEncColumn(id: string, column: string): Promise<string> {
    try {
      const store = DatabaseHelper.getStore();
      const predicates = new relationalStore.RdbPredicates('pve_clusters');
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      let val = '';
      if (resultSet.goToNextRow()) {
        val = resultSet.getString(resultSet.getColumnIndex(column)) || '';
      }
      resultSet.close();
      return val;
    } catch (e) {
      console.error('getPveEncColumn failed:', column, e);
      return '';
    }
  }

  static async deletePveCluster(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('pve_clusters');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  // ========== 快捷命令 CRUD ==========

  static async getCommands(): Promise<Command[]> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('commands');
    predicates.orderByDesc('uses');
    const resultSet = await store.query(predicates);
    const commands: Command[] = [];

    while (resultSet.goToNextRow()) {
      commands.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        cmd: resultSet.getString(resultSet.getColumnIndex('cmd')),
        category: resultSet.getString(resultSet.getColumnIndex('category')),
        uses: resultSet.getLong(resultSet.getColumnIndex('uses'))
      });
    }
    resultSet.close();
    return commands;
  }

  static async addCommand(cmd: Command): Promise<void> {
    const store = DatabaseHelper.getStore();
    const valueBucket: relationalStore.ValuesBucket = {
      id: cmd.id,
      name: cmd.name,
      cmd: cmd.cmd,
      category: cmd.category,
      uses: cmd.uses,
      created_at: Date.now()
    };
    await store.insert('commands', valueBucket);
  }

  static async incrementCommandUses(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    await store.executeSql('UPDATE commands SET uses = uses + 1 WHERE id = ?', [id]);
  }

  static async deleteCommand(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('commands');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  // ========== 告警 CRUD ==========

  static async getAlerts(resolvedOnly?: boolean): Promise<Alert[]> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('alerts');
    predicates.orderByDesc('created_at');
    if (resolvedOnly !== undefined) {
      predicates.equalTo('resolved', resolvedOnly ? 1 : 0);
    }
    const resultSet = await store.query(predicates);
    const alerts: Alert[] = [];

    while (resultSet.goToNextRow()) {
      alerts.push({
        id: resultSet.getString(resultSet.getColumnIndex('id')),
        level: (resultSet.getString(resultSet.getColumnIndex('level')) || 'info') as 'critical' | 'warning' | 'info',
        source: resultSet.getString(resultSet.getColumnIndex('source')) || '',
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        detail: resultSet.getString(resultSet.getColumnIndex('detail')) || '',
        time: resultSet.getString(resultSet.getColumnIndex('time')) || '',
        resolved: resultSet.getLong(resultSet.getColumnIndex('resolved')) === 1
      });
    }
    resultSet.close();
    return alerts;
  }

  static async addAlert(alert: Alert): Promise<void> {
    const store = DatabaseHelper.getStore();
    const valueBucket: relationalStore.ValuesBucket = {
      id: alert.id,
      level: alert.level,
      source: alert.source,
      title: alert.title,
      detail: alert.detail,
      time: alert.time,
      resolved: alert.resolved ? 1 : 0,
      created_at: Date.now()
    };
    await store.insert('alerts', valueBucket);
  }

  static async resolveAlert(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('alerts');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { resolved: 1 };
    await store.update(bucket, predicates);
  }

  static async resolveAllAlerts(): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('alerts');
    predicates.equalTo('resolved', 0);
    const bucket: relationalStore.ValuesBucket = { resolved: 1 };
    await store.update(bucket, predicates);
  }

  // ========== 游戏战绩 ==========

  static async addGameScore(game: string, score: number, level: number, difficulty: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const id: string = 'gs-' + Date.now().toString(36) + '-' + Math.random().toString(36).substring(2, 6);
    const valueBucket: relationalStore.ValuesBucket = {
      id: id,
      game: game,
      score: score,
      level: level,
      difficulty: difficulty,
      created_at: Date.now()
    };
    await store.insert('game_scores', valueBucket);
  }

  static async getGameScores(game: string, limit: number = 50): Promise<ScoreEntry[]> {
    const store = DatabaseHelper.getStore();
    const results: ScoreEntry[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates('game_scores');
      predicates.equalTo('game', game);
      predicates.orderByDesc('score');
      predicates.limitAs(limit);
      const resultSet = await store.query(predicates);
      while (resultSet.goToNextRow()) {
        results.push({
          id: resultSet.getString(resultSet.getColumnIndex('id')),
          score: resultSet.getLong(resultSet.getColumnIndex('score')),
          level: resultSet.getLong(resultSet.getColumnIndex('level')),
          difficulty: resultSet.getString(resultSet.getColumnIndex('difficulty')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        } as ScoreEntry);
      }
      resultSet.close();
    } catch (e) {
      console.error('getGameScores failed:', e);
    }
    return results;
  }

  static async getGameHighScore(game: string): Promise<number> {
    const store = DatabaseHelper.getStore();
    try {
      const predicates = new relationalStore.RdbPredicates('game_scores');
      predicates.equalTo('game', game);
      predicates.orderByDesc('score');
      predicates.limitAs(1);
      const resultSet = await store.query(predicates);
      let high: number = 0;
      if (resultSet.goToNextRow()) {
        high = resultSet.getLong(resultSet.getColumnIndex('score'));
      }
      resultSet.close();
      return high;
    } catch (e) {
      return 0;
    }
  }

  static async deleteGameScore(id: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_scores');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  static async clearGameScores(game: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('game_scores');
    predicates.equalTo('game', game);
    await store.delete(predicates);
  }

  // ========== 设置 ==========

  static async getSetting(key: string, defaultValue: string = ''): Promise<string> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('settings');
    predicates.equalTo('key', key);
    const resultSet = await store.query(predicates);
    if (resultSet.goToNextRow()) {
      const val = resultSet.getString(resultSet.getColumnIndex('value'));
      resultSet.close();
      return val || defaultValue;
    }
    resultSet.close();
    return defaultValue;
  }

  static async setSetting(key: string, value: string): Promise<void> {
    const store = DatabaseHelper.getStore();
    const predicates = new relationalStore.RdbPredicates('settings');
    predicates.equalTo('key', key);
    const resultSet = await store.query(predicates);
    if (resultSet.goToNextRow()) {
      resultSet.close();
      const bucket: relationalStore.ValuesBucket = { value: value };
      await store.update(bucket, predicates);
    } else {
      resultSet.close();
      const bucket: relationalStore.ValuesBucket = { key: key, value: value };
      await store.insert('settings', bucket);
    }
  }

  // ========== 工具方法 ==========

  private static parseTags(tagsStr: string | null): string[] {
    if (!tagsStr || tagsStr.trim() === '') return [];
    return tagsStr.split(',').filter(t => t.trim() !== '');
  }

  // 清理历史种子假数据（旧版本播种的 srv-xxx / cxx 残留，幂等：无此 id 时静默跳过）
  private static async cleanupLegacySeedData(): Promise<void> {
    const legacyServerIds: string[] = ['srv-001', 'srv-002', 'srv-003', 'srv-004', 'srv-005', 'srv-006'];
    const legacyCmdIds: string[] = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9', 'c10', 'c11', 'c12'];
    const store = DatabaseHelper.getStore();
    for (const id of legacyServerIds) {
      const predicates = new relationalStore.RdbPredicates('servers');
      predicates.equalTo('id', id);
      await store.delete(predicates);
    }
    for (const id of legacyCmdIds) {
      const predicates = new relationalStore.RdbPredicates('commands');
      predicates.equalTo('id', id);
      await store.delete(predicates);
    }
    console.info('Zhizon: legacy seed data cleaned');
  }
}
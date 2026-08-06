// 智子 - 数据库管理（RDB Store）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Server, PveCluster, Command, Alert, FileItem } from '../model/Models';

const DB_NAME = 'zhizon.db';
const DB_VERSION = 2;

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
    connection_mode TEXT DEFAULT 'agent',
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

    // v2 迁移：为已有 servers 表新增列（安全执行，列已存在时忽略错误）
    await DatabaseHelper.migrateV2();

    // 插入默认数据
    await DatabaseHelper.seedDefaults();
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
        connectionMode: (resultSet.getString(resultSet.getColumnIndex('connection_mode')) || 'agent') as 'direct' | 'agent',
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
        connectionMode: (resultSet.getString(resultSet.getColumnIndex('connection_mode')) || 'agent') as 'direct' | 'agent',
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
      connection_mode: server.connectionMode || 'agent',
      agent_token: server.agentToken || 'zhizon-agent',
      private_key_path: server.privateKeyPath || ''
    };
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

    const predicates = new relationalStore.RdbPredicates('servers');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
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
    await store.insert('pve_clusters', valueBucket);
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

  // ========== 文件管理 ==========

  static async getFiles(): Promise<FileItem[]> {
    return [
      { name: 'app', type: 'dir', size: 0, modified: '2026-08-04 09:30', perms: 'drwxr-xr-x' },
      { name: 'logs', type: 'dir', size: 0, modified: '2026-08-05 07:15', perms: 'drwxr-xr-x' },
      { name: 'config', type: 'dir', size: 0, modified: '2026-07-28 16:00', perms: 'drwxr-xr-x' },
      { name: 'deploy.sh', type: 'file', size: 2048, modified: '2026-08-03 11:20', perms: '-rwxr-xr-x' },
      { name: 'nginx.conf', type: 'file', size: 5120, modified: '2026-08-02 14:45', perms: '-rw-r--r--' },
      { name: 'docker-compose.yml', type: 'file', size: 3072, modified: '2026-07-30 08:00', perms: '-rw-r--r--' },
      { name: '.env', type: 'file', size: 1024, modified: '2026-08-01 19:10', perms: '-rw-------' }
    ];
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

  // 初始化默认数据
  private static async seedDefaults(): Promise<void> {
    const existing = await DatabaseHelper.getServers();
    if (existing.length > 0) return; // 已有数据，不重复播种

    const now = Date.now();
    const day = 86400000;

    const defaultServers: Server[] = [
      { id: 'srv-001', name: 'prod-web-01', host: '192.168.1.10', port: 22, username: 'root',
        authType: 'key', connectionMode: 'agent', group: '生产', tags: ['web', 'nginx'], os: 'Ubuntu 22.04 LTS',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 30 },
      { id: 'srv-002', name: 'prod-db-master', host: '192.168.1.20', port: 22, username: 'root',
        authType: 'key', connectionMode: 'agent', group: '生产', tags: ['mysql', 'master'], os: 'Debian 12',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 60 },
      { id: 'srv-003', name: 'dev-test-01', host: '192.168.1.30', port: 22, username: 'ubuntu',
        authType: 'password', connectionMode: 'direct', group: '测试', tags: ['docker'], os: 'Ubuntu 24.04 LTS',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 10 },
      { id: 'srv-004', name: 'monitor-grafana', host: '192.168.1.40', port: 22, username: 'root',
        authType: 'key', connectionMode: 'agent', group: '监控', tags: ['grafana', 'prometheus'], os: 'CentOS Stream 9',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 90 },
      { id: 'srv-005', name: 'backup-storage', host: '192.168.1.50', port: 2222, username: 'backup',
        authType: 'password', connectionMode: 'direct', group: '备份', tags: ['minio', 'storage'], os: 'Alpine 3.19',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 120 },
      { id: 'srv-006', name: 'ci-runner-01', host: '192.168.1.60', port: 22, username: 'gitlab',
        authType: 'key', connectionMode: 'agent', group: 'CI/CD', tags: ['gitlab', 'runner'], os: 'Ubuntu 22.04 LTS',
        status: 'offline', metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 },
        createdAt: now - day * 45 }
    ];

    for (const s of defaultServers) {
      await DatabaseHelper.addServer(s);
    }

    const defaultCommands: Command[] = [
      { id: 'c1', name: '查看 CPU 占用 Top10', cmd: 'ps aux --sort=-%cpu | head -10', category: '进程', uses: 23 },
      { id: 'c2', name: '查看内存使用', cmd: 'free -h', category: '系统', uses: 45 },
      { id: 'c3', name: '磁盘空间', cmd: 'df -h', category: '系统', uses: 67 },
      { id: 'c4', name: '查看监听端口', cmd: 'ss -tlnp', category: '网络', uses: 31 },
      { id: 'c5', name: '查看 TCP 连接数', cmd: 'ss -s', category: '网络', uses: 18 },
      { id: 'c6', name: '实时网络流量', cmd: 'iftop -n -N', category: '网络', uses: 9 },
      { id: 'c7', name: '查看系统负载', cmd: 'uptime', category: '系统', uses: 89 },
      { id: 'c8', name: 'Docker 容器列表', cmd: 'docker ps -a', category: 'Docker', uses: 52 },
      { id: 'c9', name: 'Docker 资源占用', cmd: 'docker stats --no-stream', category: 'Docker', uses: 28 },
      { id: 'c10', name: '查看登录记录', cmd: 'last -n 20', category: '安全', uses: 14 },
      { id: 'c11', name: '查看失败登录', cmd: 'grep "Failed password" /var/log/auth.log | tail -20', category: '安全', uses: 6 },
      { id: 'c12', name: '重启 Nginx', cmd: 'systemctl restart nginx', category: '服务', uses: 12 }
    ];

    for (const c of defaultCommands) {
      await DatabaseHelper.addCommand(c);
    }
  }
}
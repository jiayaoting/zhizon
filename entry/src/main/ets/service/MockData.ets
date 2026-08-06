// 智子 - Mock 数据（MVP 阶段使用）

import { Server, PveCluster, Vm, Storage, PveTask, Snapshot, Command, Alert, FileItem } from '../model/Models';

export class MockData {
  // ===== SSH 服务器 =====
  static readonly servers: Server[] = [
    {
      id: 'srv-001', name: 'prod-web-01', host: '192.168.1.10', port: 22, username: 'root',
      authType: 'key', connectionMode: 'agent', group: '生产', tags: ['web', 'nginx'], os: 'Ubuntu 22.04 LTS',
      status: 'online', lastConnected: Date.now() - 3600000, createdAt: Date.now() - 86400000 * 30,
      metrics: { cpu: 18, mem: 45, disk: 62, netIn: 12, netOut: 8, load: 0.42, uptime: 4523600 }
    },
    {
      id: 'srv-002', name: 'prod-db-master', host: '192.168.1.20', port: 22, username: 'root',
      authType: 'key', connectionMode: 'agent', group: '生产', tags: ['mysql', 'master'], os: 'Debian 12',
      status: 'warning', lastConnected: Date.now() - 7200000, createdAt: Date.now() - 86400000 * 60,
      metrics: { cpu: 78, mem: 82, disk: 71, netIn: 5, netOut: 2, load: 2.18, uptime: 3892000 }
    },
    {
      id: 'srv-003', name: 'dev-test-01', host: '192.168.1.30', port: 22, username: 'ubuntu',
      authType: 'password', connectionMode: 'direct', group: '测试', tags: ['docker'], os: 'Ubuntu 24.04 LTS',
      status: 'online', lastConnected: Date.now() - 1800000, createdAt: Date.now() - 86400000 * 10,
      metrics: { cpu: 5, mem: 22, disk: 38, netIn: 1, netOut: 1, load: 0.08, uptime: 890000 }
    },
    {
      id: 'srv-004', name: 'monitor-grafana', host: '192.168.1.40', port: 22, username: 'root',
      authType: 'key', connectionMode: 'agent', group: '监控', tags: ['grafana', 'prometheus'], os: 'CentOS Stream 9',
      status: 'online', lastConnected: Date.now() - 5400000, createdAt: Date.now() - 86400000 * 90,
      metrics: { cpu: 32, mem: 56, disk: 48, netIn: 18, netOut: 22, load: 0.85, uptime: 2891000 }
    },
    {
      id: 'srv-005', name: 'backup-storage', host: '192.168.1.50', port: 2222, username: 'backup',
      authType: 'password', connectionMode: 'direct', group: '备份', tags: ['minio', 'storage'], os: 'Alpine 3.19',
      status: 'offline', lastConnected: Date.now() - 86400000, createdAt: Date.now() - 86400000 * 120,
      metrics: { cpu: 0, mem: 0, disk: 0, netIn: 0, netOut: 0, load: 0, uptime: 0 }
    },
    {
      id: 'srv-006', name: 'ci-runner-01', host: '192.168.1.60', port: 22, username: 'gitlab',
      authType: 'key', connectionMode: 'agent', group: 'CI/CD', tags: ['gitlab', 'runner'], os: 'Ubuntu 22.04 LTS',
      status: 'online', lastConnected: Date.now() - 600000, createdAt: Date.now() - 86400000 * 45,
      metrics: { cpu: 65, mem: 48, disk: 55, netIn: 8, netOut: 4, load: 1.22, uptime: 1250000 }
    }
  ];

  // ===== PVE 集群 =====
  static readonly pveClusters: PveCluster[] = [
    {
      id: 'pve-001', name: 'homelab-cluster', host: '192.168.10.10', port: 8006,
      username: 'root@pam', authType: 'password', verifyTls: false,
      version: 'pve-manager/8.2.4', lastSync: '刚刚',
      nodes: [
        { id: 'n1', node: 'pve1', status: 'online', cpu: 0.32, maxcpu: 16, mem: 28.5, maxmem: 64, disk: 180, maxdisk: 480, uptime: 4523600, vmCount: 12, ctCount: 8 },
        { id: 'n2', node: 'pve2', status: 'online', cpu: 0.18, maxcpu: 16, mem: 20.1, maxmem: 64, disk: 220, maxdisk: 960, uptime: 3892000, vmCount: 8, ctCount: 5 },
        { id: 'n3', node: 'pve3', status: 'online', cpu: 0.45, maxcpu: 8, mem: 22.8, maxmem: 32, disk: 95, maxdisk: 240, uptime: 2891000, vmCount: 6, ctCount: 3 }
      ]
    }
  ];

  // ===== 虚拟机/容器 =====
  static readonly vms: Vm[] = [
    { vmid: 100, name: 'ubuntu-web', node: 'pve1', type: 'qemu', status: 'running', cpu: 0.08, mem: 2.4, maxmem: 4, maxdisk: 32, netin: 12.5, netout: 8.2, diskread: 0, diskwrite: 0.5, uptime: 1250000, tags: ['web', 'prod'], os: 'Ubuntu 22.04' },
    { vmid: 101, name: 'debian-db', node: 'pve1', type: 'qemu', status: 'running', cpu: 0.15, mem: 5.8, maxmem: 8, maxdisk: 100, netin: 4.2, netout: 1.1, diskread: 2.4, diskwrite: 1.8, uptime: 2340000, tags: ['mysql', 'prod'], os: 'Debian 12' },
    { vmid: 102, name: 'alpine-dns', node: 'pve1', type: 'lxc', status: 'running', cpu: 0.01, mem: 0.2, maxmem: 0.5, maxdisk: 4, netin: 0.5, netout: 0.3, diskread: 0, diskwrite: 0, uptime: 4100000, tags: ['dns'], os: 'Alpine 3.19' },
    { vmid: 103, name: 'centos-redis', node: 'pve1', type: 'qemu', status: 'stopped', cpu: 0, mem: 0, maxmem: 2, maxdisk: 20, netin: 0, netout: 0, diskread: 0, diskwrite: 0, uptime: 0, tags: ['redis', 'staging'], os: 'Rocky 9' },
    { vmid: 200, name: 'win10-office', node: 'pve2', type: 'qemu', status: 'running', cpu: 0.04, mem: 4.2, maxmem: 8, maxdisk: 80, netin: 1.2, netout: 0.5, diskread: 0, diskwrite: 0, uptime: 890000, tags: ['windows'], os: 'Windows 10' },
    { vmid: 201, name: 'haos-homeassistant', node: 'pve2', type: 'qemu', status: 'running', cpu: 0.06, mem: 1.8, maxmem: 4, maxdisk: 32, netin: 3.4, netout: 2.1, diskread: 0, diskwrite: 0, uptime: 3890000, tags: ['iot'], os: 'Home Assistant OS' },
    { vmid: 202, name: 'opnsense-fw', node: 'pve2', type: 'qemu', status: 'running', cpu: 0.02, mem: 0.8, maxmem: 2, maxdisk: 16, netin: 45.2, netout: 38.6, diskread: 0, diskwrite: 0, uptime: 3890000, tags: ['network'], os: 'OPNsense 24.1' },
    { vmid: 300, name: 'k8s-master', node: 'pve3', type: 'qemu', status: 'running', cpu: 0.18, mem: 4.2, maxmem: 8, maxdisk: 64, netin: 5.6, netout: 3.2, diskread: 0, diskwrite: 0, uptime: 2890000, tags: ['k8s', 'prod'], os: 'Ubuntu 24.04' },
    { vmid: 301, name: 'k8s-worker1', node: 'pve3', type: 'qemu', status: 'running', cpu: 0.22, mem: 6.8, maxmem: 16, maxdisk: 100, netin: 8.2, netout: 4.1, diskread: 0, diskwrite: 0, uptime: 2890000, tags: ['k8s', 'prod'], os: 'Ubuntu 24.04' },
    { vmid: 302, name: 'k8s-worker2', node: 'pve3', type: 'qemu', status: 'paused', cpu: 0, mem: 5.1, maxmem: 16, maxdisk: 100, netin: 0, netout: 0, diskread: 0, diskwrite: 0, uptime: 0, tags: ['k8s', 'prod'], os: 'Ubuntu 24.04' },
    { vmid: 303, name: 'gitlab-ci', node: 'pve3', type: 'lxc', status: 'stopped', cpu: 0, mem: 0, maxmem: 4, maxdisk: 60, netin: 0, netout: 0, diskread: 0, diskwrite: 0, uptime: 0, tags: ['ci'], os: 'Debian 12' }
  ];

  // ===== 存储池 =====
  static readonly storages: Storage[] = [
    { name: 'local', type: 'dir', node: 'pve1', content: 'iso,vztmpl,backup', used: 12, total: 100, status: 'active' },
    { name: 'local-lvm', type: 'lvmthin', node: 'pve1', content: 'images,rootdir', used: 168, total: 380, status: 'active' },
    { name: 'ssd-pool', type: 'zfs', node: 'pve1', content: 'images,rootdir', used: 145, total: 500, status: 'active' },
    { name: 'nas-backup', type: 'nfs', node: 'pve2', content: 'backup,iso', used: 820, total: 2000, status: 'active' },
    { name: 'local-lvm', type: 'lvmthin', node: 'pve2', content: 'images,rootdir', used: 412, total: 860, status: 'active' },
    { name: 'nvme-fast', type: 'zfs', node: 'pve3', content: 'images,rootdir', used: 80, total: 240, status: 'active' }
  ];

  // ===== PVE 任务 =====
  static readonly pveTasks: PveTask[] = [
    { id: 't1', node: 'pve1', upid: 'UPID:pve1:00012345:abc123', type: 'qmstart', status: 'running', user: 'root@pam', target: 'VM 100 (ubuntu-web)', progress: 0, startTime: '14:32:15' },
    { id: 't2', node: 'pve1', upid: 'UPID:pve1:00012346:def456', type: 'vzdump', status: 'running', user: 'root@pam', target: 'VM 101 (debian-db)', progress: 45, startTime: '14:25:08' },
    { id: 't3', node: 'pve2', upid: 'UPID:pve2:00009876:ghi789', type: 'qmstop', status: 'success', user: 'root@pam', target: 'VM 203 (nextcloud)', progress: 100, startTime: '14:10:22' },
    { id: 't4', node: 'pve3', upid: 'UPID:pve3:00008765:jkl012', type: 'qmclone', status: 'success', user: 'admin@pve', target: 'VM 300 → VM 305', progress: 100, startTime: '13:55:00' },
    { id: 't5', node: 'pve1', upid: 'UPID:pve1:00007654:mno345', type: 'qmshutdown', status: 'failed', user: 'root@pam', target: 'VM 103 (centos-redis)', progress: 0, startTime: '13:40:11', error: 'VM is not running' },
    { id: 't6', node: 'pve2', upid: 'UPID:pve2:00006543:pqr678', type: 'lxcstart', status: 'success', user: 'root@pam', target: 'CT 204 (jellyfin-media)', progress: 100, startTime: '13:20:45' }
  ];

  // ===== 快照 =====
  static readonly snapshots: Snapshot[] = [
    { name: 'pre-update-20260801', vmid: 100, date: '2026-08-01 02:00', size: '2.4 GB', desc: '系统升级前备份' },
    { name: 'weekly-auto', vmid: 100, date: '2026-07-28 03:00', size: '2.1 GB', desc: '自动周备份' },
    { name: 'pre-deploy-v2', vmid: 101, date: '2026-08-03 18:22', size: '5.8 GB', desc: '部署 v2 前' },
    { name: 'clean-state', vmid: 200, date: '2026-07-15 10:00', size: '4.2 GB', desc: '初始干净状态' }
  ];

  // ===== 快捷命令 =====
  static readonly commands: Command[] = [
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

  // ===== 告警 =====
  static readonly alerts: Alert[] = [
    { id: 'a1', level: 'critical', source: 'prod-db-master', title: 'CPU 使用率过高', detail: 'CPU 持续 5 分钟超过 85% (当前 92%)', time: '14:28', resolved: false },
    { id: 'a2', level: 'warning', source: 'prod-db-master', title: '内存使用率告警', detail: '内存使用率 82%，接近阈值 85%', time: '14:15', resolved: false },
    { id: 'a3', level: 'critical', source: 'backup-storage', title: '服务器离线', detail: 'SSH 连接超时，已离线 1 小时 12 分', time: '13:05', resolved: false },
    { id: 'a4', level: 'warning', source: 'pve1', title: 'VM 103 异常停止', detail: 'centos-redis 意外停止运行', time: '12:48', resolved: false },
    { id: 'a5', level: 'info', source: 'pve2', title: '备份任务完成', detail: 'VM 201 备份成功，耗时 8 分 32 秒', time: '11:20', resolved: true },
    { id: 'a6', level: 'warning', source: 'monitor-grafana', title: '磁盘空间不足', detail: '根分区使用率 78%', time: '10:55', resolved: false }
  ];

  // ===== 文件列表 =====
  static readonly files: FileItem[] = [
    { name: '..', type: 'dir', size: 0, modified: '-', perms: 'drwxr-xr-x' },
    { name: 'etc', type: 'dir', size: 4096, modified: '2026-08-03 14:22', perms: 'drwxr-xr-x' },
    { name: 'var', type: 'dir', size: 4096, modified: '2026-08-03 18:10', perms: 'drwxr-xr-x' },
    { name: 'home', type: 'dir', size: 4096, modified: '2026-08-02 09:15', perms: 'drwxr-xr-x' },
    { name: 'root', type: 'dir', size: 4096, modified: '2026-08-03 21:05', perms: 'drwx------' },
    { name: 'opt', type: 'dir', size: 4096, modified: '2026-07-28 11:30', perms: 'drwxr-xr-x' },
    { name: 'tmp', type: 'dir', size: 4096, modified: '2026-08-04 08:45', perms: 'drwxrwxrwt' },
    { name: '.bashrc', type: 'file', size: 3526, modified: '2026-06-15 10:00', perms: '-rw-r--r--' },
    { name: '.bash_history', type: 'file', size: 12800, modified: '2026-08-03 21:05', perms: '-rw-------' },
    { name: 'deploy.sh', type: 'file', size: 1820, modified: '2026-08-03 19:22', perms: '-rwxr-xr-x' },
    { name: 'nginx.conf.bak', type: 'file', size: 4520, modified: '2026-08-01 02:00', perms: '-rw-r--r--' },
    { name: 'system-monitor.py', type: 'file', size: 8200, modified: '2026-07-30 14:18', perms: '-rw-r--r--' }
  ];

  // 终端示例输出
  static readonly terminalLines: string[] = [
    'Last login: Mon Aug  4 09:12:35 2026 from 192.168.1.5',
    'root@prod-web-01:~# uptime',
    ' 09:15:22 up 52 days,  7:36,  2 users,  load average: 0.42, 0.38, 0.40',
    'root@prod-web-01:~# free -h',
    '               total        used        free      shared  buff/cache   available',
    'Mem:            16Gi       7.2Gi       4.8Gi       256Mi       4.0Gi       8.5Gi',
    'Swap:          2.0Gi          0B       2.0Gi',
    'root@prod-web-01:~# df -h /',
    'Filesystem      Size  Used Avail Use% Mounted on',
    '/dev/vda1        50G   31G   17G  62% /',
    'root@prod-web-01:~# docker ps',
    'CONTAINER ID   IMAGE          STATUS         PORTS                  NAMES',
    'a1b2c3d4e5f6   nginx:latest   Up 3 days      0.0.0.0:80->80/tcp     web-nginx',
    'f6e5d4c3b2a1   redis:7        Up 3 days      0.0.0.0:6379->6379/tcp web-redis',
    'root@prod-web-01:~# _'
  ];
}

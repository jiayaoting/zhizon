// 智子 - SFTP 文件管理页面
import { router, promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { AppTheme } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/StatusBadge';
import { DataRepository, formatSize } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { FileItem, Server } from '../model/Models';

// 传输队列项
interface TransferItem {
  id: string;
  name: string;
  direction: 'upload' | 'download';
  progress: number;
  speed: string;
  status: 'running' | 'success' | 'failed';
  localPath: string;
  remotePath: string;
}

@Component
export struct FilesPage {
  @StorageLink('isSm') isSm: boolean = false;
  @State files: FileItem[] = [];
  @State servers: Server[] = [];
  @State loading: boolean = true;
  @State selectedServer: Server | null = null;
  @State isConnected: boolean = false;
  @State transfers: TransferItem[] = [];
  @State showPicker: boolean = false;
  private breadcrumb: string[] = ['/'];
  private currentPath: string = '/';
  private transferCounter: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    if (this.selectedServer) {
      SshService.disconnect(this.selectedServer);
    }
  }

  private async loadData(): Promise<void> {
    try {
      const servers = await DataRepository.getServers();
      this.servers = servers;
    } catch (e) {
      console.error('FilesPage loadData failed:', JSON.stringify(e));
    } finally {
      this.loading = false;
    }
  }

  // 选择服务器并连接
  private async selectServer(server: Server): Promise<void> {
    this.selectedServer = server;
    this.loading = true;
    try {
      const ok = await SshService.testConnection(server);
      this.isConnected = ok;
      if (ok) {
        await this.navigateTo('/');
      }
    } catch (e) {
      this.isConnected = false;
    } finally {
      this.loading = false;
    }
  }

  // 导航到指定目录
  private async navigateTo(path: string): Promise<void> {
    if (!this.selectedServer) return;
    this.currentPath = path;
    this.breadcrumb = path === '/' ? ['/'] : path.split('/').filter((s: string) => s.length > 0);
    this.breadcrumb.unshift('/');
    try {
      this.files = await SshService.listFiles(this.selectedServer, path);
    } catch (e) {
      console.error('navigateTo failed:', JSON.stringify(e));
      this.files = [];
    }
  }

  // 目录点击
  private onDirClick(dir: FileItem): void {
    const newPath = this.currentPath === '/'
      ? `/${dir.name}`
      : `${this.currentPath}/${dir.name}`;
    this.navigateTo(newPath);
  }

  // 面包屑点击
  private onBreadcrumbClick(index: number): void {
    if (index === 0) {
      this.navigateTo('/');
    } else {
      const parts = this.breadcrumb.slice(1, index + 1);
      this.navigateTo('/' + parts.join('/'));
    }
  }

  // 上传文件
  private async uploadFile(): Promise<void> {
    if (!this.selectedServer) {
      promptAction.showToast({ message: '请先选择服务器' });
      return;
    }
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select();
      if (!uris || uris.length === 0) return;

      const uri = uris[0];
      const fileName = uri.substring(uri.lastIndexOf('/') + 1);
      const remotePath = this.currentPath === '/'
        ? `/${fileName}`
        : `${this.currentPath}/${fileName}`;

      this.transferCounter++;
      const transfer: TransferItem = {
        id: `transfer_${this.transferCounter}`,
        name: fileName,
        direction: 'upload',
        progress: 0,
        speed: '准备中',
        status: 'running',
        localPath: uri,
        remotePath: remotePath
      };
      this.transfers = [...this.transfers, transfer];

      const ok = await SshService.uploadFile(this.selectedServer, uri, remotePath);

      // 更新传输状态
      const idx = this.transfers.findIndex((t: TransferItem) => t.id === transfer.id);
      if (idx >= 0) {
        this.transfers[idx].status = ok ? 'success' : 'failed';
        this.transfers[idx].progress = ok ? 100 : this.transfers[idx].progress;
        this.transfers[idx].speed = ok ? '完成' : '失败';
        this.transfers = [...this.transfers];
      }

      if (ok) {
        promptAction.showToast({ message: `上传成功: ${fileName}` });
        await this.navigateTo(this.currentPath);
      } else {
        promptAction.showToast({ message: `上传失败: ${fileName}` });
      }
    } catch (e) {
      console.error('uploadFile failed:', JSON.stringify(e));
      promptAction.showToast({ message: '上传取消或失败' });
    }
  }

  // 下载文件
  private async downloadFile(file: FileItem): Promise<void> {
    if (!this.selectedServer) return;
    if (file.type === 'dir') return;

    try {
      const savePicker = new picker.DocumentViewPicker();
      // 下载到应用缓存目录
      const remotePath = this.currentPath === '/'
        ? `/${file.name}`
        : `${this.currentPath}/${file.name}`;

      this.transferCounter++;
      const transfer: TransferItem = {
        id: `transfer_${this.transferCounter}`,
        name: file.name,
        direction: 'download',
        progress: 0,
        speed: '准备中',
        status: 'running',
        localPath: '',
        remotePath: remotePath
      };
      this.transfers = [...this.transfers, transfer];

      // 使用临时路径下载
      const localPath = `${remotePath}_dl_${Date.now()}`;
      const ok = await SshService.downloadFile(this.selectedServer, remotePath, localPath);

      const idx = this.transfers.findIndex((t: TransferItem) => t.id === transfer.id);
      if (idx >= 0) {
        this.transfers[idx].status = ok ? 'success' : 'failed';
        this.transfers[idx].progress = ok ? 100 : this.transfers[idx].progress;
        this.transfers[idx].speed = ok ? '完成' : '失败';
        this.transfers[idx].localPath = localPath;
        this.transfers = [...this.transfers];
      }

      if (ok) {
        promptAction.showToast({ message: `下载成功: ${file.name}` });
      } else {
        promptAction.showToast({ message: `下载失败: ${file.name}` });
      }
    } catch (e) {
      console.error('downloadFile failed:', JSON.stringify(e));
      promptAction.showToast({ message: '下载失败' });
    }
  }

  // 清除已完成的传输
  private clearCompleted(): void {
    this.transfers = this.transfers.filter((t: TransferItem) => t.status === 'running');
  }

  @Builder actionsBuilder() {
    Row({ space: 8 }) {
      Button('选择服务器')
        .fontSize(12)
        .fontColor(this.selectedServer ? AppTheme.textSecondary : AppTheme.primary)
        .backgroundColor(this.selectedServer ? AppTheme.bgSurface2 : AppTheme.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => this.showPicker = true)
      if (this.selectedServer) {
        Button('上传')
          .fontSize(12)
          .fontColor(AppTheme.primary)
          .backgroundColor(AppTheme.primaryDim)
          .borderRadius(6)
          .height(28)
          .padding({ left: 10, right: 10 })
          .onClick(() => this.uploadFile())
      }
    }
  }

  // 服务器选择器
  @Builder serverSelector() {
    Row({ space: 10 }) {
      if (this.selectedServer) {
        Circle({ width: 8, height: 8 })
          .fill(this.isConnected ? AppTheme.success : AppTheme.danger)
        Text(`${this.selectedServer.name}`)
          .fontSize(13)
          .fontColor(AppTheme.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(`(${this.selectedServer.host}:${this.selectedServer.port})`)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
        Text(this.selectedServer.connectionMode === 'direct' ? '直连' : 'Agent')
          .fontSize(10)
          .fontColor(this.selectedServer.connectionMode === 'direct' ? AppTheme.warning : AppTheme.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .backgroundColor(this.selectedServer.connectionMode === 'direct' ? 'rgba(245,158,11,0.12)' : AppTheme.primaryDim)
      } else {
        Text('请选择服务器')
          .fontSize(13)
          .fontColor(AppTheme.textTertiary)
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(AppTheme.textTertiary)
      }
      Blank()
      if (this.selectedServer) {
        Button('切换')
          .fontSize(11)
          .fontColor(AppTheme.textSecondary)
          .backgroundColor(AppTheme.bgSurface2)
          .borderRadius(5)
          .height(26)
          .padding({ left: 10, right: 10 })
          .onClick(() => this.showPicker = true)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(AppTheme.bgSurface)
    .border({ width: { bottom: 0.5 }, color: AppTheme.borderSubtle })
    .onClick(() => {
      if (!this.selectedServer) {
        this.showPicker = true;
      }
    })
  }

  // 面包屑项
  @Builder crumbItem(c: string, idx: number) {
    Row({ space: 4 }) {
      Text(c)
        .fontSize(12)
        .fontColor(idx === this.breadcrumb.length - 1 ? AppTheme.textPrimary : AppTheme.primary)
        .onClick(() => this.onBreadcrumbClick(idx))
      if (idx < this.breadcrumb.length - 1) {
        Text('>')
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  // 远程文件行
  @Builder remoteFileRow(f: FileItem) {
    Row() {
      Text(f.type === 'dir' ? '📁' : '📄')
        .fontSize(14)
      Text(f.name)
        .fontSize(12)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
        .margin({ left: 8 })
        .onClick(() => {
          if (f.type === 'dir') {
            this.onDirClick(f);
          } else {
            this.downloadFile(f);
          }
        })
      Text(f.modified)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .width(100)
      Text(f.type === 'file' && f.size > 0 ? formatSize(f.size) : '-')
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(60)
      Text(f.perms)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(80)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({
      width: { bottom: 0.5 },
      color: AppTheme.borderSubtle
    })
    .alignItems(VerticalAlign.Center)
  }

  // 传输队列项
  @Builder transferRow(t: TransferItem) {
    Column({ space: 6 }) {
      Row() {
        Text(t.direction === 'upload' ? '⬆' : '⬇')
          .fontSize(14)
          .fontColor(t.direction === 'upload' ? AppTheme.info : AppTheme.success)
        Text(t.name)
          .fontSize(12)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
          .margin({ left: 6 })
        Text(t.speed)
          .fontSize(10)
          .fontColor(AppTheme.textTertiary)
          .fontFamily(AppTheme.fontMono)
          .margin({ right: 8 })
        StatusBadge({ status: t.status, badgeSize: 'small' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      ProgressBar({ value: t.progress, showLabel: true, barHeight: 4 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(AppTheme.bgSurface2)
  }

  build() {
    Stack() {
    Column() {
      TopBar({ title: '文件管理', subtitle: this.isConnected ? `${this.selectedServer?.host} · 已连接` : 'SFTP 文件浏览' }) {
        this.actionsBuilder()
      }

      // 服务器选择器
      this.serverSelector()

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(AppTheme.primary)
          Text('加载中...')
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 面包屑导航
            if (this.isConnected) {
              Row({ space: 4 }) {
                ForEach(this.breadcrumb, (c: string, idx: number) => {
                  this.crumbItem(c, idx)
                }, (c: string, idx: number) => `${c}-${idx}`)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }

            // 双栏布局
            Row() {
              // 左栏：本地操作
              Column({ space: 8 }) {
                Text('本地')
                  .fontSize(12)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Column({ space: 6 }) {
                  Text('📂')
                    .fontSize(28)
                  Text('选择文件上传')
                    .fontSize(12)
                    .fontColor(AppTheme.textTertiary)
                  Button('选择文件')
                    .fontSize(11)
                    .fontColor(AppTheme.bgBase)
                    .backgroundColor(AppTheme.primary)
                    .borderRadius(4)
                    .height(28)
                    .margin({ top: 8 })
                    .onClick(() => this.uploadFile())
                }
                .width('100%')
                .padding({ top: 20, bottom: 20 })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              }
              .layoutWeight(1)
              .padding(12)
              .backgroundColor(AppTheme.bgSurface)
              .borderRadius(10)
              .border({ width: 1, color: AppTheme.borderSubtle })
              .alignItems(HorizontalAlign.Start)

              // 中间分隔线
              Divider()
                .vertical(true)
                .height('100%')
                .strokeWidth(1)
                .color(AppTheme.borderSubtle)

              // 右栏：远程目录
              Column({ space: 8 }) {
                Text(`远程${this.isConnected ? ` - ${this.currentPath}` : ' - 未连接'}`)
                  .fontSize(12)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (!this.isConnected) {
                  Column({ space: 6 }) {
                    Text('🔌')
                      .fontSize(28)
                    Text('请先选择并连接服务器')
                      .fontSize(12)
                      .fontColor(AppTheme.textTertiary)
                  }
                  .width('100%')
                  .padding({ top: 24, bottom: 24 })
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else if (this.files.length === 0) {
                  Column({ space: 6 }) {
                    Text('📭')
                      .fontSize(28)
                    Text('目录为空')
                      .fontSize(12)
                      .fontColor(AppTheme.textTertiary)
                  }
                  .width('100%')
                  .padding({ top: 24, bottom: 24 })
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else {
                  ForEach(this.files, (f: FileItem) => {
                    this.remoteFileRow(f)
                  }, (f: FileItem) => f.name)
                }
              }
              .layoutWeight(1)
              .padding(12)
              .backgroundColor(AppTheme.bgSurface)
              .borderRadius(10)
              .border({ width: 1, color: AppTheme.borderSubtle })
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .width('100%')

            // 底部传输队列
            Column({ space: 8 }) {
              Row() {
                Text('传输队列')
                  .fontSize(AppTheme.fsMd)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Blank()
                if (this.transfers.some((t: TransferItem) => t.status !== 'running')) {
                  Button('清除已完成')
                    .fontSize(10)
                    .fontColor(AppTheme.textTertiary)
                    .backgroundColor('transparent')
                    .height(24)
                    .onClick(() => this.clearCompleted())
                }
              }
              .width('100%')

              if (this.transfers.length === 0) {
                Text('暂无传输任务')
                  .fontSize(11)
                  .fontColor(AppTheme.textTertiary)
                  .padding({ top: 8, bottom: 8 })
              } else {
                ForEach(this.transfers, (t: TransferItem) => {
                  this.transferRow(t)
                }, (t: TransferItem) => t.id)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .padding(this.isSm ? 12 : 20)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(AppTheme.bgBase)

    // 自定义服务器选择弹窗
    if (this.showPicker) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .onClick(() => {
            this.showPicker = false;
          })

        Column({ space: 0 }) {
          Row() {
            Text('选择服务器')
              .fontSize(16)
              .fontColor(AppTheme.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Button({ type: ButtonType.Circle }) {
              Text('✕')
                .fontSize(14)
                .fontColor(AppTheme.textTertiary)
            }
            .width(28)
            .height(28)
            .backgroundColor(AppTheme.bgSurface2)
            .onClick(() => {
              this.showPicker = false;
            })
          }
          .width('100%')
          .padding({ left: 20, right: 16, top: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center)

          Text(`共 ${this.servers.length} 台服务器`)
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 12 })

          Divider()
            .width('100%')
            .strokeWidth(0.5)
            .color(AppTheme.borderSubtle)

          if (this.servers.length === 0) {
            Column({ space: 8 }) {
              Text('📡')
                .fontSize(36)
              Text('暂无服务器')
                .fontSize(14)
                .fontColor(AppTheme.textTertiary)
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            Scroll() {
              Column({ space: 0 }) {
                ForEach(this.servers, (s: Server) => {
                  Column() {
                    Row({ space: 12 }) {
                      Column() {
                        Text(s.name)
                          .fontSize(14)
                          .fontColor(AppTheme.textPrimary)
                          .fontWeight(FontWeight.Medium)
                        Text(`${s.host}:${s.port}`)
                          .fontSize(11)
                          .fontColor(AppTheme.textTertiary)
                          .fontFamily(AppTheme.fontMono)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Text(s.connectionMode === 'direct' ? '直连' : 'Agent')
                        .fontSize(10)
                        .fontColor(s.connectionMode === 'direct' ? AppTheme.warning : AppTheme.primary)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(4)
                        .backgroundColor(s.connectionMode === 'direct' ? 'rgba(245,158,11,0.12)' : AppTheme.primaryDim)
                    }
                    .width('100%')
                    .padding({ left: 20, right: 16, top: 14, bottom: 14 })
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => {
                      this.showPicker = false;
                      this.selectServer(s);
                    })

                    Divider()
                      .width('100%')
                      .strokeWidth(0.5)
                      .color(AppTheme.borderSubtle)
                      .margin({ left: 20 })
                  }
                  .width('100%')
                }, (s: Server) => s.id)
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .constraintSize({ maxHeight: this.isSm ? 380 : 480 })
          }
        }
        .width(this.isSm ? '90%' : '72%')
        .constraintSize({ maxWidth: 480 })
        .borderRadius(16)
        .backgroundColor(AppTheme.bgSurface)
        .shadow({
          radius: 24,
          color: 'rgba(0,0,0,0.4)',
          offsetY: 8
        })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
    }
  }
}

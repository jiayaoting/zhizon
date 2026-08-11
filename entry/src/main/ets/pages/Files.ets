// 智子 - SFTP 文件管理页面
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { picker } from '@kit.CoreFileKit';
import { ThemePalette, defaultLightPalette } from '../common/Theme';
import { TopBar } from '../components/TopBar';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/StatusBadge';
import { GlassStyle, GlassLevel } from '../components/GlassEffect';
import { ArrayDataSource } from '../common/ArrayDataSource';
import { DataRepository, formatSize } from '../service/DataRepository';
import { SshService } from '../service/SshService';
import { FileItem, Server } from '../model/Models';
import { RemoteResult } from '../model/GovernanceModels';
import { RemoteResultAdapter } from '../service/RemoteResultAdapter';

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
  @StorageLink('themePalette') palette: ThemePalette = defaultLightPalette;
  @StorageLink('glassEffectEnabled') glassEnabled: boolean = false;
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
  private filesDataSource: ArrayDataSource<FileItem> = new ArrayDataSource<FileItem>();

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
      hilog.error(0x9201, 'Files', '%{public}s', 'operation=files-init category=PROTOCOL code=FILES_INIT_FAILED rollback=preserved');
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
    try {
      const result: RemoteResult<FileItem[]> = await SshService.listFiles(this.selectedServer, path);
      if (result.success && result.value !== null) {
        this.files = result.value;
        this.filesDataSource.reloadAll(result.value);
        this.currentPath = path;
        const nextBreadcrumb: string[] = path === '/' ? ['/'] :
          path.split('/').filter((segment: string) => segment.length > 0);
        if (path !== '/') nextBreadcrumb.unshift('/');
        this.breadcrumb = nextBreadcrumb;
      } else {
        RemoteResultAdapter.logFailure('files-list', result);
        promptAction.showToast({ message: RemoteResultAdapter.publicMessage(result) });
      }
    } catch (e) {
      hilog.error(0x9201, 'Files', '%{public}s', 'operation=files-list category=PROTOCOL code=FILES_LIST_FAILED rollback=preserved');
      promptAction.showToast({ message: '目录加载失败，已保留当前列表' });
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

      const result: RemoteResult<boolean> = await SshService.uploadFile(this.selectedServer, uri, remotePath);
      const ok: boolean = result.success;

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
      hilog.error(0x9201, 'Files', '%{public}s', 'operation=files-upload category=PROTOCOL code=FILES_UPLOAD_FAILED rollback=preserved');
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
      const result: RemoteResult<boolean> = await SshService.downloadFile(this.selectedServer, remotePath, localPath);
      const ok: boolean = result.success;

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
      hilog.error(0x9201, 'Files', '%{public}s', 'operation=files-download category=PROTOCOL code=FILES_DOWNLOAD_FAILED rollback=preserved');
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
        .fontColor(this.selectedServer ? this.palette.textSecondary : this.palette.primary)
        .backgroundColor(this.selectedServer ? this.palette.bgSurface2 : this.palette.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => this.showPicker = true)
      if (this.selectedServer) {
        Button('上传')
          .fontSize(12)
          .fontColor(this.palette.primary)
          .backgroundColor(this.palette.primaryDim)
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
          .fill(this.isConnected ? this.palette.success : this.palette.danger)
        Text(`${this.selectedServer.name}`)
          .fontSize(13)
          .fontColor(this.palette.textPrimary)
          .fontWeight(FontWeight.Medium)
        Text(`(${this.selectedServer.host}:${this.selectedServer.port})`)
          .fontSize(11)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontMono)
        Text(this.selectedServer.connectionMode === 'direct' ? '直连' : 'Agent')
          .fontSize(10)
          .fontColor(this.selectedServer.connectionMode === 'direct' ? this.palette.warning : this.palette.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .backgroundColor(this.selectedServer.connectionMode === 'direct' ? 'rgba(245,158,11,0.12)' : this.palette.primaryDim)
      } else {
        Text('请选择服务器')
          .fontSize(13)
          .fontColor(this.palette.textTertiary)
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(this.palette.textTertiary)
      }
      Blank()
      if (this.selectedServer) {
        Button('切换')
          .fontSize(11)
          .fontColor(this.palette.textSecondary)
          .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
          .borderRadius(5)
          .height(26)
          .padding({ left: 10, right: 10 })
          .onClick(() => this.showPicker = true)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
    .border({ width: { bottom: 0.5 }, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
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
        .fontColor(idx === this.breadcrumb.length - 1 ? this.palette.textPrimary : this.palette.primary)
        .onClick(() => this.onBreadcrumbClick(idx))
      if (idx < this.breadcrumb.length - 1) {
        Text('>')
          .fontSize(12)
          .fontColor(this.palette.textTertiary)
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
        .fontColor(this.palette.textPrimary)
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
        .fontColor(this.palette.textTertiary)
        .width(100)
      Text(f.type === 'file' && f.size > 0 ? formatSize(f.size) : '-')
        .fontSize(10)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontMono)
        .width(60)
      Text(f.perms)
        .fontSize(10)
        .fontColor(this.palette.textTertiary)
        .fontFamily(this.palette.fontMono)
        .width(80)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({
      width: { bottom: 0.5 },
      color: this.palette.borderSubtle
    })
    .alignItems(VerticalAlign.Center)
  }

  // 传输队列项
  @Builder transferRow(t: TransferItem) {
    Column({ space: 6 }) {
      Row() {
        Text(t.direction === 'upload' ? '⬆' : '⬇')
          .fontSize(14)
          .fontColor(t.direction === 'upload' ? this.palette.info : this.palette.success)
        Text(t.name)
          .fontSize(12)
          .fontColor(this.palette.textPrimary)
          .layoutWeight(1)
          .margin({ left: 6 })
        Text(t.speed)
          .fontSize(10)
          .fontColor(this.palette.textTertiary)
          .fontFamily(this.palette.fontMono)
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
    .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
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
            .color(this.palette.primary)
          Text('加载中...')
            .fontSize(12)
            .fontColor(this.palette.textTertiary)
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
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Column({ space: 6 }) {
                  Text('📂')
                    .fontSize(28)
                  Text('选择文件上传')
                    .fontSize(12)
                    .fontColor(this.palette.textTertiary)
                  Button('选择文件')
                    .fontSize(11)
                    .fontColor(this.palette.bgBase)
                    .backgroundColor(this.palette.primary)
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
              .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
              .borderRadius(10)
              .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
              .alignItems(HorizontalAlign.Start)

              // 中间分隔线
              Divider()
                .vertical(true)
                .height('100%')
                .strokeWidth(1)
                .color(this.palette.borderSubtle)

              // 右栏：远程目录
              Column({ space: 8 }) {
                Text(`远程${this.isConnected ? ` - ${this.currentPath}` : ' - 未连接'}`)
                  .fontSize(12)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (!this.isConnected) {
                  Column({ space: 6 }) {
                    Text('🔌')
                      .fontSize(28)
                    Text('请先选择并连接服务器')
                      .fontSize(12)
                      .fontColor(this.palette.textTertiary)
                  }
                  .width('100%')
                  .padding({ top: 24, bottom: 24 })
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else if (this.filesDataSource.totalCount() === 0) {
                  Column({ space: 6 }) {
                    Text('📭')
                      .fontSize(28)
                    Text('目录为空')
                      .fontSize(12)
                      .fontColor(this.palette.textTertiary)
                  }
                  .width('100%')
                  .padding({ top: 24, bottom: 24 })
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else {
                  List() {
                    LazyForEach(this.filesDataSource, (f: FileItem) => {
                      ListItem() {
                        this.remoteFileRow(f)
                      }
                    }, (f: FileItem) => f.name)
                  }
                  .width('100%')
                  .scrollBar(BarState.Auto)
                }
              }
              .layoutWeight(1)
              .padding(12)
              .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
              .borderRadius(10)
              .border({ width: 1, color: GlassStyle.borderColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette) })
              .alignItems(HorizontalAlign.Start)
            }
            .layoutWeight(1)
            .width('100%')

            // 底部传输队列
            Column({ space: 8 }) {
              Row() {
                Text('传输队列')
                  .fontSize(this.palette.fsMd)
                  .fontColor(this.palette.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Blank()
                if (this.transfers.some((t: TransferItem) => t.status !== 'running')) {
                  Button('清除已完成')
                    .fontSize(10)
                    .fontColor(this.palette.textTertiary)
                    .backgroundColor('transparent')
                    .height(24)
                    .onClick(() => this.clearCompleted())
                }
              }
              .width('100%')

              if (this.transfers.length === 0) {
                Text('暂无传输任务')
                  .fontSize(11)
                  .fontColor(this.palette.textTertiary)
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
              .fontColor(this.palette.textPrimary)
              .fontWeight(FontWeight.Bold)
            Blank()
            Button({ type: ButtonType.Circle }) {
              Text('✕')
                .fontSize(14)
                .fontColor(this.palette.textTertiary)
            }
            .width(28)
            .height(28)
            .backgroundColor(GlassStyle.innerBackgroundColor(this.glassEnabled, this.palette))
            .onClick(() => {
              this.showPicker = false;
            })
          }
          .width('100%')
          .padding({ left: 20, right: 16, top: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center)

          Text(`共 ${this.servers.length} 台服务器`)
            .fontSize(12)
            .fontColor(this.palette.textTertiary)
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 12 })

          Divider()
            .width('100%')
            .strokeWidth(0.5)
            .color(this.palette.borderSubtle)

          if (this.servers.length === 0) {
            Column({ space: 8 }) {
              Text('📡')
                .fontSize(36)
              Text('暂无服务器')
                .fontSize(14)
                .fontColor(this.palette.textTertiary)
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
                          .fontColor(this.palette.textPrimary)
                          .fontWeight(FontWeight.Medium)
                        Text(`${s.host}:${s.port}`)
                          .fontSize(11)
                          .fontColor(this.palette.textTertiary)
                          .fontFamily(this.palette.fontMono)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      Text(s.connectionMode === 'direct' ? '直连' : 'Agent')
                        .fontSize(10)
                        .fontColor(s.connectionMode === 'direct' ? this.palette.warning : this.palette.primary)
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(4)
                        .backgroundColor(s.connectionMode === 'direct' ? 'rgba(245,158,11,0.12)' : this.palette.primaryDim)
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
                      .color(this.palette.borderSubtle)
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
        .backgroundColor(GlassStyle.backgroundColor(this.glassEnabled, GlassLevel.P2_LIST, this.palette))
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

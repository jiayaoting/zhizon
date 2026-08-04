// 智子 - SFTP 文件管理页面
import { router, promptAction } from '@kit.ArkUI';
import { AppTheme } from '../common/Theme';
import { NavSidebar } from '../components/NavSidebar';
import { TopBar } from '../components/TopBar';
import { ProgressBar } from '../components/ProgressBar';
import { StatusBadge } from '../components/StatusBadge';
import { DataRepository, formatSize } from '../service/DataRepository';
import { FileItem } from '../model/Models';

// 本地文件占位数据
interface LocalFile {
  name: string;
  modified: string;
  size: string;
  perms: string;
}

// 传输队列项
interface TransferItem {
  name: string;
  progress: number;
  speed: string;
  status: string;
}

@Entry
@Component
struct FilesPage {
  @State activeNav: string = 'Files';
  private remoteFiles: FileItem[] = DataRepository.getFiles();
  private breadcrumb: string[] = ['/', 'root', 'logs'];
  private localFiles: LocalFile[] = [
    { name: 'Documents', modified: '2026-08-03 14:22', size: '-', perms: 'drwxr-xr-x' },
    { name: 'Downloads', modified: '2026-08-04 08:10', size: '-', perms: 'drwxr-xr-x' },
    { name: 'Desktop', modified: '2026-08-02 09:15', size: '-', perms: 'drwxr-xr-x' },
    { name: 'projects', modified: '2026-08-03 21:05', size: '-', perms: 'drwxr-xr-x' },
    { name: '.ssh', modified: '2026-06-15 10:00', size: '-', perms: 'drwx------' }
  ];
  private transfers: TransferItem[] = [
    { name: 'deploy.sh', progress: 50, speed: '1.2 MB/s', status: 'running' },
    { name: 'nginx.conf.bak', progress: 80, speed: '0.8 MB/s', status: 'running' }
  ];

  @Builder actionsBuilder() {
    Row({ space: 8 }) {
      Button('上传')
        .fontSize(12)
        .fontColor(AppTheme.primary)
        .backgroundColor(AppTheme.primaryDim)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          promptAction.showToast({ message: '选择上传文件' });
        })
      Button('下载')
        .fontSize(12)
        .fontColor(AppTheme.bgBase)
        .backgroundColor(AppTheme.primary)
        .borderRadius(6)
        .height(28)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          promptAction.showToast({ message: '选择下载文件' });
        })
    }
  }

  // 面包屑项
  @Builder crumbItem(c: string, idx: number) {
    Row({ space: 6 }) {
      Text(c)
        .fontSize(12)
        .fontColor(idx === this.breadcrumb.length - 1 ? AppTheme.textPrimary : AppTheme.primary)
        .onClick(() => {
          promptAction.showToast({ message: `跳转 ${c}` });
        })
      if (idx < this.breadcrumb.length - 1) {
        Text('>')
          .fontSize(12)
          .fontColor(AppTheme.textTertiary)
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  // 本地文件行
  @Builder localFileRow(f: LocalFile) {
    Row() {
      Text('📁')
        .fontSize(14)
      Text(f.name)
        .fontSize(12)
        .fontColor(AppTheme.textPrimary)
        .layoutWeight(1)
        .margin({ left: 8 })
      Text(f.modified)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .width(120)
      Text(f.size)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(60)
      Text(f.perms)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(100)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
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
      Text(f.modified)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .width(120)
      Text(f.type === 'file' ? formatSize(f.size) : '-')
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(60)
      Text(f.perms)
        .fontSize(10)
        .fontColor(AppTheme.textTertiary)
        .fontFamily(AppTheme.fontMono)
        .width(100)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // 传输队列项
  @Builder transferRow(t: TransferItem) {
    Column({ space: 6 }) {
      Row() {
        Text(t.name)
          .fontSize(12)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
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
    Row() {
      NavSidebar({
        activeKey: this.activeNav,
        onSelect: (key: string) => {
          router.replaceUrl({ url: `pages/${key}` }).catch(() => {});
        }
      })
      Column() {
        TopBar({ title: '文件管理', subtitle: 'SFTP 双栏浏览' }) {
          this.actionsBuilder()
        }
        Scroll() {
          Column({ space: 16 }) {
            // 面包屑导航
            Row({ space: 6 }) {
              ForEach(this.breadcrumb, (c: string, idx: number) => {
                this.crumbItem(c, idx)
              }, (c: string) => c)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 双栏布局
            Row() {
              // 左栏：本地
              Column({ space: 8 }) {
                Text('本地 - /Users/you')
                  .fontSize(12)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                ForEach(this.localFiles, (f: LocalFile) => {
                  this.localFileRow(f)
                }, (f: LocalFile) => f.name)
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

              // 右栏：远程
              Column({ space: 8 }) {
                Text('远程 - /root')
                  .fontSize(12)
                  .fontColor(AppTheme.textPrimary)
                  .fontWeight(FontWeight.Bold)
                ForEach(this.remoteFiles, (f: FileItem) => {
                  this.remoteFileRow(f)
                }, (f: FileItem) => f.name)
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
              Text('传输队列')
                .fontSize(AppTheme.fsMd)
                .fontColor(AppTheme.textPrimary)
                .fontWeight(FontWeight.Bold)
              ForEach(this.transfers, (t: TransferItem) => {
                this.transferRow(t)
              }, (t: TransferItem) => t.name)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .padding(24)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(AppTheme.bgBase)
    }
    .height('100%')
    .backgroundColor(AppTheme.bgBase)
  }
}

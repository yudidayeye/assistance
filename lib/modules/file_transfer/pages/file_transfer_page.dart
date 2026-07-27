import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../services/file_server_service.dart';
import '../services/transfer_service.dart';
import '../models/transfer_record.dart';
import '../../../shared/utils/format_utils.dart';

/// 文件互传主页面
class FileTransferPage extends StatefulWidget {
  const FileTransferPage({super.key});

  @override
  State<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends State<FileTransferPage> {
  final _server = FileServerService.instance;
  List<TransferRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _server.addListener(_onChanged);
    TransferService.instance.addListener(_onChanged);
    _loadRecords();
  }

  @override
  void dispose() {
    _server.removeListener(_onChanged);
    TransferService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecords() async {
    _recentRecords = await TransferService.instance.getRecords(limit: 5);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(appTheme),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildServerCard(appTheme),
                    if (_server.isRunning) ...[
                      const SizedBox(height: 16),
                      _buildSharedFilesCard(appTheme),
                    ],
                    if (_server.receivedFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildReceivedFilesCard(appTheme),
                    ],
                    const SizedBox(height: 16),
                    _buildHistoryCard(appTheme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 头部导航 ====================

  Widget _buildHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    final headerHeight = safeTop + 58;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        height: headerHeight,
        child: Container(
          color: appTheme.cream,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 28,
                    height: 40,
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: appTheme.earth, size: 20),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '文件互传',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 服务器卡片 ====================

  Widget _buildServerCard(AppThemeExtension appTheme) {
    final running = _server.isRunning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.dns_rounded, color: appTheme.primary, size: 24),
              const SizedBox(width: 10),
              Text('手机服务器',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
              const Spacer(),
              _statusBadge(running ? '运行中' : '已停止', running, appTheme),
            ],
          ),

          if (running) ...[
            const SizedBox(height: 16),
            // 访问地址
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appTheme.cream,
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Text('访问地址', style: TextStyle(fontSize: 13, color: appTheme.earthLight)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'http://${_server.localIp}:${_server.port}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: appTheme.earth, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _copyAddress,
                    child: Icon(Icons.copy_rounded, size: 18, color: appTheme.primary.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 连接码
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: appTheme.primary),
                      const SizedBox(width: 6),
                      Text('连接码',
                          style: TextStyle(fontSize: 13, color: appTheme.earthLight, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _refreshCode,
                        child: Icon(Icons.refresh_rounded, size: 18, color: appTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _server.connectionCode ?? '------',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 10,
                            color: appTheme.earth),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _copyCode,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: appTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.copy_rounded, size: 18, color: appTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('电脑浏览器输入此码才能访问',
                      style: TextStyle(fontSize: 12, color: appTheme.earthLight)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 选择文件分享
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickAndShareFiles,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('选择文件分享到电脑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _stopServer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTheme.rose,
                  side: BorderSide(color: appTheme.rose.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('停止服务器'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('启动服务器'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 共享文件列表卡片 ====================

  Widget _buildSharedFilesCard(AppThemeExtension appTheme) {
    final sharedFiles = _server.sharedFiles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared_rounded, color: appTheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('已分享的文件',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
              const Spacer(),
              Text('${sharedFiles.length} 个文件',
                  style: TextStyle(fontSize: 13, color: appTheme.earthLight)),
            ],
          ),
          const SizedBox(height: 12),
          if (sharedFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('点击「选择文件分享到电脑」添加文件',
                    style: TextStyle(fontSize: 14, color: appTheme.earthLight.withValues(alpha: 0.6))),
              ),
            )
          else
            ...sharedFiles.map((f) => _buildFileItem(f, appTheme)),
        ],
      ),
    );
  }

  Widget _buildFileItem(SharedFile file, AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(_fileIcon(file.name), size: 22, color: appTheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: TextStyle(fontSize: 14, color: appTheme.earth, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(FormatUtils.formatFileSize(file.size),
                    style: TextStyle(fontSize: 12, color: appTheme.earthLight)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeSharedFile(file),
            child: Icon(Icons.close_rounded, size: 18, color: appTheme.earthLight),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return Icons.video_file_rounded;
    if (['mp3', 'wav', 'flac', 'aac'].contains(ext)) return Icons.audio_file_rounded;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx', 'txt', 'md'].contains(ext)) return Icons.description_rounded;
    if (['zip', 'rar', '7z', 'tar'].contains(ext)) return Icons.archive_rounded;
    return Icons.insert_drive_file_rounded;
  }

  // ==================== 收到的文件卡片 ====================

  Widget _buildReceivedFilesCard(AppThemeExtension appTheme) {
    final files = _server.receivedFiles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.downloading_rounded, color: appTheme.sage, size: 22),
              const SizedBox(width: 8),
              Text('收到的文件',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
              const Spacer(),
              Text('${files.length} 个',
                  style: TextStyle(fontSize: 13, color: appTheme.earthLight)),
            ],
          ),
          const SizedBox(height: 4),
          Text('来自电脑上传，保存在 Download 目录',
              style: TextStyle(fontSize: 12, color: appTheme.earthLight.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          ...files.take(10).map((f) => _buildReceivedFileItem(f, appTheme)),
        ],
      ),
    );
  }

  Widget _buildReceivedFileItem(SharedFile file, AppThemeExtension appTheme) {
    return GestureDetector(
      onTap: () => _openFile(file),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(_fileIcon(file.name), size: 22, color: appTheme.sage.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: TextStyle(fontSize: 14, color: appTheme.earth, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(file.path,
                      style: TextStyle(fontSize: 11, color: appTheme.earthLight.withValues(alpha: 0.7)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(FormatUtils.formatFileSize(file.size),
                      style: TextStyle(fontSize: 12, color: appTheme.earthLight)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 18, color: appTheme.primary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  // ==================== 传输历史卡片 ====================

  Widget _buildHistoryCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: appTheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('最近传输',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('暂无传输记录',
                    style: TextStyle(fontSize: 14, color: appTheme.earthLight.withValues(alpha: 0.5))),
              ),
            )
          else
            ...(_recentRecords.map((r) => _buildRecordItem(r, appTheme))),
        ],
      ),
    );
  }

  Widget _buildRecordItem(TransferRecord record, AppThemeExtension appTheme) {
    final isUpload = record.direction == TransferDirection.upload;
    final icon = isUpload ? Icons.upload_rounded : Icons.download_rounded;
    final dirText = isUpload ? '手机→电脑' : '电脑→手机';
    final statusIcon = switch (record.status) {
      TransferStatus.completed => Icons.check_circle_rounded,
      TransferStatus.failed => Icons.error_rounded,
      TransferStatus.transferring => Icons.sync_rounded,
      _ => Icons.schedule_rounded,
    };
    final statusColor = switch (record.status) {
      TransferStatus.completed => appTheme.sage,
      TransferStatus.failed => appTheme.rose,
      TransferStatus.transferring => appTheme.primary,
      _ => appTheme.earthLight,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isUpload ? appTheme.primary : appTheme.sage),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.fileName,
                    style: TextStyle(fontSize: 14, color: appTheme.earth, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$dirText · ${FormatUtils.formatFileSize(record.fileSize)}',
                    style: TextStyle(fontSize: 12, color: appTheme.earthLight)),
              ],
            ),
          ),
          Icon(statusIcon, size: 18, color: statusColor),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================

  BoxDecoration _cardDecoration(AppThemeExtension appTheme) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(appTheme.radiusLg),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
  );

  Widget _statusBadge(String text, bool active, AppThemeExtension appTheme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: active ? appTheme.sage.withValues(alpha: 0.15) : appTheme.earthLight.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 13, color: active ? appTheme.sage : appTheme.earthLight, fontWeight: FontWeight.w500)),
  );

  // ==================== 操作方法 ====================



  Future<void> _startServer() async {
    try {
      await _server.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('启动失败: $e')));
      }
    }
  }

  Future<void> _stopServer() async => await _server.stop();

  void _refreshCode() => _server.refreshCode();

  void _copyCode() {
    final code = _server.connectionCode;
    if (code != null) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('连接码已复制'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _copyAddress() {
    final address = 'http://${_server.localIp}:${_server.port}';
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('访问地址已复制'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _pickAndShareFiles() async {
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;

      int added = 0;
      for (final file in result.files) {
        if (file.path != null) {
          _server.addSharedFile(file.name, file.path!, file.size);
          added++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 $added 个文件到分享列表'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  void _removeSharedFile(SharedFile file) {
    _server.removeSharedFile(file.name);
  }

  void _openFile(SharedFile file) {
    _copyPath(file.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制路径，请在文件管理器中粘贴查找'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: '知道了', onPressed: () {}),
        ),
      );
    }
  }

  void _copyPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('路径已复制'), duration: const Duration(seconds: 1)),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

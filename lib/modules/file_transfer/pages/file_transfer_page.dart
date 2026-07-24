import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
      backgroundColor: appTheme.cream,
      appBar: AppBar(
        title: const Text('文件互传'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: appTheme.earth,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServerCard(appTheme),
            if (_server.isRunning) ...[
              const SizedBox(height: 16),
              _buildGuideCard(appTheme),
              const SizedBox(height: 16),
              _buildSharedFilesCard(appTheme),
            ],
            if (_server.receivedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildReceivedFilesCard(appTheme),
            ],
            const SizedBox(height: 16),
            _buildHistoryCard(appTheme),
          ],
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
            // IP 和端口
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appTheme.cream,
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Column(
                children: [
                  _infoRow('访问地址', 'http://${_server.localIp}:${_server.port}', appTheme),
                  const SizedBox(height: 8),
                  _infoRow('端口', '${_server.port}', appTheme),
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

  // ==================== 操作引导卡片 ====================

  Widget _buildGuideCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: appTheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('如何使用',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuideItem(
            icon: Icons.phone_android_rounded,
            title: '手机传文件到电脑',
            steps: [
              '点击上方「选择文件分享到电脑」',
              '在电脑浏览器打开 http://${_server.localIp}:${_server.port}',
              '输入连接码 ${_server.connectionCode ?? '???'}',
              '在网页上点击文件旁的「下载」按钮',
            ],
            appTheme: appTheme,
          ),
          const Divider(height: 28),
          _buildGuideItem(
            icon: Icons.computer_rounded,
            title: '电脑传文件到手机',
            steps: [
              '在电脑浏览器打开 http://${_server.localIp}:${_server.port}',
              '输入连接码 ${_server.connectionCode ?? '???'}',
              '在网页上拖拽文件或点击上传区域选择文件',
              '文件会自动保存到手机',
            ],
            appTheme: appTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required List<String> steps,
    required AppThemeExtension appTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: appTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: appTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: appTheme.earth)),
              const SizedBox(height: 8),
              ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20, height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: appTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${e.key + 1}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: appTheme.primary)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(fontSize: 13, color: appTheme.earthLight, height: 1.4)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
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

  Widget _infoRow(String label, String value, AppThemeExtension appTheme) => Row(
    children: [
      Text(label, style: TextStyle(fontSize: 13, color: appTheme.earthLight)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: appTheme.earth, fontWeight: FontWeight.w600)),
      ),
    ],
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_extension.dart';
import '../services/file_server_service.dart';
import '../services/transfer_service.dart';
import '../services/connection_service.dart';
import '../models/transfer_record.dart';
import '../models/connection_config.dart';
import '../services/setup_script_service.dart';
import '../../../shared/utils/format_utils.dart';

/// 文件互传主页面
class FileTransferPage extends StatefulWidget {
  const FileTransferPage({super.key});

  @override
  State<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends State<FileTransferPage> {
  final _server = FileServerService.instance;
  ConnectionConfig? _activeConfig;
  List<TransferRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _server.addListener(_onChanged);
    TransferService.instance.addListener(_onChanged);
    _loadData();
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

  Future<void> _loadData() async {
    _activeConfig = await ConnectionService.instance.getDefault();
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
            const SizedBox(height: 16),
            _buildRemoteCard(appTheme),
            const SizedBox(height: 16),
            _buildHistoryCard(appTheme),
          ],
        ),
      ),
    );
  }

  // ==================== 手机服务器卡片 ====================

  Widget _buildServerCard(AppThemeExtension appTheme) {
    final running = _server.isRunning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            _infoRow('IP 地址', _server.localIp ?? '获取中...', appTheme),
            const SizedBox(height: 8),
            _infoRow('端口', '${_server.port}', appTheme),
            const SizedBox(height: 16),
            _buildCodeSection(appTheme),
            const SizedBox(height: 16),
            _actionButton('停止服务器', appTheme.rose, appTheme.rose.withValues(alpha: 0.3), _stopServer),
          ] else ...[
            const SizedBox(height: 16),
            _primaryButton('启动服务器', _startServer, appTheme),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeSection(AppThemeExtension appTheme) {
    final code = _server.connectionCode ?? '------';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                _formatCode(code),
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6,
                    color: appTheme.earth, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _copyCode,
                child: Icon(Icons.copy_rounded, size: 18, color: appTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('电脑浏览器输入此码才能访问',
                style: TextStyle(fontSize: 12, color: appTheme.earthLight)),
          ),
        ],
      ),
    );
  }

  // ==================== 访问电脑文件卡片 ====================

  Widget _buildRemoteCard(AppThemeExtension appTheme) {
    final connected = _activeConfig != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(appTheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer_rounded, color: appTheme.primary, size: 24),
              const SizedBox(width: 10),
              Text('访问电脑文件',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
            ],
          ),
          const SizedBox(height: 16),
          if (connected) ...[
            _infoRow('已连接', _activeConfig!.name, appTheme),
            const SizedBox(height: 4),
            _infoRow('地址', _activeConfig!.host, appTheme),
            const SizedBox(height: 4),
            _infoRow('共享', _activeConfig!.shareName, appTheme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _browseRemote,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.primary,
                      side: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('浏览文件'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _disconnectRemote,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.rose,
                      side: BorderSide(color: appTheme.rose.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('断开连接'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text('连接到电脑共享文件夹，浏览和传输文件',
                style: TextStyle(fontSize: 14, color: appTheme.earthLight)),
            const SizedBox(height: 16),
            _primaryButton('连接电脑', _showConnectDialog, appTheme),
          ],
        ],
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
              Icon(Icons.history_rounded, color: appTheme.primary, size: 24),
              const SizedBox(width: 10),
              Text('最近传输',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTheme.earth)),
              const Spacer(),
              if (_recentRecords.isNotEmpty)
                GestureDetector(
                  onTap: _viewAllHistory,
                  child: Text('查看全部', style: TextStyle(fontSize: 14, color: appTheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentRecords.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 40,
                        color: appTheme.earthLight.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text('暂无传输记录',
                        style: TextStyle(fontSize: 14, color: appTheme.earthLight.withValues(alpha: 0.6))),
                  ],
                ),
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
    final statusColor = switch (record.status) {
      TransferStatus.completed => appTheme.sage,
      TransferStatus.failed => appTheme.rose,
      TransferStatus.transferring => appTheme.primary,
      _ => appTheme.earthLight,
    };
    final statusText = switch (record.status) {
      TransferStatus.completed => '✓',
      TransferStatus.failed => '✗',
      TransferStatus.transferring => '…',
      _ => '⏳',
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
          Text(statusText, style: TextStyle(fontSize: 16, color: statusColor)),
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
      Text(label, style: TextStyle(fontSize: 14, color: appTheme.earthLight)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 14, color: appTheme.earth, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _primaryButton(String text, VoidCallback onPressed, AppThemeExtension appTheme) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: appTheme.primary, foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusMd)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text),
    ),
  );

  Widget _actionButton(String text, Color fg, Color border, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg, side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text),
    ),
  );

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code[0]} ${code[1]} ${code[2]} ${code[3]} ${code[4]} ${code[5]}';
    }
    return code;
  }

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

  void _disconnectRemote() async {
    if (_activeConfig != null) {
      await ConnectionService.instance.setDefault(_activeConfig!.id!);
    }
    setState(() => _activeConfig = null);
  }

  void _browseRemote() {
    // TODO: 跳转到远程浏览页面（Phase 3 SMB）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMB 远程浏览功能开发中...')),
    );
  }

  void _viewAllHistory() {
    // TODO: 跳转到传输历史页面
  }

  void _showConnectDialog() {
    final appTheme = Theme.of(context).appTheme;
    final nameController = TextEditingController(text: '家里电脑');
    final hostController = TextEditingController();
    final shareController = TextEditingController(text: r'PhoneShare$');
    final userController = TextEditingController(text: 'phone');
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusLg)),
        title: const Text('连接电脑'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController,
                decoration: const InputDecoration(labelText: '配置名称', hintText: '家里电脑')),
              const SizedBox(height: 12),
              TextField(controller: hostController,
                decoration: const InputDecoration(labelText: '电脑 IP 地址', hintText: '192.168.1.100'),
                keyboardType: TextInputType.url),
              const SizedBox(height: 12),
              TextField(controller: shareController,
                decoration: InputDecoration(labelText: '共享文件夹名', hintText: r'PhoneShare$')),
              const SizedBox(height: 12),
              TextField(controller: userController,
                decoration: const InputDecoration(labelText: '用户名')),
              const SizedBox(height: 12),
              TextField(controller: passController,
                decoration: const InputDecoration(labelText: '密码'), obscureText: true),
              const SizedBox(height: 8),
              // 生成配置脚本按钮
              TextButton.icon(
                onPressed: () {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSetupScriptDialog(
                    username: userController.text.isEmpty ? 'phone' : userController.text,
                    password: passController.text.isEmpty ? '123456' : passController.text,
                    shareName: shareController.text.replaceAll(r'$', '').isEmpty
                        ? 'PhoneShare'
                        : shareController.text.replaceAll(r'$', ''),
                  );
                },
                icon: Icon(Icons.description_outlined, size: 18, color: appTheme.primary),
                label: Text('生成电脑配置脚本', style: TextStyle(color: appTheme.primary, fontSize: 13)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final config = ConnectionConfig(
                name: nameController.text.isEmpty ? '电脑' : nameController.text,
                host: hostController.text,
                shareName: shareController.text.isEmpty ? r'PhoneShare$' : shareController.text,
                username: userController.text.isEmpty ? null : userController.text,
                password: passController.text.isEmpty ? null : passController.text,
                isDefault: true,
                createdAt: DateTime.now(),
              );
              await ConnectionService.instance.addConfig(config);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: appTheme.primary, foregroundColor: Colors.white),
            child: const Text('保存并连接'),
          ),
        ],
      ),
    );
  }

  void _showSetupScriptDialog({
    required String username,
    required String password,
    required String shareName,
  }) {
    final appTheme = Theme.of(context).appTheme;
    final script = SetupScriptService.generateBatScript(
      username: username,
      password: password,
      shareName: shareName,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(appTheme.radiusLg)),
        title: const Text('电脑配置脚本'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将以下内容保存为 .bat 文件，在电脑上以管理员身份运行：',
                style: TextStyle(fontSize: 13, color: appTheme.earthLight),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    script,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11, color: Color(0xFFD4D4D4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: script));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('脚本已复制到剪贴板'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制脚本'),
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary, foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

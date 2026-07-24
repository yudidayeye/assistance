import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_extension.dart';

/// 文件互传主页面
class FileTransferPage extends StatefulWidget {
  const FileTransferPage({super.key});

  @override
  State<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends State<FileTransferPage> {
  bool _serverRunning = false;
  String? _localIp;
  int _port = 8080;
  String? _connectionCode;
  bool _smbConnected = false;
  String? _connectedHost;

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

  /// 手机服务器卡片
  Widget _buildServerCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                color: appTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '手机服务器',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _serverRunning
                      ? appTheme.sage.withValues(alpha: 0.15)
                      : appTheme.earthLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _serverRunning ? '运行中' : '已停止',
                  style: TextStyle(
                    fontSize: 13,
                    color: _serverRunning ? appTheme.sage : appTheme.earthLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_serverRunning) ...[
            const SizedBox(height: 16),
            _buildInfoRow('IP 地址', _localIp ?? '获取中...', appTheme),
            const SizedBox(height: 8),
            _buildInfoRow('端口', '$_port', appTheme),
            const SizedBox(height: 16),
            // 连接码区域
            Container(
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
                      Text(
                        '连接码',
                        style: TextStyle(
                          fontSize: 13,
                          color: appTheme.earthLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                        _formatCode(_connectionCode ?? '------'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: appTheme.earth,
                          fontFamily: 'monospace',
                        ),
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
                    child: Text(
                      '电脑浏览器输入此码才能访问',
                      style: TextStyle(fontSize: 12, color: appTheme.earthLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _stopServer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTheme.rose,
                  side: BorderSide(color: appTheme.rose.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
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
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('启动服务器'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 访问电脑文件卡片
  Widget _buildRemoteCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.computer_rounded,
                color: appTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '访问电脑文件',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_smbConnected) ...[
            _buildInfoRow('已连接', _connectedHost ?? '', appTheme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _browseRemote,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.primary,
                      side: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('浏览文件'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _disconnectSmb,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.rose,
                      side: BorderSide(color: appTheme.rose.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('断开连接'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              '连接到电脑共享文件夹，浏览和传输文件',
              style: TextStyle(fontSize: 14, color: appTheme.earthLight),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _connectSmb,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('连接电脑'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 传输历史卡片
  Widget _buildHistoryCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: appTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '最近传输',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _viewAllHistory,
                child: Text(
                  '查看全部',
                  style: TextStyle(fontSize: 14, color: appTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 40,
                    color: appTheme.earthLight.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无传输记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: appTheme.earthLight.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppThemeExtension appTheme) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: appTheme.earthLight),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: appTheme.earth,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code[0]} ${code[1]} ${code[2]} ${code[3]} ${code[4]} ${code[5]}';
    }
    return code;
  }

  void _startServer() {
    // TODO: 实现启动服务器
    setState(() {
      _serverRunning = true;
      _localIp = '192.168.1.100';
      _connectionCode = '382916';
    });
  }

  void _stopServer() {
    // TODO: 实现停止服务器
    setState(() {
      _serverRunning = false;
      _localIp = null;
      _connectionCode = null;
    });
  }

  void _refreshCode() {
    // TODO: 实现刷新连接码
    setState(() {
      _connectionCode = '847291';
    });
  }

  void _copyCode() {
    if (_connectionCode != null) {
      Clipboard.setData(ClipboardData(text: _connectionCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('连接码已复制'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _connectSmb() {
    // TODO: 弹出连接配置对话框
    _showConnectDialog();
  }

  void _disconnectSmb() {
    setState(() {
      _smbConnected = false;
      _connectedHost = null;
    });
  }

  void _browseRemote() {
    // TODO: 跳转到远程浏览页面
  }

  void _viewAllHistory() {
    // TODO: 跳转到传输历史页面
  }

  void _showConnectDialog() {
    final appTheme = Theme.of(context).appTheme;
    final hostController = TextEditingController();
    final shareController = TextEditingController(text: r'PhoneShare$');
    final userController = TextEditingController(text: 'phone');
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
        ),
        title: const Text('连接电脑'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: '电脑 IP 地址',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shareController,
              decoration: const InputDecoration(
                labelText: '共享文件夹名',
                hintText: 'PhoneShare$',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: '用户名',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              decoration: const InputDecoration(
                labelText: '密码',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _smbConnected = true;
                _connectedHost = hostController.text;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }
}

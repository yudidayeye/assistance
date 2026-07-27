import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_extension.dart';
import 'sync_service.dart';

/// 发送数据页面 — 输入目标 IP，发送备份数据
class SyncSendPage extends StatefulWidget {
  const SyncSendPage({super.key});

  @override
  State<SyncSendPage> createState() => _SyncSendPageState();
}

class _SyncSendPageState extends State<SyncSendPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8080');
  final SyncService _sync = SyncService.instance;

  bool _sending = false;
  // idle / sending / success / error
  String _status = 'idle';
  String _statusMessage = '';

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _status = 'error';
        _statusMessage = '请输入目标 IP 地址';
      });
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _status = 'error';
        _statusMessage = '端口号无效（1-65535）';
      });
      return;
    }

    setState(() {
      _sending = true;
      _status = 'sending';
      _statusMessage = '正在发送数据...';
    });

    final result = await _sync.sendData(ip, port);

    if (!mounted) return;

    setState(() {
      _sending = false;
      if (result.isSuccess) {
        _status = 'success';
        _statusMessage = '数据同步成功！';
      } else {
        _status = 'error';
        _statusMessage = result.error ?? '发送失败';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Column(
          children: [
            // ── 顶部栏 ──
            Container(
              color: appTheme.cream,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
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
                        '发送数据',
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

            // ── 内容区 ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // ── 图标 ──
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: appTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.cloud_upload_rounded,
                          size: 32, color: appTheme.primary),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      '将本机数据发送到另一台设备',
                      style: TextStyle(
                        fontSize: 14,
                        color: appTheme.earthMedium,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── IP 输入 ──
                    _buildInputLabel(appTheme, '目标 IP 地址'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      appTheme,
                      controller: _ipController,
                      hint: '例如 192.168.1.100',
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 16),

                    // ── 端口输入 ──
                    _buildInputLabel(appTheme, '端口号'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      appTheme,
                      controller: _portController,
                      hint: '8080',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '请先在目标设备上点击「接收数据」获取地址和端口',
                      style: TextStyle(
                        fontSize: 12,
                        color: appTheme.earthMedium.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── 状态指示 ──
                    if (_status != 'idle') _buildStatusBar(appTheme),

                    if (_status != 'idle') const SizedBox(height: 24),

                    // ── 发送按钮 ──
                    GestureDetector(
                      onTap: _sending ? null : _handleSend,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _sending
                              ? appTheme.primary.withValues(alpha: 0.5)
                              : appTheme.primary,
                          borderRadius:
                              BorderRadius.circular(appTheme.radiusMd),
                        ),
                        child: Center(
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('发送',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 完成后返回 ──
                    if (_status == 'success')
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: appTheme.creamDark,
                            borderRadius:
                                BorderRadius.circular(appTheme.radiusMd),
                          ),
                          child: Center(
                            child: Text('返回',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: appTheme.earthLight)),
                          ),
                        ),
                      ),

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

  Widget _buildInputLabel(AppThemeExtension appTheme, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: appTheme.earthMedium,
        ),
      ),
    );
  }

  Widget _buildTextField(
    AppThemeExtension appTheme, {
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: GoogleFonts.dmSans().fontFamily,
          fontSize: 15,
          color: appTheme.earth,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: appTheme.earthMedium.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStatusBar(AppThemeExtension appTheme) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (_status) {
      case 'sending':
        bgColor = appTheme.primary.withValues(alpha: 0.06);
        textColor = appTheme.primary;
        icon = Icons.sync_rounded;
        break;
      case 'success':
        bgColor = appTheme.sage.withValues(alpha: 0.08);
        textColor = appTheme.sage;
        icon = Icons.check_circle_rounded;
        break;
      case 'error':
        bgColor = appTheme.rose.withValues(alpha: 0.06);
        textColor = appTheme.rose;
        icon = Icons.error_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

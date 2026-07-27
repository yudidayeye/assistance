import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_extension.dart';
import 'sync_service.dart';

/// 发送数据页面 — 自动发现局域网设备，点击即发
class SyncSendPage extends StatefulWidget {
  const SyncSendPage({super.key});

  @override
  State<SyncSendPage> createState() => _SyncSendPageState();
}

class _SyncSendPageState extends State<SyncSendPage> {
  final SyncService _sync = SyncService.instance;
  StreamSubscription<List<DiscoveredDevice>>? _sub;

  List<DiscoveredDevice> _devices = [];
  DiscoveredDevice? _sendingTo;
  // idle / sending / success / error
  String _status = 'idle';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    await _sync.startDiscovery();
    _sub = _sync.discoveredDevices.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });
    // 加载已有设备
    setState(() {
      _devices = _sync.devices;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sync.stopDiscovery();
    super.dispose();
  }

  Future<void> _sendToDevice(DiscoveredDevice device) async {
    setState(() {
      _sendingTo = device;
      _status = 'sending';
      _statusMessage = '正在发送到 ${device.name}...';
    });

    final result = await _sync.sendData(device.ip, device.port);

    if (!mounted) return;

    setState(() {
      _sendingTo = null;
      if (result.isSuccess) {
        _status = 'success';
        _statusMessage = '数据已成功发送到 ${device.name}';
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
                    const SizedBox(height: 24),

                    // ── 状态提示 ──
                    if (_status != 'idle') _buildStatusBar(appTheme),

                    if (_status != 'idle') const SizedBox(height: 20),

                    // ── 设备列表标题 ──
                    Row(
                      children: [
                        Icon(Icons.wifi_find_rounded,
                            size: 18,
                            color: appTheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Text(
                          '附近的设备',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earthMedium,
                          ),
                        ),
                        const Spacer(),
                        // 扫描动画
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: appTheme.earthMedium.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '扫描中',
                          style: TextStyle(
                            fontSize: 11,
                            color: appTheme.earthMedium.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── 设备列表 ──
                    if (_devices.isEmpty)
                      _buildEmptyState(appTheme)
                    else
                      ..._devices.map((device) =>
                          _buildDeviceItem(appTheme, device)),

                    const SizedBox(height: 32),

                    // ── 提示 ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appTheme.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: appTheme.cardBorder, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16,
                              color:
                                  appTheme.earthMedium.withValues(alpha: 0.5)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '需要对方在「接收数据」页面等待连接。\n'
                              '两台设备需连接同一 WiFi 网络。',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    appTheme.earthMedium.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
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
          if (_status == 'sending')
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          else
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

  Widget _buildEmptyState(AppThemeExtension appTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.devices_other_rounded,
              size: 40, color: appTheme.earthMedium.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            '暂未发现设备',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '请确认对方已打开「接收数据」',
            style: TextStyle(
              fontSize: 12,
              color: appTheme.earthMedium.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(AppThemeExtension appTheme, DiscoveredDevice device) {
    final isSending = _sendingTo == device;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: (_status == 'sending' && isSending) ? null : () => _sendToDevice(device),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: appTheme.cardBorder, width: 0.5),
          ),
          child: Row(
            children: [
              // 设备图标
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDeviceIcon(device.name),
                  size: 20,
                  color: appTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: appTheme.earth,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.address,
                      style: TextStyle(
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        fontSize: 11,
                        color: appTheme.earthMedium.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // 发送按钮/状态
              if (isSending && _status == 'sending')
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: appTheme.primary,
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '发送',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: appTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('windows') || lower.contains('pc') || lower.contains('desktop')) {
      return Icons.computer_rounded;
    } else if (lower.contains('android') || lower.contains('phone')) {
      return Icons.phone_iphone_rounded;
    } else if (lower.contains('iphone') || lower.contains('ios')) {
      return Icons.phone_iphone_rounded;
    } else if (lower.contains('mac') || lower.contains('macos')) {
      return Icons.computer_rounded;
    }
    return Icons.devices_other_rounded;
  }
}

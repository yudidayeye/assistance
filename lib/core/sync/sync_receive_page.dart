import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/theme_extension.dart';
import 'sync_service.dart';

/// 接收数据页面 — 起 HTTP 服务，显示 IP + 二维码，等待对端发送
class SyncReceivePage extends StatefulWidget {
  const SyncReceivePage({super.key});

  @override
  State<SyncReceivePage> createState() => _SyncReceivePageState();
}

class _SyncReceivePageState extends State<SyncReceivePage> {
  final SyncService _sync = SyncService.instance;

  String? _localIp;
  int _port = 0;
  bool _starting = true;
  String? _error;

  // 状态：idle / waiting / received / importing / done / failed
  String _status = 'idle';
  String _statusMessage = '';
  StreamSubscription<SyncRequest>? _sub;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      final ip = await _sync.getLocalIp();
      if (ip == null) {
        if (mounted) {
          setState(() {
            _error = '无法获取局域网 IP，请确认已连接 WiFi';
            _starting = false;
          });
        }
        return;
      }

      final port = await _sync.startServer();

      if (mounted) {
        setState(() {
          _localIp = ip;
          _port = port;
          _starting = false;
          _status = 'waiting';
          _statusMessage = '等待其他设备连接...';
        });
      }

      // 监听同步请求
      _sub = _sync.onRequest.listen(_onSyncRequest);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '启动服务失败：$e';
          _starting = false;
        });
      }
    }
  }

  void _onSyncRequest(SyncRequest request) {
    if (!mounted) return;

    setState(() {
      _status = 'received';
      _statusMessage = '收到数据，正在校验...';
    });

    // 弹出确认对话框
    _showConfirmDialog(request);
  }

  Future<void> _showConfirmDialog(SyncRequest request) async {
    final appTheme = Theme.of(context).appTheme;
    final preview = request.preview;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(Icons.cloud_download_rounded,
                    color: appTheme.primary, size: 26),
              ),
              const SizedBox(height: 20),
              Text('确认接收数据？',
                  style: TextStyle(
                      fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: appTheme.earth),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                '将导入 ${preview.settingsCount} 项设置、'
                '${preview.periodRecordsCount} 条生理期记录、'
                '${preview.bookPeriodsCount} 个周期、'
                '${preview.bookStagesCount} 个阶段。\n'
                '已存在的设置和记录将被覆盖。',
                style: TextStyle(
                    fontSize: 14, color: appTheme.earthMedium, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.creamDark,
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: Center(
                          child: Text('拒绝',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: appTheme.earthLight))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.primary,
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                      ),
                      child: const Center(
                          child: Text('确认接收',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white))),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _status = 'importing';
        _statusMessage = '正在导入数据...';
      });
      request.confirm();
    } else {
      request.reject();
      if (mounted) {
        setState(() {
          _status = 'waiting';
          _statusMessage = '已拒绝，继续等待...';
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sync.stopServer();
    super.dispose();
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
                        '接收数据',
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
              child: _starting
                  ? _buildLoading(appTheme)
                  : _error != null
                      ? _buildError(appTheme)
                      : _buildContent(appTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(AppThemeExtension appTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: appTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('正在启动服务...',
              style: TextStyle(fontSize: 14, color: appTheme.earthMedium)),
        ],
      ),
    );
  }

  Widget _buildError(AppThemeExtension appTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: appTheme.rose.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: appTheme.earthMedium)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _starting = true;
                  _error = null;
                });
                _startServer();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: appTheme.primary,
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: const Text('重试',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeExtension appTheme) {
    final address = '$_localIp:$_port';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // ── 状态指示 ──
          _buildStatusIndicator(appTheme),

          const SizedBox(height: 28),

          // ── 二维码 ──
          if (_status == 'waiting' || _status == 'received')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: appTheme.earth.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: address,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: appTheme.earth,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: appTheme.earth,
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── IP 地址 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_rounded,
                    size: 18, color: appTheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Text(
                  address,
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            '在另一台设备的「发送数据」中输入以上地址',
            style: TextStyle(
              fontSize: 12,
              color: appTheme.earthMedium.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 40),

          // ── 停止按钮 ──
          if (_status == 'waiting' || _status == 'received')
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: appTheme.creamDark,
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Text('停止接收',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthLight)),
              ),
            ),

          // ── 完成按钮 ──
          if (_status == 'done')
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: appTheme.primary,
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: const Text('完成',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AppThemeExtension appTheme) {
    Color dotColor;
    IconData icon;

    switch (_status) {
      case 'waiting':
        dotColor = appTheme.sage;
        icon = Icons.access_time_rounded;
        break;
      case 'received':
      case 'importing':
        dotColor = appTheme.primary;
        icon = Icons.downloading_rounded;
        break;
      case 'done':
        dotColor = appTheme.sage;
        icon = Icons.check_circle_rounded;
        break;
      case 'failed':
        dotColor = appTheme.rose;
        icon = Icons.error_outline_rounded;
        break;
      default:
        dotColor = appTheme.earthMedium;
        icon = Icons.radio_button_unchecked;
    }

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: (_status == 'importing')
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: dotColor,
                  ),
                )
              : Icon(icon, size: 28, color: dotColor),
        ),
        const SizedBox(height: 12),
        Text(
          _statusMessage,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: appTheme.earth,
          ),
        ),
      ],
    );
  }
}

import '../../shared/foundation/app_spacing.dart';
import '../../shared/foundation/app_typography.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_extension.dart';
import 'sync_service.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_segmented_tab.dart';

/// 数据同步页面 — 接收 / 发送合一
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> with TickerProviderStateMixin {
  final SyncService _sync = SyncService.instance;

  // 0 = 接收, 1 = 发送
  int _tabIndex = 0;

  // ── 接收状态 ──
  String? _localIp;
  int _port = 0;
  bool _serverStarting = false;
  String _rxStatus = 'idle'; // idle / waiting / received / importing / done / failed
  String _rxMessage = '';
  StreamSubscription<SyncRequest>? _requestSub;

  // ── 发送状态 ──
  List<DiscoveredDevice> _devices = [];
  StreamSubscription<List<DiscoveredDevice>>? _deviceSub;
  DiscoveredDevice? _sendingTo;
  String _txStatus = 'idle'; // idle / sending / success / error
  String _txMessage = '';

  // ── 动画 ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_sync.isRunning) {
      _localIp = null;
      _port = 0;
      _rxStatus = 'waiting';
      _rxMessage = '等待其他设备连接...';
      _serverStarting = false;
      _restoreServerInfo();
    }
  }

  Future<void> _restoreServerInfo() async {
    _localIp = await _sync.getLocalIp();
    _requestSub ??= _sync.onRequest.listen(_onSyncRequest);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _requestSub?.cancel();
    _deviceSub?.cancel();
    _sync.stopDiscovery();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 接收逻辑
  // ═══════════════════════════════════════════════════════════

  Future<void> _startServer() async {
    setState(() {
      _serverStarting = true;
      _rxStatus = 'idle';
      _rxMessage = '';
    });

    try {
      final ip = await _sync.getLocalIp();
      if (ip == null) {
        if (mounted) {
          setState(() {
            _rxStatus = 'failed';
            _rxMessage = '无法获取局域网 IP，请确认已连接 WiFi';
            _serverStarting = false;
          });
        }
        return;
      }

      final port = await _sync.startServer();
      _requestSub ??= _sync.onRequest.listen(_onSyncRequest);

      if (mounted) {
        setState(() {
          _localIp = ip;
          _port = port;
          _serverStarting = false;
          _rxStatus = 'waiting';
          _rxMessage = '等待其他设备连接...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rxStatus = 'failed';
          _rxMessage = '启动服务失败：$e';
          _serverStarting = false;
        });
      }
    }
  }

  Future<void> _stopServer() async {
    _requestSub?.cancel();
    _requestSub = null;
    await _sync.stopServer();
    if (mounted) {
      setState(() {
        _localIp = null;
        _port = 0;
        _rxStatus = 'idle';
        _rxMessage = '';
      });
    }
  }

  void _onSyncRequest(SyncRequest request) {
    if (!mounted) return;
    setState(() {
      _rxStatus = 'received';
      _rxMessage = '收到数据，等待确认...';
    });
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
              AppSpacing.h20,
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
              AppSpacing.h24,
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      backgroundColor: appTheme.creamDark,
                      foregroundColor: appTheme.earthLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    child: const Text('拒绝'),
                  ),
                ),
                AppSpacing.w12,
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: appTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(appTheme.radiusMd),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('确认接收'),
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
        _rxStatus = 'importing';
        _rxMessage = '正在导入数据...';
      });
      request.confirm();
      await request.result;
      if (mounted) {
        setState(() {
          _rxStatus = 'done';
          _rxMessage = '数据同步完成';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _stopServer();
        });
      }
    } else {
      request.reject();
      if (mounted) {
        setState(() {
          _rxStatus = 'waiting';
          _rxMessage = '已拒绝，继续等待...';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 发送逻辑
  // ═══════════════════════════════════════════════════════════

  void _startDiscovery() {
    _sync.startDiscovery();
    _deviceSub = _sync.discoveredDevices.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    setState(() => _devices = _sync.devices);
  }

  void _stopDiscovery() {
    _deviceSub?.cancel();
    _deviceSub = null;
    _sync.stopDiscovery();
    if (mounted) setState(() => _devices = []);
  }

  Future<void> _sendToDevice(DiscoveredDevice device) async {
    setState(() {
      _sendingTo = device;
      _txStatus = 'sending';
      _txMessage = '正在发送到 ${device.name}...';
    });

    final result = await _sync.sendData(device.ip, device.port);

    if (!mounted) return;

    setState(() {
      _sendingTo = null;
      if (result.isSuccess) {
        _txStatus = 'success';
        _txMessage = '已成功发送到 ${device.name}';
      } else {
        _txStatus = 'error';
        _txMessage = result.error ?? '发送失败';
      }
    });

    if (result.isSuccess) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _txStatus == 'success') {
          setState(() {
            _txStatus = 'idle';
            _txMessage = '';
          });
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Tab 切换
  // ═══════════════════════════════════════════════════════════

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
    if (index == 1) {
      _startDiscovery();
    } else {
      _stopDiscovery();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 构建 UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        titleSpacing: 0,
        title: Text(
          '数据同步',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: Column(
        children: [
          // ── Tab 切换 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: AppSegmentedTab(
              items: const [
                AppSegmentedTabItem(label: '接收', icon: Icons.download_rounded),
                AppSegmentedTabItem(label: '发送', icon: Icons.upload_rounded),
              ],
              selectedIndex: _tabIndex,
              onChanged: _onTabChanged,
            ),
          ),

          AppSpacing.h12,

          // ── 内容区 ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _tabIndex == 0
                ? _buildReceiveTab(appTheme)
                : _buildSendTab(appTheme),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 接收 Tab
  // ═══════════════════════════════════════════════════════════

  Widget _buildReceiveTab(AppThemeExtension appTheme) {
    // 完成状态
    if (_rxStatus == 'done') {
      return _buildDoneState(appTheme);
    }

    return SingleChildScrollView(
      key: const ValueKey('receive'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // ── 状态指示 ──
          _buildRxStatusIndicator(appTheme),

          const SizedBox(height: 28),

          // ── 本机地址卡片 ──
          if (_rxStatus == 'waiting' ||
              _rxStatus == 'received' ||
              _rxStatus == 'importing')
            _buildAddressCard(appTheme),

          // ── 开启按钮 ──
          if (_rxStatus == 'idle' || _rxStatus == 'failed')
            _buildStartCard(appTheme),

          // ── 停止按钮 ──
          if (_sync.isRunning && _rxStatus != 'importing') ...[
            AppSpacing.h16,
            _buildStopButton(appTheme),
          ],

          const SizedBox(height: 28),

          // ── 提示 ──
          _buildHintCard(
            appTheme,
            icon: Icons.info_outline_rounded,
            text: (_rxStatus == 'waiting' || _rxStatus == 'received')
                ? '请在另一台设备的「数据同步」页面中选择本机发送数据'
                : '开启后，其他设备可在局域网内发现并发送数据到本机',
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDoneState(AppThemeExtension appTheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          AppSpacing.h48,
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * value,
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: appTheme.sage.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 40, color: appTheme.sage),
                ),
                AppSpacing.h20,
                Text(
                  '同步完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '数据已成功导入',
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.earthMedium.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRxStatusIndicator(AppThemeExtension appTheme) {
    Color dotColor;
    IconData icon;
    bool showLoading = false;

    switch (_rxStatus) {
      case 'idle':
        dotColor = appTheme.primary.withValues(alpha: 0.5);
        icon = Icons.wifi_tethering_rounded;
        break;
      case 'waiting':
        dotColor = appTheme.sage;
        icon = Icons.access_time_rounded;
        break;
      case 'received':
        dotColor = appTheme.primary;
        icon = Icons.downloading_rounded;
        break;
      case 'importing':
        dotColor = appTheme.primary;
        icon = Icons.downloading_rounded;
        showLoading = true;
        break;
      case 'failed':
        dotColor = appTheme.rose;
        icon = Icons.error_outline_rounded;
        break;
      default:
        dotColor = appTheme.earthMedium.withValues(alpha: 0.4);
        icon = Icons.wifi_tethering_rounded;
    }

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale =
                _rxStatus == 'waiting' ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: 0.95 + 0.05 * scale,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: dotColor.withValues(
                      alpha: _rxStatus == 'waiting' ? 0.08 * scale : 0.1),
                  shape: BoxShape.circle,
                  boxShadow: _rxStatus == 'waiting'
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: showLoading
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: dotColor,
                        ),
                      )
                    : Icon(icon, size: 32, color: dotColor),
              ),
            );
          },
        ),
        if (_rxMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _rxMessage,
              key: ValueKey(_rxMessage),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressCard(AppThemeExtension appTheme) {
    final address = '$_localIp:$_port';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        border: Border.all(
          color: _rxStatus == 'waiting'
              ? appTheme.sage.withValues(alpha: 0.2)
              : appTheme.cardBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.earth.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 在线指示
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: appTheme.sage.withValues(
                          alpha: 0.5 + 0.5 * _pulseAnimation.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: appTheme.sage.withValues(
                              alpha: 0.3 * _pulseAnimation.value),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.w8,
                  Text(
                    '本机地址',
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // 地址
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: appTheme.creamDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Text(
              address,
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: appTheme.earth,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCard(AppThemeExtension appTheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _serverStarting ? null : _startServer,
        style: OutlinedButton.styleFrom(
          foregroundColor: appTheme.primary,
          backgroundColor: appTheme.primary.withValues(alpha: 0.1),
          side: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
          disabledForegroundColor: appTheme.earthMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: const Text('开启接收'),
      ),
    );
  }

  Widget _buildStopButton(AppThemeExtension appTheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _stopServer,
        style: OutlinedButton.styleFrom(
          foregroundColor: appTheme.rose,
          backgroundColor: appTheme.rose.withValues(alpha: 0.1),
          side: BorderSide(color: appTheme.rose.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: const Text('停止接收'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 发送 Tab
  // ═══════════════════════════════════════════════════════════

  Widget _buildSendTab(AppThemeExtension appTheme) {
    return SingleChildScrollView(
      key: const ValueKey('send'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // ── 状态提示 ──
          if (_txStatus != 'idle') ...[
            _buildTxStatusBar(appTheme),
            AppSpacing.h16,
          ],

          // ── 设备列表标题 ──
          _buildSectionHeader(appTheme),

          AppSpacing.h12,

          // ── 设备列表 ──
          if (_devices.isEmpty)
            _buildEmptyDevices(appTheme)
          else
            ...List.generate(_devices.length, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + i * 60),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildDeviceItem(appTheme, _devices[i]),
              );
            }),

          const SizedBox(height: 28),

          // ── 提示 ──
          _buildHintCard(
            appTheme,
            icon: Icons.info_outline_rounded,
            text: '需要对方在「数据同步」页面切换到接收模式并开启接收',
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppThemeExtension appTheme) {
    return Row(
      children: [
        Icon(Icons.wifi_find_rounded,
            size: 17, color: appTheme.primary.withValues(alpha: 0.6)),
        AppSpacing.w8,
        Text(
          '附近的设备',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: appTheme.earthMedium.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        // 扫描指示
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: appTheme.earthMedium.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '扫描中',
              style: TextStyle(
                fontSize: 10,
                color: appTheme.earthMedium.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTxStatusBar(AppThemeExtension appTheme) {
    Color bgColor;
    Color textColor;
    IconData icon;
    bool isLoading = false;

    switch (_txStatus) {
      case 'sending':
        bgColor = appTheme.primary.withValues(alpha: 0.06);
        textColor = appTheme.primary;
        icon = Icons.sync_rounded;
        isLoading = true;
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
            )
          else
            Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_txMessage,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDevices(AppThemeExtension appTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: appTheme.earthMedium.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.devices_other_rounded,
                size: 36, color: appTheme.earthMedium.withValues(alpha: 0.25)),
          ),
          AppSpacing.h16,
          Text('暂未发现设备',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earthMedium.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('请确认对方已开启接收',
              style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(AppThemeExtension appTheme, DiscoveredDevice device) {
    final isSending = _sendingTo == device && _txStatus == 'sending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isSending ? null : () => _sendToDevice(device),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSending
                ? appTheme.primary.withValues(alpha: 0.04)
                : appTheme.cardBackground,
            borderRadius: BorderRadius.circular(appTheme.radiusLg),
            border: Border.all(
              color: isSending
                  ? appTheme.primary.withValues(alpha: 0.15)
                  : appTheme.cardBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: appTheme.earth.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 设备图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                child: Icon(_getDeviceIcon(device.name),
                    size: 20, color: appTheme.primary.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 14),
              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earth)),
                    const SizedBox(height: 3),
                    Text(device.address,
                        style: TextStyle(
                            fontFamily: GoogleFonts.dmSans().fontFamily,
                            fontSize: 11,
                            color:
                                appTheme.earthMedium.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              // 发送按钮
              if (isSending)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: appTheme.primary),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(appTheme.radiusXl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_upload_outlined,
                          size: 13, color: appTheme.primary),
                      AppSpacing.w4,
                      Text('发送',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: appTheme.primary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintCard(AppThemeExtension appTheme,
      {required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: appTheme.earthMedium.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 15,
              color: appTheme.earthMedium.withValues(alpha: 0.45)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: appTheme.earthMedium.withValues(alpha: 0.55),
                    height: 1.6)),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('windows') ||
        lower.contains('pc') ||
        lower.contains('desktop') ||
        lower.contains('mac')) {
      return Icons.computer_rounded;
    } else if (lower.contains('android') ||
        lower.contains('phone') ||
        lower.contains('iphone') ||
        lower.contains('ios')) {
      return Icons.phone_iphone_rounded;
    }
    return Icons.devices_other_rounded;
  }
}

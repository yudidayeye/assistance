import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:my_assistant/core/settings/update_service.dart';
import 'package:my_assistant/core/theme/theme_extension.dart';
import 'package:my_assistant/shared/foundation/app_spacing.dart';
import 'package:my_assistant/shared/foundation/app_typography.dart';

/// 更新弹窗状态机
enum _UpdatePhase {
  /// 展示更新内容，等待用户确认
  confirm,

  /// 下载中（进度条 + 可取消）
  downloading,

  /// 下载完成，已唤起/可再次唤起系统安装器
  installing,

  /// 下载或安装失败
  failed,
}

/// 应用内更新弹窗
///
/// 展示更新内容 → 按设备架构匹配的 APK 下载（进度条 + 取消）
/// → 下载完成自动唤起系统安装器。
/// 样式沿用项目统一弹窗规范：cream 底色、surfaceOverlay 遮罩、
/// 52x52 语义色图标容器、更新场景主色 sage。
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    required this.asset,
  });

  /// 更新信息（版本号、更新说明、Release 页面链接）
  final UpdateInfo info;

  /// 已按设备架构匹配出的 APK 产物
  final ReleaseAsset asset;

  /// 弹出应用内更新弹窗
  static Future<void> show(
    BuildContext context, {
    required UpdateInfo info,
    required ReleaseAsset asset,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return showDialog<void>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => UpdateDialog(info: info, asset: asset),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService.instance;

  _UpdatePhase _phase = _UpdatePhase.confirm;
  int _received = 0;
  int _total = 0;
  String _errorMessage = '';
  String? _downloadedPath;
  CancelToken? _cancelToken;

  /// 进度回调节流：dio 每个数据块都会回调，限制刷新频率防掉帧
  int _lastProgressTick = 0;

  @override
  void initState() {
    super.initState();
    _total = widget.asset.size;
  }

  @override
  void dispose() {
    // 弹窗关闭即取消下载（不做后台下载）
    _cancelToken?.cancel('弹窗已关闭');
    super.dispose();
  }

  double get _progress {
    if (_total <= 0) return 0;
    return (_received / _total).clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════
  // 流程：确认 → 权限前置检查 → 下载 → 自动安装
  // ═══════════════════════════════════════════════════════════════

  /// 点击「立即更新」：权限前置在下载之前，避免下完才发现无法安装
  Future<void> _startUpdate() async {
    final permission = await _updateService.ensureInstallPermission();
    if (!mounted) return;
    switch (permission) {
      case InstallPermissionResult.granted:
        await _startDownload();
      case InstallPermissionResult.denied:
      case InstallPermissionResult.permanentlyDenied:
        _showPermissionGuide();
    }
  }

  Future<void> _startDownload() async {
    final token = CancelToken();
    _cancelToken = token;
    setState(() {
      _phase = _UpdatePhase.downloading;
      _received = 0;
      _total = widget.asset.size;
      _errorMessage = '';
    });

    try {
      final path = await _updateService.downloadApk(
        asset: widget.asset,
        version: widget.info.latestVersion ?? '',
        cancelToken: token,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      if (path == null) {
        // 用户取消下载，回到确认态
        setState(() => _phase = _UpdatePhase.confirm);
        return;
      }
      _downloadedPath = path;
      await _launchInstaller();
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.failed;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.failed;
        _errorMessage = '下载失败，请稍后重试';
      });
    }
  }

  /// 唤起系统安装器；失败时转入 failed 态并提供手动下载兜底
  Future<void> _launchInstaller() async {
    setState(() => _phase = _UpdatePhase.installing);
    final path = _downloadedPath;
    if (path == null) return;

    final launched = await _updateService.installApk(path);
    if (!mounted) return;
    if (!launched) {
      setState(() {
        _phase = _UpdatePhase.failed;
        _errorMessage = '无法唤起系统安装器，请前往 GitHub 发布页手动下载安装';
      });
    }
    // 唤起成功后保持 installing 态：
    // 用户在系统安装器里取消返回后，仍可点「立即安装」再次唤起
  }

  void _onProgress(int received, int total) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isFinal = total > 0 && received >= total;
    if (!isFinal && now - _lastProgressTick < 100) return;
    _lastProgressTick = now;
    if (!mounted) return;
    setState(() {
      _received = received;
      _total = total > 0 ? total : widget.asset.size;
    });
  }

  /// 安装权限被拒后的引导弹窗
  void _showPermissionGuide() {
    final appTheme = Theme.of(context).appTheme;
    showDialog<void>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: appTheme.sage.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.settings_rounded, color: appTheme.sage, size: 26),
        ),
        title: Text(
          '需要安装权限',
          style: AppTypography.displayMd.copyWith(color: appTheme.earth),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '完成更新需要允许本应用"安装未知应用"。\n请在接下来的系统设置页面中开启允许，返回后重新点击立即更新。',
          style: AppTypography.bodyMd.copyWith(
            color: appTheme.earthMedium,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: appTheme.earthMedium),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: Text('去设置', style: TextStyle(color: appTheme.sage)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return PopScope(
      // 下载中禁止返回键/点击遮罩误关
      canPop: _phase != _UpdatePhase.downloading,
      child: AlertDialog(
        backgroundColor: appTheme.cream,
        icon: _buildIcon(appTheme),
        title: Text(
          _title,
          style: AppTypography.displayMd.copyWith(color: appTheme.earth),
          textAlign: TextAlign.center,
        ),
        content: _buildContent(appTheme),
        actions: _buildActions(appTheme),
      ),
    );
  }

  String get _title {
    switch (_phase) {
      case _UpdatePhase.confirm:
        return '发现新版本';
      case _UpdatePhase.downloading:
        return '正在下载更新包';
      case _UpdatePhase.installing:
        return '准备安装';
      case _UpdatePhase.failed:
        return '更新失败';
    }
  }

  Widget _buildIcon(AppThemeExtension appTheme) {
    final (icon, color) = switch (_phase) {
      _UpdatePhase.confirm => (Icons.system_update_rounded, appTheme.sage),
      _UpdatePhase.downloading => (Icons.downloading_rounded, appTheme.sage),
      _UpdatePhase.installing => (Icons.system_update_rounded, appTheme.sage),
      _UpdatePhase.failed => (Icons.error_outline_rounded, appTheme.rose),
    };
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  Widget _buildContent(AppThemeExtension appTheme) {
    switch (_phase) {
      case _UpdatePhase.confirm:
        return _buildConfirmContent(appTheme);
      case _UpdatePhase.downloading:
        return _buildDownloadingContent(appTheme);
      case _UpdatePhase.installing:
        return _buildInstallingContent(appTheme);
      case _UpdatePhase.failed:
        return _buildFailedContent(appTheme);
    }
  }

  /// 确认态：版本对比 + 更新内容 + 包大小 + GitHub 兜底链接
  Widget _buildConfirmContent(AppThemeExtension appTheme) {
    final notes = widget.info.releaseNotes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'V${widget.info.currentVersion} → V${widget.info.latestVersion}',
          style: AppTypography.bodyMd.copyWith(
            fontWeight: FontWeight.w600,
            color: appTheme.sage,
          ),
          textAlign: TextAlign.center,
        ),
        if (notes != null && notes.isNotEmpty) ...[
          AppSpacing.h16,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Text(
              notes.length > 200 ? '${notes.substring(0, 200)}...' : notes,
              style: AppTypography.caption.copyWith(
                color: appTheme.earthMedium,
                height: 1.5,
              ),
            ),
          ),
        ],
        AppSpacing.h12,
        Text(
          '更新包约 ${_formatMB(widget.asset.size)}，已匹配本机架构',
          style: AppTypography.caption.copyWith(
            color: appTheme.earthMedium.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        _buildGithubLink(appTheme),
      ],
    );
  }

  /// 下载中：进度条 + 百分比 + 已下载大小
  Widget _buildDownloadingContent(AppThemeExtension appTheme) {
    final percent = (_progress * 100).toInt();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            color: appTheme.sage,
            backgroundColor: appTheme.sage.withValues(alpha: 0.12),
          ),
        ),
        AppSpacing.h12,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percent%',
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: appTheme.sage,
              ),
            ),
            Text(
              '${_formatMB(_received)} / ${_formatMB(_total)}',
              style: AppTypography.caption.copyWith(
                color: appTheme.earthMedium,
              ),
            ),
          ],
        ),
        AppSpacing.h8,
        Text(
          '下载完成后将自动进入安装',
          style: AppTypography.caption.copyWith(
            color: appTheme.earthMedium.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 安装态：提示用户在系统安装器中确认
  Widget _buildInstallingContent(AppThemeExtension appTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'V${widget.info.latestVersion} 已下载完成',
          style: AppTypography.bodyMd.copyWith(
            fontWeight: FontWeight.w600,
            color: appTheme.sage,
          ),
          textAlign: TextAlign.center,
        ),
        AppSpacing.h12,
        Text(
          '请在系统安装器中确认安装；若刚才取消了安装，可点击下方按钮再次唤起。',
          style: AppTypography.bodyMd.copyWith(
            color: appTheme.earthMedium,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 失败态：错误文案 + GitHub 兜底链接
  Widget _buildFailedContent(AppThemeExtension appTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _errorMessage,
          style: AppTypography.bodyMd.copyWith(
            color: appTheme.earthMedium,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        _buildGithubLink(appTheme),
      ],
    );
  }

  /// 「前往 GitHub 发布页」兜底链接（外链手动下载）
  Widget _buildGithubLink(AppThemeExtension appTheme) {
    final url = widget.info.releaseUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
          _updateService.openReleasePage(url);
        },
        child: Text(
          '前往 GitHub 发布页',
          style: AppTypography.caption.copyWith(
            color: appTheme.earthMedium.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(AppThemeExtension appTheme) {
    switch (_phase) {
      case _UpdatePhase.confirm:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '稍后再说',
              style: TextStyle(color: appTheme.earthMedium),
            ),
          ),
          TextButton(
            onPressed: _startUpdate,
            child: Text('立即更新', style: TextStyle(color: appTheme.sage)),
          ),
        ];
      case _UpdatePhase.downloading:
        return [
          TextButton(
            onPressed: () => _cancelToken?.cancel('用户取消'),
            child: Text('取消下载', style: TextStyle(color: appTheme.rose)),
          ),
        ];
      case _UpdatePhase.installing:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍后', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: _launchInstaller,
            child: Text('立即安装', style: TextStyle(color: appTheme.sage)),
          ),
        ];
      case _UpdatePhase.failed:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: appTheme.earthMedium)),
          ),
          TextButton(
            onPressed: _startUpdate,
            child: Text('重试', style: TextStyle(color: appTheme.sage)),
          ),
        ];
    }
  }

  /// 字节数格式化为 MB（保留 1 位小数）
  String _formatMB(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/vault_entry.dart';
import '../services/vault_service.dart';
import '../services/vault_session.dart';
import 'master_password_page.dart';

/// 查看密码详情页
///
/// 需要再次验证主密码后才能查看明文密码
class ViewEntryPage extends StatefulWidget {
  final int entryId;

  const ViewEntryPage({super.key, required this.entryId});

  @override
  State<ViewEntryPage> createState() => _ViewEntryPageState();
}

class _ViewEntryPageState extends State<ViewEntryPage> {
  VaultEntry? _entry;
  String? _plainPassword;
  bool _isEncrypted = true;
  bool _loading = true;
  bool _needVerify = false;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final entry = await VaultService.instance.getEntry(widget.entryId);
    if (entry == null || !mounted) return;

    setState(() => _entry = entry);

    // 未加密分类直接显示明文，无需验证主密码
    final category =
        await VaultService.instance.getCategory(entry.categoryId);
    _isEncrypted = category?.isEncrypted ?? true;
    if (!_isEncrypted) {
      _decryptPassword();
      return;
    }

    // 检查会话是否已解锁
    if (VaultSession.instance.isLocked) {
      setState(() {
        _needVerify = true;
        _loading = false;
      });
      return;
    }

    _decryptPassword();
  }

  void _decryptPassword() {
    if (_entry == null) return;
    final plain = VaultService.instance
        .decryptEntryPassword(_entry!, isEncrypted: _isEncrypted);
    setState(() {
      _plainPassword = plain;
      _loading = false;
      _needVerify = false;
    });
  }

  Future<void> _requestVerification() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MasterPasswordPage(
          isSetup: false,
          onSuccess: () {},
        ),
      ),
    );
    if (result == true) {
      _decryptPassword();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    if (_loading) {
      return AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '密码详情',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: appTheme.primary),
        ),
      );
    }

    if (_needVerify) {
      return _buildVerifyPrompt(appTheme);
    }

    if (_entry == null) {
      return AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '密码详情',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        body: Center(
          child: Text('条目不存在',
              style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
        ),
      );
    }

    return _buildDetail(appTheme);
  }

  Widget _buildVerifyPrompt(AppThemeExtension appTheme) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          '密码详情',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 56, color: appTheme.primary),
            const SizedBox(height: 16),
            Text(
              '需要验证主密码',
              style: AppTypography.displayMd.copyWith(color: appTheme.earth),
            ),
            const SizedBox(height: 8),
            Text(
              '为保护您的密码安全，请先验证主密码',
              style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(appTheme.radiusPill),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('验证主密码',
                  style: AppTypography.bodyLg.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(AppThemeExtension appTheme) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          _entry!.title.trim().isEmpty ? '密码详情' : _entry!.title,
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题卡片
            _buildInfoCard(
              label: '标题',
              value: _entry!.title.trim().isEmpty ? '未命名' : _entry!.title,
              icon: Icons.label_outline_rounded,
              appTheme: appTheme,
            ),
            const SizedBox(height: 14),
            // 用户名卡片
            if (_entry!.username?.trim().isNotEmpty == true) ...[
              _buildInfoCard(
                label: '用户名',
                value: _entry!.username!.trim(),
                icon: Icons.person_outline_rounded,
                appTheme: appTheme,
              ),
              const SizedBox(height: 14),
            ],
            // 密码卡片
            _buildPasswordCard(appTheme),
            const SizedBox(height: 14),
            // 备注卡片（多条）
            for (final item in _entry!.noteItems) ...[
              _buildInfoCard(
                label: item.title.trim().isEmpty ? '备注' : item.title,
                value: item.content,
                icon: Icons.notes_rounded,
                appTheme: appTheme,
              ),
              const SizedBox(height: 14),
            ],
            // 创建/更新时间
            _buildInfoCard(
              label: '创建时间',
              value: _formatTime(_entry!.createdAt),
              icon: Icons.access_time_rounded,
              appTheme: appTheme,
            ),
            const SizedBox(height: 14),
            _buildInfoCard(
              label: '更新时间',
              value: _formatTime(_entry!.updatedAt),
              icon: Icons.update_rounded,
              appTheme: appTheme,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required AppThemeExtension appTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: appTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: appTheme.earthMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(AppThemeExtension appTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_rounded, size: 20, color: appTheme.sage),
              const SizedBox(width: 12),
              Text(
                '密码',
                style: AppTypography.caption.copyWith(
                  color: appTheme.earthMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 密码显示区
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: appTheme.cream,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _plainPassword ?? '(解密失败)',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: _plainPassword != null
                          ? appTheme.earth
                          : appTheme.rose,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_plainPassword != null) {
                      Clipboard.setData(
                          ClipboardData(text: _plainPassword!));
                      AppSnackBar.show(context, '密码已复制');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: appTheme.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(appTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: appTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

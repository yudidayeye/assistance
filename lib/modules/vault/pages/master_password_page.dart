import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../services/vault_service.dart';

/// 设置 / 验证主密码页面
///
/// - 首次进入：设置主密码（输入 + 确认）
/// - 再次进入：输入主密码验证
class MasterPasswordPage extends StatefulWidget {
  final bool isSetup; // true=设置模式，false=验证模式
  final VoidCallback? onSuccess;

  const MasterPasswordPage({
    super.key,
    required this.isSetup,
    this.onSuccess,
  });

  @override
  State<MasterPasswordPage> createState() => _MasterPasswordPageState();
}

class _MasterPasswordPageState extends State<MasterPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = '请输入主密码');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '主密码至少 6 位');
      return;
    }

    if (widget.isSetup) {
      final confirm = _confirmController.text.trim();
      if (password != confirm) {
        setState(() => _error = '两次输入的密码不一致');
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        await VaultService.instance.setupMasterPassword(password);
        if (mounted) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        setState(() {
          _error = '设置失败：$e';
          _loading = false;
        });
      }
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
      final ok = await VaultService.instance.unlockWithPassword(password);
      if (!mounted) return;
      if (ok) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = '主密码错误';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final isSetup = widget.isSetup;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          isSetup ? '设置主密码' : '解锁保险箱',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // 图标
            Icon(
              isSetup ? Icons.lock_outline_rounded : Icons.lock_rounded,
              size: 72,
              color: appTheme.primary,
            ),
            const SizedBox(height: 16),
            // 提示文字
            Text(
              isSetup ? '创建主密码以保护您的密码数据' : '输入主密码解锁保险箱',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
            ),
            if (isSetup) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ 主密码无法找回，请牢记',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: appTheme.rose,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 32),
            // 密码输入框
            _buildTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: '主密码',
              obscure: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction:
                  isSetup ? TextInputAction.next : TextInputAction.done,
              onSubmitted: isSetup
                  ? (_) => _confirmFocus.requestFocus()
                  : (_) => _handleSubmit(),
            ),
            if (isSetup) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmController,
                focusNode: _confirmFocus,
                label: '确认主密码',
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSubmit(),
              ),
            ],
            // 错误提示
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: appTheme.rose,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 28),
            // 提交按钮
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusPill),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isSetup ? '设置主密码' : '解锁',
                        style: AppTypography.bodyLg.copyWith(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
        filled: true,
        fillColor: appTheme.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          borderSide: BorderSide(color: appTheme.primary, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: appTheme.earthLight,
            size: 20,
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}

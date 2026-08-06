import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/vault_entry.dart';
import '../services/vault_crypto_service.dart';
import '../services/vault_service.dart';
import '../services/vault_session.dart';

/// 新增 / 编辑密码条目页面
class AddEntryPage extends StatefulWidget {
  final int? entryId; // null=新增，非null=编辑
  final int? categoryId; // 新增时的分类ID

  const AddEntryPage({super.key, this.entryId, this.categoryId});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final _titleController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noteController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  VaultEntry? _existingEntry;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    if (widget.entryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEntry();
      });
    }
  }

  Future<void> _loadEntry() async {
    // 编辑模式需要解锁
    if (VaultSession.instance.isLocked) {
      if (mounted) {
        Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先解锁后再编辑'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }

    final entry = await VaultService.instance.getEntry(widget.entryId!);
    if (entry == null || !mounted) return;

    final plainPassword = VaultService.instance.decryptEntryPassword(entry);
    setState(() {
      _existingEntry = entry;
      _selectedCategoryId = entry.categoryId;
      _titleController.text = entry.title;
      _passwordController.text = plainPassword ?? '';
      _noteController.text = entry.note ?? '';
    });
  }

  /// 确保会话已解锁，如果未解锁则弹窗让用户输入主密码
  /// 返回 true 表示已解锁
  Future<bool> _ensureUnlocked() async {
    if (!VaultSession.instance.isLocked) return true;
    final result = await _showUnlockDialog();
    return result == true;
  }

  /// 弹窗输入主密码解锁
  Future<bool?> _showUnlockDialog() async {
    final appTheme = Theme.of(context).appTheme;
    final passwordController = TextEditingController();
    bool obscure = true;
    bool verifying = false;
    String? error;

    return showDialog<bool>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return PopScope(
              canPop: !verifying,
              child: AlertDialog(
                backgroundColor: appTheme.cream,
                title: Text(
                  '输入主密码',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: appTheme.earth,
                  ),
                  textAlign: TextAlign.center,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      autofocus: true,
                      enabled: !verifying,
                      decoration: InputDecoration(
                        hintText: '请输入主密码',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: appTheme.earthMedium.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: appTheme.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(appTheme.radiusSm),
                          borderSide: BorderSide(
                            color: appTheme.earthMedium.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: appTheme.earthLight,
                            size: 20,
                          ),
                          onPressed: verifying
                              ? null
                              : () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                      style: TextStyle(fontSize: 14, color: appTheme.earth),
                      onSubmitted: (_) {
                        if (!verifying) {
                          _doVerify(
                            ctx,
                            passwordController.text,
                            (msg) => setDialogState(() => error = msg),
                            (v) => setDialogState(() => verifying = v),
                          );
                        }
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: appTheme.rose,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: verifying ? null : () => Navigator.pop(ctx),
                    child: Text('取消',
                        style: TextStyle(color: appTheme.earthMedium)),
                  ),
                  TextButton(
                    onPressed: verifying
                        ? null
                        : () {
                            _doVerify(
                              ctx,
                              passwordController.text,
                              (msg) => setDialogState(() => error = msg),
                              (v) => setDialogState(() => verifying = v),
                            );
                          },
                    child: verifying
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: appTheme.primary,
                            ),
                          )
                        : Text('解锁',
                            style: TextStyle(color: appTheme.primary)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _doVerify(
    BuildContext ctx,
    String password,
    Function(String) onError,
    Function(bool) setVerifying,
  ) async {
    if (password.trim().isEmpty) {
      onError('请输入主密码');
      return;
    }
    setVerifying(true);
    onError('');

    final data = await VaultService.instance.getMasterPasswordData();
    if (data == null) {
      setVerifying(false);
      onError('主密码数据不存在');
      return;
    }

    final keyHex = await compute(_unlockIsolate, {
      'password': password.trim(),
      'saltHex': data['salt'] as String,
      'verifyCipherHex': data['verify_cipher'] as String,
      'verifyIvHex': data['verify_iv'] as String,
    });

    setVerifying(false);
    if (keyHex != null) {
      final keyBytes = Uint8List.fromList(
        List.generate(
          keyHex.length ~/ 2,
          (i) => int.parse(keyHex.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
      VaultSession.instance.setKey(keyBytes);
      if (ctx.mounted) Navigator.of(ctx).pop(true);
    } else {
      onError('主密码错误');
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final password = _passwordController.text.trim();

    if (title.isEmpty) {
      setState(() => _error = '请输入标题');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _error = '请选择分类');
      return;
    }

    // 新增时如果未解锁，先弹窗解锁
    if (_existingEntry == null && VaultSession.instance.isLocked) {
      final unlocked = await _ensureUnlocked();
      if (!unlocked) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_existingEntry != null) {
        await VaultService.instance.updateEntry(
          entryId: _existingEntry!.id!,
          categoryId: _selectedCategoryId!,
          title: title,
          plainPassword: password,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );
      } else {
        await VaultService.instance.insertEntry(
          categoryId: _selectedCategoryId!,
          title: title,
          plainPassword: password,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '保存失败：$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _passwordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final isEdit = _existingEntry != null;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          isEdit ? '编辑密码' : '新增密码',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
        actions: [
          if (isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
                iconSize: 20,
                onPressed: _confirmDelete,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            _buildLabel('标题', appTheme),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _titleController,
              hint: '例：GitHub 主账号',
              appTheme: appTheme,
            ),
            const SizedBox(height: 20),
            // 密码
            _buildLabel('密码', appTheme),
            const SizedBox(height: 6),
            _buildPasswordField(appTheme),
            const SizedBox(height: 20),
            // 备注
            _buildLabel('备注（可选）', appTheme),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _noteController,
              hint: '可填写账号、邮箱等信息',
              appTheme: appTheme,
              maxLines: 3,
            ),
            // 错误提示
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(color: appTheme.rose),
              ),
            ],
            const SizedBox(height: 32),
            // 保存按钮
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(appTheme.radiusPill),
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
                        isEdit ? '保存修改' : '添加密码',
                        style:
                            AppTypography.bodyLg.copyWith(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, AppThemeExtension appTheme) {
    return Text(
      text,
      style: AppTypography.label.copyWith(color: appTheme.earth),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required AppThemeExtension appTheme,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMd.copyWith(color: appTheme.earthMedium),
        filled: true,
        fillColor: appTheme.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPasswordField(AppThemeExtension appTheme) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: AppTypography.bodyLg.copyWith(
        color: appTheme.earth,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: '输入密码',
        hintStyle:
            AppTypography.bodyMd.copyWith(color: appTheme.earthMedium),
        filled: true,
        fillColor: appTheme.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: appTheme.earthLight,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final appTheme = Theme.of(context).appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
        ),
        title: Text('删除条目',
            style: AppTypography.displayMd.copyWith(color: appTheme.earth)),
        content: Text(
          '确定删除「${_existingEntry!.title}」？此操作不可撤销。',
          style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: AppTypography.bodyMd
                    .copyWith(color: appTheme.earthLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: AppTypography.bodyMd.copyWith(color: appTheme.rose)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await VaultService.instance.deleteEntry(_existingEntry!.id!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}

/// Isolate 入口：在后台线程执行 Argon2id 验证 + 密钥派生
String? _unlockIsolate(Map<String, String> params) {
  final crypto = VaultCryptoService.instance;
  final valid = crypto.verifyMasterPassword(
    params['password']!,
    params['saltHex']!,
    params['verifyCipherHex']!,
    params['verifyIvHex']!,
  );
  if (!valid) return null;
  final key = crypto.deriveKey(params['password']!, params['saltHex']!);
  return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

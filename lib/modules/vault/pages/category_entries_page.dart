import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/vault_category.dart';
import '../models/vault_entry.dart';
import '../services/vault_crypto_service.dart';
import '../services/vault_service.dart';
import '../services/vault_session.dart';

/// 某分类下的密码条目列表
///
/// 进入时不需要主密码，默认展示标题 + 备注 + 密码遮罩。
/// 点击导航栏右侧「解锁」按钮验证主密码后，展示所有明文密码，
/// 并可在当前页面直接复制标题和密码。
/// 未解锁时点击条目不允许编辑。
class CategoryEntriesPage extends StatefulWidget {
  final int categoryId;

  const CategoryEntriesPage({super.key, required this.categoryId});

  @override
  State<CategoryEntriesPage> createState() => _CategoryEntriesPageState();
}

class _CategoryEntriesPageState extends State<CategoryEntriesPage> {
  VaultCategory? _category;
  List<VaultEntry> _entries = [];
  Map<int, String?> _decryptedPasswords = {};
  bool _loading = true;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 用户真正返回（非向前导航）时锁定
  void _onPopInvoked(bool didPop) {
    if (didPop) {
      VaultSession.instance.lock();
    }
  }

  Future<void> _load() async {
    final categories = await VaultService.instance.getAllCategories();
    final category = categories.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => categories.isNotEmpty
          ? categories.first
          : VaultCategory(
              id: widget.categoryId,
              name: '未知',
              createdAt: '',
              updatedAt: ''),
    );
    final entries =
        await VaultService.instance.getEntriesByCategory(widget.categoryId);

    Map<int, String?> decrypted = {};
    if (!VaultSession.instance.isLocked) {
      for (final entry in entries) {
        final plain = VaultService.instance.decryptEntryPassword(entry);
        decrypted[entry.id!] = plain;
      }
      if (decrypted.isNotEmpty && mounted) {
        _isUnlocked = true;
      }
    }

    if (mounted) {
      setState(() {
        _category = category;
        _entries = entries;
        _decryptedPasswords = decrypted;
        _loading = false;
      });
    }
  }

  Future<void> _handleUnlock() async {
    if (!VaultSession.instance.isLocked) {
      _decryptAllEntries();
      return;
    }

    final result = await _showUnlockDialog();
    if (result == true && mounted) {
      _decryptAllEntries();
    }
  }

  /// 弹窗输入主密码解锁（与编辑余额弹窗样式一致）
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
                            verifying,
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
                              verifying,
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
    bool isVerifying,
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

    // Argon2id 密钥派生较耗时，放到 Isolate 中执行
    final keyHex = await _unlockInBackground(
      password: password.trim(),
      saltHex: data['salt'] as String,
      verifyCipherHex: data['verify_cipher'] as String,
      verifyIvHex: data['verify_iv'] as String,
    );

    setVerifying(false);
    if (keyHex != null) {
      // 在主线程设置派生密钥到 VaultSession
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

  /// 在后台 Isolate 中执行 Argon2id 验证 + 密钥派生，避免阻塞 UI
  /// 成功时返回派生密钥的 hex 字符串，失败返回 null
  Future<String?> _unlockInBackground({
    required String password,
    required String saltHex,
    required String verifyCipherHex,
    required String verifyIvHex,
  }) async {
    return compute(_unlockIsolate, {
      'password': password,
      'saltHex': saltHex,
      'verifyCipherHex': verifyCipherHex,
      'verifyIvHex': verifyIvHex,
    });
  }

  void _decryptAllEntries() {
    final Map<int, String?> decrypted = {};
    for (final entry in _entries) {
      final plain = VaultService.instance.decryptEntryPassword(entry);
      decrypted[entry.id!] = plain;
    }
    setState(() {
      _decryptedPasswords = decrypted;
      _isUnlocked = true;
    });
  }

  void _handleLock() {
    VaultSession.instance.lock();
    setState(() {
      _isUnlocked = false;
      _decryptedPasswords = {};
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已复制'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteEntry(VaultEntry entry) async {
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
          '确定删除「${entry.title}」？此操作不可撤销。',
          style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
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
      await VaultService.instance.deleteEntry(entry.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            _category?.name ?? '密码列表',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _isUnlocked ? _handleLock : _handleUnlock,
                icon: Icon(
                  _isUnlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                ),
                color: _isUnlocked ? appTheme.sage : appTheme.earth,
                iconSize: 20,
                tooltip: _isUnlocked ? '锁定密码' : '解锁查看密码',
              ),
            ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: appTheme.primary))
            : _entries.isEmpty
                ? _buildEmpty(appTheme)
                : _buildEntryList(appTheme),
        floatingActionButton: _buildFab(appTheme),
      ),
    );
  }

  Widget _buildFab(AppThemeExtension appTheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [appTheme.primary, appTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push('/vault/add?categoryId=${widget.categoryId}');
            _load();
          },
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppThemeExtension appTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_off_rounded, size: 56, color: appTheme.earthMedium),
          const SizedBox(height: 12),
          Text(
            '还没有密码记录',
            style: AppTypography.bodyLg.copyWith(color: appTheme.earthLight),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 添加密码',
            style: AppTypography.bodySm.copyWith(color: appTheme.earthMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(AppThemeExtension appTheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryCard(entry, appTheme);
      },
    );
  }

  Widget _buildEntryCard(VaultEntry entry, AppThemeExtension appTheme) {
    final decryptedPwd =
        _isUnlocked ? _decryptedPasswords[entry.id!] : null;
    final hasNote = entry.note != null && entry.note!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: appTheme.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusLg),
          ),
          child: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
        ),
        confirmDismiss: (_) async {
          await _confirmDeleteEntry(entry);
          return false;
        },
        child: Material(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(appTheme.radiusLg),
            onTap: () async {
              if (!_isUnlocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请先解锁后再编辑'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              await context.push('/vault/edit/${entry.id}');
              _load();
            },
            onLongPress: () => _showEntryActions(entry),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 标题行 + 复制标题 ──
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: AppTypography.bodyLg
                              .copyWith(color: appTheme.earth),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildSmallAction(
                        icon: Icons.copy_rounded,
                        appTheme: appTheme,
                        onTap: () =>
                            _copyToClipboard(entry.title, '标题'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── 密码行 ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: appTheme.cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isUnlocked && decryptedPwd != null
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          size: 14,
                          color: _isUnlocked && decryptedPwd != null
                              ? appTheme.sage
                              : appTheme.earthMedium,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isUnlocked && decryptedPwd != null
                                ? decryptedPwd
                                : '••••••••',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isUnlocked && decryptedPwd != null
                                  ? appTheme.earth
                                  : appTheme.earthMedium,
                              letterSpacing:
                                  _isUnlocked && decryptedPwd != null
                                      ? 0.5
                                      : 2.5,
                              fontFamily:
                                  _isUnlocked && decryptedPwd != null
                                      ? 'monospace'
                                      : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isUnlocked && decryptedPwd != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _copyToClipboard(
                                decryptedPwd, '密码'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: appTheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded,
                                      size: 12,
                                      color: appTheme.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '复制',
                                    style: AppTypography.caption
                                        .copyWith(
                                            color: appTheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // ── 备注（放在最下面） ──
                  if (hasNote) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.note!,
                      style: AppTypography.bodySm
                          .copyWith(color: appTheme.earthMedium),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAction({
    required IconData icon,
    required AppThemeExtension appTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: appTheme.earthMedium),
      ),
    );
  }

  void _showEntryActions(VaultEntry entry) {
    final appTheme = Theme.of(context).appTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: appTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(appTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: appTheme.earthMedium.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: appTheme.primary),
              title: Text('编辑',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.earth)),
              onTap: () {
                Navigator.pop(ctx);
                if (!_isUnlocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请先解锁后再编辑'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                context.push('/vault/edit/${entry.id}').then((_) => _load());
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, color: appTheme.rose),
              title: Text('删除',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.rose)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteEntry(entry);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Isolate 入口：在后台线程执行 Argon2id 验证 + 密钥派生
/// 成功时返回派生密钥的 hex 字符串，失败返回 null
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

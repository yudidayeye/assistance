import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/vault_category.dart';
import '../models/vault_entry.dart';
import '../models/vault_note_item.dart';
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

class _CategoryEntriesPageState extends State<CategoryEntriesPage>
    with WidgetsBindingObserver {
  VaultCategory? _category;
  List<VaultEntry> _entries = [];
  Map<int, String?> _decryptedPasswords = {};
  bool _loading = true;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 回到前台时，若会话已在后台锁定，同步页面解锁状态
    if (state == AppLifecycleState.resumed && VaultSession.instance.isLocked) {
      _syncLockedState();
    }
  }

  /// 同步页面解锁显示与真实会话状态（后台锁定后页面仍显示已解锁的场景）
  void _syncLockedState() {
    if (!mounted) return;
    if (_category?.isEncrypted ?? true) {
      setState(() {
        _isUnlocked = false;
        _decryptedPasswords = {};
      });
    } else {
      _load();
    }
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
              id: widget.categoryId, name: '未知', createdAt: '', updatedAt: ''),
    );
    final entries =
        await VaultService.instance.getEntriesByCategory(widget.categoryId);

    final isEncrypted = category.isEncrypted;
    Map<int, String?> decrypted = {};
    if (!VaultSession.instance.isLocked || !isEncrypted) {
      for (final entry in entries) {
        final plain = VaultService.instance
            .decryptEntryPassword(entry, isEncrypted: isEncrypted);
        decrypted[entry.id!] = plain;
      }
      if (isEncrypted && decrypted.isNotEmpty && mounted) {
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
  Future<bool?> _showUnlockDialog({String? hint}) async {
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
                    if (hint != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          hint,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: appTheme.rose,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
                          borderRadius:
                              BorderRadius.circular(appTheme.radiusSm),
                          borderSide: BorderSide(
                            color: appTheme.earthMedium.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                        : Text('解锁', style: TextStyle(color: appTheme.primary)),
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
      final plain = VaultService.instance.decryptEntryPassword(entry,
          isEncrypted: _category?.isEncrypted ?? true);
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
    AppSnackBar.show(context, '$label 已复制');
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
                style:
                    AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
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

  void _showEntryActions(VaultEntry entry) {
    final appTheme = Theme.of(context).appTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: appTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(appTheme.radiusLg)),
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
              onTap: () async {
                Navigator.pop(ctx);
                // 编辑前先确认已解锁，未解锁弹窗输入主密码
                if (VaultSession.instance.isLocked) {
                  if (_isUnlocked) _syncLockedState();
                  final unlocked = await _showUnlockDialog(hint: '请先解锁后再编辑密码！');
                  if (unlocked != true || !mounted) return;
                }
                context.push('/vault/edit/${entry.id}').then((_) => _load());
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
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
            if (_category?.isEncrypted ?? true)
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
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: _buildFab(appTheme),
        ),
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
            // 跳转新增页面前先确认已解锁，未解锁弹窗输入主密码
            if ((_category?.isEncrypted ?? true) &&
                VaultSession.instance.isLocked) {
              if (_isUnlocked) _syncLockedState();
              final unlocked = await _showUnlockDialog(hint: '请先解锁后再新增密码！');
              if (unlocked != true || !mounted) return;
            }
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
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _entries.length,
      buildDefaultDragHandles: false,
      onReorderItem: _handleEntryReorder,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryCard(entry, appTheme, index: index);
      },
    );
  }

  /// 密码条目拖动排序：更新本地顺序并持久化
  void _handleEntryReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _entries.removeAt(oldIndex);
      _entries.insert(newIndex, item);
    });
    final categoryId = _category?.id;
    if (categoryId != null) {
      VaultService.instance
          .reorderEntries(categoryId, _entries.map((e) => e.id!).toList());
    }
  }

  Widget _buildEntryCard(
    VaultEntry entry,
    AppThemeExtension appTheme, {
    required int index,
  }) {
    final decryptedPwd = _decryptedPasswords[entry.id!];
    final noteItems = entry.noteItems;
    final title = entry.title.trim();
    final username = entry.username?.trim() ?? '';
    final displayTitle =
        title.isNotEmpty ? title : (username.isNotEmpty ? username : '未命名');

    return Padding(
      key: ValueKey('entry-${entry.id}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: appTheme.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          child: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
        ),
        confirmDismiss: (_) async {
          await _confirmDeleteEntry(entry);
          return false;
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: appTheme.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  side: BorderSide(
                    color: appTheme.earthMedium.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onLongPress: () => _showEntryActions(entry),
                  onTap: () => _openEntryDetail(entry),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 标题行 + 复制标题 ──
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayTitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: appTheme.earth,
                                        letterSpacing: -0.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (title.isNotEmpty)
                                    _buildSmallAction(
                                      icon: Icons.copy_rounded,
                                      appTheme: appTheme,
                                      onTap: () =>
                                          _copyToClipboard(title, '标题'),
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openEntryDetail(entry),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                  color: appTheme.earthMedium
                                      .withValues(alpha: 0.36),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ── 凭据区（用户名 + 密码） ──
                        const SizedBox(height: 8),
                        if (username.isNotEmpty && title.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                _buildCredentialIcon(
                                  icon: Icons.person_outline_rounded,
                                  color: appTheme.primary,
                                  appTheme: appTheme,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: appTheme.earth,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildCopyBadge(
                                  () => _copyToClipboard(username, '用户名'),
                                  appTheme,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Divider(
                              height: 1,
                              thickness: 0.5,
                              color:
                                  appTheme.earthMedium.withValues(alpha: 0.10),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              _buildCredentialIcon(
                                icon: decryptedPwd != null
                                    ? Icons.lock_open_rounded
                                    : Icons.lock_outline_rounded,
                                color: decryptedPwd != null
                                    ? appTheme.sage
                                    : appTheme.earthMedium,
                                appTheme: appTheme,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  decryptedPwd ?? '••••••••',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: decryptedPwd != null
                                        ? appTheme.earth
                                        : appTheme.earthMedium,
                                    letterSpacing:
                                        decryptedPwd != null ? 0.5 : 2.5,
                                    fontFamily: decryptedPwd != null
                                        ? 'monospace'
                                        : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (decryptedPwd != null) ...[
                                const SizedBox(width: 6),
                                _buildCopyBadge(
                                  () => _copyToClipboard(decryptedPwd, '密码'),
                                  appTheme,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ── 备注（多条，每条可复制） ──
                        if (noteItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  appTheme.earthMedium.withValues(alpha: 0.02),
                              border: Border.all(
                                color: appTheme.earthMedium
                                    .withValues(alpha: 0.15),
                              ),
                              borderRadius:
                                  BorderRadius.circular(appTheme.radiusMd),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < noteItems.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: appTheme.earthMedium
                                          .withValues(alpha: 0.12),
                                    ),
                                  _buildNoteItem(
                                    noteItems[i],
                                    appTheme,
                                    titleWidth:
                                        _measureNoteTitleWidth(noteItems),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 拖拽排序手柄
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 进入密码详情（编辑页），未解锁时先弹主密码输入框
  Future<void> _openEntryDetail(VaultEntry entry) async {
    if ((_category?.isEncrypted ?? true) && VaultSession.instance.isLocked) {
      if (_isUnlocked) _syncLockedState();
      final unlocked = await _showUnlockDialog(hint: '请先解锁后再编辑密码！');
      if (unlocked != true || !mounted) return;
    }
    await context.push('/vault/edit/${entry.id}');
    _load();
  }

  /// 凭据区图标徽章（浅色小圆角底）
  Widget _buildCredentialIcon({
    required IconData icon,
    required Color color,
    required AppThemeExtension appTheme,
  }) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Icon(icon, size: 13, color: color),
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

  /// 复制胶囊按钮（subtle 为 true 时使用次级弱化样式）
  Widget _buildCopyBadge(
    VoidCallback onTap,
    AppThemeExtension appTheme, {
    bool subtle = false,
  }) {
    final color = subtle ? appTheme.earthMedium : appTheme.primary;
    final background = subtle
        ? appTheme.earthMedium.withValues(alpha: 0.08)
        : appTheme.primary.withValues(alpha: 0.1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              '复制',
              style: AppTypography.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// 计算备注标题标签的最大宽度，保证多条备注的描述起点对齐
  double _measureNoteTitleWidth(List<VaultNoteItem> items) {
    double maxWidth = 24;
    for (final item in items) {
      final label = item.title.trim().isEmpty ? '备注' : item.title;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
    return maxWidth;
  }

  /// 单条备注：表格行（标题列 + 描述 + 复制）
  Widget _buildNoteItem(
    VaultNoteItem item,
    AppThemeExtension appTheme, {
    required double titleWidth,
  }) {
    final label = item.title.trim().isEmpty ? '备注' : item.title;
    final content = item.content.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题列（统一宽度，允许换行）
          SizedBox(
            width: titleWidth,
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: appTheme.earth,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 描述（占满剩余空间，允许换行）
          Expanded(
            child: Text(
              content,
              style: AppTypography.bodySm.copyWith(
                color: appTheme.earthMedium,
                height: 1.5,
              ),
            ),
          ),
          // 复制（固定最右侧）
          if (content.isNotEmpty) ...[
            const SizedBox(width: 6),
            _buildCopyBadge(
              () => _copyToClipboard(item.copyText, '备注'),
              appTheme,
              subtle: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Isolate 入口：在后台线程执行 Argon2id 验证 + 密钥派生
/// 成功时返回派生密钥的 hex 字符串，失败返回 null
String? _unlockIsolate(Map<String, String> params) {
  final crypto = VaultCryptoService.instance;
  final key = crypto.verifyAndDeriveKey(
    params['password']!,
    params['saltHex']!,
    params['verifyCipherHex']!,
    params['verifyIvHex']!,
  );
  if (key == null) return null;
  return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

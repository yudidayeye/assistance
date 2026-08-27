import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../models/vault_entry.dart';
import '../models/vault_note_item.dart';
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<_NoteInput> _notes = [];

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  VaultEntry? _existingEntry;
  int? _selectedCategoryId;
  bool _isEncrypted = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    _loadCategoryInfo();
    if (widget.entryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEntry();
      });
    }
  }

  Future<void> _loadCategoryInfo() async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return;
    final category = await VaultService.instance.getCategory(categoryId);
    if (mounted && category != null) {
      setState(() => _isEncrypted = category.isEncrypted);
    }
  }

  Future<void> _loadEntry() async {
    final entry = await VaultService.instance.getEntry(widget.entryId!);
    if (entry == null || !mounted) return;

    final category =
        await VaultService.instance.getCategory(entry.categoryId);
    _isEncrypted = category?.isEncrypted ?? true;

    // 编辑模式需要解锁（仅加密分类）
    if (_isEncrypted && VaultSession.instance.isLocked) {
      if (mounted) {
        Navigator.of(context).pop();
        if (mounted) {
          AppSnackBar.show(context, '请先解锁后再编辑密码！');
        }
      }
      return;
    }

    final plainPassword = VaultService.instance
        .decryptEntryPassword(entry, isEncrypted: _isEncrypted);
    setState(() {
      _existingEntry = entry;
      _selectedCategoryId = entry.categoryId;
      _titleController.text = entry.title;
      _usernameController.text = entry.username ?? '';
      _passwordController.text = plainPassword ?? '';
      _notes
        ..clear()
        ..addAll(entry.noteItems.map((item) {
          final input = _NoteInput();
          input.title.text = item.title;
          input.content.text = item.content;
          return input;
        }));
    });
  }

  /// 确保会话已解锁，如果未解锁则弹窗让用户输入主密码
  /// 返回 true 表示已解锁
  Future<bool> _ensureUnlocked({String? hint}) async {
    if (!VaultSession.instance.isLocked) return true;
    final result = await _showUnlockDialog(hint: hint);
    return result == true;
  }

  /// 弹窗输入主密码解锁
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
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: appTheme.earthMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
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
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _error = '请选择分类');
      return;
    }

    // 保存前如果未解锁，先弹窗解锁（仅加密分类）
    if (_isEncrypted && VaultSession.instance.isLocked) {
      final unlocked = await _ensureUnlocked(
        hint: _existingEntry == null
            ? '请先解锁后再新增密码！'
            : '请先解锁后再修改密码！',
      );
      if (!unlocked) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final note = VaultEntry.encodeNotes(_notes
        .map((n) => VaultNoteItem(
            title: n.title.text.trim(), content: n.content.text.trim()))
        .toList());

    try {
      if (_existingEntry != null) {
        await VaultService.instance.updateEntry(
          entryId: _existingEntry!.id!,
          categoryId: _selectedCategoryId!,
          title: title,
          username: username,
          plainPassword: password,
          note: note,
        );
      } else {
        await VaultService.instance.insertEntry(
          categoryId: _selectedCategoryId!,
          title: title,
          username: username,
          plainPassword: password,
          note: note,
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
    _usernameController.dispose();
    _passwordController.dispose();
    for (final note in _notes) {
      note.dispose();
    }
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
            // 标题（可选）
            _buildLabel('标题（可选）', appTheme),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _titleController,
              hint: '例：GitHub 主账号',
              appTheme: appTheme,
            ),
            const SizedBox(height: 20),
            // 用户名（可选）
            _buildLabel('用户名（可选）', appTheme),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _usernameController,
              hint: '例：admin@example.com',
              appTheme: appTheme,
            ),
            const SizedBox(height: 20),
            // 密码（必填）
            _buildLabel('密码（必填）', appTheme),
            const SizedBox(height: 6),
            _buildPasswordField(appTheme),
            const SizedBox(height: 20),
            // 备注（多条：标题 + 描述，可拖动排序）
            _buildLabel('备注（可选）', appTheme),
            const SizedBox(height: 6),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: _onNoteReorder,
              proxyDecorator: (child, index, animation) =>
                  _buildNoteDragProxy(child, animation, appTheme),
              children: [
                for (var i = 0; i < _notes.length; i++)
                  Padding(
                    key: ObjectKey(_notes[i]),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildNoteItemEditor(i, appTheme),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _addNote,
              icon: Icon(Icons.add_rounded, size: 16, color: appTheme.primary),
              label: Text(
                '添加备注',
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: appTheme.primary.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(appTheme.radiusMd),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
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

  void _addNote() {
    setState(() => _notes.add(_NoteInput()));
  }

  void _removeNote(int index) {
    setState(() => _notes.removeAt(index).dispose());
  }

  /// 备注拖动排序：将条目从旧位置移动到新位置
  void _onNoteReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _notes.removeAt(oldIndex);
      _notes.insert(newIndex, item);
    });
  }

  /// 拖动中的备注卡片：轻微抬升阴影，保持圆角
  Widget _buildNoteDragProxy(
      Widget child, Animation<double> animation, AppThemeExtension appTheme) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
        return Material(
          color: Colors.transparent,
          elevation: elevation,
          shadowColor: appTheme.earth.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          child: child,
        );
      },
    );
  }

  /// 单条备注编辑卡片：标题 + 描述 + 删除
  Widget _buildNoteItemEditor(int index, AppThemeExtension appTheme) {
    final input = _notes[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        border: Border.all(
          color: appTheme.earthMedium.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: '拖动排序',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: appTheme.earthLight.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: input.title,
              hint: '标题',
              appTheme: appTheme,
              textStyle: AppTypography.bodySm.copyWith(
                color: appTheme.earth,
                fontWeight: FontWeight.w400,
              ),
              hintStyle: AppTypography.caption
                  .copyWith(color: appTheme.earthMedium),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _buildTextField(
              controller: input.content,
              hint: '描述',
              appTheme: appTheme,
              maxLines: 1,
              textStyle: AppTypography.bodySm.copyWith(
                color: appTheme.earth,
                fontWeight: FontWeight.w400,
              ),
              hintStyle: AppTypography.caption
                  .copyWith(color: appTheme.earthMedium),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: appTheme.rose,
              ),
              onPressed: () => _removeNote(index),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: '删除该条备注',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required AppThemeExtension appTheme,
    int maxLines = 1,
    TextStyle? textStyle,
    TextStyle? hintStyle,
    EdgeInsetsGeometry? contentPadding,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: textStyle ?? AppTypography.bodyLg.copyWith(color: appTheme.earth),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            hintStyle ?? AppTypography.bodyMd.copyWith(color: appTheme.earthMedium),
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
          borderSide: BorderSide(color: appTheme.primary, width: 1),
        ),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: suffixIcon,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
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

/// 单条备注的输入状态（标题 + 描述）
class _NoteInput {
  final TextEditingController title = TextEditingController();
  final TextEditingController content = TextEditingController();

  void dispose() {
    title.dispose();
    content.dispose();
  }
}

/// Isolate 入口：在后台线程执行 Argon2id 验证 + 密钥派生
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

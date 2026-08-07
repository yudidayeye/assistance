import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../models/vault_category.dart';
import '../services/vault_service.dart';
import 'master_password_page.dart';

/// 密码保险箱入口页 — 分类列表
class VaultEntryPage extends StatefulWidget {
  const VaultEntryPage({super.key});

  @override
  State<VaultEntryPage> createState() => _VaultEntryPageState();
}

class _VaultEntryPageState extends State<VaultEntryPage> {
  List<VaultCategory> _categories = [];
  bool _loading = true;
  bool _needSetup = false;
  bool _isSetup = false;
  bool _navigating = false;

  // 预置分类图标映射
  static const _presetIcons = <String, IconData>{
    'email': Icons.email_rounded,
    'git': Icons.code_rounded,
    'cloud': Icons.cloud_rounded,
    'social': Icons.people_rounded,
    'finance': Icons.account_balance_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'game': Icons.sports_esports_rounded,
    'work': Icons.work_rounded,
    'folder': Icons.folder_rounded,
    'lock': Icons.lock_rounded,
    'wifi': Icons.wifi_rounded,
    'server': Icons.dns_rounded,
    'database': Icons.storage_rounded,
    'key': Icons.vpn_key_rounded,
    'phone': Icons.phone_android_rounded,
  };

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
    VaultService.instance.addListener(_onVaultChanged);
  }

  @override
  void dispose() {
    VaultService.instance.removeListener(_onVaultChanged);
    super.dispose();
  }

  void _onVaultChanged() {
    if (mounted) {
      _loadCategories();
    }
  }

  Future<void> _checkAndLoad() async {
    final hasMaster = await VaultService.instance.hasMasterPassword();
    if (!hasMaster) {
      if (mounted) {
        setState(() {
          _isSetup = true;
          _needSetup = true;
          _loading = false;
        });
      }
      return;
    }

    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await VaultService.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _loading = false;
        _needSetup = false;
      });
    }
  }

  Future<void> _navigateToUnlock() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MasterPasswordPage(
            isSetup: _isSetup,
            onSuccess: () {},
          ),
        ),
      );
      if (result == true) {
        await _loadCategories();
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  IconData _getIcon(String iconName) {
    return _presetIcons[iconName] ?? Icons.folder_rounded;
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'folder';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final appTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: appTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusLg),
              ),
              title: Text(
                '新增分类',
                style: AppTypography.displayMd.copyWith(color: appTheme.earth),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: appTheme.earth),
                    decoration: InputDecoration(
                      labelText: '分类名称',
                      labelStyle: TextStyle(color: appTheme.earthLight),
                      filled: true,
                      fillColor: appTheme.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '选择图标',
                    style: AppTypography.bodySm.copyWith(color: appTheme.earthLight),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetIcons.entries.map((e) {
                      final isSelected = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedIcon = e.key),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? appTheme.primary.withValues(alpha: 0.15)
                                : appTheme.cream,
                            borderRadius:
                                BorderRadius.circular(appTheme.radiusSm),
                            border: isSelected
                                ? Border.all(color: appTheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Icon(
                            e.value,
                            size: 20,
                            color: isSelected
                                ? appTheme.primary
                                : appTheme.earthMedium,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('取消',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('确定',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.primary)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      await VaultService.instance.insertCategory(VaultCategory(
        name: nameController.text.trim(),
        icon: selectedIcon,
        sortOrder: _categories.length,
        createdAt: now,
        updatedAt: now,
      ));
      await _loadCategories();
    }
  }

  Future<void> _showEditCategoryDialog(VaultCategory category) async {
    final nameController = TextEditingController(text: category.name);
    String selectedIcon = category.icon;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final appTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: appTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(appTheme.radiusLg),
              ),
              title: Text(
                '编辑分类',
                style: AppTypography.displayMd.copyWith(color: appTheme.earth),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: appTheme.earth),
                    decoration: InputDecoration(
                      labelText: '分类名称',
                      labelStyle: TextStyle(color: appTheme.earthLight),
                      filled: true,
                      fillColor: appTheme.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(appTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '选择图标',
                    style: AppTypography.bodySm.copyWith(color: appTheme.earthLight),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetIcons.entries.map((e) {
                      final isSelected = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedIcon = e.key),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? appTheme.primary.withValues(alpha: 0.15)
                                : appTheme.cream,
                            borderRadius:
                                BorderRadius.circular(appTheme.radiusSm),
                            border: isSelected
                                ? Border.all(color: appTheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Icon(
                            e.value,
                            size: 20,
                            color: isSelected
                                ? appTheme.primary
                                : appTheme.earthMedium,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('取消',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.earthLight)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('确定',
                      style: AppTypography.bodyMd.copyWith(color: appTheme.primary)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await VaultService.instance.updateCategory(category.copyWith(
        name: nameController.text.trim(),
        icon: selectedIcon,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      await _loadCategories();
    }
  }

  Future<void> _confirmDeleteCategory(VaultCategory category) async {
    final count = await VaultService.instance.getCategoryEntryCount(category.id!);
    if (!mounted) return;

    final appTheme = Theme.of(context).appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
        ),
        title: Text('删除分类',
            style: AppTypography.displayMd.copyWith(color: appTheme.earth)),
        content: Text(
          count > 0
              ? '「${category.name}」下有 $count 条密码记录，删除分类将同时删除所有记录，确定删除？'
              : '确定删除「${category.name}」？',
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
      await VaultService.instance.deleteCategory(category.id!);
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    // 首次使用，需设置主密码
    if (_needSetup) {
      return _buildSetupScreen(appTheme);
    }

    if (_loading) {
      return AppScaffold(
        appBar: AppBar(
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '密码保险箱',
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: appTheme.primary),
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          '密码保险箱',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
        actions: [],
      ),
      body: _categories.isEmpty
          ? _buildEmptyState(appTheme)
          : _buildCategoryList(appTheme),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: _buildFab(appTheme),
      ),
    );
  }

  Widget _buildSetupScreen(AppThemeExtension appTheme) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          '密码保险箱',
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 64, color: appTheme.primary),
            const SizedBox(height: 16),
            Text(
              '欢迎使用密码保险箱',
              style: AppTypography.displayMd.copyWith(color: appTheme.earth),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _navigating ? null : _navigateToUnlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: appTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusPill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  elevation: 0,
                ),
                child: _navigating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSetup ? '设置主密码' : '解锁',
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

  Widget _buildEmptyState(AppThemeExtension appTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 56, color: appTheme.earthMedium),
          const SizedBox(height: 12),
          Text(
            '还没有分类',
            style: AppTypography.bodyLg.copyWith(color: appTheme.earthLight),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 创建第一个分类',
            style: AppTypography.bodySm.copyWith(color: appTheme.earthMedium),
          ),
        ],
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
          onTap: _showAddCategoryDialog,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildCategoryList(AppThemeExtension appTheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildCategoryCard(category, appTheme);
      },
    );
  }

  Widget _buildCategoryCard(VaultCategory category, AppThemeExtension appTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
          onTap: () {
            context.push('/vault/category/${category.id}');
          },
          onLongPress: () => _showCategoryActions(category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: appTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(appTheme.radiusMd),
                  ),
                  child: Icon(
                    _getIcon(category.icon),
                    color: appTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // 名称
                Expanded(
                  child: Text(
                    category.name,
                    style: AppTypography.bodyLg.copyWith(color: appTheme.earth),
                  ),
                ),
                // 条目数
                FutureBuilder<int>(
                  future: VaultService.instance.getCategoryEntryCount(category.id!),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count > 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '$count',
                          style: AppTypography.bodySm
                              .copyWith(color: appTheme.earthMedium),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // 箭头
                Icon(
                  Icons.chevron_right_rounded,
                  color: appTheme.earthMedium,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryActions(VaultCategory category) {
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
                _showEditCategoryDialog(category);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: appTheme.rose),
              title: Text('删除',
                  style: AppTypography.bodyMd.copyWith(color: appTheme.rose)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteCategory(category);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

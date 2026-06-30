import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/category_service.dart';
import '../../../core/theme/theme_extension.dart';

/// 分类管理页面 — 柔和风格
class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({super.key});

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final expense = await CategoryService.instance.getExpenseCategories();
    final income = await CategoryService.instance.getIncomeCategories();
    if (mounted) {
      setState(() {
        _expenseCategories = expense;
        _incomeCategories = income;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return Scaffold(
      backgroundColor: appTheme.cream,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: appTheme.primary,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 头部区域
                SliverToBoxAdapter(
                  child: _buildHeader(context, appTheme),
                ),

                // 支出分类
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                      appTheme, '支出分类', Icons.arrow_downward_rounded),
                ),
                SliverToBoxAdapter(
                  child: _buildCategorySection(
                      appTheme, _expenseCategories, TransactionType.expense),
                ),

                // 收入分类
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                      appTheme, '收入分类', Icons.arrow_upward_rounded),
                ),
                SliverToBoxAdapter(
                  child: _buildCategorySection(
                      appTheme, _incomeCategories, TransactionType.income),
                ),

                // 底部间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeExtension appTheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 16, 24, 16),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: appTheme.earthMedium,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '分类管理',
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      AppThemeExtension appTheme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: appTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: GoogleFonts.playfairDisplay().fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
      AppThemeExtension appTheme, List<Category> categories, TransactionType type) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusLg),
        boxShadow: appTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 分类列表
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            final isLast = index == categories.length - 1;

            return Column(
              children: [
                _buildCategoryItem(appTheme, cat),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 60,
                    color: appTheme.earthMedium.withAlpha(15),
                  ),
              ],
            );
          }),

          // 添加按钮
          Divider(
            height: 1,
            color: appTheme.earthMedium.withAlpha(15),
          ),
          _buildAddButton(appTheme, type),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(AppThemeExtension appTheme, Category cat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // 分类图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appTheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              cat.icon,
              color: appTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // 分类名称
          Expanded(
            child: Text(
              cat.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
            ),
          ),

          // 标签或删除按钮
          if (cat.isCustom)
            GestureDetector(
              onTap: () async {
                final result = await CategoryService.instance.deleteCategory(cat.id);
                if (result == DeleteCategoryResult.referenced && mounted) {
                  _showSnackBar('该分类下还有交易记录，无法删除', isError: true);
                  return;
                }
                _loadCategories();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: appTheme.rose.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: appTheme.rose,
                  size: 18,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: appTheme.creamDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '预设',
                style: TextStyle(
                  fontSize: 11,
                  color: appTheme.earthMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton(AppThemeExtension appTheme, TransactionType type) {
    return GestureDetector(
      onTap: () => _showAddDialog(type),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: appTheme.sage.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add_rounded,
                color: appTheme.sage,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '添加自定义分类',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: appTheme.sage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final appTheme = Theme.of(context).appTheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.white : appTheme.earth,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? appTheme.rose : appTheme.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _showAddDialog(TransactionType type) {
    showDialog(
      context: context,
      builder: (ctx) => _AddCategoryDialog(type: type),
    ).then((_) => _loadCategories());
  }
}

/// 添加分类弹窗 — 独立 StatefulWidget，弹窗内部维护图标选中状态
class _AddCategoryDialog extends StatefulWidget {
  final TransactionType type;

  const _AddCategoryDialog({required this.type});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  IconData _selectedIcon = Icons.label;
  static const _availableIcons = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.home,
    Icons.sports_esports,
    Icons.medical_services,
    Icons.school,
    Icons.phone_android,
    Icons.checkroom,
    Icons.label,
    Icons.payments,
    Icons.card_giftcard,
    Icons.trending_up,
    Icons.laptop,
    Icons.more_horiz,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final currentCats = await CategoryService.instance.getCategories(widget.type);
    await CategoryService.instance.addCustomCategory(
      Category(
        id: 'custom_${const Uuid().v4().substring(0, 8)}',
        name: name,
        type: widget.type,
        icon: _selectedIcon,
        isCustom: true,
        sortOrder: currentCats.length,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appTheme.cream,
          borderRadius: BorderRadius.circular(appTheme.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '添加${widget.type == TransactionType.expense ? '支出' : '收入'}分类',
              style: TextStyle(
                fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '分类名称',
                  hintStyle: TextStyle(
                    color: appTheme.earthMedium.withAlpha(120),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                style: TextStyle(
                  color: appTheme.earth,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '选择图标',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons
                    .map((icon) => GestureDetector(
                          onTap: () => setState(() => _selectedIcon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _selectedIcon == icon
                                  ? appTheme.primary.withAlpha(30)
                                  : appTheme.creamDark,
                              borderRadius: BorderRadius.circular(12),
                              border: _selectedIcon == icon
                                  ? Border.all(color: appTheme.primary)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              size: 22,
                              color: _selectedIcon == icon
                                  ? appTheme.primary
                                  : appTheme.earthMedium,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: appTheme.creamDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: appTheme.earthMedium.withAlpha(30),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: appTheme.earthMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _add,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [appTheme.primary, appTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

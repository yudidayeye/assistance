import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/category_service.dart';
import '../../../core/theme/theme_extension.dart';

/// 分类管理页面 — 奢华自然主义风格
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
                color: appTheme.gold,
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
                color: appTheme.creamDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: appTheme.earthMedium.withAlpha(30),
                ),
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
              color: appTheme.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: appTheme.gold,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
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
              color: appTheme.gold.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              cat.icon,
              color: appTheme.gold,
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
                await CategoryService.instance.deleteCategory(cat.id);
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

  void _showAddDialog(TransactionType type) {
    final appTheme = Theme.of(context).appTheme;
    String name = '';
    IconData selectedIcon = Icons.label;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                '添加${type == TransactionType.expense ? '支出' : '收入'}分类',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 20),

              // 输入框
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: appTheme.earthMedium.withAlpha(30),
                  ),
                ),
                child: TextField(
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
                  onChanged: (v) => name = v,
                ),
              ),
              const SizedBox(height: 20),

              // 图标选择
              Text(
                '选择图标',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
              const SizedBox(height: 12),

              // 图标网格
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: appTheme.earthMedium.withAlpha(20),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                  ]
                      .map((icon) => GestureDetector(
                            onTap: () {
                              setState(() => selectedIcon = icon);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selectedIcon == icon
                                    ? appTheme.gold.withAlpha(30)
                                    : appTheme.creamDark,
                                borderRadius: BorderRadius.circular(12),
                                border: selectedIcon == icon
                                    ? Border.all(color: appTheme.gold)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                size: 22,
                                color: selectedIcon == icon
                                    ? appTheme.gold
                                    : appTheme.earthMedium,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
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
                      onTap: () async {
                        if (name.trim().isEmpty) return;
                        final currentCats =
                            await CategoryService.instance.getCategories(type);
                        await CategoryService.instance.addCustomCategory(
                          Category(
                            id:
                                'custom_${const Uuid().v4().substring(0, 8)}',
                            name: name.trim(),
                            type: type,
                            icon: selectedIcon,
                            isCustom: true,
                            sortOrder: currentCats.length,
                          ),
                        );
                        Navigator.pop(ctx);
                        _loadCategories();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [appTheme.gold, appTheme.goldDark],
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
      ),
    );
  }
}

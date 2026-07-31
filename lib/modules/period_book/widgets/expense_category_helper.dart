import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/foundation/app_spacing.dart';
import '../../../../shared/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 支出分类相关工具方法（阶段编辑页和大额记录页共用）
class ExpenseCategoryHelper {
  // 数据库 category 值 → 显示名称
  static const _categoryDisplayMap = {
    'shopping': '购物',
    'other': '其他',
  };

  // 显示名称 → 数据库存储值
  static const _categoryValueMap = {
    '生活': '生活',
    '购物': '购物',
    '工作': '工作',
    '娱乐': '娱乐',
    '大餐': '大餐',
  };

  // 可选类型列表
  static const _categories = ['生活', '购物', '工作', '娱乐', '大餐'];

  static String mapCategoryForDisplay(String dbValue) {
    return _categoryDisplayMap[dbValue] ?? dbValue;
  }

  static String categoryToDbValue(String displayName) {
    return _categoryValueMap[displayName] ?? displayName;
  }

  static List<String> get expenseCategories => _categories;

  static bool isOtherCategory(String category) {
    return category == 'other';
  }

  static IconData? categoryIcon(String displayName) {
    switch (displayName) {
      case '其他':
        return null;
      case '生活':
        return Icons.coffee_outlined;
      case '购物':
        return Icons.shopping_bag_outlined;
      case '工作':
        return Icons.business_center_outlined;
      case '娱乐':
        return Icons.sports_esports_outlined;
      case '大餐':
        return Icons.restaurant_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  static Color categoryColor(AppThemeExtension appTheme, String displayName) {
    switch (displayName) {
      case '生活':
        return appTheme.sage;
      case '购物':
        return const Color(0xFF8B7EC8);
      case '工作':
        return const Color(0xFF3E6FA0);
      case '娱乐':
        return const Color(0xFFC49A6C);
      case '大餐':
        return appTheme.rose;
      default:
        return appTheme.earthMedium.withValues(alpha: 0.5);
    }
  }

  /// 构建支出列表项（阶段编辑页和大额记录页共用）
  static Widget buildExpenseItem({
    required BuildContext context,
    required AppThemeExtension appTheme,
    required String expenseId,
    required String category,
    required String description,
    required double amount,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    Widget? leading,
  }) {
    final displayCat = mapCategoryForDisplay(category);
    final icon = categoryIcon(displayCat);
    final color = categoryColor(appTheme, displayCat);

    return GestureDetector(
      key: ValueKey('expense_$expenseId'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: appTheme.earthMedium.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) leading,
            if (leading != null) AppSpacing.w8,
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              AppSpacing.w8,
            ],
            if (category != 'other')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(appTheme.radiusPill),
                ),
                child: Text(
                  displayCat,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            AppSpacing.w8,
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earth,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '-${FormatUtils.formatAmount(amount)}',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.rose,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            AppSpacing.w8,
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示编辑支出弹窗（阶段编辑页和大额记录页共用）
  static Future<void> showEditExpenseSheet({
    required BuildContext context,
    required AppThemeExtension appTheme,
    required String category,
    required double amount,
    required String description,
    required bool showCategorySelector,
    required Function(String category, double amount, String description) onSave,
  }) async {
    String selectedCategory = category;
    final amountController = TextEditingController(text: amount.toStringAsFixed(2));
    final descController = TextEditingController(text: description);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx).appTheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: sheetTheme.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTheme.radiusXl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    children: [
                      Text(
                        category == 'other' ? '编辑其他支出' : '编辑支出',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: sheetTheme.earth,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: sheetTheme.earthMedium.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  if (showCategorySelector) ...[
                    // 类型选择
                    Text(
                      '类型',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sheetTheme.earthMedium.withValues(alpha: 0.7),
                      ),
                    ),
                    AppSpacing.h8,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: expenseCategories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        final catColor = categoryColor(sheetTheme, cat);
                        return GestureDetector(
                          onTap: () {
                            setLocal(() => selectedCategory = cat);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? catColor.withValues(alpha: 0.12)
                                  : sheetTheme.creamDark.withValues(alpha: 0.5),
                              borderRadius:
                                  BorderRadius.circular(sheetTheme.radiusPill),
                              border: Border.all(
                                color: isSelected
                                    ? catColor.withValues(alpha: 0.4)
                                    : sheetTheme.earthMedium.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? catColor.withValues(alpha: 0.85)
                                    : sheetTheme.earthMedium,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    AppSpacing.h16,
                  ] else
                    AppSpacing.h12,
                  // 金额
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '金额',
                      hintText: '请输入金额',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: sheetTheme.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                        borderSide: BorderSide(
                          color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                  ),
                  const SizedBox(height: 14),
                  // 描述
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: '描述',
                      hintText: '请输入描述',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: sheetTheme.earthMedium.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: sheetTheme.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(sheetTheme.radiusSm),
                        borderSide: BorderSide(
                          color: sheetTheme.earthMedium.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    style: TextStyle(fontSize: 14, color: sheetTheme.earth),
                  ),
                  AppSpacing.h16,
                  // 确定按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final dbCategory = showCategorySelector
                            ? categoryToDbValue(selectedCategory)
                            : 'other';
                        final parsedAmount = double.tryParse(amountController.text) ?? 0;
                        onSave(dbCategory, parsedAmount, descController.text);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: sheetTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(sheetTheme.radiusMd),
                        ),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('保存修改'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';
import 'expense_category_helper.dart';

/// 支出列表卡片组件（阶段编辑页和大额记录页共用）
///
/// 包含：标题行 + 总金额 + 支出列表 + 添加按钮
class ExpenseSectionCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<ExpenseItemData> expenses;
  final Color color;
  final bool isOther;
  final VoidCallback? onAdd;
  final Function(ExpenseItemData expense)? onEdit;
  final Function(ExpenseItemData expense)? onDelete;

  /// 回调使用移除前的插入索引，与 canReorder / applyReorder 的约定一致。
  final Function(int oldIndex, int newIndex)? onReorder;
  final Widget? leading;
  final Widget? form;
  final bool showAddButton;
  final bool showCategoryLabel;
  final String? focusExpenseId;
  final String? highlightedExpenseId;
  final GlobalKey? focusKey;

  const ExpenseSectionCard({
    super.key,
    required this.title,
    required this.emptyText,
    required this.expenses,
    required this.color,
    this.isOther = false,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onReorder,
    this.leading,
    this.form,
    this.showAddButton = true,
    this.showCategoryLabel = true,
    this.focusExpenseId,
    this.highlightedExpenseId,
    this.focusKey,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(appTheme, total),
            ],
          ),
          AppSpacing.h12,
          // 列表
          if (expenses.isEmpty)
            Center(
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            )
          else if (onReorder != null)
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              // 框架给出移除后的索引；还原为业务排序工具约定的插入索引。
              onReorderItem: (oldIndex, newIndex) {
                onReorder!(
                    oldIndex, newIndex > oldIndex ? newIndex + 1 : newIndex);
              },
              children: [
                for (int i = 0; i < expenses.length; i++)
                  _buildExpenseItem(context, appTheme, expenses[i], index: i),
              ],
            )
          else
            ...expenses.map((e) => _buildExpenseItem(context, appTheme, e)),
          // 内嵌表单（在列表和添加按钮之间）
          if (form != null) ...[
            AppSpacing.h8,
            form!,
          ],
          AppSpacing.h12,
          // 添加按钮
          if (showAddButton && onAdd != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加支出'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTheme.primary,
                  backgroundColor: appTheme.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: appTheme.primary.withValues(alpha: 0.3)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalChip(AppThemeExtension appTheme, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Text(
        '-¥${total.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildExpenseItem(
      BuildContext context, AppThemeExtension appTheme, ExpenseItemData expense,
      {int? index}) {
    Widget? effectiveLeading = leading;
    if (effectiveLeading != null && onReorder != null && index != null) {
      effectiveLeading = ReorderableDragStartListener(
        index: index,
        child: effectiveLeading,
      );
    }

    return AnimatedContainer(
      key: expense.id == focusExpenseId
          ? focusKey
          : ValueKey('expense_row_${expense.id}'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
          color: expense.id == highlightedExpenseId
              ? appTheme.primaryLight.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(appTheme.radiusSm)),
      child: ExpenseCategoryHelper.buildExpenseItem(
        context: context,
        appTheme: appTheme,
        expenseId: expense.id,
        showCategoryLabel: showCategoryLabel,
        category: expense.category,
        description: expense.description,
        amount: expense.amount,
        onTap: () => onEdit?.call(expense),
        onDelete: () => onDelete?.call(expense),
        leading: effectiveLeading,
        entryDate: expense.entryDate,
      ),
    );
  }
}

/// 支出项数据（统一接口）
class ExpenseItemData {
  final String id;
  final String category;
  final String description;
  final double amount;

  /// 存储态发生时间（`YYYY-MM-DD`）；`null` 表示用户未填写。
  final String? entryDate;

  const ExpenseItemData({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    this.entryDate,
  });
}

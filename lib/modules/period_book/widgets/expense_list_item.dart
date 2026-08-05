import '../../../shared/foundation/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/expense_record.dart';

/// 支出明细条目 — 左滑删除
class ExpenseListItem extends StatelessWidget {
  final ExpenseRecord expense;
  final VoidCallback onDelete;
  final bool isReadOnly;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.onDelete,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final isShopping = expense.category == 'shopping';
    // 支出统一红色语义（购物/其他类别仍由图标形状区分）
    final color = appTheme.rose;

    final child = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.cream.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
            ),
            child: Icon(
              isShopping
                  ? Icons.shopping_bag_outlined
                  : Icons.category_outlined,
              size: 18,
              color: color,
            ),
          ),
          AppSpacing.w12,
          Expanded(
            child: Text(
              expense.description,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '-${FormatUtils.formatAmount(expense.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.rose,
            ),
          ),
        ],
      ),
    );

    if (isReadOnly) {
      return child;
    }

    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: appTheme.rose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
        ),
        child:
            Icon(Icons.delete_outline_rounded, color: appTheme.rose, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

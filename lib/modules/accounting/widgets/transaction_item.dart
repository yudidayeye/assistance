import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../core/theme/theme_extension.dart';

/// 交易记录列表项 — 奢华自然主义风格
class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback? onChanged;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense ? appTheme.rose : appTheme.sage;
    final categoryName = category?.name ?? '未知';
    final categoryIcon = category?.icon ?? Icons.receipt_long;

    return GestureDetector(
      onTap: () async {
        final result = await context.push<bool>('/accounting/edit/${transaction.id}');
        if (result == true) onChanged?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: appTheme.earthMedium.withAlpha(20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note ?? categoryName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: appTheme.earth,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              FormatUtils.formatAmountWithSign(transaction.amount,
                  isExpense: isExpense),
              style: TextStyle(
                fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

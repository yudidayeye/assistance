import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../../../core/theme/theme_extension.dart';

/// 金额显示区域 — 奢华自然主义风格
class AmountInput extends StatelessWidget {
  final String amountText;
  final TransactionType type;
  final DateTime selectedDate;
  final VoidCallback onDateTap;

  const AmountInput({
    super.key,
    required this.amountText,
    required this.type,
    required this.selectedDate,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final color =
        type == TransactionType.expense ? appTheme.rose : appTheme.sage;
    final dateStr =
        '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appTheme.earthMedium.withAlpha(20),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 金额标签
          Text(
            type == TransactionType.expense ? '支出金额' : '收入金额',
            style: TextStyle(
              fontSize: 13,
              color: appTheme.earthMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // 金额显示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: color.withAlpha(180),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                amountText.isEmpty ? '0' : amountText,
                style: TextStyle(
                  fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 日期选择
          GestureDetector(
            onTap: onDateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: appTheme.creamDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: appTheme.earthMedium.withAlpha(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: appTheme.earthMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: appTheme.earthMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: appTheme.earthMedium.withAlpha(150),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

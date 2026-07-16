import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart';

/// 周期汇总卡片 — 展示总本金/总支出/余额/大额
class PeriodSummaryCard extends StatelessWidget {
  final PeriodCalculations calc;
  final PeriodRecord? period;
  final VoidCallback? onEditBalance;
  final VoidCallback? onTapTotalBase;
  final VoidCallback? onTapTotalExpense;
  final double? largeItemsNet;
  final VoidCallback? onEditLargeItems;

  const PeriodSummaryCard({
    super.key,
    required this.calc,
    this.period,
    this.onEditBalance,
    this.onTapTotalBase,
    this.onTapTotalExpense,
    this.largeItemsNet,
    this.onEditLargeItems,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final items = [
      _SummaryItem(
        label: '总本金',
        value: FormatUtils.formatAmount(calc.totalBase),
        color: appTheme.primary,
        isClickable: onTapTotalBase != null,
        onTap: onTapTotalBase,
      ),
      _SummaryItem(
        label: '总支出',
        value: '-${FormatUtils.formatAmount(calc.totalBase - (calc.balance ?? 0))}',
        color: appTheme.roseLight,
        isClickable: onTapTotalExpense != null,
        onTap: onTapTotalExpense,
      ),
      _SummaryItem(
        label: '余额',
        value: calc.balance != null
            ? FormatUtils.formatAmount(calc.balance!)
            : '¥0.00',
        color: appTheme.primaryDark,
        isBalance: true,
      ),
      if (largeItemsNet != null)
        _SummaryItem(
          label: '大额',
          value: _formatLargeItemsValue(largeItemsNet!),
          color: appTheme.earthMedium,
          isLargeItem: true,
          onEdit: onEditLargeItems,
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // 左侧竖线 + 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: appTheme.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '汇总',
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earthMedium,
                  ),
                ),
              ],
            ),
          ),
          // 数据行
          ...items.map((item) {
            final idx = items.indexOf(item);
            return Column(
              children: [
                if (idx > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 78),
                    child: Divider(
                      height: 1,
                      color: appTheme.earthMedium.withValues(alpha: 0.07),
                    ),
                  ),
                _buildItemRow(appTheme, item),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemRow(AppThemeExtension appTheme, _SummaryItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: appTheme.earth,
                  ),
                ),
                if (item.isBalance && onEditBalance != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onEditBalance,
                    child: Icon(
                      Icons.create_outlined,
                      size: 14,
                      color: appTheme.primaryDark.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                if (item.isLargeItem && onEditLargeItems != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onEditLargeItems,
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: appTheme.earthMedium.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.isClickable)
            GestureDetector(
              onTap: item.onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: item.value.startsWith('¥0') || item.value == '—'
                          ? appTheme.earthMedium.withValues(alpha: 0.5)
                          : item.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: item.color.withValues(alpha: 0.6),
                  ),
                ],
              ),
            )
          else
            Text(
              item.value,
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: item.value.startsWith('¥0') || item.value == '—'
                    ? appTheme.earthMedium.withValues(alpha: 0.5)
                    : appTheme.earth,
              ),
            ),
        ],
      ),
    );
  }
  String _formatLargeItemsValue(double net) {
    final abs = FormatUtils.formatAmount(net.abs());
    if (net > 0) return '+$abs';
    if (net < 0) return '-$abs';
    return '¥0.00';
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final Color color;
  final bool isClickable;
  final bool isBalance;
  final bool isLargeItem;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.isClickable = false,
    this.isBalance = false,
    this.isLargeItem = false,
    this.onTap,
    this.onEdit,
  });
}

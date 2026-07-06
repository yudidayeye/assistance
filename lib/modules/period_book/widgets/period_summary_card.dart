import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../services/period_book_service.dart';

/// 周期汇总卡片 — 展示总本金/购物/其他/余额/生活/生活日均
class PeriodSummaryCard extends StatelessWidget {
  final PeriodCalculations calc;
  final VoidCallback? onEditBalance;

  const PeriodSummaryCard({
    super.key,
    required this.calc,
    this.onEditBalance,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final items = [
      _SummaryItem(
        label: '总本金',
        value: FormatUtils.formatAmount(calc.totalBase),
        color: appTheme.primary,
      ),
      _SummaryItem(
        label: '购物',
        value: '-${FormatUtils.formatAmount(calc.shoppingTotal)}',
        color: appTheme.sage,
      ),
      _SummaryItem(
        label: '其他',
        value: '-${FormatUtils.formatAmount(calc.otherTotal)}',
        color: appTheme.roseLight,
      ),
      _SummaryItem(
        label: '余额',
        value: calc.balance != null
            ? FormatUtils.formatAmount(calc.balance!)
            : '—',
        color: appTheme.primaryDark,
        isEditable: true,
        onEdit: onEditBalance,
      ),
      _SummaryItem(
        label: '生活',
        value: calc.livingTotal != null
            ? '-${FormatUtils.formatAmount(calc.livingTotal!)}'
            : '—',
        color: appTheme.earthLight,
      ),
      _SummaryItem(
        label: '生活日均',
        value: calc.livingDailyAvg != null
            ? '-${FormatUtils.formatAmount(calc.livingDailyAvg!)}'
            : '—',
        color: appTheme.earthLight,
        subtitle: '${calc.totalDays}天',
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
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        child: Text(
                          item.subtitle != null
                              ? '${item.label}（${item.subtitle}）'
                              : item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: appTheme.earth,
                          ),
                        ),
                      ),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.value == '—'
                              ? appTheme.earthMedium.withValues(alpha: 0.5)
                              : appTheme.earth,
                        ),
                      ),
                      if (item.isEditable) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: item.onEdit,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: appTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: appTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final Color color;
  final bool isEditable;
  final VoidCallback? onEdit;
  final String? subtitle;

  _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.isEditable = false,
    this.onEdit,
    this.subtitle,
  });
}

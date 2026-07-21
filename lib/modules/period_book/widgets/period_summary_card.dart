import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart' show PeriodCalculations;

/// 周期汇总卡片 — 余额/本金一行式布局
///
/// 结构：余额/本金合并展示 + 进度条 + 支出/大额纯文本统计。
class PeriodSummaryCard extends StatelessWidget {
  final PeriodCalculations calc;
  final PeriodRecord? period;
  final VoidCallback? onTapTotalBase;
  final VoidCallback? onTapTotalExpense;
  final double? largeItemsNet;
  final VoidCallback? onEditLargeItems;

  const PeriodSummaryCard({
    super.key,
    required this.calc,
    this.period,
    this.onTapTotalBase,
    this.onTapTotalExpense,
    this.largeItemsNet,
    this.onEditLargeItems,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final balance = calc.balance;
    final spent = calc.totalBase - (balance ?? 0);
    final balanceRatio = calc.totalBase > 0
        ? ((balance ?? 0) / calc.totalBase).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: appTheme.cardBackground,
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                appTheme.primary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceSection(appTheme, balance),
              const SizedBox(height: 16),
              _buildProgressRow(appTheme, balanceRatio, spent),
            ],
          ),
        ),
      ),
    );
  }

  /// 余额/本金合并展示：¥1859.70 / 2500
  Widget _buildBalanceSection(AppThemeExtension appTheme, double? balance) {
    final balanceText = FormatUtils.formatAmount(balance ?? 0);
    final muted = balance == null || balance == 0;

    return GestureDetector(
      onTap: onTapTotalBase,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              balanceText,
              key: ValueKey(balanceText),
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: muted
                    ? appTheme.primary.withValues(alpha: 0.4)
                    : appTheme.primary,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: appTheme.earthMedium.withValues(alpha: 0.3),
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            FormatUtils.formatAmount(calc.totalBase),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.earthMedium.withValues(alpha: 0.5),
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// 余额进度条（余额/本金，入场与数据变化时带过渡动画）
  Widget _buildUsageBar(AppThemeExtension appTheme, double balanceRatio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: balanceRatio),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: appTheme.roseLight.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth * value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appTheme.primary.withValues(alpha: 0.55),
                          appTheme.primary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 进度条 + 支出/大额一行
  Widget _buildProgressRow(AppThemeExtension appTheme, double balanceRatio, double spent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUsageBar(appTheme, balanceRatio),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onEditLargeItems,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '大额 ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: appTheme.earthMedium.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    _formatLargeItemsValue(largeItemsNet ?? 0),
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: largeItemsNet != null
                          ? (largeItemsNet! >= 0 ? appTheme.sage : appTheme.rose)
                          : appTheme.earthMedium.withValues(alpha: 0.4),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (onEditLargeItems != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: appTheme.earthMedium.withValues(alpha: 0.4),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTapTotalExpense,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    size: 14,
                    color: appTheme.rose.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '支出 -${FormatUtils.formatAmount(spent)}',
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: spent > 0 ? appTheme.rose : appTheme.earthMedium.withValues(alpha: 0.4),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLargeItemsValue(double net) {
    final abs = FormatUtils.formatAmount(net.abs());
    if (net > 0) return '+$abs';
    if (net < 0) return '-$abs';
    return '¥0.00';
  }
}

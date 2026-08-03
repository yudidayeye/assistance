import '../../../shared/foundation/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart' show PeriodCalculations;

/// 周期汇总卡片 — 余额/本金一行式布局
///
/// 结构：余额/本金合并展示 + 右上角支出占比环形图（个人/其他/杂项）
/// + 进度条 + 支出/大额纯文本统计。
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

    // 支出构成：个人 / 其他 / 杂项（杂项为倒推值，未填余额时未知）
    final shopping = calc.shoppingTotal > 0 ? calc.shoppingTotal : 0.0;
    final other = calc.otherTotal > 0 ? calc.otherTotal : 0.0;
    final living = (calc.livingTotal != null && calc.livingTotal! > 0)
        ? calc.livingTotal!
        : 0.0;
    final expenseTotal = shopping + other + living;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: appTheme.primaryLight.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        boxShadow: appTheme.cardShadow,
        border: Border.all(
          color: appTheme.primaryLight.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceSection(appTheme, balance),
                      AppSpacing.h10,
                      _buildExpenseLegend(
                          appTheme, shopping, other, living, expenseTotal),
                    ],
                  ),
                ),
                AppSpacing.w16,
                _buildExpenseDonut(
                    appTheme, shopping, other, living, expenseTotal),
              ],
            ),
            AppSpacing.h14,
            _buildProgressRow(appTheme, balanceRatio, spent),
          ],
        ),
      ),
    );
  }

  /// 余额/本金合并展示：¥1284.09 / ¥2500
  Widget _buildBalanceSection(AppThemeExtension appTheme, double? balance) {
    final balanceText = FormatUtils.formatAmount(balance ?? 0);
    final muted = balance == null || balance == 0;

    return GestureDetector(
      onTap: onTapTotalBase,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                balanceText,
                key: ValueKey(balanceText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: muted
                      ? appTheme.primary.withValues(alpha: 0.4)
                      : appTheme.primary,
                  letterSpacing: -0.5,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          AppSpacing.w6,
          Text(
            '/',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.earthMedium.withValues(alpha: 0.9),
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          AppSpacing.w6,
          Text(
            FormatUtils.formatAmount(calc.totalBase),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: appTheme.earthMedium.withValues(alpha: 0.9),
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// 右上角支出占比环形图 — 个人（sage）/ 其他（rose）/ 结余（primary）
  ///
  /// 入场带轻微缩放渐显，数据变化时扇区平滑过渡。
  Widget _buildExpenseDonut(
    AppThemeExtension appTheme,
    double shopping,
    double other,
    double living,
    double total,
  ) {
    final chart = SizedBox(
      width: 68,
      height: 68,
      child: total <= 0
          ? // 空态：与环形等宽的灰色轨道圈
          Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: appTheme.roseLight.withValues(alpha: 0.35),
                  width: 8,
                ),
              ),
            )
          : PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: shopping > 0 ? shopping : 0.001,
                    color: appTheme.sage,
                    radius: 8,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: other > 0 ? other : 0.001,
                    color: appTheme.rose,
                    radius: 8,
                    showTitle: false,
                  ),
                  if (living > 0)
                    PieChartSectionData(
                      value: living,
                      color: appTheme.primary.withValues(alpha: 0.6),
                      radius: 8,
                      showTitle: false,
                    ),
                ],
                centerSpaceRadius: 22,
                sectionsSpace: 1.5,
                startDegreeOffset: -90,
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: value, child: child),
      ),
      child: chart,
    );
  }

  /// 支出构成图例行：●个人 72%  ●其他 12%  ●杂项 15%
  Widget _buildExpenseLegend(
    AppThemeExtension appTheme,
    double shopping,
    double other,
    double living,
    double total,
  ) {
    if (total <= 0) {
      return Text(
        '暂无支出构成',
        style: TextStyle(
          fontSize: 11,
          color: appTheme.earthMedium.withValues(alpha: 0.9),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _legendItem(appTheme, '个人', appTheme.sage, shopping / total),
        _legendItem(appTheme, '其他', appTheme.rose, other / total),
        if (living > 0)
          _legendItem(appTheme, '杂项',
              appTheme.primary.withValues(alpha: 0.6), living / total),
      ],
    );
  }

  Widget _legendItem(
      AppThemeExtension appTheme, String label, Color color, double pct,
      {Widget? marker}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker ??
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: appTheme.earthMedium.withValues(alpha: 0.9),
          ),
        ),
        AppSpacing.w4,
        Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: appTheme.earth,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 余额进度条（余额/本金，入场与数据变化时带过渡动画）
  Widget _buildUsageBar(AppThemeExtension appTheme, double balanceRatio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: balanceRatio),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: appTheme.roseLight.withValues(alpha: 0.3),
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
  Widget _buildProgressRow(
      AppThemeExtension appTheme, double balanceRatio, double spent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUsageBar(appTheme, balanceRatio),
        AppSpacing.h10,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onEditLargeItems,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.diamond_outlined,
                      size: 14,
                      color: appTheme.earthMedium.withValues(alpha: 0.75),
                    ),
                    AppSpacing.w4,
                    Text(
                      '大额',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthMedium.withValues(alpha: 0.9),
                      ),
                    ),
                    AppSpacing.w6,
                    Flexible(
                      child: Text(
                        _formatLargeItemsValue(largeItemsNet ?? 0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: largeItemsNet != null
                              ? (largeItemsNet! >= 0
                                  ? appTheme.sage
                                  : appTheme.rose)
                              : appTheme.earthMedium.withValues(alpha: 0.9),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (onEditLargeItems != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: appTheme.earthMedium.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: GestureDetector(
                onTap: onTapTotalExpense,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_down_rounded,
                      size: 14,
                      color: appTheme.rose.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '支出',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: appTheme.rose,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '-${FormatUtils.formatAmount(spent)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: spent > 0
                              ? appTheme.rose
                              : appTheme.earthMedium.withValues(alpha: 0.9),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (onTapTotalExpense != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: appTheme.earthMedium.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
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

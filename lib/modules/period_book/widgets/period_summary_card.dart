import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart' show PeriodCalculations;

/// 周期汇总卡片 — 余额焦点式紧凑布局
///
/// 结构：余额主指标 + 本金次指标 + 已用进度条 + 支出/大额快捷统计。
/// 每项数据只出现一次，无重复标题；所有交互入口保留。
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
    final balance = calc.balance;
    final spent = calc.totalBase - (balance ?? 0);
    final usedRatio = calc.totalBase > 0
        ? (spent / calc.totalBase).clamp(0.0, 1.0)
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
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
              _buildHeroRow(appTheme, balance),
              const SizedBox(height: 12),
              _buildUsageBar(appTheme, usedRatio),
              const SizedBox(height: 5),
              Text(
                '已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: appTheme.earthMedium.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow(appTheme, spent),
            ],
          ),
        ),
      ),
    );
  }

  /// 主排行：余额（焦点大数字）+ 本金（右侧次指标）
  Widget _buildHeroRow(AppThemeExtension appTheme, double? balance) {
    final balanceText = FormatUtils.formatAmount(balance ?? 0);
    final muted = balance == null || balance == 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 余额 — 焦点指标
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '余额',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: appTheme.earthMedium,
                    ),
                  ),
                  if (onEditBalance != null)
                    GestureDetector(
                      onTap: onEditBalance,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.create_outlined,
                          size: 13,
                          color: appTheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  balanceText,
                  key: ValueKey(balanceText),
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: muted
                        ? appTheme.earthMedium.withValues(alpha: 0.5)
                        : appTheme.earth,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        // 本金 — 次指标
        _buildSecondaryStat(
          appTheme: appTheme,
          label: '本金',
          value: FormatUtils.formatAmount(calc.totalBase),
          color: appTheme.primary,
          muted: calc.totalBase == 0,
          onTap: onTapTotalBase,
        ),
      ],
    );
  }

  /// 右上角次指标块（标签 + 数值 + 箭头）
  Widget _buildSecondaryStat({
    required AppThemeExtension appTheme,
    required String label,
    required String value,
    required Color color,
    required bool muted,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: appTheme.earthMedium),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: muted
                        ? appTheme.earthMedium.withValues(alpha: 0.5)
                        : color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }

  /// 已用本金进度条（入场与数据变化时带过渡动画）
  Widget _buildUsageBar(AppThemeExtension appTheme, double ratio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: appTheme.earthMedium.withValues(alpha: 0.12),
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
                          appTheme.rose.withValues(alpha: 0.65),
                          appTheme.rose,
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

  /// 底部快捷统计：支出（必有）+ 大额（有数据时显示）
  Widget _buildStatRow(AppThemeExtension appTheme, double spent) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            appTheme: appTheme,
            label: '支出',
            value: '-${FormatUtils.formatAmount(spent)}',
            color: appTheme.rose,
            muted: spent == 0,
            onTap: onTapTotalExpense,
          ),
        ),
        if (largeItemsNet != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              appTheme: appTheme,
              label: '大额',
              value: _formatLargeItemsValue(largeItemsNet!),
              color: largeItemsNet! >= 0 ? appTheme.sage : appTheme.rose,
              muted: largeItemsNet == 0,
              onTap: onEditLargeItems,
            ),
          ),
        ],
      ],
    );
  }

  /// 单个统计 chip：淡色底 + 标签 + 数值 + 箭头，带水波纹按压反馈
  Widget _buildStatChip({
    required AppThemeExtension appTheme,
    required String label,
    required String value,
    required Color color,
    required bool muted,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: muted ? 0.05 : 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: appTheme.earthMedium),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: muted
                        ? appTheme.earthMedium.withValues(alpha: 0.5)
                        : color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
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

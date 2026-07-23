import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart' show PeriodCalculations;

/// 周期汇总卡片 — 严格按设计稿配色
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

  // 设计稿颜色
  static const Color _blue = Color(0xFF5B8FF9);
  static const Color _grayText = Color(0xFF999999);
  static const Color _labelGray = Color(0xFF666666);
  static const Color _lightGrayBg = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    final balance = calc.balance ?? 0;
    final totalBase = calc.totalBase;
    final spent = totalBase - balance;
    final largeNet = largeItemsNet ?? 0;
    final percent = totalBase > 0
        ? (balance / totalBase).clamp(0.0, 1.0)
        : 0.0;
    final percentText = '${(percent * 100).round()}%';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "剩余金额" 标签
            Text(
              '剩余金额',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _labelGray,
              ),
            ),
            const SizedBox(height: 8),
            // 余额大数字行：¥1734.03 / ¥2500   69%
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTapTotalBase,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            FormatUtils.formatAmount(balance),
                            key: ValueKey(balance),
                            style: TextStyle(
                              fontFamily: GoogleFonts.dmSans().fontFamily,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: _blue,
                              letterSpacing: -0.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '/ ${FormatUtils.formatAmount(totalBase)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _grayText,
                            fontFamily: GoogleFonts.dmSans().fontFamily,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  percentText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _blue.withValues(alpha: 0.8),
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 进度条
            _buildUsageBar(percent),
            const SizedBox(height: 20),
            // 大额 / 支出 双卡
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    label: '大额',
                    value: largeNet,
                    isPositive: true,
                    onTap: onEditLargeItems,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    label: '支出',
                    value: spent,
                    isPositive: false,
                    onTap: onTapTotalExpense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 余额进度条
  Widget _buildUsageBar(double ratio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFFEEEEEE),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth * value,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF5B8FF9),
                          Color(0xFF4A80E8),
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

  /// 大额 / 支出 信息卡
  Widget _buildInfoCard({
    required String label,
    required double value,
    required bool isPositive,
    VoidCallback? onTap,
  }) {
    final displayValue = value.abs();
    final prefix = isPositive ? '' : '-';
    final textColor = _blue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: _lightGrayBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _labelGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$prefix${FormatUtils.formatAmount(displayValue)}',
                    style: TextStyle(
                      fontFamily: GoogleFonts.dmSans().fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}

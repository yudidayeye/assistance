import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/utils/format_utils.dart';

/// 月度支出趋势折线图 — 按月统计总支出
class MonthlyExpenseChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MonthlyExpenseChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusXl),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                AppSpacing.w8,
                Text(
                  '月度支出趋势',
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
          if (data.isEmpty || data.every((d) => d['expense'] == 0))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '暂无支出数据',
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earthMedium.withValues(alpha: 0.4),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              child: AspectRatio(
                aspectRatio: 2.2,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getHorizontalInterval(),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: appTheme.earthMedium.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length) {
                              return const SizedBox.shrink();
                            }
                            final month = data[idx]['month'] as int;
                            // 显示格式：7月
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '$month月',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: appTheme.earthMedium
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final item = data[spot.x.toInt()];
                            return LineTooltipItem(
                              '${item['month']}月\n¥${FormatUtils.formatAmount((item['expense'] as num).toDouble())}',
                              TextStyle(
                                fontSize: 12,
                                color: appTheme.earth,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _buildSpots(),
                        isCurved: true,
                        color: appTheme.primary,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: appTheme.primary,
                              strokeWidth: 1.5,
                              strokeColor: appTheme.cardBackground,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: appTheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AppSpacing.h8,
        ],
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final expense = data[i]['expense'] as num;
      spots.add(FlSpot(i.toDouble(), expense.toDouble()));
    }
    return spots;
  }

  double _getHorizontalInterval() {
    if (data.isEmpty) return 1000;
    final maxExpense = data
        .map((d) => (d['expense'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxExpense <= 0) return 1000;
    // 根据最大值计算合适的间隔
    if (maxExpense <= 1000) return 200;
    if (maxExpense <= 5000) return 1000;
    if (maxExpense <= 10000) return 2000;
    return 5000;
  }
}

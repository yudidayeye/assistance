import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';

/// 余额趋势折线图 — 跨周期余额变化
class BalanceTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const BalanceTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

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
                const SizedBox(width: 8),
                Text(
                  '余额趋势',
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
          if (data.isEmpty || data.every((d) => d['balance'] == null))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '暂无余额数据',
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
                    gridData: const FlGridData(show: false),
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
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= data.length) {
                              return const SizedBox.shrink();
                            }
                            final dt = DateTime.parse(data[idx]['startDate']);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${dt.month}/${dt.day}',
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
                              '${item['startDate'].substring(5)}\n¥${(item['balance'] as num).toStringAsFixed(2)}',
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
                        color: appTheme.earth,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: appTheme.earth.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    final spots = <FlSpot>[];
    int idx = 0;
    for (final item in data) {
      final balance = item['balance'];
      if (balance != null) {
        spots.add(FlSpot(idx.toDouble(), (balance as num).toDouble()));
      }
      idx++;
    }
    return spots;
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/stats_service.dart';
import '../../../core/theme/theme_extension.dart';

/// 月度统计饼图 — 奢华自然主义风格
class ExpensePieChart extends StatelessWidget {
  final List<CategoryStats> stats;

  const ExpensePieChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    if (stats.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: appTheme.earthMedium,
            fontSize: 14,
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: stats.asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            final cat = stat.category;
            final color = _getCategoryColor(appTheme, index);

            return PieChartSectionData(
              value: stat.total,
              title: '${(stat.percent * 100).toStringAsFixed(0)}%',
              color: color,
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              titlePositionPercentageOffset: 0.6,
            );
          }).toList(),
          sectionsSpace: 3,
          centerSpaceRadius: 45,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Color _getCategoryColor(AppThemeExtension appTheme, int index) {
    final colors = [
      appTheme.rose,
      appTheme.gold,
      appTheme.sage,
      appTheme.earthMedium,
      appTheme.roseLight,
      appTheme.goldDark,
      appTheme.sageLight,
      appTheme.earthLight,
      appTheme.goldLight,
      appTheme.rose.withAlpha(180),
    ];
    return colors[index % colors.length];
  }
}

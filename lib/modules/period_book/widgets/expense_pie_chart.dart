import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';

/// 支出占比饼图 — 购物 / 其他 / 生活
class ExpensePieChart extends StatelessWidget {
  final Map<String, double> data;

  const ExpensePieChart({super.key, required this.data});

  double get _total => data.values.fold(0.0, (sum, v) => sum + v);

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    final hasData = _total > 0;
    final shoppingPct = hasData ? data['shopping']! / _total : 0.0;
    final otherPct = hasData ? data['other']! / _total : 0.0;
    final livingPct = hasData ? data['living']! / _total : 0.0;

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
                  '支出占比',
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
          if (!hasData)
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 饼图
                  Expanded(
                    flex: 2,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            _buildSection(
                              value: data['shopping']!,
                              color: appTheme.sage,
                              title: '购物',
                              pct: shoppingPct,
                            ),
                            _buildSection(
                              value: data['other']!,
                              color: appTheme.rose,
                              title: '其他',
                              pct: otherPct,
                            ),
                            if (data['living']! > 0)
                              _buildSection(
                                value: data['living']!,
                                color: appTheme.primary.withValues(alpha: 0.6),
                                title: '生活',
                                pct: livingPct,
                              ),
                          ],
                          centerSpaceRadius: 32,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                        ),
                      ),
                    ),
                  ),
                  // 图例
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegend(appTheme, '购物', appTheme.sage,
                            data['shopping']!, shoppingPct),
                        const SizedBox(height: 12),
                        _buildLegend(appTheme, '其他', appTheme.rose,
                            data['other']!, otherPct),
                        const SizedBox(height: 12),
                        if (data['living']! > 0)
                          _buildLegend(
                              appTheme,
                              '生活',
                              appTheme.primary.withValues(alpha: 0.6),
                              data['living']!,
                              livingPct),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  PieChartSectionData _buildSection({
    required double value,
    required Color color,
    required String title,
    required double pct,
  }) {
    final showTitle = pct > 0.1;
    return PieChartSectionData(
      value: value > 0 ? value : 0.001,
      color: color,
      radius: showTitle ? 52 : 28,
      badgeWidget: showTitle
          ? Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      badgePositionPercentageOffset: 0.5,
      title: '',
    );
  }

  Widget _buildLegend(
    AppThemeExtension appTheme,
    String label,
    Color color,
    double value,
    double pct,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: appTheme.earth,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
              ),
            ),
            Text(
              '¥${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}',
              style: TextStyle(
                fontSize: 11,
                color: appTheme.earthMedium.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/ai_model.dart';
import 'ai_dashboard_typography.dart';

class AiDashboardSummary extends StatelessWidget {
  final List<AiModel> models;
  final AiCostMetric metric;
  final String date;

  const AiDashboardSummary(
      {super.key,
      required this.models,
      required this.metric,
      required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    final scores = models.map((m) => m.intelligence).toList()..sort();
    final costs = models.map((m) => m.cost(metric)).whereType<double>().toList()
      ..sort();
    String price(double value) => value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value < 0.01 ? 4 : 2);
    final entries = [
      (
        Icons.hexagon_outlined,
        const Color(0xFF147AFF),
        '收录模型',
        '${models.length}',
      ),
      (
        Icons.bar_chart_rounded,
        const Color(0xFF087F80),
        '智能指数范围',
        scores.isEmpty
            ? '—'
            : '${scores.first.toStringAsFixed(1)} – ${scores.last.toStringAsFixed(1)}',
      ),
      (
        Icons.currency_yen_rounded,
        const Color(0xFFF0642D),
        '${metric.label}范围',
        costs.isEmpty
            ? '未公布'
            : '\$${price(costs.first)} – \$${price(costs.last)}',
      ),
      (Icons.schedule_rounded, const Color(0xFF8246FF), '最近更新', date),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      final valueStyle = AiDashboardTypography.strong
          .copyWith(fontSize: 14, height: 1.3, color: theme.earth);
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final entry in entries)
          Container(
            width: width,
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  entry.$2.withValues(alpha: 0.045), theme.cardBackground),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: entry.$2.withValues(alpha: 0.10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(entry.$1, color: entry.$2, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(entry.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AiDashboardTypography.strong
                              .copyWith(fontSize: 12, color: theme.earthLight)),
                      const SizedBox(height: 4),
                      Tooltip(
                          message: entry.$4,
                          child: Text(entry.$4,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: valueStyle)),
                    ])),
              ],
            ),
          ),
      ]);
    });
  }
}

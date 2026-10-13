import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/ai_model.dart';

Color creatorColor(String creator) {
  final hash =
      creator.codeUnits.fold<int>(0, (sum, unit) => (sum * 31 + unit) & 0xffff);
  return HSLColor.fromAHSL(1, hash % 360.0, 0.6, 0.43).toColor();
}

/// 成本用对数轴；点击圆点查看模型，点击位置在当前绘制坐标系内匹配。
class AiRelationChart extends StatelessWidget {
  final List<AiModel> models;
  final AiCostMetric metric;
  final String? selectedSlug;
  final double height;
  final ValueChanged<AiModel> onSelected;
  const AiRelationChart(
      {super.key,
      required this.models,
      required this.metric,
      required this.onSelected,
      this.selectedSlug,
      this.height = 300});

  @override
  Widget build(BuildContext context) {
    final plotted = models.where((m) => (m.cost(metric) ?? 0) > 0).toList();
    if (plotted.isEmpty) {
      return const SizedBox(
          height: 180, child: Center(child: Text('暂无可绘制的成本数据，请切换价格口径')));
    }
    final theme = Theme.of(context).appTheme;
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, height);
      final geometry = ChartGeometry(plotted, metric, size);
      return Semantics(
        label: '模型能力与成本关系图，越靠左上越好。可点击圆点查看模型。',
        child: GestureDetector(
          onTapUp: (event) {
            AiModel? nearest;
            var distance = 24.0;
            for (final m in plotted) {
              final d = (geometry.point(m) - event.localPosition).distance;
              if (d < distance) {
                nearest = m;
                distance = d;
              }
            }
            if (nearest != null) onSelected(nearest);
          },
          child: CustomPaint(
              size: size,
              painter: _RelationPainter(
                  geometry,
                  plotted,
                  metric,
                  selectedSlug,
                  theme.earth,
                  theme.earthMedium,
                  theme.primary,
                  theme.cardBackground,
                  theme.sageLight,
                  paretoFrontier(models, metric)
                      .where((m) => (m.cost(metric) ?? 0) > 0)
                      .toList())),
        ),
      );
    });
  }
}

class ChartGeometry {
  final AiCostMetric metric;
  final Rect plot;
  late final double minX;
  late final double maxX;
  late final double maxY;
  ChartGeometry(List<AiModel> models, this.metric, Size size)
      : plot = Rect.fromLTRB(
            42, 24, math.max(43, size.width - 12), size.height - 40) {
    final costs = models.map((m) => logCost(m.cost(metric)!));
    minX = costs.reduce(math.min).floorToDouble();
    maxX = math.max(minX + 1, costs.reduce(math.max).ceilToDouble());
    maxY = math
        .max(
            10,
            (models.map((m) => m.intelligence).reduce(math.max) / 10).ceil() *
                10)
        .toDouble();
  }
  Offset point(AiModel model) => Offset(
      plot.left +
          (logCost(model.cost(metric)!) - minX) / (maxX - minX) * plot.width,
      plot.bottom - model.intelligence / maxY * plot.height);
}

class _RelationPainter extends CustomPainter {
  final ChartGeometry geometry;
  final List<AiModel> models;
  final AiCostMetric metric;
  final List<AiModel> frontier;
  final String? selected;
  final Color textColor, gridColor, primary, background, favorable;
  _RelationPainter(
      this.geometry,
      this.models,
      this.metric,
      this.selected,
      this.textColor,
      this.gridColor,
      this.primary,
      this.background,
      this.favorable,
      this.frontier);

  void text(Canvas canvas, String value, Offset point, {double size = 10}) {
    final painter = TextPainter(
        text: TextSpan(
            text: value, style: TextStyle(fontSize: size, color: textColor)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, point);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final costs = models.map((m) => m.cost(metric)!).toList()..sort();
    final scores = models.map((m) => m.intelligence).toList()..sort();
    final middleCost = costs[costs.length ~/ 2];
    final middleScore = scores[scores.length ~/ 2];
    final boundaryX = plot.left +
        (logCost(middleCost) - geometry.minX) /
            (geometry.maxX - geometry.minX) *
            plot.width;
    final boundaryY = plot.bottom - middleScore / geometry.maxY * plot.height;
    canvas.drawRect(Rect.fromLTRB(plot.left, plot.top, boundaryX, boundaryY),
        Paint()..color = favorable.withValues(alpha: 0.5));
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.16)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      text(
          canvas, (geometry.maxY * i / 4).toStringAsFixed(0), Offset(8, y - 6));
    }
    final span = (geometry.maxX - geometry.minX).toInt();
    final step = math.max(1, (span / 4).ceil());
    for (var i = 0; i <= span; i += step) {
      final exponent = geometry.minX + i;
      final x = plot.left + i / span * plot.width;
      final cost = math.pow(10, exponent).toDouble();
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      text(
          canvas,
          '\$${cost < 1 ? cost.toStringAsFixed(math.min(6, -exponent.toInt())) : cost.toStringAsFixed(0)}',
          Offset(x - 12, plot.bottom + 8));
    }
    text(canvas, '智能指数 ↑', const Offset(4, 2));
    text(canvas, '成本（对数轴）→',
        Offset(math.max(0, size.width - 112), size.height - 14));
    final line = Paint()
      ..color = primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < frontier.length; i++) {
      final start = geometry.point(frontier[i - 1]);
      final finish = geometry.point(frontier[i]);
      final delta = finish - start;
      final length = delta.distance;
      if (length == 0) continue;
      for (var d = 0.0; d < length; d += 6) {
        canvas.drawLine(start + delta * (d / length),
            start + delta * (math.min(d + 2, length) / length), line);
      }
    }
    final labels = <Rect>[];
    final frontierSlugs = frontier.map((m) => m.slug).toSet();
    for (final m in models) {
      final point = geometry.point(m);
      final isSelected = m.slug == selected;
      if (isSelected) {
        canvas.drawCircle(
            point, 8, Paint()..color = primary.withValues(alpha: 0.18));
      }
      canvas.drawCircle(point, isSelected ? 5 : 3.5,
          Paint()..color = creatorColor(m.creator));
      if (isSelected || models.length <= 35 || frontierSlugs.contains(m.slug)) {
        final label = TextPainter(
            text: TextSpan(
                text: m.name, style: TextStyle(fontSize: 11, color: textColor)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…')
          ..layout(maxWidth: math.min(180, plot.width));
        final left = (point.dx - label.width / 2)
            .clamp(plot.left, plot.right - label.width)
            .toDouble();
        final top = math.max(plot.top, point.dy - 22).toDouble();
        final bounds =
            Rect.fromLTWH(left - 3, top - 2, label.width + 6, label.height + 4);
        if (!isSelected && labels.any((old) => old.overlaps(bounds))) continue;
        labels.add(bounds);
        canvas.drawRect(
            bounds, Paint()..color = background.withValues(alpha: 0.85));
        label.paint(canvas, Offset(left, top));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RelationPainter old) => true;
}

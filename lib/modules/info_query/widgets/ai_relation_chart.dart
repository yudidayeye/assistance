import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../models/ai_model.dart';

Map<String, Color> creatorColors(Iterable<String> creators) {
  const brands = {
    'anthropic': Color(0xFFFFB400),
    'openai': Color(0xFF0784FF),
    'google': Color(0xFF8645E8),
    'meta': Color(0xFFD50A77),
    'xai': Color(0xFFF4264C),
    'spacexai': Color(0xFFF4264C),
    'xiaomi': Color(0xFFFF303B),
    'alibaba': Color(0xFF29BA85),
    'z ai': Color(0xFF18AA78),
    'z.ai': Color(0xFF18AA78),
    'stepfun': Color(0xFF91CE40),
    'kimi': Color(0xFF103FA5),
    'deepseek': Color(0xFF416BE3),
  };
  const palette = [
    Color(0xFF0072B2),
    Color(0xFFD55E00),
    Color(0xFF009E73),
    Color(0xFFCC79A7),
    Color(0xFF6F42C1),
    Color(0xFF9A7600),
    Color(0xFF008B9A),
    Color(0xFFC62828),
    Color(0xFF546E7A),
    Color(0xFF6B7B00)
  ];
  final names = creators.toSet().toList()..sort();
  return {
    for (var i = 0; i < names.length; i++)
      names[i]: brands[names[i].toLowerCase()] ??
          (i < palette.length
              ? palette[i]
              : HSLColor.fromAHSL(
                      1, (i * 137.508) % 360, 0.72, i.isEven ? 0.34 : 0.52)
                  .toColor())
  };
}

/// 成本用对数轴；点击圆点查看模型，点击位置在当前绘制坐标系内匹配。
class AiRelationChart extends StatelessWidget {
  final List<AiModel> models;
  final AiCostMetric metric;
  final String? selectedSlug;
  final double height;
  final double minimumScore;
  final Map<String, Color>? colors;
  final ValueChanged<AiModel> onSelected;

  /// 放大图使用带引导线和自适应字号的详细标注，首页小图保持简洁。
  final bool detailedLabels;
  const AiRelationChart(
      {super.key,
      required this.models,
      required this.metric,
      required this.onSelected,
      this.selectedSlug,
      this.minimumScore = 0,
      this.colors,
      this.detailedLabels = false,
      this.height = 300});

  @override
  Widget build(BuildContext context) {
    final plotted = models.where((m) => (m.cost(metric) ?? 0) > 0).toList();
    if (plotted.isEmpty) {
      return SizedBox(
          height: 180,
          child: Center(
              child: Text(models.isEmpty
                  ? '没有符合当前智能指数或搜索条件的模型'
                  : '当前模型未公布此项成本，请切换价格口径或查看原始榜单')));
    }
    final theme = Theme.of(context).appTheme;
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, height);
      final geometry =
          ChartGeometry(plotted, metric, size, minimumScore: minimumScore);
      return Semantics(
        label: '模型能力与成本关系图，越靠左上越好。虚线为优势前沿，绿色矩形为低成本、高能力区域。可点击圆点查看模型。',
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
                    theme.cardBackground,
                    theme.primary,
                    theme.sageLight,
                    paretoFrontier(models, metric)
                        .where((model) => (model.cost(metric) ?? 0) > 0)
                        .toList(),
                    colors ?? creatorColors(models.map((m) => m.creator)),
                    detailedLabels))),
      );
    });
  }
}

class ChartGeometry {
  final AiCostMetric metric;
  final Rect plot;
  late final double minX, maxX, maxY;
  final double minY;
  ChartGeometry(List<AiModel> models, this.metric, Size size,
      {double minimumScore = 0})
      : minY = minimumScore,
        plot = Rect.fromLTRB(
            36, 16, math.max(37, size.width - 14), size.height - 30) {
    final costs = models.map((m) => logCost(m.cost(metric)!));
    minX = costs.reduce(math.min);
    maxX = math.max(minX + 1, costs.reduce(math.max).ceilToDouble());
    maxY = math
        .max(minY + 1,
            (models.map((m) => m.intelligence).reduce(math.max) / 5).ceil() * 5)
        .toDouble();
  }
  Offset point(AiModel model) => Offset(
      plot.left +
          (logCost(model.cost(metric)!) - minX) / (maxX - minX) * plot.width,
      scoreY(model.intelligence));
  double scoreY(double score) =>
      plot.bottom - (score - minY) / (maxY - minY) * plot.height;
}

/// 单个标签的排版结果：逐行文本、整体宽高与行高。
class _LabelText {
  final List<TextPainter> painters;
  final double width;
  final double height;
  final double lineHeight;
  const _LabelText(this.painters, this.width, this.height, this.lineHeight);
}

class _RelationPainter extends CustomPainter {
  final ChartGeometry geometry;
  final List<AiModel> models;
  final AiCostMetric metric;
  final String? selected;
  final Color textColor, gridColor, background, primary, favorable;
  final List<AiModel> frontier;
  final Map<String, Color> colors;
  final bool detailedLabels;
  _RelationPainter(
      this.geometry,
      this.models,
      this.metric,
      this.selected,
      this.textColor,
      this.gridColor,
      this.background,
      this.primary,
      this.favorable,
      this.frontier,
      this.colors,
      this.detailedLabels);

  TextPainter _text(String value,
          {double size = 11, double maxWidth = double.infinity}) =>
      TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(fontSize: size, color: textColor, height: 1.3)),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…')
        ..layout(maxWidth: maxWidth);

  /// 按给定字号测量单行文本，供标签的均衡换行使用。
  TextPainter _measure(String value, double size,
          {double maxWidth = double.infinity}) =>
      TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(fontSize: size, color: textColor, height: 1.3)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…')
        ..layout(maxWidth: maxWidth);

  /// 名字与分数连成一段，排成最多两行，并让两行宽度尽量接近：
  /// 既不会出现第三行，也不会出现第一行没占满就换行的情况。
  _LabelText _layoutLabel(String value, double fontSize, double maxWidth) {
    final words = value.split(' ').where((word) => word.isNotEmpty).toList();
    var lines = <String>[value];
    if (words.length > 1 && _measure(value, fontSize).width > maxWidth) {
      var bestSplit = -1;
      var bestScore = double.infinity;
      var bestFits = false;
      for (var i = 1; i < words.length; i++) {
        final first = words.sublist(0, i).join(' ');
        final second = words.sublist(i).join(' ');
        final firstWidth = _measure(first, fontSize).width;
        final secondWidth = _measure(second, fontSize).width;
        final fits = firstWidth <= maxWidth && secondWidth <= maxWidth;
        final score = math.max(firstWidth, secondWidth);
        // 优先选两行都不超宽且更均衡的切分点，否则退让到最不拥挤的方案。
        if (fits) {
          if (!bestFits || score < bestScore) {
            bestFits = true;
            bestScore = score;
            bestSplit = i;
          }
        } else if (!bestFits && score < bestScore) {
          bestScore = score;
          bestSplit = i;
        }
      }
      if (bestSplit > 0) {
        lines = [
          words.sublist(0, bestSplit).join(' '),
          words.sublist(bestSplit).join(' '),
        ];
      }
    }
    final painters = [
      for (final line in lines) _measure(line, fontSize, maxWidth: maxWidth),
    ];
    final lineHeight = painters.first.height;
    final width =
        painters.map((painter) => painter.width).reduce(math.max) + 12;
    final height = lineHeight * painters.length + 8;
    return _LabelText(painters, width, height, lineHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final costs = models.map((model) => model.cost(metric)!).toList()..sort();
    final scores = models.map((model) => model.intelligence).toList()..sort();
    final boundaryX = plot.left +
        (logCost(costs[costs.length ~/ 2]) - geometry.minX) /
            (geometry.maxX - geometry.minX) *
            plot.width;
    final boundaryY = geometry.scoreY(scores[scores.length ~/ 2]);
    canvas.drawRect(Rect.fromLTRB(plot.left, plot.top, boundaryX, boundaryY),
        Paint()..color = favorable.withValues(alpha: 0.5));
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;
    final axis = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      canvas.drawLine(Offset(plot.left - 4, y), Offset(plot.left, y), axis);
      final score = geometry.minY + (geometry.maxY - geometry.minY) * i / 4;
      final label =
          _text(score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1));
      label.paint(
          canvas, Offset(plot.left - label.width - 10, y - label.height / 2));
    }
    final span = geometry.maxX - geometry.minX;
    final step = math.max(1, (span / 4).ceil());
    final ticks = <double>[
      geometry.minX,
      for (var exponent = geometry.minX.floor() + 1;
          exponent <= geometry.maxX;
          exponent += step)
        exponent.toDouble(),
    ];
    var previousLabelRight = double.negativeInfinity;
    for (final exponent in ticks) {
      final x = plot.left + (exponent - geometry.minX) / span * plot.width;
      final cost = math.pow(10, exponent).toDouble();
      final value = cost < 0.000001
          ? cost.toStringAsExponential(2)
          : cost.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
      final label = _text('\$$value');
      final labelLeft =
          (x - label.width / 2).clamp(0.0, size.width - label.width);
      // 起点始终标注实际最低价格，过近的后续刻度略去以免重叠。
      if (labelLeft < previousLabelRight + 8) continue;
      previousLabelRight = labelLeft + label.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 5), axis);
      label.paint(canvas, Offset(labelLeft, plot.bottom + 9));
    }
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axis);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    final line = Paint()
      ..color = primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (var i = 1; i < frontier.length; i++) {
      final start = geometry.point(frontier[i - 1]);
      final finish = geometry.point(frontier[i]);
      final delta = finish - start;
      final length = delta.distance;
      if (length == 0) continue;
      for (var distance = 0.0; distance < length; distance += 6) {
        canvas.drawLine(start + delta * (distance / length),
            start + delta * (math.min(distance + 2, length) / length), line);
      }
    }
    for (final m in models) {
      final point = geometry.point(m);
      if (m.slug == selected) {
        canvas.drawCircle(point, 8,
            Paint()..color = colors[m.creator]!.withValues(alpha: 0.18));
      }
      canvas.drawCircle(point, m.slug == selected ? 5 : 3.5,
          Paint()..color = colors[m.creator]!);
    }
    // 放大图标注全部前沿；首页小图只标选中的和前沿最高端 5 个。
    final frontierModels = paretoFrontier(models, metric).reversed;
    final highlighted =
        (detailedLabels ? frontierModels : frontierModels.take(5)).toList();
    final selectedModels = models.where((m) => m.slug == selected);
    final annotations = {...selectedModels, ...highlighted};
    final occupied = <Rect>[];
    // 每个模型的圆点都是避让目标：标签不允许压住任何数据点。
    final dotRects = <Rect>[
      for (final m in models)
        Rect.fromCircle(
            center: geometry.point(m), radius: m.slug == selected ? 11 : 7),
    ];
    for (final model in annotations) {
      final point = geometry.point(model);
      // 大图标签更窄；小图保持原宽度。
      final maxWidth = detailedLabels
          ? math.min(80.0, plot.width - 12)
          : math.min(110.0, plot.width - 12);
      // 放大图空间紧张时按 10 → 9 → 8 逐级缩小字号；首页小图保持固定字号。
      final fontSizes = detailedLabels ? const [10.0, 9.0, 8.0] : const [10.0];
      _LabelText? label;
      Rect? bounds;
      var leastDot = double.infinity;
      var leastOverlap = double.infinity;
      for (final fontSize in fontSizes) {
        // 名字和分数连成一段，最多排两行，且两行宽度尽量接近。
        final labelText = _layoutLabel(
            '${model.name} ${model.intelligence.toStringAsFixed(1)}',
            fontSize,
            maxWidth);
        final width = labelText.width;
        final height = labelText.height;
        final offsets = <Offset>[];
        if (detailedLabels) {
          // 大图：三个距离层各试八个方位，尽量找到不遮点也不重叠的位置。
          for (final gap in const [8.0, 20.0, 34.0]) {
            offsets.addAll([
              Offset(-width - gap, -height / 2),
              Offset(gap, -height / 2),
              Offset(-width / 2, -height - gap),
              Offset(-width / 2, gap),
              Offset(-width - gap, -height - gap),
              Offset(gap, -height - gap),
              Offset(-width - gap, gap),
              Offset(gap, gap),
            ]);
          }
        } else {
          // 首页小图沿用最初版本的四个候选方位。
          offsets.addAll([
            Offset(-width - 8, -height / 2),
            Offset(8, -height - 8),
            Offset(-width / 2, 8),
            Offset(-width - 8, -height - 8),
          ]);
        }
        // 大图允许标签贴近画布边缘，避免被 clamp 拉回压到圆点上。
        final minX = detailedLabels ? 2.0 : plot.left;
        final maxX = detailedLabels
            ? math.max(minX, size.width - width - 2)
            : math.max(plot.left, plot.right - width);
        Rect? best;
        var bestDot = double.infinity;
        var bestOverlap = double.infinity;
        for (final offset in offsets) {
          final candidate = Rect.fromLTWH(
              (point.dx + offset.dx).clamp(minX, maxX).toDouble(),
              (point.dy + offset.dy)
                  .clamp(2.0, math.max(2.0, plot.bottom - height - 4))
                  .toDouble(),
              width,
              height);
          if (!detailedLabels) {
            // 小图：压到圆点或和已放标签重叠的候选直接作废，找不到干净位置就不画。
            final hitsDot =
                dotRects.any((dot) => !dot.intersect(candidate).isEmpty);
            final hitsLabel =
                occupied.any((placed) => placed.inflate(3).overlaps(candidate));
            if (hitsDot || hitsLabel) continue;
            best = candidate;
            break;
          }
          var overlap = 0.0;
          for (final placed in occupied) {
            final hit = placed.inflate(3).intersect(candidate);
            if (!hit.isEmpty) overlap += hit.width * hit.height;
          }
          var dotOverlap = 0.0;
          for (final dot in dotRects) {
            final hit = dot.intersect(candidate);
            if (!hit.isEmpty) dotOverlap += hit.width * hit.height;
          }
          // 大图：先保证不遮点，再在同类里挑标签重叠面积最小的位置。
          if (dotOverlap < bestDot ||
              (dotOverlap == bestDot && overlap < bestOverlap)) {
            bestDot = dotOverlap;
            bestOverlap = overlap;
            best = candidate;
          }
          if (dotOverlap == 0 && overlap == 0) break;
        }
        if (detailedLabels) {
          if (bestDot < leastDot ||
              (bestDot == leastDot && bestOverlap < leastOverlap)) {
            leastDot = bestDot;
            leastOverlap = bestOverlap;
            bounds = best;
            label = labelText;
          }
          if (leastDot == 0 && leastOverlap == 0) break;
        } else {
          if (best == null) continue;
          bounds = best;
          label = labelText;
          break;
        }
      }
      final chosenLabel = label;
      final chosenBounds = bounds;
      if (chosenLabel == null || chosenBounds == null) continue;
      occupied.add(chosenBounds);
      if (detailedLabels) {
        // 细引导线把标签和圆点连起来，避免误读归属。
        final anchor = Offset(
            point.dx.clamp(chosenBounds.left, chosenBounds.right),
            point.dy.clamp(chosenBounds.top, chosenBounds.bottom));
        final delta = anchor - point;
        if (delta.distance > 1) {
          canvas.drawLine(
              point + delta / delta.distance * 4,
              anchor,
              Paint()
                ..color = gridColor.withValues(alpha: 0.6)
                ..strokeWidth = 0.8);
        }
      }
      final rounded =
          RRect.fromRectAndRadius(chosenBounds, const Radius.circular(6));
      canvas.drawRRect(
          rounded, Paint()..color = background.withValues(alpha: 0.94));
      canvas.drawRRect(
          rounded,
          Paint()
            ..color = gridColor.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7);
      // 逐行绘制，不在文本里拼换行符。
      for (var i = 0; i < chosenLabel.painters.length; i++) {
        chosenLabel.painters[i].paint(canvas,
            chosenBounds.topLeft + Offset(6, 4 + chosenLabel.lineHeight * i));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RelationPainter old) => true;
}

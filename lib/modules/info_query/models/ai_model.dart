import 'dart:math' as math;

enum AiCostMetric {
  task('每任务成本', '美元 / 任务'),
  input('输入价格', '美元 / 百万 Token'),
  output('输出价格', '美元 / 百万 Token');

  const AiCostMetric(this.label, this.unit);
  final String label;
  final String unit;
}

/// 只保留公开榜单中可验证的指标，不推算缺失的每任务成本。
class AiModel {
  final String slug;
  final String name;
  final String creator;
  final double intelligence;
  final double? taskCost;
  final double? inputPrice;
  final double? outputPrice;
  final bool estimated;

  const AiModel(
      {required this.slug,
      required this.name,
      required this.creator,
      required this.intelligence,
      this.taskCost,
      this.inputPrice,
      this.outputPrice,
      this.estimated = false});

  double? cost(AiCostMetric metric) => switch (metric) {
        AiCostMetric.task => taskCost,
        AiCostMetric.input => inputPrice,
        AiCostMetric.output => outputPrice,
      };

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'creator': creator,
        'intelligenceIndex': intelligence,
        'intelligenceIndexCostPerTask': taskCost,
        'price1mInputTokens': inputPrice,
        'price1mOutputTokens': outputPrice,
        'intelligenceIndexIsEstimated': estimated,
      };

  static AiModel? fromJson(Map<String, dynamic> row) {
    double? number(dynamic value) {
      if (value is! num || !value.isFinite || value < 0) return null;
      return value.toDouble();
    }

    final slug = row['slug'];
    final name = row['name'];
    final score = number(row['intelligenceIndex']);
    if (slug is! String ||
        slug.isEmpty ||
        name is! String ||
        name.isEmpty ||
        score == null) {
      return null;
    }
    final perTask = row['intelligenceIndexCostPerTask'];
    final costs = perTask is Map ? perTask['cost'] : null;
    // 当前榜单为数字字段；兼容旧缓存及源站曾使用的嵌套结构。
    final task =
        number(perTask) ?? number(costs is Map ? costs['total'] : null);
    return AiModel(
        slug: slug,
        name: name,
        creator: row['modelCreatorName'] as String? ??
            row['creator'] as String? ??
            '其他',
        intelligence: score,
        taskCost: task,
        inputPrice: number(row['price1mInputTokens']),
        outputPrice: number(row['price1mOutputTokens']),
        estimated: row['intelligenceIndexIsEstimated'] == true);
  }
}

class AiSnapshot {
  final DateTime fetchedAt;
  final List<AiModel> models;
  const AiSnapshot({required this.fetchedAt, required this.models});

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'fetchedAt': fetchedAt.toIso8601String(),
        'models': models.map((m) => m.toJson()).toList()
      };
}

/// 以每家厂商最高智能指数排名，同分时按名称排序，保证榜单稳定。
List<String> topCreators(List<AiModel> models, {int limit = 20}) {
  final best = <String, double>{};
  for (final model in models) {
    final previous = best[model.creator];
    if (previous == null || model.intelligence > previous) {
      best[model.creator] = model.intelligence;
    }
  }
  final ranked = best.keys.toList()
    ..sort((a, b) {
      final score = best[b]!.compareTo(best[a]!);
      return score != 0 ? score : a.compareTo(b);
    });
  return ranked.take(limit).toList();
}

/// 帕累托前沿：不存在成本更低或相等、能力更高的模型。
List<AiModel> paretoFrontier(List<AiModel> models, AiCostMetric metric) {
  final sorted = models.where((m) => m.cost(metric) != null).toList()
    ..sort((a, b) {
      final price = a.cost(metric)!.compareTo(b.cost(metric)!);
      return price != 0 ? price : b.intelligence.compareTo(a.intelligence);
    });
  var best = double.negativeInfinity;
  final result = <AiModel>[];
  for (final m in sorted) {
    if (m.intelligence > best) {
      result.add(m);
      best = m.intelligence;
    }
  }
  return result;
}

double logCost(double value) => math.log(value) / math.ln10;

import 'dart:convert';
import '../models/ai_model.dart';

/// 解码源站公开 HTML 内的 Next.js 数据字符串，不执行网页脚本。
List<AiModel> parseAiLeaderboard(String html) {
  final chunks = <String>[];
  final marker = RegExp(r'self\.__next_f\.push\(\[1,\s*"');
  for (final match in marker.allMatches(html)) {
    final start = match.end - 1;
    for (var end = start + 1; end < html.length; end++) {
      if (html[end] == r'\') {
        end++;
        continue;
      }
      if (html[end] == '"') {
        try {
          chunks.add(jsonDecode(html.substring(start, end + 1)) as String);
        } on FormatException {/* 损坏的片段不作为数据。 */}
        break;
      }
    }
  }
  // 分块可能切开同一条记录，按源站顺序合并后提取。
  final raw = chunks.isEmpty ? html : chunks.join();
  final bySlug = <String, AiModel>{};
  // 当前榜单使用 initialModels；models 仍用于旧页面及部分导航数据。
  final arrays = RegExp(r'"(?:initialModels|models)"\s*:\s*\[').allMatches(raw);
  for (final match in arrays) {
    final start = match.end - 1;
    var depth = 0;
    var quoted = false;
    for (var end = start; end < raw.length; end++) {
      final char = raw[end];
      if (quoted && char == r'\') {
        end++;
        continue;
      }
      if (char == '"') {
        quoted = !quoted;
        continue;
      }
      if (quoted) continue;
      if (char == '[') depth++;
      if (char == ']' && --depth == 0) {
        try {
          final rows = jsonDecode(raw.substring(start, end + 1)) as List;
          for (final row in rows) {
            if (row is! Map<String, dynamic>) continue;
            final model = AiModel.fromJson(row);
            if (model == null) continue;
            final previous = bySlug[model.slug];
            int richness(AiModel m) => [m.taskCost, m.inputPrice, m.outputPrice]
                .where((x) => x != null)
                .length;
            if (previous == null || richness(model) > richness(previous)) {
              bySlug[model.slug] = model;
            }
          }
        } on FormatException {/* 使用后备记录解析。 */} on TypeError {/* 使用后备记录解析。 */}
        break;
      }
    }
  }
  if (bySlug.isNotEmpty) {
    return bySlug.values.toList()
      ..sort((a, b) => b.intelligence.compareTo(a.intelligence));
  }
  // 新记录不再带 id，改用实际模型标识 slug，同时兼容旧记录。
  final starts = RegExp(r'\{[^{}]{0,512}"(?:slug|id)"\s*:').allMatches(raw);
  for (final match in starts) {
    final start = match.start;
    var depth = 0;
    var inString = false;
    var end = start;
    for (; end < raw.length; end++) {
      final char = raw[end];
      if (inString && char == r'\') {
        end++;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == '{') depth++;
      if (char == '}' && --depth == 0) break;
    }
    if (end >= raw.length) continue;
    try {
      final row =
          jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      final model = AiModel.fromJson(row);
      if (model == null) continue;
      final previous = bySlug[model.slug];
      int completeness(AiModel m) => [m.taskCost, m.inputPrice, m.outputPrice]
          .where((x) => x != null)
          .length;
      if (previous == null || completeness(model) > completeness(previous)) {
        bySlug[model.slug] = model;
      }
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
  }
  if (bySlug.isEmpty) {
    final models = _parseLeaderboardTable(html);
    if (models.isEmpty) {
      throw const FormatException('榜单数据结构变化或页面未返回模型数据');
    }
    return models..sort((a, b) => b.intelligence.compareTo(a.intelligence));
  }
  return bySlug.values.toList()
    ..sort((a, b) => b.intelligence.compareTo(a.intelligence));
}

// 页面公开表格可在内嵌数据格式变化时提供榜单上显示的指标。
List<AiModel> _parseLeaderboardTable(String html) {
  Iterable<String> contents(String source, String tag) =>
      RegExp('<$tag\\b[^>]*>(.*?)</$tag\\s*>',
              caseSensitive: false, dotAll: true)
          .allMatches(source)
          .map((match) => match.group(1)!);

  final tags = RegExp(r'<[^>]+>');
  final entities =
      RegExp(r'&(?:amp|quot|apos|lt|gt|nbsp|#\d+|#x[0-9a-fA-F]+);');
  const namedEntities = {
    'amp': '&',
    'quot': '"',
    'apos': "'",
    'lt': '<',
    'gt': '>',
    'nbsp': ' ',
  };
  String plain(String value) => value
      .replaceAll(tags, '')
      .replaceAllMapped(entities, (match) {
        final key = match[0]!.substring(1, match[0]!.length - 1);
        if (!key.startsWith('#')) return namedEntities[key]!;
        final hex = key.startsWith('#x');
        final code =
            int.tryParse(key.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
        return code != null && code <= 0x10ffff
            ? String.fromCharCode(code)
            : match[0]!;
      })
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final modelLink = RegExp(
      r'''href\s*=\s*["'](?:https://artificialanalysis\.ai)?/models/([\w-]+)(?=[/?#"'])''');
  final creatorImage = RegExp(
      r'''<img\b[^>]*\balt\s*=\s*(?:"([^"]*)"|'([^']*)')''',
      caseSensitive: false);
  for (final table in contents(html, 'table')) {
    final rows = contents(table, 'tr');
    final models = <String, AiModel>{};
    var nameColumn = -1;
    var scoreColumn = -1;
    var costColumn = -1;
    for (final row in rows) {
      final headers =
          contents(row, 'th').map((cell) => plain(cell).toLowerCase()).toList();
      if (headers.isNotEmpty) {
        nameColumn = headers.indexOf('model');
        scoreColumn = headers
            .indexWhere((header) => header.contains('intelligence index'));
        costColumn =
            headers.indexWhere((header) => header.contains('cost per task'));
        continue;
      }
      if (nameColumn < 0 || scoreColumn < 0) continue;
      final cells = contents(row, 'td').toList();
      if (nameColumn >= cells.length || scoreColumn >= cells.length) continue;
      final nameCell = cells[nameColumn];
      final name = plain(nameCell);
      final family = modelLink.firstMatch(row)?.group(1);
      final score = double.tryParse(plain(cells[scoreColumn]));
      if (name.isEmpty || family == null || score == null) continue;
      final creator = creatorImage.firstMatch(nameCell);
      // 同一模型系列的不同推理档位可能链接到同一个详情页面。
      final slug = '$family/$name';
      final model = AiModel.fromJson({
        'slug': slug,
        'name': name,
        'modelCreatorName': creator == null
            ? null
            : plain(creator.group(1) ?? creator.group(2)!),
        'intelligenceIndex': score,
        'intelligenceIndexCostPerTask':
            costColumn < 0 || costColumn >= cells.length
                ? null
                : double.tryParse(
                    plain(cells[costColumn]).replaceAll(RegExp(r'[$,\s]'), '')),
      });
      if (model != null) models[slug] = model;
    }
    if (models.isNotEmpty) return models.values.toList();
  }
  return [];
}

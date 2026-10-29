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
  if (bySlug.isEmpty) throw const FormatException('榜单数据结构变化或页面未返回模型数据');
  return bySlug.values.toList()
    ..sort((a, b) => b.intelligence.compareTo(a.intelligence));
}

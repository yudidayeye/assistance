import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage/database_service.dart';
import '../models/ai_model.dart';
import 'ai_leaderboard_parser.dart';

class AiQueryException implements Exception {
  final String message;
  const AiQueryException(this.message);
  @override
  String toString() => message;
}

class AiLeaderboardService {
  static const sourceUrl = 'https://artificialanalysis.ai/leaderboards/models';
  static const cacheKey = 'info_query_ai_snapshot';
  static final instance = AiLeaderboardService();
  final http.Client? client;
  final Duration timeout;
  final Future<String?> Function() readCache;
  final Future<void> Function(String) writeCache;
  final DateTime Function() clock;

  AiLeaderboardService(
      {this.client,
      this.timeout = const Duration(seconds: 35),
      Future<String?> Function()? cacheReader,
      Future<void> Function(String)? cacheWriter,
      DateTime Function()? clock})
      : readCache = cacheReader ?? _readCache,
        writeCache = cacheWriter ?? _writeCache,
        clock = clock ?? DateTime.now;

  static Future<String?> _readCache() async {
    final rows = await DatabaseService.instance
        .query('app_settings', where: 'key = ?', whereArgs: [cacheKey]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> _writeCache(String value) =>
      DatabaseService.instance.upsertSetting(cacheKey, value);

  Future<AiSnapshot?> cached() async {
    final text = await readCache();
    if (text == null) return null;
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['schema'] != 1) return null;
      final models = (data['models'] as List)
          .map((m) => AiModel.fromJson(m as Map<String, dynamic>))
          .whereType<AiModel>()
          .toList();
      if (models.isEmpty) return null;
      return AiSnapshot(
          fetchedAt: DateTime.parse(data['fetchedAt'] as String),
          models: models);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<AiSnapshot> query() async {
    try {
      final uri = Uri.parse(sourceUrl);
      const headers = {
        'Accept': 'text/html',
        'Cache-Control': 'no-cache',
        'User-Agent': 'Mozilla/5.0 (compatible; AssistanceInfoQuery/1.0)'
      };
      final response = await (client?.get(uri, headers: headers) ??
              http.get(uri, headers: headers))
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AiQueryException(
            response.statusCode == 403 || response.statusCode == 429
                ? '数据源暂时限制访问（${response.statusCode}），请稍后重试或查看原始榜单'
                : '数据源返回 HTTP ${response.statusCode}，请稍后重试');
      }
      final body = utf8.decode(response.bodyBytes);
      final models = await compute(parseAiLeaderboard, body);
      final snapshot = AiSnapshot(fetchedAt: clock(), models: models);
      // 查询成功不依赖缓存写入；缓存故障不丢弃已获取的真实数据。
      try {
        await writeCache(jsonEncode(snapshot.toJson()));
      } catch (_) {/* 保留本次结果。 */}
      return snapshot;
    } on AiQueryException {
      rethrow;
    } on TimeoutException {
      throw const AiQueryException('查询超时，请检查网络或代理后重试');
    } on SocketException {
      throw const AiQueryException('无法连接数据源，请检查网络或代理后重试');
    } on http.ClientException {
      throw const AiQueryException('无法连接数据源，请检查网络或代理后重试');
    } on HandshakeException {
      throw const AiQueryException('安全连接失败，请检查设备时间或网络设置');
    } on FormatException {
      throw const AiQueryException('榜单数据格式发生变化，暂时无法生成关系图，请查看原始榜单');
    } catch (_) {
      throw const AiQueryException('查询失败，请稍后重试或查看原始榜单');
    }
  }
}

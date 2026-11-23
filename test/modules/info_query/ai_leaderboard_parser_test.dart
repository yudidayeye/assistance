import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_assistant/modules/info_query/services/ai_leaderboard_parser.dart';
import 'package:my_assistant/modules/info_query/services/ai_leaderboard_service.dart';

void main() {
  test('内嵌数据不可读时使用公开榜单表格，并保留不同推理档位', () {
    final models = parseAiLeaderboard('''
      <script>self.__next_f.push([1,"0:[]"])</script>
      <table><thead>
        <tr><th colspan="4">Intelligence and Price</th></tr>
        <tr><th>Model</th><th>Artificial Analysis Intelligence Index</th>
          <th>Cost per Task <span>USD</span></th><th>Further Analysis</th></tr>
      </thead><tbody>
        <tr><td>Example High</td><td>40</td><td>--</td>
          <td><a href="/models/example">Model</a></td></tr>
        <tr><td><img alt="A &amp; B">Example Max</td><td>50</td><td>\$ 1.25</td>
          <td><a href="/models/example">Model</a></td></tr>
        <tr><td>Unranked</td><td>--</td><td>\$0.50</td>
          <td><a href="/models/unranked">Model</a></td></tr>
      </tbody></table>
    ''');
    expect(models.map((model) => model.name), ['Example Max', 'Example High']);
    expect(models.map((model) => model.slug).toSet(), hasLength(2));
    expect(models.first.creator, 'A & B');
    expect(models.first.taskCost, 1.25);
    expect(models.first.inputPrice, isNull);
    expect(models.last.taskCost, isNull);
  });

  test('当前榜单从initialModels读取无id的模型，忽略导航数据及缺失分数', () {
    // 2026-10-29 公开页面中的四条原始记录，保留当前的 RSC 数据封装。
    final html =
        File('test/modules/info_query/fixtures/aa_leaderboard_2026_10_29.html')
            .readAsStringSync();
    final models = parseAiLeaderboard(html);
    expect(models, hasLength(3));
    expect(models.first.slug, 'gemini-4-carbon');
    expect(models.first.creator, 'Google');
    expect(models.first.intelligence, closeTo(59.425738829526, 1e-10));
    expect(models.first.taskCost, closeTo(7.755545745286556, 1e-10));
    expect(models.first.inputPrice, 4);
    expect(models.first.outputPrice, 20);
    expect(models.any((model) => model.slug == 'jt-35b-flash'), isFalse);
    expect(models.where((model) => model.taskCost == null), hasLength(1));
  });

  test('后备解析使用slug识别模型，不依赖外层数组名或id', () {
    final row = {
      'slug': 'no-id-model',
      'name': '无id模型',
      'modelCreatorName': '厂商',
      'intelligenceIndex': 42.5,
      'scores': {'nested': 0.8},
      'intelligenceIndexCostPerTask': 0.25,
    };
    final model = parseAiLeaderboard('1:${jsonEncode(row)}').single;
    expect(model.slug, 'no-id-model');
    expect(model.intelligence, 42.5);
    expect(model.taskCost, 0.25);
  });

  test('当前格式查询成功后写入缓存并可按旧缓存协议恢复', () async {
    final html =
        File('test/modules/info_query/fixtures/aa_leaderboard_2026_10_29.html')
            .readAsStringSync();
    String? cache;
    final client = MockClient((_) async => http.Response(html, 200,
        headers: {'content-type': 'text/html; charset=utf-8'}));
    addTearDown(client.close);
    final service = AiLeaderboardService(
      client: client,
      cacheReader: () async => cache,
      cacheWriter: (value) async => cache = value,
      clock: () => DateTime.utc(2026, 10, 29),
    );
    final result = await service.query();
    expect(result.models, hasLength(3));
    final restored = (await service.cached())!;
    expect(restored.fetchedAt, result.fetchedAt);
    expect(restored.models.map((model) => model.toJson()),
        result.models.map((model) => model.toJson()));
  });
}

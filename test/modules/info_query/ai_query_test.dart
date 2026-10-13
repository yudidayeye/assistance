import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/core/module_system/module_registry.dart';
import 'package:my_assistant/modules/info_query/info_query_module.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/modules/info_query/models/ai_model.dart';
import 'package:my_assistant/modules/info_query/pages/ai_models_page.dart';
import 'package:my_assistant/modules/info_query/services/ai_leaderboard_parser.dart';
import 'package:my_assistant/modules/info_query/services/ai_leaderboard_service.dart';
import 'package:my_assistant/modules/info_query/widgets/ai_relation_chart.dart';

Map<String, dynamic> row(String name,
        {double? cost = 0.1, double score = 50}) =>
    {
      'id': name,
      'slug': name,
      'name': name,
      'modelCreatorName': '厂商A',
      'intelligenceIndex': score,
      'intelligenceIndexCostPerTask': {
        'cost': {'total': cost}
      },
      'price1mInputTokens': 2,
      'price1mOutputTokens': 10,
    };
String html(List<Map<String, dynamic>> rows) =>
    '<script>self.__next_f.push([1,${jsonEncode('1:${jsonEncode({
          'models': rows
        })}')}])</script>';

void main() {
  test('解析公开网页的嵌套任务成本，字符串括号不影响解析，分块可重组', () {
    final payload = '1:${jsonEncode({
          'models': [row('模型["A"]{1}')]
        })}';
    final cut = payload.length ~/ 2;
    final raw =
        '<script>self.__next_f.push([1,${jsonEncode(payload.substring(0, cut))}])</script>'
        '<script>self.__next_f.push([1,${jsonEncode(payload.substring(cut))}])</script>';
    final model = parseAiLeaderboard(raw).single;
    expect(model.name, '模型["A"]{1}');
    expect(model.taskCost, 0.1);
    expect(model.inputPrice, 2);
  });

  test('模型键顺序可变化，缺失任务成本不以Token单价代替', () {
    final record = row('model', cost: null);
    record.remove('id');
    record['id'] = 'model';
    final model = parseAiLeaderboard(html([record])).single;
    expect(model.taskCost, isNull);
    expect(model.inputPrice, 2);
  });

  test('重复模型保留较完整记录；缺失能力和负成本不伪造', () {
    final bad = row('invalid')..['intelligenceIndex'] = null;
    final model =
        parseAiLeaderboard(html([row('model', cost: null), row('model'), bad]))
            .single;
    expect(model.taskCost, 0.1);
    expect(AiModel.fromJson(row('negative', cost: -1))!.taskCost, isNull);
    expect(() => parseAiLeaderboard('<html>challenge</html>'),
        throwsFormatException);
  });

  test('优势前沿排除同价低分、同分高价，成本为零仍可比较', () {
    final models = [
      row('free', cost: 0, score: 20),
      row('cheap', cost: 0.1, score: 50),
      row('sameprice', cost: 0.1, score: 40),
      row('dominated', cost: 0.2, score: 50),
      row('smart', cost: 1, score: 60)
    ].map((r) => AiModel.fromJson(r)!).toList();
    expect(paretoFrontier(models, AiCostMetric.task).map((m) => m.name),
        ['free', 'cheap', 'smart']);
    final plotted = models.where((m) => m.taskCost! > 0).toList();
    final geometry =
        ChartGeometry(plotted, AiCostMetric.task, const Size(320, 300));
    expect(geometry.point(plotted.first).dx,
        lessThan(geometry.point(plotted.last).dx));
    expect(geometry.point(plotted.last).dy,
        lessThan(geometry.point(plotted.first).dy));
  });

  test('主动查询只GET公共榜单，成功保存并恢复带日期的缓存', () async {
    String? cached;
    final service = AiLeaderboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.body, isEmpty);
          expect(request.url.toString(), AiLeaderboardService.sourceUrl);
          return http.Response(html([row('model')]), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
        cacheReader: () async => cached,
        cacheWriter: (v) async {
          cached = v;
        },
        clock: () => DateTime.utc(2026, 10, 13));
    expect(await service.cached(), isNull);
    final snapshot = await service.query();
    expect(snapshot.models.single.name, 'model');
    expect((await service.cached())!.fetchedAt, DateTime.utc(2026, 10, 13));
    expect((await service.cached())!.models.single.creator, '厂商A');
  });

  test('限流、格式变化和超时给出明确错误且不覆盖上次缓存', () async {
    for (final status in [403, 429, 500, 200]) {
      var writes = 0;
      final service = AiLeaderboardService(
          client: MockClient((_) async => http.Response('challenge', status)),
          cacheReader: () async => null,
          cacheWriter: (_) async {
            writes++;
          });
      await expectLater(service.query(), throwsA(isA<AiQueryException>()));
      expect(writes, 0);
    }
    final service = AiLeaderboardService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 10),
        cacheReader: () async => null,
        cacheWriter: (_) async {});
    await expectLater(
        service.query(),
        throwsA(isA<AiQueryException>()
            .having((e) => e.message, 'message', contains('超时'))));
  });

  testWidgets('进入不自动查询，点击才加载关系图，查询失败保留标记缓存的图', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    final service = AiLeaderboardService(
        client: MockClient((_) async {
          calls++;
          if (calls > 1) return http.Response('', 503);
          return http.Response(html([row('测试模型')]), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }),
        cacheReader: () async => null,
        cacheWriter: (_) async {});
    await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider.instance.themeData,
        home: AiModelsPage(service: service)));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('查询最新数据'));
    for (var i = 0;
        i < 30 && find.byType(AiRelationChart).evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AiRelationChart), findsOneWidget);
    expect(find.textContaining('本次获取'), findsOneWidget);
    await tester.tap(find.text('查询最新数据'));
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.textContaining('上次查询缓存'), findsOneWidget);
    expect(find.byType(AiRelationChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('资讯模块可离线注册并声明自己的查询路由', () async {
    final module = InfoQueryModule();
    ModuleRegistry.instance.reset();
    addTearDown(ModuleRegistry.instance.reset);
    await ModuleRegistry.instance.register(module);
    expect(ModuleRegistry.instance.getModule('info_query'), same(module));
    expect(module.displayName, '资讯查询');
    expect((module.buildSubRoutes().single as GoRoute).path, 'ai-models');
    expect((await module.getSummary()).line1, contains('AI 模型'));
  });

  testWidgets('关系图点击模型可查看金额，放大图支持缩放且没有布局溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final snapshot = AiSnapshot(
        fetchedAt: DateTime.utc(2026, 10, 13),
        models: [AiModel.fromJson(row('测试模型'))!]);
    final service = AiLeaderboardService(
        cacheReader: () async => jsonEncode(snapshot.toJson()),
        cacheWriter: (_) async {});
    await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider.instance.themeData,
        home: AiModelsPage(service: service)));
    await tester.pumpAndSettle();
    final chart = find.byType(AiRelationChart);
    await tester.ensureVisible(chart);
    final size = tester.getSize(chart);
    final point = ChartGeometry(snapshot.models, AiCostMetric.task, size)
        .point(snapshot.models.single);
    await tester.tapAt(tester.getTopLeft(chart) + point);
    await tester.pumpAndSettle();
    expect(find.textContaining('每任务成本：'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('放大关系图'));
    await tester.tap(find.text('放大关系图'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('能力与成本关系图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('查询失败后延迟读取的本地缓存仍可恢复', (tester) async {
    final cached = Completer<String?>();
    final service = AiLeaderboardService(
        client: MockClient((_) async => http.Response('', 503)),
        cacheReader: () => cached.future,
        cacheWriter: (_) async {});
    await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider.instance.themeData,
        home: AiModelsPage(service: service)));
    await tester.pump();
    await tester.tap(find.text('查询最新数据'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    cached.complete(jsonEncode(AiSnapshot(
        fetchedAt: DateTime.utc(2026, 10, 13),
        models: [AiModel.fromJson(row('缓存模型'))!]).toJson()));
    await tester.pumpAndSettle();
    expect(find.byType(AiRelationChart), findsOneWidget);
    expect(find.textContaining('上次查询缓存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

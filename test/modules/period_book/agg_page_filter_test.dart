// `dart:ffi` 也有个 `Size`（FFI 结构体），会与 `dart:ui` 的同名类型撞车
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/modules/period_book/pages/agg.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 覆盖契约 C3 / C4 / C5（`specs/001-report-pie-filter/contracts/ui-contract.md`）：
/// 吸顶筛选标签、三个视图的卡片下钻、页面的筛选与展开状态。
///
/// 这里跑的是**真实数据库**：`AggPage` 的取数全部走 `PeriodBookService`，
/// 把它换成内存替身反而测不出 `_expenseMap` / `_calcMap` 的装配口径。
void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      // 与 import_export_vault_sort_test.dart 同款：flutter test 下 sqlite3.dll
      // 不在系统搜索路径里，需要先手动载入
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    // 建表必须挂在 `openDatabase` 的 `onCreate` 上，不能对已打开的句柄直接调用
    // `createSchemaForTesting`：后者内部的 `db.transaction` 一旦提交，随后用
    // `db`（而非 `txn`）执行的建表语句会与事务自己持有的锁互等，永远不返回。
    // 走 `onCreate` 则与生产环境的建库路径一致，且拿到的就是最新 schema。
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        // `createSchemaForTesting` 内部自行取 `DatabaseService._currentVersion`，
        // 这里的值只决定 `onCreate` 是否被调用
        version: 1,
        onCreate: (d, _) => DatabaseService.instance.createSchemaForTesting(d),
      ),
    );
    DatabaseService.instance.useDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------- 数据装配

  /// 造一个周期 + 一个阶段
  Future<void> seedPeriod({
    required int periodId,
    required int stageId,
    required String startDate,
    required String endDate,
    required double baseAmount,
    required double stageBalance,
  }) async {
    await db.insert('mod_period_book_periods', {
      'id': periodId,
      'start_date': startDate,
      'end_date': endDate,
      'base_amount': baseAmount,
      'is_closed': 1,
      'created_at': '${startDate}T00:00:00.000',
      'updated_at': '${startDate}T00:00:00.000',
    });
    await db.insert('mod_period_book_stages', {
      'id': stageId,
      'period_id': periodId,
      'start_date': startDate,
      'end_date': endDate,
      'current_date': endDate,
      'balance': stageBalance,
      'sort_order': 0,
      'created_at': '${startDate}T00:00:00.000',
      'updated_at': '${startDate}T00:00:00.000',
    });
  }

  Future<void> seedExpense({
    required int stageId,
    required String category,
    required double amount,
    required String description,
    int sortOrder = 0,
  }) async {
    await db.insert('mod_period_book_expenses', {
      'stage_id': stageId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': '2026-08-01T00:00:00.000',
    });
  }

  Future<void> seedLargeAddition({
    required int periodId,
    required double amount,
    required String reason,
    int sortOrder = 0,
  }) async {
    await db.insert('mod_period_book_large_additions', {
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'sort_order': sortOrder,
      'created_at': '2026-08-01T00:00:00.000',
    });
  }

  Future<void> seedLargeExpense({
    required int periodId,
    required String category,
    required double amount,
    required String description,
    int sortOrder = 0,
  }) async {
    await db.insert('mod_period_book_large_expenses', {
      'period_id': periodId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': '2026-08-01T00:00:00.000',
    });
  }

  /// 标准数据：让「购物」在 8 月周期有 4 条日常明细（触发展开控件）+ 1 条大额，
  /// 7 月周期没有任何「购物」支出（触发零小计卡片）。
  ///
  /// 阶段结余取 3000 − 600 − 50 = 2350，使倒推残值 `livingTotal` 恰为 0：
  /// 饼图里不会凭空多出一个「杂项」扇区，各用例的断言才不受它的干扰。
  Future<void> seedStandard() async {
    await seedPeriod(
      periodId: 1,
      stageId: 11,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
      baseAmount: 3000,
      stageBalance: 2350,
    );
    await seedPeriod(
      periodId: 2,
      stageId: 21,
      startDate: '2026-07-01',
      endDate: '2026-07-31',
      baseAmount: 3000,
      stageBalance: 2900,
    );

    await seedExpense(
      stageId: 11,
      category: '购物',
      amount: 320,
      description: '买衣服',
    );
    await seedExpense(
      stageId: 11,
      category: '购物',
      amount: 180,
      description: '买鞋',
      sortOrder: 1,
    );
    await seedExpense(
      stageId: 11,
      category: '购物',
      amount: 60,
      description: '买书',
      sortOrder: 2,
    );
    await seedExpense(
      stageId: 11,
      category: '购物',
      amount: 40,
      description: '买包',
      sortOrder: 3,
    );
    // 其他消费：MUST 归入「其他」，MUST NOT 混进同名的「购物」（契约 C2-2）
    await seedExpense(
      stageId: 11,
      category: 'other:购物',
      amount: 50,
      description: '小零食',
      sortOrder: 4,
    );
    await seedExpense(
      stageId: 21,
      category: '娱乐',
      amount: 100,
      description: '看电影',
    );

    await seedLargeAddition(periodId: 1, amount: 1000, reason: '年终奖');
    await seedLargeExpense(
      periodId: 1,
      category: '购物',
      amount: 500,
      description: '大额购物',
    );
    await seedLargeExpense(
      periodId: 1,
      category: '娱乐',
      amount: 200,
      description: '大额娱乐',
      sortOrder: 1,
    );
  }

  // ---------------------------------------------------------------- 页面装配

  /// 卡片主体点击会 `context.push`，因此页面必须挂在真实的路由下。
  /// 路由表里放两个哨兵页面，用来断言「点展开控件没有触发跳转」（契约 C4-6）。
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AggPage()),
        GoRoute(
          path: '/period_book/detail/:id',
          builder: (_, __) => const Text('周期详情哨兵'),
        ),
        GoRoute(
          path: '/period_book/large_items/:id',
          builder: (_, __) => const Text('大额记录哨兵'),
        ),
      ],
    );
  }

  /// `_loadData()` 由 `initState` 触发，内部是一串二十来步的**真实**数据库 await。
  /// `testWidgets` 默认跑在 FakeAsync 里：隔离线程的应答只有放行真实事件循环才会
  /// 到达，而应答之后的续体排在 FakeAsync 的微任务队列里、只有 `pump` 才排空。
  /// 因此这里交替推进「放行真实事件循环」与「排空微任务队列」，一次迭代走一步。
  Future<void> pumpAggPage(WidgetTester tester) async {
    // 周期卡片挂在 `SliverList` 上，默认 800×600 的测试窗口只够建出第一张卡片，
    // 第二张连同它的筛选区根本不会进树。把窗口拉高，让所有卡片一次建齐。
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));

    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump();
    }

    // 先失败、再让 `pumpAndSettle` 去撞 10 分钟的超时：取数没跑完时后面每一条
    // 断言都会落空，错误越早暴露越好
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '取数未在预期步数内完成',
    );
    await tester.pumpAndSettle();
  }

  /// 点图例选中分类；同名的图例行在图表右侧，索引取最后一个
  Future<void> tapLegend(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Finder filterLabel(String category) => find.text('筛选：$category');

  // ------------------------------------------------------------------ 用例

  group('C3 吸顶筛选标签', () {
    testWidgets('未筛选时不渲染标签', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      expect(filterLabel('购物'), findsNothing);
    });

    testWidgets('点击图例行后标签渲染并显示分类名', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      await tapLegend(tester, '购物');

      expect(filterLabel('购物'), findsOneWidget);
    });

    testWidgets('关闭控件与再次点击等价，取消后标签消失', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');
      expect(filterLabel('购物'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(filterLabel('购物'), findsNothing);
    });

    testWidgets('切换记账视图清空筛选', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tester.tap(find.text('大额'));
      await tester.pumpAndSettle();

      expect(filterLabel('购物'), findsNothing);
    });

    testWidgets('报表从占比切到趋势时筛选保留、标签仍在', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tester.tap(find.text('支出占比'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支出趋势'));
      await tester.pumpAndSettle();

      // 「支出趋势」视图没有饼图与图例，标签是唯一的取消入口（契约 C3-7）
      expect(filterLabel('购物'), findsOneWidget);
      expect(find.text('支出趋势'), findsOneWidget);
    });
  });

  group('C4 日常卡片下钻', () {
    testWidgets('图例入口：展示分类小计与至多 3 条明细', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      await tapLegend(tester, '购物');

      // 8 月周期：小计 600、折叠态只列前 3 条
      expect(find.text('购物小计'), findsNWidgets(2));
      expect(find.text('买衣服'), findsOneWidget);
      expect(find.text('买鞋'), findsOneWidget);
      expect(find.text('买书'), findsOneWidget);
      expect(find.text('买包'), findsNothing);
      // 「其他消费」不属于「购物」，MUST NOT 出现在筛选结果里（契约 C2-2）
      expect(find.text('小零食'), findsNothing);
      // 4 条 > 3 条，出展开控件
      expect(find.text('查看全部 4 条'), findsOneWidget);
    });

    testWidgets('扇区入口与图例入口等价', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      // 「购物」占日常饼图 600/650 ≈ 92%，圆心右侧的圆环带必然落在它的扇区里
      // （圆心留白 28、扇区半径 40）
      final pieCenter = tester.getCenter(find.byType(PieChart));
      await tester.tapAt(pieCenter + const Offset(34, 0));
      await tester.pumpAndSettle();

      expect(filterLabel('购物'), findsOneWidget);
      expect(find.text('查看全部 4 条'), findsOneWidget);
    });

    testWidgets('再次点击当前分类取消筛选', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tapLegend(tester, '购物');

      expect(filterLabel('购物'), findsNothing);
      expect(find.text('购物小计'), findsNothing);
    });

    testWidgets('点击扇区与图例之外的空白取消筛选', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');
      expect(filterLabel('购物'), findsOneWidget);

      // 饼图控件是正方形，左上角离圆心远于扇区半径，属于图例与扇区之外的空白
      final pieTopLeft = tester.getTopLeft(find.byType(PieChart));
      await tester.tapAt(pieTopLeft + const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(filterLabel('购物'), findsNothing);
    });

    testWidgets('超过 3 条可原地展开全部并收起，且不触发卡片跳转', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tester.tap(find.text('查看全部 4 条'));
      await tester.pumpAndSettle();

      expect(find.text('买包'), findsOneWidget);
      expect(find.text('收起'), findsOneWidget);
      // 展开控件不得冒泡成卡片跳转（契约 C4-6）
      expect(find.text('周期详情哨兵'), findsNothing);

      await tester.tap(find.text('收起'));
      await tester.pumpAndSettle();

      expect(find.text('买包'), findsNothing);
      expect(find.text('查看全部 4 条'), findsOneWidget);
    });

    testWidgets('不超过 3 条时不出展开控件', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      await tapLegend(tester, '其他');

      expect(find.text('查看全部 1 条'), findsNothing);
      expect(find.text('小零食'), findsOneWidget);
    });

    testWidgets('小计为零的周期保留卡片并显示零，且无空明细区', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      await tapLegend(tester, '购物');

      // 7 月周期没有任何「购物」支出，卡片仍在、小计显示零（契约 C4-9）
      expect(find.text('购物小计'), findsNWidgets(2));
      expect(find.text('¥0'), findsOneWidget);
      expect(find.text('查看全部 1 条'), findsNothing);
    });

    testWidgets('汇总行数值在筛选前后不变', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);

      // 8 月周期：个人消费 600（第一行总额 650、其他消费 50）
      expect(find.text('-¥600'), findsOneWidget);
      expect(find.text('-¥50'), findsOneWidget);
      expect(find.text('-¥650'), findsOneWidget);

      await tapLegend(tester, '购物');

      // 汇总行原样保留，多出来的一条是新增的分类小计（契约 C4-1）
      expect(find.text('-¥600'), findsNWidgets(2));
      expect(find.text('-¥50'), findsOneWidget);
      expect(find.text('-¥650'), findsOneWidget);
    });

    testWidgets('大额视图筛选时三组明细被整体替换', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tester.tap(find.text('大额'));
      await tester.pumpAndSettle();

      // 未筛选：三组明细齐全
      expect(find.text('大额追加'), findsOneWidget);
      expect(find.text('个人支出'), findsOneWidget);
      expect(find.text('年终奖'), findsOneWidget);

      await tapLegend(tester, '购物');

      // 「大额追加」「个人支出」「其他支出」三组全部让位（契约 C4-8）
      expect(find.text('大额追加'), findsNothing);
      expect(find.text('个人支出'), findsNothing);
      expect(find.text('其他支出'), findsNothing);
      expect(find.text('年终奖'), findsNothing);
      expect(find.text('购物小计'), findsNWidgets(2));
      expect(find.text('大额购物'), findsOneWidget);
      // 第一行净额口径不随筛选变化：追加 1000 − 大额支出 700（契约 C4-1）
      expect(find.text('+¥300'), findsOneWidget);
    });
  });

  group('C4 合计卡片分组', () {
    testWidgets('日常组与大额组各自给出小计，N 为两组之和', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tester.tap(find.text('合计'));
      await tester.pumpAndSettle();

      await tapLegend(tester, '购物');

      expect(find.text('购物小计'), findsNWidgets(2));
      expect(find.text('日常小计'), findsNWidgets(2));
      expect(find.text('大额小计'), findsNWidgets(2));
      // 8 月周期：4 条日常 + 1 条大额，折叠态先取日常 3 条
      expect(find.text('查看全部 5 条'), findsOneWidget);
      expect(find.text('买包'), findsNothing);

      await tester.tap(find.text('查看全部 5 条'));
      await tester.pumpAndSettle();

      expect(find.text('买包'), findsOneWidget);
      expect(find.text('大额购物'), findsOneWidget);
    });
  });

  group('C4 「杂项」只有残值', () {
    /// 阶段结余取 2000，倒推残值 3000 − 600 − 50 − 2000 = 350 > 0，
    /// 饼图里因此存在「杂项」扇区
    Future<void> seedResidual() async {
      await seedPeriod(
        periodId: 1,
        stageId: 11,
        startDate: '2026-08-01',
        endDate: '2026-08-31',
        baseAmount: 3000,
        stageBalance: 2000,
      );
      await seedExpense(
        stageId: 11,
        category: '购物',
        amount: 600,
        description: '买衣服',
      );
    }

    testWidgets('只出小计与一行说明，无明细区、无展开控件', (tester) async {
      await tester.runAsync(seedResidual);
      await pumpAggPage(tester);

      await tapLegend(tester, '杂项');

      expect(filterLabel('杂项'), findsOneWidget);
      expect(find.text('杂项小计'), findsOneWidget);
      expect(find.text('来自未逐条记录的部分'), findsOneWidget);
      expect(find.textContaining('查看全部'), findsNothing);
      // 「杂项」没有底层记录，任何支出描述都不该出现在它的筛选结果里
      expect(find.text('买衣服'), findsNothing);
    });
  });

  group('C5 展开态随筛选结果重算而整体重置', () {
    testWidgets('切换报表视图：展开态收起，筛选保留', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tester.tap(find.text('查看全部 4 条'));
      await tester.pumpAndSettle();
      expect(find.text('买包'), findsOneWidget);

      await tester.tap(find.text('支出占比'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支出趋势'));
      await tester.pumpAndSettle();

      // 卡片内容随报表视图切换重排，上一视图的展开状态没有理由保留（契约 C5-3）
      expect(find.text('买包'), findsNothing);
      expect(find.text('查看全部 4 条'), findsOneWidget);
      // 但筛选本身 MUST NOT 被清掉：「支出趋势」没有饼图也没有图例，
      // 吸顶标签是它唯一的取消入口（FR-017 / 契约 C3-7）
      expect(filterLabel('购物'), findsOneWidget);
    });

    testWidgets('调整范围条件：展开态收起', (tester) async {
      await tester.runAsync(seedStandard);
      await pumpAggPage(tester);
      await tapLegend(tester, '购物');

      await tester.tap(find.text('查看全部 4 条'));
      await tester.pumpAndSettle();
      expect(find.text('买包'), findsOneWidget);

      await tester.tap(find.text('2026年'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8月'));
      await tester.pumpAndSettle();

      // 范围条件一换，卡片内容随之重算，展开态一并收起（契约 C5-3）。
      // 「筛选因新范围无金额而自动取消」只是其中一条路径，其余路径同样要收起
      expect(find.text('买包'), findsNothing);
      expect(find.text('查看全部 4 条'), findsOneWidget);
    });
  });
}

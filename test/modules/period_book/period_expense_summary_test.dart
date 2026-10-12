import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/modules/period_book/pages/period_detail_page.dart';
import 'package:my_assistant/modules/period_book/period_book_module.dart';
import 'package:my_assistant/modules/period_book/widgets/report_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'period_detail_delete_test.dart' show fixture;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('工具箱未填余额只统计记录支出，空记录显示零且排除大额', () async {
    final db = await fixture();
    addTearDown(db.close);
    await db.update('mod_period_book_periods', {'is_closed': 1},
        where: 'id = 2');
    await db.update('mod_period_book_periods', {'end_date': '2099-12-31'},
        where: 'id = 1');
    final module = PeriodBookModule();
    expect((await module.getSummary()).line2, '支出 ¥10.00');
    await db.delete('mod_period_book_expenses', where: 'stage_id = 1');
    expect((await module.getSummary()).line2, '支出 ¥0.00');
    await db.update('mod_period_book_stages', {'balance': 900},
        where: 'id = 1');
    expect((await module.getSummary()).line2, '余额 ¥900.00');
  });

  testWidgets('阶段显示含首尾天数，支出弹窗分类及总额与历史日常报表一致', (tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await fixture();
      await db.update('mod_period_book_stages', {'balance': 950},
          where: 'id = 1');
      for (final (category, amount) in [('购物', 20), ('other:生活', 5)]) {
        await db.insert('mod_period_book_expenses', {
          'stage_id': 1,
          'category': category,
          'description': category,
          'amount': amount,
          'created_at': '2026-10-01'
        });
      }
    });
    addTearDown(db.close);
    final router = GoRouter(initialLocation: '/detail', routes: [
      GoRoute(
          path: '/detail',
          builder: (_, __) => const PeriodDetailPage(periodId: 1)),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('第1阶段 · 10天'), findsOneWidget);
    await tester.tap(find.text('支出').first);
    await tester.pumpAndSettle();
    expect(find.text('总支出构成'), findsOneWidget);
    final report = tester.widget<ReportCard>(find.byType(ReportCard));
    expect(report.expenseTypeData,
        {'工作': 10.0, '购物': 20.0, '其他': 5.0, '杂项': 25.0});
    expect(report.expenseTypeData.values.reduce((a, b) => a + b), 60);
    expect(report.monthlyData.single['expense'], 60);
    expect(tester.takeException(), isNull);
  });
}

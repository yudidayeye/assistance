import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/modules/period_book/pages/period_detail_page.dart';
import 'package:my_assistant/modules/period_book/services/period_book_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const tables = [
  'mod_period_book_periods',
  'mod_period_book_stages',
  'mod_period_book_additions',
  'mod_period_book_expenses',
  'mod_period_book_large_additions',
  'mod_period_book_large_expenses',
];

Future<Database> fixture() async {
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) =>
              DatabaseService.instance.createSchemaForTesting(db)));
  DatabaseService.instance.useDatabaseForTesting(db);
  for (final id in [1, 2]) {
    await db.insert(tables[0], {
      'id': id,
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
      'base_amount': 1000,
      'is_closed': 0,
      'created_at': '2026-10-01',
      'updated_at': '2026-10-01'
    });
    await db.insert(tables[1], {
      'id': id,
      'period_id': id,
      'start_date': '2026-10-01',
      'end_date': '2026-10-10',
      'sort_order': 1,
      'created_at': '2026-10-01',
      'updated_at': '2026-10-01'
    });
    for (final table in tables.skip(2)) {
      await db.insert(table, {
        'id': id,
        table.contains('large') ? 'period_id' : 'stage_id': id,
        'amount': 10,
        'created_at': '2026-10-01',
        if (table.contains('additions'))
          'reason': '追加'
        else ...{'category': '工作', 'description': '充值AI'},
      });
    }
  }
  return db;
}

void main() {
  setUpAll(() {
    if (Platform.isLinux || Platform.isWindows) sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('删除中途失败时，所有关联数据回滚', () async {
    final db = await fixture();
    addTearDown(db.close);
    await db.execute(
        "CREATE TRIGGER fail_delete BEFORE DELETE ON mod_period_book_stages BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(PeriodBookService.instance.deletePeriod(1),
        throwsA(isA<DatabaseException>()));
    for (final table in tables) {
      expect(await db.query(table), hasLength(2), reason: table);
    }
  });

  testWidgets('周期菜单支持取消和确认删除，保留其他周期及其条目', (tester) async {
    late Database db;
    await tester.runAsync(() async => db = await fixture());
    addTearDown(db.close);
    final router = GoRouter(initialLocation: '/detail', routes: [
      GoRoute(
          path: '/detail',
          builder: (_, __) => const PeriodDetailPage(periodId: 1)),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    Future<void> advanceIo() async {
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)));
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await advanceIo();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('新增周期'), findsOneWidget);
    expect(find.text('编辑周期'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.text('删除周期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final table in tables) {
        expect(await db.query(table), hasLength(2));
      }
    });
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除周期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await advanceIo();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final table in tables) {
        expect((await db.query(table)).single['id'], 2, reason: table);
      }
    });
    expect(tester.takeException(), isNull);
  });
}

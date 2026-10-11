import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/modules/period_book/pages/stage_edit_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('更多菜单保留编辑日期，取消删除不动数据，确认只删除当前阶段', (tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) =>
                  DatabaseService.instance.createSchemaForTesting(db)));
      DatabaseService.instance.useDatabaseForTesting(db);
      await db.insert('mod_period_book_periods', {
        'id': 1,
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'base_amount': 1000,
        'is_closed': 0,
        'created_at': '2026-10-01',
        'updated_at': '2026-10-01',
      });
      for (final id in [11, 12]) {
        await db.insert('mod_period_book_stages', {
          'id': id,
          'period_id': 1,
          'start_date': '2026-10-01',
          'end_date': '2026-10-10',
          'current_date': '2026-10-10',
          'sort_order': id - 10,
          'created_at': '2026-10-01',
          'updated_at': '2026-10-01',
        });
        await db.insert('mod_period_book_expenses', {
          'stage_id': id,
          'category': '工作',
          'description': '充值AI$id',
          'amount': 10,
          'sort_order': 0,
          'created_at': '2026-10-10',
          'entry_date': '2026-10-10',
        });
        await db.insert('mod_period_book_additions', {
          'stage_id': id,
          'reason': '追加',
          'amount': 10,
          'sort_order': 0,
          'created_at': '2026-10-10',
        });
      }
    });
    addTearDown(() => db.close());
    final router =
        GoRouter(initialLocation: '/period_book/stage_edit/11', routes: [
      GoRoute(
          path: '/period_book/stage_edit/:id',
          builder: (_, __) => const StageEditPage(stageId: 11)),
      GoRoute(
          path: '/period_book/detail/:id',
          builder: (_, __) => const Scaffold(body: Text('周期仍在'))),
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
    expect(find.text('充值AI11'), findsOneWidget);
    expect(find.text('10.10'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑日期'), findsOneWidget);
    await tester.tap(find.text('删除阶段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await db.query('mod_period_book_stages'), hasLength(2));
    });
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除阶段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await advanceIo();
    await tester.pumpAndSettle();
    expect(find.text('周期仍在'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.query('mod_period_book_periods'), hasLength(1));
      expect((await db.query('mod_period_book_stages')).single['id'], 12);
      expect(
          (await db.query('mod_period_book_expenses')).single['stage_id'], 12);
      expect(
          (await db.query('mod_period_book_additions')).single['stage_id'], 12);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/period_book/pages/large_items_edit_page.dart';
import 'package:my_assistant/modules/period_book/widgets/add_form.dart';
import 'package:my_assistant/shared/widgets/app_segmented_tab.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'period_detail_delete_test.dart' show fixture;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final index in [0, 1, 2]) {
    final label = ['个人支出', '其他支出', '大额追加'][index];
    testWidgets('$label确认添加后保持当前Tab并刷新记录', (tester) async {
      late Database db;
      await tester.runAsync(() async => db = await fixture());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> advanceIo() async {
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 2)));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      await tester.pumpWidget(const MaterialApp(
        home: LargeItemsEditPage(periodId: 1),
      ));
      await advanceIo();
      final tabs = find.byType(AppSegmentedTab);
      await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
      await tester.pumpAndSettle();
      // 直接展开该分区的表单，再通过实际确认按钮提交。
      final addButton = find.byIcon(Icons.add_rounded);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      final form = tester.widget<AddForm>(find.byType(AddForm));
      form.amountController.text = '123';
      form.descController.text = '新增$label记录';
      await tester.tap(find.text('确认添加'));
      await advanceIo();
      await tester.pumpAndSettle();

      expect(tester.widget<AppSegmentedTab>(tabs).selectedIndex, index);
      expect(find.text('新增$label记录'), findsOneWidget);
      await tester.runAsync(() async {
        final rows = await db.query(
          index == 2
              ? 'mod_period_book_large_additions'
              : 'mod_period_book_large_expenses',
          where: '${index == 2 ? 'reason' : 'description'} = ?',
          whereArgs: ['新增$label记录'],
        );
        expect(rows, hasLength(1));
        expect(rows.single['amount'], 123);
        if (index != 2) {
          expect((rows.single['category'] as String).startsWith('other:'),
              index == 1);
        }
      });
      expect(tester.takeException(), isNull);
    });
  }
}

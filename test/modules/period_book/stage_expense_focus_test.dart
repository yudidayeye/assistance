import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_assistant/modules/period_book/pages/stage_edit_page.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_section_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'period_detail_delete_test.dart' show fixture;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  for (final other in [false, true]) {
    testWidgets('${other ? "其他" : "个人"}支出从历史跳转后自动定位并短暂高亮', (tester) async {
      late Database db;
      late int targetId;
      await tester.runAsync(() async {
        db = await fixture();
        for (var i = 0; i < 25; i++) {
          await db.insert('mod_period_book_expenses', {
            'stage_id': 1,
            'category': other ? 'other:生活' : '娱乐',
            'description': '前面记录$i',
            'amount': 10,
            'sort_order': i + 1,
            'created_at': '2026-10-01'
          });
        }
        targetId = await db.insert('mod_period_book_expenses', {
          'stage_id': 1,
          'category': other ? 'other:生活' : '娱乐',
          'description': other ? '电费' : '电影八仙',
          'amount': 10,
          'sort_order': 30,
          'created_at': '2026-10-01'
        });
      });
      addTearDown(db.close);
      final router =
          GoRouter(initialLocation: '/stage?expenseId=$targetId', routes: [
        GoRoute(
            path: '/stage',
            builder: (_, state) => StageEditPage(
                stageId: 1,
                expenseId: int.tryParse(
                    state.uri.queryParameters['expenseId'] ?? ''))),
      ]);
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 450));
      final card =
          tester.widget<ExpenseSectionCard>(find.byType(ExpenseSectionCard));
      expect(card.isOther, other);
      expect(card.focusExpenseId, '$targetId');
      final target = find.byKey(ValueKey('expense_$targetId'));
      expect(
          tester.getRect(target).overlaps(const Rect.fromLTWH(0, 0, 360, 800)),
          isTrue);
      var sawHighlight = false;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        sawHighlight |= tester
                .widget<ExpenseSectionCard>(find.byType(ExpenseSectionCard))
                .highlightedExpenseId ==
            '$targetId';
      }
      expect(sawHighlight, isTrue);
      // 计时器推进后高亮恢复，定位不会修改记录或持续闪烁。
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ExpenseSectionCard>(find.byType(ExpenseSectionCard))
              .highlightedExpenseId,
          isNull);
      await tester.runAsync(() async => expect(
          (await db.query('mod_period_book_expenses',
                  where: 'id = ?', whereArgs: [targetId]))
              .single['description'],
          other ? '电费' : '电影八仙'));
      expect(tester.takeException(), isNull);
    });
  }
}

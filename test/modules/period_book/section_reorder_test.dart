import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/modules/period_book/services/entry_ordering.dart';
import 'package:my_assistant/modules/period_book/widgets/addition_section_card.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_section_card.dart';

void main() {
  for (final isAddition in [true, false]) {
    testWidgets('${isAddition ? "追加" : "支出"}列表向下及向上拖动使用正确目标索引', (tester) async {
      var ids = ['a', 'b', 'c'];
      final moves = <(int, int)>[];
      await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider.instance.themeData,
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          void reorder(int oldIndex, int newIndex) {
            moves.add((oldIndex, newIndex));
            setState(() => ids = applyReorder(ids, oldIndex, newIndex));
          }

          return SingleChildScrollView(
              child: isAddition
                  ? AdditionSectionCard(
                      title: '追加',
                      emptyText: '空',
                      color: Colors.blue,
                      additions: ids
                          .map((id) =>
                              AdditionItemData(id: id, reason: id, amount: 10))
                          .toList(),
                      onReorder: reorder,
                      leading: const Icon(Icons.drag_handle),
                      showAddButton: false,
                    )
                  : ExpenseSectionCard(
                      title: '支出',
                      emptyText: '空',
                      color: Colors.blue,
                      expenses: ids
                          .map((id) => ExpenseItemData(
                              id: id,
                              category: '工作',
                              description: id,
                              amount: 10))
                          .toList(),
                      onReorder: reorder,
                      leading: const Icon(Icons.drag_handle),
                      showAddButton: false,
                    ));
        })),
      ));
      await tester.pumpAndSettle();
      Future<void> drag(int from, int to) async {
        final handles = find.byType(ReorderableDragStartListener);
        final start = tester.getCenter(handles.at(from));
        final target =
            tester.getCenter(handles.at(to)) + Offset(0, to > from ? 60 : -60);
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
        for (var step = 1; step <= 8; step++) {
          await gesture.moveTo(Offset.lerp(start, target, step / 8)!);
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(0, 2);
      expect(moves, [(0, 3)]);
      expect(ids, ['b', 'c', 'a']);
      await drag(2, 0);
      expect(moves, [(0, 3), (2, 0)]);
      expect(ids, ['a', 'b', 'c']);
      expect(tester.takeException(), isNull);
    });
  }
}

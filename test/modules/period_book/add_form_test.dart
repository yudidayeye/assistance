import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/period_book/widgets/add_form.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_category_helper.dart';

void main() {
  testWidgets('窄屏分类保持单行图标，今天可选择和清除且提交保留日期', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final amount = TextEditingController();
    final description = TextEditingController();
    addTearDown(amount.dispose);
    addTearDown(description.dispose);
    DateTime? selectedDate;
    DateTime? submittedDate;
    var category = '生活';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AddForm(
            amountLabel: '金额',
            descLabel: '描述',
            amountHint: '',
            descHint: '',
            amountController: amount,
            descController: description,
            categories: ExpenseCategoryHelper.expenseCategories,
            selectedCategory: category,
            onCategoryChanged: (value) => setState(() => category = value),
            selectedDate: selectedDate,
            onDateChanged: (value) => setState(() => selectedDate = value),
            onConfirm: () => submittedDate = selectedDate,
          )),
    ))));
    expect(selectedDate, isNull);
    expect(find.text('选择日期'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('清除日期').hitTestable(), findsNothing);
    final dateBox = find.byKey(const ValueKey('entry-date-box'));
    final initialDateBoxRect = tester.getRect(dateBox);
    final label = tester.renderObject<RenderParagraph>(find.text('时间（可选）'));
    expect(label.didExceedMaxLines, isFalse);
    expect(initialDateBoxRect.width, 140);
    expect(find.text('工作'), findsNothing);
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(5));
    final y = tester.getTopLeft(chips.first).dy;
    for (var i = 0; i < 5; i++) {
      expect(tester.getTopLeft(chips.at(i)).dy, y);
    }
    await tester.tap(find.byIcon(Icons.business_center_outlined));
    await tester.pump();
    expect(category, '工作');
    await tester.tap(find.text('今天'));
    await tester.pump();
    final now = DateTime.now();
    expect(selectedDate, DateTime(now.year, now.month, now.day));
    expect(tester.getRect(dateBox), initialDateBoxRect);
    expect(find.byTooltip('清除日期').hitTestable(), findsOneWidget);
    await tester.tap(find.text('确认添加'));
    expect(submittedDate, selectedDate);
    tester
        .widget<AddForm>(find.byType(AddForm))
        .onDateChanged!(DateTime(now.year - 1, 12, 31));
    await tester.pump();
    expect(find.text('${now.year - 1}.12.31'), findsOneWidget);
    expect(tester.getRect(dateBox), initialDateBoxRect);
    await tester.tap(find.byTooltip('清除日期'));
    await tester.pump();
    expect(selectedDate, isNull);
    expect(find.text('选择日期'), findsOneWidget);
    expect(find.byTooltip('清除日期').hitTestable(), findsNothing);
    expect(tester.getRect(dateBox), initialDateBoxRect);
    expect(tester.takeException(), isNull);
  });
}

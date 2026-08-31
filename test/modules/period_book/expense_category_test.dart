import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/period_book/models/expense_record.dart';
import 'package:my_assistant/modules/period_book/models/large_expense_record.dart';
import 'package:my_assistant/modules/period_book/widgets/add_form.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_category_helper.dart';

void main() {
  group('ExpenseRecord.isOther', () {
    ExpenseRecord buildRecord(String category) {
      return ExpenseRecord(
        stageId: 1,
        category: category,
        amount: 10,
        description: '测试支出',
        createdAt: '2026-08-31T00:00:00.000',
      );
    }

    test('兼容旧版其他支出分类', () {
      expect(buildRecord('other').isOther, isTrue);
    });

    test('识别带具体分类的其他支出', () {
      expect(buildRecord('other:购物').isOther, isTrue);
    });

    test('个人支出不属于其他支出', () {
      expect(buildRecord('购物').isOther, isFalse);
    });
  });

  group('LargeExpenseRecord.isOther', () {
    LargeExpenseRecord buildLargeRecord(String category) {
      return LargeExpenseRecord(
        periodId: 1,
        category: category,
        amount: 10,
        description: '测试大额支出',
        createdAt: '2026-08-31T00:00:00.000',
      );
    }

    test('兼容旧版其他支出分类', () {
      expect(buildLargeRecord('other').isOther, isTrue);
    });

    test('识别带具体分类的其他支出', () {
      expect(buildLargeRecord('other:购物').isOther, isTrue);
    });

    test('个人支出不属于其他支出', () {
      expect(buildLargeRecord('购物').isOther, isFalse);
    });

    test('旧版购物分类不属于其他支出', () {
      expect(buildLargeRecord('shopping').isOther, isFalse);
    });
  });

  group('ExpenseCategoryHelper', () {
    test('显示其他支出的具体分类', () {
      expect(
        ExpenseCategoryHelper.mapCategoryForDisplay('other:购物'),
        '购物',
      );
    });

    test('兼容显示旧版其他支出', () {
      expect(
        ExpenseCategoryHelper.mapCategoryForDisplay('other'),
        '其他',
      );
    });

    test('兼容显示旧版购物分类', () {
      expect(
        ExpenseCategoryHelper.mapCategoryForDisplay('shopping'),
        '购物',
      );
    });

    test('生成其他支出的兼容分类值', () {
      expect(
        ExpenseCategoryHelper.toOtherCategory('娱乐'),
        'other:娱乐',
      );
    });

    test('识别带具体分类的其他支出值', () {
      expect(
        ExpenseCategoryHelper.isOtherCategory('other:生活'),
        isTrue,
      );
    });

    test('识别旧版其他支出值', () {
      expect(
        ExpenseCategoryHelper.isOtherCategory('other'),
        isTrue,
      );
    });

    test('普通分类转换为数据库值', () {
      expect(
        ExpenseCategoryHelper.categoryToDbValue('生活'),
        '生活',
      );
    });
  });

  testWidgets('AddForm 展示分类并回调选中项', (tester) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    addTearDown(amountController.dispose);
    addTearDown(descController.dispose);
    String? changedCategory;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddForm(
            amountLabel: '金额',
            descLabel: '描述',
            amountHint: '请输入金额',
            descHint: '请输入描述',
            amountController: amountController,
            descController: descController,
            categories: const ['生活', '购物'],
            selectedCategory: '生活',
            onCategoryChanged: (category) => changedCategory = category,
          ),
        ),
      ),
    );

    expect(find.text('分类'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);

    await tester.tap(find.text('购物'));
    await tester.pump();

    expect(changedCategory, '购物');
  });
}

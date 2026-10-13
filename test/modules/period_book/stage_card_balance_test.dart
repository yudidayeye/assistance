import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/modules/period_book/models/stage_record.dart';
import 'package:my_assistant/modules/period_book/services/period_book_service.dart';
import 'package:my_assistant/modules/period_book/widgets/stage_card.dart';

void main() {
  Future<void> showCard(WidgetTester tester,
      {required double principal,
      required double shopping,
      required double other,
      required double balance,
      double additions = 0}) async {
    final living = principal + additions - shopping - other - balance;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeProvider.instance.themeData,
      home: Scaffold(
        body: StageCard(
          stage: StageRecord(
            periodId: 1,
            startDate: '2000-01-01',
            endDate: '2000-01-10',
            balance: balance,
            sortOrder: 0,
            createdAt: '2000-01-01',
            updatedAt: '2000-01-01',
          ),
          stageCalc: StageCalculations(
            baseAmount: principal + additions,
            additionsTotal: additions,
            shoppingTotal: shopping,
            otherTotal: other,
            balance: balance,
            livingTotal: living,
            livingDailyAvg: living / 10,
            totalDays: 10,
          ),
          previousBalance: principal,
          additions: const [],
          expandExpenseByDefault: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('余额等于本金加追加减支出时不提示', (tester) async {
    await showCard(tester,
        principal: 100, additions: 10, shopping: 20, other: 30, balance: 60);
    expect(find.text('!'), findsNothing);
  });

  testWidgets('小数支出产生浮点误差时相等余额不提示', (tester) async {
    await showCard(tester,
        principal: 0.3, shopping: 0.1, other: 0.2, balance: 0);
    expect(find.text('!'), findsNothing);
  });

  testWidgets('余额少于计算值时不提示', (tester) async {
    await showCard(tester,
        principal: 100, shopping: 20, other: 30, balance: 49.99);
    expect(find.text('!'), findsNothing);
  });

  testWidgets('余额真正超过计算值一分钱时仍提示', (tester) async {
    await showCard(tester,
        principal: 100, shopping: 20, other: 30, balance: 50.01);
    expect(find.text('!'), findsWidgets);
  });
}

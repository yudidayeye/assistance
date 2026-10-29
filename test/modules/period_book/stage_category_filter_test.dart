import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/theme/theme_provider.dart';
import 'package:my_assistant/modules/period_book/models/stage_record.dart';
import 'package:my_assistant/modules/period_book/pages/stage_edit_page.dart';
import 'package:my_assistant/modules/period_book/services/period_book_service.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_section_card.dart';
import 'package:my_assistant/modules/period_book/widgets/category_filter_label.dart';
import 'package:my_assistant/modules/period_book/widgets/expense_category_breakdown.dart';
import 'package:my_assistant/modules/period_book/widgets/report_card.dart';
import 'package:my_assistant/modules/period_book/widgets/records_tab_card.dart';
import 'package:my_assistant/modules/period_book/widgets/stage_card.dart';
import 'package:my_assistant/shared/widgets/app_segmented_tab.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'period_detail_delete_test.dart' show fixture;

const personal = {'生活': 50.0, '购物': 40.0, '工作': 30.0, '娱乐': 20.0, '大餐': 10.0};

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget card(
          {bool detailed = false,
          String? selected,
          ValueChanged<String?>? onSelected}) =>
      StageCard(
        stage: const StageRecord(
            id: 1,
            periodId: 1,
            startDate: '2000-01-01',
            endDate: '2000-01-10',
            balance: 750,
            sortOrder: 0,
            createdAt: '2000-01-01',
            updatedAt: '2000-01-01'),
        stageCalc: const StageCalculations(
            baseAmount: 1000,
            additionsTotal: 0,
            shoppingTotal: 150,
            otherTotal: 65,
            balance: 750,
            livingTotal: 35,
            livingDailyAvg: 3.5,
            totalDays: 10),
        previousBalance: 1000,
        additions: const [],
        expandExpenseByDefault: true,
        personalExpenseBreakdown: const {...personal, '杂项': 35},
        showPersonalCategories: detailed,
        selectedBreakdownCategory: selected,
        onBreakdownCategorySelected: onSelected,
      );

  testWidgets('周期卡片默认仍显示个人消费汇总', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card())));
    await tester.pumpAndSettle();
    expect(find.text('个人消费'), findsOneWidget);
    expect(find.text('其他消费'), findsOneWidget);
    expect(find.text('漏记杂项'), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-category-生活')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('阶段详情与历史记录复用图表，分类排序、金额和选中样式完全一致', (tester) async {
    tester.view.physicalSize = const Size(392, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<(double, Color, double)>? historySections;
    for (final history in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(history),
        theme: ThemeProvider.instance.themeData,
        home: Scaffold(
            body: history
                ? const ReportCard(
                    monthlyData: [],
                    stageData: [],
                    expenseTypeData: {...personal, '其他': 65, '杂项': 35},
                    selectedCategory: '购物')
                : card(detailed: true, selected: '购物')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseCategoryBreakdown), findsOneWidget);
      final order = ['其他', '生活', '购物', '杂项', '工作', '娱乐', '大餐'];
      final positions = [
        for (final category in order)
          tester
              .getTopLeft(find.byKey(ValueKey('expense-category-$category')))
              .dy
      ];
      expect(positions, orderedEquals([...positions]..sort()));
      final shopping = find.byKey(const ValueKey('expense-category-购物'));
      expect(find.descendant(of: shopping, matching: find.text('购物')),
          findsOneWidget);
      expect(find.descendant(of: shopping, matching: find.text('16%')),
          findsOneWidget);
      expect(find.descendant(of: shopping, matching: find.text('¥40')),
          findsOneWidget);
      expect(find.text('其他消费'), findsNothing);
      expect(find.text('漏记杂项'), findsNothing);
      expect(find.textContaining('/天 ×'), findsNothing);
      final sections = tester
          .widget<PieChart>(find.byType(PieChart))
          .data
          .sections
          .map((section) => (section.value, section.color, section.radius))
          .toList();
      if (history) {
        historySections = sections;
      } else {
        expect(sections, historySections);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('与历史记录一致，不展示零金额图例，也不允许选中零金额分类', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpenseCategoryBreakdown(
      data: const {'购物': 67.15, '生活': 64.43, '其他': 0, '杂项': 0},
      onCategorySelected: (value) => selected = value,
    ))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense-category-其他')), findsNothing);
    expect(find.byKey(const ValueKey('expense-category-杂项')), findsNothing);
    expect(tester.widget<PieChart>(find.byType(PieChart)).data.sections,
        hasLength(2));
    await tester.tap(find.byKey(const ValueKey('expense-category-购物')));
    expect(selected, '购物');
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类图例适配窄屏大字，扇区和图例可选中、切换及取消', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final config in [(320.0, 1.5), (392.0, 1.0), (800.0, 1.0)]) {
      tester.view.physicalSize = Size(config.$1, 1200);
      String? selected;
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(config),
        theme: ThemeProvider.instance.themeData,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(config.$2)),
            child: child!),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => card(
                    detailed: true,
                    selected: selected,
                    onSelected: (value) => setState(() => selected = value)))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('个人消费'), findsNothing);
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections, hasLength(7));
      expect(pie.data.sections.fold(0.0, (sum, section) => sum + section.value),
          250);
      await tester.tap(find.byKey(const ValueKey('expense-category-生活')));
      await tester.pumpAndSettle();
      expect(selected, '生活');
      await tester.tap(find.byKey(const ValueKey('expense-category-购物')));
      await tester.pumpAndSettle();
      expect(selected, '购物');
      await tester.tap(find.byKey(const ValueKey('expense-category-购物')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      // 第一个扇区是金额最高的「其他」：按角度点击真实图表。
      final center = tester.getRect(find.byType(PieChart)).center;
      const angle = -math.pi / 2 + 65 / 250 * math.pi;
      await tester
          .tapAt(center + Offset(math.cos(angle), math.sin(angle)) * 40);
      await tester.pumpAndSettle();
      expect(selected, '其他');
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('阶段详情按具体分类筛选，其他支出切Tab，杂项说明和清除筛选正常', (tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await fixture();
      await db.delete('mod_period_book_expenses',
          where: 'stage_id = ?', whereArgs: [1]);
      await db.delete('mod_period_book_additions',
          where: 'stage_id = ?', whereArgs: [1]);
      await db.update('mod_period_book_stages',
          {'balance': 750, 'current_date': '2026-10-10'},
          where: 'id = ?', whereArgs: [1]);
      for (final entry
          in {...personal, 'other:生活': 60.0, 'other': 5.0}.entries) {
        await db.insert('mod_period_book_expenses', {
          'stage_id': 1,
          'category': entry.key == '购物' ? 'shopping' : entry.key,
          'description': '${entry.key}记录',
          'amount': entry.value,
          'sort_order': 0,
          'created_at': '2026-10-01',
        });
      }
    });
    addTearDown(db.close);
    tester.view.physicalSize = const Size(392, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeProvider.instance.themeData,
      home: const StageEditPage(stageId: 1),
    ));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    ExpenseSectionCard section() =>
        tester.widget<ExpenseSectionCard>(find.byType(ExpenseSectionCard));
    int? tab() => tester
        .widget<RecordsTabCard>(find.byType(RecordsTabCard))
        .selectedIndex;
    Future<void> select(String category) async {
      final target = find.byKey(ValueKey('expense-category-$category'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    expect(section().expenses, hasLength(5));
    for (final category in personal.keys) {
      await select(category);
      expect(tab(), 0);
      expect(section().expenses.single.description, '$category记录');
      expect(section().onReorder, isNull);
      expect(
          tester
              .widget<StageCard>(find.byType(StageCard))
              .selectedBreakdownCategory,
          category);
      await select(category);
      expect(section().expenses, hasLength(5));
      expect(section().onReorder, isNotNull);
    }
    await select('其他');
    expect(tab(), 1);
    expect(section().expenses, hasLength(2));
    expect(section().isOther, isTrue);
    await tester.tap(find.byTooltip('清除分类筛选'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<StageCard>(find.byType(StageCard))
            .selectedBreakdownCategory,
        isNull);
    expect(tab(), 1);
    await select('杂项');
    expect(tab(), 0);
    expect(find.byType(CategoryFilterLabel), findsOneWidget);
    expect(find.text('筛选：杂项'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(section().expenses, isEmpty);
    expect(find.text('漏记杂项由阶段余额倒推，没有对应支出条目'), findsOneWidget);
    await tester.tap(find.byTooltip('清除分类筛选'));
    await tester.pumpAndSettle();
    expect(section().expenses, hasLength(5));
    await select('生活');
    await tester.tap(find.descendant(
        of: find.byType(AppSegmentedTab), matching: find.text('其他支出')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<StageCard>(find.byType(StageCard))
            .selectedBreakdownCategory,
        isNull);
    expect(section().expenses, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

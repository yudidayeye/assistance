import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/modules/period_book/models/expense_record.dart';
import 'package:my_assistant/modules/period_book/models/large_expense_record.dart';
import 'package:my_assistant/modules/period_book/models/period_record.dart';
import 'package:my_assistant/modules/period_book/models/stage_record.dart';
import 'package:my_assistant/modules/period_book/services/period_book_service.dart';
import 'package:my_assistant/modules/period_book/widgets/category_filter_helper.dart';

/// 覆盖契约 C2-1..C2-9（`specs/001-report-pie-filter/contracts/ui-contract.md`）。
///
/// 本文件不触碰 `DatabaseService`：`CategoryFilterHelper` 是纯函数层，
/// 若它偷偷发起数据库查询，这些用例会在未初始化 sqflite 的测试环境里直接抛错
/// ——这正是 C2-8 的可执行化断言。
void main() {
  PeriodRecord buildPeriod(int id) {
    return PeriodRecord(
      id: id,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
      baseAmount: 1000,
      createdAt: '2026-08-01T00:00:00.000',
      updatedAt: '2026-08-01T00:00:00.000',
    );
  }

  ExpenseRecord buildExpense({
    required int stageId,
    required String category,
    required double amount,
    String description = '支出',
    int sortOrder = 0,
  }) {
    return ExpenseRecord(
      stageId: stageId,
      category: category,
      amount: amount,
      description: description,
      sortOrder: sortOrder,
      createdAt: '2026-08-01T00:00:00.000',
    );
  }

  LargeExpenseRecord buildLargeExpense({
    required String category,
    required double amount,
    String description = '大额支出',
    int sortOrder = 0,
  }) {
    return LargeExpenseRecord(
      periodId: 1,
      category: category,
      amount: amount,
      description: description,
      sortOrder: sortOrder,
      createdAt: '2026-08-01T00:00:00.000',
    );
  }

  StageRecord buildStage(int id, {int periodId = 1}) {
    return StageRecord(
      id: id,
      periodId: periodId,
      startDate: '2026-08-01',
      endDate: '2026-08-15',
      sortOrder: 0,
      createdAt: '2026-08-01T00:00:00.000',
      updatedAt: '2026-08-01T00:00:00.000',
    );
  }

  StageCalculations buildStageCalc({double livingTotal = 0}) {
    return StageCalculations(
      baseAmount: 0,
      additionsTotal: 0,
      shoppingTotal: 0,
      otherTotal: 0,
      balance: null,
      livingTotal: livingTotal,
      livingDailyAvg: null,
      totalDays: 15,
    );
  }

  PeriodCalculations buildCalc(List<StageCalculations> stages) {
    return PeriodCalculations(
      totalBase: 0,
      shoppingTotal: 0,
      otherTotal: 0,
      balance: null,
      livingTotal: null,
      livingDailyAvg: null,
      totalDays: 30,
      stages: stages,
    );
  }

  List<PeriodCategorySummary> run({
    required String categoryName,
    List<PeriodRecord>? periods,
    Map<int, List<ExpenseRecord>>? expenseMap,
    Map<int, List<LargeExpenseRecord>>? largeExpenseMap,
    Map<int, List<StageRecord>>? stagesMap,
    Map<int, PeriodCalculations>? calcMap,
    int? selectedStage,
    bool includeDaily = true,
    bool includeLarge = false,
  }) {
    return CategoryFilterHelper.buildSummaries(
      categoryName: categoryName,
      periods: periods ?? [buildPeriod(1)],
      expenseMap: expenseMap ?? const {},
      largeExpenseMap: largeExpenseMap ?? const {},
      stagesMap: stagesMap ?? const {},
      calcMap: calcMap ?? const {},
      selectedStage: selectedStage,
      includeDaily: includeDaily,
      includeLarge: includeLarge,
    );
  }

  group('resolveCategoryName 归类顺序', () {
    test('other:购物 归入「其他」，不混入「购物」', () {
      expect(
        CategoryFilterHelper.resolveCategoryName(
          isOther: true,
          rawCategory: 'other:购物',
        ),
        '其他',
      );
    });

    test('旧版 other 同样归入「其他」', () {
      expect(
        CategoryFilterHelper.resolveCategoryName(
          isOther: true,
          rawCategory: 'other',
        ),
        '其他',
      );
    });

    test('非其他记录走常规映射', () {
      expect(
        CategoryFilterHelper.resolveCategoryName(
          isOther: false,
          rawCategory: 'shopping',
        ),
        '购物',
      );
    });

    test('残值伪分类名为「杂项」', () {
      expect(CategoryFilterHelper.residualOnlyCategory, '杂项');
    });
  });

  group('C2-1 无该分类支出的周期仍产出对象', () {
    test('小计为零、明细为空，但对象存在', () {
      final summaries = run(
        categoryName: '购物',
        periods: [buildPeriod(1), buildPeriod(2)],
        expenseMap: {
          1: [buildExpense(stageId: 1, category: '购物', amount: 320)],
          2: const [],
        },
      );

      expect(summaries.length, 2);
      expect(summaries[0].dailySubtotal, 320);
      expect(summaries[1].periodId, 2);
      expect(summaries[1].dailySubtotal, 0);
      expect(summaries[1].dailyItems, isEmpty);
      expect(summaries[1].hasAnyAmount, isFalse);
    });
  });

  group('C2-2 分类归属', () {
    test('other:购物 计入「其他」而不计入「购物」', () {
      final expenseMap = {
        1: [
          buildExpense(stageId: 1, category: 'other:购物', amount: 50),
          buildExpense(stageId: 1, category: '购物', amount: 100),
        ],
      };

      final other = run(categoryName: '其他', expenseMap: expenseMap).single;
      final shopping = run(categoryName: '购物', expenseMap: expenseMap).single;

      expect(other.dailySubtotal, 50);
      expect(other.dailyItems.length, 1);
      expect(shopping.dailySubtotal, 100);
      expect(shopping.dailyItems.length, 1);
    });

    test('大额侧同样按 isOther 归类', () {
      final largeExpenseMap = {
        1: [
          buildLargeExpense(category: 'other:生活', amount: 800),
          buildLargeExpense(category: '生活', amount: 200),
        ],
      };

      final other = run(
              categoryName: '其他',
              largeExpenseMap: largeExpenseMap,
              includeLarge: true)
          .single;
      final living = run(
              categoryName: '生活',
              largeExpenseMap: largeExpenseMap,
              includeLarge: true)
          .single;

      expect(other.largeSubtotal, 800);
      expect(living.largeSubtotal, 200);
    });
  });

  group('C2-3「杂项」只出小计', () {
    test('isResidualOnly 为真、明细恒空、小计为各阶段残值之和', () {
      final summaries = run(
        categoryName: CategoryFilterHelper.residualOnlyCategory,
        expenseMap: {
          1: [buildExpense(stageId: 1, category: '购物', amount: 320)],
        },
        calcMap: {
          1: buildCalc([
            buildStageCalc(livingTotal: 120),
            buildStageCalc(livingTotal: 80)
          ]),
        },
      );

      final summary = summaries.single;
      expect(summary.isResidualOnly, isTrue);
      expect(summary.dailySubtotal, 200);
      expect(summary.dailyItems, isEmpty);
      expect(summary.totalCount, 0);
      expect(summary.isExpandable, isFalse);
    });

    test('大额视图（includeDaily 为 false）下不产生残值分支', () {
      final summary = run(
        categoryName: CategoryFilterHelper.residualOnlyCategory,
        calcMap: {
          1: buildCalc([buildStageCalc(livingTotal: 120)]),
        },
        includeDaily: false,
        includeLarge: true,
      ).single;

      expect(summary.isResidualOnly, isFalse);
      expect(summary.dailySubtotal, 0);
    });
  });

  group('C2-4 单侧视图的另一侧恒为零', () {
    test('仅日常时大额侧小计为零、明细为空', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: {
          1: [buildExpense(stageId: 1, category: '购物', amount: 100)],
        },
        largeExpenseMap: {
          1: [buildLargeExpense(category: '购物', amount: 500)],
        },
        includeLarge: false,
      ).single;

      expect(summary.dailySubtotal, 100);
      expect(summary.largeSubtotal, 0);
      expect(summary.largeItems, isEmpty);
    });

    test('仅大额时日常侧小计为零、明细为空', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: {
          1: [buildExpense(stageId: 1, category: '购物', amount: 100)],
        },
        largeExpenseMap: {
          1: [buildLargeExpense(category: '购物', amount: 500)],
        },
        includeDaily: false,
        includeLarge: true,
      ).single;

      expect(summary.dailySubtotal, 0);
      expect(summary.dailyItems, isEmpty);
      expect(summary.largeSubtotal, 500);
    });
  });

  group('C2-5 / C2-9 合计取序与计数', () {
    List<PeriodCategorySummary> buildMixed() => run(
          categoryName: '购物',
          expenseMap: {
            1: [
              buildExpense(
                  stageId: 1, category: '购物', amount: 10, description: '日常1'),
              buildExpense(
                  stageId: 1, category: '购物', amount: 20, description: '日常2'),
            ],
          },
          largeExpenseMap: {
            1: [
              buildLargeExpense(category: '购物', amount: 30, description: '大额1'),
              buildLargeExpense(category: '购物', amount: 40, description: '大额2'),
              buildLargeExpense(category: '购物', amount: 50, description: '大额3'),
            ],
          },
          includeDaily: true,
          includeLarge: true,
        );

    test('totalCount 等于两侧明细条数之和', () {
      final summary = buildMixed().single;
      expect(summary.totalCount, 5);
      expect(summary.totalCount,
          summary.dailyItems.length + summary.largeItems.length);
      expect(summary.dailySubtotal, 30);
      expect(summary.largeSubtotal, 120);
    });

    test('折叠时返回前 3 条，先日常后大额、跨组不混排', () {
      final summary = buildMixed().single;
      final visible =
          CategoryFilterHelper.visibleItems(summary, expanded: false);

      expect(visible.length, 3);
      expect(
        visible.map((item) => item.description).toList(),
        ['日常1', '日常2', '大额1'],
      );
    });

    test('展开后返回全部', () {
      final summary = buildMixed().single;
      final visible =
          CategoryFilterHelper.visibleItems(summary, expanded: true);

      expect(visible.length, 5);
      expect(visible.last.description, '大额3');
    });

    test('条目不超过 3 条时 isExpandable 为假', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: {
          1: [buildExpense(stageId: 1, category: '购物', amount: 10)],
        },
      ).single;

      expect(summary.isExpandable, isFalse);
      expect(CategoryFilterHelper.visibleItems(summary, expanded: false).length,
          1);
    });
  });

  group('C2-6 阶段收敛', () {
    Map<int, List<ExpenseRecord>> twoStageExpenses() => {
          1: [
            buildExpense(
                stageId: 11, category: '购物', amount: 100, description: '一阶段'),
            buildExpense(
                stageId: 12, category: '购物', amount: 200, description: '二阶段'),
          ],
        };

    test('选中阶段时日常侧只统计该阶段', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: twoStageExpenses(),
        stagesMap: {
          1: [buildStage(11), buildStage(12)],
        },
        selectedStage: 2,
      ).single;

      expect(summary.dailySubtotal, 200);
      expect(summary.dailyItems.single.description, '二阶段');
    });

    test('不选阶段时日常侧统计整个周期', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: twoStageExpenses(),
        stagesMap: {
          1: [buildStage(11), buildStage(12)],
        },
      ).single;

      expect(summary.dailySubtotal, 300);
      expect(summary.dailyItems.length, 2);
    });

    test('大额侧不按阶段收敛', () {
      final summary = run(
        categoryName: '购物',
        largeExpenseMap: {
          1: [buildLargeExpense(category: '购物', amount: 500)],
        },
        stagesMap: {
          1: [buildStage(11), buildStage(12)],
        },
        selectedStage: 2,
        includeDaily: true,
        includeLarge: true,
      ).single;

      expect(summary.largeSubtotal, 500);
    });

    test('该周期没有所选阶段时不贡献日常记录', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: twoStageExpenses(),
        stagesMap: {
          1: [buildStage(11)],
        },
        selectedStage: 3,
      ).single;

      expect(summary.dailySubtotal, 0);
      expect(summary.dailyItems, isEmpty);
    });

    test('杂项在选中阶段时取该阶段残值', () {
      final summary = run(
        categoryName: CategoryFilterHelper.residualOnlyCategory,
        stagesMap: {
          1: [buildStage(11), buildStage(12)],
        },
        calcMap: {
          1: buildCalc([
            buildStageCalc(livingTotal: 120),
            buildStageCalc(livingTotal: 80)
          ]),
        },
        selectedStage: 1,
      ).single;

      expect(summary.dailySubtotal, 120);
    });
  });

  group('C2-7 组内沿用既有顺序', () {
    test('日常明细保持传入顺序，不按金额重排', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: {
          1: [
            buildExpense(
                stageId: 1,
                category: '购物',
                amount: 300,
                description: '先',
                sortOrder: 0),
            buildExpense(
                stageId: 1,
                category: '购物',
                amount: 10,
                description: '后',
                sortOrder: 1),
          ],
        },
      ).single;

      expect(
        summary.dailyItems.map((item) => item.description).toList(),
        ['先', '后'],
      );
    });
  });

  group('明细项与空描述占位', () {
    test('FilterItem 只携带描述与金额，不出现分类或子类标签', () {
      final summary = run(
        categoryName: '其他',
        expenseMap: {
          1: [
            buildExpense(
              stageId: 1,
              category: 'other:购物',
              amount: 50,
              description: '买了本书',
            ),
          ],
        },
      ).single;

      final item = summary.dailyItems.single;
      expect(item.description, '买了本书');
      expect(item.amount, 50);
      expect(item.toString().contains('其他'), isFalse);
      expect(item.toString().contains('购物'), isFalse);
    });

    test('描述为空时以分类显示名占位', () {
      final summary = run(
        categoryName: '购物',
        expenseMap: {
          1: [
            buildExpense(
                stageId: 1, category: '购物', amount: 10, description: '   ')
          ],
        },
      ).single;

      expect(summary.dailyItems.single.description, '购物');
    });

    test('空描述的其他消费以「其他」占位，不泄漏子类名', () {
      final summary = run(
        categoryName: '其他',
        expenseMap: {
          1: [
            buildExpense(
                stageId: 1, category: 'other:购物', amount: 10, description: '')
          ],
        },
      ).single;

      expect(summary.dailyItems.single.description, '其他');
    });
  });

  group('周期无 id 时跳过', () {
    test('id 为空的周期不产出对象', () {
      final summaries = run(
        categoryName: '购物',
        periods: [
          const PeriodRecord(
            startDate: '2026-08-01',
            endDate: '2026-08-31',
            baseAmount: 1000,
            createdAt: '2026-08-01T00:00:00.000',
            updatedAt: '2026-08-01T00:00:00.000',
          ),
        ],
      );

      expect(summaries, isEmpty);
    });
  });
}

import '../models/expense_record.dart';
import '../models/large_expense_record.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../services/period_book_service.dart';
import 'expense_category_helper.dart';

/// 明细项 —— 筛选生效后卡片内逐条列出的支出
///
/// 只携带描述与金额：分类名、子类名 MUST NOT 进入本模型（FR-023）。子类信息
/// （`other:购物` 中的「购物」）只保留在数据库里，因为子类名与普通分类同名时
/// （「其他·购物」对真正的「购物」），带上标签会让用户无法分辨这笔钱属于哪一边。
class FilterItem {
  final String description;
  final double amount;

  const FilterItem({required this.description, required this.amount});

  @override
  String toString() => 'FilterItem($description, $amount)';
}

/// 周期 × 分类汇总 —— 筛选生效后，列表中的每张卡片对应一个本对象
///
/// 三个视图共用此结构，由各自的展示层决定渲染哪一部分。
class PeriodCategorySummary {
  final int periodId;
  final String categoryName;

  /// 日常侧（[ExpenseRecord]）该分类小计
  final double dailySubtotal;

  /// 大额侧（[LargeExpenseRecord]）该分类小计
  final double largeSubtotal;

  /// 日常侧明细，已按既有展示顺序排好
  final List<FilterItem> dailyItems;

  /// 大额侧明细，已按既有展示顺序排好
  final List<FilterItem> largeItems;

  /// 仅「杂项」为 true：有小计、必然无明细（FR-022）
  final bool isResidualOnly;

  const PeriodCategorySummary({
    required this.periodId,
    required this.categoryName,
    this.dailySubtotal = 0,
    this.largeSubtotal = 0,
    this.dailyItems = const [],
    this.largeItems = const [],
    this.isResidualOnly = false,
  });

  /// 「查看全部 N 条」的 N（契约 C2-9）
  int get totalCount => dailyItems.length + largeItems.length;

  /// 两侧小计之和是否大于零 —— FR-016「范围变更后自动取消筛选」的判定口径
  bool get hasAnyAmount => dailySubtotal + largeSubtotal > 0;

  bool get isExpandable => totalCount > CategoryFilterHelper.maxCollapsedItems;

  @override
  String toString() => 'PeriodCategorySummary(period $periodId, $categoryName, '
      'daily $dailySubtotal/${dailyItems.length}, '
      'large $largeSubtotal/${largeItems.length})';
}

/// 纯函数聚合层 —— 按周期算出所选分类的小计与明细
///
/// 无 IO、无 `BuildContext`，只遍历调用方已载入内存的 Map，MUST NOT 发起任何
/// 数据库查询（research R10 / 契约 C2-8）。因此本类可直接 unit test。
class CategoryFilterHelper {
  CategoryFilterHelper._();

  /// 折叠态下每张卡片最多展示的明细条数（FR-011）
  static const int maxCollapsedItems = 3;

  /// 「其他消费」在数据库中的存储值（`other` 与 `other:<子类>` 共用此前缀）
  static const String otherCategoryDbValue = 'other';

  /// 倒推残值伪分类：不是数据库分类，没有任何记录与之对应（FR-022）
  static const String residualOnlyCategory = '杂项';

  /// 分类归属的唯一判定入口。
  ///
  /// 顺序是本特性的正确性核心：**先**判 `isOther`、**再**归一化。若颠倒，
  /// `other:购物` 会被 [ExpenseCategoryHelper.mapCategoryForDisplay] 剥掉前缀
  /// 而成「购物」，混入同名的普通分类扇区——这正是本特性要修的既有 bug
  /// （research R5 / 契约 C2-2）。
  ///
  /// 饼图取数（`AggPage._calculateStats` 中的四处）与本聚合层 MUST 调用同一个
  /// 方法，MUST NOT 各自内联一份 `isOther` 分支：多处实现必然漂移。
  static String resolveCategoryName({
    required bool isOther,
    required String rawCategory,
  }) {
    if (isOther) {
      // 取映射表的返回值，MUST NOT 硬编码「其他」字面量
      return ExpenseCategoryHelper.mapCategoryForDisplay(otherCategoryDbValue);
    }
    return ExpenseCategoryHelper.mapCategoryForDisplay(rawCategory);
  }

  /// 为每个入参周期产出一个汇总对象，包括无该分类支出的周期（小计 0、明细空）。
  ///
  /// [includeDaily] / [includeLarge] 决定统计哪一侧：日常视图只含日常，大额视图
  /// 只含大额，合计视图两者皆含（契约 C2-1 / C2-4）。
  static List<PeriodCategorySummary> buildSummaries({
    required String categoryName,
    required List<PeriodRecord> periods,
    required Map<int, List<ExpenseRecord>> expenseMap,
    required Map<int, List<LargeExpenseRecord>> largeExpenseMap,
    required Map<int, List<StageRecord>> stagesMap,
    required Map<int, PeriodCalculations> calcMap,
    required int? selectedStage,
    required bool includeDaily,
    required bool includeLarge,
  }) {
    final summaries = <PeriodCategorySummary>[];
    for (final period in periods) {
      final periodId = period.id;
      if (periodId == null) continue;

      final calc = calcMap[periodId];

      var dailySubtotal = 0.0;
      var dailyItems = <FilterItem>[];
      var isResidualOnly = false;

      if (includeDaily) {
        // 命中阶段收敛时，先按 stageId 收敛、再判分类（FR-016a / 契约 C2-6）。
        // 阶段选择只作用于日常侧：大额与合计视图的饼图不响应阶段，
        // 故卡片也不按阶段收敛。
        var stageReady = true;
        int? stageFilterId;
        if (selectedStage != null) {
          final stages = stagesMap[periodId] ?? const <StageRecord>[];
          final stageIndex = selectedStage - 1;
          if (stageIndex < 0 || stageIndex >= stages.length) {
            // 该周期没有这个阶段 —— 不贡献任何日常记录（与 agg.dart 既有口径一致）
            stageReady = false;
          } else {
            stageFilterId = stages[stageIndex].id;
          }
        }

        if (stageReady) {
          if (categoryName == residualOnlyCategory) {
            // 「杂项」没有底层记录，只出小计（FR-022 / 契约 C2-3）
            isResidualOnly = true;
            dailySubtotal = _residualSubtotal(calc, selectedStage);
          } else {
            for (final e in expenseMap[periodId] ?? const <ExpenseRecord>[]) {
              if (stageFilterId != null && e.stageId != stageFilterId) continue;
              final name = resolveCategoryName(
                isOther: e.isOther,
                rawCategory: e.category,
              );
              if (name != categoryName) continue;
              dailySubtotal += e.amount;
              dailyItems.add(FilterItem(
                description: _describe(e.description, categoryName),
                amount: e.amount,
              ));
            }
          }
        }
      }

      var largeSubtotal = 0.0;
      final largeItems = <FilterItem>[];
      if (includeLarge) {
        for (final e
            in largeExpenseMap[periodId] ?? const <LargeExpenseRecord>[]) {
          final name = resolveCategoryName(
            isOther: e.isOther,
            rawCategory: e.category,
          );
          if (name != categoryName) continue;
          largeSubtotal += e.amount;
          largeItems.add(FilterItem(
            description: _describe(e.description, categoryName),
            amount: e.amount,
          ));
        }
      }

      summaries.add(PeriodCategorySummary(
        periodId: periodId,
        categoryName: categoryName,
        dailySubtotal: dailySubtotal,
        largeSubtotal: largeSubtotal,
        dailyItems: dailyItems,
        largeItems: largeItems,
        isResidualOnly: isResidualOnly,
      ));
    }
    return summaries;
  }

  /// 卡片当前应展示的明细。
  ///
  /// [expanded] 为 false 时返回前 [maxCollapsedItems] 条（FR-011）。取序为
  /// **先日常组、再大额组**，跨组不混排（契约 C2-5）——因此「前 3 条」恰好等于
  /// 展开后列表的开头，不会产生认知落差。
  static List<FilterItem> visibleItems(
    PeriodCategorySummary summary, {
    required bool expanded,
  }) {
    final all = <FilterItem>[
      ...summary.dailyItems,
      ...summary.largeItems,
    ];
    if (expanded || all.length <= maxCollapsedItems) return all;
    return all.sublist(0, maxCollapsedItems);
  }

  /// 「杂项」的小计 —— 由倒推残值构成，无任何记录可列。
  ///
  /// 口径 MUST 与饼图逐字一致（`agg.dart` 中 livingTotal 的取法），否则
  /// SC-003「卡片小计之和 = 图例合计」不成立：先对全部阶段的 livingTotal 求和、
  /// 再判正负，而不是逐阶段过滤正值。
  static double _residualSubtotal(
    PeriodCalculations? calc,
    int? selectedStage,
  ) {
    if (calc == null) return 0;
    if (selectedStage != null) {
      // 选中阶段时，饼图取自该阶段的 livingTotal
      final stageIndex = selectedStage - 1;
      if (stageIndex < 0 || stageIndex >= calc.stages.length) return 0;
      final living = calc.stages[stageIndex].livingTotal ?? 0;
      return living > 0 ? living : 0;
    }
    final livingTotal =
        calc.stages.fold<double>(0, (sum, s) => sum + (s.livingTotal ?? 0));
    return livingTotal > 0 ? livingTotal : 0;
  }

  /// 无描述的记录以所属分类名占位，不渲染空文本（Edge Case「无描述的支出记录」）。
  static String _describe(String description, String categoryName) {
    return description.trim().isEmpty ? categoryName : description;
  }
}

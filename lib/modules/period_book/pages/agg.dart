import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../models/expense_record.dart';
import '../models/stage_record.dart';
import '../models/large_addition_record.dart';
import '../models/large_expense_record.dart';
import '../services/period_book_service.dart';
import '../widgets/category_filter_helper.dart';
import '../widgets/history_filter_bar.dart';
import '../widgets/report_card.dart';

/// 聚合历史记录页面 - 日常/大额/合计视图切换
class AggPage extends StatefulWidget {
  const AggPage({super.key});

  @override
  State<AggPage> createState() => _AggPageState();
}

class _AggPageState extends State<AggPage> with SingleTickerProviderStateMixin {
  final _service = PeriodBookService.instance;

  late TabController _tabController;
  int _selectedIndex = 0;

  /// 上一次已归位的记账视图下标，用于在 `_tabController` 监听中判定是否真的换了视图。
  /// MUST NOT 用 `_selectedIndex` 代替：点击分段按钮时它已先行更新（FR-018）。
  int _lastTabIndex = 0;

  List<PeriodRecord> _periods = [];
  final Map<int, double?> _balances = {};
  final Map<int, PeriodCalculations> _calcMap = {};
  final Map<int, List<ExpenseRecord>> _expenseMap = {};
  final Map<int, List<StageRecord>> _stagesMap = {};
  final Map<int, List<LargeAdditionRecord>> _additionsMap = {};
  final Map<int, List<LargeExpenseRecord>> _largeExpensesMap = {};
  bool _loading = true;

  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _stageData = [];
  Map<String, double> _expenseTypeData = {};
  Map<String, double> _stageExpenseTypeData = {};

  List<Map<String, dynamic>> _largeMonthlyData = [];
  Map<String, double> _largeExpenseTypeData = {};

  // 合计统计（日常 + 大额）
  List<Map<String, dynamic>> _summaryMonthlyData = [];
  Map<String, double> _summaryExpenseTypeData = {};

  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedStage;
  List<int> _availableYears = [];
  List<int> _availableMonths = [];
  List<int> _availableStages = [];

  List<PeriodRecord> _filteredPeriods = [];

  /// 当前选中的分类显示名；null 表示未筛选。
  ///
  /// 纯页面临时状态，MUST NOT 写入 `toolbox.db` 或 `app_settings`（FR-014）。
  String? _selectedCategory;

  /// 已展开全部明细的周期 id，按周期记录、允许多张同时展开（FR-012）。
  final Set<int> _expandedPeriodIds = {};

  double _totalExpense = 0;
  double _totalLargeAddition = 0;
  double _totalLargeExpense = 0;
  double _totalNet = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // 滑动或点击切换后始终与当前 Tab 同步，保证标题按钮高亮一致
      final currentIndex = _tabController.index;
      if (currentIndex != _selectedIndex) {
        setState(() {
          _selectedIndex = currentIndex;
        });
      }
      // 切换记账视图即清空筛选（FR-018）。挂在监听上而非分段按钮的回调上，
      // 使点击与左右滑动两种切换方式都被覆盖；已选中的分类互不跨视图传递
      if (currentIndex != _lastTabIndex) {
        _lastTabIndex = currentIndex;
        if (_selectedCategory != null) {
          setState(() {
            _selectedCategory = null;
            _expandedPeriodIds.clear();
          });
        }
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final periods = await _service.getAllPeriods();
      _periods = periods;

      for (final p in periods) {
        final calc = await _service.getPeriodCalculations(p.id!);
        _balances[p.id!] = calc.balance;
        _calcMap[p.id!] = calc;
        _expenseMap[p.id!] = await _service.getExpensesByPeriod(p.id!);
        _stagesMap[p.id!] = await _service.getStagesByPeriod(p.id!);
        _additionsMap[p.id!] = await _service.getLargeAdditionsByPeriod(p.id!);
        _largeExpensesMap[p.id!] =
            await _service.getLargeExpensesByPeriod(p.id!);
      }

      _extractFilterOptions();
      _calculateStats();
      _calculateSummary();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('AggPage load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _extractFilterOptions() {
    final years = _periods
        .map((p) => DateTime.parse(p.startDate).year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    _availableYears = years;

    if (_selectedYear != null) {
      final months = _periods
          .where((p) => DateTime.parse(p.startDate).year == _selectedYear)
          .map((p) => DateTime.parse(p.startDate).month)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      _availableMonths = months;
    } else {
      final months = _periods
          .map((p) => DateTime.parse(p.startDate).month)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      _availableMonths = months;
    }

    if (_selectedMonth != null) {
      final filtered = _getFilteredPeriods();
      int maxStages = 0;
      for (final p in filtered) {
        final calc = _calcMap[p.id];
        if (calc != null && calc.stages.length > maxStages) {
          maxStages = calc.stages.length;
        }
      }
      // 阶段倒序展示：第 N 阶段在最前，第 1 阶段放在最后
      _availableStages = List.generate(maxStages, (i) => maxStages - i);
    } else {
      _availableStages = [];
      _selectedStage = null;
    }
  }

  void _calculateStats() {
    final Map<String, double> monthlyExpenseMap = {};
    final List<Map<String, dynamic>> stageDataList = [];
    final Map<String, double> categoryTotals = {};
    // 倒推残值伪分类，四个饼图数据源共用同一字面量
    const residualCategory = CategoryFilterHelper.residualOnlyCategory;
    double totalBalance = 0;

    _filteredPeriods = _getFilteredPeriods();

    for (final period in _filteredPeriods) {
      final calc = _calcMap[period.id];
      if (calc == null) continue;

      final balance = _balances[period.id];
      totalBalance += balance ?? 0;

      // 其他消费整体归入「其他」扇区。此前它们被 where 直接滤掉，饼图既没有
      // 「其他」扇区、也盖不全该周期的总支出（FR-001a）
      final expenses = _expenseMap[period.id] ?? [];
      for (final e in expenses) {
        final cat = CategoryFilterHelper.resolveCategoryName(
          isOther: e.isOther,
          rawCategory: e.category,
        );
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }

      final livingTotal =
          calc.stages.fold<double>(0, (sum, s) => sum + (s.livingTotal ?? 0));
      if (livingTotal > 0) {
        categoryTotals[residualCategory] =
            (categoryTotals[residualCategory] ?? 0) + livingTotal;
      }

      final startDate = DateTime.parse(period.startDate);
      final monthKey =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
      final totalExpense = calc.totalBase - (balance ?? 0);
      monthlyExpenseMap[monthKey] =
          (monthlyExpenseMap[monthKey] ?? 0) + totalExpense;

      if (_selectedMonth != null) {
        for (int i = 0; i < calc.stages.length; i++) {
          final stage = calc.stages[i];
          final stageExpense =
              stage.shoppingTotal + stage.otherTotal + (stage.livingTotal ?? 0);
          stageDataList.add({
            'stage': i + 1,
            'expense': stageExpense,
            'shopping': stage.shoppingTotal,
            'other': stage.otherTotal,
            'living': stage.livingTotal ?? 0,
          });
        }
      }
    }

    _monthlyData = monthlyExpenseMap.entries.map((e) {
      final parts = e.key.split('-');
      return {
        'month': int.parse(parts[1]),
        'year': int.parse(parts[0]),
        'expense': e.value,
      };
    }).toList()
      ..sort((a, b) {
        final aKey = (a['year']! as int) * 100 + (a['month']! as int);
        final bKey = (b['year']! as int) * 100 + (b['month']! as int);
        return aKey.compareTo(bKey);
      });

    if (_selectedMonth != null) {
      final Map<int, Map<String, double>> stageMap = {};
      for (final data in stageDataList) {
        final stage = data['stage'] as int;
        if (!stageMap.containsKey(stage)) {
          stageMap[stage] = {
            'expense': 0,
            'shopping': 0,
            'other': 0,
            'living': 0
          };
        }
        stageMap[stage]!['expense'] =
            stageMap[stage]!['expense']! + (data['expense'] as double);
        stageMap[stage]!['shopping'] =
            stageMap[stage]!['shopping']! + (data['shopping'] as double);
        stageMap[stage]!['other'] =
            stageMap[stage]!['other']! + (data['other'] as double);
        stageMap[stage]!['living'] =
            stageMap[stage]!['living']! + (data['living'] as double);
      }
      _stageData = stageMap.entries
          .map((e) => {
                'stage': e.key,
                'expense': e.value['expense'],
                'shopping': e.value['shopping'],
                'other': e.value['other'],
                'living': e.value['living'],
              })
          .toList()
        ..sort((a, b) => (a['stage'] as int).compareTo(b['stage'] as int));
    } else {
      _stageData = [];
    }

    _expenseTypeData = {
      ...categoryTotals,
      'balance': totalBalance,
    };

    _stageExpenseTypeData = {};
    if (_selectedStage != null) {
      final Map<String, double> stageCategoryTotals = {};
      double stageTotalBalance = 0;

      for (final period in _filteredPeriods) {
        final stages = _stagesMap[period.id];
        if (stages == null || stages.isEmpty) continue;

        final calc = _calcMap[period.id];
        if (calc == null) continue;

        final stageIndex = _selectedStage! - 1;
        if (stageIndex >= stages.length) continue;

        final targetStage = stages[stageIndex];
        final targetStageId = targetStage.id!;
        final targetStageCalc = calc.stages[stageIndex];

        final expenses = _expenseMap[period.id] ?? [];
        for (final e in expenses) {
          // 先按阶段收敛、再判分类，两个顺序 MUST NOT 颠倒（FR-001b / FR-016a）
          if (e.stageId == targetStageId) {
            final cat = CategoryFilterHelper.resolveCategoryName(
              isOther: e.isOther,
              rawCategory: e.category,
            );
            stageCategoryTotals[cat] =
                (stageCategoryTotals[cat] ?? 0) + e.amount;
          }
        }

        if (targetStage.balance != null) {
          stageTotalBalance += targetStage.balance!;
        }

        final stageLiving = targetStageCalc.livingTotal ?? 0;
        if (stageLiving > 0) {
          stageCategoryTotals[residualCategory] =
              (stageCategoryTotals[residualCategory] ?? 0) + stageLiving;
        }
      }

      _stageExpenseTypeData = {
        ...stageCategoryTotals,
        'balance': stageTotalBalance,
      };
    }

    final Map<String, double> largeMonthlyExpenseMap = {};
    final Map<String, double> largeCategoryTotals = {};

    for (final period in _filteredPeriods) {
      final expenses = _largeExpensesMap[period.id] ?? [];
      double periodExpense = 0;
      for (final e in expenses) {
        periodExpense += e.amount;
        // 大额侧同样先判 isOther：other:购物 MUST 归入「其他」（FR-001b）
        final cat = CategoryFilterHelper.resolveCategoryName(
          isOther: e.isOther,
          rawCategory: e.category,
        );
        largeCategoryTotals[cat] = (largeCategoryTotals[cat] ?? 0) + e.amount;
      }

      final startDate = DateTime.parse(period.startDate);
      final monthKey =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
      largeMonthlyExpenseMap[monthKey] =
          (largeMonthlyExpenseMap[monthKey] ?? 0) + periodExpense;
    }

    _largeMonthlyData = largeMonthlyExpenseMap.entries.map((e) {
      final parts = e.key.split('-');
      return {
        'month': int.parse(parts[1]),
        'year': int.parse(parts[0]),
        'expense': e.value,
      };
    }).toList()
      ..sort((a, b) {
        final aKey = (a['year']! as int) * 100 + (a['month']! as int);
        final bKey = (b['year']! as int) * 100 + (b['month']! as int);
        return aKey.compareTo(bKey);
      });

    _largeExpenseTypeData = {...largeCategoryTotals};
    // 计算合计数据（日常 + 大额）
    final Map<String, double> summaryMonthlyMap = {};
    final Map<String, double> summaryCategoryTotals = {};

    for (final period in _filteredPeriods) {
      final calc = _calcMap[period.id];
      if (calc == null) continue;

      final balance = _balances[period.id];
      final startDate = DateTime.parse(period.startDate);
      final monthKey =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';

      // 日常消费
      final dailyExpense = calc.totalBase - (balance ?? 0);

      // 大额消费
      final largeExpenses = _largeExpensesMap[period.id] ?? [];
      final largeExpense =
          largeExpenses.fold<double>(0, (sum, e) => sum + e.amount);

      // 合计月度消费
      summaryMonthlyMap[monthKey] =
          (summaryMonthlyMap[monthKey] ?? 0) + dailyExpense + largeExpense;

      // 按分类汇总日常消费
      final expenses = _expenseMap[period.id] ?? [];
      for (final e in expenses) {
        final cat = CategoryFilterHelper.resolveCategoryName(
          isOther: e.isOther,
          rawCategory: e.category,
        );
        summaryCategoryTotals[cat] =
            (summaryCategoryTotals[cat] ?? 0) + e.amount;
      }

      // 杂项
      final livingTotal =
          calc.stages.fold<double>(0, (sum, s) => sum + (s.livingTotal ?? 0));
      if (livingTotal > 0) {
        summaryCategoryTotals[residualCategory] =
            (summaryCategoryTotals[residualCategory] ?? 0) + livingTotal;
      }

      // 大额消费按分类汇总（与日常同分类合并计入合计）
      for (final e in largeExpenses) {
        final cat = CategoryFilterHelper.resolveCategoryName(
          isOther: e.isOther,
          rawCategory: e.category,
        );
        summaryCategoryTotals[cat] =
            (summaryCategoryTotals[cat] ?? 0) + e.amount;
      }
    }

    _summaryMonthlyData = summaryMonthlyMap.entries.map((e) {
      final parts = e.key.split('-');
      return {
        'month': int.parse(parts[1]),
        'year': int.parse(parts[0]),
        'expense': e.value,
      };
    }).toList()
      ..sort((a, b) {
        final aKey = (a['year']! as int) * 100 + (a['month']! as int);
        final bKey = (b['year']! as int) * 100 + (b['month']! as int);
        return aKey.compareTo(bKey);
      });

    _summaryExpenseTypeData = {...summaryCategoryTotals};

    // 范围已换，筛选是否还有落点要按新范围重新判定（FR-016）
    _applyAutoCancelFilter();
  }

  /// 选中分类的唯一收敛入口：选中 / 换分类 / 取消都走这里。
  ///
  /// 展开状态随筛选结果重算而整体重置，避免「新分类的卡片仍停在展开态」这类
  /// 与用户上一次操作无关的残留（FR-012 Edge Case / 契约 C5-3）。
  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category;
      _expandedPeriodIds.clear();
    });
  }

  /// 报表视图（占比 ↔ 趋势）被用户切换。
  ///
  /// 筛选状态 MUST NOT 因此取消（FR-017）——「支出趋势」视图没有饼图也没有
  /// 图例，吸顶标签是它唯一的取消入口，一并清掉就再也取消不掉。这里只收起
  /// 展开态：卡片内容随视图切换重排，上一视图的展开状态没有理由保留（契约 C5-3）
  void _onReportViewChanged(ReportViewType viewType) {
    if (_expandedPeriodIds.isEmpty) return;
    setState(_expandedPeriodIds.clear);
  }

  /// 当前视图的筛选汇总，与下方卡片共用同一份结果。
  ///
  /// 三个视图的口径由各自的饼图决定：日常视图只含日常侧且跟随阶段，大额视图
  /// 只含大额侧、合计视图两侧皆含，后两者不按阶段收敛（FR-016a）。
  List<PeriodCategorySummary> _buildFilterSummaries({
    required String categoryName,
    required bool includeDaily,
    required bool includeLarge,
  }) {
    return CategoryFilterHelper.buildSummaries(
      categoryName: categoryName,
      periods: _filteredPeriods,
      expenseMap: _expenseMap,
      largeExpenseMap: _largeExpensesMap,
      stagesMap: _stagesMap,
      calcMap: _calcMap,
      selectedStage: _selectedStage,
      includeDaily: includeDaily,
      includeLarge: includeLarge,
    );
  }

  /// 当前视图口径下，按周期 id 索引的筛选汇总。
  ///
  /// 由各视图在构建时按自己的口径调一次，再下发给卡片；MUST NOT 让每张卡片
  /// 各算一遍——`SliverChildBuilderDelegate` 每帧都会重建卡片，逐卡重算就是
  /// O(周期数²)。未筛选时立即返回空表，卡片按原样渲染（FR-021 / 契约 C3-1）。
  Map<int, PeriodCategorySummary> _filterSummaryMap({
    required bool includeDaily,
    required bool includeLarge,
  }) {
    final category = _selectedCategory;
    if (category == null) return const {};
    return {
      for (final summary in _buildFilterSummaries(
        categoryName: category,
        includeDaily: includeDaily,
        includeLarge: includeLarge,
      ))
        summary.periodId: summary,
    };
  }

  /// 范围变更后的自动取消：新范围内该分类小计之和为零即清空筛选（FR-016）。
  ///
  /// 判定口径是聚合层的小计而非记录条数，因此「杂项」这类只有残值、没有任何
  /// 记录的分类不会被误取消——它的卡片仍有金额可看。
  void _applyAutoCancelFilter() {
    final category = _selectedCategory;
    if (category == null) return;
    final hasAmount = _buildFilterSummaries(
      categoryName: category,
      includeDaily: _selectedIndex != 1,
      includeLarge: _selectedIndex != 0,
    ).any((s) => s.hasAnyAmount);
    if (!hasAmount) {
      _selectedCategory = null;
      _expandedPeriodIds.clear();
    }
  }

  /// 在卡片内原地展开 / 收起某周期的全部明细（FR-012 / 契约 C4-5）。
  ///
  /// 按周期 id 记录，多张卡片可同时展开且相互独立。
  void _togglePeriodExpanded(int periodId) {
    setState(() {
      if (!_expandedPeriodIds.add(periodId)) {
        _expandedPeriodIds.remove(periodId);
      }
    });
  }

  /// 卡片底部的筛选下钻区：分类小计 → 至多 3 条明细 → 查看全部 / 收起。
  ///
  /// 三个视图共用同一实现：日常与大额视图各自只有一侧有数据，[grouped] 为
  /// false 时合计成一行小计；合计视图两侧都有，[grouped] 为 true 时拆成
  /// 「日常」「大额」两组、各自给出小计（FR-009 / 契约 C4-2）。
  Widget _buildFilterSection({
    required AppThemeExtension appTheme,
    required PeriodCategorySummary summary,
    bool grouped = false,
  }) {
    final subtotal = summary.dailySubtotal + summary.largeSubtotal;

    // 「杂项」是倒推残值，没有底层记录可列：只给小计与一行说明，
    // MUST NOT 渲染明细区，MUST NOT 显示「查看全部」（FR-022 / 契约 C4-7）
    if (summary.isResidualOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSubtotalRow(appTheme, summary.categoryName, subtotal),
          AppSpacing.h4,
          Text(
            '来自未逐条记录的部分',
            style: TextStyle(
              fontSize: 11,
              color: appTheme.earthMedium.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    final expanded = _expandedPeriodIds.contains(summary.periodId);
    // 折叠态取前 3 条——先日常组、再大额组，跨组不混排（契约 C2-5）。
    // 因此展开后列表只是同一个序的延长，不会出现条目换位。
    final visible =
        CategoryFilterHelper.visibleItems(summary, expanded: expanded);
    final visibleDaily = visible.take(summary.dailyItems.length).toList();
    final visibleLarge = visible.skip(summary.dailyItems.length).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterSubtotalRow(appTheme, summary.categoryName, subtotal),
        // 小计为零：保留卡片并显示零，MUST NOT 渲染空的明细区（FR-010 / C4-9）
        if (visible.isNotEmpty || grouped) ...[
          AppSpacing.h6,
          if (grouped) ...[
            _buildFilterGroup(
              appTheme: appTheme,
              title: '日常',
              subtotal: summary.dailySubtotal,
              items: visibleDaily,
            ),
            AppSpacing.h6,
            _buildFilterGroup(
              appTheme: appTheme,
              title: '大额',
              subtotal: summary.largeSubtotal,
              items: visibleLarge,
            ),
          ] else
            _buildFilterGroup(
              appTheme: appTheme,
              title: null,
              subtotal: subtotal,
              items: visible,
            ),
        ],
        if (summary.isExpandable) ...[
          AppSpacing.h4,
          _buildFilterToggle(appTheme, summary, expanded: expanded),
        ],
      ],
    );
  }

  /// 分类小计行 —— 卡片内部锚定「这一屏的钱属于哪一类」
  Widget _buildFilterSubtotalRow(
    AppThemeExtension appTheme,
    String categoryName,
    double subtotal,
  ) {
    final hasAmount = subtotal > 0;
    return Row(
      children: [
        Text(
          '$categoryName小计',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: appTheme.earthMedium.withValues(alpha: 0.85),
          ),
        ),
        const Spacer(),
        Text(
          hasAmount
              ? '-${FormatUtils.formatAmount(subtotal)}'
              : FormatUtils.formatAmount(0),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: hasAmount
                ? appTheme.rose
                : appTheme.earthMedium.withValues(alpha: 0.4),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 合计视图下的单侧分组：小计 + 该侧明细（FR-009）
  ///
  /// [title] 为 null 时不出分组标题、只出明细——日常与大额视图只有一侧，
  /// 标题纯属噪音。小计为 0 的一侧仍然出标题与零值，让用户看到「这一侧没有」
  /// 而不是以为界面漏了一组（US3 场景 2）。
  Widget _buildFilterGroup({
    required AppThemeExtension appTheme,
    required String? title,
    required double subtotal,
    required List<FilterItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          _buildFilterSubtotalRow(appTheme, title, subtotal),
          if (items.isNotEmpty) AppSpacing.h4,
        ],
        ...items.map((item) => _buildDetailRow(
              appTheme,
              item.description,
              '-${FormatUtils.formatAmount(item.amount)}',
              appTheme.rose,
            )),
      ],
    );
  }

  /// 「查看全部 N 条 / 收起」——原地展开，不跳页、不弹窗（FR-011 / C4-4）
  ///
  /// 内层 `GestureDetector` 在手势竞技场中先于卡片主体的 `onTap` 入局并胜出，
  /// 因此点击本控件 MUST NOT 触发卡片跳转（FR-012 / C4-6）。
  Widget _buildFilterToggle(
    AppThemeExtension appTheme,
    PeriodCategorySummary summary, {
    required bool expanded,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePeriodExpanded(summary.periodId),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded ? '收起' : '查看全部 ${summary.totalCount} 条',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: appTheme.primary,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
              color: appTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _calculateSummary() {
    double totalExpense = 0;
    double totalLargeAddition = 0;
    double totalLargeExpense = 0;

    for (final period in _periods) {
      final calc = _calcMap[period.id];
      final balance = _balances[period.id];
      if (calc != null) {
        totalExpense += calc.totalBase - (balance ?? 0);
      }

      final additions = _additionsMap[period.id] ?? [];
      for (final a in additions) {
        totalLargeAddition += a.amount;
      }

      final expenses = _largeExpensesMap[period.id] ?? [];
      for (final e in expenses) {
        totalLargeExpense += e.amount;
      }
    }

    setState(() {
      _totalExpense = totalExpense;
      _totalLargeAddition = totalLargeAddition;
      _totalLargeExpense = totalLargeExpense;
      _totalNet = totalLargeAddition - totalLargeExpense;
    });
  }

  List<PeriodRecord> _getFilteredPeriods() {
    return _periods.where((period) {
      final startDate = DateTime.parse(period.startDate);
      if (_selectedYear != null && startDate.year != _selectedYear) {
        return false;
      }
      if (_selectedMonth != null && startDate.month != _selectedMonth) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onYearChanged(int? year) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = null;
      _selectedStage = null;
      _extractFilterOptions();
      // 范围条件已换，卡片内容随之重算，展开态一并收起（契约 C5-3）。
      // 「筛选因新范围无金额而自动取消」只是其中一条路径，其余路径同样要收起
      _expandedPeriodIds.clear();
      _calculateStats();
    });
  }

  void _onMonthChanged(int? month) {
    setState(() {
      _selectedMonth = month;
      _selectedStage = null;
      _extractFilterOptions();
      _expandedPeriodIds.clear();
      _calculateStats();
    });
  }

  void _onStageChanged(int? stage) {
    setState(() {
      _selectedStage = stage;
      _expandedPeriodIds.clear();
      _calculateStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: appTheme.cream,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Text(
          '历史记录',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('日常', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('大额', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text('合计', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_selectedIndex},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedIndex = newSelection.first;
                  _tabController.animateTo(_selectedIndex);
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return appTheme.primary;
                    }
                    return appTheme.cardBackground;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return appTheme.earth;
                  },
                ),
                side: WidgetStateProperty.all(
                  BorderSide(
                      color: appTheme.earthMedium.withValues(alpha: 0.2)),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(appTheme.radiusSm),
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: appTheme.primary))
          : TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDailyView(appTheme),
                _buildLargeView(appTheme),
                _buildSummaryView(appTheme),
              ],
            ),
    );
  }

  Widget _buildDailyView(AppThemeExtension appTheme) {
    if (_periods.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: '暂无历史记录',
        subtitle: '删除的周期记录不会出现在这里',
      );
    }

    // 日常视图只统计日常侧，且跟随阶段选择（FR-016a）
    final summaries =
        _filterSummaryMap(includeDaily: true, includeLarge: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
              boxShadow: appTheme.cardShadow,
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            child: Column(
              children: [
                HistoryFilterBar(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedStage: _selectedStage,
                  availableYears: _availableYears,
                  availableMonths: _availableMonths,
                  availableStages: _availableStages,
                  onYearChanged: _onYearChanged,
                  onMonthChanged: _onMonthChanged,
                  onStageChanged: _onStageChanged,
                ),
                Divider(
                  height: 1,
                  color: appTheme.earthMedium.withValues(alpha: 0.08),
                ),
                if (_monthlyData.isNotEmpty ||
                    _stageData.isNotEmpty ||
                    _expenseTypeData.values.any((v) => v > 0))
                  ReportCard(
                    monthlyData: _monthlyData,
                    stageData: _stageData,
                    expenseTypeData: _expenseTypeData,
                    stageExpenseTypeData:
                        _selectedStage != null ? _stageExpenseTypeData : null,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: _onCategorySelected,
                    onViewTypeChanged: _onReportViewChanged,
                  ),
              ],
            ),
          ),
        ),
        // 未筛选时 MUST NOT 渲染该 sliver（FR-021 / 契约 C3-1）
        if (_selectedCategory != null) _buildFilterLabelSliver(appTheme),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = _filteredPeriods[index];
              return _buildPeriodCard(appTheme, period, summaries[period.id]);
            },
            childCount: _filteredPeriods.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildLargeView(AppThemeExtension appTheme) {
    if (_periods.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.diamond_outlined,
        title: '暂无大额记录',
        subtitle: '创建周期后可在大额记录中追加与支出',
      );
    }

    // 大额视图只统计大额侧，且不按阶段收敛（FR-016a）
    final summaries =
        _filterSummaryMap(includeDaily: false, includeLarge: true);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
              boxShadow: appTheme.cardShadow,
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            child: Column(
              children: [
                HistoryFilterBar(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedStage: null,
                  availableYears: _availableYears,
                  availableMonths: _availableMonths,
                  availableStages: const [],
                  onYearChanged: _onYearChanged,
                  onMonthChanged: _onMonthChanged,
                  onStageChanged: null,
                ),
                Divider(
                  height: 1,
                  color: appTheme.earthMedium.withValues(alpha: 0.08),
                ),
                if (_largeMonthlyData.isNotEmpty ||
                    _largeExpenseTypeData.values.any((v) => v > 0))
                  ReportCard(
                    monthlyData: _largeMonthlyData,
                    stageData: const [],
                    expenseTypeData: _largeExpenseTypeData,
                    stageExpenseTypeData: null,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: _onCategorySelected,
                    onViewTypeChanged: _onReportViewChanged,
                  ),
              ],
            ),
          ),
        ),
        // 未筛选时 MUST NOT 渲染该 sliver（FR-021 / 契约 C3-1）
        if (_selectedCategory != null) _buildFilterLabelSliver(appTheme),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = _filteredPeriods[index];
              return _buildLargePeriodCard(
                  appTheme, period, summaries[period.id]);
            },
            childCount: _filteredPeriods.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSummaryView(AppThemeExtension appTheme) {
    if (_periods.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: '暂无历史记录',
        subtitle: '删除的周期记录不会出现在这里',
      );
    }

    // 合计视图两侧皆含，卡片内需按日常 / 大额分组呈现（FR-009）
    final summaries = _filterSummaryMap(includeDaily: true, includeLarge: true);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 筛选 + 报表
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
              boxShadow: appTheme.cardShadow,
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            child: Column(
              children: [
                HistoryFilterBar(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedStage: null,
                  availableYears: _availableYears,
                  availableMonths: _availableMonths,
                  availableStages: const [],
                  onYearChanged: _onYearChanged,
                  onMonthChanged: _onMonthChanged,
                  onStageChanged: null,
                ),
                Divider(
                  height: 1,
                  color: appTheme.earthMedium.withValues(alpha: 0.08),
                ),
                if (_summaryMonthlyData.isNotEmpty ||
                    _summaryExpenseTypeData.values.any((v) => v > 0))
                  ReportCard(
                    monthlyData: _summaryMonthlyData,
                    stageData: const [],
                    expenseTypeData: _summaryExpenseTypeData,
                    stageExpenseTypeData: null,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: _onCategorySelected,
                    onViewTypeChanged: _onReportViewChanged,
                  ),
              ],
            ),
          ),
        ),
        // 周期列表
        // 未筛选时 MUST NOT 渲染该 sliver（FR-021 / 契约 C3-1）
        if (_selectedCategory != null) _buildFilterLabelSliver(appTheme),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = _filteredPeriods[index];
              return _buildSummaryPeriodCard(
                  appTheme, period, summaries[period.id]);
            },
            childCount: _filteredPeriods.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// 吸顶筛选标签 —— 三个视图共用，插在图表与卡片列表之间
  ///
  /// 渲染条件 MUST NOT 依赖报表视图：切到「支出趋势」后饼图与图例都不存在，
  /// 本标签是该视图下唯一的取消入口（FR-006a / FR-017 / 契约 C3-7）。
  Widget _buildFilterLabelSliver(AppThemeExtension appTheme) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterLabelHeaderDelegate(
        category: _selectedCategory!,
        appTheme: appTheme,
        onClose: () => _onCategorySelected(null),
      ),
    );
  }

  Widget _buildSummaryItem({
    required AppThemeExtension appTheme,
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earthMedium,
                ),
              ),
              Text(
                value >= 0
                    ? FormatUtils.formatAmount(value)
                    : '-${FormatUtils.formatAmount(value.abs())}',
                style: TextStyle(
                  fontSize: isTotal ? 20 : 16,
                  fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(AppThemeExtension appTheme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: appTheme.earthMedium,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.earth,
          ),
        ),
      ],
    );
  }

  /// 日常周期卡片
  ///
  /// [summary] 非空表示筛选生效，在既有汇总行下方追加分类小计与明细
  /// （FR-007 / 契约 C4-1）；为空时与筛选前完全一致。
  Widget _buildPeriodCard(
    AppThemeExtension appTheme,
    PeriodRecord period,
    PeriodCategorySummary? summary,
  ) {
    final calc = _calcMap[period.id];
    final startDate = DateTime.parse(period.startDate);
    final endDate = DateTime.parse(period.endDate);
    final totalExpense = (calc?.shoppingTotal ?? 0) +
        (calc?.livingTotal ?? 0) +
        (calc?.otherTotal ?? 0);
    final personalExpense =
        (calc?.shoppingTotal ?? 0) + (calc?.livingTotal ?? 0);
    final otherExpense = calc?.otherTotal ?? 0;
    final hasExpense = totalExpense > 0;

    return GestureDetector(
      onTap: () => context.push('/period_book/detail/${period.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: appTheme.earth.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：日历图标 + 日期范围 | 大金额 + 箭头
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 14, right: 12, bottom: 10),
              child: Row(
                children: [
                  // 年份图标（日历内展示年份）
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 24,
                        color: appTheme.primary.withValues(alpha: 0.25),
                      ),
                      Text(
                        _fmtYearShort(startDate, endDate),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: appTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.w8,
                  // 日期范围
                  Expanded(
                    child: Text(
                      _fmtDateRangeShort(startDate, endDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthLight,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // 金额 + 箭头
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        hasExpense
                            ? '-${FormatUtils.formatAmount(totalExpense)}'
                            : FormatUtils.formatAmount(0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasExpense
                              ? appTheme.rose
                              : appTheme.earthMedium.withValues(alpha: 0.4),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      AppSpacing.w6,
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: appTheme.earthMedium.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 分隔线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 0.5,
                color: appTheme.creamDark,
              ),
            ),
            // 第二行：支出明细
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Row(
                children: [
                  // 个人消费
                  _buildExpenseItem(
                    appTheme: appTheme,
                    label: '个人消费',
                    value: personalExpense,
                  ),
                  // 分隔符
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '|',
                      style: TextStyle(
                        fontSize: 11,
                        color: appTheme.earthMedium.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // 其他消费
                  _buildExpenseItem(
                    appTheme: appTheme,
                    label: '其他消费',
                    value: otherExpense,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // 筛选下钻区：分类小计 + 至多 3 条明细 + 查看全部（FR-007）
            if (summary != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: appTheme.creamDark),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _buildFilterSection(
                  appTheme: appTheme,
                  summary: summary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 大额周期卡片
  ///
  /// [summary] 非空表示筛选生效：未筛选时可见的三组明细 MUST 整体让位于该分类的
  /// 小计与明细，MUST NOT 叠加展示（FR-008 / 契约 C4-8）。第一行的净额口径
  /// 不随筛选变化，仍是「大额追加合计 − 大额支出合计」（FR-013 / 契约 C4-1）。
  Widget _buildLargePeriodCard(
    AppThemeExtension appTheme,
    PeriodRecord period,
    PeriodCategorySummary? summary,
  ) {
    final additions = _additionsMap[period.id] ?? [];
    final expenses = _largeExpensesMap[period.id] ?? [];
    final additionsTotal =
        additions.fold<double>(0, (sum, a) => sum + a.amount);
    final expensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final net = additionsTotal - expensesTotal;
    final hasItems = additions.isNotEmpty || expenses.isNotEmpty;

    final startDate = DateTime.parse(period.startDate);
    final endDate = DateTime.parse(period.endDate);

    return GestureDetector(
      onTap: () => context.push('/period_book/large_items/${period.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: appTheme.earth.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行：年份图标 + 起止日期 | 总金额 + 箭头
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 14, right: 12, bottom: 10),
              child: Row(
                children: [
                  // 年份图标（日历内展示年份）
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 24,
                        color: appTheme.primary.withValues(alpha: 0.25),
                      ),
                      Text(
                        _fmtYearShort(startDate, endDate),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: appTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.w8,
                  // 日期范围
                  Expanded(
                    child: Text(
                      _fmtDateRangeShort(startDate, endDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthLight,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // 总金额（净额）+ 箭头
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatNet(net),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasItems
                              ? (net >= 0 ? appTheme.sage : appTheme.rose)
                              : appTheme.earthMedium.withValues(alpha: 0.4),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      AppSpacing.w6,
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: appTheme.earthMedium.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 分隔线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 0.5,
                color: appTheme.creamDark,
              ),
            ),
            // 内容区：大额记录明细
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: !hasItems && summary == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '暂无大额记录',
                        style: TextStyle(
                          fontSize: 12,
                          color: appTheme.earthMedium.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : summary != null
                      ? _buildFilterSection(
                          appTheme: appTheme, summary: summary)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (additions.isNotEmpty)
                              _buildDetailGroup(
                                appTheme: appTheme,
                                title: '大额追加',
                                color: appTheme.sage,
                                children: additions.map((a) {
                                  return _buildDetailRow(
                                    appTheme,
                                    a.reason,
                                    '+${FormatUtils.formatAmount(a.amount)}',
                                    appTheme.sage,
                                  );
                                }).toList(),
                              ),
                            if (expenses
                                .where((e) => !e.isOther)
                                .isNotEmpty) ...[
                              if (additions.isNotEmpty) AppSpacing.h6,
                              _buildDetailGroup(
                                appTheme: appTheme,
                                title: '个人支出',
                                color: appTheme.rose,
                                children:
                                    expenses.where((e) => !e.isOther).map((e) {
                                  return _buildDetailRow(
                                    appTheme,
                                    e.description,
                                    '-${FormatUtils.formatAmount(e.amount)}',
                                    appTheme.rose,
                                  );
                                }).toList(),
                              ),
                            ],
                            if (expenses
                                .where((e) => e.isOther)
                                .isNotEmpty) ...[
                              if (additions.isNotEmpty ||
                                  expenses.where((e) => !e.isOther).isNotEmpty)
                                AppSpacing.h6,
                              _buildDetailGroup(
                                appTheme: appTheme,
                                title: '其他支出',
                                color: appTheme.rose,
                                children:
                                    expenses.where((e) => e.isOther).map((e) {
                                  return _buildDetailRow(
                                    appTheme,
                                    e.description,
                                    '-${FormatUtils.formatAmount(e.amount)}',
                                    appTheme.rose,
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 合计周期卡片
  ///
  /// [summary] 非空表示筛选生效：在既有「日常消费 / 大额记录」汇总行下方，把所选
  /// 分类的记录拆成日常与大额两组，各自给出小计与明细（FR-009 / 契约 C4-1）。
  Widget _buildSummaryPeriodCard(
    AppThemeExtension appTheme,
    PeriodRecord period,
    PeriodCategorySummary? summary,
  ) {
    final calc = _calcMap[period.id];
    final balance = _balances[period.id];
    final startDate = DateTime.parse(period.startDate);
    final endDate = DateTime.parse(period.endDate);

    // 日常消费
    final dailyExpense = calc != null ? calc.totalBase - (balance ?? 0) : 0.0;

    // 大额消费
    final largeExpenses = _largeExpensesMap[period.id] ?? [];
    final largeExpenseTotal =
        largeExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // 合计
    final totalExpense = dailyExpense + largeExpenseTotal;
    final hasExpense = totalExpense > 0;

    return GestureDetector(
      onTap: () => context.push('/period_book/detail/${period.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: appTheme.earth.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行：年份图标 + 起止日期 | 总金额 + 箭头
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 14, right: 12, bottom: 10),
              child: Row(
                children: [
                  // 年份图标（日历内展示年份）
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 24,
                        color: appTheme.primary.withValues(alpha: 0.25),
                      ),
                      Text(
                        _fmtYearShort(startDate, endDate),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: appTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.w8,
                  // 日期范围
                  Expanded(
                    child: Text(
                      _fmtDateRangeShort(startDate, endDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthLight,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // 总金额 + 箭头
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        hasExpense
                            ? '-${FormatUtils.formatAmount(totalExpense)}'
                            : FormatUtils.formatAmount(0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasExpense
                              ? appTheme.rose
                              : appTheme.earthMedium.withValues(alpha: 0.4),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      AppSpacing.w6,
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: appTheme.earthMedium.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 分隔线
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 0.5,
                color: appTheme.creamDark,
              ),
            ),
            // 内容区：日常消费 + 大额消费总额
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Row(
                children: [
                  // 日常消费
                  _buildExpenseItem(
                    appTheme: appTheme,
                    label: '日常消费',
                    value: dailyExpense,
                  ),
                  // 分隔符
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '|',
                      style: TextStyle(
                        fontSize: 11,
                        color: appTheme.earthMedium.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // 大额消费
                  _buildExpenseItem(
                    appTheme: appTheme,
                    label: '大额记录',
                    value: largeExpenseTotal,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // 筛选下钻区：日常与大额两组各自给出小计与明细（FR-009）
            if (summary != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: appTheme.creamDark),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _buildFilterSection(
                  appTheme: appTheme,
                  summary: summary,
                  grouped: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem({
    required AppThemeExtension appTheme,
    required String label,
    required double value,
  }) {
    final hasValue = value > 0;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: appTheme.earthMedium.withValues(alpha: 0.75),
          ),
        ),
        AppSpacing.w4,
        Text(
          hasValue ? '-${FormatUtils.formatAmount(value)}' : '0',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: hasValue
                ? appTheme.earth
                : appTheme.earthMedium.withValues(alpha: 0.35),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGroup({
    required AppThemeExtension appTheme,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: appTheme.earthMedium.withValues(alpha: 0.8),
          ),
        ),
        AppSpacing.h4,
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(
    AppThemeExtension appTheme,
    String label,
    String amount,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: appTheme.earth,
              ),
            ),
          ),
          AppSpacing.w8,
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// 年份标识（图标内展示），按周期开始日期的年份计算
  String _fmtYearShort(DateTime start, DateTime end) {
    return (start.year % 100).toString();
  }

  String _fmtDateRangeShort(DateTime start, DateTime end) {
    final startStr = '${start.month}/${start.day}';
    final endStr = '${end.month}/${end.day}';
    return '$startStr - $endStr';
  }

  String _formatNet(double net) {
    final abs = FormatUtils.formatAmount(net.abs());
    if (net > 0) return '+$abs';
    if (net < 0) return '-$abs';
    return '0.00';
  }
}

/// 吸顶筛选标签的 delegate（仅 `agg.dart` 一处使用，故就地定义）
///
/// 高度恒定、不做展开收起动画：每次筛选状态变化只引起一次布局变化，滚动过程中
/// 标签尺寸不再变动，因此不会让下方卡片列表持续抖动（契约 C3-6）。已知取舍：
/// 标签出现 / 消失的瞬间，列表整体上下让位一个标签高度。
class _FilterLabelHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterLabelHeaderDelegate({
    required this.category,
    required this.appTheme,
    required this.onClose,
  });

  final String category;
  final AppThemeExtension appTheme;
  final VoidCallback onClose;

  /// 标签条高度，同时也是关闭控件的点击区域高度
  static const double _barHeight = 44;

  @override
  double get minExtent => _barHeight;

  @override
  double get maxExtent => _barHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _barHeight,
      // 底色 MUST 不透明，否则下方的卡片会透上来造成误读（契约 C3-5）
      color: appTheme.cream,
      padding: EdgeInsets.only(
        left: AppSpacing.pageH.left,
        right: AppSpacing.pageH.right,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: appTheme.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(appTheme.radiusPill),
              border: Border.all(
                color: appTheme.primary.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              '筛选：$category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: appTheme.primary,
              ),
            ),
          ),
          // 关闭控件 —— 与再次点击同一分类完全等价（FR-020 / 契约 C3-3）。
          // 点击区域取满标签条高度，保证列表滚到任意位置都能一次点中（SC-002）
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: _barHeight,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: appTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterLabelHeaderDelegate oldDelegate) {
    return oldDelegate.category != category || oldDelegate.appTheme != appTheme;
  }
}

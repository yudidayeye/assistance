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
import '../widgets/history_filter_bar.dart';
import '../widgets/report_card.dart';

/// 聚合历史记录页面 - 日常/大额/合计视图切换
class AggPage extends StatefulWidget {
  const AggPage({super.key});

  @override
  State<AggPage> createState() => _AggPageState();
}

class _AggPageState extends State<AggPage>
    with SingleTickerProviderStateMixin {
  final _service = PeriodBookService.instance;
  
  late TabController _tabController;
  int _selectedIndex = 0;
  
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

  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedStage;
  List<int> _availableYears = [];
  List<int> _availableMonths = [];
  List<int> _availableStages = [];

  List<PeriodRecord> _filteredPeriods = [];

  double _totalExpense = 0;
  double _totalLargeAddition = 0;
  double _totalLargeExpense = 0;
  double _totalNet = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
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
        _largeExpensesMap[p.id!] = await _service.getLargeExpensesByPeriod(p.id!);
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
        ..sort();
      _availableMonths = months;
    } else {
      final months = _periods
          .map((p) => DateTime.parse(p.startDate).month)
          .toSet()
          .toList()
        ..sort();
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
      _availableStages = List.generate(maxStages, (i) => i + 1);
    } else {
      _availableStages = [];
      _selectedStage = null;
    }
  }

  void _calculateStats() {
    final Map<String, double> monthlyExpenseMap = {};
    final List<Map<String, dynamic>> stageDataList = [];
    final Map<String, double> categoryTotals = {};
    double totalBalance = 0;

    _filteredPeriods = _getFilteredPeriods();

    for (final period in _filteredPeriods) {
      final calc = _calcMap[period.id];
      if (calc == null) continue;

      final balance = _balances[period.id];
      totalBalance += balance ?? 0;

      final expenses = _expenseMap[period.id] ?? [];
      for (final e in expenses) {
        final cat = _normalizeCategory(e.category);
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }

      final livingTotal = calc.stages.fold<double>(
          0, (sum, s) => sum + (s.livingTotal ?? 0));
      if (livingTotal > 0) {
        categoryTotals['杂项'] = (categoryTotals['杂项'] ?? 0) + livingTotal;
      }

      final startDate = DateTime.parse(period.startDate);
      final monthKey = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
      final totalExpense = calc.totalBase - (balance ?? 0);
      monthlyExpenseMap[monthKey] = (monthlyExpenseMap[monthKey] ?? 0) + totalExpense;

      if (_selectedMonth != null) {
        for (int i = 0; i < calc.stages.length; i++) {
          final stage = calc.stages[i];
          final stageExpense = stage.shoppingTotal + stage.otherTotal + (stage.livingTotal ?? 0);
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
          stageMap[stage] = {'expense': 0, 'shopping': 0, 'other': 0, 'living': 0};
        }
        stageMap[stage]!['expense'] = stageMap[stage]!['expense']! + (data['expense'] as double);
        stageMap[stage]!['shopping'] = stageMap[stage]!['shopping']! + (data['shopping'] as double);
        stageMap[stage]!['other'] = stageMap[stage]!['other']! + (data['other'] as double);
        stageMap[stage]!['living'] = stageMap[stage]!['living']! + (data['living'] as double);
      }
      _stageData = stageMap.entries.map((e) => {
        'stage': e.key,
        'expense': e.value['expense'],
        'shopping': e.value['shopping'],
        'other': e.value['other'],
        'living': e.value['living'],
      }).toList()
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
          if (e.stageId == targetStageId) {
            final cat = _normalizeCategory(e.category);
            stageCategoryTotals[cat] = (stageCategoryTotals[cat] ?? 0) + e.amount;
          }
        }

        if (targetStage.balance != null) {
          stageTotalBalance += targetStage.balance!;
        }

        final stageLiving = targetStageCalc.livingTotal ?? 0;
        if (stageLiving > 0) {
          stageCategoryTotals['杂项'] = (stageCategoryTotals['杂项'] ?? 0) + stageLiving;
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
        final cat = _normalizeCategory(e.category);
        largeCategoryTotals[cat] = (largeCategoryTotals[cat] ?? 0) + e.amount;
      }

      final startDate = DateTime.parse(period.startDate);
      final monthKey = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
      largeMonthlyExpenseMap[monthKey] = (largeMonthlyExpenseMap[monthKey] ?? 0) + periodExpense;
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

  String _normalizeCategory(String dbCategory) {
    if (dbCategory == 'shopping') return '购物';
    if (dbCategory == 'other') return '其他';
    return dbCategory;
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
      _calculateStats();
    });
  }

  void _onMonthChanged(int? month) {
    setState(() {
      _selectedMonth = month;
      _selectedStage = null;
      _extractFilterOptions();
      _calculateStats();
    });
  }

  void _onStageChanged(int? stage) {
    setState(() {
      _selectedStage = stage;
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
                  BorderSide(color: appTheme.earthMedium.withValues(alpha: 0.2)),
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
                    stageExpenseTypeData: _selectedStage != null
                        ? _stageExpenseTypeData
                        : null,
                  ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = _filteredPeriods[index];
              return _buildPeriodCard(appTheme, period);
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
                  ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final period = _filteredPeriods[index];
              return _buildLargePeriodCard(appTheme, period);
            },
            childCount: _filteredPeriods.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSummaryView(AppThemeExtension appTheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
              boxShadow: appTheme.cardShadow,
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '汇总统计',
                  style: AppTypography.headerTitle.copyWith(
                    color: appTheme.earth,
                    fontSize: 18,
                  ),
                ),
                AppSpacing.h16,
                _buildSummaryItem(
                  appTheme: appTheme,
                  label: '总日常消费',
                  value: _totalExpense,
                  icon: Icons.shopping_cart_outlined,
                  color: appTheme.rose,
                ),
                AppSpacing.h12,
                _buildSummaryItem(
                  appTheme: appTheme,
                  label: '总大额追加',
                  value: _totalLargeAddition,
                  icon: Icons.add_circle_outline,
                  color: appTheme.sage,
                ),
                AppSpacing.h12,
                _buildSummaryItem(
                  appTheme: appTheme,
                  label: '总大额支出',
                  value: _totalLargeExpense,
                  icon: Icons.remove_circle_outline,
                  color: appTheme.rose,
                ),
                Divider(
                  height: 24,
                  color: appTheme.earthMedium.withValues(alpha: 0.15),
                ),
                _buildSummaryItem(
                  appTheme: appTheme,
                  label: '大额净额',
                  value: _totalNet,
                  icon: Icons.account_balance_outlined,
                  color: _totalNet >= 0 ? appTheme.sage : appTheme.rose,
                  isTotal: true,
                ),
              ],
            ),
          ),
          AppSpacing.h16,
          Container(
            decoration: BoxDecoration(
              color: appTheme.cardBackground,
              borderRadius: BorderRadius.circular(appTheme.radiusMd),
              boxShadow: appTheme.cardShadow,
              border: Border.all(color: appTheme.cardBorder, width: 0.5),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '统计信息',
                  style: AppTypography.headerTitle.copyWith(
                    color: appTheme.earth,
                    fontSize: 18,
                  ),
                ),
                AppSpacing.h16,
                _buildInfoRow(appTheme, '总周期数', '${_periods.length} 个'),
                AppSpacing.h8,
                _buildInfoRow(appTheme, '总天数', '${_periods.fold<int>(0, (sum, p) => sum + p.totalDays)} 天'),
                AppSpacing.h8,
                _buildInfoRow(appTheme, '平均每周期消费', 
                  _periods.isNotEmpty 
                    ? FormatUtils.formatAmount(_totalExpense / _periods.length)
                    : '0.00'),
              ],
            ),
          ),
        ],
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

  Widget _buildPeriodCard(AppThemeExtension appTheme, PeriodRecord period) {
    final calc = _calcMap[period.id];
    final balance = _balances[period.id];
    final startDate = DateTime.parse(period.startDate);
    final endDate = DateTime.parse(period.endDate);

    double totalExpense = 0;
    if (calc != null) {
      totalExpense = calc.totalBase - (balance ?? 0);
    }

    final personalExpense = calc?.stages.fold<double>(
            0, (sum, s) => sum + s.shoppingTotal) ?? 0;
    final otherExpense = calc?.stages.fold<double>(
            0, (sum, s) => sum + s.otherTotal + (s.livingTotal ?? 0)) ?? 0;

    final hasExpense = totalExpense > 0;

    return GestureDetector(
      onTap: () => context.push('/period_book/large_items/${period.id}'),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: period.isClosed
                        ? appTheme.earthMedium.withValues(alpha: 0.3)
                        : appTheme.primary,
                  ),
                ),
                AppSpacing.w8,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: appTheme.creamDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
            child: Row(
              children: [
                _buildExpenseItem(
                  appTheme: appTheme,
                  label: '个人消费',
                  value: personalExpense,
                ),
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
                _buildExpenseItem(
                  appTheme: appTheme,
                  label: '其他消费',
                  value: otherExpense,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildLargePeriodCard(AppThemeExtension appTheme, PeriodRecord period) {
    final additions = _additionsMap[period.id] ?? [];
    final expenses = _largeExpensesMap[period.id] ?? [];
    final startDate = DateTime.parse(period.startDate);
    final endDate = DateTime.parse(period.endDate);

    double additionsTotal = 0;
    for (final a in additions) {
      additionsTotal += a.amount;
    }

    double expensesTotal = 0;
    for (final e in expenses) {
      expensesTotal += e.amount;
    }

    final net = additionsTotal - expensesTotal;
    final hasData = additions.isNotEmpty || expenses.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/period_book/large_items/${period.id}'),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(appTheme.radiusMd),
        boxShadow: appTheme.cardShadow,
        border: Border.all(color: appTheme.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: period.isClosed
                        ? appTheme.earthMedium.withValues(alpha: 0.3)
                        : appTheme.primary,
                  ),
                ),
                AppSpacing.w8,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatNet(net),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: net > 0
                            ? appTheme.sage
                            : net < 0
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: appTheme.creamDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
            child: hasData
                ? Column(
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
                          .where((e) => e.category != 'other')
                          .isNotEmpty) ...[
                        if (additions.isNotEmpty) AppSpacing.h6,
                        _buildDetailGroup(
                          appTheme: appTheme,
                          title: '个人支出',
                          color: appTheme.rose,
                          children: expenses
                              .where((e) => e.category != 'other')
                              .map((e) {
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
                          .where((e) => e.category == 'other')
                          .isNotEmpty) ...[
                        if (additions.isNotEmpty ||
                            expenses
                                .where((e) => e.category != 'other')
                                .isNotEmpty)
                          AppSpacing.h6,
                        _buildDetailGroup(
                          appTheme: appTheme,
                          title: '其他支出',
                          color: appTheme.rose,
                          children: expenses
                              .where((e) => e.category == 'other')
                              .map((e) {
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
                  )
                : Text(
                    '暂无大额记录',
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                  ),
          ),
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
          hasValue
              ? '-${FormatUtils.formatAmount(value)}'
              : '0',
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








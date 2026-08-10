import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../models/large_addition_record.dart';
import '../models/large_expense_record.dart';
import '../services/period_book_service.dart';
import '../widgets/history_filter_bar.dart';
import '../widgets/report_card.dart';

/// 大额记录列表页 — 参照历史记录页，但移除了阶段筛选，统计大额追加与支出
class LargeItemsHistoryPage extends StatefulWidget {
  const LargeItemsHistoryPage({super.key});

  @override
  State<LargeItemsHistoryPage> createState() => _LargeItemsHistoryPageState();
}

class _LargeItemsHistoryPageState extends State<LargeItemsHistoryPage> {
  final _service = PeriodBookService.instance;
  List<PeriodRecord> _periods = [];
  final Map<int, List<LargeAdditionRecord>> _additionsMap = {};
  final Map<int, List<LargeExpenseRecord>> _expensesMap = {};
  bool _loading = true;

  // 统计数据
  List<Map<String, dynamic>> _monthlyData = [];
  Map<String, double> _expenseTypeData = {};

  // 筛选状态（大额不区分阶段，仅年份 + 月份）
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];
  List<int> _availableMonths = [];

  // 缓存筛选后的周期列表
  List<PeriodRecord> _filteredPeriods = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final periods = await _service.getAllPeriods();
      _periods = periods;

      // 批量获取每个周期的大额追加与支出
      for (final p in periods) {
        _additionsMap[p.id!] = await _service.getLargeAdditionsByPeriod(p.id!);
        _expensesMap[p.id!] = await _service.getLargeExpensesByPeriod(p.id!);
      }

      _extractFilterOptions();
      _calculateStats();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('LargeItemsHistoryPage load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 提取可用筛选项（年份 + 月份）
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
  }

  /// 计算统计数据（大额支出维度）
  void _calculateStats() {
    final Map<String, double> monthlyExpenseMap = {};
    final Map<String, double> categoryTotals = {};

    _filteredPeriods = _getFilteredPeriods();

    for (final period in _filteredPeriods) {
      final expenses = _expensesMap[period.id] ?? [];
      double periodExpense = 0;
      for (final e in expenses) {
        periodExpense += e.amount;
        final cat = _normalizeCategory(e.category);
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }

      // 按周期开始日期的月份统计
      final startDate = DateTime.parse(period.startDate);
      final monthKey =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
      monthlyExpenseMap[monthKey] =
          (monthlyExpenseMap[monthKey] ?? 0) + periodExpense;
    }

    // 转换为列表并按月份排序
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

    // 大额支出类型汇总（购物 / 其他）
    _expenseTypeData = {...categoryTotals};
  }

  /// 标准化分类名称：'shopping'→'购物', 'other'→'其他'
  String _normalizeCategory(String dbCategory) {
    if (dbCategory == 'shopping') return '购物';
    if (dbCategory == 'other') return '其他';
    return dbCategory;
  }

  /// 筛选后的周期列表（仅按年份 / 月份）
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
      _extractFilterOptions();
      _calculateStats();
    });
  }

  void _onMonthChanged(int? month) {
    setState(() {
      _selectedMonth = month;
      _extractFilterOptions();
      _calculateStats();
    });
  }

  String _fmtDateRangeShort(DateTime start, DateTime end) {
    return '${start.month}月${start.day}日 ~ ${end.month}月${end.day}日';
  }

  /// 年份标识（图标内展示），按周期开始日期的年份计算
  String _fmtYearShort(DateTime start, DateTime end) {
    return (start.year % 100).toString();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return AppScaffold(
      body: _loading && _periods.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: appTheme.primary,
              backgroundColor: appTheme.cardBackground,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: appTheme.cream,
                    elevation: 0,
                    centerTitle: false,
                    titleSpacing: 0,
                    automaticallyImplyLeading: true,
                    title: Text(
                      '大额记录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headerTitle
                          .copyWith(color: appTheme.earth),
                    ),
                  ),
                  if (_periods.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.diamond_outlined,
                        title: '暂无大额记录',
                        subtitle: '创建周期后可在大额记录中追加与支出',
                      ),
                    )
                  else ...[
                    // 筛选 + 报表（同一个卡片）
                    SliverToBoxAdapter(
                      child: _buildFilterReportCard(appTheme),
                    ),
                    // 周期列表
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final period = _filteredPeriods[index];
                          return _buildLargePeriodCard(appTheme, period);
                        },
                        childCount: _filteredPeriods.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  /// 筛选栏 + 报表
  Widget _buildFilterReportCard(AppThemeExtension appTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
          // 分割线
          Divider(
            height: 1,
            color: appTheme.earthMedium.withValues(alpha: 0.08),
          ),
          if (_monthlyData.isNotEmpty ||
              _expenseTypeData.values.any((v) => v > 0))
            ReportCard(
              monthlyData: _monthlyData,
              stageData: const [],
              expenseTypeData: _expenseTypeData,
              stageExpenseTypeData: null,
              defaultView: ReportViewType.expenseTrend,
            ),
        ],
      ),
    );
  }

  /// 大额记录卡片 — 标题区展示起止日期与总金额，内容区直接展示大额明细
  Widget _buildLargePeriodCard(
      AppThemeExtension appTheme, PeriodRecord period) {
    final additions = _additionsMap[period.id] ?? [];
    final expenses = _expensesMap[period.id] ?? [];
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
              padding:
                  const EdgeInsets.only(left: 16, top: 14, right: 12, bottom: 10),
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
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // 总金额（净额）+ 箭头
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatNet(net),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasItems
                              ? (net >= 0 ? appTheme.sage : appTheme.rose)
                              : appTheme.earthMedium.withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      AppSpacing.w6,
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: appTheme.earthMedium.withValues(alpha: 0.3),
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
              child: !hasItems
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
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 明细分组
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

  /// 明细行 — 标签 + 金额
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
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNet(double net) {
    final abs = FormatUtils.formatAmount(net.abs());
    if (net > 0) return '+$abs';
    if (net < 0) return '-$abs';
    return '¥0.00';
  }
}
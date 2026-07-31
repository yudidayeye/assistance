import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart';
import '../widgets/history_filter_bar.dart';
import '../widgets/report_card.dart';

/// 历史周期列表页 — 编辑排版风格，强调金额数字的视觉冲击
class PeriodHistoryPage extends StatefulWidget {
  const PeriodHistoryPage({super.key});

  @override
  State<PeriodHistoryPage> createState() => _PeriodHistoryPageState();
}

class _PeriodHistoryPageState extends State<PeriodHistoryPage> {
  final _service = PeriodBookService.instance;
  List<PeriodRecord> _periods = [];
  final Map<int, double?> _balances = {};
  final Map<int, PeriodCalculations> _calcMap = {};
  bool _loading = true;

  // 统计数据
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _stageData = [];
  Map<String, double> _expenseTypeData = {};

  // 筛选状态
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedStage;
  List<int> _availableYears = [];
  List<int> _availableMonths = [];
  List<int> _availableStages = [];

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

      // 批量获取余额和计算数据
      for (final p in periods) {
        final calc = await _service.getPeriodCalculations(p.id!);
        _balances[p.id!] = calc.balance;
        _calcMap[p.id!] = calc;
      }

      // 提取可用筛选项
      _extractFilterOptions();

      // 计算统计数据
      _calculateStats();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('PeriodHistoryPage load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 提取可用筛选项
  void _extractFilterOptions() {
    // 提取年份
    final years = _periods.map((p) => DateTime.parse(p.startDate).year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    _availableYears = years;

    // 提取月份（根据选中的年份）
    if (_selectedYear != null) {
      final months = _periods
          .where((p) => DateTime.parse(p.startDate).year == _selectedYear)
          .map((p) => DateTime.parse(p.startDate).month)
          .toSet()
          .toList()
        ..sort();
      _availableMonths = months;
    } else {
      final months = _periods.map((p) => DateTime.parse(p.startDate).month).toSet().toList()
        ..sort();
      _availableMonths = months;
    }

    // 提取阶段序号（根据选中的月份动态更新）
    if (_selectedMonth != null) {
      // 当选择月份时，获取该月份对应周期的最大阶段数
      int maxStages = 0;
      for (final p in _filteredPeriods) {
        final calc = _calcMap[p.id];
        if (calc != null && calc.stages.length > maxStages) {
          maxStages = calc.stages.length;
        }
      }
      _availableStages = List.generate(maxStages, (i) => i + 1);
    } else {
      // 当未选择月份时，获取所有周期的最大阶段数
      int maxStages = 0;
      for (final p in _periods) {
        final calc = _calcMap[p.id];
        if (calc != null && calc.stages.length > maxStages) {
          maxStages = calc.stages.length;
        }
      }
      _availableStages = List.generate(maxStages, (i) => i + 1);
    }

    // 不再自动选中年份，允许用户选择"全部"
  }

  /// 计算统计数据
  void _calculateStats() {
    // 月度支出数据（按月份汇总）
    final Map<String, double> monthlyExpenseMap = {};
    // 阶段支出数据（当选择月份时使用）
    final List<Map<String, dynamic>> stageDataList = [];
    // 消费类型汇总（购物、其他、生活）
    double totalShopping = 0;
    double totalOther = 0;
    double totalLiving = 0;

    // 获取筛选后的周期列表
    _filteredPeriods = _getFilteredPeriods();

    for (final period in _filteredPeriods) {
      final calc = _calcMap[period.id];
      if (calc == null) continue;

      final balance = _balances[period.id];
      final totalExpense = calc.totalBase - (balance ?? 0);

      // 累加消费类型（分开计算）
      totalShopping += calc.shoppingTotal;
      totalLiving += calc.livingTotal ?? 0;
      totalOther += calc.otherTotal;

      // 按结束日期的月份统计
      final endDate = DateTime.parse(period.endDate);
      final monthKey = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}';
      monthlyExpenseMap[monthKey] = (monthlyExpenseMap[monthKey] ?? 0) + totalExpense;

      // 当选择月份时，收集阶段数据
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

    // 合并相同阶段的数据
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

    // 消费类型数据（购物、其他、生活）
    _expenseTypeData = {
      'shopping': totalShopping,
      'other': totalOther,
      'living': totalLiving,
    };
  }

  /// 获取筛选后的周期列表
  List<PeriodRecord> _getFilteredPeriods() {
    return _periods.where((period) {
      final startDate = DateTime.parse(period.startDate);

      // 年份筛选
      if (_selectedYear != null && startDate.year != _selectedYear) {
        return false;
      }

      // 月份筛选
      if (_selectedMonth != null && startDate.month != _selectedMonth) {
        return false;
      }

      // 阶段筛选（检查周期是否有该序号的阶段）
      if (_selectedStage != null) {
        final calc = _calcMap[period.id];
        if (calc == null || calc.stages.length < _selectedStage!) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// 年份筛选变更
  void _onYearChanged(int? year) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = null; // 重置月份选择
      _selectedStage = null; // 重置阶段选择
      _extractFilterOptions();
      _calculateStats();
    });
  }

  /// 月份筛选变更
  void _onMonthChanged(int? month) {
    setState(() {
      _selectedMonth = month;
      _selectedStage = null; // 重置阶段选择
      _calculateStats();
    });
  }

  /// 阶段筛选变更
  void _onStageChanged(int? stage) {
    setState(() {
      _selectedStage = stage;
      _calculateStats();
    });
  }

  String _fmtDateRange(String startDate, String endDate) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final startStr =
        '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
    return '$startStr ~ $endStr';
  }

  Future<bool> _showDeleteConfirmDialog(PeriodRecord period) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final appTheme = Theme.of(context).appTheme;
        return AlertDialog(
          backgroundColor: appTheme.cream,
          title: Text(
            '删除周期',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: appTheme.earth,
            ),
          ),
          content: Text(
            '确定要删除 ${_fmtDateRange(period.startDate, period.endDate)} 的周期吗？\n\n删除后该周期的所有数据将无法恢复。',
            style: TextStyle(
              fontSize: 14,
              color: appTheme.earthMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '取消',
                style: TextStyle(color: appTheme.earthMedium),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '删除',
                style: TextStyle(color: appTheme.rose),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _deletePeriod(PeriodRecord period) async {
    try {
      await _service.deletePeriod(period.id!);
      setState(() {
        _periods.removeWhere((p) => p.id == period.id);
        _balances.remove(period.id);
        _calcMap.remove(period.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('删除成功'),
            backgroundColor: Theme.of(context).appTheme.sage,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Theme.of(context).appTheme.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadData();
    }
  }

  Future<void> _confirmDelete(PeriodRecord period) async {
    final confirmed = await _showDeleteConfirmDialog(period);
    if (!confirmed) return;
    await _deletePeriod(period);
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
                      '历史记录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
                    ),
                  ),
                  if (_periods.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.history_rounded,
                        title: '暂无历史记录',
                        subtitle: '删除的周期记录不会出现在这里',
                      ),
                    )
                  else ...[
                    // 筛选栏
                    SliverToBoxAdapter(
                      child: HistoryFilterBar(
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
                    ),
                    // 报表卡片
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (_monthlyData.isNotEmpty ||
                              _stageData.isNotEmpty ||
                              _expenseTypeData.values.any((v) => v > 0))
                            ReportCard(
                              monthlyData: _monthlyData,
                              stageData: _stageData,
                              expenseTypeData: _expenseTypeData,
                            ),
                          AppSpacing.h8,
                        ],
                      ),
                    ),
                    // 周期列表
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final period = _filteredPeriods[index];
                          return _buildPeriodCard(appTheme, period);
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


  /// 周期卡片 — 参考设计图：日期+金额第一行 + 支出明细第二行
  Widget _buildPeriodCard(AppThemeExtension appTheme, PeriodRecord period) {
    final balance = _balances[period.id];
    final calc = _calcMap[period.id];
    final totalExpense = (calc?.totalBase ?? 0) - (balance ?? 0);
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
              padding: const EdgeInsets.only(left: 16, top: 14, right: 12, bottom: 10),
              child: Row(
                children: [
                  // 日历图标
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: appTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(appTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: appTheme.primary,
                    ),
                  ),
                  AppSpacing.w10,
                  // 日期范围
                  Expanded(
                    child: Text(
                      _fmtDateRange(period.startDate, period.endDate),
                      style: TextStyle(
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earthLight,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  // 金额 + 箭头
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasExpense
                            ? '-${FormatUtils.formatAmount(totalExpense)}'
                            : FormatUtils.formatAmount(0),
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasExpense
                              ? appTheme.rose
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
            // 第二行：支出明细 + 删除按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Row(
                children: [
                  // 个人消费
                  _buildExpenseItem(
                    appTheme: appTheme,
                    label: '个人消费',
                    value: personalExpense,
                    dotColor: appTheme.primary,
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
                    dotColor: appTheme.earthMedium.withValues(alpha: 0.35),
                  ),
                  const Spacer(),
                  // 删除按钮
                  _buildDeleteButton(appTheme, period),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 支出明细项 — 圆点 + 标签 + 金额
  Widget _buildExpenseItem({
    required AppThemeExtension appTheme,
    required String label,
    required double value,
    required Color dotColor,
  }) {
    final hasValue = value > 0;
    return Row(
      children: [
        // 彩色圆点
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        AppSpacing.w6,
        // 标签
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: appTheme.earthMedium.withValues(alpha: 0.75),
          ),
        ),
        AppSpacing.w4,
        // 金额
        Text(
          hasValue
              ? '-${FormatUtils.formatAmount(value)}'
              : '¥0',
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: hasValue
                ? appTheme.earth
                : appTheme.earthMedium.withValues(alpha: 0.35),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 删除按钮
  Widget _buildDeleteButton(AppThemeExtension appTheme, PeriodRecord period) {
    return GestureDetector(
      onTap: () => _confirmDelete(period),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          Icons.delete_outline_rounded,
          size: 16,
          color: appTheme.earthMedium.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
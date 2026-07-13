import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart';

/// 历史周期列表页
class PeriodHistoryPage extends StatefulWidget {
  const PeriodHistoryPage({super.key});

  @override
  State<PeriodHistoryPage> createState() => _PeriodHistoryPageState();
}

class _PeriodHistoryPageState extends State<PeriodHistoryPage> {
  final _service = PeriodBookService.instance;
  List<PeriodRecord> _periods = [];
  Map<int, double?> _balances = {};
  Map<int, double> _totalBases = {};
  Map<int, PeriodCalculations> _calcMap = {};
  bool _loading = true;

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

      // 批量获取余额、总本金和计算数据
      for (final p in periods) {
        final calc = await _service.getPeriodCalculations(p.id!);
        _balances[p.id!] = calc.balance;
        _totalBases[p.id!] = calc.totalBase;
        _calcMap[p.id!] = calc;
      }
    } catch (e) {
      debugPrint('PeriodHistoryPage load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtDate(String dateStr) {
    final dt = DateTime.parse(dateStr);
    return '${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
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
            '确定要删除 ${_fmtDate(period.startDate)} ~ ${_fmtDate(period.endDate)} 的周期吗？\n\n删除后该周期的所有数据将无法恢复。',
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
        _totalBases.remove(period.id);
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
      // 如果删除失败，重新加载数据
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Column(
          children: [
            // 头部
            _buildHeader(appTheme),
            // 列表
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _periods.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.history_rounded,
                          title: '暂无历史记录',
                          subtitle: '删除的周期记录不会出现在这里',
                        )
                      : ListView(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          children: [
                            // 表头
                            _buildTableHeader(appTheme),
                            // 数据行
                            ..._periods.map((period) {
                              return _buildPeriodRow(appTheme, period);
                            }),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeExtension appTheme) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, safeTop + 12, 24, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: appTheme.earthMedium, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '历史记录',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: appTheme.earth,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(AppThemeExtension appTheme) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: appTheme.earthMedium.withValues(alpha: 0.7),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: appTheme.creamDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(appTheme.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('周期', style: headerStyle)),
          Expanded(flex: 2, child: Text('总支出', style: headerStyle)),
          Expanded(flex: 2, child: Text('总追加', style: headerStyle)),
          Expanded(flex: 2, child: Text('余额', style: headerStyle)),
          Expanded(flex: 1, child: Text('操作', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildPeriodRow(AppThemeExtension appTheme, PeriodRecord period) {
    final balance = _balances[period.id];
    final calc = _calcMap[period.id];
    final shoppingTotal = calc?.shoppingTotal ?? 0;
    final otherTotal = calc?.otherTotal ?? 0;
    final totalExpense = shoppingTotal + otherTotal;
    final totalAddition = calc?.stages.fold<double>(0, (sum, s) => sum + s.additionsTotal) ?? 0;
    final isClosed = period.isClosed;

    return GestureDetector(
      onTap: () => context.push('/period_book/detail/${period.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusSm),
          border: Border.all(color: appTheme.cardBorder.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          children: [
            // 周期名称（已包含日期范围）
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    isClosed ? Icons.lock_outline_rounded : Icons.schedule_rounded,
                    size: 14,
                    color: isClosed ? appTheme.earthMedium : appTheme.sage,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_fmtDate(period.startDate)} ~ ${_fmtDate(period.endDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.earth,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // 总支出
            Expanded(
              flex: 2,
              child: Text(
                FormatUtils.formatAmount(totalExpense),
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appTheme.earth,
                ),
              ),
            ),
            // 总追加
            Expanded(
              flex: 2,
              child: Text(
                '+${FormatUtils.formatAmount(totalAddition)}',
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appTheme.sage,
                ),
              ),
            ),
            // 余额
            Expanded(
              flex: 2,
              child: Text(
                balance != null
                    ? FormatUtils.formatAmount(balance)
                    : '¥0.00',
                style: TextStyle(
                  fontSize: 13,
                  color: balance != null
                      ? appTheme.primary
                      : appTheme.earthMedium.withValues(alpha: 0.4),
                ),
              ),
            ),
            // 操作
            Expanded(
              flex: 1,
              child: Center(
                child: GestureDetector(
                  onTap: () => _confirmDelete(period),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: appTheme.rose.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: appTheme.rose,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PeriodRecord period) async {
    final confirmed = await _showDeleteConfirmDialog(period);
    if (!confirmed) return;
    await _deletePeriod(period);
  }
}

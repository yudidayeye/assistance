import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/pinned_header_delegate.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/period_record.dart';
import '../services/period_book_service.dart';

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
    } catch (e) {
      debugPrint('PeriodHistoryPage load error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
      // 如果删除失败，重新加载数据
      _loadData();
    }
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
                  AppHeader.simple(title: '历史记录'),
                  if (_periods.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.history_rounded,
                        title: '暂无历史记录',
                        subtitle: '删除的周期记录不会出现在这里',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final period = _periods[index];
                          return _buildPeriodCard(appTheme, period);
                        },
                        childCount: _periods.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }


  /// 周期卡片 — 两行紧凑布局：日期与金额对比 + 辅助信息
  Widget _buildPeriodCard(AppThemeExtension appTheme, PeriodRecord period) {
    final balance = _balances[period.id];
    final calc = _calcMap[period.id];
    final totalExpense = (calc?.totalBase ?? 0) - (balance ?? 0);
    final personalExpense =
        (calc?.shoppingTotal ?? 0) + (calc?.livingTotal ?? 0);
    final otherExpense = calc?.otherTotal ?? 0;
    final days = DateTime.parse(period.endDate)
            .difference(DateTime.parse(period.startDate))
            .inDays +
        1;
    final hasExpense = totalExpense > 0;

    return GestureDetector(
      onTap: () => context.push('/period_book/detail/${period.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: appTheme.cardShadow,
          border: Border.all(color: appTheme.cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：日期范围（左）+ 大金额（右）+ 箭头
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧：日期范围 + 天数
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtDateRange(period.startDate, period.endDate),
                        style: TextStyle(
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: appTheme.earth,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧：大金额 + 箭头
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      hasExpense
                          ? '-${FormatUtils.formatAmount(totalExpense)}'
                          : FormatUtils.formatAmount(0),
                      style: TextStyle(
                        fontFamily: GoogleFonts.dmSans().fontFamily,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: hasExpense
                            ? appTheme.rose
                            : appTheme.earthMedium.withValues(alpha: 0.4),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: appTheme.earthMedium.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第二行：个人/其他标签（左）+ 删除按钮（右）
            Row(
              children: [
                // 左侧：标签组
                Expanded(
                  child: Row(
                    children: [
                      _buildTag(
                        appTheme: appTheme,
                        label: '个人消费',
                        value: personalExpense,
                        color: appTheme.earth,
                      ),
                      const SizedBox(width: 6),
                      _buildTag(
                        appTheme: appTheme,
                        label: '其他消费',
                        value: otherExpense,
                        color: appTheme.earthMedium,
                      ),
                    ],
                  ),
                ),
                // 右侧：删除按钮
                GestureDetector(
                  onTap: () => _confirmDelete(period),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: appTheme.rose.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: appTheme.rose.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 标签式金额展示（紧凑版）
  Widget _buildTag({
    required AppThemeExtension appTheme,
    required String label,
    required double value,
    required Color color,
  }) {
    final hasValue = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            hasValue
                ? '-${FormatUtils.formatAmount(value)}'
                : FormatUtils.formatAmount(0),
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasValue ? color : color.withValues(alpha: 0.4),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PeriodRecord period) async {
    final confirmed = await _showDeleteConfirmDialog(period);
    if (!confirmed) return;
    await _deletePeriod(period);
  }
}


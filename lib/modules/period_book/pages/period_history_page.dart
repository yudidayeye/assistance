import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/utils/format_utils.dart';
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

      // 批量获取余额和总本金
      for (final p in periods) {
        final calc = await _service.getPeriodCalculations(p.id!);
        _balances[p.id!] = calc.balance;
        _totalBases[p.id!] = calc.totalBase;
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
                      ? Center(
                          child: Text(
                            '暂无历史记录',
                            style: TextStyle(
                              fontSize: 14,
                              color: appTheme.earthMedium.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: _periods.length,
                            itemBuilder: (ctx, i) {
                              final period = _periods[i];
                              return _buildPeriodRow(appTheme, period);
                            },
                          ),
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
      padding: EdgeInsets.fromLTRB(24, safeTop + 16, 24, 16),
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

  Widget _buildPeriodRow(AppThemeExtension appTheme, PeriodRecord period) {
    final balance = _balances[period.id];
    final totalBase = _totalBases[period.id] ?? 0;
    final isClosed = period.isClosed;

    return GestureDetector(
      onTap: () => context.push('/period_book/detail/${period.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: appTheme.cardShadow,
          border: Border.all(color: appTheme.cardBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // 日期范围
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        isClosed ? Icons.lock_outline_rounded : Icons.schedule_rounded,
                        size: 16,
                        color: isClosed ? appTheme.earthMedium : appTheme.sage,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmtDate(period.startDate)} ~ ${_fmtDate(period.endDate)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: appTheme.earth,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '共${period.totalDays}天',
                    style: TextStyle(
                      fontSize: 12,
                      color: appTheme.earthMedium.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 金额信息
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FormatUtils.formatAmount(totalBase),
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.earth,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance != null
                      ? FormatUtils.formatAmount(balance)
                      : '—',
                  style: TextStyle(
                    fontSize: 12,
                    color: balance != null
                        ? appTheme.primary
                        : appTheme.earthMedium.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

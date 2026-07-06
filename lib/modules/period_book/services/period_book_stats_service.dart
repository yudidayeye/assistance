import 'period_book_service.dart';

/// 周期记账统计服务 — 图表数据
class PeriodBookStatsService {
  static final PeriodBookStatsService instance = PeriodBookStatsService._();
  PeriodBookStatsService._();

  final PeriodBookService _service = PeriodBookService.instance;

  /// 饼图数据：购物 / 其他 / 生活 三类占比
  Future<Map<String, double>> getPieChartData(int periodId) async {
    final calc = await _service.getPeriodCalculations(periodId);
    return {
      'shopping': calc.shoppingTotal,
      'other': calc.otherTotal,
      'living': calc.livingTotal ?? 0,
    };
  }

  /// 余额趋势数据：所有周期的余额变化
  Future<List<Map<String, dynamic>>> getBalanceTrendData() async {
    final periods = await _service.getAllPeriods();
    // 按 start_date 正序
    periods.sort((a, b) => a.startDate.compareTo(b.startDate));

    final result = <Map<String, dynamic>>[];
    for (final p in periods) {
      final calc = await _service.getPeriodCalculations(p.id!);
      result.add({
        'startDate': p.startDate,
        'endDate': p.endDate,
        'balance': calc.balance,
      });
    }
    return result;
  }
}

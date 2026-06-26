import '../models/period_record.dart';
import '../../../shared/utils/date_utils.dart';

/// 日期范围
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

/// 周期预测结果
class PredictionResult {
  final DateTime nextStartDate;
  final int avgCycleLength;
  final DateTime ovulationDay;
  final DateRange fertileWindow;
  final int currentDayInCycle;

  PredictionResult({
    required this.nextStartDate,
    required this.avgCycleLength,
    required this.ovulationDay,
    required this.fertileWindow,
    required this.currentDayInCycle,
  });
}

/// 周期预测服务
class PredictionService {
  static final PredictionService instance = PredictionService._();
  PredictionService._();

  /// 计算加权平均周期长度
  int predictNextCycle(List<PeriodRecord> records) {
    // 取最近6个有效周期长度
    final cycleLengths = records
        .where((r) => r.cycleLength != null)
        .map((r) => r.cycleLength!)
        .toList()
        .reversed
        .take(6)
        .toList();

    if (cycleLengths.length < 3) return 28; // 默认值

    // 加权计算: 最近1个权重3, 最近2个权重2, 最近3-6个权重1
    final weights = [3, 2, 1, 1, 1, 1];
    double sum = 0;
    double weightSum = 0;

    for (int i = 0; i < cycleLengths.length; i++) {
      sum += cycleLengths[i] * weights[i];
      weightSum += weights[i];
    }

    return (sum / weightSum).round();
  }

  /// 生成完整预测结果
  /// [today] 可注入固定日期用于测试
  PredictionResult? predict(List<PeriodRecord> records, {DateTime? today}) {
    if (records.isEmpty) return null;

    final now = today ?? DateTime.now();
    final sorted = records.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final lastRecord = sorted.last;
    final avgCycle = predictNextCycle(sorted);

    // 循环推进 nextStartDate 直到落在今天或未来
    var nextStartDate = lastRecord.startDate.add(Duration(days: avgCycle));
    while (nextStartDate.isBefore(AppDateUtils.dateOnly(now))) {
      nextStartDate = nextStartDate.add(Duration(days: avgCycle));
    }

    final ovulationDay = nextStartDate.subtract(const Duration(days: 14));
    final fertileWindow = DateRange(
      start: ovulationDay.subtract(const Duration(days: 5)),
      end: ovulationDay.add(const Duration(days: 1)),
    );

    // 当前周期天数（从最后一次经期开始到今天）
    final currentDay = AppDateUtils.dateOnly(now)
        .difference(AppDateUtils.dateOnly(lastRecord.startDate))
        .inDays + 1;

    return PredictionResult(
      nextStartDate: nextStartDate,
      avgCycleLength: avgCycle,
      ovulationDay: ovulationDay,
      fertileWindow: fertileWindow,
      currentDayInCycle: currentDay,
    );
  }
}
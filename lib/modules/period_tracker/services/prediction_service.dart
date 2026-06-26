import '../models/period_record.dart';
import '../../../shared/utils/date_utils.dart';

/// 预测算法常量配置 — 集中管理，改一处全局生效
class PredictionConfig {
  /// 默认周期长度（少于 3 条记录时使用）
  static const int defaultCycleLength = 28;

  /// 最少需要多少条有效记录才能加权计算
  static const int minRecordsForWeighted = 3;

  /// 加权窗口大小
  static const int maxRecordsForWeight = 6;

  /// 排卵日偏移（下次经期前 N 天）
  static const int ovulationOffset = 14;

  /// 易孕期窗口：排卵前 N 天
  static const int fertileWindowBefore = 5;

  /// 易孕期窗口：排卵后 N 天
  static const int fertileWindowAfter = 1;

  /// 预测经期默认持续天数
  static const int defaultPeriodDuration = 5;
}

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
    final cycleLengths = records
        .where((r) => r.cycleLength != null)
        .map((r) => r.cycleLength!)
        .toList()
        .reversed
        .take(PredictionConfig.maxRecordsForWeight)
        .toList();

    if (cycleLengths.length < PredictionConfig.minRecordsForWeighted) {
      return PredictionConfig.defaultCycleLength;
    }

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

    final ovulationDay =
        nextStartDate.subtract(const Duration(days: PredictionConfig.ovulationOffset));
    final fertileWindow = DateRange(
      start: ovulationDay
          .subtract(const Duration(days: PredictionConfig.fertileWindowBefore)),
      end: ovulationDay
          .add(const Duration(days: PredictionConfig.fertileWindowAfter)),
    );

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
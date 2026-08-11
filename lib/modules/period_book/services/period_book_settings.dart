import '../../../core/storage/database_service.dart';

/// 周期记账全局设置 — 发薪日配置
class PeriodBookSettings {
  static final PeriodBookSettings instance = PeriodBookSettings._();
  PeriodBookSettings._();

  final DatabaseService _db = DatabaseService.instance;

  static const String _keyPayday = 'period_book_payday';
  static const int _defaultPayday = 10;

  int? _cachedPayday;

  /// 获取发薪日（1~31）
  Future<int> getPayday() async {
    if (_cachedPayday != null) return _cachedPayday!;
    final rows = await _db
        .query('app_settings', where: "key = ?", whereArgs: [_keyPayday]);
    if (rows.isEmpty) {
      _cachedPayday = _defaultPayday;
      return _defaultPayday;
    }
    final val = int.tryParse(rows.first['value'] as String);
    _cachedPayday =
        (val != null && val >= 1 && val <= 31) ? val : _defaultPayday;
    return _cachedPayday!;
  }

  /// 设置发薪日（1~31）
  Future<void> setPayday(int day) async {
    if (day < 1 || day > 31) return;
    _cachedPayday = day;
    await _db.upsertSetting(_keyPayday, day.toString());
  }

  /// 清除缓存（设置修改后调用）
  void clearCache() {
    _cachedPayday = null;
  }

  /// 计算 year 年 month 月的实际发薪日
  /// （发薪日超过当月天数时，取当月最后一天，如 31 号在 2/4/6/9/11 月）
  DateTime _paydayInMonth(int year, int month, int payday) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final day = payday > daysInMonth ? daysInMonth : payday;
    return DateTime(year, month, day);
  }

  /// 获取自 from 之后（不含）最近的一个发薪日
  Future<DateTime> getNextPayday(DateTime from) async {
    final payday = await getPayday();
    final base = DateTime(from.year, from.month, from.day);
    var candidate = _paydayInMonth(base.year, base.month, payday);
    if (!candidate.isAfter(base)) {
      candidate = _paydayInMonth(base.year, base.month + 1, payday);
    }
    return candidate;
  }

  /// 根据开始日期计算对应周期的结束日期（下一个发薪日前一天）
  Future<DateTime> getPeriodEndDate(DateTime start) async {
    final nextPayday = await getNextPayday(start);
    return nextPayday.subtract(const Duration(days: 1));
  }

  /// 当月发薪日（默认开始日期）
  Future<DateTime> getDefaultStartDate() async {
    final payday = await getPayday();
    final now = DateTime.now();
    return _paydayInMonth(now.year, now.month, payday);
  }

  /// 下月发薪日前一天（默认结束日期）
  Future<DateTime> getDefaultEndDate() async {
    final start = await getDefaultStartDate();
    return getPeriodEndDate(start);
  }
}

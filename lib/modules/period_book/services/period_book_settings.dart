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

  /// 当月发薪日
  Future<DateTime> getDefaultStartDate() async {
    final payday = await getPayday();
    final now = DateTime.now();
    return DateTime(now.year, now.month, payday);
  }

  /// 下月发薪日前一天（默认结束日期）
  Future<DateTime> getDefaultEndDate() async {
    final payday = await getPayday();
    final now = DateTime.now();
    // 下月发薪日
    var nextMonth = now.month + 1;
    var nextYear = now.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    // 下月发薪日前一天
    final nextPayday = DateTime(nextYear, nextMonth, payday);
    return nextPayday.subtract(const Duration(days: 1));
  }
}

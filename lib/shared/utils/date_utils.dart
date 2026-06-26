/// 日期工具类
class AppDateUtils {
  /// 将 DateTime 标准化为仅日期部分（去除时分秒毫秒）
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 判断 date 是否在 [start, end] 闭区间内（使用 date-only 比较）
  static bool isDateInRangeInclusive(DateTime date, DateTime start, DateTime end) {
    final d = dateOnly(date);
    final s = dateOnly(start);
    final e = dateOnly(end);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  /// 格式化月份显示
  static String formatMonth(DateTime date) {
    return '${date.year}年${date.month}月';
  }

  /// 格式化日期显示
  static String formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  /// 格式化完整日期
  static String formatFullDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 获取某月第一天
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 获取某月最后一天
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// 获取两个日期之间的天数差
  static int daysBetween(DateTime a, DateTime b) {
    return b.difference(a).inDays;
  }

  /// 判断是否同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断是否同一个月
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// DateTime 转 ISO 8601 字符串
  static String toIso8601String(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  /// ISO 8601 字符串 转 DateTime
  static DateTime fromIso8601String(String str) {
    return DateTime.parse(str);
  }
}
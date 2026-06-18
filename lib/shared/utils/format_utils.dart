/// 格式化工具类
class FormatUtils {
  /// 格式化金额
  static String formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return '¥${amount.truncate().abs()}';
    }
    return '¥${amount.abs().toStringAsFixed(2)}';
  }

  /// 格式化金额（带符号）
  static String formatAmountWithSign(double amount, {bool isExpense = true}) {
    final sign = isExpense ? '-' : '+';
    if (amount == amount.truncateToDouble()) {
      return '$sign¥${amount.truncate()}';
    }
    return '$sign¥${amount.toStringAsFixed(2)}';
  }

  /// 格式化百分比
  static String formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}
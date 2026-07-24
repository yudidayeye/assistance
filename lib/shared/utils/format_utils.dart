/// 格式化工具类
class FormatUtils {
  /// 格式化交易金额（始终显示为正值，用于收入/支出条目）
  static String formatAmount(double amount) {
    final v = amount.abs();
    if (v == v.truncateToDouble()) {
      return '¥${v.truncate()}';
    }
    return '¥${v.toStringAsFixed(2)}';
  }

  /// 格式化结余/净额（保留正负号，用于余额显示）
  static String formatBalance(double amount) {
    if (amount == amount.truncateToDouble()) {
      return '¥${amount.truncate()}';
    }
    return '¥${amount.toStringAsFixed(2)}';
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

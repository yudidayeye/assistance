import '../models/category.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';
import 'category_service.dart';

/// 分类统计数据
class CategoryStats {
  final Category category;
  final double total;
  final double percent;

  CategoryStats({required this.category, required this.total, required this.percent});
}

/// 月度统计服务
class StatsService {
  static final StatsService instance = StatsService._();
  StatsService._();

  final TransactionService _txnService = TransactionService.instance;
  final CategoryService _catService = CategoryService.instance;

  /// 获取某月支出分类统计
  Future<List<CategoryStats>> getExpenseStatsByCategory(DateTime month) async {
    final transactions = await _txnService.getTransactionsByMonth(month);
    final expenseTxns = transactions.where((t) => t.type == TransactionType.expense);

    final totalExpense = expenseTxns.fold(0.0, (sum, t) => sum + t.amount);
    final Map<String, double> categoryTotals = {};

    for (final t in expenseTxns) {
      categoryTotals[t.categoryId] = (categoryTotals[t.categoryId] ?? 0) + t.amount;
    }

    final List<CategoryStats> stats = [];
    for (final entry in categoryTotals.entries) {
      final cat = await _catService.getCategory(entry.key);
      if (cat != null) {
        stats.add(CategoryStats(
          category: cat,
          total: entry.value,
          percent: totalExpense > 0 ? entry.value / totalExpense : 0,
        ));
      }
    }

    stats.sort((a, b) => b.total.compareTo(a.total));
    return stats;
  }

  /// 获取某月收支概览
  Future<Map<String, double>> getMonthOverview(DateTime month) async {
    final expense = await _txnService.getMonthExpenseTotal(month);
    final income = await _txnService.getMonthIncomeTotal(month);
    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }
}
import '../../../core/storage/database_service.dart';
import '../models/category.dart';

/// 分类统计数据
class CategoryStats {
  final Category category;
  final double total;
  final double percent;

  CategoryStats({required this.category, required this.total, required this.percent});
}

/// 月度统计服务 — 使用 SQL 聚合，避免 Dart 侧 fold 和逐条分类查询
class StatsService {
  static final StatsService instance = StatsService._();
  StatsService._();

  final DatabaseService _db = DatabaseService.instance;

  /// 获取某月支出分类统计（SQL GROUP BY + join 分类表）
  Future<List<CategoryStats>> getExpenseStatsByCategory(DateTime month) async {
    final year = month.year;
    final mon = month.month;
    final datePrefix = '$year-${mon.toString().padLeft(2, '0')}';

    // 子查询：支出分类合计 + 分类原始信息
    final rows = await _db.rawQuery('''
      SELECT
        c.id, c.name, c.type, c.icon_code_point, c.icon_font_family,
        c.is_custom, c.sort_order,
        COALESCE(t.total, 0) AS total
      FROM mod_accounting_categories c
      LEFT JOIN (
        SELECT category_id, SUM(amount) AS total
        FROM mod_accounting_transactions
        WHERE type = 'expense' AND date LIKE ?
        GROUP BY category_id
      ) t ON c.id = t.category_id
      WHERE c.type = 'expense'
      ORDER BY total DESC
    ''', ['$datePrefix%']);

    final totalExpense = rows.fold(0.0, (s, r) => s + (r['total'] as num).toDouble());
    final stats = <CategoryStats>[];

    for (final row in rows) {
      final cat = Category.fromMap(row);
      final total = (row['total'] as num).toDouble();
      if (total <= 0) continue;
      stats.add(CategoryStats(
        category: cat,
        total: total,
        percent: totalExpense > 0 ? total / totalExpense : 0,
      ));
    }

    return stats;
  }

  /// 获取某月收支概览（SQL SUM 聚合）
  Future<Map<String, double>> getMonthOverview(DateTime month) async {
    final year = month.year;
    final mon = month.month.toString().padLeft(2, '0');
    final datePrefix = '$year-$mon';

    final rows = await _db.rawQuery('''
      SELECT type, SUM(amount) AS total
      FROM mod_accounting_transactions
      WHERE date LIKE ?
      GROUP BY type
    ''', ['$datePrefix%']);

    double income = 0;
    double expense = 0;
    for (final row in rows) {
      final total = (row['total'] as num).toDouble();
      if (row['type'] == 'income') {
        income = total;
      } else {
        expense = total;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }
}

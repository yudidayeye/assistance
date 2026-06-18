import '../../../core/storage/database_service.dart';
import '../models/transaction.dart';

/// 交易记录服务
class TransactionService {
  static final TransactionService instance = TransactionService._();
  TransactionService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_accounting_transactions';

  /// 获取某月所有交易
  Future<List<Transaction>> getTransactionsByMonth(DateTime month) async {
    final start = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final endMonth = DateTime(month.year, month.month + 1, 0);
    final end = '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}-${endMonth.day.toString().padLeft(2, '0')}';

    final rows = await _db.query(
      _table,
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((r) => Transaction.fromMap(r)).toList();
  }

  /// 获取今日支出总额
  Future<double> getTodayExpenseTotal() async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final rows = await _db.query(
      _table,
      where: 'date = ? AND type = ?',
      whereArgs: [todayStr, 'expense'],
    );
    return rows.fold<double>(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
  }

  /// 获取某月支出总额
  Future<double> getMonthExpenseTotal(DateTime month) async {
    final start = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final endMonth = DateTime(month.year, month.month + 1, 0);
    final end = '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}-${endMonth.day.toString().padLeft(2, '0')}';

    final rows = await _db.query(
      _table,
      where: 'date >= ? AND date <= ? AND type = ?',
      whereArgs: [start, end, 'expense'],
    );
    return rows.fold<double>(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
  }

  /// 获取某月收入总额
  Future<double> getMonthIncomeTotal(DateTime month) async {
    final start = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final endMonth = DateTime(month.year, month.month + 1, 0);
    final end = '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}-${endMonth.day.toString().padLeft(2, '0')}';

    final rows = await _db.query(
      _table,
      where: 'date >= ? AND date <= ? AND type = ?',
      whereArgs: [start, end, 'income'],
    );
    return rows.fold<double>(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
  }

  /// 插入交易
  Future<void> insertTransaction(Transaction txn) async {
    await _db.insert(_table, txn.toMap());
  }

  /// 更新交易
  Future<void> updateTransaction(Transaction txn) async {
    await _db.update(
      _table,
      txn.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  /// 删除交易
  Future<void> deleteTransaction(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 获取单条交易
  Future<Transaction?> getTransaction(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Transaction.fromMap(rows.first);
  }
}
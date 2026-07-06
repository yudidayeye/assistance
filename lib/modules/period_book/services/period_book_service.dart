import '../../../core/storage/database_service.dart';
import '../models/period_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';

/// 周期计算结果
class PeriodCalculations {
  final double totalBase; // 总本金 = 初始 + 追加
  final double shoppingTotal; // 购物总额
  final double otherTotal; // 其他总额
  final double? balance; // 余额（手动输入）
  final double? livingTotal; // 生活支出（倒推）
  final double? livingDailyAvg; // 生活日均
  final int totalDays; // 周期天数

  const PeriodCalculations({
    required this.totalBase,
    required this.shoppingTotal,
    required this.otherTotal,
    required this.balance,
    required this.livingTotal,
    required this.livingDailyAvg,
    required this.totalDays,
  });
}

/// 周期记账数据服务 — CRUD + 业务计算
class PeriodBookService {
  static final PeriodBookService instance = PeriodBookService._();
  PeriodBookService._();

  final DatabaseService _db = DatabaseService.instance;

  // ═══════════════════════════════════════════════════════════
  // 周期 CRUD
  // ══════════════════════════════════════════════════════════

  /// 新建周期，返回 id
  Future<int> createPeriod({
    required String startDate,
    required String endDate,
    required double baseAmount,
    double? balance,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('mod_period_book_periods', {
      'start_date': startDate,
      'end_date': endDate,
      'base_amount': baseAmount,
      'balance': balance,
      'is_closed': 0,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  /// 获取当前进行中的周期（is_closed=0，最新创建的）
  Future<PeriodRecord?> getOngoingPeriod() async {
    final rows = await _db.query(
      'mod_period_book_periods',
      where: 'is_closed = 0',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodRecord.fromMap(rows.first);
  }

  /// 获取所有周期（按 start_date 倒序）
  Future<List<PeriodRecord>> getAllPeriods() async {
    final rows = await _db.query(
      'mod_period_book_periods',
      orderBy: 'start_date DESC',
    );
    return rows.map(PeriodRecord.fromMap).toList();
  }

  /// 获取已关闭周期列表
  Future<List<PeriodRecord>> getClosedPeriods() async {
    final rows = await _db.query(
      'mod_period_book_periods',
      where: 'is_closed = 1',
      orderBy: 'start_date DESC',
    );
    return rows.map(PeriodRecord.fromMap).toList();
  }

  /// 按 ID 获取周期
  Future<PeriodRecord?> getPeriodById(int id) async {
    final rows = await _db.query(
      'mod_period_book_periods',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return PeriodRecord.fromMap(rows.first);
  }

  /// 更新周期字段
  Future<void> updatePeriod(int id, Map<String, dynamic> values) async {
    values['updated_at'] = DateTime.now().toIso8601String();
    await _db.update(
      'mod_period_book_periods',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 标记周期为已结束（同时将该周期之前的所有未关闭周期也关闭）
  Future<void> closePeriod(int id) async {
    await updatePeriod(id, {'is_closed': 1});
  }

  /// 删除周期及关联数据
  Future<void> deletePeriod(int id) async {
    await _db.delete('mod_period_book_expenses',
        where: 'period_id = ?', whereArgs: [id]);
    await _db.delete('mod_period_book_additions',
        where: 'period_id = ?', whereArgs: [id]);
    await _db.delete('mod_period_book_periods',
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════
  // 追加记录 CRUD
  // ═══════════════════════════════════════════════════════════

  Future<int> addAddition(int periodId, double amount, String reason) async {
    final now = DateTime.now().toIso8601String();
    return _db.insert('mod_period_book_additions', {
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'created_at': now,
    });
  }

  Future<List<AdditionRecord>> getAdditionsByPeriod(int periodId) async {
    final rows = await _db.query(
      'mod_period_book_additions',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'created_at ASC',
    );
    return rows.map(AdditionRecord.fromMap).toList();
  }

  Future<void> deleteAddition(int id) async {
    await _db.delete('mod_period_book_additions',
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // 支出明细 CRUD
  // ═══════════════════════════════════════════════════════════

  Future<int> addExpense(
    int periodId,
    String category,
    double amount,
    String description,
  ) async {
    final now = DateTime.now().toIso8601String();
    return _db.insert('mod_period_book_expenses', {
      'period_id': periodId,
      'category': category,
      'amount': amount,
      'description': description,
      'created_at': now,
    });
  }

  Future<List<ExpenseRecord>> getExpensesByPeriod(int periodId) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<List<ExpenseRecord>> getExpensesByCategory(
    int periodId,
    String category,
  ) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'period_id = ? AND category = ?',
      whereArgs: [periodId, category],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<void> deleteExpense(int id) async {
    await _db.delete('mod_period_book_expenses',
        where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════
  // 业务计算
  // ═══════════════════════════════════════════════════════════

  /// 获取周期的完整计算数据
  Future<PeriodCalculations> getPeriodCalculations(int periodId) async {
    final period = await getPeriodById(periodId);
    if (period == null) {
      throw Exception('周期不存在: $periodId');
    }

    // 追加金额总和
    final additions = await getAdditionsByPeriod(periodId);
    final totalAdditions =
        additions.fold<double>(0, (sum, a) => sum + a.amount);
    final totalBase = period.baseAmount + totalAdditions;

    // 支出分类汇总
    final expenses = await getExpensesByPeriod(periodId);
    double shoppingTotal = 0;
    double otherTotal = 0;
    for (final e in expenses) {
      if (e.category == 'shopping') {
        shoppingTotal += e.amount;
      } else {
        otherTotal += e.amount;
      }
    }

    final balance = period.balance;
    final totalDays = period.totalDays;

    // 余额未填 → 生活相关显示缺省
    double? livingTotal;
    double? livingDailyAvg;
    if (balance != null) {
      livingTotal = totalBase - shoppingTotal - otherTotal - balance;
      livingDailyAvg = totalDays > 0 ? livingTotal / totalDays : 0;
    }

    return PeriodCalculations(
      totalBase: totalBase,
      shoppingTotal: shoppingTotal,
      otherTotal: otherTotal,
      balance: balance,
      livingTotal: livingTotal,
      livingDailyAvg: livingDailyAvg,
      totalDays: totalDays,
    );
  }
}

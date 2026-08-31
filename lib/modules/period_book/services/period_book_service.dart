import 'package:flutter/foundation.dart';
import '../../../core/storage/database_service.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';
import '../models/large_addition_record.dart';
import '../models/large_expense_record.dart';

/// 阶段计算结果
class StageCalculations {
  final double baseAmount; // 阶段本金 = 上阶段余额 + 本阶段追加
  final double additionsTotal; // 本阶段追加总额
  final double shoppingTotal; // 本阶段购物总额
  final double otherTotal; // 本阶段其他总额
  final double? balance; // 本阶段余额（手动输入）
  final double? livingTotal; // 本阶段生活支出（倒推）
  final double? livingDailyAvg; // 本阶段生活日均
  final int totalDays; // 本阶段天数

  const StageCalculations({
    required this.baseAmount,
    required this.additionsTotal,
    required this.shoppingTotal,
    required this.otherTotal,
    required this.balance,
    required this.livingTotal,
    required this.livingDailyAvg,
    required this.totalDays,
  });
}

/// 周期计算结果（汇总所有阶段）
class PeriodCalculations {
  final double totalBase; // 总本金 = 初始 + 所有追加
  final double shoppingTotal; // 所有阶段购物总额
  final double otherTotal; // 所有阶段其他总额
  final double? balance; // 最新阶段余额（未填显示 —）
  final double? livingTotal; // 所有阶段生活支出总和
  final double? livingDailyAvg; // 所有阶段生活日均总和
  final int totalDays; // 周期总天数
  final List<StageCalculations> stages; // 各阶段计算结果

  const PeriodCalculations({
    required this.totalBase,
    required this.shoppingTotal,
    required this.otherTotal,
    required this.balance,
    required this.livingTotal,
    required this.livingDailyAvg,
    required this.totalDays,
    required this.stages,
  });
}

/// 周期记账数据服务 — CRUD + 业务计算
class PeriodBookService extends ChangeNotifier {
  static final PeriodBookService instance = PeriodBookService._();
  PeriodBookService._();

  final DatabaseService _db = DatabaseService.instance;

  void _notifyChanged() => notifyListeners();

  /// 外部通知数据已变更（如导入后刷新 UI）
  void notifyChanged() => notifyListeners();

  // ══════════════════════════════════════════════════════════
  // 周期 CRUD
  // ══════════════════════════════════════════════════════════

  /// 新建周期（自动创建阶段），返回 id
  Future<int> createPeriod({
    required String startDate,
    required String endDate,
    required double baseAmount,
  }) async {
    // 检查日期重叠
    if (await hasDateOverlap(startDate, endDate)) {
      throw Exception('日期与已有周期重叠');
    }

    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('mod_period_book_periods', {
      'start_date': startDate,
      'end_date': endDate,
      'base_amount': baseAmount,
      'is_closed': 0,
      'created_at': now,
      'updated_at': now,
    });

    // 自动创建阶段
    await _autoCreateStages(id, startDate, endDate);

    _notifyChanged();
    return id;
  }

  /// 获取当前进行中的周期（is_closed=0，最新的）
  /// 如果周期 endDate 已过，自动关闭并返回 null
  Future<PeriodRecord?> getOngoingPeriod() async {
    final rows = await _db.query(
      'mod_period_book_periods',
      where: 'is_closed = 0',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final period = PeriodRecord.fromMap(rows.first);

    // 检查周期是否已过期（endDate < 今天），过期则自动关闭
    final endDate = DateTime.parse(period.endDate);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (endDate.isBefore(today)) {
      await closePeriod(period.id!);
      return null;
    }

    return period;
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
    _notifyChanged();
  }

  /// 标记周期为已结束
  Future<void> closePeriod(int id) async {
    await updatePeriod(id, {'is_closed': 1});
  }

  /// 删除周期及关联数据
  Future<void> deletePeriod(int id) async {
    // 先删除阶段（级联删除 additions 和 expenses）
    await _db.delete('mod_period_book_stages',
        where: 'period_id = ?', whereArgs: [id]);
    // 删除大额记录
    await _db.delete('mod_period_book_large_additions',
        where: 'period_id = ?', whereArgs: [id]);
    await _db.delete('mod_period_book_large_expenses',
        where: 'period_id = ?', whereArgs: [id]);
    await _db
        .delete('mod_period_book_periods', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 检查日期是否与已有周期重叠
  Future<bool> hasDateOverlap(String startDate, String endDate,
      {int? excludeId}) async {
    final rows = await _db.query(
      'mod_period_book_periods',
      where: 'start_date <= ? AND end_date >= ?',
      whereArgs: [endDate, startDate],
    );
    for (final row in rows) {
      final id = row['id'] as int;
      if (excludeId == null || id != excludeId) {
        return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════
  // 阶段 CRUD
  // ══════════════════════════════════════════════════════════

  /// 自动创建阶段（按周拆分）
  Future<void> _autoCreateStages(
      int periodId, String startDate, String endDate) async {
    final stages = _generateStages(periodId, startDate, endDate);
    for (final stage in stages) {
      await _db.insert('mod_period_book_stages', stage.toMap());
    }
  }

  /// 生成阶段列表（按自然周划分：周一到周日）
  List<StageRecord> _generateStages(
      int periodId, String startDate, String endDate) {
    final stages = <StageRecord>[];
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final now = DateTime.now().toIso8601String();

    var current = start;
    var sortOrder = 1;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      // 计算当前阶段的结束日期
      DateTime stageEnd;

      if (sortOrder == 1) {
        // 第一个阶段：从开始日期到当周周日
        // weekday: Monday=1, Sunday=7
        final daysUntilSunday = 7 - current.weekday;
        final sundayOfFirstWeek = current.add(Duration(days: daysUntilSunday));

        if (sundayOfFirstWeek.isAfter(end)) {
          // 如果当周周日超过结束日期，则到结束日期
          stageEnd = end;
        } else {
          stageEnd = sundayOfFirstWeek;
        }
      } else {
        // 后续阶段：从周一开始
        // 计算本周一
        final daysFromMonday = current.weekday - 1;
        final mondayOfThisWeek =
            current.subtract(Duration(days: daysFromMonday));

        // 本阶段从周一开始，到周日结束
        final sundayOfThisWeek = mondayOfThisWeek.add(const Duration(days: 6));

        if (sundayOfThisWeek.isAfter(end)) {
          // 如果本周日超过结束日期，则到结束日期
          stageEnd = end;
        } else {
          stageEnd = sundayOfThisWeek;
        }
      }

      stages.add(StageRecord(
        periodId: periodId,
        startDate: _formatDate(current),
        endDate: _formatDate(stageEnd),
        balance: null,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      ));

      current = stageEnd.add(const Duration(days: 1));
      sortOrder++;
    }

    return stages;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取周期的所有阶段（按 sort_order 排序）
  Future<List<StageRecord>> getStagesByPeriod(int periodId) async {
    final rows = await _db.query(
      'mod_period_book_stages',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(StageRecord.fromMap).toList();
  }

  /// 按 ID 获取阶段
  Future<StageRecord?> getStageById(int id) async {
    final rows = await _db.query(
      'mod_period_book_stages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return StageRecord.fromMap(rows.first);
  }

  /// 添加阶段（手动添加）
  Future<int> addStage({
    required int periodId,
    required String startDate,
    required String endDate,
    required int sortOrder,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('mod_period_book_stages', {
      'period_id': periodId,
      'start_date': startDate,
      'end_date': endDate,
      'balance': null,
      'sort_order': sortOrder,
      'created_at': now,
      'updated_at': now,
    });
    _notifyChanged();
    return id;
  }

  /// 更新阶段
  Future<void> updateStage(int id, Map<String, dynamic> values) async {
    values['updated_at'] = DateTime.now().toIso8601String();
    await _db.update(
      'mod_period_book_stages',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  /// 更新阶段余额
  Future<void> updateStageBalance(int id, double? balance) async {
    await updateStage(id, {'balance': balance});
  }

  /// 删除阶段及关联数据
  Future<void> deleteStage(int id) async {
    await _db.delete('mod_period_book_expenses',
        where: 'stage_id = ?', whereArgs: [id]);
    await _db.delete('mod_period_book_additions',
        where: 'stage_id = ?', whereArgs: [id]);
    await _db
        .delete('mod_period_book_stages', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 获取最后一个阶段
  Future<StageRecord?> getLastStage(int periodId) async {
    final rows = await _db.query(
      'mod_period_book_stages',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'sort_order DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StageRecord.fromMap(rows.first);
  }

  // ══════════════════════════════════════════════════════════
  // 追加记录 CRUD
  // ══════════════════════════════════════════════════════════

  Future<int> addAddition(int stageId, double amount, String reason) async {
    final now = DateTime.now().toIso8601String();
    // 获取当前最大 sort_order
    final existingAdditions = await getAdditionsByStage(stageId);
    final sortOrder = existingAdditions.isNotEmpty
        ? existingAdditions
                .map((a) => a.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1
        : 0;

    final id = await _db.insert('mod_period_book_additions', {
      'stage_id': stageId,
      'amount': amount,
      'reason': reason,
      'sort_order': sortOrder,
      'created_at': now,
    });
    _notifyChanged();
    return id;
  }

  Future<List<AdditionRecord>> getAdditionsByStage(int stageId) async {
    final rows = await _db.query(
      'mod_period_book_additions',
      where: 'stage_id = ?',
      whereArgs: [stageId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(AdditionRecord.fromMap).toList();
  }

  /// 获取周期所有阶段的追加记录（批量查询，性能优化）
  Future<List<AdditionRecord>> getAdditionsByPeriod(int periodId) async {
    final stages = await getStagesByPeriod(periodId);
    if (stages.isEmpty) return [];

    final stageIds = stages.map((s) => s.id!).toList();
    final placeholders = stageIds.map((_) => '?').join(',');

    final rows = await _db.rawQuery(
      'SELECT * FROM mod_period_book_additions WHERE stage_id IN ($placeholders) ORDER BY sort_order ASC, created_at ASC',
      stageIds,
    );
    return rows.map(AdditionRecord.fromMap).toList();
  }

  Future<void> deleteAddition(int id) async {
    await _db
        .delete('mod_period_book_additions', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 更新追加记录（金额、原因）
  Future<void> updateAddition(int id, {double? amount, String? reason}) async {
    final data = <String, dynamic>{};
    if (amount != null) data['amount'] = amount;
    if (reason != null) data['reason'] = reason;
    if (data.isEmpty) return;
    await _db.update('mod_period_book_additions', data,
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 批量更新追加记录排序
  Future<void> updateAdditionsOrder(List<AdditionRecord> additions) async {
    for (var i = 0; i < additions.length; i++) {
      final addition = additions[i];
      if (addition.id != null) {
        await _db.update('mod_period_book_additions', {'sort_order': i},
            where: 'id = ?', whereArgs: [addition.id]);
      }
    }
    _notifyChanged();
  }

  // ══════════════════════════════════════════════════════════
  // 支出明细 CRUD
  // ══════════════════════════════════════════════════════════

  Future<int> addExpense(
    int stageId,
    String category,
    double amount,
    String description,
  ) async {
    final now = DateTime.now().toIso8601String();
    // 获取当前最大 sort_order
    final existingExpenses = await getExpensesByStage(stageId);
    final sortOrder = existingExpenses.isNotEmpty
        ? existingExpenses
                .map((e) => e.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1
        : 0;

    return _db.insert('mod_period_book_expenses', {
      'stage_id': stageId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': now,
    }).then((id) {
      _notifyChanged();
      return id;
    });
  }

  /// 批量添加支出
  Future<void> batchAddExpenses(
    int stageId,
    List<Map<String, dynamic>> expenses,
  ) async {
    final now = DateTime.now().toIso8601String();
    // 获取当前最大 sort_order
    final existingExpenses = await getExpensesByStage(stageId);
    var sortOrder = existingExpenses.isNotEmpty
        ? existingExpenses
                .map((e) => e.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1
        : 0;

    for (final expense in expenses) {
      await _db.insert('mod_period_book_expenses', {
        'stage_id': stageId,
        'category': expense['category'],
        'amount': expense['amount'],
        'description': expense['description'],
        'sort_order': sortOrder,
        'created_at': now,
      });
      sortOrder++;
    }
    _notifyChanged();
  }

  Future<List<ExpenseRecord>> getExpensesByStage(int stageId) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'stage_id = ?',
      whereArgs: [stageId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  /// 获取周期所有阶段的支出记录（批量查询，性能优化）
  Future<List<ExpenseRecord>> getExpensesByPeriod(int periodId) async {
    final stages = await getStagesByPeriod(periodId);
    if (stages.isEmpty) return [];

    final stageIds = stages.map((s) => s.id!).toList();
    final placeholders = stageIds.map((_) => '?').join(',');

    final rows = await _db.rawQuery(
      'SELECT * FROM mod_period_book_expenses WHERE stage_id IN ($placeholders) ORDER BY sort_order ASC, created_at ASC',
      stageIds,
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<List<ExpenseRecord>> getExpensesByCategory(
    int stageId,
    String category,
  ) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'stage_id = ? AND category = ?',
      whereArgs: [stageId, category],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<void> deleteExpense(int id) async {
    await _db
        .delete('mod_period_book_expenses', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 更新支出记录（分类、金额、描述）
  Future<void> updateExpense(int id,
      {String? category, double? amount, String? description}) async {
    final data = <String, dynamic>{};
    if (category != null) data['category'] = category;
    if (amount != null) data['amount'] = amount;
    if (description != null) data['description'] = description;
    if (data.isEmpty) return;
    await _db.update('mod_period_book_expenses', data,
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 批量更新支出排序
  Future<void> updateExpensesOrder(List<ExpenseRecord> expenses) async {
    for (var i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      if (expense.id != null) {
        await _db.update('mod_period_book_expenses', {'sort_order': i},
            where: 'id = ?', whereArgs: [expense.id]);
      }
    }
    _notifyChanged();
  }

  // ══════════════════════════════════════════════════════════
  // 大额记录 CRUD（周期级，不计入总本金和总支出）
  // ══════════════════════════════════════════════════════════

  // --- 大额追加 ---

  Future<int> addLargeAddition(
      int periodId, double amount, String reason) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('mod_period_book_large_additions', {
      'period_id': periodId,
      'amount': amount,
      'reason': reason,
      'created_at': now,
    });
    _notifyChanged();
    return id;
  }

  Future<List<LargeAdditionRecord>> getLargeAdditionsByPeriod(
      int periodId) async {
    final rows = await _db.query(
      'mod_period_book_large_additions',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(LargeAdditionRecord.fromMap).toList();
  }

  Future<void> deleteLargeAddition(int id) async {
    await _db.delete('mod_period_book_large_additions',
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  /// 更新大额追加记录
  Future<void> updateLargeAddition(int id,
      {double? amount, String? reason, int? sortOrder}) async {
    final data = <String, dynamic>{};
    if (amount != null) data['amount'] = amount;
    if (reason != null) data['reason'] = reason;
    if (sortOrder != null) data['sort_order'] = sortOrder;
    if (data.isEmpty) return;
    await _db.update('mod_period_book_large_additions', data,
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<void> updateLargeAdditionsOrder(
      List<LargeAdditionRecord> additions) async {
    for (var i = 0; i < additions.length; i++) {
      final addition = additions[i];
      if (addition.id != null) {
        await _db.update('mod_period_book_large_additions', {'sort_order': i},
            where: 'id = ?', whereArgs: [addition.id]);
      }
    }
    _notifyChanged();
  }

  // --- 大额支出 ---

  Future<int> addLargeExpense(
    int periodId,
    String category,
    double amount,
    String description,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = await getLargeExpensesByPeriod(periodId);
    final sortOrder = existing.isNotEmpty
        ? existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1
        : 0;

    final id = await _db.insert('mod_period_book_large_expenses', {
      'period_id': periodId,
      'category': category,
      'amount': amount,
      'description': description,
      'sort_order': sortOrder,
      'created_at': now,
    });
    _notifyChanged();
    return id;
  }

  Future<List<LargeExpenseRecord>> getLargeExpensesByPeriod(
      int periodId) async {
    final rows = await _db.query(
      'mod_period_book_large_expenses',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(LargeExpenseRecord.fromMap).toList();
  }

  Future<void> deleteLargeExpense(int id) async {
    await _db.delete('mod_period_book_large_expenses',
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<void> updateLargeExpense(int id,
      {String? category,
      double? amount,
      String? description,
      int? sortOrder}) async {
    final data = <String, dynamic>{};
    if (category != null) data['category'] = category;
    if (amount != null) data['amount'] = amount;
    if (description != null) data['description'] = description;
    if (sortOrder != null) data['sort_order'] = sortOrder;
    if (data.isEmpty) return;
    await _db.update('mod_period_book_large_expenses', data,
        where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<void> updateLargeExpensesOrder(
      List<LargeExpenseRecord> expenses) async {
    for (var i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      if (expense.id != null) {
        await _db.update('mod_period_book_large_expenses', {'sort_order': i},
            where: 'id = ?', whereArgs: [expense.id]);
      }
    }
    _notifyChanged();
  }

  /// 获取大额记录净额（追加总额 - 支出总额）
  Future<double> getLargeItemsNet(int periodId) async {
    final additions = await getLargeAdditionsByPeriod(periodId);
    final expenses = await getLargeExpensesByPeriod(periodId);
    final additionsTotal =
        additions.fold<double>(0, (sum, a) => sum + a.amount);
    final expensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    return additionsTotal - expensesTotal;
  }

  // ══════════════════════════════════════════════════════════
  // 业务计算
  // ══════════════════════════════════════════════════════════

  /// 获取阶段的计算数据
  Future<StageCalculations> getStageCalculations(
      int stageId, double previousBalance) async {
    final stage = await getStageById(stageId);
    if (stage == null) {
      throw Exception('阶段不存在: $stageId');
    }

    // 本阶段追加
    final additions = await getAdditionsByStage(stageId);
    final additionsTotal =
        additions.fold<double>(0, (sum, a) => sum + a.amount);

    // 阶段本金 = 上阶段余额 + 本阶段追加（第一阶段 = 初始本金）
    final baseAmount = previousBalance + additionsTotal;

    // 支出分类汇总（兼容旧数据：shopping→购物, other→其他）
    final expenses = await getExpensesByStage(stageId);
    double shoppingTotal = 0; // 个人支出（所有非 other 分类）
    double otherTotal = 0; // 其他支出（仅 other）
    for (final e in expenses) {
      if (e.isOther) {
        otherTotal += e.amount;
      } else {
        // shopping / 生活 / 购物 / 工作 / 娱乐 / 大餐 都算个人支出
        shoppingTotal += e.amount;
      }
    }

    final balance = stage.balance;
    final livingDays = stage.livingDays;

    // 余额未填 → 生活相关显示缺省
    double? livingTotal;
    double? livingDailyAvg;
    if (balance != null) {
      livingTotal = baseAmount - shoppingTotal - otherTotal - balance;
      livingDailyAvg = livingDays > 0 ? livingTotal / livingDays : 0;
    }

    return StageCalculations(
      baseAmount: baseAmount,
      additionsTotal: additionsTotal,
      shoppingTotal: shoppingTotal,
      otherTotal: otherTotal,
      balance: balance,
      livingTotal: livingTotal,
      livingDailyAvg: livingDailyAvg,
      totalDays: livingDays,
    );
  }

  /// 获取周期的完整计算数据（汇总所有阶段，性能优化）
  Future<PeriodCalculations> getPeriodCalculations(int periodId) async {
    final period = await getPeriodById(periodId);
    if (period == null) {
      throw Exception('周期不存在: $periodId');
    }

    // 一次性获取所有阶段数据
    final stages = await getStagesByPeriod(periodId);
    final allAdditions = await getAdditionsByPeriod(periodId);
    final allExpenses = await getExpensesByPeriod(periodId);

    // 按 stage_id 分组
    final additionsByStage = <int, List<AdditionRecord>>{};
    for (final addition in allAdditions) {
      additionsByStage.putIfAbsent(addition.stageId, () => []);
      additionsByStage[addition.stageId]!.add(addition);
    }

    final expensesByStage = <int, List<ExpenseRecord>>{};
    for (final expense in allExpenses) {
      expensesByStage.putIfAbsent(expense.stageId, () => []);
      expensesByStage[expense.stageId]!.add(expense);
    }

    // 计算每个阶段的数据
    final stageCalculations = <StageCalculations>[];
    double totalAdditions = 0;
    double shoppingTotal = 0;
    double otherTotal = 0;
    double previousBalance = period.baseAmount;
    double? lastBalance;

    for (final stage in stages) {
      final stageAdditions = additionsByStage[stage.id!] ?? [];
      final stageExpenses = expensesByStage[stage.id!] ?? [];

      final additionsTotal =
          stageAdditions.fold<double>(0, (sum, a) => sum + a.amount);
      final baseAmount = previousBalance + additionsTotal;

      double stageShoppingTotal = 0; // 个人支出
      double stageOtherTotal = 0; // 其他支出
      for (final e in stageExpenses) {
        if (e.isOther) {
          stageOtherTotal += e.amount;
        } else {
          // shopping / 生活 / 购物 / 工作 / 娱乐 / 大餐 都算个人支出
          stageShoppingTotal += e.amount;
        }
      }

      final balance = stage.balance;
      final livingDays = stage.livingDays;

      double? livingTotal;
      double? livingDailyAvg;
      if (balance != null) {
        livingTotal =
            baseAmount - stageShoppingTotal - stageOtherTotal - balance;
        livingDailyAvg = livingDays > 0 ? livingTotal / livingDays : 0;
      }

      stageCalculations.add(StageCalculations(
        baseAmount: baseAmount,
        additionsTotal: additionsTotal,
        shoppingTotal: stageShoppingTotal,
        otherTotal: stageOtherTotal,
        balance: balance,
        livingTotal: livingTotal,
        livingDailyAvg: livingDailyAvg,
        totalDays: livingDays,
      ));

      totalAdditions += additionsTotal;
      shoppingTotal += stageShoppingTotal;
      otherTotal += stageOtherTotal;

      if (balance != null) {
        previousBalance = balance;
        lastBalance = balance;
      } else {
        previousBalance = baseAmount - stageShoppingTotal - stageOtherTotal;
      }
    }

    final totalBase = period.baseAmount + totalAdditions;

    double? livingTotal;
    double? livingDailyAvg;
    if (lastBalance != null) {
      livingTotal = totalBase - shoppingTotal - otherTotal - lastBalance;
      final totalDays = period.totalDays;
      livingDailyAvg = totalDays > 0 ? livingTotal / totalDays : 0;
    }

    return PeriodCalculations(
      totalBase: totalBase,
      shoppingTotal: shoppingTotal,
      otherTotal: otherTotal,
      balance: lastBalance,
      livingTotal: livingTotal,
      livingDailyAvg: livingDailyAvg,
      totalDays: period.totalDays,
      stages: stageCalculations,
    );
  }
}

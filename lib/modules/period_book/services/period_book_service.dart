import '../../../core/storage/database_service.dart';
import '../models/period_record.dart';
import '../models/stage_record.dart';
import '../models/addition_record.dart';
import '../models/expense_record.dart';

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
class PeriodBookService {
  static final PeriodBookService instance = PeriodBookService._();
  PeriodBookService._();

  final DatabaseService _db = DatabaseService.instance;

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

    return id;
  }

  /// 获取当前进行中的周期（is_closed=0，最新的）
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

  /// 标记周期为已结束
  Future<void> closePeriod(int id) async {
    await updatePeriod(id, {'is_closed': 1});
  }

  /// 删除周期及关联数据
  Future<void> deletePeriod(int id) async {
    // 先删除阶段（级联删除 additions 和 expenses）
    await _db.delete('mod_period_book_stages',
        where: 'period_id = ?', whereArgs: [id]);
    await _db.delete('mod_period_book_periods',
        where: 'id = ?', whereArgs: [id]);
  }

  /// 检查日期是否与已有周期重叠
  Future<bool> hasDateOverlap(String startDate, String endDate, {int? excludeId}) async {
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
  Future<void> _autoCreateStages(int periodId, String startDate, String endDate) async {
    final stages = _generateStages(periodId, startDate, endDate);
    for (final stage in stages) {
      await _db.insert('mod_period_book_stages', stage.toMap());
    }
  }

  /// 生成阶段列表（按周拆分）
  List<StageRecord> _generateStages(int periodId, String startDate, String endDate) {
    final stages = <StageRecord>[];
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final now = DateTime.now().toIso8601String();

    var current = start;
    var sortOrder = 1;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      // 本周结束日期 = current + 6天 或 end（取较小值）
      var stageEnd = current.add(const Duration(days: 6));
      if (stageEnd.isAfter(end)) {
        stageEnd = end;
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
    return _db.insert('mod_period_book_stages', {
      'period_id': periodId,
      'start_date': startDate,
      'end_date': endDate,
      'balance': null,
      'sort_order': sortOrder,
      'created_at': now,
      'updated_at': now,
    });
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
    await _db.delete('mod_period_book_stages',
        where: 'id = ?', whereArgs: [id]);
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
    return _db.insert('mod_period_book_additions', {
      'stage_id': stageId,
      'amount': amount,
      'reason': reason,
      'created_at': now,
    });
  }

  Future<List<AdditionRecord>> getAdditionsByStage(int stageId) async {
    final rows = await _db.query(
      'mod_period_book_additions',
      where: 'stage_id = ?',
      whereArgs: [stageId],
      orderBy: 'created_at ASC',
    );
    return rows.map(AdditionRecord.fromMap).toList();
  }

  /// 获取周期所有阶段的追加记录
  Future<List<AdditionRecord>> getAdditionsByPeriod(int periodId) async {
    final stages = await getStagesByPeriod(periodId);
    final allAdditions = <AdditionRecord>[];
    for (final stage in stages) {
      final additions = await getAdditionsByStage(stage.id!);
      allAdditions.addAll(additions);
    }
    return allAdditions;
  }

  Future<void> deleteAddition(int id) async {
    await _db.delete('mod_period_book_additions',
        where: 'id = ?', whereArgs: [id]);
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
    return _db.insert('mod_period_book_expenses', {
      'stage_id': stageId,
      'category': category,
      'amount': amount,
      'description': description,
      'created_at': now,
    });
  }

  /// 批量添加支出
  Future<void> batchAddExpenses(
    int stageId,
    List<Map<String, dynamic>> expenses,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final expense in expenses) {
      await _db.insert('mod_period_book_expenses', {
        'stage_id': stageId,
        'category': expense['category'],
        'amount': expense['amount'],
        'description': expense['description'],
        'created_at': now,
      });
    }
  }

  Future<List<ExpenseRecord>> getExpensesByStage(int stageId) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'stage_id = ?',
      whereArgs: [stageId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  /// 获取周期所有阶段的支出记录
  Future<List<ExpenseRecord>> getExpensesByPeriod(int periodId) async {
    final stages = await getStagesByPeriod(periodId);
    final allExpenses = <ExpenseRecord>[];
    for (final stage in stages) {
      final expenses = await getExpensesByStage(stage.id!);
      allExpenses.addAll(expenses);
    }
    return allExpenses;
  }

  Future<List<ExpenseRecord>> getExpensesByCategory(
    int stageId,
    String category,
  ) async {
    final rows = await _db.query(
      'mod_period_book_expenses',
      where: 'stage_id = ? AND category = ?',
      whereArgs: [stageId, category],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<void> deleteExpense(int id) async {
    await _db.delete('mod_period_book_expenses',
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // 业务计算
  // ══════════════════════════════════════════════════════════

  /// 获取阶段的计算数据
  Future<StageCalculations> getStageCalculations(int stageId, double previousBalance) async {
    final stage = await getStageById(stageId);
    if (stage == null) {
      throw Exception('阶段不存在: $stageId');
    }

    // 本阶段追加
    final additions = await getAdditionsByStage(stageId);
    final additionsTotal = additions.fold<double>(0, (sum, a) => sum + a.amount);

    // 阶段本金 = 上阶段余额 + 本阶段追加（第一阶段 = 初始本金）
    final baseAmount = previousBalance + additionsTotal;

    // 支出分类汇总
    final expenses = await getExpensesByStage(stageId);
    double shoppingTotal = 0;
    double otherTotal = 0;
    for (final e in expenses) {
      if (e.category == 'shopping') {
        shoppingTotal += e.amount;
      } else {
        otherTotal += e.amount;
      }
    }

    final balance = stage.balance;
    final totalDays = stage.totalDays;

    // 余额未填 → 生活相关显示缺省
    double? livingTotal;
    double? livingDailyAvg;
    if (balance != null) {
      livingTotal = baseAmount - shoppingTotal - otherTotal - balance;
      livingDailyAvg = totalDays > 0 ? livingTotal / totalDays : 0;
    }

    return StageCalculations(
      baseAmount: baseAmount,
      additionsTotal: additionsTotal,
      shoppingTotal: shoppingTotal,
      otherTotal: otherTotal,
      balance: balance,
      livingTotal: livingTotal,
      livingDailyAvg: livingDailyAvg,
      totalDays: totalDays,
    );
  }

  /// 获取周期的完整计算数据（汇总所有阶段）
  Future<PeriodCalculations> getPeriodCalculations(int periodId) async {
    final period = await getPeriodById(periodId);
    if (period == null) {
      throw Exception('周期不存在: $periodId');
    }

    final stages = await getStagesByPeriod(periodId);
    final stageCalculations = <StageCalculations>[];

    double totalBase = period.baseAmount; // 初始本金
    double totalAdditions = 0;
    double shoppingTotal = 0;
    double otherTotal = 0;
    double previousBalance = period.baseAmount; // 第一阶段本金 = 初始本金
    double? lastBalance; // 最新阶段余额

    for (final stage in stages) {
      // 计算本阶段（第一阶段：previousBalance = baseAmount，additionsTotal = 0）
      final calc = await getStageCalculations(stage.id!, previousBalance - totalAdditions);
      stageCalculations.add(calc);

      // 更新累计值
      totalAdditions += calc.additionsTotal;
      shoppingTotal += calc.shoppingTotal;
      otherTotal += calc.otherTotal;

      // 更新 previousBalance 为当前阶段的余额（用于链式传递）
      if (calc.balance != null) {
        previousBalance = calc.balance!;
        lastBalance = calc.balance;
      } else {
        // 如果当前阶段没有余额，使用阶段本金 - 支出作为估算
        previousBalance = calc.baseAmount - calc.shoppingTotal - calc.otherTotal;
      }
    }

    totalBase = period.baseAmount + totalAdditions;

    // 生活支出 = 总本金 - 购物 - 其他 - 最新余额
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

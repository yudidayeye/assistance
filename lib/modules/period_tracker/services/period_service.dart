import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/database_service.dart';
import '../models/period_record.dart';

/// 经期记录服务
class PeriodService extends ChangeNotifier {
  static final PeriodService instance = PeriodService._();
  PeriodService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_period_tracker_records';

  void _notifyChanged() => notifyListeners();

  /// 外部通知数据已变更（如导入后刷新 UI）
  void notifyChanged() => notifyListeners();

  /// 获取所有记录（按开始日期倒序）
  Future<List<PeriodRecord>> getAllRecords() async {
    final rows = await _db.query(_table, orderBy: 'start_date DESC');
    return rows.map((r) => PeriodRecord.fromMap(r)).toList();
  }

  /// 获取最近N条记录
  Future<List<PeriodRecord>> getRecentRecords(int n) async {
    final rows = await _db.query(_table, orderBy: 'start_date DESC', limit: n);
    return rows.map((r) => PeriodRecord.fromMap(r)).toList();
  }

  /// 插入记录
  Future<void> insertRecord(PeriodRecord record) async {
    await _db.insert(_table, record.toMap());
    await _updateCycleLengths();
    _notifyChanged();
  }

  /// 插入一条经期范围记录（start→end）
  Future<void> insertPeriodRange(DateTime start, DateTime end) async {
    final now = DateTime.now();
    final record = PeriodRecord(
      id: const Uuid().v4(),
      startDate: start,
      endDate: end,
      createdAt: now,
    );
    await _db.insert(_table, record.toMap());
    await _updateCycleLengths();
    _notifyChanged();
  }

  /// 更新记录
  Future<void> updateRecord(PeriodRecord record) async {
    await _db.update(
      _table,
      record.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    await _updateCycleLengths();
    _notifyChanged();
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _updateCycleLengths();
    _notifyChanged();
  }

  /// 公开重算所有 cycle_length 值。
  /// 用于批量导入后一次性重算，避免每条记录单独触发。
  Future<void> recalculateCycleLengths() async {
    await _updateCycleLengths();
    _notifyChanged();
  }

  /// 获取单条记录
  Future<PeriodRecord?> getRecord(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PeriodRecord.fromMap(rows.first);
  }

  /// 获取最近一条已结束的记录
  Future<PeriodRecord?> getLastCompletedRecord() async {
    final rows = await _db.query(
      _table,
      where: 'end_date IS NOT NULL',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodRecord.fromMap(rows.first);
  }

  /// 获取最近一条记录（包括进行中的）
  Future<PeriodRecord?> getLatestRecord() async {
    final rows = await _db.query(
      _table,
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodRecord.fromMap(rows.first);
  }

  /// 重新计算所有周期长度（事务中执行：先清空再重算）
  Future<void> _updateCycleLengths() async {
    await _db.transaction((txn) async {
      // 先清空所有 cycle_length
      await txn.rawUpdate(
        'UPDATE $_table SET cycle_length = NULL',
      );

      // 按 start_date 升序获取所有记录
      final rows = await txn.rawQuery(
        'SELECT * FROM $_table ORDER BY start_date ASC',
      );
      final records = rows
          .map((r) => PeriodRecord.fromMap(r))
          .toList();

      // 从第二条开始写入与上一条的间隔
      for (int i = 1; i < records.length; i++) {
        final cycleLength = records[i]
            .startDate
            .difference(records[i - 1].startDate)
            .inDays;
        await txn.rawUpdate(
          'UPDATE $_table SET cycle_length = ? WHERE id = ?',
          [cycleLength, records[i].id],
        );
      }
    });
  }
}
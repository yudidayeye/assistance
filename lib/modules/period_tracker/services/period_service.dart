import '../../../core/storage/database_service.dart';
import '../models/period_record.dart';

/// 经期记录服务
class PeriodService {
  static final PeriodService instance = PeriodService._();
  PeriodService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_period_tracker_records';

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
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _updateCycleLengths();
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

  /// 重新计算所有周期长度
  Future<void> _updateCycleLengths() async {
    final records = await getAllRecords();
    final sorted = records.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    for (int i = 1; i < sorted.length; i++) {
      final cycleLength = sorted[i].startDate.difference(sorted[i - 1].startDate).inDays;
      await _db.update(
        _table,
        {'cycle_length': cycleLength},
        where: 'id = ?',
        whereArgs: [sorted[i].id],
      );
    }
  }
}
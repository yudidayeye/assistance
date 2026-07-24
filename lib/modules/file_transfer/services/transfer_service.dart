import 'package:flutter/foundation.dart';
import '../../../core/storage/database_service.dart';
import '../models/transfer_record.dart';

/// 传输记录管理服务
class TransferService extends ChangeNotifier {
  static final TransferService instance = TransferService._();
  TransferService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_file_transfer_records';

  /// 查询传输记录（默认最近 50 条）
  Future<List<TransferRecord>> getRecords({int limit = 50}) async {
    final rows = await _db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(TransferRecord.fromMap).toList();
  }

  /// 添加传输记录
  Future<int> addRecord(TransferRecord record) async {
    final id = await _db.insert(_table, record.toMap());
    notifyListeners();
    return id;
  }

  /// 更新传输状态
  Future<void> updateStatus(
    int id,
    TransferStatus status, {
    String? errorMessage,
  }) async {
    await _db.update(
      _table,
      {
        'status': status.name,
        'error_message': errorMessage,
        if (status == TransferStatus.completed)
          'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  /// 删除传输记录
  Future<void> deleteRecord(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    await _db.delete(_table);
    notifyListeners();
  }
}

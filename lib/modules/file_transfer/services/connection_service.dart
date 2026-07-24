import 'package:flutter/foundation.dart';
import '../../../core/storage/database_service.dart';
import '../models/connection_config.dart';

/// 连接配置管理服务
class ConnectionService extends ChangeNotifier {
  static final ConnectionService instance = ConnectionService._();
  ConnectionService._();

  final DatabaseService _db = DatabaseService.instance;
  static const String _table = 'mod_file_transfer_configs';

  /// 查询所有连接配置
  Future<List<ConnectionConfig>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'is_default DESC, created_at DESC');
    return rows.map(ConnectionConfig.fromMap).toList();
  }

  /// 获取默认配置
  Future<ConnectionConfig?> getDefault() async {
    final rows = await _db.query(
      _table,
      where: 'is_default = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ConnectionConfig.fromMap(rows.first);
  }

  /// 添加连接配置
  Future<int> addConfig(ConnectionConfig config) async {
    final id = await _db.insert(_table, config.toMap());
    notifyListeners();
    return id;
  }

  /// 更新连接配置
  Future<void> updateConfig(ConnectionConfig config) async {
    await _db.update(
      _table,
      config.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
    notifyListeners();
  }

  /// 删除连接配置
  Future<void> deleteConfig(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// 设置默认配置（取消其他默认）
  Future<void> setDefault(int id) async {
    await _db.update(_table, {'is_default': 0});
    await _db.update(_table, {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io' show Platform;

/// SQLite 全局数据库服务（原生平台：Windows/Android/iOS）
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  /// 初始化数据库工厂
  static Future<void> initializeFactory() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// 获取数据库实例
  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'toolbox.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE mod_accounting_transactions (id TEXT PRIMARY KEY, type TEXT NOT NULL, category_id TEXT NOT NULL, amount REAL NOT NULL, note TEXT, date TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT)''');
    await db.execute('''CREATE TABLE mod_accounting_categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, icon_code_point INTEGER NOT NULL, icon_font_family TEXT NOT NULL DEFAULT 'MaterialIcons', is_custom INTEGER NOT NULL DEFAULT 0, sort_order INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE mod_period_tracker_records (id TEXT PRIMARY KEY, start_date TEXT NOT NULL, end_date TEXT, cycle_length INTEGER, created_at TEXT NOT NULL, updated_at TEXT)''');
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<Object?>? whereArgs, String? orderBy, int? limit}) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(table, values);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> execute(String sql) async {
    final db = await database;
    await db.execute(sql);
  }

  Future<void> clearModuleData(String moduleId) async {
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'mod_${moduleId}_%'");
    for (final table in tables) { await db.delete(table['name'] as String); }
  }

  Future<void> clearAllData() async {
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (final table in tables) {
      final name = table['name'] as String;
      if (name != 'sqlite_master' && name != 'sqlite_sequence') { await db.delete(name); }
    }
  }
}
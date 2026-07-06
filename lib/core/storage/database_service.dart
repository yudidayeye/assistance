import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io' show Platform;

/// SQLite 全局数据库服务（原生平台：Windows/Android/iOS）
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  static const int _currentVersion = 5;

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
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // --- Schema ---

  static Future<void> _createV1Schema(Database db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_tracker_records (
        id TEXT PRIMARY KEY,
        start_date TEXT NOT NULL,
        end_date TEXT,
        cycle_length INTEGER,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
  }

  static Future<void> _createV2Schema(Database db) async {
    // 添加必要索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_period_start_date ON mod_period_tracker_records(start_date)',
    );
  }

  static Future<void> _createV4Schema(Database db) async {
    // 周期记账模块三张表
    await db.execute('''
      CREATE TABLE mod_period_book_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        in_progress_date TEXT,
        base_amount REAL NOT NULL,
        balance REAL,
        is_closed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    // 索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_periods_start_date ON mod_period_book_periods(start_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_expenses_period ON mod_period_book_expenses(period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_additions_period ON mod_period_book_additions(period_id)',
    );
  }

  static Future<void> _createV5Schema(Database db) async {
    // 删除旧 accounting 模块的表和索引
    await db.execute('DROP TABLE IF EXISTS mod_accounting_transactions');
    await db.execute('DROP TABLE IF EXISTS mod_accounting_categories');
  }

  // --- Lifecycle ---

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      // v1 base tables
      await _createV1Schema(db);
      // v2 indices
      await _createV2Schema(db);
      // v4 period_book tables
      await _createV4Schema(db);
      // v5 删除旧 accounting 模块表
      await _createV5Schema(db);
      await batch.commit(noResult: true);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        if (v == 2) {
          await _createV2Schema(db);
        }
        if (v == 3) {
          await db.execute(
            'ALTER TABLE mod_period_tracker_records ADD COLUMN note TEXT',
          );
        }
        if (v == 4) {
          await _createV4Schema(db);
        }
        if (v == 5) {
          await _createV5Schema(db);
        }
        await batch.commit(noResult: true);
      });
    }
  }

  // --- CRUD Helpers (3.2) ---

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(table, values);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> execute(String sql) async {
    final db = await database;
    await db.execute(sql);
  }

  /// 原生 SQL 查询
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
          [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  /// 原生 SQL 插入
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawInsert(sql, arguments);
  }

  /// 原生 SQL 更新
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawUpdate(sql, arguments);
  }

  /// 事务执行
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// 批处理
  Future<void> batch(List<Future<void> Function(Batch batch)> operations) async {
    final db = await database;
    final b = db.batch();
    for (final op in operations) {
      await op(b);
    }
    await b.commit(noResult: true);
  }

  /// 设置表 upsert
  Future<void> upsertSetting(String key, String value) async {
    await rawInsert(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  // --- Data Clearing (3.4) ---

  /// 清除单个模块的业务数据（保留 app_settings）
  Future<void> clearModuleData(String moduleId) async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
      ['mod_${moduleId}_%'],
    );
    for (final table in tables) {
      await db.delete(table['name'] as String);
    }
  }

  /// 清除所有业务数据（保留设置和主题）
  Future<void> clearAllBusinessData() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'mod_%'",
    );
    for (final table in tables) {
      await db.delete(table['name'] as String);
    }
  }

  /// 恢复出厂设置（清除所有数据 + 重置主题和设置）
  Future<void> factoryReset() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    for (final table in tables) {
      final name = table['name'] as String;
      if (name != 'sqlite_master' && name != 'sqlite_sequence') {
        await db.delete(name);
      }
    }
  }

  /// ⚠️ 旧方法：删除所有表数据（包括 app_settings），已废弃
  /// 推荐使用 clearAllBusinessData() 或 factoryReset()
  @Deprecated('Use clearAllBusinessData() or factoryReset() instead')
  Future<void> clearAllData() async {
    await factoryReset();
  }
}

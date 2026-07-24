import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io' show Platform;

/// SQLite 全局数据库服务（原生平台：Windows/Android/iOS）
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  static const int _currentVersion = 12;

  /// 注入数据库实例（仅测试用，绕过依赖 path_provider 的默认初始化）
  @visibleForTesting
  void useDatabaseForTesting(Database db) {
    _db = db;
  }

  /// 在指定数据库上创建最新完整表结构（仅测试用）
  @visibleForTesting
  Future<void> createSchemaForTesting(Database db) async {
    await _onCreate(db, _currentVersion);
  }

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
    // 周期记账模块三张表 - v6 最终结构（全新安装时直接创建最终结构）
    await db.execute('''
      CREATE TABLE mod_period_book_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        base_amount REAL NOT NULL,
        is_closed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_stages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        current_date TEXT,
        balance REAL,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
      )
    ''');
    // 索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_periods_start_date ON mod_period_book_periods(start_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_stages_period ON mod_period_book_stages(period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_expenses_stage ON mod_period_book_expenses(stage_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_additions_stage ON mod_period_book_additions(stage_id)',
    );
    // 大额记录表（周期级，不计入总本金和总支出）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mod_period_book_large_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mod_period_book_large_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_additions_period ON mod_period_book_large_additions(period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_expenses_period ON mod_period_book_large_expenses(period_id)',
    );
  }

  static Future<void> _createV5Schema(Database db) async {
    // 删除旧 accounting 模块的表和索引
    await db.execute('DROP TABLE IF EXISTS mod_accounting_transactions');
    await db.execute('DROP TABLE IF EXISTS mod_accounting_categories');
  }

  static Future<void> _createV12Schema(Database db) async {
    // 文件互传模块 - 传输记录表
    await db.execute('''
      CREATE TABLE mod_file_transfer_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        direction TEXT NOT NULL,
        target_path TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');
    // 文件互传模块 - 连接配置表
    await db.execute('''
      CREATE TABLE mod_file_transfer_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER DEFAULT 445,
        share_name TEXT NOT NULL,
        username TEXT,
        password TEXT,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ft_records_created ON mod_file_transfer_records(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ft_configs_default ON mod_file_transfer_configs(is_default)',
    );
  }

  // --- Lifecycle ---

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      // v1 base tables
      await _createV1Schema(db);
      // v2 indices
      await _createV2Schema(db);
      // v4 period_book tables (v6 最终结构)
      await _createV4Schema(db);
      // v5 删除旧 accounting 模块表
      await _createV5Schema(db);
      // v12 文件互传模块表
      await _createV12Schema(db);
      await batch.commit(noResult: true);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 如果从 v5 以下升级到 v6，先执行中间版本的迁移
    if (oldVersion < 6 && newVersion >= 6) {
      await _migrateToV6(db, oldVersion);
    }

    // 如果从 v6 升级到 v7，添加 sort_order 字段到 expenses 表
    if (oldVersion < 7 && newVersion >= 7) {
      await _migrateToV7(db);
    }

    // 如果从 v7 升级到 v8，添加 current_date 字段到 stages 表
    if (oldVersion < 8 && newVersion >= 8) {
      await _migrateToV8(db);
    }

    // 如果从 v8 升级到 v9，添加大额记录表
    if (oldVersion < 9 && newVersion >= 9) {
      await _migrateToV9(db);
    }

    // 如果从 v9 升级到 v10，添加 sort_order 字段到 additions 表
    if (oldVersion < 10 && newVersion >= 10) {
      await _migrateToV10(db);
    }

    // 如果从 v10 升级到 v11，添加 sort_order 字段到大额追加表
    if (oldVersion < 11 && newVersion >= 11) {
      await _migrateToV11(db);
    }

    // 如果从 v11 升级到 v12，添加文件互传模块表
    if (oldVersion < 12 && newVersion >= 12) {
      await _migrateToV12(db);
    }

    // 对于其他版本的升级，逐个执行
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      if (v == 6) continue; // 已经在上面处理了
      if (v == 7) continue; // 已经在上面处理了
      if (v == 8) continue; // 已经在上面处理了
      if (v == 9) continue; // 已经在上面处理了
      if (v == 10) continue; // 已经在上面处理了
      if (v == 11) continue; // 已经在上面处理了
      if (v == 12) continue; // 已经在上面处理了

      await db.transaction((txn) async {
        if (v == 2) {
          await _createV2Schema(db);
        } else if (v == 3) {
          await db.execute(
            'ALTER TABLE mod_period_tracker_records ADD COLUMN note TEXT',
          );
        } else if (v == 5) {
          await _createV5Schema(db);
        }
      });
    }
  }

  /// v6 迁移：引入阶段概念，保留旧数据
  Future<void> _migrateToV6(Database db, int fromVersion) async {
    await db.transaction((txn) async {
      // 如果从 v4 或更早版本升级，需要先创建 v4 的表结构
      if (fromVersion < 4) {
        await _createV4Schema(db);
      }

      // 如果从 v5 或更早版本升级，执行 v5 的清理
      if (fromVersion < 5) {
        await _createV5Schema(db);
      }

      // 1. 备份旧数据
      final oldPeriods = await txn.query('mod_period_book_periods');
      final oldAdditions = await txn.query('mod_period_book_additions');
      final oldExpenses = await txn.query('mod_period_book_expenses');

      // 2. 删除旧表
      await txn.execute('DROP TABLE IF EXISTS mod_period_book_expenses');
      await txn.execute('DROP TABLE IF EXISTS mod_period_book_additions');
      await txn.execute('DROP TABLE IF EXISTS mod_period_book_stages');
      await txn.execute('DROP TABLE IF EXISTS mod_period_book_periods');

      // 3. 创建新的 v6 表结构
      await txn.execute('''
        CREATE TABLE mod_period_book_periods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          base_amount REAL NOT NULL,
          is_closed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE mod_period_book_stages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          period_id INTEGER NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          balance REAL,
          sort_order INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE mod_period_book_additions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stage_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          reason TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE mod_period_book_expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stage_id INTEGER NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (stage_id) REFERENCES mod_period_book_stages(id) ON DELETE CASCADE
        )
      ''');

      // 4. 创建索引
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_pb_periods_start_date ON mod_period_book_periods(start_date)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_pb_stages_period ON mod_period_book_stages(period_id)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_pb_expenses_stage ON mod_period_book_expenses(stage_id)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_pb_additions_stage ON mod_period_book_additions(stage_id)',
      );

      // 5. 迁移旧数据：每个旧周期归入一个默认阶段
      final now = DateTime.now().toIso8601String();
      for (final period in oldPeriods) {
        final periodId = period['id'] as int;
        final startDate = period['start_date'] as String;
        final endDate = period['end_date'] as String;
        final baseAmount = period['base_amount'] as double;
        final isClosed = period['is_closed'] as int;
        final createdAt = period['created_at'] as String;
        final updatedAt = period['updated_at'] as String;

        // 插入新 periods 记录
        final newPeriodId = await txn.insert('mod_period_book_periods', {
          'start_date': startDate,
          'end_date': endDate,
          'base_amount': baseAmount,
          'is_closed': isClosed,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });

        // 创建默认阶段（整个周期作为一个阶段）
        final stageId = await txn.insert('mod_period_book_stages', {
          'period_id': newPeriodId,
          'start_date': startDate,
          'end_date': endDate,
          'balance': period['balance'], // 保留旧的 balance 到阶段
          'sort_order': 1,
          'created_at': now,
          'updated_at': now,
        });

        // 迁移该周期的 additions
        for (final addition in oldAdditions) {
          if (addition['period_id'] == periodId) {
            await txn.insert('mod_period_book_additions', {
              'stage_id': stageId,
              'amount': addition['amount'],
              'reason': addition['reason'],
              'created_at': addition['created_at'],
            });
          }
        }

        // 迁移该周期的 expenses
        for (final expense in oldExpenses) {
          if (expense['period_id'] == periodId) {
            await txn.insert('mod_period_book_expenses', {
              'stage_id': stageId,
              'category': expense['category'],
              'amount': expense['amount'],
              'description': expense['description'],
              'created_at': expense['created_at'],
            });
          }
        }
      }
    });
  }

  /// v7 迁移：为 expenses 表添加 sort_order 字段
  Future<void> _migrateToV7(Database db) async {
    await db.execute(
      'ALTER TABLE mod_period_book_expenses ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// v8 迁移：为 stages 表添加 current_date 字段
  Future<void> _migrateToV8(Database db) async {
    await db.execute(
      'ALTER TABLE mod_period_book_stages ADD COLUMN current_date TEXT',
    );
  }

  /// v10 迁移：为 additions 表添加 sort_order 字段（支持手动排序）
  Future<void> _migrateToV10(Database db) async {
    await db.execute(
      'ALTER TABLE mod_period_book_additions ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _migrateToV11(Database db) async {
    await db.execute(
      'ALTER TABLE mod_period_book_large_additions ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// v12 迁移：添加文件互传模块表
  Future<void> _migrateToV12(Database db) async {
    await _createV12Schema(db);
  }

  /// v9 迁移：添加大额记录表（周期级，不计入总本金和总支出）
  Future<void> _migrateToV9(Database db) async {
    await db.execute('''
      CREATE TABLE mod_period_book_large_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_large_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (period_id) REFERENCES mod_period_book_periods(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_additions_period ON mod_period_book_large_additions(period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pb_large_expenses_period ON mod_period_book_large_expenses(period_id)',
    );
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
  Future<void> batch(
      List<Future<void> Function(Batch batch)> operations) async {
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

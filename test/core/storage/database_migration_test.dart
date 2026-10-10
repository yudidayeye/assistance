import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _tables = [
  'mod_period_book_additions',
  'mod_period_book_expenses',
  'mod_period_book_large_additions',
  'mod_period_book_large_expenses',
];

Future<Database> _openDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  for (final table in _tables) {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }
  return db;
}

Future<bool> _hasEntryDate(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == 'entry_date');
}

Future<int> _entryDateCount(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.where((row) => row['name'] == 'entry_date').length;
}

Future<Database> _createV17Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  for (final table in _tables) {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }
  await db.execute('PRAGMA user_version = 17');
  return db;
}

void main() {
  final service = DatabaseService.instance;

  setUpAll(() {
    if (Platform.isWindows) {
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('实际 openDatabase v17 到 v18 迁移并更新 user_version', () async {
    final dir = await Directory.systemTemp.createTemp('database-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v17.db';
    final legacyDb = await _createV17Database(path);
    await legacyDb.insert(_tables.first, {
      'amount': 9.5,
      'created_at': '2026-10-10T12:00:00.000Z',
    });
    await legacyDb.close();

    final upgradedDb = await service.openDatabaseAtForTesting(path);
    addTearDown(upgradedDb.close);

    final versionRows = await upgradedDb.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], 18);
    for (final table in _tables) {
      expect(await _entryDateCount(upgradedDb, table), 1);
    }
    final rows = await upgradedDb.query(_tables.first);
    expect(rows.single['amount'], 9.5);
    expect(rows.single['created_at'], '2026-10-10T12:00:00.000Z');
    expect(rows.single['entry_date'], isNull);
  });

  test('实际 openDatabase 拒绝高版本数据库且保留版本与数据', () async {
    final dir = await Directory.systemTemp.createTemp('database-downgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v19.db';
    final db = await _createV17Database(path);
    await db.insert(_tables.first, {
      'amount': 6,
      'created_at': '2026-10-10T13:00:00.000Z',
    });
    await db.execute('PRAGMA user_version = 19');
    await db.close();

    await expectLater(
      service.openDatabaseAtForTesting(path),
      throwsA(isA<StateError>()),
    );

    final verifyDb = await databaseFactoryFfi.openDatabase(path);
    addTearDown(verifyDb.close);
    final versionRows = await verifyDb.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], 19);
    final rows = await verifyDb.query(_tables.first);
    expect(rows.single['amount'], 6);
    expect(rows.single['created_at'], '2026-10-10T13:00:00.000Z');
  });

  test('重复执行 v18 迁移不会重复添加列', () async {
    final db = await _openDatabase();
    addTearDown(db.close);

    for (final table in _tables) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN entry_date TEXT',
      );
    }

    await service.migrateToV18ForTesting(db);
    await service.migrateToV18ForTesting(db);

    for (final table in _tables) {
      expect(await _hasEntryDate(db, table), isTrue);
      expect(await _entryDateCount(db, table), 1);
    }
  });

  test('缺失列时 v18 迁移会补齐四张表', () async {
    final db = await _openDatabase();
    addTearDown(db.close);

    await service.migrateToV18ForTesting(db);

    for (final table in _tables) {
      expect(await _hasEntryDate(db, table), isTrue);
    }
  });

  test('部分完成的 v18 迁移只补缺失列', () async {
    final db = await _openDatabase();
    addTearDown(db.close);

    for (final table in _tables.take(2)) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN entry_date TEXT',
      );
    }

    await service.migrateToV18ForTesting(db);

    for (final table in _tables) {
      expect(await _entryDateCount(db, table), 1);
    }
  });

  test('v18 迁移保留既有数据并将新列置为 NULL', () async {
    final db = await _openDatabase();
    addTearDown(db.close);

    await db.insert(_tables.first, {
      'amount': 12.5,
      'created_at': '2026-10-10T10:00:00.000Z',
    });
    await service.migrateToV18ForTesting(db);

    final rows = await db.query(_tables.first);
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 12.5);
    expect(rows.single['created_at'], '2026-10-10T10:00:00.000Z');
    expect(rows.single['entry_date'], isNull);
  });

  test('数据库降级被拒绝且不修改数据', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await db.insert(_tables.first, {
      'amount': 8,
      'created_at': '2026-10-10T11:00:00.000Z',
    });

    await expectLater(
      service.downgradeForTesting(db, 18, 17),
      throwsA(isA<StateError>()),
    );

    final rows = await db.query(_tables.first);
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 8);
    expect(await _hasEntryDate(db, _tables.first), isFalse);
  });
}

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/settings/import_export_service.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      // flutter test ??? sqlite3 ? system ???sqlite3.dll?????????
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;
  bool dbInitialized = false;

  /// ?????????????????? createSchemaForTesting ?????????
  Future<void> createSchema(Database db) async {
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
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
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
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_period_book_large_additions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
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
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_vault_master (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        salt TEXT NOT NULL,
        verify_cipher TEXT NOT NULL,
        verify_iv TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_vault_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'folder',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_encrypted INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mod_vault_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        username TEXT,
        encrypted_password TEXT NOT NULL,
        password_iv TEXT NOT NULL,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES mod_vault_categories(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> setUpDb() async {
    // ??????????? sqflite ??????????????
    if (dbInitialized) {
      await testDb.close();
    }
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbInitialized = true;
    DatabaseService.instance.useDatabaseForTesting(testDb);
    await createSchema(testDb);
  }

  String now() => DateTime.now().toIso8601String();

  File tempFile() => File(
      '${Directory.systemTemp.path}/vault_import_test_${DateTime.now().microsecondsSinceEpoch}.json');

  test('?????? sort_order?????????', () async {
    await setUpDb();
    final db = DatabaseService.instance;

    final catId = await db.insert('mod_vault_categories', {
      'name': '????',
      'icon': 'folder',
      'sort_order': 1,
      'is_encrypted': 0,
      'created_at': now(),
      'updated_at': now(),
    });
    await db.insert('mod_vault_entries', {
      'category_id': catId,
      'title': '??A',
      'username': 'u1',
      'encrypted_password': 'p1',
      'password_iv': 'iv1',
      'note': null,
      'sort_order': 0,
      'created_at': now(),
      'updated_at': now(),
    });
    await db.insert('mod_vault_entries', {
      'category_id': catId,
      'title': '??B',
      'username': 'u2',
      'encrypted_password': 'p2',
      'password_iv': 'iv2',
      'note': null,
      'sort_order': 3,
      'created_at': now(),
      'updated_at': now(),
    });

    final bytes = await ImportExportService.instance.generateExportBytes();
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final entries =
        (json['data']['vault_entries'] as List).cast<Map<String, dynamic>>();
    expect(entries, hasLength(2));
    // ??? sort_order ??
    expect(entries.map((e) => e['title']).toList(), ['??A', '??B']);
    expect(entries.map((e) => e['sort_order']).toList(), [0, 3]);

    // ?????????????
    await db.delete('mod_vault_entries');
    await db.delete('mod_vault_categories');

    final file = tempFile();
    await file.writeAsBytes(bytes);
    final result = await ImportExportService.instance.executeImport(file.path);
    await file.delete();
    expect(result.isSuccess, isTrue);
    expect(result.vaultEntriesCount, 2);

    final rows =
        await db.query('mod_vault_entries', orderBy: 'sort_order ASC');
    expect(rows.map((r) => r['title']).toList(), ['??A', '??B']);
    expect(rows.map((r) => r['sort_order']).toList(), [0, 3]);
  });

  test('?????? sort_order ?????????? 0?', () async {
    await setUpDb();
    final db = DatabaseService.instance;

    final payload = {
      'version': 4,
      'exportedAt': now(),
      'appName': 'my_assistant',
      'appVersion': '1.0.0',
      'data': {
        'app_settings': <String, String>{},
        'period_tracker_records': <dynamic>[],
        'period_book_periods': <dynamic>[],
        'period_book_stages': <dynamic>[],
        'period_book_additions': <dynamic>[],
        'period_book_expenses': <dynamic>[],
        'period_book_large_additions': <dynamic>[],
        'period_book_large_expenses': <dynamic>[],
        'vault_master': null,
        'vault_categories': [
          {
            'id': 1,
            'name': '???',
            'icon': 'folder',
            'sort_order': 0,
            'is_encrypted': 0,
            'created_at': now(),
            'updated_at': now(),
          }
        ],
        'vault_entries': [
          {
            // ??????? sort_order ??
            'id': 1,
            'category_id': 1,
            'title': '???',
            'username': 'u',
            'encrypted_password': 'p',
            'password_iv': 'iv',
            'note': null,
            'created_at': now(),
            'updated_at': now(),
          }
        ],
      },
    };

    final file = tempFile();
    await file.writeAsString(jsonEncode(payload), encoding: utf8);
    final result = await ImportExportService.instance.executeImport(file.path);
    await file.delete();
    expect(result.isSuccess, isTrue);
    expect(result.vaultEntriesCount, 1);

    final rows = await db.query('mod_vault_entries');
    expect(rows, hasLength(1));
    expect(rows.first['sort_order'], 0);
  });
}

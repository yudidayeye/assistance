import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/settings/import_export_service.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late Directory temp;
  final service = ImportExportService.instance;

  setUpAll(() {
    if (Platform.isWindows) {
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseService.instance.createSchemaForTesting(db);
    DatabaseService.instance.useDatabaseForTesting(db);
    temp = await Directory.systemTemp.createTemp('merge_test_');
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Map<String, Object?> category(int id, String created) => {
        'id': id,
        'name': '分类 $created',
        'is_encrypted': 0,
        'created_at': created,
        'updated_at': created,
      };

  Map<String, Object?> entry(int id, int categoryId, String created) => {
        'id': id,
        'category_id': categoryId,
        'title': created,
        'encrypted_password': 'password-$created',
        'password_iv': '',
        'created_at': created,
        'updated_at': created,
      };

  Future<File> backup() async {
    final file = File('${temp.path}/backup.json');
    await file.writeAsBytes(await service.generateExportBytes());
    return file;
  }

  test('手机新增记账与电脑新增密码合并，重复同步不改变已有内容', () async {
    await db.insert('mod_vault_categories', category(1, 'shared'));
    await db.insert('mod_vault_entries', entry(1, 1, 'shared'));
    final file = await backup();
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    payload['data']['period_book_periods'] = [
      {
        'id': 1,
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'base_amount': 1000,
        'is_closed': 0,
        'created_at': 'phone',
        'updated_at': 'phone',
      }
    ];
    await file.writeAsString(jsonEncode(payload));
    await db.insert('mod_vault_entries', entry(2, 1, 'desktop'));
    await db.update('mod_vault_entries', {'title': '本地修改'},
        where: 'id = ?', whereArgs: [1]);
    final before = await db.query('mod_vault_entries', orderBy: 'id');

    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await service.executeImport(file.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(await db.query('mod_vault_entries', orderBy: 'id'), before);
      expect(await db.query('mod_period_book_periods'), hasLength(1));
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }
  });

  test('两端分类和密码编号冲突时保留双方记录，重复导入不新增副本', () async {
    await db.insert('mod_vault_categories', category(1, 'phone'));
    await db.insert('mod_vault_entries', entry(1, 1, 'phone'));
    final file = await backup();
    await db.delete('mod_vault_categories');
    await db.insert('mod_vault_categories', category(1, 'desktop'));
    await db.insert('mod_vault_entries', entry(1, 1, 'desktop'));

    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await service.executeImport(file.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      final categories = await db.query('mod_vault_categories', orderBy: 'id');
      final entries = await db.query('mod_vault_entries', orderBy: 'id');
      expect(categories, hasLength(2));
      expect(entries, hasLength(2));
      expect(entries.first['title'], 'desktop');
      expect(entries.last['title'], 'phone');
      expect(entries.last['category_id'], categories.last['id']);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }
  });

  test('共同周期和阶段下的本地支出不被级联删除，冲突支出重新编号', () async {
    await db.insert('mod_period_book_periods', {
      'id': 1,
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
      'base_amount': 1000,
      'created_at': 'shared',
      'updated_at': 'shared',
    });
    await db.insert('mod_period_book_stages', {
      'id': 1,
      'period_id': 1,
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
      'sort_order': 0,
      'created_at': 'shared',
      'updated_at': 'shared',
    });
    final expense = {
      'id': 1,
      'stage_id': 1,
      'category': '日常',
      'amount': 10,
      'description': '手机新增',
      'created_at': 'phone',
    };
    await db.insert('mod_period_book_expenses', expense);
    final file = await backup();
    await db.delete('mod_period_book_expenses');
    await db.insert('mod_period_book_expenses', {
      ...expense,
      'description': '电脑新增',
      'created_at': 'desktop',
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await service.executeImport(file.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(await db.query('mod_period_book_periods'), hasLength(1));
      expect(await db.query('mod_period_book_stages'), hasLength(1));
      expect(await db.query('mod_period_book_expenses'), hasLength(2));
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }
  });
}

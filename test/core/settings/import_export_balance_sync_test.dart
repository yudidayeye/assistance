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
    temp = await Directory.systemTemp.createTemp('balance_sync_test_');
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Map<String, Object?> period({String updatedAt = '2026-01-01T00:00:00'}) => {
        'id': 1,
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'base_amount': 1000,
        'is_closed': 0,
        'created_at': 'shared',
        'updated_at': updatedAt,
      };

  Map<String, Object?> stage({
    Object? balance,
    Object? currentDate,
    String updatedAt = '2026-01-01T00:00:00',
  }) =>
      {
        'id': 1,
        'period_id': 1,
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'current_date': currentDate,
        'balance': balance,
        'sort_order': 0,
        'created_at': 'shared',
        'updated_at': updatedAt,
      };

  Future<File> backup() async {
    final file = File('${temp.path}/backup.json');
    await file.writeAsBytes(await service.generateExportBytes());
    return file;
  }

  /// 导出后覆盖 stages 列表，模拟「远端备份携带不同阶段数据」。
  Future<File> backupWithStages(List<Map<String, Object?>> stages) async {
    final file = await backup();
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    payload['data']['period_book_stages'] = stages;
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  test('全新导入写入阶段余额与生活费日期', () async {
    await db.insert('mod_period_book_periods', period());
    final file = await backupWithStages([
      stage(balance: 500, currentDate: '2026-10-15'),
    ]);

    final result = await service.executeImport(file.path);
    expect(result.isSuccess, isTrue, reason: result.error);

    final stages = await db.query('mod_period_book_stages');
    expect(stages, hasLength(1));
    expect((stages.single['balance'] as num).toDouble(), closeTo(500, 0.001));
    expect(stages.single['current_date'], '2026-10-15');
  });

  test('二次同步时源端更新的阶段余额覆盖本地', () async {
    await db.insert('mod_period_book_periods', period());
    await db.insert('mod_period_book_stages', stage(balance: null));
    final file = await backupWithStages([
      stage(
        balance: 500,
        currentDate: '2026-10-15',
        updatedAt: '2026-02-01T00:00:00',
      ),
    ]);

    final result = await service.executeImport(file.path);
    expect(result.isSuccess, isTrue, reason: result.error);

    final stages = await db.query('mod_period_book_stages');
    expect(stages, hasLength(1));
    expect((stages.single['balance'] as num).toDouble(), closeTo(500, 0.001));
    expect(stages.single['current_date'], '2026-10-15');
  });

  test('远端更新时间更旧时保留本地余额不被覆盖', () async {
    await db.insert('mod_period_book_periods', period());
    await db.insert(
      'mod_period_book_stages',
      stage(balance: 200, updatedAt: '2026-03-01T00:00:00'),
    );
    final file = await backupWithStages([
      stage(balance: 100, updatedAt: '2026-02-01T00:00:00'),
    ]);

    final result = await service.executeImport(file.path);
    expect(result.isSuccess, isTrue, reason: result.error);

    final stages = await db.query('mod_period_book_stages');
    expect(stages, hasLength(1));
    expect((stages.single['balance'] as num).toDouble(), closeTo(200, 0.001));
  });

  test('周期和阶段重新编号后仍更新余额且支出归属不变，重复同步不产生副本', () async {
    await db.insert('mod_period_book_periods', {...period(), 'id': 7});
    await db.insert('mod_period_book_stages', {
      ...stage(balance: 0),
      'id': 8,
      'period_id': 7,
    });
    await db.insert('mod_period_book_expenses', {
      'id': 1,
      'stage_id': 8,
      'category': 'shopping',
      'amount': 67.93,
      'description': '本地支出',
      'created_at': 'local-expense',
    });
    final file = await backup();
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    payload['data']['period_book_periods'] = [
      {...period(updatedAt: '2026-02-01T00:00:00'), 'base_amount': 2000},
    ];
    payload['data']['period_book_stages'] = [
      stage(
        balance: 479.20,
        currentDate: '2026-10-15',
        updatedAt: '2026-02-01T00:00:00',
      ),
    ];
    payload['data']['period_book_expenses'] = [
      {
        'id': 2,
        'stage_id': 1,
        'category': 'shopping',
        'amount': 10,
        'description': '远端支出',
        'created_at': 'remote-expense',
      },
    ];
    await file.writeAsString(jsonEncode(payload));

    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await service.executeImport(file.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      final periods = await db.query('mod_period_book_periods');
      expect(periods, hasLength(1));
      expect(periods.single['id'], 7);
      expect(periods.single['base_amount'], 2000);
      final stages = await db.query('mod_period_book_stages');
      expect(stages, hasLength(1));
      expect(stages.single['id'], 8);
      expect(stages.single['balance'], closeTo(479.20, 0.001));
      expect(stages.single['current_date'], '2026-10-15');
      final expenses = await db.query('mod_period_book_expenses');
      expect(expenses, hasLength(2));
      expect(expenses.every((expense) => expense['stage_id'] == 8), isTrue);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    }
  });

  test('同批创建的阶段重新编号后按阶段顺序匹配且保留较新的本地余额', () async {
    await db.insert('mod_period_book_periods', period());
    await db.insert('mod_period_book_stages', {
      ...stage(balance: 100, updatedAt: '2026-03-01T00:00:00'),
      'id': 8,
    });
    await db.insert('mod_period_book_stages', {
      ...stage(balance: 200),
      'id': 9,
      'sort_order': 1,
      'start_date': '2026-11-01',
      'end_date': '2026-11-07',
    });
    final file = await backupWithStages([
      stage(balance: 500, updatedAt: '2026-02-01T00:00:00'),
      {
        ...stage(balance: 0, updatedAt: '2026-02-01T00:00:00'),
        'id': 2,
        'sort_order': 1,
        'start_date': '2026-11-01',
        'end_date': '2026-11-07',
      },
    ]);

    final result = await service.executeImport(file.path);
    expect(result.isSuccess, isTrue, reason: result.error);
    final stages = await db.query('mod_period_book_stages', orderBy: 'id');
    expect(stages, hasLength(2));
    expect(stages.first['balance'], 100);
    expect(stages.last['balance'], 0);
  });

  test('阶段编号与另一阶段交叉时不串改余额', () async {
    await db.insert('mod_period_book_periods', period());
    await db
        .insert('mod_period_book_stages', {...stage(balance: 100), 'id': 2});
    await db.insert('mod_period_book_stages', {
      ...stage(balance: 200),
      'sort_order': 1,
      'start_date': '2026-11-01',
      'end_date': '2026-11-07',
    });
    final file = await backupWithStages([
      stage(balance: 500, updatedAt: '2026-02-01T00:00:00'),
      {
        ...stage(balance: null, updatedAt: '2026-02-01T00:00:00'),
        'id': 2,
        'sort_order': 1,
        'start_date': '2026-11-01',
        'end_date': '2026-11-07',
      },
    ]);

    final result = await service.executeImport(file.path);
    expect(result.isSuccess, isTrue, reason: result.error);
    final stages =
        await db.query('mod_period_book_stages', orderBy: 'sort_order');
    expect(stages, hasLength(2));
    expect(stages.first['id'], 2);
    expect(stages.first['balance'], 500);
    expect(stages.last['id'], 1);
    expect(stages.last['balance'], isNull);
  });
}

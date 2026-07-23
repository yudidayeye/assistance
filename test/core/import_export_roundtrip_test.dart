import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_assistant/core/settings/import_export_service.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:my_assistant/modules/period_book/services/period_book_service.dart';

/// 导入导出往返测试 — 验证追加记录的自定义排序在「备份 → 恢复」后不丢失，
/// 以及旧格式备份文件（不含 sort_order 字段）仍然可以导入。
///
/// 依赖 sqlite3 原生库：Windows 上若 .dart_tool/sqlite3.dll 存在则自动加载，
/// 原生库不可用时测试自动跳过（不影响移动端 CI）。
void main() {
  final dbsToClose = <Database>[];
  late final bool ffiAvailable;

  /// 打开一个带最新完整 schema 的内存库，并注入 DatabaseService
  Future<void> openFreshDb() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseService.instance.createSchemaForTesting(db);
    dbsToClose.add(db);
    DatabaseService.instance.useDatabaseForTesting(db);
  }

  setUpAll(() async {
    // Windows：优先使用 .dart_tool/sqlite3.dll（不入库，本地自备）
    if (Platform.isWindows) {
      final dll = File('.dart_tool${Platform.pathSeparator}sqlite3.dll');
      if (dll.existsSync()) {
        open.overrideFor(OperatingSystem.windows,
            () => DynamicLibrary.open(dll.absolute.path));
      }
    }
    // 探测原生库是否可用
    try {
      sqfliteFfiInit();
      final probe = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await probe.close();
      ffiAvailable = true;
    } catch (_) {
      ffiAvailable = false;
    }
  });

  tearDown(() async {
    for (final db in dbsToClose) {
      await db.close();
    }
    dbsToClose.clear();
  });

  /// 将 JSON 内容写入临时文件，测试结束后自动删除
  File writeTempJson(String content) {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'import_export_test_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    file.writeAsStringSync(content, encoding: utf8);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    return file;
  }

  test('追加记录：自定义排序经 导出 → 导入 往返后保留', () async {
    if (!ffiAvailable) {
      markTestSkipped('sqlite3 原生库不可用（Windows 需将 sqlite3.dll 置于 .dart_tool/）');
      return;
    }
    // ── 准备源数据：1 周期 + 1 阶段 + 3 条追加记录 ──
    await openFreshDb();
    final db = DatabaseService.instance;
    final periodId = await db.insert('mod_period_book_periods', {
      'start_date': '2026-01-10',
      'end_date': '2026-01-18',
      'base_amount': 1000.0,
      'is_closed': 1,
      'created_at': '2026-01-10T00:00:00.000',
      'updated_at': '2026-01-10T00:00:00.000',
    });
    final stageId = await db.insert('mod_period_book_stages', {
      'period_id': periodId,
      'start_date': '2026-01-10',
      'end_date': '2026-01-18',
      'balance': 500.0,
      'sort_order': 1,
      'created_at': '2026-01-10T00:00:00.000',
      'updated_at': '2026-01-18T00:00:00.000',
    });

    final service = PeriodBookService.instance;
    await service.addAddition(stageId, 100, '先添加'); // sort 0
    await service.addAddition(stageId, 200, '后添加'); // sort 1
    await service.addAddition(stageId, 300, '最后添加'); // sort 2

    // 模拟用户拖拽排序为 [最后添加, 先添加, 后添加]
    final additions = await service.getAdditionsByStage(stageId);
    await service.updateAdditionsOrder([
      additions[2],
      additions[0],
      additions[1],
    ]);

    // ── 导出 ──
    final bytes = await ImportExportService.instance.generateExportBytes();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final exported = (payload['data']['period_book_additions'] as List)
        .cast<Map<String, dynamic>>();

    expect(exported.length, 3);
    expect(exported.every((a) => a.containsKey('sort_order')), isTrue,
        reason: '导出 JSON 应包含 sort_order 字段');
    expect(
      exported.map((a) => a['reason']).toList(),
      ['最后添加', '先添加', '后添加'],
      reason: '导出文件中记录顺序应与应用内显示顺序一致',
    );

    // ── 导入到新库 ──
    final tempFile = writeTempJson(utf8.decode(bytes));
    final preview =
        ImportExportService.instance.previewImportFromPath(tempFile.path);
    expect(preview.isReady, isTrue, reason: preview.error);
    expect(preview.bookAdditionsCount, 3);

    await openFreshDb(); // 切换到全新空库
    final result =
        await ImportExportService.instance.executeImport(tempFile.path);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.bookAdditionsCount, 3);

    // ── 验证导入后顺序与原自定义顺序一致 ──
    final imported = await service.getAdditionsByStage(stageId);
    expect(imported.map((a) => a.reason).toList(),
        ['最后添加', '先添加', '后添加']);
    expect(imported.map((a) => a.sortOrder).toList(), [0, 1, 2]);
  });

  test('旧格式导入文件（无 sort_order）可导入，回退按 created_at 排序', () async {
    if (!ffiAvailable) {
      markTestSkipped('sqlite3 原生库不可用（Windows 需将 sqlite3.dll 置于 .dart_tool/）');
      return;
    }
    await openFreshDb();

    // 模拟 a.json / b.json 这类早期手工整理的导入文件：追加记录不含 sort_order
    final legacyJson = {
      'version': 2,
      'appName': 'my_assistant',
      'data': {
        'period_book_periods': [
          {
            'id': 111,
            'start_date': '2026-01-10',
            'end_date': '2026-02-09',
            'base_amount': 1000.0,
            'is_closed': 1,
            'created_at': '2026-01-10T00:00:00.000',
            'updated_at': '2026-01-10T00:00:00.000',
          }
        ],
        'period_book_stages': [
          {
            'id': 222,
            'period_id': 111,
            'start_date': '2026-01-10',
            'end_date': '2026-01-18',
            'balance': 500.0,
            'sort_order': 1,
            'created_at': '2026-01-10T00:00:00.000',
            'updated_at': '2026-01-18T00:00:00.000',
          }
        ],
        'period_book_additions': [
          {
            'id': 333,
            'stage_id': 222,
            'amount': 100.0,
            'reason': '转入',
            'created_at': '2026-01-11T00:00:00.000',
          },
          {
            'id': 334,
            'stage_id': 222,
            'amount': 200.0,
            'reason': '红包',
            'created_at': '2026-01-12T00:00:00.000',
          },
        ],
      },
    };
    final tempFile = writeTempJson(jsonEncode(legacyJson));

    final preview =
        ImportExportService.instance.previewImportFromPath(tempFile.path);
    expect(preview.isReady, isTrue, reason: preview.error);
    expect(preview.bookAdditionsCount, 2);

    final result =
        await ImportExportService.instance.executeImport(tempFile.path);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.bookAdditionsCount, 2);

    final additions =
        await PeriodBookService.instance.getAdditionsByStage(222);
    expect(additions.map((a) => a.reason).toList(), ['转入', '红包'],
        reason: 'sort_order 相同（默认 0）时应按 created_at 排序');
    expect(additions.every((a) => a.sortOrder == 0), isTrue,
        reason: '缺失 sort_order 时应默认为 0');
  });
}

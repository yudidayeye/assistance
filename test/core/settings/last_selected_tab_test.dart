import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/module_system/module_context.dart';
import 'package:my_assistant/core/module_system/module_registry.dart';
import 'package:my_assistant/core/module_system/module_summary.dart';
import 'package:my_assistant/core/module_system/tool_module.dart';
import 'package:my_assistant/core/settings/settings_service.dart';
import 'package:my_assistant/core/storage/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 测试用最小模块实现（loadSettings 需遍历已注册模块）
class _StubModule extends ToolModule {
  _StubModule(this._id);

  final String _id;

  @override
  String get moduleId => _id;

  @override
  String get displayName => '模块$_id';

  @override
  String get description => '测试桩模块';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.extension);

  @override
  Color get themeColor => Colors.blue;

  @override
  Widget buildEntryPage(BuildContext context) => const SizedBox.shrink();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  Future<void> onRegister(ModuleContext context) async {}

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async => const ModuleSummary(line1: '');
}

void main() {
  final dbService = DatabaseService.instance;
  final settings = SettingsService.instance;

  setUpAll(() async {
    if (Platform.isWindows) {
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final testDb =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbService.useDatabaseForTesting(testDb);
    await dbService.createSchemaForTesting(testDb);

    await ModuleRegistry.instance.registerAll([
      _StubModule('mod_t1'),
      _StubModule('mod_t2'),
    ]);
    await settings.seedDefaultsForModules();
    await settings.loadSettings();
  });

  test('默认无记录时 lastSelectedTab 回退为 toolbox', () async {
    // 清空历史记录，模拟全新安装
    await dbService.delete('app_settings',
        where: "key = 'last_selected_tab'");
    await settings.loadSettings();

    expect(settings.lastSelectedTab, 'toolbox');
  });

  test('setLastSelectedTab 往返持久化，模拟重启后仍保持', () async {
    await settings.setLastSelectedTab('mod_t2');
    expect(settings.lastSelectedTab, 'mod_t2');

    // 模拟应用重启：重新从数据库加载
    await settings.loadSettings();
    expect(settings.lastSelectedTab, 'mod_t2');

    // DB 中确有一行
    final rows = await dbService.query('app_settings',
        where: "key = 'last_selected_tab'");
    expect(rows, hasLength(1));
    expect(rows.first['value'], 'mod_t2');

    // 切换到「我的」后再重启保持
    await settings.setLastSelectedTab('profile');
    await settings.loadSettings();
    expect(settings.lastSelectedTab, 'profile');
  });
}

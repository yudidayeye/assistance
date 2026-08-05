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

/// 测试用最小模块实现
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
  final controller = SettingsController.instance;
  final registry = ModuleRegistry.instance;

  List<String> orderedIds() =>
      registry.orderedModules.map((m) => m.moduleId).toList();

  List<String> enabledIds() =>
      registry.getEnabledModules().map((m) => m.moduleId).toList();

  setUpAll(() async {
    if (Platform.isWindows) {
      // flutter test 环境下 sqlite3 走 system 查找（sqlite3.dll），
      // 而 dll 实际位于 windows/runner/。先按路径预加载该模块，
      // 之后系统对 sqlite3.dll 的查找会命中这个已加载的模块。
      // 若文件不存在，请先运行 windows/setup_sqlite3.bat。
      DynamicLibrary.open(r'windows\runner\sqlite3.dll');
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final testDb =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbService.useDatabaseForTesting(testDb);
    await dbService.createSchemaForTesting(testDb);

    await registry.registerAll([
      _StubModule('mod_a'),
      _StubModule('mod_b'),
      _StubModule('mod_c'),
    ]);
    await settings.seedDefaultsForModules();
    await settings.loadSettings();
  });

  test('未保存顺序时使用注册顺序', () async {
    // 重置为无自定义顺序
    await settings.setModuleOrder([]);
    await settings.loadSettings();

    expect(orderedIds(), ['mod_a', 'mod_b', 'mod_c']);
    expect(enabledIds(), ['mod_a', 'mod_b', 'mod_c']);
  });

  test('setModuleOrder 后首页与设置页顺序同步更新', () async {
    await settings.setModuleOrder(['mod_c', 'mod_a', 'mod_b']);

    expect(orderedIds(), ['mod_c', 'mod_a', 'mod_b']);
    expect(enabledIds(), ['mod_c', 'mod_a', 'mod_b']);
  });

  test('顺序持久化，重新加载后保持', () async {
    await settings.setModuleOrder(['mod_b', 'mod_c', 'mod_a']);
    // 模拟应用重启：从数据库重新加载
    await settings.loadSettings();

    expect(settings.moduleOrder, ['mod_b', 'mod_c', 'mod_a']);
    expect(orderedIds(), ['mod_b', 'mod_c', 'mod_a']);
  });

  test('保存顺序中缺失的新注册模块按注册顺序追加到末尾', () async {
    await settings.setModuleOrder(['mod_b']);

    expect(orderedIds(), ['mod_b', 'mod_a', 'mod_c']);
  });

  test('保存顺序中的失效模块 ID 被忽略', () async {
    await settings.setModuleOrder(['ghost_module', 'mod_c', 'mod_a']);

    expect(orderedIds(), ['mod_c', 'mod_a', 'mod_b']);
  });

  test('禁用中间模块不影响其余模块顺序', () async {
    await settings.setModuleOrder(['mod_c', 'mod_a', 'mod_b']);
    await settings.setModuleEnabled('mod_a', false);

    expect(enabledIds(), ['mod_c', 'mod_b']);

    // 恢复启用
    await settings.setModuleEnabled('mod_a', true);
    expect(enabledIds(), ['mod_c', 'mod_a', 'mod_b']);
  });

  test('SettingsController.setModuleOrder 通知监听者', () async {
    var notified = false;
    void listener() => notified = true;

    controller.addListener(listener);
    await controller.setModuleOrder(['mod_a', 'mod_b', 'mod_c']);
    controller.removeListener(listener);

    expect(notified, isTrue);
    expect(orderedIds(), ['mod_a', 'mod_b', 'mod_c']);
  });
}

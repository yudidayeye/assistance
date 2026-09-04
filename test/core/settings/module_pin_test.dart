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

  final ids = ['mod_p1', 'mod_p2', 'mod_p3'];

  List<String> pinnedIds() =>
      registry.getPinnedModules().map((m) => m.moduleId).toList();

  setUpAll(() async {
    if (Platform.isWindows) {
      // flutter test 环境下 sqlite3 走 system 查找（sqlite3.dll），
      // 而 dll 实际位于 windows/runner/。先按路径预加载该模块。
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
      _StubModule('mod_p1'),
      _StubModule('mod_p2'),
      _StubModule('mod_p3'),
    ]);
    await settings.seedDefaultsForModules();
    await settings.loadSettings();
  });

  /// 归一到初始状态：全部启用、均不固定、注册顺序
  Future<void> resetAll() async {
    for (final id in ids) {
      await settings.setModuleEnabled(id, true);
      await settings.setModulePinned(id, false);
    }
    await settings.setModuleOrder([]);
  }

  test('默认未固定：isModulePinned 为 false 且不在固定列表', () async {
    await resetAll();

    for (final id in ids) {
      expect(settings.isModulePinned(id), isFalse);
    }
    expect(pinnedIds(), isEmpty);
  });

  test('setModulePinned 往返持久化，重新加载后保持', () async {
    await resetAll();
    await settings.setModulePinned('mod_p1', true);
    await settings.setModulePinned('mod_p3', true);

    expect(settings.isModulePinned('mod_p1'), isTrue);
    expect(settings.isModulePinned('mod_p2'), isFalse);
    expect(settings.isModulePinned('mod_p3'), isTrue);

    // 模拟应用重启：从数据库重新加载
    await settings.loadSettings();

    expect(settings.isModulePinned('mod_p1'), isTrue);
    expect(settings.isModulePinned('mod_p3'), isTrue);
    expect(settings.isModulePinned('mod_p2'), isFalse);
  });

  test('禁用模块自动清除固定（缓存 + DB 行），重新启用不恢复固定', () async {
    await resetAll();
    await settings.setModulePinned('mod_p1', true);
    expect(settings.isModulePinned('mod_p1'), isTrue);

    await settings.setModuleEnabled('mod_p1', false);

    expect(settings.isModuleEnabled('mod_p1'), isFalse);
    expect(settings.isModulePinned('mod_p1'), isFalse);
    final rows = await dbService.query('app_settings',
        where: "key = 'module_pinned_mod_p1'");
    expect(rows, hasLength(1));
    expect(rows.first['value'], '0');

    // 重新启用不会恢复固定
    await settings.setModuleEnabled('mod_p1', true);
    expect(settings.isModuleEnabled('mod_p1'), isTrue);
    expect(settings.isModulePinned('mod_p1'), isFalse);
  });

  test('getPinnedModules 遵循 moduleOrder 且过滤未启用模块', () async {
    await resetAll();
    await settings.setModuleOrder(['mod_p3', 'mod_p1', 'mod_p2']);

    // 停用 mod_p1 后仍强制写入固定（模拟“固定但禁用”的陈旧状态）
    await settings.setModuleEnabled('mod_p1', false);
    await settings.setModulePinned('mod_p1', true);
    await settings.setModulePinned('mod_p2', true);
    await settings.setModulePinned('mod_p3', true);

    // mod_p1 未启用被过滤，其余按顺序
    expect(pinnedIds(), ['mod_p3', 'mod_p2']);
  });

  test('重新加载后清除「固定但禁用」的陈旧状态并落库为 0', () async {
    await resetAll();
    await settings.setModuleEnabled('mod_p1', false);
    // 绕过 API 直接写库，模拟导入恢复出的矛盾状态：固定=1 且 启用=0
    await dbService.insert('app_settings', {
      'key': 'module_pinned_mod_p1',
      'value': '1',
    });

    await settings.loadSettings();

    expect(settings.isModulePinned('mod_p1'), isFalse);
    final rows = await dbService.query('app_settings',
        where: "key = 'module_pinned_mod_p1'");
    expect(rows.first['value'], '0');
  });

  test('SettingsController.setModulePinned / setModuleEnabled 通知监听者', () async {
    await resetAll();
    var notified = 0;
    void listener() => notified++;

    controller.addListener(listener);
    await controller.setModulePinned('mod_p1', true);
    await controller.setModuleEnabled('mod_p1', false); // 联动清固定
    controller.removeListener(listener);

    expect(notified, greaterThanOrEqualTo(2));
    expect(settings.isModulePinned('mod_p1'), isFalse);
    expect(controller.isModulePinned('mod_p1'), isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_assistant/core/module_system/module_context.dart';
import 'package:my_assistant/core/module_system/module_registry.dart';
import 'package:my_assistant/core/module_system/module_summary.dart';
import 'package:my_assistant/core/module_system/tool_module.dart';

class _StubModule extends ToolModule {
  _StubModule(this._id);

  final String _id;
  int registerCount = 0;
  int openCount = 0;

  @override
  String get moduleId => _id;

  @override
  String get displayName => _id;

  @override
  String get description => '';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.extension);

  @override
  Color get themeColor => Colors.blue;

  @override
  Widget buildEntryPage(BuildContext context) => const SizedBox.shrink();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  Future<void> onRegister(ModuleContext context) async {
    registerCount++;
  }

  @override
  Future<void> onOpen(ModuleContext context) async {
    openCount++;
  }

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async => const ModuleSummary(line1: '');
}

void main() {
  final registry = ModuleRegistry.instance;

  setUp(() => registry.reset());
  tearDown(() => registry.reset());

  test('重复注册相同模块 ID 会被拒绝', () async {
    await registry.register(_StubModule('period_book'));

    await expectLater(
      registry.register(_StubModule('period_book')),
      throwsA(isA<StateError>()),
    );
  });

  test('reset 清除已注册模块并允许重新注册', () async {
    final first = _StubModule('period_book');
    final replacement = _StubModule('period_book');
    await registry.register(first);
    await registry.initializeAll();

    registry.reset();
    await registry.register(replacement);
    await registry.initializeAll();

    expect(registry.allModules, [replacement]);
    expect(first.registerCount, 1);
    expect(first.openCount, 1);
    expect(replacement.registerCount, 1);
    expect(replacement.openCount, 1);
  });
}

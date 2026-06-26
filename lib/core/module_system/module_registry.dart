import 'tool_module.dart';
import 'module_context.dart';
import '../settings/settings_service.dart';

/// 模块注册中心
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._();

  ModuleRegistry._();

  final Map<String, ToolModule> _modules = {};
  bool _initialized = false;

  /// 异步注册单个模块，确保 onRegister() 被 await
  Future<void> register(ToolModule module) async {
    if (_modules.containsKey(module.moduleId)) {
      throw StateError('Module "${module.moduleId}" is already registered');
    }
    _modules[module.moduleId] = module;
    await module.onRegister(ModuleContext(moduleId: module.moduleId));
  }

  /// 批量注册模块并等待所有 onRegister 完成
  Future<void> registerAll(List<ToolModule> modules) async {
    for (final module in modules) {
      await register(module);
    }
  }

  /// 初始化所有模块
  Future<void> initializeAll() async {
    if (_initialized) return;
    for (final module in _modules.values) {
      await module.onOpen(ModuleContext(moduleId: module.moduleId));
    }
    _initialized = true;
  }

  /// 获取所有已注册模块
  List<ToolModule> get allModules => _modules.values.toList();

  /// 获取已启用模块
  List<ToolModule> getEnabledModules() {
    return _modules.values
        .where((m) => SettingsService.instance.isModuleEnabled(m.moduleId))
        .toList();
  }

  /// 根据ID获取模块
  ToolModule? getModule(String moduleId) => _modules[moduleId];
}
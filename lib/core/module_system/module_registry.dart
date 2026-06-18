import 'tool_module.dart';
import 'module_context.dart';
import '../settings/settings_service.dart';

/// 模块注册中心
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._();

  ModuleRegistry._();

  final Map<String, ToolModule> _modules = {};
  bool _initialized = false;

  /// 注册模块
  void register(ToolModule module) {
    _modules[module.moduleId] = module;
    module.onRegister(ModuleContext(moduleId: module.moduleId));
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
  List<ToolModule> getEnabledModules(SettingsService settings) {
    return _modules.values
        .where((m) => settings.isModuleEnabled(m.moduleId))
        .toList();
  }

  /// 根据ID获取模块
  ToolModule? getModule(String moduleId) => _modules[moduleId];
}
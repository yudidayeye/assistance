import 'package:flutter/foundation.dart';
import '../storage/database_service.dart';
import '../module_system/module_registry.dart';

/// 设置服务 — 管理模块启用状态和全局配置
class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  final DatabaseService _db = DatabaseService.instance;

  /// 基于已注册模块动态 seed 默认启用状态（仅首次启动）
  Future<void> seedDefaultsForModules() async {
    final existing =
        await _db.query('app_settings', where: "key LIKE 'module_enabled_%'");
    if (existing.isNotEmpty) return; // 已有设置，跳过

    for (final module in ModuleRegistry.instance.allModules) {
      await _db.insert('app_settings', {
        'key': 'module_enabled_${module.moduleId}',
        'value': '1',
      });
    }
  }

  /// 检查模块是否启用
  bool isModuleEnabled(String moduleId) {
    return _moduleEnabledCache[moduleId] ?? true;
  }

  final Map<String, bool> _moduleEnabledCache = {};

  /// 模块展示顺序缓存（moduleId 列表，空表示使用默认注册顺序）
  List<String> _moduleOrderCache = [];

  /// 获取已保存的模块展示顺序
  List<String> get moduleOrder => List.unmodifiable(_moduleOrderCache);

  /// 从数据库加载设置到缓存
  Future<void> loadSettings() async {
    final rows =
        await _db.query('app_settings', where: "key LIKE 'module_enabled_%'");
    for (final row in rows) {
      final key = row['key'] as String;
      final moduleId = key.replaceFirst('module_enabled_', '');
      _moduleEnabledCache[moduleId] = row['value'] == '1';
    }
    // 确保未在数据库中的已注册模块默认启用
    for (final module in ModuleRegistry.instance.allModules) {
      _moduleEnabledCache.putIfAbsent(module.moduleId, () => true);
    }
    // 加载模块展示顺序
    await _loadModuleOrder();
    // 加载固定状态（默认未固定）
    final pinnedRows =
        await _db.query('app_settings', where: "key LIKE 'module_pinned_%'");
    for (final row in pinnedRows) {
      final key = row['key'] as String;
      final moduleId = key.replaceFirst('module_pinned_', '');
      _modulePinnedCache[moduleId] = row['value'] == '1';
    }
    // 不变量：固定 ⟹ 启用。清除「已固定但被禁用」的陈旧状态（含导入恢复场景）。
    for (final module in ModuleRegistry.instance.allModules) {
      final moduleId = module.moduleId;
      if ((_modulePinnedCache[moduleId] ?? false) &&
          !isModuleEnabled(moduleId)) {
        _modulePinnedCache[moduleId] = false;
        await _db.upsertSetting('module_pinned_$moduleId', '0');
      }
    }
    // 加载隐私声明
    await loadPrivacyDisclaimer();
  }

  /// 设置模块启用状态
  ///
  /// 关闭启用时联动清除固定状态，保证「固定 ⟹ 启用」不变量成立。
  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    _moduleEnabledCache[moduleId] = enabled;
    if (!enabled) {
      final wasPinned = _modulePinnedCache[moduleId] ?? false;
      _modulePinnedCache[moduleId] = false;
      if (wasPinned) {
        await _db.upsertSetting('module_pinned_$moduleId', '0');
      }
    }
    await _db.upsertSetting('module_enabled_$moduleId', enabled ? '1' : '0');
  }

  final Map<String, bool> _modulePinnedCache = {};

  /// 检查模块是否已固定到底部导航
  bool isModulePinned(String moduleId) {
    return _modulePinnedCache[moduleId] ?? false;
  }

  /// 设置模块固定状态（固定/取消固定）并持久化
  Future<void> setModulePinned(String moduleId, bool pinned) async {
    _modulePinnedCache[moduleId] = pinned;
    await _db.upsertSetting('module_pinned_$moduleId', pinned ? '1' : '0');
  }

  /// 从数据库加载模块展示顺序
  Future<void> _loadModuleOrder() async {
    final rows = await _db.query('app_settings',
        where: "key = 'module_order'");
    if (rows.isEmpty) {
      _moduleOrderCache = [];
      return;
    }
    final value = (rows.first['value'] as String?) ?? '';
    _moduleOrderCache =
        value.split(',').where((id) => id.isNotEmpty).toList();
  }

  /// 保存模块展示顺序（同步更新缓存，再持久化）
  Future<void> setModuleOrder(List<String> moduleIds) async {
    _moduleOrderCache = List.of(moduleIds);
    await _db.upsertSetting('module_order', moduleIds.join(','));
  }

  /// 获取免责声明确认状态
  bool hasAcceptedPrivacyDisclaimer() {
    return _privacyAccepted;
  }

  bool _privacyAccepted = false;

  Future<void> setPrivacyDisclaimerAccepted() async {
    _privacyAccepted = true;
    await _db.insert(
        'app_settings', {'key': 'privacy_disclaimer_accepted', 'value': '1'});
  }

  Future<void> loadPrivacyDisclaimer() async {
    final rows = await _db.query('app_settings',
        where: "key = 'privacy_disclaimer_accepted'");
    _privacyAccepted = rows.isNotEmpty && rows.first['value'] == '1';
  }
}

/// 设置状态控制器 — ChangeNotifier，供 UI 层监听模块启停变化
class SettingsController extends ChangeNotifier {
  static final SettingsController instance = SettingsController._();
  SettingsController._();

  final SettingsService _service = SettingsService.instance;

  bool isModuleEnabled(String moduleId) => _service.isModuleEnabled(moduleId);

  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    await _service.setModuleEnabled(moduleId, enabled);
    notifyListeners();
  }

  /// 保存模块展示顺序并通知 UI（首页卡片顺序随之更新）
  Future<void> setModuleOrder(List<String> moduleIds) async {
    await _service.setModuleOrder(moduleIds);
    notifyListeners();
  }

  bool isModulePinned(String moduleId) => _service.isModulePinned(moduleId);

  /// 固定/取消固定模块并通知 UI（底部导航随之实时更新）
  Future<void> setModulePinned(String moduleId, bool pinned) async {
    await _service.setModulePinned(moduleId, pinned);
    notifyListeners();
  }

  /// 从数据库重新加载设置并通知 UI
  Future<void> reload() async {
    await _service.loadSettings();
    notifyListeners();
  }
}

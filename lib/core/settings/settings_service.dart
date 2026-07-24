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
    // 加载隐私声明
    await loadPrivacyDisclaimer();
  }

  /// 设置模块启用状态
  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    _moduleEnabledCache[moduleId] = enabled;
    await _db.upsertSetting('module_enabled_$moduleId', enabled ? '1' : '0');
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

  /// 从数据库重新加载设置并通知 UI
  Future<void> reload() async {
    await _service.loadSettings();
    notifyListeners();
  }
}

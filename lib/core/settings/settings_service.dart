import '../storage/database_service.dart';

/// 设置服务 — 管理模块启用状态和全局配置
class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  final DatabaseService _db = DatabaseService.instance;

  /// 初始化默认设置（首次启动）
  Future<void> initializeDefaults() async {
    // 确保所有模块默认启用
    final existing = await _db.query('app_settings', where: "key LIKE 'module_enabled_%'");
    if (existing.isEmpty) {
      await _db.insert('app_settings', {'key': 'module_enabled_accounting', 'value': '1'});
      await _db.insert('app_settings', {'key': 'module_enabled_period_tracker', 'value': '1'});
    }
  }

  /// 检查模块是否启用
  bool isModuleEnabled(String moduleId) {
    // 默认启用
    return _moduleEnabledCache[moduleId] ?? true;
  }

  final Map<String, bool> _moduleEnabledCache = {};

  /// 从数据库加载设置到缓存
  Future<void> loadSettings() async {
    final rows = await _db.query('app_settings', where: "key LIKE 'module_enabled_%'");
    for (final row in rows) {
      final key = row['key'] as String;
      final moduleId = key.replaceFirst('module_enabled_', '');
      _moduleEnabledCache[moduleId] = row['value'] == '1';
    }
    // 确保默认启用未在数据库中的模块
    _moduleEnabledCache['accounting'] ??= true;
    _moduleEnabledCache['period_tracker'] ??= true;
  }

  /// 设置模块启用状态
  Future<void> setModuleEnabled(String moduleId, bool enabled) async {
    _moduleEnabledCache[moduleId] = enabled;
    await _db.update(
      'app_settings',
      {'value': enabled ? '1' : '0'},
      where: 'key = ?',
      whereArgs: ['module_enabled_$moduleId'],
    );
  }

  /// 获取免责声明确认状态
  bool hasAcceptedPrivacyDisclaimer() {
    return _privacyAccepted;
  }

  bool _privacyAccepted = false;

  Future<void> setPrivacyDisclaimerAccepted() async {
    _privacyAccepted = true;
    await _db.insert('app_settings', {'key': 'privacy_disclaimer_accepted', 'value': '1'});
  }

  Future<void> loadPrivacyDisclaimer() async {
    final rows = await _db.query('app_settings', where: "key = 'privacy_disclaimer_accepted'");
    _privacyAccepted = rows.isNotEmpty && rows.first['value'] == '1';
  }
}
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
    // 加载工具箱展示样式（单列/双列）
    final colRows = await _db.query('app_settings',
        where: "key = 'toolbox_columns'");
    _toolboxColumns = (colRows.isNotEmpty && colRows.first['value'] == '1')
        ? '1'
        : '2';
    // 加载隐私声明
    await loadPrivacyDisclaimer();
    // 加载用户昵称与头像
    await _loadUserProfile();
    // 加载上次选中的底部 Tab
    await _loadLastSelectedTab();
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

  // ─────────────────────────────────────────────────────────
  // 工具箱展示样式偏好
  // ─────────────────────────────────────────────────────────

  String _toolboxColumns = '2';

  /// 工具箱模块区的展示列数（'1' 单列 / '2' 双列）
  String get toolboxColumns => _toolboxColumns;

  /// 设置工具箱展示列数并持久化（非法值一律回退双列）
  Future<void> setToolboxColumns(String value) async {
    _toolboxColumns = value == '1' ? '1' : '2';
    await _db.upsertSetting('toolbox_columns', _toolboxColumns);
  }

  // ─────────────────────────────────────────────────────────
  // 用户身份（昵称 + 头像）
  // ─────────────────────────────────────────────────────────

  /// 未设置昵称时的默认展示名
  static const String defaultUserName = '用户';

  String _userName = defaultUserName;

  /// 头像 base64（无头像时为 null；空串统一规整为 null）
  String? _avatarB64;

  /// 当前用户昵称（未设置时回退 [defaultUserName]）
  String get userName => _userName;

  /// 当前头像 base64，无头像时为 null
  String? get avatarB64 => _avatarB64;

  /// 从数据库加载用户昵称与头像到缓存
  Future<void> _loadUserProfile() async {
    final nameRows =
        await _db.query('app_settings', where: "key = 'user_name'");
    _userName = (nameRows.isNotEmpty &&
            (nameRows.first['value'] as String? ?? '').trim().isNotEmpty)
        ? (nameRows.first['value'] as String).trim()
        : defaultUserName;

    final avatarRows =
        await _db.query('app_settings', where: "key = 'user_avatar'");
    final raw = avatarRows.isNotEmpty
        ? (avatarRows.first['value'] as String? ?? '')
        : '';
    _avatarB64 = raw.isEmpty ? null : raw;
  }

  /// 保存用户昵称并持久化（去首尾空白，空值忽略）
  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _userName = trimmed;
    await _db.upsertSetting('user_name', trimmed);
  }

  /// 保存用户头像 base64 并持久化（传空串即「移除头像」）
  Future<void> setUserAvatar(String b64) async {
    _avatarB64 = b64.isEmpty ? null : b64;
    await _db.upsertSetting('user_avatar', b64);
  }

  // ─────────────────────────────────────────────────────────
  // 底部导航上次选中项（重启后恢复）
  // ─────────────────────────────────────────────────────────

  String _lastTabId = 'toolbox';

  /// 上次选中的底部 Tab 标识：'toolbox' | 模块 moduleId | 'profile'
  String get lastSelectedTab => _lastTabId;

  /// 保存当前选中的底部 Tab 并持久化，供下次启动恢复
  Future<void> setLastSelectedTab(String tabId) async {
    _lastTabId = tabId;
    await _db.upsertSetting('last_selected_tab', tabId);
  }

  /// 从数据库加载上次选中的底部 Tab（无记录则回退工具箱）
  Future<void> _loadLastSelectedTab() async {
    final rows =
        await _db.query('app_settings', where: "key = 'last_selected_tab'");
    _lastTabId = (rows.isNotEmpty &&
            (rows.first['value'] as String? ?? '').isNotEmpty)
        ? (rows.first['value'] as String)
        : 'toolbox';
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

  /// 工具箱展示列数（'1'/'2'）
  String get toolboxColumns => _service.toolboxColumns;

  /// 设置工具箱展示列数并通知 UI（模块网格随之实时重排）
  Future<void> setToolboxColumns(String value) async {
    await _service.setToolboxColumns(value);
    notifyListeners();
  }

  /// 当前用户昵称（未设置时回退默认名）
  String get userName => _service.userName;

  /// 当前头像 base64（无头像时为 null）
  String? get avatarB64 => _service.avatarB64;

  /// 保存昵称并通知 UI（工具箱欢迎区随之更新）
  Future<void> setUserName(String name) async {
    await _service.setUserName(name);
    notifyListeners();
  }

  /// 保存头像 base64（空串 = 移除头像）并通知 UI
  Future<void> setUserAvatar(String b64) async {
    await _service.setUserAvatar(b64);
    notifyListeners();
  }

  /// 上次选中的底部 Tab 标识（'toolbox' | 模块 moduleId | 'profile'）
  ///
  /// 只读透传：Tab 由 MainShellPage 自管状态，无需经控制器广播。
  String get lastSelectedTab => _service.lastSelectedTab;

  /// 从数据库重新加载设置并通知 UI
  Future<void> reload() async {
    await _service.loadSettings();
    notifyListeners();
  }
}

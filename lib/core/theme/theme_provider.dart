import 'package:flutter/material.dart';
import '../storage/database_service.dart';
import 'app_theme.dart';

/// 主题类型枚举 — 4 套柔和配色
enum AppThemeType {
  softNight('柔夜', Color(0xFF7B8BAA)),
  morningMist('晨雾', Color(0xFF8AADB8)),
  leafWhisper('叶语', Color(0xFF9CAD8A)),
  flowerMist('花雾', Color(0xFFC9A0AA));

  final String label;
  final Color color;
  const AppThemeType(this.label, this.color);

  /// 旧名称 → 新枚举的迁移映射
  static AppThemeType fromLegacyName(String legacyName) {
    return switch (legacyName) {
      'gold' => AppThemeType.softNight,
      'blue' => AppThemeType.morningMist,
      'green' => AppThemeType.leafWhisper,
      'pink' => AppThemeType.flowerMist,
      _ => AppThemeType.values.firstWhere(
          (t) => t.name == legacyName,
          orElse: () => AppThemeType.softNight,
        ),
    };
  }
}

/// 主题管理器 — 全局单例
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  AppThemeType _currentTheme = AppThemeType.softNight;
  AppThemeType get currentTheme => _currentTheme;

  /// 从数据库加载主题设置（兼容旧名称）
  Future<void> loadTheme() async {
    final db = DatabaseService.instance;
    final rows = await db.query('app_settings', where: "key = 'theme_type'");
    if (rows.isNotEmpty) {
      final themeName = rows.first['value'] as String;
      _currentTheme = AppThemeType.fromLegacyName(themeName);
    }
  }

  /// 切换主题
  Future<void> setTheme(AppThemeType type) async {
    if (_currentTheme == type) return;
    _currentTheme = type;
    notifyListeners();

    // 持久化到数据库
    final db = DatabaseService.instance;
    final existing = await db.query('app_settings', where: "key = 'theme_type'");
    if (existing.isEmpty) {
      await db.insert('app_settings', {'key': 'theme_type', 'value': type.name});
    } else {
      await db.update(
        'app_settings',
        {'value': type.name},
        where: 'key = ?',
        whereArgs: ['theme_type'],
      );
    }
  }

  /// 获取当前主题数据
  ThemeData get themeData => AppTheme.getTheme(_currentTheme);
}

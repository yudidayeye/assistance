import 'package:flutter/material.dart';
import '../storage/database_service.dart';
import 'app_theme.dart';

/// 主题类型枚举
enum AppThemeType {
  gold('金色', Color(0xFFD4AF37)),
  blue('蓝色', Color(0xFF4A90D9)),
  green('绿色', Color(0xFF4CAF50)),
  pink('粉色', Color(0xFFE91E63));

  final String label;
  final Color color;
  const AppThemeType(this.label, this.color);
}

/// 主题管理器 — 全局单例
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  AppThemeType _currentTheme = AppThemeType.gold;
  AppThemeType get currentTheme => _currentTheme;

  /// 从数据库加载主题设置
  Future<void> loadTheme() async {
    final db = DatabaseService.instance;
    final rows = await db.query('app_settings', where: "key = 'theme_type'");
    if (rows.isNotEmpty) {
      final themeName = rows.first['value'] as String;
      _currentTheme = AppThemeType.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => AppThemeType.gold,
      );
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

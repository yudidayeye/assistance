import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_extension.dart';
import 'theme_provider.dart';

/// 应用主题 — 支持多套配色
class AppTheme {
  AppTheme._();

  // ── 通用属性 ──────────────────────────────────────
  static const Color _white = Colors.white;
  static const Color _error = Color(0xFFCF6679);

  // ── 金色配色（默认）──────────────────────────────────
  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFF5E6CC);
  static const Color _goldDark = Color(0xFFB8941F);
  static const Color _goldEarth = Color(0xFF2C1810);
  static const Color _goldEarthLight = Color(0xFF4A3228);
  static const Color _goldEarthMedium = Color(0xFF8B6F5C);
  static const Color _goldCream = Color(0xFFFDF8F0);
  static const Color _goldCreamDark = Color(0xFFF5EDE0);
  static const Color _goldSage = Color(0xFF7A8B6F);
  static const Color _goldSageLight = Color(0xFFB8C4AB);
  static const Color _goldRose = Color(0xFFC97D7D);
  static const Color _goldRoseLight = Color(0xFFE8B4B4);

  // ── 蓝色配色 ──────────────────────────────────────
  static const Color _bluePrimary = Color(0xFF4A90D9);
  static const Color _blueLight = Color(0xFFD6E8FA);
  static const Color _blueDark = Color(0xFF2E6DB4);
  static const Color _blueEarth = Color(0xFF1A2332);
  static const Color _blueEarthLight = Color(0xFF2D3F55);
  static const Color _blueEarthMedium = Color(0xFF6B7D94);
  static const Color _blueCream = Color(0xFFF5F8FC);
  static const Color _blueCreamDark = Color(0xFFE8EFF7);
  static const Color _blueSage = Color(0xFF5C9AC9);
  static const Color _blueSageLight = Color(0xFFA8CCE8);
  static const Color _blueRose = Color(0xFFE8746A);
  static const Color _blueRoseLight = Color(0xFFF5B8B3);

  // ── 绿色配色 ──────────────────────────────────────
  static const Color _greenPrimary = Color(0xFF4CAF50);
  static const Color _greenLight = Color(0xFFD7EDDA);
  static const Color _greenDark = Color(0xFF388E3C);
  static const Color _greenEarth = Color(0xFF1B2E1C);
  static const Color _greenEarthLight = Color(0xFF2D4A2F);
  static const Color _greenEarthMedium = Color(0xFF6B8B6E);
  static const Color _greenCream = Color(0xFFF5FAF5);
  static const Color _greenCreamDark = Color(0xFFE8F2E9);
  static const Color _greenSage = Color(0xFF81C784);
  static const Color _greenSageLight = Color(0xFFB8DFBA);
  static const Color _greenRose = Color(0xFFFF8A65);
  static const Color _greenRoseLight = Color(0xFFFFC0A8);

  // ── 粉色配色 ──────────────────────────────────────
  static const Color _pinkPrimary = Color(0xFFE91E63);
  static const Color _pinkLight = Color(0xFFFCE4EC);
  static const Color _pinkDark = Color(0xFFC2185B);
  static const Color _pinkEarth = Color(0xFF2D1A22);
  static const Color _pinkEarthLight = Color(0xFF4A2D38);
  static const Color _pinkEarthMedium = Color(0xFF8B6B75);
  static const Color _pinkCream = Color(0xFFFFF5F7);
  static const Color _pinkCreamDark = Color(0xFFFCE8ED);
  static const Color _pinkSage = Color(0xFFF48FB1);
  static const Color _pinkSageLight = Color(0xFFF8BBD0);
  static const Color _pinkRose = Color(0xFF7C4DFF);
  static const Color _pinkRoseLight = Color(0xFFB388FF);

  /// 根据主题类型获取 ThemeData
  static ThemeData getTheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.gold:
        return _buildTheme(
          primary: _goldPrimary,
          primaryLight: _goldLight,
          primaryDark: _goldDark,
          earth: _goldEarth,
          earthLight: _goldEarthLight,
          earthMedium: _goldEarthMedium,
          cream: _goldCream,
          creamDark: _goldCreamDark,
          sage: _goldSage,
          sageLight: _goldSageLight,
          rose: _goldRose,
          roseLight: _goldRoseLight,
        );
      case AppThemeType.blue:
        return _buildTheme(
          primary: _bluePrimary,
          primaryLight: _blueLight,
          primaryDark: _blueDark,
          earth: _blueEarth,
          earthLight: _blueEarthLight,
          earthMedium: _blueEarthMedium,
          cream: _blueCream,
          creamDark: _blueCreamDark,
          sage: _blueSage,
          sageLight: _blueSageLight,
          rose: _blueRose,
          roseLight: _blueRoseLight,
        );
      case AppThemeType.green:
        return _buildTheme(
          primary: _greenPrimary,
          primaryLight: _greenLight,
          primaryDark: _greenDark,
          earth: _greenEarth,
          earthLight: _greenEarthLight,
          earthMedium: _greenEarthMedium,
          cream: _greenCream,
          creamDark: _greenCreamDark,
          sage: _greenSage,
          sageLight: _greenSageLight,
          rose: _greenRose,
          roseLight: _greenRoseLight,
        );
      case AppThemeType.pink:
        return _buildTheme(
          primary: _pinkPrimary,
          primaryLight: _pinkLight,
          primaryDark: _pinkDark,
          earth: _pinkEarth,
          earthLight: _pinkEarthLight,
          earthMedium: _pinkEarthMedium,
          cream: _pinkCream,
          creamDark: _pinkCreamDark,
          sage: _pinkSage,
          sageLight: _pinkSageLight,
          rose: _pinkRose,
          roseLight: _pinkRoseLight,
        );
    }
  }

  /// 构建 ThemeData
  static ThemeData _buildTheme({
    required Color primary,
    required Color primaryLight,
    required Color primaryDark,
    required Color earth,
    required Color earthLight,
    required Color earthMedium,
    required Color cream,
    required Color creamDark,
    required Color sage,
    required Color sageLight,
    required Color rose,
    required Color roseLight,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.dmSans().fontFamily,

      // 色彩
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: _white,
        primaryContainer: primaryLight,
        secondary: sage,
        onSecondary: _white,
        secondaryContainer: sageLight,
        tertiary: rose,
        tertiaryContainer: roseLight,
        surface: cream,
        onSurface: earth,
        error: _error,
        onError: _white,
      ),

      // Scaffold
      scaffoldBackgroundColor: cream,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: earth,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: earth,
          letterSpacing: -0.5,
        ),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: _white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // 输入
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: earthMedium.withAlpha(40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: earthMedium.withAlpha(40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: earthMedium.withAlpha(120)),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _white,
        selectedItemColor: primary,
        unselectedItemColor: earthMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: _white,
        elevation: 4,
        shape: const CircleBorder(),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: earthMedium.withAlpha(20),
        thickness: 1,
        space: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: creamDark,
        selectedColor: primaryLight,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: earth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // 扩展主题
      extensions: [
        AppThemeExtension(
          primary: primary,
          primaryLight: primaryLight,
          primaryDark: primaryDark,
          earth: earth,
          earthLight: earthLight,
          earthMedium: earthMedium,
          cream: cream,
          creamDark: creamDark,
          sage: sage,
          sageLight: sageLight,
          rose: rose,
          roseLight: roseLight,
          gradientPrimary: LinearGradient(
            colors: [primary, primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          gradientEarth: LinearGradient(
            colors: [earth, earthLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        ModuleThemeExtension(moduleColor: primary),
      ],
    );
  }

  /// 创建带有模块主题色的 ThemeData
  static ThemeData withModuleColor(Color moduleColor) {
    final base = getTheme(AppThemeType.gold);
    return base.copyWith(
      extensions: [
        base.extension<AppThemeExtension>()!,
        ModuleThemeExtension(moduleColor: moduleColor),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_extension.dart';

/// 应用主题
class AppTheme {
  AppTheme._();

  // ── 色彩系统 ──────────────────────────────────────
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFF5E6CC);
  static const Color _goldDark = Color(0xFFB8941F);

  static const Color _earth = Color(0xFF2C1810);
  static const Color _earthLight = Color(0xFF4A3228);
  static const Color _earthMedium = Color(0xFF8B6F5C);

  static const Color _cream = Color(0xFFFDF8F0);
  static const Color _creamDark = Color(0xFFF5EDE0);

  static const Color _sage = Color(0xFF7A8B6F);
  static const Color _sageLight = Color(0xFFB8C4AB);

  static const Color _rose = Color(0xFFC97D7D);
  static const Color _roseLight = Color(0xFFE8B4B4);

  static const Color _white = Colors.white;
  static const Color _error = Color(0xFFCF6679);

  // ── 文字色 ───────────────────────────────────────
  static const Color _onDark = Colors.white;
  static const Color _onLight = _earth;
  static const Color _onLightMuted = _earthMedium;

  // ── 间距 ──────────────────────────────────────────
  static const double _r = 16.0;

  // ── 浅色主题 ──────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.dmSans().fontFamily,

    // 色彩
    colorScheme: ColorScheme.light(
      primary: _gold,
      onPrimary: _onDark,
      primaryContainer: _goldLight,
      secondary: _sage,
      onSecondary: _onDark,
      secondaryContainer: _sageLight,
      tertiary: _rose,
      tertiaryContainer: _roseLight,
      surface: _cream,
      onSurface: _onLight,
      error: _error,
      onError: _onDark,
    ),

    // Scaffold
    scaffoldBackgroundColor: _cream,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _onLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.playfairDisplay().fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _onLight,
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
        borderSide: BorderSide(color: _earthMedium.withAlpha(40)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _earthMedium.withAlpha(40)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: _earthMedium.withAlpha(120)),
    ),

    // 按钮
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: _onDark,
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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _white,
      selectedItemColor: _gold,
      unselectedItemColor: _earthMedium,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _gold,
      foregroundColor: _onDark,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: _earthMedium.withAlpha(20),
      thickness: 1,
      space: 0,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _creamDark,
      selectedColor: _goldLight,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _onLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // 扩展主题
    extensions: const [
      AppThemeExtension(
        gold: _gold,
        goldLight: _goldLight,
        goldDark: _goldDark,
        earth: _earth,
        earthLight: _earthLight,
        earthMedium: _earthMedium,
        cream: _cream,
        creamDark: _creamDark,
        sage: _sage,
        sageLight: _sageLight,
        rose: _rose,
        roseLight: _roseLight,
        gradientGold: LinearGradient(
          colors: [_gold, _goldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        gradientEarth: LinearGradient(
          colors: [_earth, _earthLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      ModuleThemeExtension(moduleColor: _gold),
    ],
  );

  /// 创建带有模块主题色的 ThemeData
  static ThemeData withModuleColor(Color moduleColor) {
    return light.copyWith(
      extensions: [
        light.extension<AppThemeExtension>()!,
        ModuleThemeExtension(moduleColor: moduleColor),
      ],
    );
  }
}

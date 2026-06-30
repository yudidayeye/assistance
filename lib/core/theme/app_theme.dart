import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_extension.dart';
import 'theme_provider.dart';

/// 应用主题 — 4 套柔和配色（柔夜/晨雾/叶语/花雾）
class AppTheme {
  AppTheme._();

  // ── 通用属性 ──────────────────────────────────────
  static const Color _white = Colors.white;
  static const Color _cardWhite = Color(0xFFFAF8F5); // 柔和卡片白，非纯白
  static const Color _error = Color(0xFFCF6679);

  // ── 通用文字色系（所有主题共用） ──────────────────────
  static const Color _earth = Color(0xFF3D3D3D);
  static const Color _earthLight = Color(0xFF6B6B6B);
  static const Color _earthMedium = Color(0xFF9B9B9B);

  // ── 通用辅助色（所有主题共用） ──────────────────────
  static const Color _sage = Color(0xFF8CADA0);
  static const Color _sageLight = Color(0xFFCDE0D6);
  static const Color _rose = Color(0xFFD4879A);
  static const Color _roseLight = Color(0xFFEDCDD4);

  // ── 通用卡片阴影（所有主题共用） ──────────────────────
  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: _earth.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 2),
    ),
  ];

  static const Color _surfaceOverlay = Color(0x4D000000); // 30% 黑

  // ══════════════════════════════════════════════════════
  // 主题 1: 柔夜 (Soft Night) — 默认主题
  // ══════════════════════════════════════════════════════
  static const Color _softNightPrimary = Color(0xFF7B8BAA);
  static const Color _softNightPrimaryLight = Color(0xFFD8DFE8);
  static const Color _softNightPrimaryDark = Color(0xFF5A6B8A);
  static const Color _softNightCream = Color(0xFFF5F3F0);
  static const Color _softNightCreamDark = Color(0xFFEBE8E4);

  // ══════════════════════════════════════════════════════
  // 主题 2: 晨雾 (Morning Mist)
  // ══════════════════════════════════════════════════════
  static const Color _morningMistPrimary = Color(0xFF8AADB8);
  static const Color _morningMistPrimaryLight = Color(0xFFD6E5EA);
  static const Color _morningMistPrimaryDark = Color(0xFF6A8E9A);
  static const Color _morningMistCream = Color(0xFFF4F6F7);
  static const Color _morningMistCreamDark = Color(0xFFE8EDEF);

  // ══════════════════════════════════════════════════════
  // 主题 3: 叶语 (Leaf Whisper)
  // ══════════════════════════════════════════════════════
  static const Color _leafWhisperPrimary = Color(0xFF9CAD8A);
  static const Color _leafWhisperPrimaryLight = Color(0xFFDDE5D6);
  static const Color _leafWhisperPrimaryDark = Color(0xFF7A8D6A);
  static const Color _leafWhisperCream = Color(0xFFF5F4F0);
  static const Color _leafWhisperCreamDark = Color(0xFFEBE9E4);

  // ══════════════════════════════════════════════════════
  // 主题 4: 花雾 (Flower Mist)
  // ══════════════════════════════════════════════════════
  static const Color _flowerMistPrimary = Color(0xFFC9A0AA);
  static const Color _flowerMistPrimaryLight = Color(0xFFEDD8DE);
  static const Color _flowerMistPrimaryDark = Color(0xFFA8808A);
  static const Color _flowerMistCream = Color(0xFFF7F4F5);
  static const Color _flowerMistCreamDark = Color(0xFFEFEAEB);

  /// 根据主题类型获取 ThemeData
  static ThemeData getTheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.softNight:
        return _buildTheme(
          primary: _softNightPrimary,
          primaryLight: _softNightPrimaryLight,
          primaryDark: _softNightPrimaryDark,
          cream: _softNightCream,
          creamDark: _softNightCreamDark,
        );
      case AppThemeType.morningMist:
        return _buildTheme(
          primary: _morningMistPrimary,
          primaryLight: _morningMistPrimaryLight,
          primaryDark: _morningMistPrimaryDark,
          cream: _morningMistCream,
          creamDark: _morningMistCreamDark,
        );
      case AppThemeType.leafWhisper:
        return _buildTheme(
          primary: _leafWhisperPrimary,
          primaryLight: _leafWhisperPrimaryLight,
          primaryDark: _leafWhisperPrimaryDark,
          cream: _leafWhisperCream,
          creamDark: _leafWhisperCreamDark,
        );
      case AppThemeType.flowerMist:
        return _buildTheme(
          primary: _flowerMistPrimary,
          primaryLight: _flowerMistPrimaryLight,
          primaryDark: _flowerMistPrimaryDark,
          cream: _flowerMistCream,
          creamDark: _flowerMistCreamDark,
        );
    }
  }

  /// 构建 ThemeData — 统一柔和风格
  static ThemeData _buildTheme({
    required Color primary,
    required Color primaryLight,
    required Color primaryDark,
    required Color cream,
    required Color creamDark,
  }) {
    // 页面柔光渐变
    final scaffoldGradient = LinearGradient(
      colors: [cream, creamDark.withValues(alpha: 0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.dmSans().fontFamily,

      // 色彩
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: _white,
        primaryContainer: primaryLight,
        secondary: _sage,
        onSecondary: _white,
        secondaryContainer: _sageLight,
        tertiary: _rose,
        tertiaryContainer: _roseLight,
        surface: cream,
        onSurface: _earth,
        error: _error,
        onError: _white,
      ),

      // Scaffold
      scaffoldBackgroundColor: cream,

      // AppBar — 透明无分割线
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _earth,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _earth,
          letterSpacing: -0.5,
        ),
      ),

      // 卡片 — 大圆角 24px, 无边框, 极轻阴影, 柔和底色
      cardTheme: CardThemeData(
        color: _cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // 输入框 — 圆角 16px, 无边框, 半透明白底
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _white.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: _earthMedium),
      ),

      // 按钮 — 圆角 16px, 无阴影
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // 底部导航 — 半透明毛玻璃效果
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _white.withValues(alpha: 0.85),
        selectedItemColor: primary,
        unselectedItemColor: _earthLight,
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

      // FAB — 圆角 16px
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: _white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider — 极淡
      dividerTheme: DividerThemeData(
        color: _earthMedium.withValues(alpha: 0.12),
        thickness: 1,
        space: 0,
      ),

      // Chip — 圆角 12px
      chipTheme: ChipThemeData(
        backgroundColor: creamDark,
        selectedColor: primaryLight,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _earth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // 扩展主题
      extensions: [
        AppThemeExtension(
          primary: primary,
          primaryLight: primaryLight,
          primaryDark: primaryDark,
          earth: _earth,
          earthLight: _earthLight,
          earthMedium: _earthMedium,
          cream: cream,
          creamDark: creamDark,
          sage: _sage,
          sageLight: _sageLight,
          rose: _rose,
          roseLight: _roseLight,
          gradientPrimary: LinearGradient(
            colors: [primary, primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          gradientEarth: LinearGradient(
            colors: [const Color(0xFF3D3D3D), const Color(0xFF6B6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          cardBackground: _cardWhite,
          cardBorder: creamDark,
          cardShadow: _cardShadow,
          scaffoldGradient: scaffoldGradient,
          surfaceOverlay: _surfaceOverlay,
        ),
        ModuleThemeExtension(moduleColor: primary),
      ],
    );
  }

  /// 创建带有模块主题色的 ThemeData
  static ThemeData withModuleColor(Color moduleColor) {
    final base = getTheme(AppThemeType.softNight);
    return base.copyWith(
      extensions: [
        base.extension<AppThemeExtension>()!,
        ModuleThemeExtension(moduleColor: moduleColor),
      ],
    );
  }
}

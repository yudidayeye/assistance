import 'package:flutter/material.dart';

double _lerpD(double a, double b, double t) => a + (b - a) * t;

/// 应用主题扩展 — 通用色彩系统 + 卡片/背景/圆角/间距 token
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // ── 色彩（保留） ──
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color earth;
  final Color earthLight;
  final Color earthMedium;
  final Color cream;
  final Color creamDark;
  final Color sage;
  final Color sageLight;
  final Color rose;
  final Color roseLight;
  final Gradient gradientPrimary;
  final Gradient gradientEarth;

  // ── 卡片系统（新增） ──
  final Color cardBackground;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;

  // ── 背景系统（新增） ──
  final Gradient scaffoldGradient;
  final Color surfaceOverlay;

  // ── 圆角系统（新增） ──
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;

  // ── 间距系统（新增） ──
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  const AppThemeExtension({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.earth,
    required this.earthLight,
    required this.earthMedium,
    required this.cream,
    required this.creamDark,
    required this.sage,
    required this.sageLight,
    required this.rose,
    required this.roseLight,
    required this.gradientPrimary,
    required this.gradientEarth,
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShadow,
    required this.scaffoldGradient,
    required this.surfaceOverlay,
    this.radiusSm = 12,
    this.radiusMd = 16,
    this.radiusLg = 24,
    this.radiusXl = 28,
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 16,
    this.spaceLg = 24,
    this.spaceXl = 32,
  });

  @override
  AppThemeExtension copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? earth,
    Color? earthLight,
    Color? earthMedium,
    Color? cream,
    Color? creamDark,
    Color? sage,
    Color? sageLight,
    Color? rose,
    Color? roseLight,
    Gradient? gradientPrimary,
    Gradient? gradientEarth,
    Color? cardBackground,
    Color? cardBorder,
    List<BoxShadow>? cardShadow,
    Gradient? scaffoldGradient,
    Color? surfaceOverlay,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
  }) {
    return AppThemeExtension(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      earth: earth ?? this.earth,
      earthLight: earthLight ?? this.earthLight,
      earthMedium: earthMedium ?? this.earthMedium,
      cream: cream ?? this.cream,
      creamDark: creamDark ?? this.creamDark,
      sage: sage ?? this.sage,
      sageLight: sageLight ?? this.sageLight,
      rose: rose ?? this.rose,
      roseLight: roseLight ?? this.roseLight,
      gradientPrimary: gradientPrimary ?? this.gradientPrimary,
      gradientEarth: gradientEarth ?? this.gradientEarth,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      scaffoldGradient: scaffoldGradient ?? this.scaffoldGradient,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension other, double t) {
    return AppThemeExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      earth: Color.lerp(earth, other.earth, t)!,
      earthLight: Color.lerp(earthLight, other.earthLight, t)!,
      earthMedium: Color.lerp(earthMedium, other.earthMedium, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      creamDark: Color.lerp(creamDark, other.creamDark, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageLight: Color.lerp(sageLight, other.sageLight, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseLight: Color.lerp(roseLight, other.roseLight, t)!,
      gradientPrimary: other.gradientPrimary,
      gradientEarth: other.gradientEarth,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      scaffoldGradient: other.scaffoldGradient,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      radiusSm: _lerpD(radiusSm, other.radiusSm, t),
      radiusMd: _lerpD(radiusMd, other.radiusMd, t),
      radiusLg: _lerpD(radiusLg, other.radiusLg, t),
      radiusXl: _lerpD(radiusXl, other.radiusXl, t),
      spaceXs: _lerpD(spaceXs, other.spaceXs, t),
      spaceSm: _lerpD(spaceSm, other.spaceSm, t),
      spaceMd: _lerpD(spaceMd, other.spaceMd, t),
      spaceLg: _lerpD(spaceLg, other.spaceLg, t),
      spaceXl: _lerpD(spaceXl, other.spaceXl, t),
    );
  }
}

/// 模块主题色扩展
class ModuleThemeExtension extends ThemeExtension<ModuleThemeExtension> {
  final Color moduleColor;

  const ModuleThemeExtension({required this.moduleColor});

  @override
  ModuleThemeExtension copyWith({Color? moduleColor}) =>
      ModuleThemeExtension(moduleColor: moduleColor ?? this.moduleColor);

  @override
  ModuleThemeExtension lerp(ModuleThemeExtension other, double t) =>
      ModuleThemeExtension(
        moduleColor: Color.lerp(moduleColor, other.moduleColor, t)!,
      );
}

/// 从 Theme 中获取应用主题扩展
extension AppThemeGetter on ThemeData {
  AppThemeExtension get appTheme {
    return extension<AppThemeExtension>() ?? AppThemeExtension(
      primary: const Color(0xFF7B8BAA),
      primaryLight: const Color(0xFFD8DFE8),
      primaryDark: const Color(0xFF5A6B8A),
      earth: const Color(0xFF3D3D3D),
      earthLight: const Color(0xFF6B6B6B),
      earthMedium: const Color(0xFF9B9B9B),
      cream: const Color(0xFFF5F3F0),
      creamDark: const Color(0xFFEBE8E4),
      sage: const Color(0xFF8CADA0),
      sageLight: const Color(0xFFCDE0D6),
      rose: const Color(0xFFD4879A),
      roseLight: const Color(0xFFEDCDD4),
      gradientPrimary: const LinearGradient(
        colors: [Color(0xFF7B8BAA), Color(0xFF5A6B8A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      gradientEarth: const LinearGradient(
        colors: [Color(0xFF3D3D3D), Color(0xFF6B6B6B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      cardBackground: const Color(0xFFFAF8F5),
      cardBorder: const Color(0xFFEBE8E4),
      cardShadow: [
        BoxShadow(
          color: Color(0x0A3D3D3D),
          blurRadius: 20,
          offset: Offset(0, 2),
        ),
      ],
      scaffoldGradient: const LinearGradient(
        colors: [Color(0xFFF5F3F0), Color(0xFFEBE8E4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceOverlay: const Color(0x4D000000),
    );
  }
}

/// 从 Theme 中获取模块主题色
extension ModuleThemeGetter on ThemeData {
  ModuleThemeExtension get moduleTheme {
    return extension<ModuleThemeExtension>() ?? const ModuleThemeExtension(moduleColor: Colors.blue);
  }
}

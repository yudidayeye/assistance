import 'package:flutter/material.dart';

/// 应用主题扩展 — 通用色彩系统
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
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
      gradientPrimary: gradientPrimary,
      gradientEarth: gradientEarth,
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
    return extension<AppThemeExtension>() ?? const AppThemeExtension(
      primary: Color(0xFFD4AF37),
      primaryLight: Color(0xFFF5E6CC),
      primaryDark: Color(0xFFB8941F),
      earth: Color(0xFF2C1810),
      earthLight: Color(0xFF4A3228),
      earthMedium: Color(0xFF8B6F5C),
      cream: Color(0xFFFDF8F0),
      creamDark: Color(0xFFF5EDE0),
      sage: Color(0xFF7A8B6F),
      sageLight: Color(0xFFB8C4AB),
      rose: Color(0xFFC97D7D),
      roseLight: Color(0xFFE8B4B4),
      gradientPrimary: LinearGradient(
        colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      gradientEarth: LinearGradient(
        colors: [Color(0xFF2C1810), Color(0xFF4A3228)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }
}

/// 从 Theme 中获取模块主题色
extension ModuleThemeGetter on ThemeData {
  ModuleThemeExtension get moduleTheme {
    return extension<ModuleThemeExtension>() ?? const ModuleThemeExtension(moduleColor: Colors.blue);
  }
}

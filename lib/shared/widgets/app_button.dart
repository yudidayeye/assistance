import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';
import '../foundation/app_spacing.dart';

/// 按钮变体类型
enum AppButtonVariant { primary, secondary, danger, add, gradient, plain, outline }

/// 统一的应用按钮组件
///
/// 支持 7 种变体：
/// - [AppButton.primary] — 主要操作按钮（primary 色）
/// - [AppButton.secondary] — 次要/取消按钮（creamDark 色）
/// - [AppButton.danger] — 危险操作按钮（rose 色）
/// - [AppButton.add] — 添加按钮（primary 色透明底）
/// - [AppButton.gradient] — 渐变主要按钮（primary→primaryDark）
/// - [AppButton.plain] — 纯文字按钮（无背景）
/// - [AppButton.outline] — 边框按钮（primary 边框）
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final double fontSize;
  final FontWeight fontWeight;
  final double verticalPadding;
  final double horizontalPadding;
  final double borderRadius;
  final bool expanded;
  final Widget? child;
  final IconData? icon;

  const AppButton._({
    required this.label,
    this.onTap,
    required this.variant,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.verticalPadding = 14,
    this.horizontalPadding = 0,
    this.borderRadius = 16,
    this.expanded = false,
    this.child,
    this.icon,
  });

  /// 主要操作按钮（primary 色）
  factory AppButton.primary({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.primary,
      expanded: expanded,
    );
  }

  /// 次要/取消按钮（creamDark 色）
  factory AppButton.secondary({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.secondary,
      expanded: expanded,
    );
  }

  /// 危险操作按钮（rose 色透明底，类似 add 样式）
  factory AppButton.danger({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
    IconData? icon,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.danger,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      verticalPadding: 10,
      borderRadius: 10,
      expanded: expanded,
      icon: icon,
    );
  }

  /// 添加按钮（primary 色透明底）
  factory AppButton.add({
    required String label,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.add,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      verticalPadding: 10,
      borderRadius: 10,
      icon: icon,
    );
  }

  /// 渐变主要按钮（primary→primaryDark）
  factory AppButton.gradient({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.gradient,
      expanded: expanded,
    );
  }

  /// 纯文字按钮（无背景）
  factory AppButton.plain({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.plain,
      expanded: expanded,
    );
  }

  /// 边框按钮（primary 边框）
  factory AppButton.outline({
    required String label,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return AppButton._(
      label: label,
      onTap: onTap,
      variant: AppButtonVariant.outline,
      expanded: expanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final isEnabled = onTap != null;

    Color bgColor;
    Color txtColor;
    Gradient? gradient;

    // 根据变体决定颜色
    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = appTheme.primary;
        txtColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        bgColor = appTheme.creamDark;
        txtColor = appTheme.earthLight;
        break;
      case AppButtonVariant.danger:
        bgColor = appTheme.rose.withValues(alpha: 0.1);
        txtColor = appTheme.rose;
        break;
      case AppButtonVariant.add:
        bgColor = appTheme.primary.withValues(alpha: 0.1);
        txtColor = appTheme.primary;
        break;
      case AppButtonVariant.gradient:
        bgColor = appTheme.primary;
        txtColor = Colors.white;
        gradient = isEnabled
            ? LinearGradient(
                colors: [appTheme.primary, appTheme.primaryDark],
              )
            : null;
        break;
      case AppButtonVariant.plain:
        bgColor = Colors.transparent;
        txtColor = appTheme.primary;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        txtColor = appTheme.primary;
        break;
    }

    final buttonContent = GestureDetector(
      onTap: onTap,
      child: Container(
        width: expanded ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        decoration: BoxDecoration(
          color: gradient == null
              ? (isEnabled ? bgColor : appTheme.creamDark)
              : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: variant == AppButtonVariant.add
              ? Border.all(
                  color: isEnabled ? appTheme.primary.withValues(alpha: 0.3) : appTheme.primary.withValues(alpha: 0.15),
                  width: 1,
                )
              : variant == AppButtonVariant.danger
                  ? Border.all(
                      color: isEnabled ? appTheme.rose.withValues(alpha: 0.3) : appTheme.rose.withValues(alpha: 0.15),
                      width: 1,
                    )
                  : variant == AppButtonVariant.outline
                      ? Border.all(
                          color: isEnabled ? appTheme.primary : appTheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        )
                      : null,
          boxShadow: gradient != null && isEnabled
              ? [
                  BoxShadow(
                    color: appTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: child ??
              (icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isEnabled ? txtColor : appTheme.earthMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: AppTypography.bodyLg.copyWith(
                            fontSize: fontSize,
                            fontWeight: fontWeight,
                            color: isEnabled ? txtColor : appTheme.earthMedium,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: AppTypography.bodyLg.copyWith(
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        color: isEnabled ? txtColor : appTheme.earthMedium,
                      ),
                    )),
        ),
      ),
    );

    if (expanded) {
      return Expanded(child: buttonContent);
    }

    return buttonContent;
  }
}

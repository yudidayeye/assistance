import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_spacing.dart';
import '../foundation/app_typography.dart';

/// SnackBar 提示类型
enum AppSnackBarType { info, success, error }

/// 全局统一的 SnackBar 提示组件
///
/// Apple 风格悬浮提示：圆角 + 外边距，按语义着色。
/// info：主色浅底（常规提示）；success：绿色（成功）；error：红色（错误/校验失败）。
class AppSnackBar {
  AppSnackBar._();

  /// 显示提示，自动替换当前正在显示的 SnackBar
  static void show(
    BuildContext context,
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
  }) {
    final appTheme = Theme.of(context).appTheme;
    final (background, foreground) = switch (type) {
      AppSnackBarType.info => (appTheme.primaryLight, appTheme.earth),
      AppSnackBarType.success => (appTheme.sage, Colors.white),
      AppSnackBarType.error => (appTheme.rose, Colors.white),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTypography.bodyMd.copyWith(color: foreground),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.radiusMd),
          ),
          margin: const EdgeInsets.all(AppSpacing.sm),
        ),
      );
  }
}

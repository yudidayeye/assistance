import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';
import '../foundation/app_spacing.dart';
import 'app_button.dart';

/// 统一的应用弹窗组件
///
/// 提供标准化的弹窗容器和按钮对。
class AppDialog {
  /// 弹窗内"取消 + 确认"按钮对
  static Widget confirmCancelPair({
    required BuildContext context,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool confirmEnabled = true,
    bool isDestructive = false,
  }) {
    return Row(
      children: [
        AppButton.secondary(
          label: cancelLabel,
          onTap: onCancel ?? () => Navigator.pop(context),
          expanded: true,
        ),
        AppSpacing.w12,
        if (isDestructive)
          AppButton.danger(
            label: confirmLabel,
            onTap: confirmEnabled ? onConfirm : null,
            expanded: true,
          )
        else
          AppButton.primary(
            label: confirmLabel,
            onTap: confirmEnabled ? onConfirm : null,
            expanded: true,
          ),
      ],
    );
  }

  /// 快捷：显示一个完整弹窗
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget body,
    String? cancelLabel,
    String? confirmLabel,
    VoidCallback? onConfirm,
    bool isDestructive = false,
    double radius = 28,
  }) {
    final appTheme = Theme.of(context).appTheme;

    return showDialog<T>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20), // Apple 风格：更紧凑
          decoration: BoxDecoration(
            color: appTheme.cream,
            borderRadius: BorderRadius.circular(appTheme.radiusMd), // Apple 风格：更紧凑圆角
            border: Border.all(
              color: appTheme.earthMedium.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                title,
                style: AppTypography.displayMd.copyWith(
                  color: appTheme.earth,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.h20,
              // 内容
              body,
              // 按钮对
              if (cancelLabel != null && confirmLabel != null) ...[
                AppSpacing.h24,
                confirmCancelPair(
                  context: ctx,
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  onConfirm: onConfirm ?? () => Navigator.pop(ctx),
                  isDestructive: isDestructive,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 显示带图标的弹窗
  static Future<T?> showWithIcon<T>(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? message,
    String? cancelLabel,
    String? confirmLabel,
    VoidCallback? onConfirm,
    bool isDestructive = false,
    double radius = 28,
  }) {
    final appTheme = Theme.of(context).appTheme;

    return show<T>(
      context,
      title: title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(appTheme.radiusLg),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          AppSpacing.h20,
          // 消息
          if (message != null)
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: appTheme.earthMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
      isDestructive: isDestructive,
      radius: radius,
    );
  }
}

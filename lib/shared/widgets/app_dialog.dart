import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_spacing.dart';

/// 统一的应用弹窗组件（AlertDialog 风格）
class AppDialog {
  static Widget _textButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: textColor ?? appTheme.earthMedium)),
    );
  }

  /// 弹窗内"取消 + 确认"按钮对
  static List<Widget> confirmCancelPair({
    required BuildContext context,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    final appTheme = Theme.of(context).appTheme;
    return [
      _textButton(context: context, label: cancelLabel, onTap: onCancel ?? () => Navigator.pop(context)),
      _textButton(context: context, label: confirmLabel, onTap: onConfirm, textColor: isDestructive ? appTheme.rose : appTheme.primary),
    ];
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
  }) {
    final appTheme = Theme.of(context).appTheme;

    return showDialog<T>(
      context: context,
      barrierColor: appTheme.surfaceOverlay,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.cream,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: appTheme.earth,
          ),
          textAlign: TextAlign.center,
        ),
        content: body,
        actions: [
          if (cancelLabel != null && confirmLabel != null)
            ...confirmCancelPair(
              context: ctx,
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              onConfirm: onConfirm ?? () => Navigator.pop(ctx),
              isDestructive: isDestructive,
            ),
        ],
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
    );
  }
}

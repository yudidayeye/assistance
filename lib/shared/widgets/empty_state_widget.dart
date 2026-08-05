import '../../shared/foundation/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 通用空状态组件 — 柔和引导风格
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final color = iconColor ?? appTheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 36,
                color: color.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.h24,
            // 标题
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: appTheme.earth,
              ),
              textAlign: TextAlign.center,
            ),
            // 副标题
            if (subtitle != null) ...[
              AppSpacing.h8,
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earthMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // 操作按钮 — Apple 风格：pill 形状
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.h24,
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(appTheme.radiusPill), // Apple 风格：pill 形状
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

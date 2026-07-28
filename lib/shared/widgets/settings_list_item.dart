import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 设置页面列表项
///
/// 替换 settings_page 的 `_buildFunctionItem` / `_buildAboutItem` / `_buildModuleItem`。
class SettingsListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;
  final Color? iconColor;
  final Widget? trailing;

  const SettingsListItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final iconBgColor = isDestructive ? appTheme.rose : (iconColor ?? appTheme.primary);
    final textColor = isDestructive ? appTheme.rose : appTheme.earth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // 图标
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconBgColor, size: 18),
            ),
            const SizedBox(width: 12),
            // 文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: appTheme.earthMedium.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 尾部
            if (trailing != null)
              trailing!
            else if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

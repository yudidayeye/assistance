import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';

/// 分区标签
///
/// 替换 settings_page 的 `_SectionLabel`。
class SectionLabel extends StatelessWidget {
  final String title;

  const SectionLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.dmSans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appTheme.earthMedium,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分区卡片容器
///
/// 替换 settings_page 的 `_SectionCard`。
class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: appTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appTheme.cardShadow,
        border: Border.all(
          color: appTheme.cardBorder,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

import '../../shared/foundation/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';

/// 分段控制器 Tab 项
class AppSegmentedTabItem {
  final String label;
  final IconData? icon;
  const AppSegmentedTabItem({required this.label, this.icon});
}

/// 统一的分段控制器组件
///
/// 替换 3 处 Segmented Tab 控件重复结构。
class AppSegmentedTab extends StatelessWidget {
  final List<AppSegmentedTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const AppSegmentedTab({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.earthMedium.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(appTheme.radiusSm), // Apple 风格：更紧凑圆角
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? appTheme.cardBackground : null,
                  borderRadius: BorderRadius.circular(6), // Apple 风格：更紧凑圆角
                  // Apple 风格：无阴影
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected ? appTheme.primary : appTheme.earthMedium,
                      ),
                      AppSpacing.w4,
                    ],
                    Text(
                      item.label,
                      style: AppTypography.bodyMd.copyWith(
                        color: isSelected ? appTheme.primary : appTheme.earthMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

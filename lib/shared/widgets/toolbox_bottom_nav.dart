import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';

/// 底部导航项（数据驱动）
class ToolboxBottomNavItem {
  /// 标签文案
  final String label;

  /// 选中态强调色；为空则使用主题 primary / primaryDark
  final Color? selectedColor;

  /// 图标构建器（接收当前着色，便于统一适配普通 Icon 与模块 ModuleIcon）
  final Widget Function(Color color) iconBuilder;

  const ToolboxBottomNavItem({
    required this.label,
    required this.iconBuilder,
    this.selectedColor,
  });
}

/// 工具箱底部导航栏 — 毛玻璃柔和风格
class ToolboxBottomNav extends StatelessWidget {
  final List<ToolboxBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ToolboxBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: appTheme.cream.withValues(alpha: 0.94),
        // Apple 风格：无阴影，用分隔线替代
        border: Border(
          top: BorderSide(
            color: appTheme.earthMedium.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                item: items[i],
                isSelected: selectedIndex == i,
                onTap: () => onTap(i),
                appTheme: appTheme,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ToolboxBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeExtension appTheme;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.selectedColor;
    final barColor = accent ?? appTheme.primary;
    final color = isSelected
        ? (accent ?? appTheme.primaryDark)
        : appTheme.earthLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 28 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            item.iconBuilder(color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

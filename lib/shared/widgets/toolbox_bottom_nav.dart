import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';

/// 工具箱底部导航栏 — 毛玻璃柔和风格
class ToolboxBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ToolboxBottomNav({
    super.key,
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
        color: Colors.white.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.handyman_rounded,
              label: '工具箱',
              isSelected: selectedIndex == 0,
              onTap: () => onTap(0),
              appTheme: appTheme,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: '我的',
              isSelected: selectedIndex == 1,
              onTap: () => onTap(1),
              appTheme: appTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeExtension appTheme;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? appTheme.primary : appTheme.earthLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 选中指示短线
            if (isSelected)
              Container(
                width: 20,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: appTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 9),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
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

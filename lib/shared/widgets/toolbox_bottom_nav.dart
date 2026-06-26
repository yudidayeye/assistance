import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_extension.dart';

/// 工具箱底部导航栏
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
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withAlpha(18),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.handyman_rounded,
              label: '工具箱',
              isSelected: selectedIndex == 0,
              onTap: () => onTap(0),
              selectedColor: appTheme.sage,
              unselectedColor: appTheme.earthMedium,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: '我的',
              isSelected: selectedIndex == 1,
              onTap: () => onTap(1),
              selectedColor: appTheme.sage,
              unselectedColor: appTheme.earthMedium,
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
  final Color selectedColor;
  final Color unselectedColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 工具箱底部导航栏
class ToolboxBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ToolboxBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _selectedColor = Color(0xFF10b981);
  static const _unselectedColor = Color(0xFF8892a4);

  @override
  Widget build(BuildContext context) {
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
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: '我的',
              isSelected: selectedIndex == 1,
              onTap: () => onTap(1),
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? ToolboxBottomNav._selectedColor
        : ToolboxBottomNav._unselectedColor;

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

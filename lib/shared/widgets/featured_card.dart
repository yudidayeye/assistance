import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import 'package:go_router/go_router.dart';

/// 特色功能卡片 — 浅色系柔和风格
/// 匹配模块管理设置页的视觉语言：白底 + 浅色图标容器 + 无渐变
class FeaturedCard extends StatelessWidget {
  final ToolModule module;
  final String categoryLabel;
  final VoidCallback? onTap;
  final bool vertical;

  const FeaturedCard({
    super.key,
    required this.module,
    required this.categoryLabel,
    this.onTap,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = module.themeColor;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/${module.moduleId}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(8),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: vertical
              ? _buildVerticalLayout(color)
              : _buildHorizontalLayout(color),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: module.icon.build(size: 24, color: color),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            categoryLabel,
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withAlpha(180),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          module.displayName,
          style: TextStyle(
            fontFamily: GoogleFonts.robotoSlab().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C1810),
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          module.description,
          style: TextStyle(
            fontFamily: GoogleFonts.dmSans().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8B6F5C),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(Color color) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: module.icon.build(size: 26, color: color),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  categoryLabel,
                  style: TextStyle(
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withAlpha(180),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                module.displayName,
                style: TextStyle(
                  fontFamily: GoogleFonts.robotoSlab().fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C1810),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                module.description,
                style: TextStyle(
                  fontFamily: GoogleFonts.dmSans().fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8B6F5C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

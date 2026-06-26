import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/theme/theme_extension.dart';
import 'package:go_router/go_router.dart';

/// 特色功能卡片 — 极简风格
/// 白底 + 主题色图标 + 标题，无标签和描述
class FeaturedCard extends StatelessWidget {
  final ToolModule module;
  final VoidCallback? onTap;

  const FeaturedCard({
    super.key,
    required this.module,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = module.themeColor;
    final appTheme = Theme.of(context).appTheme;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/${module.moduleId}'),
      child: Container(
        decoration: BoxDecoration(
          color: appTheme.creamDark,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(8),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
            Text(
              module.displayName,
              style: TextStyle(
                fontFamily: GoogleFonts.robotoSlab().fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: appTheme.earth,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

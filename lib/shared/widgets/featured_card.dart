import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/theme/theme_extension.dart';
import 'package:go_router/go_router.dart';

/// 特色功能卡片 — 柔和状态容器风格
class FeaturedCard extends StatefulWidget {
  final ToolModule module;
  final VoidCallback? onTap;

  const FeaturedCard({
    super.key,
    required this.module,
    this.onTap,
  });

  @override
  State<FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<FeaturedCard> {
  String? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final s = await widget.module.getSummary();
    if (mounted) {
      setState(() => _summary = s.line1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.module.themeColor;
    final appTheme = Theme.of(context).appTheme;

    return GestureDetector(
      onTap: widget.onTap ?? () => context.push('/${widget.module.moduleId}'),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.cardBackground,
              appTheme.cardBackground.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(appTheme.radiusLg),
          boxShadow: appTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 模块图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Center(
                child: widget.module.icon.build(size: 28, color: color),
              ),
            ),
            SizedBox(height: appTheme.spaceMd),
            // 标题
            Text(
              widget.module.displayName,
              style: TextStyle(
                fontFamily: GoogleFonts.dmSans().fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: appTheme.earth,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_summary != null) ...[
              const SizedBox(height: 6),
              Text(
                _summary!,
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

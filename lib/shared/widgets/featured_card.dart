import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/theme/theme_extension.dart';
import 'package:go_router/go_router.dart';

/// 特色功能卡片 — 极简风格 + 底部摘要
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                child: widget.module.icon.build(size: 24, color: color),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.module.displayName,
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
            if (_summary != null) ...[
              const SizedBox(height: 6),
              Text(
                _summary!,
                style: TextStyle(
                  fontSize: 11,
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

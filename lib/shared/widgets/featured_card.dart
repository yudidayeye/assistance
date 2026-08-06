import 'package:flutter/material.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_summary.dart';
import '../../core/theme/theme_extension.dart';
import '../../modules/period_book/services/period_book_service.dart';
import '../../modules/period_tracker/services/period_service.dart';
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
  ModuleSummary? _summary;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    // 监听模块数据变更，自动刷新卡片
    if (widget.module.moduleId == 'period_book') {
      PeriodBookService.instance.addListener(_onDataChanged);
    }
    if (widget.module.moduleId == 'period_tracker') {
      PeriodService.instance.addListener(_onDataChanged);
    }
  }

  @override
  void dispose() {
    if (widget.module.moduleId == 'period_book') {
      PeriodBookService.instance.removeListener(_onDataChanged);
    }
    if (widget.module.moduleId == 'period_tracker') {
      PeriodService.instance.removeListener(_onDataChanged);
    }
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) refresh();
  }

  Future<void> _loadSummary() async {
    final s = await widget.module.getSummary();
    if (mounted) {
      setState(() => _summary = s);
    }
  }

  /// 外部触发刷新（如从子页面返回后）
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    await _loadSummary();
    _refreshing = false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.module.themeColor;
    final appTheme = Theme.of(context).appTheme;

    return GestureDetector(
      onTap: widget.onTap ?? () => context.push('/${widget.module.moduleId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: appTheme.cardBackground,
          borderRadius: BorderRadius.circular(appTheme.radiusLg), // Apple 风格：紧凑圆角
          border: Border.all(
            color: appTheme.earthMedium.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 模块图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(appTheme.radiusMd),
              ),
              child: Center(
                child: widget.module.icon.build(size: 24, color: color),
              ),
            ),
            const SizedBox(height: 10),
            // 标题
            Text(
              widget.module.displayName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_summary?.line1 != null) ...[
              const SizedBox(height: 4),
              Text(
                _summary!.line1,
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
            if (_summary?.line2 != null) ...[
              const SizedBox(height: 2),
              Text(
                _summary!.line2!,
                style: TextStyle(
                  fontSize: 11,
                  color: appTheme.earthMedium.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
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

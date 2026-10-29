import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';

/// 历史记录和阶段详情共用的分类筛选标签。
class CategoryFilterLabel extends StatelessWidget {
  final String category;
  final VoidCallback onClose;
  final EdgeInsetsGeometry padding;

  const CategoryFilterLabel({
    super.key,
    required this.category,
    required this.onClose,
    this.padding = AppSpacing.pageH,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Container(
      height: 44,
      color: appTheme.cream,
      padding: padding,
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 5),
          decoration: BoxDecoration(
            color: appTheme.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(appTheme.radiusPill),
            border: Border.all(
                color: appTheme.primary.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Text('筛选：$category',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: appTheme.primary)),
        ),
        Tooltip(
          message: '清除分类筛选',
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child:
                  Icon(Icons.close_rounded, size: 16, color: appTheme.primary),
            ),
          ),
        ),
      ]),
    );
  }
}

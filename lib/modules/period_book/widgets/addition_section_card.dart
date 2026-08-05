import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/foundation/app_spacing.dart';
import '../../../shared/utils/format_utils.dart';

/// 追加记录列表卡片组件（阶段编辑页和大额记录页共用）
///
/// 包含：标题行 + 总金额 + 追加列表 + 添加按钮
class AdditionSectionCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<AdditionItemData> additions;
  final Color color;
  final String prefix;
  final VoidCallback? onAdd;
  final Function(AdditionItemData addition)? onEdit;
  final Function(AdditionItemData addition)? onDelete;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Widget? leading;
  final Widget? form;
  final bool showAddButton;

  const AdditionSectionCard({
    super.key,
    required this.title,
    required this.emptyText,
    required this.additions,
    required this.color,
    this.prefix = '+¥',
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onReorder,
    this.leading,
    this.form,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    final total = additions.fold(0.0, (sum, a) => sum + a.amount);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: appTheme.earth,
                ),
              ),
              const Spacer(),
              _buildTotalChip(appTheme, total),
            ],
          ),
          AppSpacing.h12,
          // 列表
          if (additions.isEmpty)
            Center(
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 12,
                  color: appTheme.earthMedium.withValues(alpha: 0.5),
                ),
              ),
            )
          else if (onReorder != null)
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                onReorder!(oldIndex, newIndex);
              },
              children: [
                for (int i = 0; i < additions.length; i++)
                  _buildAdditionItem(context, appTheme, additions[i], index: i),
              ],
            )
          else
            ...additions.map((a) => _buildAdditionItem(context, appTheme, a)),
          // 内嵌表单（在列表和添加按钮之间）
          if (form != null) ...[
            AppSpacing.h8,
            form!,
          ],
          AppSpacing.h12,
          // 添加按钮
          if (showAddButton && onAdd != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加追加'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTheme.primary,
                  backgroundColor: appTheme.primary.withValues(alpha: 0.1),
                  side: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalChip(AppThemeExtension appTheme, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Text(
        '$prefix${total.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildAdditionItem(
      BuildContext context, AppThemeExtension appTheme, AdditionItemData addition,
      {int? index}) {
    Widget? effectiveLeading = leading;
    if (effectiveLeading != null && onReorder != null && index != null) {
      effectiveLeading = ReorderableDragStartListener(
        index: index,
        child: effectiveLeading,
      );
    }

    return GestureDetector(
      key: ValueKey('addition_${addition.id}'),
      onTap: () => onEdit?.call(addition),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: appTheme.earthMedium.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (effectiveLeading != null) effectiveLeading,
            if (effectiveLeading != null) AppSpacing.w8,
            Expanded(
              child: Text(
                addition.reason,
                style: TextStyle(
                  fontSize: 13,
                  color: appTheme.earth,
                ),
              ),
            ),
            Text(
              '+${FormatUtils.formatAmount(addition.amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            AppSpacing.w8,
            GestureDetector(
              onTap: () => onDelete?.call(addition),
              child: Icon(
                Icons.close,
                size: 16,
                color: appTheme.earthMedium.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 追加项数据（统一接口）
class AdditionItemData {
  final String id;
  final String reason;
  final double amount;

  const AdditionItemData({
    required this.id,
    required this.reason,
    required this.amount,
  });
}

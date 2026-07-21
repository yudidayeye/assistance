import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../shared/utils/format_utils.dart';
import '../models/addition_record.dart';

/// 追加记录条目
class AdditionListItem extends StatelessWidget {
  final AdditionRecord addition;
  final VoidCallback onDelete;
  final bool isReadOnly;

  const AdditionListItem({
    super.key,
    required this.addition,
    required this.onDelete,
    this.isReadOnly = false,
  });

  String _formatDate(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;

    final child = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.cream.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: appTheme.sage.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: appTheme.sage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  addition.reason,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: appTheme.earth,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(addition.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.earthMedium.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${FormatUtils.formatAmount(addition.amount)}',
            style: TextStyle(
              fontFamily: GoogleFonts.dmSans().fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.sage,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (isReadOnly) {
      return child;
    }

    return Dismissible(
      key: Key('addition_${addition.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: appTheme.rose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: appTheme.rose, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

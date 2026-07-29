import 'package:flutter/material.dart';
import '../../core/theme/theme_extension.dart';
import '../foundation/app_typography.dart';

/// 金额徽章组件
///
/// 替换 2 处完全相同的 `_buildTotalChip`。
class AmountChip extends StatelessWidget {
  final double amount;
  final Color color;
  final String prefix;

  const AmountChip({
    super.key,
    required this.amount,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(appTheme.radiusPill),
      ),
      child: Text(
        '$prefix${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

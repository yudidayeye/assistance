import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';
import 'info_query_typography.dart';

class InfoQueryCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const InfoQueryCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).appTheme;
    return Material(
      color: theme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: theme.earthMedium.withValues(alpha: 0.15), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: DefaultTextStyle(
            style: InfoQueryTypography.body.copyWith(color: theme.earth),
            child: child,
          ),
        ),
      ),
    );
  }
}

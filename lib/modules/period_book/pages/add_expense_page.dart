import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/foundation/app_typography.dart';
import '../../../shared/foundation/app_spacing.dart';

/// 记一笔页面 — Phase 4 实现
class AddExpensePage extends StatefulWidget {
  final int periodId;
  final String defaultCategory;

  const AddExpensePage({
    super.key,
    required this.periodId,
    this.defaultCategory = 'shopping',
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return AppScrollScaffold(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: appTheme.cream,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          automaticallyImplyLeading: true,
          title: Text(
            '记一笔',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headerTitle.copyWith(color: appTheme.earth),
          ),
        ),
        const SliverToBoxAdapter(
          child: Center(
            child: Text(
              '记一笔（开发中）',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8B9BAA),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';

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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Center(
          child: Text(
            '记一笔（开发中）',
            style: TextStyle(
              fontSize: 16,
              color: appTheme.earthMedium,
            ),
          ),
        ),
      ),
    );
  }
}

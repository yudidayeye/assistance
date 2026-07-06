import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';

/// 历史周期列表页 — Phase 3 实现
class PeriodHistoryPage extends StatefulWidget {
  const PeriodHistoryPage({super.key});

  @override
  State<PeriodHistoryPage> createState() => _PeriodHistoryPageState();
}

class _PeriodHistoryPageState extends State<PeriodHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Center(
          child: Text(
            '历史周期列表（开发中）',
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

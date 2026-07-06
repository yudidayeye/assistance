import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';

/// 新建周期页 — Phase 2 实现
class NewPeriodPage extends StatefulWidget {
  const NewPeriodPage({super.key});

  @override
  State<NewPeriodPage> createState() => _NewPeriodPageState();
}

class _NewPeriodPageState extends State<NewPeriodPage> {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Center(
          child: Text(
            '新建周期页（开发中）',
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

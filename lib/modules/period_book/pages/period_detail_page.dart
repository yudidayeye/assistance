import 'package:flutter/material.dart';
import '../../../core/theme/theme_extension.dart';

/// 当前周期详情页（入口页）— Phase 2 实现
class PeriodDetailPage extends StatefulWidget {
  /// 指定周期 ID 时以只读模式展示（历史周期）
  final int? periodId;

  const PeriodDetailPage({super.key, this.periodId});

  @override
  State<PeriodDetailPage> createState() => _PeriodDetailPageState();
}

class _PeriodDetailPageState extends State<PeriodDetailPage> {
  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).appTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.scaffoldGradient),
        child: Center(
          child: Text(
            '周期详情页（开发中）',
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import 'services/period_service.dart';
import 'services/prediction_service.dart';
import 'pages/calendar_page.dart';
import 'pages/stats_page.dart';
import 'package:my_assistant/shared/utils/date_utils.dart';

/// 生理期记录模块注册
class PeriodTrackerModule implements ToolModule {
  @override
  String get moduleId => 'period_tracker';

  @override
  String get displayName => '生理期记录';

  @override
  String get description => '女性生理周期记录与预测工具';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.favorite_rounded);

  @override
  Color get themeColor => const Color(0xFFD4879A); // 柔粉 — 关怀粉

  @override
  Widget buildEntryPage(BuildContext context) => const CalendarPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  List<RouteBase> buildSubRoutes() => [
        GoRoute(
          path: 'stats',
          builder: (context, state) => const PeriodStatsPage(),
        ),
      ];

  @override
  Future<void> onRegister(ModuleContext context) async {}

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async {
    final records = await PeriodService.instance.getAllRecords();
    final prediction = PredictionService.instance.predict(records);

    if (prediction != null) {
      return ModuleSummary(
        line1: '下次预测 ${AppDateUtils.formatDate(prediction.nextStartDate)}',
        line2: '当前周期 第${prediction.currentDayInCycle}天',
      );
    }
    return const ModuleSummary(line1: '暂无记录，点击开始');
  }
}

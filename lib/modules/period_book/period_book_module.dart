import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import 'services/period_book_service.dart';
import 'services/period_book_settings.dart';
import 'pages/period_detail_page.dart';
import 'pages/new_period_page.dart';
import 'pages/edit_period_page.dart';
import 'pages/period_history_page.dart';
import 'pages/large_items_history_page.dart';
import 'pages/stage_edit_page.dart';
import 'pages/large_items_edit_page.dart';

/// 周期记账模块注册
class PeriodBookModule implements ToolModule {
  @override
  String get moduleId => 'period_book';

  @override
  String get displayName => '周期记账';

  @override
  String get description => '以发薪周期为单位的轻量记账工具';

  @override
  ModuleIcon get icon =>
      const ModuleIcon.icon(Icons.account_balance_wallet_rounded);

  @override
  Color get themeColor => const Color(0xFF7B8BAA); // 柔夜蓝

  @override
  Widget buildEntryPage(BuildContext context) => const PeriodDetailPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  List<RouteBase> buildSubRoutes() => [
        GoRoute(
          path: 'new',
          builder: (context, state) => const NewPeriodPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return EditPeriodPage(periodId: id);
          },
        ),
        GoRoute(
          path: 'stage_edit/:stageId',
          builder: (context, state) {
            final stageId =
                int.tryParse(state.pathParameters['stageId'] ?? '') ?? 0;
            return StageEditPage(stageId: stageId);
          },
        ),
        GoRoute(
          path: 'history',
          builder: (context, state) => const PeriodHistoryPage(),
        ),
        GoRoute(
          path: 'large_history',
          builder: (context, state) => const LargeItemsHistoryPage(),
        ),
        GoRoute(
          path: 'detail/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return PeriodDetailPage(periodId: id);
          },
        ),
        GoRoute(
          path: 'large_items/:periodId',
          builder: (context, state) {
            final periodId =
                int.tryParse(state.pathParameters['periodId'] ?? '') ?? 0;
            return LargeItemsEditPage(periodId: periodId);
          },
        ),
        // 'add-expense' 路由已移除，阶段编辑页已内嵌添加支出/追加表单
      ];

  @override
  Future<void> onRegister(ModuleContext context) async {
    // 初始化默认发薪日（首次使用）
    await PeriodBookSettings.instance.getPayday();
  }

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async {
    final period = await PeriodBookService.instance.getOngoingPeriod();
    if (period == null) {
      return const ModuleSummary(line1: '暂无周期，点击创建');
    }
    final startFmt = _formatDateShort(period.startDate);
    final endFmt = _formatDateShort(period.endDate);
    final line1 = '$startFmt ~ $endFmt';

    // 使用 PeriodCalculations 获取计算后的余额（与详情页一致）
    final calc =
        await PeriodBookService.instance.getPeriodCalculations(period.id!);
    final balance = calc.balance;
    final totalExpense = calc.totalBase - (balance ?? 0);
    final line2 = balance != null
        ? '余额 ¥${balance.toStringAsFixed(2)}'
        : '支出 ¥${totalExpense.toStringAsFixed(2)}';

    return ModuleSummary(line1: line1, line2: line2);
  }

  String _formatDateShort(String dateStr) {
    final dt = DateTime.parse(dateStr);
    return '${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
  }
}

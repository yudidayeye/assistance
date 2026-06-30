import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import '../../shared/utils/format_utils.dart';
import 'services/transaction_service.dart';
import 'services/category_service.dart';
import 'pages/entry_page.dart';
import 'pages/add_page.dart';
import 'pages/stats_page.dart';
import 'pages/category_settings.dart';

/// 记账模块注册
class AccountingModule implements ToolModule {
  @override
  String get moduleId => 'accounting';

  @override
  String get displayName => '记账';

  @override
  String get description => '轻量级个人记账工具，快速记录收支';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.auto_awesome_rounded);

  @override
  Color get themeColor => const Color(0xFF9CAD8A); // 叶语绿 — 温和的绿

  @override
  Widget buildEntryPage(BuildContext context) => const AccountingEntryPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => const CategorySettingsPage();

  @override
  List<RouteBase> buildSubRoutes() => [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddTransactionPage(),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const AccountingStatsPage(),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const CategorySettingsPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AddTransactionPage(editId: id);
          },
        ),
      ];

  @override
  Future<void> onRegister(ModuleContext context) async {
    // 初始化预设分类
    await CategoryService.instance.initializeDefaultCategories();
  }

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {}

  @override
  Future<ModuleSummary> getSummary() async {
    final monthExpense = await TransactionService.instance.getMonthExpenseTotal(DateTime.now());
    return ModuleSummary(line1: '本月支出 ${FormatUtils.formatAmount(monthExpense)}');
  }
}
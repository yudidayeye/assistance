import 'package:flutter/material.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import 'services/transaction_service.dart';
import 'services/category_service.dart';
import 'pages/entry_page.dart';
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
  Color get themeColor => const Color(0xFFD4AF37); // 金色主题

  @override
  Widget buildEntryPage(BuildContext context) => const AccountingEntryPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => const CategorySettingsPage();

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
    final todayExpense = await TransactionService.instance.getTodayExpenseTotal();
    return ModuleSummary(line1: '今日支出 ¥${todayExpense == todayExpense.truncateToDouble() ? todayExpense.truncate() : todayExpense.toStringAsFixed(2)}');
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import 'services/vault_service.dart';
import 'services/vault_session.dart';
import 'pages/vault_entry_page.dart';
import 'pages/master_password_page.dart';
import 'pages/category_entries_page.dart';
import 'pages/add_entry_page.dart';
import 'pages/view_entry_page.dart';

/// 密码保险箱模块注册
class VaultModule implements ToolModule {
  @override
  String get moduleId => 'vault';

  @override
  String get displayName => '密码保险箱';

  @override
  String get description => '安全存储和管理常用密码';

  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.shield_rounded);

  @override
  Color get themeColor => const Color(0xFF6B8E7B); // 沉稳绿 — 安全感

  @override
  Widget buildEntryPage(BuildContext context) => const VaultEntryPage();

  @override
  Widget? buildSettingsPage(BuildContext context) => null;

  @override
  List<RouteBase> buildSubRoutes() => [
        GoRoute(
          path: 'setup',
          builder: (context, state) => const MasterPasswordPage(
            isSetup: true,
          ),
        ),
        GoRoute(
          path: 'unlock',
          builder: (context, state) => const MasterPasswordPage(
            isSetup: false,
          ),
        ),
        GoRoute(
          path: 'category/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return CategoryEntriesPage(categoryId: id);
          },
        ),
        GoRoute(
          path: 'add',
          builder: (context, state) {
            final categoryId =
                int.tryParse(state.uri.queryParameters['categoryId'] ?? '');
            return AddEntryPage(categoryId: categoryId);
          },
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return AddEntryPage(entryId: id);
          },
        ),
        GoRoute(
          path: 'view/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ViewEntryPage(entryId: id);
          },
        ),
      ];

  @override
  Future<void> onRegister(ModuleContext context) async {
    VaultSession.instance.init();
  }

  @override
  Future<void> onOpen(ModuleContext context) async {}

  @override
  Future<void> onClose(ModuleContext context) async {
    VaultSession.instance.lock();
  }

  @override
  Future<ModuleSummary> getSummary() async {
    final hasMaster = await VaultService.instance.hasMasterPassword();
    if (!hasMaster) {
      return const ModuleSummary(line1: '点击设置主密码', line2: '保护您的密码安全');
    }

    final totalCount = await VaultService.instance.getTotalEntryCount();
    final categories = await VaultService.instance.getAllCategories();

    if (totalCount == 0) {
      return const ModuleSummary(line1: '暂无密码记录', line2: '点击开始添加');
    }

    return ModuleSummary(
      line1: '$totalCount 条密码记录',
      line2: '${categories.length} 个分类',
    );
  }
}

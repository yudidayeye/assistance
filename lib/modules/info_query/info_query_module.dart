import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/module_system/module_context.dart';
import '../../core/module_system/module_summary.dart';
import '../../core/module_system/tool_module.dart';
import '../../core/theme/theme_provider.dart';
import 'pages/ai_models_page.dart';
import 'pages/info_query_page.dart';

class InfoQueryModule implements ToolModule {
  @override
  String get moduleId => 'info_query';
  @override
  String get displayName => '资讯查询';
  @override
  String get description => '查询公开资讯与 AI 模型能力价格榜单';
  @override
  ModuleIcon get icon => const ModuleIcon.icon(Icons.travel_explore_rounded);
  @override
  Color get themeColor => ThemeProvider.instance.themeData.colorScheme.primary;
  @override
  Widget buildEntryPage(BuildContext context) => const InfoQueryPage();
  @override
  Widget? buildSettingsPage(BuildContext context) => null;
  @override
  List<RouteBase> buildSubRoutes() =>
      [GoRoute(path: 'ai-models', builder: (_, state) => const AiModelsPage())];
  @override
  Future<void> onRegister(ModuleContext context) async {}
  @override
  Future<void> onOpen(ModuleContext context) async {}
  @override
  Future<void> onClose(ModuleContext context) async {}
  @override
  Future<ModuleSummary> getSummary() async =>
      const ModuleSummary(line1: 'AI 模型能力与价格', line2: '点击查询最新公开榜单');
}
